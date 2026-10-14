#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
set -Eeuo pipefail

# Dotfiles setup entrypoint. See SETUP.md for the fresh-machine runbook and
# scripts/lib/targets.sh for the managed file inventory.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR
for lib in progress env links render targets brew shell plugins skills agents dia; do
    # shellcheck source=/dev/null
    source "$DOTFILES_DIR/scripts/lib/$lib.sh"
done

dot_setup_error() {
    local status=$?
    local line="${BASH_LINENO[0]:-${LINENO}}"
    local command="${BASH_COMMAND:-unknown}"

    dot_progress_fail "Setup failed (exit $status) at line $line: $command"
    exit "$status"
}

trap dot_setup_error ERR

NO_BREW=false
DRY_RUN=false
DOT_ENV_FILE="${DOT_ENV_FILE:-$DOTFILES_DIR/setup.env}"

usage() {
    cat <<'USAGE'
Usage: setup.sh [--dry-run] [--no-brew] [--env-file PATH]

Setup reads machine-local values from setup.env by default. Create it with:
  cp setup.env.example setup.env
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-brew)
            NO_BREW=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --env-file)
            if [ "$#" -lt 2 ]; then
                dot_progress_fail "--env-file requires a value"
                exit 2
            fi
            DOT_ENV_FILE="${2:-}"
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
            dot_progress_fail "Unknown argument: $1"
            usage >&2
            exit 2
            ;;
    esac
done

apply_link_targets() {
    local want="$1"
    local section condition src dest

    while IFS='|' read -r section condition src dest; do
        [ "$section" = "$want" ] || continue
        if dot_target_enabled "$condition"; then
            link_file "$DOTFILES_DIR/$src" "$dest"
        else
            dot_progress_skip "$src ($condition!=1)"
        fi
    done <<EOF
$(dot_link_targets)
EOF
}

apply_render_targets() {
    local want="$1"
    local section condition template dest label

    while IFS='|' read -r section condition template dest label; do
        [ "$section" = "$want" ] || continue
        if dot_target_enabled "$condition"; then
            write_managed_file "$DOTFILES_DIR/$template" "$dest" "$label"
        else
            dot_progress_skip "$label ($condition!=1)"
        fi
    done <<EOF
$(dot_render_targets)
EOF
}

remove_legacy_targets() {
    local prefix dest

    while IFS='|' read -r prefix dest; do
        remove_legacy_managed_link "$dest" "$DOTFILES_DIR/$prefix"
        remove_empty_legacy_dir "$(dirname "$dest")"
    done <<EOF
$(dot_legacy_targets)
EOF
}

copy_local_override() {
    local example="$1"
    local dest="$2"

    if [ -f "$dest" ]; then
        dot_progress_skip "Local overrides already exist: $dest"
    elif dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp $example $dest"
    else
        mkdir -p "$(dirname "$dest")"
        cp "$DOTFILES_DIR/$example" "$dest"
        dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "$example -> $dest"
    fi
}

# Karabiner only watches its config directory after the console user server
# restarts, so a newly linked directory needs one restart.
reload_karabiner_if_relinked() {
    local before="$1"
    local service="gui/$UID/org.pqrs.service.agent.Karabiner-Console-User-Server"

    dot_dry_run && return 0
    [ -L "$HOME/.config/karabiner" ] || return 0
    [ "$(readlink "$HOME/.config/karabiner")" != "$before" ] || return 0
    launchctl print "$service" >/dev/null 2>&1 || return 0
    if launchctl kickstart -k "$service" >/dev/null 2>&1; then
        dot_progress_ok "Karabiner reloaded from the linked config directory"
    else
        dot_progress_warn "Restart Karabiner-Elements so it watches $HOME/.config/karabiner"
    fi
}

initialize_setup_environment
validate_setup_env

dot_progress_title "Dotfiles setup"
dot_progress_info "Directory: $DOTFILES_DIR"
dot_progress_info "Env file: $DOT_ENV_FILE"
dot_progress_info "Backup dir: $DOT_BACKUP_DIR"
if dot_dry_run; then
    dot_progress_info "Mode: dry-run"
fi

dot_progress_info "Homebrew layers:"
while IFS= read -r brewfile; do
    [ -n "$brewfile" ] || continue
    dot_progress_info "  - $brewfile"
done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF

if [ "$NO_BREW" = true ]; then
    dot_progress_skip "Homebrew packages (--no-brew)"
elif dot_dry_run; then
    dot_progress_skip "Homebrew packages (--dry-run)"
else
    if ! command -v brew >/dev/null 2>&1; then
        dot_progress_run_step --stream "Installing Homebrew" install_homebrew
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        dot_progress_ok "Homebrew available"
    fi

    # Collect layers first: brew must keep the terminal as stdin, not the list.
    brewfiles=()
    while IFS= read -r brewfile; do
        [ -n "$brewfile" ] && brewfiles+=("$(dot_abs_path "$brewfile")")
    done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF
    for brewfile in ${brewfiles[@]+"${brewfiles[@]}"}; do
        install_brewfile "$brewfile"
    done
fi

dot_ensure_dir "$TOOLS_HOME"

dot_progress_section "Shell configurations"
write_shell_env_files
cleanup_legacy_fish_split
apply_link_targets shell
copy_local_override shell/zsh/zshrc.local.example "$HOME/.zshrc.local"
copy_local_override shell/fish/local.fish.example "$HOME/.config/fish/local.fish"
apply_default_shell

dot_progress_section "Terminal configurations"
apply_link_targets terminal
link_executables "$DOTFILES_DIR/terminal/bin" "$HOME/.local/bin"
apply_render_targets terminal
remove_legacy_targets

dot_progress_section "Editor configurations"
apply_link_targets editor

dot_progress_section "System configurations"
karabiner_before="$(readlink "$HOME/.config/karabiner" 2>/dev/null || true)"
apply_link_targets system
reload_karabiner_if_relinked "$karabiner_before"
apply_render_targets system
if dot_truthy "$DOT_ENABLE_DIA"; then
    if dot_changed_in_run "$HOME/Library/LaunchAgents/$AGENT_BROWSER_DIA_LAUNCH_AGENT.plist"; then
        setup_dia_cdp 1
    else
        setup_dia_cdp 0
    fi
fi

dot_progress_section "Agent configurations"
sync_agents

dot_progress_ok "Setup complete"
dot_progress_info "Restart terminal; use fish or zsh to switch shells explicitly"
dot_progress_info "Next verification: bun run doctor"
