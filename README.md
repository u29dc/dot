## 1. Quick Start

```bash
git clone git@github.com:u29dc/dot.git ~/Git/dot
cd ~/Git/dot
bun install     # Install dependencies (formatter, linter, git hooks)
bun run setup   # Setup Homebrew packages & create symlinks (installs 70+ packages including GUI apps)
```

## 2. Commands

```bash
bun run setup              # Setup Homebrew packages & create all symlinks
bun run setup:link         # Create symlinks only
bun run util:format        # Format all config files
bun run util:lint          # Check formatting
bun run util:lint:shell    # Lint shell scripts
bun run util:format:shell  # Format shell scripts
bun run util:check         # Run all linting checks
```

## 3. Directory Structure

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

## 4. Agent Configurations

| File                | Description                                                                         | Usage                                                                                              |
| ------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `AGENTS.md`         | Main AI agent manifesto and guidelines                                              | Linked to `~/.claude/CLAUDE.md` and `~/.config/amp/AGENTS.md`                                      |
| `claude.json`       | Claude Code settings with modern tool permissions                                   | Linked to `~/.claude/settings.json`                                                                |
| `amp.settings.json` | AMP CLI settings and permissions                                                    | Linked to `~/.config/amp/settings.json`                                                            |
| `commands/`         | Self-contained commands (clean/execute/plan/research/review/troubleshoot/commit/pr) | Linked to `~/.claude/agents`, `~/.claude/commands`, `~/.codex/commands`, `~/.config/amp/commands/` |
| `codex.toml`        | Codex AI configuration and model settings                                           | Linked to `~/.config/codex.toml`                                                                   |

## 5. Configuration Mappings

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

## 6. Applications

- **CLI Development**: Git, GitHub CLI, Node.js, Bun, Deno, Rust, Zig, Neovim
- **CLI Modern Tools**: eza (ls), bat (cat), fd (find), bottom (htop), zoxide (cd), ripgrep, sd (sed), dust (du), procs (ps)
- **CLI Git**: git-delta, gitui, lazygit, git-open
- **CLI Shell**: Starship prompt, Atuin history, Broot file navigation
- **CLI AI**: codex, gemini-cli
- **CLI Media**: ffmpeg, ImageMagick, yt-dlp, gifsicle, sox, webp, openexr
- **CLI Utilities**: jq, yq, just, direnv, shellcheck, shfmt, tldr, hyperfine, neofetch, pipx, scc, wget, gitingest, blueutil, gnupg, poppler, stripe, supabase
- **GUI Productivity**: 1Password, Notion suite, Raycast, Cursor, Ollama
- **GUI Development**: Zed (preview), Ghostty terminal, CotEditor
- **GUI Media**: IINA, Figma, CleanShot, Clop
- **GUI System**: CleanMyMac, Karabiner Elements, MonitorControl, Keka, Ice, Leader Key, Transmission
- **GUI Communication**: WhatsApp, Zoom, Lark
- **GUI Cloud**: Google Drive, Dropbox, Backblaze
- **GUI Security**: AdGuard

See `homebrew/Brewfile` for the complete list with descriptions.

## 7. Shell

- **Functions**: `upd` (update all Homebrew packages with progress tracking), `zed` (open Zed editor, defaults to current directory), `eza` (wrapper with smart defaults for tree view)
- **Aliases**: `ls`/`ll`/`lt`/`tree` → eza variants, `cat` → bat, `find` → fd, `htop`/`top` → btm

## 8. Setup

- **Prerequisites**: Install Homebrew via `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`, Bun installed via Homebrew during setup
- **Manual steps**: Clone to `~/Git/dot`, run `bun install`, run `./scripts/setup.sh`
- **Local config**: Copy `shell/zshrc.local.example` to `shell/zshrc.local` for API keys and secrets (gitignored, auto-sourced by zshrc)

## 9. Notes

- Existing files are backed up with `.backup` extension before creating symlinks
- Git hooks are automatically set up for commit linting and formatting
- Shell configurations are optimized with extracted functions for better maintainability
- All modern CLI tools are configured with sensible defaults
