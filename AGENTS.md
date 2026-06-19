> `dot` is a macOS dotfiles and workstation bootstrap repository. [`scripts/setup.sh`](scripts/setup.sh) installs profile-selected Homebrew layers and materializes repo-managed config into `$HOME` for shell, editor, terminal, system, and AI-agent tooling.

## 1. Documentation

- Bootstrap and symlink behavior: [`scripts/setup.sh`](scripts/setup.sh)
- Package inventory: [`homebrew/Brewfile.base`](homebrew/Brewfile.base), [`homebrew/Brewfile.profile1`](homebrew/Brewfile.profile1), [`homebrew/Brewfile.profile2`](homebrew/Brewfile.profile2)
- Local setup override template: [`profiles/local.env.example`](profiles/local.env.example)
- Agent policy and shared AI config: [`agents/AGENTS.md`](agents/AGENTS.md), [`agents/codex.toml`](agents/codex.toml), [`agents/claude.json`](agents/claude.json)
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
├── profiles/                local setup override template and profile notes
├── macos/                   macOS preference script
└── scripts/                 bootstrap and maintenance scripts
```

- Edit files in this repository, not the symlink targets under `$HOME`.
- `shell/`, `terminal/`, `editor/`, `system/`, and `macos/` map onto concrete destinations under `~/.config`, `~/.ssh`, `~/Library/Application Support`, and other home-directory paths.
- `agents/` is part of the managed dotfiles surface; setup links config into `~/.claude`, `~/.codex`, and shared skill directories.

## 3. Commands

Fresh machine setup does not require Bun; use the setup script directly. Day-to-day repo maintenance can use the Bun wrappers.

Factory-fresh Mac bootstrap:

1. Complete macOS first-run setup and sign in to Apple ID.
2. Install Apple command line tools: `xcode-select --install`.
3. Clone over HTTPS first: `git clone https://github.com/u29dc/dot.git ~/Git/dot`.
4. Run setup: `bash ~/Git/dot/scripts/setup.sh --profile profile1`.
5. Restart shell: `exec zsh -l`.
6. Sign into human apps such as 1Password, Dropbox if allowed, Codex, Claude, backup, sync, and security tools.
7. Add machine-local overrides in `~/.config/dot/local.env` when needed, then rerun setup.
8. Verify with `./scripts/doctor.sh`, GitHub SSH, Codex MCP, and Dia/agent-browser checks.

- `xcode-select --install` - install Apple command line tools on a new macOS machine
- `git clone https://github.com/u29dc/dot.git ~/Git/dot` - clone the repository
- `bash ~/Git/dot/scripts/setup.sh --dry-run --profile profile1` - preview setup without writing
- `bash ~/Git/dot/scripts/setup.sh --profile profile1` - install packages and link config, backing up existing real files into run-id backups when needed
- `bash ~/Git/dot/scripts/setup.sh --profile profile2 --dry-run --no-brew` - preview the second profile without package installation
- `source ~/.zshrc` - reload shell config after setup
- `bun install` - install repo-local tooling and husky hooks when working on the repo itself
- `bun run setup` - run the full setup flow from the repository root
- `bun run setup:profile1` - run the first setup profile
- `bun run setup:profile2` - run the second setup profile
- `bun run setup:dry` - preview link setup without Homebrew writes
- `bun run doctor` - run read-only dotfiles structure and privacy checks
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
- The repository is declarative: top-level folders hold the desired config state, and setup materializes that state into `$HOME` via profile-selected symlinks and generated local config.
- Existing non-symlink targets are moved into `~/.dotfiles-backups/<run-id>/` and recorded in a manifest before links are created.
- Setup links GUI and macOS-specific config such as Ghostty, Karabiner, 1Password, Zed, and `~/.macos` alongside shared shell, terminal, and agent config.
- Agent skills are merged from the repo skill directory and optional external skill paths into `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`.
- Codex config is generated locally from the single shared template at `agents/codex.toml`; `profile1` and `profile2` do not change Codex intelligence, access, reasoning, or sandbox settings.
- Keep volatile Codex app state out of tracked config: auth state, remote-control IDs, trusted project lists, marketplace caches, browser client hashes, app build numbers, private vault paths, and machine-specific notification paths.

## 5. Runtime and State

- Create local-only secrets from [`shell/zshrc.local.example`](shell/zshrc.local.example) and keep machine-specific keys out of the repository.
- Setup copies `shell/zshrc.local.example` to `~/.zshrc.local` only when that file does not already exist; it does not link ignored local secrets from the repository.
- Public setup profiles: `profile1`, `profile2`.
- `homebrew/Brewfile.base` currently contains the complete shared workstation package inventory. `profile1` and `profile2` are empty extension layers for future machine-specific deltas.
- Profile behavior lives in `scripts/setup.sh`; do not add per-profile env templates or duplicate profile defaults in another config file.
- Local env precedence, highest to lowest: CLI flags, process env, `profiles/local.env`, `~/.config/dot/local.env`, then setup defaults.
- Use `profiles/local.env.example` as the only tracked local-env template. Keep actual `profiles/local.env` ignored and local-only.
- Setup flags: `--profile profile1|profile2`, `--dry-run`, and `--no-brew`.
- Environment overrides: `TOOLS_HOME` changes the tool home directory, `SKILLS_BASE` changes the base skill source, and `DOT_SKILLS_PROFILE1` / `DOT_SKILLS_PROFILE2` add profile-specific extra skill source folders.
- Optional feature overrides use literal `1` for enabled and any other value for disabled; profile defaults may enable features without local env entries.
- Agent browser defaults live at `~/.agent-browser/config.json` and `~/.agent-browser/chrome.json`; the managed Dia service lives at `~/Library/LaunchAgents/com.u29dc.dia-cdp.plist` and reserves local port `9222`.
- High-impact write targets include `~/.zshrc`, `~/.gitconfig`, `~/.ssh/config`, `~/.config/*`, `~/.agent-browser/*`, `~/.claude/*`, `~/.codex/*`, `~/Library/LaunchAgents/*`, and `~/Library/Application Support/com.mitchellh.ghostty/config` on host machines.

## 6. Validation

- Required repository gate: `bun run util:check`
- If you change shell logic or setup behavior, also run `bun run util:lint:shell`
- If you change [`scripts/setup.sh`](scripts/setup.sh), smoke-test profile dry-runs before running real setup
- If you change profiles, generated config, or setup privacy behavior, run `bun run doctor`
- If you change the Dia LaunchAgent or agent-browser defaults, verify `http://127.0.0.1:9222/json/version` and at least one `agent-browser` command against the managed Dia session
- Verify that changed symlink targets resolve correctly and that adopted real files are preserved under `~/.dotfiles-backups/<run-id>/`

## 7. Further Reading

- [`homebrew/`](homebrew/) - shared package inventory and profile extension layers
- [`agents/AGENTS.md`](agents/AGENTS.md) - repo-wide agent operating contract
- [`shell/`](shell/) and [`terminal/`](terminal/) - most frequently changed day-to-day config surfaces
