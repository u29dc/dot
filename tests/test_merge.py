"""Guard the one write path that can silently lose app-owned agent state."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import merge_agent_config as merge  # noqa: E402


class MergeTests(unittest.TestCase):
    def test_merge_keeps_app_state_and_applies_template(self):
        live = {
            'model': 'in-app-choice',
            'approval_policy': 'on-request',
            'personality': 'pragmatic',
            'projects': {'/repo': {'trust_level': 'trusted'}},
            'plugins': {'kept@market': {'enabled': False}},
            'mcp_servers': {'paper': {'command': 'paper', 'args': ['mcp']}},
            'unknown': {'kept': True},
        }
        managed = {
            'model': 'template-model',
            'approval_policy': 'never',
            'plugins': {'kept@market': {'enabled': True}, 'new@market': {'enabled': True}},
            'mcp_servers': {'paper': {'url': 'http://127.0.0.1/mcp'}},
        }
        result = merge.compose(live, managed, 'toml')
        self.assertEqual(result['model'], 'in-app-choice')  # seed-only
        self.assertEqual(result['approval_policy'], 'never')  # template wins
        self.assertNotIn('personality', result)  # retired
        self.assertEqual(result['projects'], live['projects'])  # app-owned
        self.assertEqual(result['plugins'], {'kept@market': {'enabled': False}, 'new@market': {'enabled': True}})
        self.assertEqual(result['mcp_servers'], live['mcp_servers'])  # never field-merged
        self.assertEqual(result['unknown'], {'kept': True})
        self.assertEqual(live['personality'], 'pragmatic')  # input not mutated
        self.assertEqual(tomllib.loads(merge.toml_dump(result)), result)

    def test_unparseable_live_config_is_never_replaced(self):
        with tempfile.TemporaryDirectory() as home:
            env = dict(os.environ, HOME=home)
            for name in ('CODEX_CONFIG_DEST', 'DOT_BACKUP_DIR', 'DOT_BACKUP_MANIFEST'):
                env.pop(name, None)
            for script, relative in (('claude.sh', '.claude/settings.json'), ('codex.sh', '.codex/config.toml')):
                dest = Path(home) / relative
                dest.parent.mkdir(parents=True)
                dest.write_text('not valid [{')
                result = subprocess.run(['/bin/bash', str(ROOT / 'scripts' / script)], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, script)
                self.assertIn('could not be merged', result.stdout, script)
                self.assertEqual(dest.read_text(), 'not valid [{', script)

    def test_unchanged_symlink_becomes_local_without_changing_source(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            env = dict(os.environ, DOT_BACKUP_DIR=str(fixture / 'backups'), DOT_BACKUP_MANIFEST=str(fixture / 'backups' / 'manifest.tsv'))
            for script, suffix in (('claude.sh', 'json'), ('codex.sh', 'toml')):
                with self.subTest(script=script):
                    dest = fixture / f'live.{suffix}'
                    command = ['/bin/bash', str(ROOT / 'scripts' / script), '--dest', str(dest)]
                    initial = subprocess.run(command, env=env, capture_output=True, text=True)
                    self.assertEqual(initial.returncode, 0, initial.stdout + initial.stderr)
                    source = fixture / f'source.{suffix}'
                    dest.rename(source)
                    original = source.read_bytes()
                    dest.symlink_to(source)

                    applied = subprocess.run(command, env=env, capture_output=True, text=True)
                    self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
                    self.assertFalse(dest.is_symlink())
                    self.assertEqual(dest.read_bytes(), original)
                    self.assertEqual(source.read_bytes(), original)
                    backup = fixture / 'backups' / str(dest).lstrip('/')
                    self.assertEqual(backup.read_bytes(), original)

                    unchanged = dest.stat().st_mtime_ns
                    repeated = subprocess.run(command, env=env, capture_output=True, text=True)
                    self.assertEqual(repeated.returncode, 0, repeated.stdout + repeated.stderr)
                    self.assertEqual(dest.stat().st_mtime_ns, unchanged)


if __name__ == '__main__':
    unittest.main()
