"""Keep package channel choices local to each workstation."""
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SetupTests(unittest.TestCase):
    def test_onepassword_channel_selects_one_package(self):
        for channel, package in ((None, '1password'), ('beta', '1password@beta'), ('nightly', '1password@nightly')):
            with self.subTest(channel=channel):
                env = dict(os.environ)
                env.pop('HOMEBREW_BUNDLE_ONEPASSWORD_CHANNEL', None)
                if channel is not None:
                    env['HOMEBREW_BUNDLE_ONEPASSWORD_CHANNEL'] = channel
                result = subprocess.run(['brew', 'bundle', 'list', '--cask', '--file', str(ROOT / 'homebrew/Brewfile.primary')], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                packages = [line for line in result.stdout.splitlines() if line in ('1password', '1password@beta', '1password@nightly')]
                self.assertEqual(packages, [package])

    def test_onepassword_channel_survives_generated_shell_env(self):
        script = '''
set -eu
DOTFILES_DIR="$1"
for lib in env render shell; do source "$DOTFILES_DIR/scripts/lib/$lib.sh"; done
dot_apply_defaults
shell_env_content "$2" /tmp/dot-channel-check
'''
        for shell in ('zsh', 'fish'):
            with self.subTest(shell=shell):
                env = dict(os.environ, DOT_ONEPASSWORD_CHANNEL='beta')
                result = subprocess.run(['/bin/bash', '-c', script, 'dot-test', str(ROOT), shell], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                for name in ('DOT_ONEPASSWORD_CHANNEL', 'HOMEBREW_BUNDLE_ONEPASSWORD_CHANNEL'):
                    match = re.search(r"(?:export |set -gx )" + name + r"[= ]'([^']+)'", result.stdout)
                    self.assertIsNotNone(match)
                    self.assertEqual(match.group(1), 'beta')


if __name__ == '__main__':
    unittest.main()
