#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

profile="${DOT_PROFILE:-profile1}"
dest="${CODEX_CONFIG_DEST:-$HOME/.codex/config.toml}"
backup_dir="${DOT_BACKUP_DIR:-}"
backup_manifest="${DOT_BACKUP_MANIFEST:-}"

usage() {
    cat <<'USAGE'
Usage: codex.sh [--profile profile1|profile2] [--dest PATH]

Renders a machine-local Codex config from the tracked shared template.
Existing non-generated configs are backed up before replacement.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile)
            if [ "$#" -lt 2 ]; then
                printf '%s\n' "--profile requires a value" >&2
                exit 2
            fi
            profile="${2:-}"
            shift 2
            ;;
        --profile=*)
            profile="${1#--profile=}"
            shift
            ;;
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

case "$profile" in
    profile1 | profile2) ;;
    *)
        printf 'Unsupported setup profile: %s\n' "$profile" >&2
        exit 2
        ;;
esac

template="$DOTFILES_DIR/agents/codex.toml"
tools_home="${TOOLS_HOME:-${DOT_TOOLS_HOME:-$HOME/.tools}}"
node_repl_env_file="${CODEX_NODE_REPL_ENV_FILE:-$HOME/.config/dot/codex-node-repl.env.toml}"

if [ ! -f "$template" ]; then
    printf 'Codex template not found: %s\n' "$template" >&2
    exit 1
fi

if [ -e "$dest" ] || [ -L "$dest" ]; then
    if ! grep -Fq "dotfiles-managed: codex-config" "$dest" 2>/dev/null; then
        backup_dir="${backup_dir:-$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)}"
        backup_manifest="${backup_manifest:-$backup_dir/manifest.tsv}"
        backup="$backup_dir/${dest#/}"
        mkdir -p "$(dirname "$backup")"
        if [ -L "$dest" ]; then
            cp "$dest" "$backup"
            rm "$dest"
        else
            mv "$dest" "$backup"
        fi
        if [ ! -f "$backup_manifest" ]; then
            printf 'action\tsource\tdestination\tbackup\n' >"$backup_manifest"
        fi
        printf 'backup-codex\t%s\t%s\t%s\n' "$template" "$dest" "$backup" >>"$backup_manifest"
    fi
fi

mkdir -p "$(dirname "$dest")"

tmp="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")"
{
    printf '# dotfiles-managed: codex-config\n'
    printf '# dotfiles-profile: %s\n' "$profile"
    printf '# generated from: %s\n\n' "${template#"$DOTFILES_DIR"/}"
    sed \
        -e "s#__HOME__#$HOME#g" \
        -e "s#__TOOLS_HOME__#$tools_home#g" \
        "$template" |
        while IFS= read -r line; do
            printf '%s\n' "$line"
            if [ "$line" = "# dotfiles-managed: codex-node-repl-env" ] && [ -f "$node_repl_env_file" ]; then
                sed '/^[[:space:]]*$/d; /^[[:space:]]*#/d' "$node_repl_env_file"
            fi
        done
} >"$tmp"

mv "$tmp" "$dest"
printf 'Rendered Codex config: %s\n' "$dest"
