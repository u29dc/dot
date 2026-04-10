#!/usr/bin/env bash
set -e

# ==============================================================================
# DOTFILES SETUP
# ==============================================================================
#
# NEW MACHINE SETUP
# -----------------
# On a fresh macOS install, run these commands:
#
#   # 1. Install Xcode CLI tools (provides git, compilers)
#   xcode-select --install
#
#   # 2. Clone dotfiles (git is now available from step 1)
#   git clone https://github.com/u29dc/dot.git ~/Git/dot
#
#   # 3. Run setup (auto-installs Homebrew if missing, then all packages + symlinks)
#   bash ~/Git/dot/scripts/setup.sh
#
#   # 4. Reload shell
#   source ~/.zshrc
#
#   # 5. Configure local secrets (API keys, machine-specific settings)
#   cp ~/Git/dot/shell/zshrc.local.example ~/.zshrc.local
#   # Edit ~/.zshrc.local to add your keys
#
#   # 6. Log in to AI coding agents
#   claude login
#   codex login
#   amp login
#
#   # 7. (Optional) Apply macOS system preferences
#   ~/.macos
#
# ==============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_BROWSER_DIA_PORT="${AGENT_BROWSER_DIA_PORT:-9222}"
AGENT_BROWSER_DIA_APP="/Applications/Dia.app"
AGENT_BROWSER_DIA_BIN="$AGENT_BROWSER_DIA_APP/Contents/MacOS/Dia"
AGENT_BROWSER_DIA_LAUNCH_AGENT="com.u29dc.dia-cdp"

# Parse command line arguments
LINK_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --link-only) LINK_ONLY=true ;;
    esac
done

# Function to create symlink with backup and verification
link_file() {
    local src="$1"
    local dest="$2"

    # Skip if source doesn't exist
    if [ ! -e "$src" ]; then
        echo "[SKIP] Source not found: $src"
        return 0
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"

    # Backup existing file if it exists and isn't a symlink
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "[BACKUP] $dest -> ${dest}.backup"
        mv "$dest" "${dest}.backup"
    fi

    # Remove existing symlink if it exists
    if [ -L "$dest" ]; then
        rm "$dest"
    fi

    # Create new symlink
    ln -s "$src" "$dest"

    # Verify symlink was created correctly
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        echo "[LINK] $(basename "$src") -> $dest"
    else
        echo "[ERROR] Failed to create symlink: $dest"
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

    mkdir -p "$target"

    for src_dir in "$@"; do
        if [ ! -d "$src_dir" ]; then
            echo "[SKIP] Skills source not found: $src_dir"
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

    if [ ! -f "$plist_path" ]; then
        echo "[SKIP] Dia LaunchAgent not linked: $plist_path"
        return 0
    fi

    if [ ! -x "$AGENT_BROWSER_DIA_BIN" ]; then
        echo "[SKIP] Dia.app not found: $AGENT_BROWSER_DIA_APP"
        return 0
    fi

    if ! command -v launchctl >/dev/null 2>&1; then
        echo "[SKIP] launchctl not available"
        return 0
    fi

    if ! dia_gui_domain_available; then
        echo "[SKIP] GUI launchctl domain unavailable: $domain_target"
        return 0
    fi

    if dia_cdp_healthy; then
        echo "[OK] Dia CDP already available on port $AGENT_BROWSER_DIA_PORT"
        return 0
    fi

    if dia_running_without_cdp; then
        echo "[SKIP] Dia is already running without CDP. Quit Dia, then run agent-browser-dia-on or rerun setup."
        return 0
    fi

    if dia_running_with_cdp; then
        if wait_for_dia_cdp 20; then
            echo "[OK] Dia CDP became healthy on port $AGENT_BROWSER_DIA_PORT"
        else
            echo "[SKIP] Dia is already running with a CDP flag, but port $AGENT_BROWSER_DIA_PORT is not healthy yet."
        fi
        return 0
    fi

    echo "Dia browser CDP:"
    if dia_launch_agent_loaded; then
        launchctl kickstart -k "$service_target"
    else
        launchctl bootstrap "$domain_target" "$plist_path"
    fi

    if wait_for_dia_cdp; then
        echo "[OK] Dia CDP ready on port $AGENT_BROWSER_DIA_PORT"
    else
        echo "[WARN] Dia LaunchAgent loaded, but CDP did not become healthy on port $AGENT_BROWSER_DIA_PORT"
    fi
}

# Full setup: Install Homebrew and packages
if [ "$LINK_ONLY" = false ]; then
    echo "Starting dotfiles setup..."
    echo "Directory: $DOTFILES_DIR"
    echo

    # Check prerequisites
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Install Homebrew packages
    if [ -f "$DOTFILES_DIR/homebrew/Brewfile" ]; then
        echo "Installing Homebrew packages..."
        brew bundle install --file="$DOTFILES_DIR/homebrew/Brewfile"
        echo
    else
        echo "Brewfile not found, skipping Homebrew packages"
        echo
    fi
fi

# Create tool home directory
mkdir -p "${TOOLS_HOME:-$HOME/.tools}"

# Create symlinks (runs for both full setup and link-only mode)
echo "Creating symlinks..."
echo

# Shell configs
echo "Shell configurations:"
link_file "$DOTFILES_DIR/shell/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/shell/zprofile" "$HOME/.zprofile"
link_file "$DOTFILES_DIR/shell/zshrc.local" "$HOME/.zshrc.local"

# Terminal configs
echo
echo "Terminal configurations:"
link_file "$DOTFILES_DIR/terminal/starship-dark.toml" "$HOME/.config/starship/starship-dark.toml"
link_file "$DOTFILES_DIR/terminal/starship-light.toml" "$HOME/.config/starship/starship-light.toml"
link_file "$DOTFILES_DIR/terminal/bottom.toml" "$HOME/.config/bottom/bottom.toml"
link_file "$DOTFILES_DIR/terminal/atuin.toml" "$HOME/.config/atuin/config.toml"
link_file "$DOTFILES_DIR/terminal/bat" "$HOME/.config/bat/config"
link_file "$DOTFILES_DIR/terminal/ignore" "$HOME/.ignore"

link_file "$DOTFILES_DIR/biome.json" "$HOME/.config/biome/biome.json"
link_file "$DOTFILES_DIR/tsconfig.json" "$HOME/.config/typescript/tsconfig.json"
link_file "$DOTFILES_DIR/bunfig.toml" "$HOME/.bunfig.toml"
link_file "$DOTFILES_DIR/uv.toml" "$HOME/.config/uv/uv.toml"

echo
echo "Editor configurations:"
link_file "$DOTFILES_DIR/editor/settings.json" "$HOME/.config/zed/settings.json"
link_file "$DOTFILES_DIR/editor/keymap.json" "$HOME/.config/zed/keymap.json"

echo
echo "Additional terminal configurations:"
link_file "$DOTFILES_DIR/terminal/ssh" "$HOME/.ssh/config"
link_file "$DOTFILES_DIR/terminal/neofetch" "$HOME/.config/neofetch/config.conf"
link_file "$DOTFILES_DIR/terminal/statusline" "$HOME/.config/ccstatusline/settings.json"
link_file "$DOTFILES_DIR/terminal/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link_file "$DOTFILES_DIR/terminal/yt-dlp" "$HOME/.config/yt-dlp/config"
link_file "$DOTFILES_DIR/terminal/agent-browser.json" "$HOME/.agent-browser/config.json"
link_file "$DOTFILES_DIR/terminal/agent-browser.chrome.json" "$HOME/.agent-browser/chrome.json"

echo
echo "System configurations:"
link_file "$DOTFILES_DIR/system/gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/system/karabiner" "$HOME/.config/karabiner/karabiner.json"
link_file "$DOTFILES_DIR/system/1password" "$HOME/.config/1Password/ssh/agent.toml"
link_file "$DOTFILES_DIR/system/launchagents/com.u29dc.dia-cdp.plist" "$HOME/Library/LaunchAgents/com.u29dc.dia-cdp.plist"
link_file "$DOTFILES_DIR/macos/.macos" "$HOME/.macos"
setup_dia_cdp

# Agent configurations
echo
echo "Agent configurations:"
# Claude Code
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link_file "$DOTFILES_DIR/agents/claude.json" "$HOME/.claude/settings.json"
SKILLS_BASE="${SKILLS_BASE:-$DOTFILES_DIR/agents/skills}"
link_skills "$HOME/.claude/skills" "$SKILLS_BASE" ${SKILLS_U29DC:+"$SKILLS_U29DC"}
# Codex CLI
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
link_file "$DOTFILES_DIR/agents/codex.toml" "$HOME/.codex/config.toml"
link_skills "$HOME/.codex/skills" "$SKILLS_BASE" ${SKILLS_U29DC:+"$SKILLS_U29DC"}
link_skills "$HOME/.agents/skills" "$SKILLS_BASE" ${SKILLS_U29DC:+"$SKILLS_U29DC"}
# AMP CLI
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.config/amp/AGENTS.md"
link_file "$DOTFILES_DIR/agents/amp.settings.json" "$HOME/.config/amp/settings.json"

echo
echo "Symlinks created successfully."

if [ "$LINK_ONLY" = false ]; then
    echo
    echo "Setup complete."
    echo "Restart terminal or run: source ~/.zshrc"
fi
