> `dot` is a macOS dotfiles and workstation bootstrap repository. [`scripts/setup.sh`](scripts/setup.sh) reads the local ignored [`setup.env`](setup.env.example), installs selected Homebrew layers, links shared config, and renders machine-local config into `$HOME` for shell, editor, terminal, system, and AI-agent tooling.

## 1. Documentation

- Bootstrap and symlink behavior: [`scripts/setup.sh`](scripts/setup.sh)
- Managed file inventory (links, rendered files, retired paths): [`scripts/lib/targets.sh`](scripts/lib/targets.sh)
- Full fresh-machine setup guide: [`SETUP.md`](SETUP.md)
- Package inventory: [`homebrew/Brewfile.primary`](homebrew/Brewfile.primary) (shared) and [`homebrew/Brewfile.personal`](homebrew/Brewfile.personal) (personal machines)
- Local setup template: [`setup.env.example`](setup.env.example)
- Agent policy and shared AI config: [`agents/AGENTS.md`](agents/AGENTS.md), [`agents/codex.toml`](agents/codex.toml), [`agents/claude.json`](agents/claude.json)
- Agent browser defaults: [`terminal/agent-browser.json.template`](terminal/agent-browser.json.template), [`terminal/agent-browser.chrome.json`](terminal/agent-browser.chrome.json), [`system/launchagents/com.u29dc.dia-cdp.plist.template`](system/launchagents/com.u29dc.dia-cdp.plist.template)
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
├── scripts/                 bootstrap and maintenance scripts
└── tests/                   isolated Python unittest suite
```

- Edit files in this repository, not the symlink targets under `$HOME`.
- `shell/`, `terminal/`, `editor/`, `system/`, and `macos/` map onto concrete destinations under `~/.config`, `~/.ssh`, `~/Library/Application Support`, and other home-directory paths.
- `agents/` is part of the managed dotfiles surface; setup links config into `~/.claude`, `~/.codex`, and shared skill directories.
- Machine-sensitive configs such as Git identity, SSH signing, 1Password agent config, SSH config, and Dia LaunchAgent are templates in the repo and rendered to `$HOME` from ignored `setup.env`.

## 3. Commands

Fresh machine setup belongs in [`SETUP.md`](SETUP.md). Keep this section limited to day-to-day repository maintenance and runtime checks.

- `bun install` - install repo-local tooling and husky hooks when working on the repo itself
- `bun run doctor` - run read-only dotfiles structure and privacy checks
- `agent-browser ...` - browser automation against the managed Dia CDP endpoint on `127.0.0.1:9222`
- `agent-browser-dia ...` - force `agent-browser` to use the managed Dia config explicitly
- `agent-browser-dia-on` - start or load the managed Dia CDP session after quitting an unmanaged Dia instance
- `agent-browser-dia-off` - unload the managed Dia CDP LaunchAgent
- `agent-browser-dia-status` - inspect the Dia LaunchAgent and CDP endpoint health
- `agent-browser-chrome ...` - force `agent-browser` to use Chrome `Default` instead of Dia
- `bun run util:check` - format and lint repository files, then run the test suite; this command writes formatting fixes
- `bun run util:test` - run the isolated unittest suite only
- `/bin/bash scripts/plugins.sh [--dry-run]` - reconcile agent links, settings, plugins and skills without the rest of setup
- `bun run util:lint:shell` - run `shellcheck` on setup scripts and shell functions
- `bun run util:lint:zsh` - parse-check Zsh entrypoints and helper functions
- `bun run util:lint:fish` - parse-check Fish config and functions

## 4. Architecture

- [`scripts/setup.sh`](scripts/setup.sh) is the source of truth for setup orchestration; one-word libraries under [`scripts/lib/`](scripts/lib/) own the reusable setup behavior. Every script must run under macOS system Bash 3.2.
- The repository is declarative: top-level folders hold the desired config state, and setup materializes that state into `$HOME` via symlinks and generated local config.
- [`scripts/lib/targets.sh`](scripts/lib/targets.sh) is the single inventory of linked and rendered files. Setup applies it and `doctor.sh` verifies every entry, so add new managed files there rather than as one-off `link_file` calls. Every executable in `terminal/bin/` is linked into `~/.local/bin` automatically; names starting with `_` are skipped.
- Root `biome.json` and `tsconfig.json` double as shared base configs: other repositories `extends` them through `~/.config/biome/biome.json`, `~/.config/typescript/tsconfig.json`, or a sibling `../dot/` path. Treat changes to them as changes to every consuming repository.
- Existing non-symlink targets are moved into `~/.dotfiles-backups/<run-id>/` and recorded in that run's manifest before links are created; replaced symlinks record their previous target. Generated files and agent settings whose content is unchanged are never rewritten or backed up.
- Setup links GUI and macOS-specific config such as Ghostty, Karabiner, 1Password, Zed, and `~/.macos` alongside shared shell, terminal, and agent config. Karabiner is linked as the whole `~/.config/karabiner` directory, as Karabiner-Elements requires for change detection.
- `setup.env` is the single machine-local input. Setup renders shell-specific env files at `~/.config/dot/env.zsh` and `~/.config/dot/env.fish`; Zsh and Fish should consume those rendered files instead of duplicating defaults.
- Keep Zsh and Fish side by side under `shell/zsh` and `shell/fish`. Fish intentionally uses one `config.fish` plus one `functions.fish`, not `conf.d` or one-file-per-function autoloading. Do not translate setup or doctor into Fish; bootstrap scripts stay Bash for factory-fresh reproducibility.
- Configured agent sources may contain standalone skills or complete plugins. Plugin manifests take precedence over `SKILL.md`; default `DOT_PLUGIN_MODE=link` symlinks each complete plugin root into `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`, preserving child skills and shared resources. Previously managed marketplace snapshots are disabled with settings backups. Claude snapshots are also backed up and unregistered through its CLI, since disabled installations still reserve their names. Other plugins remain unchanged. Standalone skills retain their symlinks.
- `scripts/plugins.sh` is the narrow agent-only setup entrypoint; it reads the same configured sources without running Homebrew, shell, or system setup. Live links read current source without packaging or refresh. Explicit `DOT_PLUGIN_MODE=package` uses official host CLIs and versioned catalogs under `~/.local/share/dot/plugins/`; do not run both discovery modes for one source.
- Codex config and Claude settings are generated local files merged from `agents/codex.toml` and `agents/claude.json` by [`scripts/merge_agent_config.py`](scripts/merge_agent_config.py), not settings symlinks. Shared managed preferences apply while runtime plugin selections, marketplace registrations, Codex project state and other unknown local fields are preserved. Model choices (`model`, plus Codex `model_reasoning_effort` and `service_tier`) only seed new machines, because they are changed in-app. Existing `mcp_servers` entries are app-owned and never field-merged. Merges never delete live keys, so a key the templates stop managing must be added to `RETIRED` in the merge script, or its last value stays in place. Changed files are backed up before replacement; runtime plugin registration must not write into tracked settings. Machine-local setup values must not change Codex intelligence, access, reasoning, or sandbox settings.
- Keep volatile Codex app state out of tracked config: auth state, remote-control IDs, trusted project lists, marketplace caches, browser client hashes, app build numbers, app-internal paths such as the ChatGPT-managed `node_repl` server, private vault paths, and machine-specific notification paths.

## 5. Runtime and State

- Create local-only secrets from the shell local examples and keep machine-specific keys out of the repository.
- Setup copies `shell/zsh/zshrc.local.example` to `~/.zshrc.local` and `shell/fish/local.fish.example` to `~/.config/fish/local.fish` only when those files do not already exist; it does not link ignored local secrets from the repository.
- `setup.env.example` is the only tracked local setup template. Keep actual `setup.env` ignored and local-only.
- Cross-machine updates preserve each Mac's ignored setup and local override files. Pull shared changes, preview setup, then apply it using that Mac's env; see the update workflow in `SETUP.md`. Setup must never rewrite the selected env file. Legacy agent settings symlinks must become local files even when their contents already match the template.
- Setup defaults to a personal Mac using Fish and both shared and personal Homebrew layers. `homebrew/Brewfile.primary` is the shared baseline for every machine and `homebrew/Brewfile.personal` adds personal-only apps. A work machine lists `homebrew/Brewfile.primary:homebrew/Brewfile.local`, where the ignored local layer holds only that machine's extras; never copy the primary layer into it.
- `DOT_ONEPASSWORD_CHANNEL` selects the stable, beta, or nightly package per machine. Keep it aligned with that Mac's app data; installing an older stable build over newer prerelease data can prevent 1Password from opening.
- Local env precedence, highest to lowest: CLI operational flags, `setup.env`, inherited process env for values absent from `setup.env`, then setup defaults.
- Setup flags: `--dry-run`, `--no-brew`, and `--env-file`.
- Environment overrides: `TOOLS_HOME` changes the tool home directory, `SKILLS_BASE` changes the base skill source, `DOT_SKILL_SOURCES` adds extra skill sources, `DOT_BREWFILES` selects ordered Brew layers, and `DOT_DEFAULT_SHELL` can set `fish`, `zsh`, `none`, or an absolute login shell path.
- Navigation overrides: `DOT_DROPBOX_HOME`, `DOT_VAULT_HOME`, and `DOT_GDRIVE_HOME` feed shared Fish/Zsh shortcuts such as `oo`, `vault`, `dropbox`, and `gdrive`. `DOT_CLOUDSTORAGE_HOME` is a reusable base path for local setup values. Leave them blank on machines without those locations.
- Optional feature overrides use literal `1` for enabled and `0` for disabled.
- Agent browser defaults live at `~/.agent-browser/config.json` and `~/.agent-browser/chrome.json`; the managed Dia service lives at `~/Library/LaunchAgents/com.u29dc.dia-cdp.plist` and reserves local port `9222`.
- High-impact write targets include `~/.zshrc`, `~/.zprofile`, `~/.config/fish/*`, `~/.config/dot/env.*`, `~/.gitconfig`, `~/.ssh/config`, `~/.config/*`, `~/.agent-browser/*`, `~/.claude/*`, `~/.codex/*`, `~/Library/LaunchAgents/*`, and `~/Library/Application Support/com.mitchellh.ghostty/config` on host machines.

## 6. Validation

- Required repository gate: `bun run util:check`
- If you change shell logic or setup behavior, also run `bun run util:lint:shell`, `bun run util:lint:zsh`, and `bun run util:lint:fish`
- If you change [`scripts/setup.sh`](scripts/setup.sh), smoke-test `/bin/bash scripts/setup.sh --dry-run --no-brew` before running real setup
- If you change setup env, generated config, or setup privacy behavior, run `bun run doctor`; it re-renders each managed file and reports drift by file and by agent setting key
- If you change the Dia LaunchAgent or agent-browser defaults, verify `http://127.0.0.1:9222/json/version` and at least one `agent-browser` command against the managed Dia session
- Verify that changed symlink targets resolve correctly and that adopted real files are preserved under `~/.dotfiles-backups/<run-id>/`

## 7. Further Reading

- [`homebrew/`](homebrew/) - shared package inventory
- [`agents/AGENTS.md`](agents/AGENTS.md) - repo-wide agent operating contract
- [`shell/zsh/`](shell/zsh/), [`shell/fish/`](shell/fish/), and [`terminal/`](terminal/) - most frequently changed day-to-day config surfaces
