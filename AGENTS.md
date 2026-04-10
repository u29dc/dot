> `dot` is a macOS dotfiles and workstation bootstrap repository. [`scripts/setup.sh`](scripts/setup.sh) installs packages from [`homebrew/Brewfile`](homebrew/Brewfile) and symlinks repo-managed config into `$HOME` for shell, editor, terminal, system, and AI-agent tooling.

## 1. Documentation

- Bootstrap and symlink behavior: [`scripts/setup.sh`](scripts/setup.sh)
- Package inventory: [`homebrew/Brewfile`](homebrew/Brewfile)
- Agent policy and shared AI config: [`agents/AGENTS.md`](agents/AGENTS.md), [`agents/codex.toml`](agents/codex.toml), [`agents/claude.json`](agents/claude.json), [`agents/amp.settings.json`](agents/amp.settings.json)
- Agent browser defaults: [`terminal/agent-browser.json`](terminal/agent-browser.json), [`terminal/agent-browser.chrome.json`](terminal/agent-browser.chrome.json), [`system/launchagents/com.u29dc.dia-cdp.plist`](system/launchagents/com.u29dc.dia-cdp.plist)
- Local secrets template: [`shell/zshrc.local.example`](shell/zshrc.local.example)
- Root quality tooling: [`package.json`](package.json), [`biome.json`](biome.json), [`commitlint.config.js`](commitlint.config.js), [`lint-staged.config.js`](lint-staged.config.js)

## 2. Repository Structure

```text
.
├── agents/                  AI assistant policy, settings, and skills
├── shell/                   zsh config and extracted shell functions
├── terminal/                CLI and terminal tool config
├── editor/                  editor settings and keymaps
├── system/                  git, launchagent, karabiner, and 1Password config
├── homebrew/                package and cask inventory
├── macos/                   macOS preference script
└── scripts/                 bootstrap and maintenance scripts
```

- Edit files in this repository, not the symlink targets under `$HOME`.
- `shell/`, `terminal/`, `editor/`, `system/`, and `macos/` map onto concrete destinations under `~/.config`, `~/.ssh`, `~/Library/Application Support`, and other home-directory paths.
- `agents/` is part of the managed dotfiles surface; setup links config into `~/.claude`, `~/.codex`, `~/.config/amp`, and shared skill directories.

## 3. Commands

Fresh machine setup does not require Bun; use the setup script directly. Day-to-day repo maintenance can use the Bun wrappers.

- `xcode-select --install` - install Apple command line tools on a new macOS machine
- `git clone https://github.com/u29dc/dot.git ~/Git/dot` - clone the repository
- `bash ~/Git/dot/scripts/setup.sh` - install Homebrew if needed, install packages, and create symlinks
- `source ~/.zshrc` - reload shell config after setup
- `bun install` - install repo-local tooling and husky hooks when working on the repo itself
- `bun run setup` - run the full setup flow from the repository root
- `bun run setup:link` - recreate symlinks without reinstalling packages
- `agent-browser ...` - browser automation against the managed Dia CDP endpoint on `127.0.0.1:9222`
- `agent-browser-dia ...` - force `agent-browser` to use the managed Dia config explicitly
- `agent-browser-dia-on` - start or load the managed Dia CDP session after quitting an unmanaged Dia instance
- `agent-browser-dia-off` - unload the managed Dia CDP LaunchAgent
- `agent-browser-dia-status` - inspect the Dia LaunchAgent and CDP endpoint health
- `agent-browser-chrome ...` - force `agent-browser` to use Chrome `Default` instead of Dia
- `bun run util:check` - format and lint repository files
- `bun run util:lint:shell` - run `shellcheck` on setup scripts and shell functions

## 4. Architecture

- [`scripts/setup.sh`](scripts/setup.sh) is the source of truth for link targets and setup behavior; keep this file subordinate to the script.
- The repository is declarative: top-level folders hold the desired config state, and setup materializes that state into `$HOME` via symlinks.
- Existing non-symlink targets are moved aside as `*.backup` before new links are created.
- Setup links GUI and macOS-specific config such as Ghostty, Karabiner, 1Password, Zed, and `~/.macos` alongside shared shell, terminal, and agent config.
- Agent skills are merged from the repo skill directory and optional external skill paths into `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`.

## 5. Runtime and State

- Create local-only secrets from [`shell/zshrc.local.example`](shell/zshrc.local.example) and keep machine-specific keys out of the repository.
- Setup flags: `--link-only` skips Homebrew installation.
- Environment overrides: `TOOLS_HOME` changes the tool home directory, `SKILLS_BASE` changes the base skill source, `SKILLS_U29DC` adds an extra skill source tree.
- Agent browser defaults live at `~/.agent-browser/config.json` and `~/.agent-browser/chrome.json`; the managed Dia service lives at `~/Library/LaunchAgents/com.u29dc.dia-cdp.plist` and reserves local port `9222`.
- High-impact write targets include `~/.zshrc`, `~/.gitconfig`, `~/.ssh/config`, `~/.config/*`, `~/.agent-browser/*`, `~/.claude/*`, `~/.codex/*`, `~/.config/amp/*`, `~/Library/LaunchAgents/*`, and `~/Library/Application Support/com.mitchellh.ghostty/config` on host machines.

## 6. Validation

- Required repository gate: `bun run util:check`
- If you change shell logic or setup behavior, also run `bun run util:lint:shell`
- If you change [`scripts/setup.sh`](scripts/setup.sh), smoke-test at least one `--link-only` run before considering the change complete
- If you change the Dia LaunchAgent or agent-browser defaults, verify `http://127.0.0.1:9222/json/version` and at least one `agent-browser` command against the managed Dia session
- Verify that changed symlink targets resolve correctly and that existing real files are preserved as `.backup`

## 7. Further Reading

- [`homebrew/Brewfile`](homebrew/Brewfile) - package inventory and cask list
- [`agents/AGENTS.md`](agents/AGENTS.md) - repo-wide agent operating contract
- [`shell/`](shell/) and [`terminal/`](terminal/) - most frequently changed day-to-day config surfaces
