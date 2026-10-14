#!/usr/bin/env bash
# Merge agents/claude.json into the machine-local Claude settings file.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/progress.sh
source "$DOTFILES_DIR/scripts/lib/progress.sh"
# shellcheck source=scripts/lib/env.sh
source "$DOTFILES_DIR/scripts/lib/env.sh"
# shellcheck source=scripts/lib/links.sh
source "$DOTFILES_DIR/scripts/lib/links.sh"
# shellcheck source=scripts/lib/agents.sh
source "$DOTFILES_DIR/scripts/lib/agents.sh"

dest="$HOME/.claude/settings.json"
DRY_RUN=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dest)
            dest="${2:?--dest requires a path}"
            shift 2
            ;;
        --dest=*)
            dest="${1#--dest=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h | --help)
            printf 'Usage: claude.sh [--dest PATH] [--dry-run]\n'
            exit 0
            ;;
        *)
            printf 'Usage: claude.sh [--dest PATH] [--dry-run]\n' >&2
            exit 2
            ;;
    esac
done

dot_apply_defaults
sync_claude_settings "$dest"
