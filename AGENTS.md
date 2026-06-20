> `dot` is a macOS dotfiles and workstation bootstrap repository. [`scripts/setup.sh`](scripts/setup.sh) reads the local ignored [`setup.env`](setup.env.example), installs selected Homebrew layers, links shared config, and renders machine-local config into `$HOME` for shell, editor, terminal, system, and AI-agent tooling.

## 1. Documentation

- Bootstrap and symlink behavior: [`scripts/setup.sh`](scripts/setup.sh)
- Package inventory: [`homebrew/Brewfile.base`](homebrew/Brewfile.base)
- Local setup template: [`setup.env.example`](setup.env.example)
- Agent policy and shared AI config: [`agents/AGENTS.md`](agents/AGENTS.md), [`agents/codex.toml`](agents/codex.toml), [`agents/claude.json`](agents/claude.json)
- Agent browser defaults: [`terminal/agent-browser.json`](terminal/agent-browser.json), [`terminal/agent-browser.chrome.json`](terminal/agent-browser.chrome.json), [`system/launchagents/com.u29dc.dia-cdp.plist.template`](system/launchagents/com.u29dc.dia-cdp.plist.template)
- Local secrets templates: [`shell/zsh/zshrc.local.example`](shell/zsh/zshrc.local.example), [`shell/fish/local.fish.example`](shell/fish/local.fish.example)
- Root quality tooling: [`package.json`](package.json), [`biome.json`](biome.json), [`commitlint.config.js`](commitlint.config.js), [`lint-staged.config.js`](lint-staged.config.js)

## 2. Repository Structure

```text
.
├── agents/                  AI assistant policy, settings, and skills
├── shell/                   zsh and fish config, split by shell
├── terminal/                CLI and terminal tool config
├── editor/                  editor settings and keymaps
├── system/                  git, launchagent, karabiner, and 1Password config
├── homebrew/                package and cask inventory
├── macos/                   macOS preference script
└── scripts/                 bootstrap and maintenance scripts
```

- Edit files in this repository, not the symlink targets under `$HOME`.
- `shell/`, `terminal/`, `editor/`, `system/`, and `macos/` map onto concrete destinations under `~/.config`, `~/.ssh`, `~/Library/Application Support`, and other home-directory paths.
- `agents/` is part of the managed dotfiles surface; setup links config into `~/.claude`, `~/.codex`, and shared skill directories.
- Machine-sensitive configs such as Git identity, SSH signing, 1Password agent config, SSH config, and Dia LaunchAgent are templates in the repo and rendered to `$HOME` from ignored `setup.env`.

## 3. Commands

Fresh machine setup does not require Bun; use the setup script directly. Day-to-day repo maintenance can use the Bun wrappers.

Factory-fresh Mac bootstrap:

1. Complete macOS first-run setup and sign in to Apple ID.
2. Install Apple command line tools: `xcode-select --install`.
3. Clone over HTTPS first: `git clone https://github.com/u29dc/dot.git ~/Git/dot`.
4. Create local setup answers: `cd ~/Git/dot && cp setup.env.example setup.env`.
5. Fill `setup.env` with machine-local values and preferences.
6. Preview setup: `bash ~/Git/dot/scripts/setup.sh --dry-run --no-brew`.
7. Run setup: `bash ~/Git/dot/scripts/setup.sh`.
8. Restart the terminal; `setup.env.example` defaults to Fish, while Zsh remains available with `zsh`.
9. Sign into human apps such as 1Password, Dropbox if allowed, Codex, Claude, backup, sync, and security tools.
10. Verify with `./scripts/doctor.sh`, GitHub SSH, Codex MCP, and Dia/agent-browser checks.

- `xcode-select --install` - install Apple command line tools on a new macOS machine
- `git clone https://github.com/u29dc/dot.git ~/Git/dot` - clone the repository
- `cp setup.env.example setup.env` - create the ignored machine-local setup form
- `bash ~/Git/dot/scripts/setup.sh --dry-run --no-brew` - preview setup without writes or package installation
- `bash ~/Git/dot/scripts/setup.sh` - install packages, link shared config, and render machine-local config with run-id backups when needed
- `bash ~/Git/dot/scripts/setup.sh --env-file ./other.env --dry-run` - preview a different local env file
- `fish` - start the Fish setup explicitly
- `zsh` - start the side-by-side Zsh setup explicitly
- `bun install` - install repo-local tooling and husky hooks when working on the repo itself
- `bun run setup` - run the full setup flow from the repository root
- `bun run setup:dry` - preview link setup without Homebrew writes
- `bun run setup:nobrew` - run setup without Homebrew package installation
- `bun run doctor` - run read-only dotfiles structure and privacy checks
- `agent-browser ...` - browser automation against the managed Dia CDP endpoint on `127.0.0.1:9222`
- `agent-browser-dia ...` - force `agent-browser` to use the managed Dia config explicitly
- `agent-browser-dia-on` - start or load the managed Dia CDP session after quitting an unmanaged Dia instance
- `agent-browser-dia-off` - unload the managed Dia CDP LaunchAgent
- `agent-browser-dia-status` - inspect the Dia LaunchAgent and CDP endpoint health
- `agent-browser-chrome ...` - force `agent-browser` to use Chrome `Default` instead of Dia
- `bun run util:check` - format and lint repository files; this command writes formatting fixes
- `bun run util:lint:shell` - run `shellcheck` on setup scripts and shell functions
- `bun run util:lint:zsh` - parse-check Zsh entrypoints and helper functions
- `bun run util:lint:fish` - parse-check Fish config and functions

## 4. Architecture

- [`scripts/setup.sh`](scripts/setup.sh) is the source of truth for link targets and setup behavior; keep this file subordinate to the script.
- The repository is declarative: top-level folders hold the desired config state, and setup materializes that state into `$HOME` via symlinks and generated local config.
- Existing non-symlink targets are moved into `~/.dotfiles-backups/<run-id>/` and recorded in a manifest before links are created.
- Setup links GUI and macOS-specific config such as Ghostty, Karabiner, 1Password, Zed, and `~/.macos` alongside shared shell, terminal, and agent config.
- `setup.env` is the single machine-local input. Setup renders shell-specific env files at `~/.config/dot/env.zsh` and `~/.config/dot/env.fish`; Zsh and Fish should consume those rendered files instead of duplicating defaults.
- Keep Zsh and Fish side by side under `shell/zsh` and `shell/fish`. Fish intentionally uses one `config.fish` plus one `functions.fish`, not `conf.d` or one-file-per-function autoloading. Do not translate setup or doctor into Fish; bootstrap scripts stay Bash for factory-fresh reproducibility.
- Agent skills are merged from the repo skill directory and optional external skill paths into `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`.
- Codex config is generated locally from the single shared template at `agents/codex.toml`; machine-local setup values must not change Codex intelligence, access, reasoning, or sandbox settings.
- Keep volatile Codex app state out of tracked config: auth state, remote-control IDs, trusted project lists, marketplace caches, browser client hashes, app build numbers, private vault paths, and machine-specific notification paths.

## 5. Runtime and State

- Create local-only secrets from the shell local examples and keep machine-specific keys out of the repository.
- Setup copies `shell/zsh/zshrc.local.example` to `~/.zshrc.local` and `shell/fish/local.fish.example` to `~/.config/fish/local.fish` only when those files do not already exist; it does not link ignored local secrets from the repository.
- `setup.env.example` is the only tracked local setup template. Keep actual `setup.env` ignored and local-only.
- `homebrew/Brewfile.base` currently contains the complete shared workstation package inventory. Optional local Brewfiles may be listed in `DOT_BREWFILES` but should be ignored unless intentionally promoted.
- Local env precedence, highest to lowest: CLI operational flags, process env, `setup.env`, then setup defaults.
- Setup flags: `--dry-run`, `--no-brew`, and `--env-file`.
- Environment overrides: `TOOLS_HOME` changes the tool home directory, `SKILLS_BASE` changes the base skill source, `DOT_SKILL_SOURCES` adds colon-separated extra skill source folders, `DOT_BREWFILES` selects ordered Brew layers, and `DOT_DEFAULT_SHELL` can set `fish`, `zsh`, `none`, or an absolute login shell path.
- Navigation overrides: `DOT_DROPBOX_HOME`, `DOT_VAULT_HOME`, and `DOT_GDRIVE_HOME` feed shared Fish/Zsh shortcuts such as `oo`, `vault`, `dropbox`, and `gdrive`. `DOT_CLOUDSTORAGE_HOME` is a reusable base path for local setup values. Leave them blank on machines without those locations.
- Optional feature overrides use literal `1` for enabled and `0` for disabled.
- Agent browser defaults live at `~/.agent-browser/config.json` and `~/.agent-browser/chrome.json`; the managed Dia service lives at `~/Library/LaunchAgents/com.u29dc.dia-cdp.plist` and reserves local port `9222`.
- High-impact write targets include `~/.zshrc`, `~/.zprofile`, `~/.config/fish/*`, `~/.config/dot/env.*`, `~/.gitconfig`, `~/.ssh/config`, `~/.config/*`, `~/.agent-browser/*`, `~/.claude/*`, `~/.codex/*`, `~/Library/LaunchAgents/*`, and `~/Library/Application Support/com.mitchellh.ghostty/config` on host machines.

## 6. Validation

- Required repository gate: `bun run util:check`
- If you change shell logic or setup behavior, also run `bun run util:lint:shell`, `bun run util:lint:zsh`, and `bun run util:lint:fish`
- If you change [`scripts/setup.sh`](scripts/setup.sh), smoke-test `/bin/bash scripts/setup.sh --dry-run --no-brew` before running real setup
- If you change setup env, generated config, or setup privacy behavior, run `bun run doctor`
- If you change the Dia LaunchAgent or agent-browser defaults, verify `http://127.0.0.1:9222/json/version` and at least one `agent-browser` command against the managed Dia session
- Verify that changed symlink targets resolve correctly and that adopted real files are preserved under `~/.dotfiles-backups/<run-id>/`

## 7. Further Reading

- [`homebrew/`](homebrew/) - shared package inventory
- [`agents/AGENTS.md`](agents/AGENTS.md) - repo-wide agent operating contract
- [`shell/zsh/`](shell/zsh/), [`shell/fish/`](shell/fish/), and [`terminal/`](terminal/) - most frequently changed day-to-day config surfaces
