#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${CODEX_CONFIG_DEST:-$HOME/.codex/config.toml}"
backup_dir="${DOT_BACKUP_DIR:-}"
backup_manifest="${DOT_BACKUP_MANIFEST:-}"
dry_run=false

usage() {
    cat <<'USAGE'
Usage: codex.sh [--dest PATH] [--dry-run]

Renders a machine-local Codex config from agents/codex.toml.
Existing non-generated configs are backed up before replacement.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dest)
            if [ "$#" -lt 2 ]; then
                printf '%s\n' "--dest requires a value" >&2
                exit 2
            fi
            dest="${2:-}"
            shift 2
            ;;
        --dest=*)
            dest="${1#--dest=}"
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

template="$DOTFILES_DIR/agents/codex.toml"
tools_home="${TOOLS_HOME:-${DOT_TOOLS_HOME:-$HOME/.tools}}"
node_repl_env_file="${CODEX_NODE_REPL_ENV_FILE:-$HOME/.config/dot/codex-node-repl.env.toml}"
codex_notify_command="${DOT_CODEX_NOTIFY_COMMAND:-$HOME/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient}"

if [ ! -f "$template" ]; then
    printf 'Codex template not found: %s\n' "$template" >&2
    exit 1
fi

render_line() {
    local line="$1"
    line="${line//__HOME__/$HOME}"
    line="${line//__TOOLS_HOME__/$tools_home}"
    line="${line//__CODEX_NOTIFY_COMMAND__/$codex_notify_command}"
    printf '%s\n' "$line"
}

render_config() {
    local line

    printf '# dotfiles-managed: codex-config\n'
    printf '# dotfiles-source: %s\n\n' "${template#"$DOTFILES_DIR"/}"

    while IFS= read -r line || [ -n "$line" ]; do
        render_line "$line"
        if [ "$line" = "# dotfiles-managed: codex-node-repl-env" ] && [ -f "$node_repl_env_file" ]; then
            sed '/^[[:space:]]*$/d; /^[[:space:]]*#/d' "$node_repl_env_file"
        fi
    done <"$template"
}

backup_existing() {
    local backup

    [ -e "$dest" ] || [ -L "$dest" ] || return 0
    grep -Fq "dotfiles-managed: codex-config" "$dest" 2>/dev/null && return 0

    backup_dir="${backup_dir:-$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)}"
    backup_manifest="${backup_manifest:-$backup_dir/manifest.tsv}"
    backup="$backup_dir/${dest#/}"

    if [ "$dry_run" = true ]; then
        printf 'Would back up Codex config: %s -> %s\n' "$dest" "$backup"
        return 0
    fi

    mkdir -p "$(dirname "$backup")"
    if [ -L "$dest" ]; then
        cp -P "$dest" "$backup"
        rm "$dest"
    else
        mv "$dest" "$backup"
    fi
    if [ ! -f "$backup_manifest" ]; then
        printf 'action\tsource\tdestination\tbackup\n' >"$backup_manifest"
    fi
    printf 'backup-codex\t%s\t%s\t%s\n' "$template" "$dest" "$backup" >>"$backup_manifest"
}

if [ "$dry_run" = true ]; then
    render_config >/dev/null
    printf 'Would render Codex config: %s\n' "$dest"
    exit 0
fi

backup_existing
mkdir -p "$(dirname "$dest")"
tmp="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")"
render_config >"$tmp"
mv "$tmp" "$dest"
printf 'Rendered Codex config: %s\n' "$dest"
