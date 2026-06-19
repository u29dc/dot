#!/usr/bin/env bash
set -Eeuo pipefail

# Dotfiles setup entrypoint. See AGENTS.md for the fresh-machine runbook.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=shell/functions/progress.sh
source "$DOTFILES_DIR/shell/functions/progress.sh"

dot_setup_error() {
    local status=$?
    local line="${BASH_LINENO[0]:-${LINENO}}"
    local command="${BASH_COMMAND:-unknown}"

    dot_progress_fail "Setup failed (exit $status) at line $line: $command"
    exit "$status"
}

trap dot_setup_error ERR

DOT_KNOWN_ENV_VARS=(
    DOT_PROFILE
    DOT_TOOLS_HOME
    TOOLS_HOME
    DOT_SKILLS_PROFILE1
    DOT_SKILLS_PROFILE2
    DOT_SKILL_ROOTS_STATE
    DOT_ENABLE_DIA
    DOT_ENABLE_ONEPASSWORD
    DOT_ENABLE_SYSTEM_EXTENSIONS
    DOT_ENABLE_CODEX_CONFIG
    CODEX_NODE_REPL_ENV_FILE
    SKILLS_BASE
)

AGENT_BROWSER_DIA_PORT="${AGENT_BROWSER_DIA_PORT:-9222}"
AGENT_BROWSER_DIA_APP="/Applications/Dia.app"
AGENT_BROWSER_DIA_BIN="$AGENT_BROWSER_DIA_APP/Contents/MacOS/Dia"
AGENT_BROWSER_DIA_LAUNCH_AGENT="com.u29dc.dia-cdp"

# Parse command line arguments
NO_BREW=false
DRY_RUN=false
CLI_DOT_PROFILE=""

usage() {
    cat <<'USAGE'
Usage: setup.sh [--profile profile1|profile2] [--dry-run] [--no-brew]

Profiles:
  profile1  shared workstation setup plus profile1 extension layer
  profile2  shared workstation setup plus profile2 extension layer
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
        --profile)
            if [ "$#" -lt 2 ]; then
                dot_progress_fail "--profile requires a value"
                exit 2
            fi
            CLI_DOT_PROFILE="${2:-}"
            shift 2
            ;;
        --profile=*)
            CLI_DOT_PROFILE="${1#--profile=}"
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

capture_process_env() {
    local var
    for var in "${DOT_KNOWN_ENV_VARS[@]}"; do
        eval "DOT_PROCESS_HAS_$var=\"\${$var+x}\""
        eval "DOT_PROCESS_VAL_$var=\"\${$var-}\""
    done
}

restore_process_env() {
    local var has value
    for var in "${DOT_KNOWN_ENV_VARS[@]}"; do
        has="$(eval "printf '%s' \"\$DOT_PROCESS_HAS_$var\"")"
        if [ -n "$has" ]; then
            value="$(eval "printf '%s' \"\$DOT_PROCESS_VAL_$var\"")"
            printf -v "$var" '%s' "$value"
            export "${var?}"
        fi
    done
}

load_env_file() {
    local path="$1"
    [ -f "$path" ] || return 0
    # shellcheck source=/dev/null
    set -a
    source "$path"
    set +a
    dot_progress_info "Loaded env: $path"
}

capture_process_env
load_env_file "$HOME/.config/dot/local.env"
load_env_file "$DOTFILES_DIR/profiles/local.env"
restore_process_env

if [ -n "$CLI_DOT_PROFILE" ]; then
    DOT_PROFILE="$CLI_DOT_PROFILE"
fi

DOT_PROFILE="${DOT_PROFILE:-profile1}"
case "$DOT_PROFILE" in
    profile1 | profile2) ;;
    *)
        dot_progress_fail "Unsupported profile: $DOT_PROFILE"
        exit 2
        ;;
esac

dot_default() {
    local name="$1"
    local value="$2"
    if [ -z "${!name+x}" ]; then
        printf -v "$name" '%s' "$value"
        export "${name?}"
    fi
}

case "$DOT_PROFILE" in
    profile1)
        DOT_BREWFILES=("homebrew/Brewfile.base" "homebrew/Brewfile.profile1")
        dot_default DOT_ENABLE_DIA 1
        dot_default DOT_ENABLE_ONEPASSWORD 1
        dot_default DOT_ENABLE_SYSTEM_EXTENSIONS 1
        ;;
    profile2)
        DOT_BREWFILES=("homebrew/Brewfile.base" "homebrew/Brewfile.profile2")
        dot_default DOT_ENABLE_DIA 1
        dot_default DOT_ENABLE_ONEPASSWORD 1
        dot_default DOT_ENABLE_SYSTEM_EXTENSIONS 1
        ;;
esac

dot_default DOT_ENABLE_CODEX_CONFIG 1

DOT_ENABLE_DIA="${DOT_ENABLE_DIA:-0}"
DOT_ENABLE_ONEPASSWORD="${DOT_ENABLE_ONEPASSWORD:-0}"
DOT_ENABLE_SYSTEM_EXTENSIONS="${DOT_ENABLE_SYSTEM_EXTENSIONS:-0}"
DOT_ENABLE_CODEX_CONFIG="${DOT_ENABLE_CODEX_CONFIG:-1}"

if [ -n "${DOT_TOOLS_HOME:-}" ] && [ -z "${TOOLS_HOME:-}" ]; then
    TOOLS_HOME="$DOT_TOOLS_HOME"
    export TOOLS_HOME
fi

TOOLS_HOME="${TOOLS_HOME:-$HOME/.tools}"
DOT_SKILL_ROOTS_STATE="${DOT_SKILL_ROOTS_STATE:-$HOME/.config/dot/extra-skill-roots}"
DOT_RUN_ID="${DOT_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
DOT_BACKUP_DIR="${DOT_BACKUP_DIR:-$HOME/.dotfiles-backups/$DOT_RUN_ID}"
DOT_BACKUP_MANIFEST="$DOT_BACKUP_DIR/manifest.tsv"

dot_truthy() {
    [ "${1:-0}" = "1" ]
}

dot_dry_run() {
    [ "$DRY_RUN" = true ]
}

dot_apply() {
    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "$*"
        return 0
    fi

    "$@"
}

dot_manifest_append() {
    local action="$1"
    local src="$2"
    local dest="$3"
    local backup="${4:-}"

    dot_dry_run && return 0
    mkdir -p "$DOT_BACKUP_DIR"
    if [ ! -f "$DOT_BACKUP_MANIFEST" ]; then
        printf 'action\tsource\tdestination\tbackup\n' >"$DOT_BACKUP_MANIFEST"
    fi
    printf '%s\t%s\t%s\t%s\n' "$action" "$src" "$dest" "$backup" >>"$DOT_BACKUP_MANIFEST"
}

install_homebrew() {
    local installer
    installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return $?
    /bin/bash -c "$installer"
}

install_brewfile() {
    local file="$1"
    if [ ! -f "$file" ]; then
        dot_progress_skip "Homebrew layer not found: $file"
        return 0
    fi

    if brew bundle check --no-upgrade --file="$file" >/dev/null; then
        dot_progress_ok "Homebrew layer satisfied: ${file#"$DOTFILES_DIR"/}"
        return 0
    fi

    dot_progress_run_step --stream "Installing ${file#"$DOTFILES_DIR"/}" brew bundle install --no-upgrade --file="$file"
}

# Function to create symlink with backup and verification
link_file() {
    local src="$1"
    local dest="$2"
    local backup
    local rel

    # Skip if source doesn't exist
    if [ ! -e "$src" ]; then
        dot_progress_skip "Source not found: $src"
        return 0
    fi

    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$src" ]; then
            dot_progress_ok "Already linked: $dest"
            return 0
        fi

        dot_apply rm "$dest"
        dot_manifest_append "remove-symlink" "$src" "$dest"
    elif [ -e "$dest" ]; then
        rel="${dest#/}"
        backup="$DOT_BACKUP_DIR/$rel"
        dot_progress_status "BACKUP" "$DOT_PROGRESS_YELLOW" "$dest -> $backup"
        dot_apply mkdir -p "$(dirname "$backup")"
        dot_apply mv "$dest" "$backup"
        dot_manifest_append "backup" "$src" "$dest" "$backup"
    fi

    dot_apply mkdir -p "$(dirname "$dest")"
    dot_apply ln -s "$src" "$dest"
    dot_manifest_append "link" "$src" "$dest"

    # Verify symlink was created correctly
    if dot_dry_run; then
        dot_progress_status "LINK" "$DOT_PROGRESS_BLUE" "$(basename "$src") -> $dest"
        return 0
    fi

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        dot_progress_status "LINK" "$DOT_PROGRESS_BLUE" "$(basename "$src") -> $dest"
    else
        dot_progress_fail "Failed to create symlink: $dest"
        return 1
    fi
}

# Merge skills from multiple source directories into a single target.
# Creates target as real directory; symlinks each valid skill subdirectory.
# Skips sources that don't exist.
#
# Usage: link_skills <target_dir> <source_dir> [<source_dir>...]
link_skills() {
    local target="$1"
    shift
    local existing target_path
    local source_dir

    dot_apply mkdir -p "$target"

    for existing in "$target"/*; do
        [ -L "$existing" ] || continue
        [ -e "$existing" ] && continue
        target_path="$(readlink "$existing" 2>/dev/null || true)"

        local owned_by_active_source=0
        for source_dir in "$@"; do
            case "$target_path" in
                "$source_dir" | "$source_dir"/*)
                    owned_by_active_source=1
                    break
                    ;;
            esac
        done
        [ "$owned_by_active_source" -eq 1 ] || continue

        dot_progress_status "REMOVE" "$DOT_PROGRESS_YELLOW" "$existing"
        dot_apply rm "$existing"
        dot_manifest_append "remove-broken-skill" "$target_path" "$existing"
    done

    for src_dir in "$@"; do
        if [ ! -d "$src_dir" ]; then
            dot_progress_skip "Skills source not found: $src_dir"
            continue
        fi

        for skill in "$src_dir"/*/; do
            [ -d "$skill" ] || continue
            local name
            name="$(basename "$skill")"
            [[ "$name" == .* ]] && continue

            # Only link directories containing SKILL.md
            [ -f "$skill/SKILL.md" ] || continue

            link_file "${skill%/}" "$target/$name"
        done
    done
}

remove_inactive_extra_skill_links() {
    local target="$1"
    shift
    local -a known_sources=("$@")
    local -a active_sources=("${ACTIVE_EXTRA_SKILL_SOURCES[@]}")
    local link target_path
    local action configured known source

    [ -d "$target" ] || return 0

    for link in "$target"/*; do
        [ -L "$link" ] || continue
        target_path="$(readlink "$link")"
        configured=0
        known=0

        for source in "$SKILLS_BASE" "${active_sources[@]}"; do
            [ -n "$source" ] || continue
            case "$target_path" in
                "$source" | "$source"/*)
                    configured=1
                    break
                    ;;
            esac
        done
        [ "$configured" -eq 0 ] || continue

        for source in "${known_sources[@]}"; do
            case "$target_path" in
                "$source" | "$source"/*)
                    known=1
                    break
                    ;;
            esac
        done

        if [ "$known" -eq 1 ]; then
            action="remove-inactive-extra-skill"
        else
            action="remove-unconfigured-skill"
        fi

        dot_progress_status "REMOVE" "$DOT_PROGRESS_YELLOW" "$link"
        dot_apply rm "$link"
        dot_manifest_append "$action" "$target_path" "$link"
    done
}

append_active_skill_sources() {
    local list="${1:-}"
    local source old_ifs

    [ -n "$list" ] || return 0

    old_ifs="$IFS"
    IFS=':'
    for source in $list; do
        [ -n "$source" ] || continue
        ACTIVE_EXTRA_SKILL_SOURCES+=("$source")
    done
    IFS="$old_ifs"
}

append_known_skill_sources() {
    local list="${1:-}"
    local source old_ifs

    [ -n "$list" ] || return 0

    old_ifs="$IFS"
    IFS=':'
    for source in $list; do
        [ -n "$source" ] || continue
        KNOWN_EXTRA_SKILL_SOURCES+=("$source")
    done
    IFS="$old_ifs"
}

append_previous_extra_skill_sources() {
    local source

    [ -f "$DOT_SKILL_ROOTS_STATE" ] || return 0

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        KNOWN_EXTRA_SKILL_SOURCES+=("$source")
    done <"$DOT_SKILL_ROOTS_STATE"
}

write_extra_skill_sources_state() {
    local source

    dot_dry_run && return 0

    mkdir -p "$(dirname "$DOT_SKILL_ROOTS_STATE")"
    : >"$DOT_SKILL_ROOTS_STATE"
    for source in "${VALID_EXTRA_SKILL_SOURCES[@]}"; do
        printf '%s\n' "$source" >>"$DOT_SKILL_ROOTS_STATE"
    done
}

dia_cdp_url() {
    printf 'http://127.0.0.1:%s/json/version\n' "$AGENT_BROWSER_DIA_PORT"
}

dia_launch_agent_domain() {
    printf 'gui/%s\n' "$UID"
}

dia_launch_agent_service() {
    printf '%s/%s\n' "$(dia_launch_agent_domain)" "$AGENT_BROWSER_DIA_LAUNCH_AGENT"
}

dia_cdp_healthy() {
    curl -fsS "$(dia_cdp_url)" >/dev/null 2>&1
}

wait_for_dia_cdp() {
    local tries="${1:-40}"
    local i

    for ((i = 0; i < tries; i++)); do
        if dia_cdp_healthy; then
            return 0
        fi
        sleep 0.25
    done

    return 1
}

dia_main_commands() {
    ps -axo command= | awk '/\/Applications\/Dia.app\/Contents\/MacOS\/Dia( |$)/ { print }'
}

dia_running_without_cdp() {
    local commands
    commands="$(dia_main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1 && return 1
    return 0
}

dia_running_with_cdp() {
    local commands
    commands="$(dia_main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1
}

dia_gui_domain_available() {
    launchctl print "$(dia_launch_agent_domain)" >/dev/null 2>&1
}

dia_launch_agent_loaded() {
    launchctl print "$(dia_launch_agent_service)" >/dev/null 2>&1
}

setup_dia_cdp() {
    local plist_path
    local domain_target
    local service_target

    plist_path="$HOME/Library/LaunchAgents/${AGENT_BROWSER_DIA_LAUNCH_AGENT}.plist"
    domain_target="$(dia_launch_agent_domain)"
    service_target="$(dia_launch_agent_service)"

    if dot_dry_run; then
        dot_progress_skip "Dia CDP startup (--dry-run)"
        return 0
    fi

    if [ ! -f "$plist_path" ]; then
        dot_progress_skip "Dia LaunchAgent not linked: $plist_path"
        return 0
    fi

    if [ ! -x "$AGENT_BROWSER_DIA_BIN" ]; then
        dot_progress_skip "Dia.app not found: $AGENT_BROWSER_DIA_APP"
        return 0
    fi

    if ! command -v launchctl >/dev/null 2>&1; then
        dot_progress_skip "launchctl not available"
        return 0
    fi

    if ! dia_gui_domain_available; then
        dot_progress_skip "GUI launchctl domain unavailable: $domain_target"
        return 0
    fi

    if dia_cdp_healthy; then
        dot_progress_ok "Dia CDP already available on port $AGENT_BROWSER_DIA_PORT"
        return 0
    fi

    if dia_running_without_cdp; then
        dot_progress_skip "Dia is already running without CDP. Quit Dia, then run agent-browser-dia-on or rerun setup."
        return 0
    fi

    if dia_running_with_cdp; then
        if wait_for_dia_cdp 20; then
            dot_progress_ok "Dia CDP became healthy on port $AGENT_BROWSER_DIA_PORT"
        else
            dot_progress_skip "Dia is already running with a CDP flag, but port $AGENT_BROWSER_DIA_PORT is not healthy yet."
        fi
        return 0
    fi

    dot_progress_run "Starting Dia CDP LaunchAgent"
    if dia_launch_agent_loaded; then
        launchctl kickstart -k "$service_target"
    else
        launchctl bootstrap "$domain_target" "$plist_path"
    fi

    if wait_for_dia_cdp; then
        dot_progress_ok "Dia CDP ready on port $AGENT_BROWSER_DIA_PORT"
    else
        dot_progress_warn "Dia LaunchAgent loaded, but CDP did not become healthy on port $AGENT_BROWSER_DIA_PORT"
    fi
}

dot_progress_title "Dotfiles setup"
dot_progress_info "Directory: $DOTFILES_DIR"
dot_progress_info "Profile: $DOT_PROFILE"
dot_progress_info "Backup dir: $DOT_BACKUP_DIR"

if dot_dry_run; then
    dot_progress_info "Mode: dry-run"
fi

dot_progress_info "Homebrew layers:"
for brewfile in "${DOT_BREWFILES[@]}"; do
    dot_progress_info "  - $brewfile"
done

# Full setup: Install Homebrew and packages
if [ "$NO_BREW" = true ]; then
    dot_progress_skip "Homebrew packages (--no-brew)"
elif dot_dry_run; then
    dot_progress_skip "Homebrew packages (--dry-run)"
else
    # Check prerequisites
    if ! command -v brew >/dev/null 2>&1; then
        dot_progress_run_step --stream "Installing Homebrew" install_homebrew

        # Add Homebrew to PATH for this session
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        dot_progress_ok "Homebrew available"
    fi

    for brewfile in "${DOT_BREWFILES[@]}"; do
        install_brewfile "$DOTFILES_DIR/$brewfile"
    done
fi

# Create tool home directory
if dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "mkdir -p $TOOLS_HOME"
else
    dot_progress_run_step "Creating tool home" mkdir -p "$TOOLS_HOME"
fi

# Shell configs
dot_progress_section "Shell configurations"
link_file "$DOTFILES_DIR/shell/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/shell/zprofile" "$HOME/.zprofile"
if [ -f "$HOME/.zshrc.local" ]; then
    dot_progress_skip "Local shell overrides already exist: $HOME/.zshrc.local"
elif dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp shell/zshrc.local.example $HOME/.zshrc.local"
else
    cp "$DOTFILES_DIR/shell/zshrc.local.example" "$HOME/.zshrc.local"
    dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "zshrc.local.example -> $HOME/.zshrc.local"
fi

# Terminal configs
dot_progress_section "Terminal configurations"
link_file "$DOTFILES_DIR/terminal/starship-dark.toml" "$HOME/.config/starship/starship-dark.toml"
link_file "$DOTFILES_DIR/terminal/starship-light.toml" "$HOME/.config/starship/starship-light.toml"
link_file "$DOTFILES_DIR/terminal/bottom.toml" "$HOME/.config/bottom/bottom.toml"
link_file "$DOTFILES_DIR/terminal/atuin.toml" "$HOME/.config/atuin/config.toml"
link_file "$DOTFILES_DIR/terminal/bat" "$HOME/.config/bat/config"
link_file "$DOTFILES_DIR/terminal/ignore" "$HOME/.ignore"
link_file "$DOTFILES_DIR/terminal/bin/buf" "$HOME/.local/bin/buf"
link_file "$DOTFILES_DIR/terminal/bin/cho" "$HOME/.local/bin/cho"
link_file "$DOTFILES_DIR/terminal/bin/delta-themed" "$HOME/.local/bin/delta-themed"
link_file "$DOTFILES_DIR/terminal/bin/fin" "$HOME/.local/bin/fin"
link_file "$DOTFILES_DIR/terminal/bin/grn" "$HOME/.local/bin/grn"
link_file "$DOTFILES_DIR/terminal/bin/let" "$HOME/.local/bin/let"
link_file "$DOTFILES_DIR/terminal/bin/pdf" "$HOME/.local/bin/pdf"
link_file "$DOTFILES_DIR/terminal/bin/tao" "$HOME/.local/bin/tao"

link_file "$DOTFILES_DIR/biome.json" "$HOME/.config/biome/biome.json"
link_file "$DOTFILES_DIR/tsconfig.json" "$HOME/.config/typescript/tsconfig.json"
link_file "$DOTFILES_DIR/bunfig.toml" "$HOME/.bunfig.toml"
link_file "$DOTFILES_DIR/uv.toml" "$HOME/.config/uv/uv.toml"

dot_progress_section "Editor configurations"
link_file "$DOTFILES_DIR/editor/settings.json" "$HOME/.config/zed/settings.json"
link_file "$DOTFILES_DIR/editor/keymap.json" "$HOME/.config/zed/keymap.json"

dot_progress_section "Additional terminal configurations"
link_file "$DOTFILES_DIR/terminal/ssh" "$HOME/.ssh/config"
link_file "$DOTFILES_DIR/terminal/neofetch" "$HOME/.config/neofetch/config.conf"
link_file "$DOTFILES_DIR/terminal/statusline" "$HOME/.config/ccstatusline/settings.json"
link_file "$DOTFILES_DIR/terminal/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link_file "$DOTFILES_DIR/terminal/yt-dlp" "$HOME/.config/yt-dlp/config"
link_file "$DOTFILES_DIR/terminal/agent-browser.json" "$HOME/.agent-browser/config.json"
link_file "$DOTFILES_DIR/terminal/agent-browser.chrome.json" "$HOME/.agent-browser/chrome.json"

dot_progress_section "System configurations"
link_file "$DOTFILES_DIR/system/gitconfig" "$HOME/.gitconfig"
if dot_truthy "$DOT_ENABLE_SYSTEM_EXTENSIONS"; then
    link_file "$DOTFILES_DIR/system/karabiner" "$HOME/.config/karabiner/karabiner.json"
    link_file "$DOTFILES_DIR/macos/.macos" "$HOME/.macos"
else
    dot_progress_skip "System extension configs (DOT_ENABLE_SYSTEM_EXTENSIONS!=1)"
fi

if dot_truthy "$DOT_ENABLE_ONEPASSWORD"; then
    link_file "$DOTFILES_DIR/system/1password" "$HOME/.config/1Password/ssh/agent.toml"
else
    dot_progress_skip "1Password SSH agent config (DOT_ENABLE_ONEPASSWORD!=1)"
fi

if dot_truthy "$DOT_ENABLE_DIA"; then
    link_file "$DOTFILES_DIR/system/launchagents/com.u29dc.dia-cdp.plist" "$HOME/Library/LaunchAgents/com.u29dc.dia-cdp.plist"
    setup_dia_cdp
else
    dot_progress_skip "Dia CDP LaunchAgent (DOT_ENABLE_DIA!=1)"
fi

# Agent configurations
dot_progress_section "Agent configurations"
# Claude Code
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link_file "$DOTFILES_DIR/agents/claude.json" "$HOME/.claude/settings.json"
SKILLS_BASE="${SKILLS_BASE:-$DOTFILES_DIR/agents/skills}"
ACTIVE_EXTRA_SKILL_SOURCES=()
VALID_EXTRA_SKILL_SOURCES=()
KNOWN_EXTRA_SKILL_SOURCES=()
append_previous_extra_skill_sources
append_known_skill_sources "${DOT_SKILLS_PROFILE1:-}"
append_known_skill_sources "${DOT_SKILLS_PROFILE2:-}"
case "$DOT_PROFILE" in
    profile1) append_active_skill_sources "${DOT_SKILLS_PROFILE1:-}" ;;
    profile2) append_active_skill_sources "${DOT_SKILLS_PROFILE2:-}" ;;
esac

for source in "${ACTIVE_EXTRA_SKILL_SOURCES[@]}"; do
    if [ -d "$source" ]; then
        dot_progress_info "Extra skills: $source"
        VALID_EXTRA_SKILL_SOURCES+=("$source")
    else
        dot_progress_skip "Extra skills source not found: $source"
    fi
done

remove_inactive_extra_skill_links "$HOME/.claude/skills" "${KNOWN_EXTRA_SKILL_SOURCES[@]}"
remove_inactive_extra_skill_links "$HOME/.codex/skills" "${KNOWN_EXTRA_SKILL_SOURCES[@]}"
remove_inactive_extra_skill_links "$HOME/.agents/skills" "${KNOWN_EXTRA_SKILL_SOURCES[@]}"
write_extra_skill_sources_state

link_skills "$HOME/.claude/skills" "$SKILLS_BASE" "${VALID_EXTRA_SKILL_SOURCES[@]}"
# Codex CLI
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
if dot_truthy "$DOT_ENABLE_CODEX_CONFIG"; then
    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "scripts/codex.sh --profile $DOT_PROFILE --dest $HOME/.codex/config.toml"
    else
        DOT_BACKUP_DIR="$DOT_BACKUP_DIR" DOT_BACKUP_MANIFEST="$DOT_BACKUP_MANIFEST" TOOLS_HOME="$TOOLS_HOME" "$DOTFILES_DIR/scripts/codex.sh" --profile "$DOT_PROFILE" --dest "$HOME/.codex/config.toml"
    fi
else
    dot_progress_skip "Codex config generation (DOT_ENABLE_CODEX_CONFIG!=1)"
fi
link_skills "$HOME/.codex/skills" "$SKILLS_BASE" "${VALID_EXTRA_SKILL_SOURCES[@]}"
link_skills "$HOME/.agents/skills" "$SKILLS_BASE" "${VALID_EXTRA_SKILL_SOURCES[@]}"

dot_progress_ok "Symlinks created successfully"

dot_progress_ok "Setup complete"
dot_progress_info "Restart terminal or run: source ~/.zshrc"
