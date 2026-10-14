"""Discover complete plugins and install host-specific copies through official CLIs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import os

from merge_agent_config import toml_dump, tomllib

MANIFESTS = ('plugin.json', '.claude-plugin/plugin.json', '.codex-plugin/plugin.json')


def is_plugin(path):
    return any((path / name).is_file() for name in MANIFESTS)


def manifest(path):
    for name in MANIFESTS:
        if (path / name).is_file():
            data = json.loads((path / name).read_text())
            if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', data.get('name', '')):
                raise ValueError(f'Invalid plugin name in {path / name}')
            return data
    raise ValueError(f'No plugin manifest: {path}')


def discover(sources):
    found = {}
    for source in sources:
        path = Path(source).resolve()
        if not path.is_dir():
            continue
        candidates = [path] if is_plugin(path) else sorted(p for p in path.iterdir() if p.is_dir() and not p.name.startswith('.'))
        for candidate in candidates:
            if is_plugin(candidate):
                name = manifest(candidate)['name']
                if name in found and found[name] != candidate:
                    raise ValueError(f'Duplicate plugin name: {name}')
                found[name] = candidate
    return found


def registered_path(row):
    """Handle CLI source descriptors without treating a type tag as a path."""
    source = row.get('marketplaceSource', {})
    if isinstance(source, dict):
        for key in ('path', 'source'):
            value = source.get(key)
            if isinstance(value, str) and Path(value).is_absolute():
                return Path(value)
    source = row.get('source', {})
    if isinstance(source, dict):
        value = source.get('path')
        if isinstance(value, str) and Path(value).is_absolute():
            return Path(value)
    for key in ('path', 'root', 'installLocation'):
        value = row.get(key)
        if isinstance(value, str) and Path(value).is_absolute():
            return Path(value)
    return None


def stamp_local_version(package):
    """Fingerprint the exported bytes, then change only local manifest versions."""
    digest = hashlib.sha256()
    for path in sorted(package.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Packaged plugin contains a symlink: {path}')
        if path.is_file():
            digest.update(path.relative_to(package).as_posix().encode() + b'\0')
            content = path.read_bytes()
            digest.update(str(len(content)).encode() + b'\0' + content)
    base = manifest(package).get('version', '0.0.0')
    version = base + ('.local.' if '+' in base else '+local.') + digest.hexdigest()[:16]
    for relative in MANIFESTS:
        path = package / relative
        if path.is_file():
            data = json.loads(path.read_text())
            data['version'] = version
            path.write_text(json.dumps(data, indent=2) + '\n')
    return version


def installed_plugin(binary, host, selector):
    inventory = json.loads(subprocess.check_output([binary, 'plugin', 'list', '--json'], text=True))
    def find(value):
        if isinstance(value, dict):
            if value.get('pluginId', value.get('id')) == selector:
                if host == 'codex' and value.get('installed') is not True:
                    return None
                if host == 'claude' and value.get('scope') != 'user':
                    return None
                return value
            for item in value.values():
                result = find(item)
                if result is not None:
                    return result
        elif isinstance(value, list):
            for item in value:
                result = find(item)
                if result is not None:
                    return result
        return None
    return find(inventory)


def disable_snapshots(plugins, dry_run):
    """Keep old packages for recovery, but let whole-root source links own discovery."""
    selectors = {name + '@dot-local-' + name for name in plugins}
    paths = (
        (Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))) / 'config.toml', 'plugins', 'toml'),
        (Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home() / '.claude'))) / 'settings.json', 'enabledPlugins', 'json'),
    )
    for path, key, kind in paths:
        if not path.exists():
            continue
        original = path.read_text()
        data = tomllib.loads(original) if kind == 'toml' else json.loads(original)
        changed = []
        for selector in sorted(selectors):
            entry = data.get(key, {}).get(selector)
            if kind == 'toml' and isinstance(entry, dict) and entry.get('enabled', True) is not False:
                entry['enabled'] = False
                changed.append(selector)
            elif kind == 'json' and entry is True:
                data[key][selector] = False
                changed.append(selector)
        if not changed:
            continue
        if dry_run:
            print(f'Would disable managed snapshots in {path}: {", ".join(changed)}')
            continue
        text = toml_dump(data) if kind == 'toml' else json.dumps(data, indent=2) + '\n'
        backup = Path(tempfile.mkdtemp(prefix='plugin-links-', dir=backup_root()))
        shutil.copy2(path, backup / path.name, follow_symlinks=False)
        # Replace a legacy settings symlink without writing into its tracked source.
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(text)
        try:
            temporary.chmod(path.stat().st_mode & 0o777)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
        print(f'Disabled managed snapshots: {", ".join(changed)}; backup: {backup}')
    retire_claude_snapshots(selectors, dry_run)


def retire_claude_snapshots(selectors, dry_run):
    """Claude reserves installed plugin names even when disabled; back up and unregister."""
    root = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home() / '.claude')))
    registry = root / 'plugins/installed_plugins.json'
    if not registry.is_file():
        return
    installed = json.loads(registry.read_text()).get('plugins', {})
    for selector in sorted(selectors):
        entries = [row for row in installed.get(selector, []) if row.get('scope') == 'user']
        if not entries:
            continue
        if dry_run:
            print(f'Would back up and unregister Claude snapshot {selector} so the live name can load')
            continue
        binary = shutil.which('claude')
        if binary is None:
            raise ValueError('Claude CLI unavailable; cannot release the installed snapshot name')
        cache_root = (root / 'plugins/cache').resolve()
        for row in entries:
            cache = Path(row['installPath'])
            if not cache.resolve().is_relative_to(cache_root):
                raise ValueError(f'Refusing to retire a Claude plugin outside its cache: {cache}')
        backup = Path(tempfile.mkdtemp(prefix='plugin-snapshot-', dir=backup_root()))
        shutil.copy2(registry, backup / registry.name)
        settings = root / 'settings.json'
        if settings.exists():
            shutil.copy2(settings, backup / settings.name, follow_symlinks=False)
        for index, row in enumerate(entries):
            cache = Path(row['installPath'])
            if cache.is_dir():
                shutil.copytree(cache, backup / f'cache-{index}', symlinks=True)
        subprocess.run([binary, 'plugin', 'uninstall', selector, '--scope', 'user', '--keep-data'], check=True)
        remaining = json.loads(registry.read_text()).get('plugins', {}).get(selector, [])
        if any(row.get('scope') == 'user' for row in remaining):
            raise ValueError(f'Claude snapshot still registered: {selector}')
        print(f'Unregistered Claude snapshot {selector}; recovery copy: {backup}')


def backup_root():
    path = Path.home() / '.dotfiles-backups'
    path.mkdir(parents=True, exist_ok=True)
    return path


def install(source, host, root, dry_run):
    info = manifest(source)
    name = info['name']
    market = 'dot-local-' + name
    catalog = root / host / name
    destination = catalog / 'plugins' / name
    selector = name + '@' + market
    binary = shutil.which(host)
    if dry_run:
        print(f'Would package {name} for {host} in {catalog}')
        print(f'Would run {host} plugin marketplace add {catalog}')
        print(f'Would run {host} plugin {"add" if host == "codex" else "install/update"} {name}@{market} only if its content version changed')
        return
    if binary is None:
        raise ValueError(f'{host} CLI unavailable; no installation performed for {name}')
    catalog.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f'.{name}-', dir=catalog.parent))
    try:
        package = staging / 'plugins' / name
        package.parent.mkdir(parents=True)
        builder = source / 'build/package.py'
        if not builder.is_file():
            builder = source / 'scripts/package.py'
        if builder.is_file():
            subprocess.run([sys.executable, str(builder), '--format', host, '--output', str(package)], check=True)
        else:
            if any(p.is_symlink() for p in source.rglob('*')):
                raise ValueError(f'Generic plugin copy refuses symlinks: {source}')
            shutil.copytree(source, package, ignore=shutil.ignore_patterns('.git', '.DS_Store', '__pycache__', 'node_modules'))
        if manifest(package)['name'] != name:
            raise ValueError('Packaged plugin identity changed')
        version = stamp_local_version(package)
        if host == 'codex':
            relative = '.agents/plugins/marketplace.json'
            entry = {'name': name, 'source': {'source': 'local', 'path': './plugins/' + name}, 'policy': {'installation': 'AVAILABLE', 'authentication': 'ON_INSTALL'}, 'category': 'Productivity'}
            data = {'name': market, 'interface': {'displayName': 'Local ' + name}, 'plugins': [entry]}
        else:
            relative = '.claude-plugin/marketplace.json'
            data = {'name': market, 'owner': {'name': 'Local operator'}, 'plugins': [{'name': name, 'source': './plugins/' + name}]}
        path = staging / relative
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(data, indent=2) + '\n')
        inventory = json.loads(subprocess.check_output([binary, 'plugin', 'marketplace', 'list', '--json'], text=True))
        rows = inventory.get('marketplaces', []) if isinstance(inventory, dict) else inventory
        matches = [row for row in rows if row.get('name') == market]
        if matches:
            registered = registered_path(matches[0])
            if registered is None or registered.resolve() != catalog.resolve():
                raise ValueError(f'Marketplace {market} already points elsewhere; reconcile it before installing')
        installed = installed_plugin(binary, host, selector)
        if matches and installed and installed.get('version') == version and is_plugin(destination) and manifest(destination).get('version') == version:
            print(f'Unchanged {selector} for {host}: {version}; installation skipped')
            return
        # Keep previous catalog for recovery if a CLI registration/install fails.
        if catalog.exists():
            backup = Path(tempfile.mkdtemp(prefix=f'.{name}-previous-', dir=catalog.parent))
            backup.rmdir()
            catalog.rename(backup)
            print(f'Previous catalog retained: {backup}')
        staging.rename(catalog)
        if not matches:
            subprocess.run([binary, 'plugin', 'marketplace', 'add', str(catalog)], check=True)
        action = 'add' if host == 'codex' else ('update' if installed else 'install')
        command = [binary, 'plugin', action, selector]
        if host == 'claude':
            command += ['--scope', 'user']
        subprocess.run(command, check=True)
        verified = installed_plugin(binary, host, selector)
        if verified is None or verified.get('version') != version:
            raise ValueError(f'{selector}: CLI did not report the expected installed version {version}')
        print(f'Installed {selector} for {host}: {version}; enabled={verified.get("enabled")}')
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['list', 'install', 'disable-snapshots'])
    parser.add_argument('sources', nargs='+')
    parser.add_argument('--host', choices=['codex', 'claude', 'both'], default='both')
    parser.add_argument('--root', type=Path, default=Path.home() / '.local/share/dot/plugins')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    plugins = discover(args.sources)
    if args.action == 'disable-snapshots':
        disable_snapshots(plugins, args.dry_run)
        return
    for name, source in plugins.items():
        if args.action == 'list':
            print(f'{name}\t{source}')
        else:
            for host in ('codex', 'claude') if args.host == 'both' else (args.host,):
                install(source, host, args.root, args.dry_run)


if __name__ == '__main__':
    main()
