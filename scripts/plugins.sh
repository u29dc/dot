#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
# Narrow agent setup: policy links, settings, plugins and skills only. No
# Homebrew, shell, app or system changes.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR
for lib in progress env links targets plugins skills agents; do
    # shellcheck source=/dev/null
    source "$DOTFILES_DIR/scripts/lib/$lib.sh"
done

usage() {
    printf 'Usage: plugins.sh [--dry-run] [--env-file PATH]\n'
}

DRY_RUN=false
DOT_ENV_FILE="${DOT_ENV_FILE:-$DOTFILES_DIR/setup.env}"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --env-file)
            DOT_ENV_FILE="${2:?--env-file requires a path}"
            shift 2
            ;;
        --env-file=*)
            DOT_ENV_FILE="${1#--env-file=}"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

initialize_setup_environment
sync_agents
