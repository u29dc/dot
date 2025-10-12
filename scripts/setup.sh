#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Parse command line arguments
LINK_ONLY=false
if [[ "$1" == "--link-only" ]]; then
    LINK_ONLY=true
fi

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

# Create symlinks (runs for both full setup and link-only mode)
echo "Creating symlinks..."
echo

# Shell configs
echo "Shell configurations:"
link_file "$DOTFILES_DIR/shell/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/shell/zprofile" "$HOME/.zprofile"
link_file "$DOTFILES_DIR/shell/zshrc.local" "$HOME/.zshrc.local"

# Editor configs (Zed)
echo
echo "Editor configurations:"
link_file "$DOTFILES_DIR/editor/settings.json" "$HOME/.config/zed/settings.json"
link_file "$DOTFILES_DIR/editor/keymap.json" "$HOME/.config/zed/keymap.json"

# Terminal configs
echo
echo "Terminal configurations:"
link_file "$DOTFILES_DIR/terminal/ssh" "$HOME/.ssh/config"
link_file "$DOTFILES_DIR/terminal/neofetch" "$HOME/.config/neofetch/config.conf"
link_file "$DOTFILES_DIR/terminal/statusline" "$HOME/.config/ccstatusline/settings.json"
link_file "$DOTFILES_DIR/terminal/starship.toml" "$HOME/.config/starship/starship.toml"
link_file "$DOTFILES_DIR/terminal/bottom.toml" "$HOME/.config/bottom/bottom.toml"
link_file "$DOTFILES_DIR/terminal/atuin.toml" "$HOME/.config/atuin/config.toml"
link_file "$DOTFILES_DIR/terminal/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link_file "$DOTFILES_DIR/terminal/bat" "$HOME/.config/bat/config"
link_file "$DOTFILES_DIR/biome.json" "$HOME/.config/biome/biome.json"

# System configs
echo
echo "System configurations:"
link_file "$DOTFILES_DIR/system/gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/system/karabiner" "$HOME/.config/karabiner/karabiner.json"
link_file "$DOTFILES_DIR/system/1password" "$HOME/.config/1Password/ssh/agent.toml"

# Agent configurations
echo
echo "Agent configurations:"
# Claude Code
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link_file "$DOTFILES_DIR/agents/subagents" "$HOME/.claude/agents"
link_file "$DOTFILES_DIR/agents/commands" "$HOME/.claude/commands"
link_file "$DOTFILES_DIR/agents/claude.json" "$HOME/.claude/settings.json"
# Codex CLI
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
link_file "$DOTFILES_DIR/agents/codex.toml" "$HOME/.codex/config.toml"
link_file "$DOTFILES_DIR/agents/subagents" "$HOME/.codex/prompts"

echo
echo "Symlinks created successfully."

if [ "$LINK_ONLY" = false ]; then
    echo
    echo "Setup complete."
    echo "Restart terminal or run: source ~/.zshrc"
fi
