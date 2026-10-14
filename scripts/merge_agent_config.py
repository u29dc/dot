"""Merge shared settings without discarding runtime-owned agent state.

Prints "changed" or "unchanged" first; --report adds one line per changed key.
"""
import argparse
import copy
import datetime
import json
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

# Tables the agent apps write at runtime: live entries win, template entries
# only supply missing defaults.
RUNTIME = {'toml': {'plugins', 'marketplaces', 'projects'}, 'json': {'enabledPlugins', 'extraKnownMarketplaces'}}
# Server definitions are atomic; merging fields across two definitions could
# combine a stdio command with an HTTP url.
ATOMIC = {'toml': {'mcp_servers'}, 'json': {'mcpServers'}}
# Model choices are changed in-app; the template seeds them for new machines.
SEED = {'toml': {'model', 'model_reasoning_effort', 'service_tier'}, 'json': {'model'}}
# Keys the templates once wrote and no longer manage. Merges never delete live
# keys otherwise, so a dropped key would keep its stale value forever.
RETIRED = {
    'toml': {
        ('personality',),  # deprecated: friendly/pragmatic no longer select a style
        ('agents', 'max_threads'),  # legacy alias of agents.max_concurrent_threads_per_session
        ('agents', 'job_max_runtime_seconds'),  # removed from the config schema
        ('shell_environment_policy', 'set', 'BUF'),  # retired managed tools
        ('shell_environment_policy', 'set', 'GRN'),
        ('shell_environment_policy', 'set', 'PDF'),
    },
    'json': {
        ('env', 'DISABLE_AUTO_COMPACT'),  # superseded by autoCompactEnabled
    },
}


def merge(base, overlay):
    result = dict(base)
    for key, value in overlay.items():
        result[key] = merge(result[key], value) if isinstance(value, dict) and isinstance(result.get(key), dict) else value
    return result


def compose(live, managed, kind):
    # Deep copy: retiring keys below must never mutate the caller's live data.
    result = merge(copy.deepcopy(live), managed)
    for key in RUNTIME[kind] & live.keys():
        result[key] = merge(managed.get(key, {}), live[key]) if isinstance(live[key], dict) else live[key]
    for key in ATOMIC[kind] & live.keys():
        template = managed.get(key, {})
        if isinstance(live[key], dict) and isinstance(template, dict):
            result[key] = {**template, **live[key]}
    for key in SEED[kind] & live.keys():
        result[key] = live[key]
    for path in RETIRED[kind]:
        parent = result
        for part in path[:-1]:
            parent = parent.get(part) if isinstance(parent, dict) else None
        if isinstance(parent, dict):
            parent.pop(path[-1], None)
    return result


def render(text, variables):
    """Replace __NAME__ placeholders with values escaped for JSON and TOML strings."""
    for name, value in variables.items():
        text = text.replace(f'__{name}__', json.dumps(value, ensure_ascii=False)[1:-1])
    return text


def toml_value(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (datetime.datetime, datetime.date, datetime.time)):
        return value.isoformat()
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return '[' + ', '.join(toml_value(item) for item in value) + ']'
    if isinstance(value, dict):
        return '{' + ', '.join(json.dumps(key) + ' = ' + toml_value(item) for key, item in value.items()) + '}'
    raise ValueError(f'Unsupported TOML value: {type(value)}')


def toml_dump(data):
    lines = ['# dotfiles-managed: codex-config', '# Shared preferences merged with local runtime state.']

    def table(value, path):
        if path:
            lines.append('\n[' + '.'.join(json.dumps(key) for key in path) + ']')
        for key, item in value.items():
            if not isinstance(item, dict):
                lines.append(json.dumps(key) + ' = ' + toml_value(item))
        for key, item in value.items():
            if isinstance(item, dict):
                table(item, path + [key])

    table(data, [])
    text = '\n'.join(lines) + '\n'
    if tomllib.loads(text) != data:
        raise ValueError('TOML round-trip failed')
    return text


def changes(before, after, path=()):
    """Yield (dotted key, old, new) for every leaf that differs."""
    if isinstance(before, dict) and isinstance(after, dict):
        for key in sorted(before.keys() | after.keys()):
            yield from changes(before.get(key), after.get(key), path + (key,))
    elif before != after:
        yield '.'.join(path), before, after


def describe(value):
    text = '<unset>' if value is None else json.dumps(value, ensure_ascii=False)
    text = text.replace(str(Path.home()), '~')
    return text if len(text) <= 80 else text[:77] + '...'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['json', 'toml'])
    parser.add_argument('managed', type=Path)
    parser.add_argument('live', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--var', action='append', default=[], metavar='NAME=VALUE', help='placeholder value for __NAME__ in the template')
    parser.add_argument('--report', action='store_true', help='list changed keys after the status line')
    args = parser.parse_args()

    def parse(text, origin):
        value = json.loads(text) if args.kind == 'json' else tomllib.loads(text)
        if not isinstance(value, dict):
            raise ValueError(f'{origin}: configuration must be an object')
        return value

    variables = dict(item.split('=', 1) for item in args.var)
    managed = parse(render(args.managed.read_text(), variables), args.managed)
    live = parse(args.live.read_text(), args.live) if args.live.exists() else {}
    result = compose(live, managed, args.kind)
    args.output.write_text(json.dumps(result, indent=2) + '\n' if args.kind == 'json' else toml_dump(result))

    print('unchanged' if args.live.exists() and result == live else 'changed')
    if args.report:
        for key, old, new in changes(live, result):
            print(f'{key}: {describe(old)} -> {describe(new)}')


if __name__ == '__main__':
    main()
