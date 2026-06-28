#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
set -Eeuo pipefail

# Dotfiles setup entrypoint. See AGENTS.md for the fresh-machine runbook.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR
# shellcheck source=scripts/lib/progress.sh
source "$DOTFILES_DIR/scripts/lib/progress.sh"
# shellcheck source=scripts/lib/env.sh
source "$DOTFILES_DIR/scripts/lib/env.sh"
# shellcheck source=scripts/lib/links.sh
source "$DOTFILES_DIR/scripts/lib/links.sh"
# shellcheck source=scripts/lib/render.sh
source "$DOTFILES_DIR/scripts/lib/render.sh"
# shellcheck source=scripts/lib/brew.sh
source "$DOTFILES_DIR/scripts/lib/brew.sh"
# shellcheck source=scripts/lib/shell.sh
source "$DOTFILES_DIR/scripts/lib/shell.sh"
# shellcheck source=scripts/lib/skills.sh
source "$DOTFILES_DIR/scripts/lib/skills.sh"
# shellcheck source=scripts/lib/dia.sh
source "$DOTFILES_DIR/scripts/lib/dia.sh"

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

    while IFS= read -r brewfile; do
        [ -n "$brewfile" ] || continue
        install_brewfile "$(dot_abs_path "$brewfile")"
    done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF
fi

if dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "mkdir -p $TOOLS_HOME"
else
    dot_progress_run_step "Creating tool home" mkdir -p "$TOOLS_HOME"
fi

dot_progress_section "Shell configurations"
write_shell_env_files
link_file "$DOTFILES_DIR/shell/zsh/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/shell/zsh/zprofile" "$HOME/.zprofile"
if [ -f "$HOME/.zshrc.local" ]; then
    dot_progress_skip "Local shell overrides already exist: $HOME/.zshrc.local"
elif dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp shell/zsh/zshrc.local.example $HOME/.zshrc.local"
else
    cp "$DOTFILES_DIR/shell/zsh/zshrc.local.example" "$HOME/.zshrc.local"
    dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "zshrc.local.example -> $HOME/.zshrc.local"
fi
cleanup_legacy_fish_split
link_file "$DOTFILES_DIR/shell/fish/config.fish" "$HOME/.config/fish/config.fish"
link_file "$DOTFILES_DIR/shell/fish/functions.fish" "$HOME/.config/fish/functions.fish"
if [ -f "$HOME/.config/fish/local.fish" ]; then
    dot_progress_skip "Local Fish overrides already exist: $HOME/.config/fish/local.fish"
elif dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp shell/fish/local.fish.example $HOME/.config/fish/local.fish"
else
    mkdir -p "$HOME/.config/fish"
    cp "$DOTFILES_DIR/shell/fish/local.fish.example" "$HOME/.config/fish/local.fish"
    dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "local.fish.example -> $HOME/.config/fish/local.fish"
fi
apply_default_shell

dot_progress_section "Terminal configurations"
link_file "$DOTFILES_DIR/terminal/starship-dark.toml" "$HOME/.config/starship/starship-dark.toml"
link_file "$DOTFILES_DIR/terminal/starship-light.toml" "$HOME/.config/starship/starship-light.toml"
link_file "$DOTFILES_DIR/terminal/bottom.toml" "$HOME/.config/bottom/bottom.toml"
link_file "$DOTFILES_DIR/terminal/atuin.toml" "$HOME/.config/atuin/config.toml"
link_file "$DOTFILES_DIR/terminal/bat" "$HOME/.config/bat/config"
link_file "$DOTFILES_DIR/terminal/ignore" "$HOME/.ignore"
link_file "$DOTFILES_DIR/terminal/bin/buf" "$HOME/.local/bin/buf"
link_file "$DOTFILES_DIR/terminal/bin/cho" "$HOME/.local/bin/cho"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-chrome" "$HOME/.local/bin/agent-browser-chrome"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia" "$HOME/.local/bin/agent-browser-dia"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia-off" "$HOME/.local/bin/agent-browser-dia-off"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia-on" "$HOME/.local/bin/agent-browser-dia-on"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia-status" "$HOME/.local/bin/agent-browser-dia-status"
link_file "$DOTFILES_DIR/terminal/bin/delta-themed" "$HOME/.local/bin/delta-themed"
link_file "$DOTFILES_DIR/terminal/bin/fin" "$HOME/.local/bin/fin"
link_file "$DOTFILES_DIR/terminal/bin/grn" "$HOME/.local/bin/grn"
link_file "$DOTFILES_DIR/terminal/bin/let" "$HOME/.local/bin/let"
link_file "$DOTFILES_DIR/terminal/bin/pdf" "$HOME/.local/bin/pdf"
link_file "$DOTFILES_DIR/terminal/bin/tao" "$HOME/.local/bin/tao"
link_file "$DOTFILES_DIR/terminal/bin/upd" "$HOME/.local/bin/upd"

link_file "$DOTFILES_DIR/biome.json" "$HOME/.config/biome/biome.json"
link_file "$DOTFILES_DIR/tsconfig.json" "$HOME/.config/typescript/tsconfig.json"
link_file "$DOTFILES_DIR/bunfig.toml" "$HOME/.bunfig.toml"
link_file "$DOTFILES_DIR/uv.toml" "$HOME/.config/uv/uv.toml"

dot_progress_section "Editor configurations"
link_file "$DOTFILES_DIR/editor/settings.json" "$HOME/.config/zed/settings.json"
link_file "$DOTFILES_DIR/editor/keymap.json" "$HOME/.config/zed/keymap.json"

dot_progress_section "Additional terminal configurations"
write_managed_file "$DOTFILES_DIR/terminal/ssh.template" "$HOME/.ssh/config" "SSH config"
link_file "$DOTFILES_DIR/terminal/neofetch" "$HOME/.config/neofetch/config.conf"
link_file "$DOTFILES_DIR/terminal/statusline" "$HOME/.config/ccstatusline/settings.json"
link_file "$DOTFILES_DIR/terminal/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link_file "$DOTFILES_DIR/terminal/yt-dlp" "$HOME/.config/yt-dlp/config"
write_managed_file "$DOTFILES_DIR/terminal/agent-browser.json.template" "$HOME/.agent-browser/config.json" "agent-browser Dia config"
link_file "$DOTFILES_DIR/terminal/agent-browser.chrome.json" "$HOME/.agent-browser/chrome.json"

dot_progress_section "System configurations"
if dot_truthy "$DOT_ENABLE_GIT_CONFIG"; then
    write_managed_file "$DOTFILES_DIR/system/gitconfig.template" "$HOME/.gitconfig" "gitconfig"
    write_managed_file "$DOTFILES_DIR/system/git-allowed-signers.template" "$DOT_GIT_ALLOWED_SIGNERS_FILE" "git allowed signers"
else
    dot_progress_skip "Git config generation (DOT_ENABLE_GIT_CONFIG!=1)"
fi

if dot_truthy "$DOT_ENABLE_SYSTEM_EXTENSIONS"; then
    link_file "$DOTFILES_DIR/system/karabiner" "$HOME/.config/karabiner/karabiner.json"
    link_file "$DOTFILES_DIR/macos/.macos" "$HOME/.macos"
else
    dot_progress_skip "System extension configs (DOT_ENABLE_SYSTEM_EXTENSIONS!=1)"
fi

if dot_truthy "$DOT_ENABLE_ONEPASSWORD"; then
    write_managed_file "$DOTFILES_DIR/system/1password.agent.toml.template" "$HOME/.config/1Password/ssh/agent.toml" "1Password SSH agent"
else
    dot_progress_skip "1Password SSH agent config (DOT_ENABLE_ONEPASSWORD!=1)"
fi

if dot_truthy "$DOT_ENABLE_DIA"; then
    write_managed_file "$DOTFILES_DIR/system/launchagents/com.u29dc.dia-cdp.plist.template" "$HOME/Library/LaunchAgents/com.u29dc.dia-cdp.plist" "Dia CDP LaunchAgent"
    setup_dia_cdp
else
    dot_progress_skip "Dia CDP LaunchAgent (DOT_ENABLE_DIA!=1)"
fi

dot_progress_section "Agent configurations"
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link_file "$DOTFILES_DIR/agents/claude.json" "$HOME/.claude/settings.json"
read_known_extra_skill_sources
link_skills "$HOME/.claude/skills"

link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
if dot_truthy "$DOT_ENABLE_CODEX_CONFIG"; then
    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "scripts/codex.sh --dest $HOME/.codex/config.toml"
    else
        DOT_BACKUP_DIR="$DOT_BACKUP_DIR" DOT_BACKUP_MANIFEST="$DOT_BACKUP_MANIFEST" TOOLS_HOME="$TOOLS_HOME" CODEX_NODE_REPL_ENV_FILE="$CODEX_NODE_REPL_ENV_FILE" DOT_CODEX_NOTIFY_COMMAND="$DOT_CODEX_NOTIFY_COMMAND" "$DOTFILES_DIR/scripts/codex.sh" --dest "$HOME/.codex/config.toml"
    fi
else
    dot_progress_skip "Codex config generation (DOT_ENABLE_CODEX_CONFIG!=1)"
fi
link_skills "$HOME/.codex/skills"
link_skills "$HOME/.agents/skills"
write_extra_skill_sources_state

dot_progress_ok "Setup complete"
dot_progress_info "Restart terminal; use fish or zsh to switch shells explicitly"
dot_progress_info "Next verification: bun run doctor"
