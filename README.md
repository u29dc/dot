# dot

## Quick Start

```bash
# Clone and setup
git clone git@github.com:u29dc/dot.git ~/Git/dot
cd ~/Git/dot
bun install     # Install dependencies (formatter, linter, git hooks)

# Note: This will install 70+ packages including GUI applications
bun run setup   # Setup Homebrew packages & create symlinks
```

## Commands

```bash
bun run setup              # Setup Homebrew packages & create all symlinks
bun run setup:link         # Create symlinks only
bun run util:format        # Format all config files
bun run util:lint          # Check formatting
bun run util:lint:shell    # Lint shell scripts
bun run util:format:shell  # Format shell scripts
bun run util:check         # Run all linting checks
```

## Directory Structure

```
dot/
├── agents/                   # AI coding assistant configurations
│   ├── commands/             # Self-contained commands (clean/execute/plan/research/review/troubleshoot/commit/pr)
│   ├── AGENTS.md             # Main AI agent manifesto
│   ├── claude.json           # Claude Code settings
│   ├── amp.settings.json     # AMP CLI settings
│   └── codex.toml            # Codex AI configuration
├── shell/                    # Shell configurations
│   ├── functions/            # Extracted shell functions
│   ├── zshrc                 # Zsh configuration
│   ├── zshrc.local.example   # Template for local secrets
│   └── ...                   # Profile files
├── editor/                   # Editor settings (Zed)
├── terminal/                 # Terminal and CLI tools
├── system/                   # System configurations (git, karabiner, 1password)
├── homebrew/                 # Homebrew packages and casks
└── scripts/                  # Setup and utility scripts
```

## Agent Configurations

The `agents/` directory contains configurations for AI coding assistants:

| File                | Description                                                                         | Usage                                                                                              |
| ------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `AGENTS.md`         | Main AI agent manifesto and guidelines                                              | Linked to `~/.claude/CLAUDE.md` and `~/.config/amp/AGENTS.md`                                      |
| `claude.json`       | Claude Code settings with modern tool permissions                                   | Linked to `~/.claude/settings.json`                                                                |
| `amp.settings.json` | AMP CLI settings and permissions                                                    | Linked to `~/.config/amp/settings.json`                                                            |
| `commands/`         | Self-contained commands (clean/execute/plan/research/review/troubleshoot/commit/pr) | Linked to `~/.claude/agents`, `~/.claude/commands`, `~/.codex/commands`, `~/.config/amp/commands/` |
| `codex.toml`        | Codex AI configuration and model settings                                           | Linked to `~/.config/codex.toml`                                                                   |

These configurations promote modern CLI tools (eza, bat, fd, rg, etc.) and include comprehensive development guidelines.

## Configuration Mappings

| Config       | Source                     | Destination                                                                             |
| ------------ | -------------------------- | --------------------------------------------------------------------------------------- |
| **Shell**    |                            |                                                                                         |
| Zsh          | `shell/zshrc`              | `~/.zshrc`                                                                              |
| Zsh Profile  | `shell/zprofile`           | `~/.zprofile`                                                                           |
| **Editor**   |                            |                                                                                         |
| Zed Settings | `editor/settings.json`     | `~/.config/zed/settings.json`                                                           |
| Zed Keymap   | `editor/keymap.json`       | `~/.config/zed/keymap.json`                                                             |
| **Terminal** |                            |                                                                                         |
| SSH          | `terminal/ssh`             | `~/.ssh/config`                                                                         |
| Neofetch     | `terminal/neofetch`        | `~/.config/neofetch/config.conf`                                                        |
| Statusline   | `terminal/statusline`      | `~/.config/ccstatusline/settings.json`                                                  |
| Starship     | `terminal/starship.toml`   | `~/.config/starship/starship.toml`                                                      |
| Bottom       | `terminal/bottom.toml`     | `~/.config/bottom/bottom.toml`                                                          |
| Atuin        | `terminal/atuin.toml`      | `~/.config/atuin/config.toml`                                                           |
| Ghostty      | `terminal/ghostty`         | `~/Library/Application Support/com.mitchellh.ghostty/config`                            |
| Bat          | `terminal/bat`             | `~/.config/bat/config`                                                                  |
| Biome        | `biome.json`               | `~/.config/biome/biome.json`                                                            |
| **System**   |                            |                                                                                         |
| Git          | `system/gitconfig`         | `~/.gitconfig`                                                                          |
| Karabiner    | `system/karabiner`         | `~/.config/karabiner/karabiner.json`                                                    |
| 1Password    | `system/1password`         | `~/.config/1Password/ssh/agent.toml`                                                    |
| macOS        | `macos/.macos`             | `~/.macos`                                                                              |
| **Agents**   |                            |                                                                                         |
| AI Manifesto | `agents/AGENTS.md`         | `~/.claude/CLAUDE.md`, `~/.config/amp/AGENTS.md`                                        |
| Claude Code  | `agents/claude.json`       | `~/.claude/settings.json`                                                               |
| AMP CLI      | `agents/amp.settings.json` | `~/.config/amp/settings.json`                                                           |
| Codex        | `agents/codex.toml`        | `~/.config/codex.toml`                                                                  |
| Commands     | `agents/commands`          | `~/.claude/agents`, `~/.claude/commands`, `~/.codex/commands`, `~/.config/amp/commands` |

## Installed Applications

The Homebrew bundle (`homebrew/Brewfile`) includes:

### Command-Line Tools

- **Development**: Git, GitHub CLI, Node.js, Bun, Deno, Rust, Zig, Neovim
- **Modern CLI Tools**: eza (ls), bat (cat), fd (find), bottom (htop), zoxide (cd), ripgrep, sd (sed), dust (du), procs (ps)
- **Git Enhancements**: git-delta, gitui, lazygit, git-open
- **Shell Tools**: Starship prompt, Atuin history, Broot file navigation
- **AI Tools**: codex, gemini-cli
- **Media Processing**: ffmpeg, ImageMagick, yt-dlp, gifsicle, sox, webp, openexr
- **Development Utilities**: jq, yq, just, direnv, shellcheck, shfmt, tldr
- **Utilities**: hyperfine, neofetch, pipx, scc, wget, gitingest, blueutil, gnupg, poppler
- **Cloud & Services**: stripe, supabase

### GUI Applications

- **Productivity**: 1Password, Notion suite, Raycast, Cursor, Ollama
- **Development**: Zed (preview), Ghostty terminal, CotEditor
- **Media & Design**: IINA, Figma, CleanShot, Clop
- **System Utilities**: CleanMyMac, Karabiner Elements, MonitorControl, Keka, Ice, Leader Key, Transmission
- **Communication**: WhatsApp, Zoom, Lark
- **Cloud Storage**: Google Drive, Dropbox, Backblaze
- **Security**: AdGuard

See `homebrew/Brewfile` for the complete list with descriptions.

## Shell Functions and Aliases

### Functions

Custom functions available in zsh:

- `upd` - Update all Homebrew packages with progress tracking and detailed output
- `zed` - Open Zed editor (defaults to current directory)
- `eza` - Wrapper for eza with smart defaults for tree view

### Aliases

Modern CLI tool aliases (replacing traditional commands):

- `ls` → `eza` - Modern ls with git integration and colors
- `ll` → `eza -la` - Detailed list view
- `lt` → `eza --tree` - Tree view
- `tree` → `eza -T` - Tree view alternative
- `cat` → `bat --paging=never` - Syntax highlighting
- `find` → `fd` - Fast file search
- `htop` → `btm` - Modern system monitor
- `top` → `btm` - Modern system monitor

## Manual Setup

### Prerequisites

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Note: Bun will be installed via Homebrew during setup
```

### Manual Installation Steps

```bash
# Clone repository
git clone git@github.com:u29dc/dot.git ~/Git/dot
cd ~/Git/dot

# Install Node.js dependencies
bun install

# Setup all Homebrew packages and create symlinks
./scripts/setup.sh
```

### Local Configuration

For sensitive information like API keys, use the local configuration template:

```bash
# Copy the example template
cp shell/zshrc.local.example shell/zshrc.local

# Edit with your API keys and secrets
# The file is gitignored and won't be committed
```

The `zshrc.local` file is automatically sourced by `zshrc` if it exists, allowing you to keep API keys, tokens, and other sensitive environment variables separate from the version-controlled configuration.

## Notes

- Existing files are backed up with `.backup` extension before creating symlinks
- Git hooks are automatically set up for commit linting and formatting
- Shell configurations are optimized with extracted functions for better maintainability
- The `upd` function provides detailed feedback on which packages are being updated
- All modern CLI tools are configured with sensible defaults
