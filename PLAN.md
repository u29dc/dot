# DOTFILES HARDENING PLAN

This plan tracks the next cleanup batch for fresh-mac reliability, Fish/Zsh parity, Dia/Codex rendering, doctor coverage, and later setup decomposition.

## Goal

Make setup safer and more predictable without changing the intended workstation behavior:

- Codex and Claude stay full-access by default.
- Dia stays enabled and defaults to port `9222`.
- Fish remains the preferred login shell; Zsh remains fully usable.
- `homebrew/Brewfile.primary` remains the single shared tracked Brewfile for now.
- `setup.env` remains the single ignored machine-local input.

## Principles

- Keep `scripts/setup.sh` as the user-facing setup command.
- Prefer behavior-preserving moves before design changes.
- Keep generated files validated before replacing live files.
- Keep private paths, keys, tokens, app state, and personal vault details out of tracked files.
- Use one-word shell library names under `scripts/lib/`; do not add `setup-` prefixes.
- Do not split Brewfiles unless a real second-machine need appears.

## Phase 1: Immediate Safety Fixes

### 1. Make `setup.env.example` first-pass safe

Problem: copying `setup.env.example` and running setup fails because Git and 1Password rendering are enabled while required values are blank.

Change:

```sh
DOT_ENABLE_ONEPASSWORD=0
DOT_ENABLE_GIT_CONFIG=0
```

Keep enabled:

```sh
DOT_ENABLE_DIA=1
DOT_ENABLE_SYSTEM_EXTENSIONS=1
DOT_ENABLE_CODEX_CONFIG=1
```

Update comments so the file explains:

- first pass works immediately after copy;
- final pass turns Git and 1Password on after SSH/signing keys and 1Password items exist.

Validation:

```sh
tmp="$(mktemp /tmp/dot-env.XXXXXX)"
cp setup.env.example "$tmp"
/bin/bash scripts/setup.sh --dry-run --no-brew --env-file "$tmp"
rm -f "$tmp"
```

### 2. Normalize `--env-file`

Problem: relative `--env-file` values can be rendered into `env.zsh` / `env.fish` and later break from another working directory.

Change:

- Convert `DOT_ENV_FILE` to an absolute path after argument parsing and before `load_env_file`.
- Render only the absolute normalized path into generated shell env files.
- Preserve support for `DOT_ENV_FILE=...` from the environment.

Validation:

```sh
/bin/bash scripts/setup.sh --dry-run --no-brew --env-file setup.env
```

Then inspect generated dry-run output expectations and run:

```sh
DOT_ENV_FILE=setup.env /bin/bash scripts/doctor.sh
```

Only the real current shell env should decide whether this passes; no relative path should be persisted by setup.

### 3. Fix Fish PATH ordering

Problem: repeated `fish_add_path --path --move` calls prepend each item, so Fish effective precedence can reverse the written order and drift from Zsh.

Target precedence:

```text
~/.bun/bin
~/bin
/opt/homebrew/bin
/opt/homebrew/sbin
~/.local/bin
~/.cargo/bin
/Applications/Obsidian.app/Contents/MacOS
```

Change:

- Update `shell/fish/config.fish` so the final Fish PATH matches the intended order.
- Prefer a single ordered `fish_add_path` call if it preserves the order.
- Otherwise deliberately reverse the calls and document why.

Validation:

```sh
fish --no-config --no-execute shell/fish/config.fish shell/fish/functions.fish shell/fish/local.fish.example
```

Add or run a small runtime probe to confirm the first PATH entries.

## Phase 2: Dia And Codex Hardening

### 4. Fix Dia port split

Problem: `AGENT_BROWSER_DIA_PORT` is configurable, but `terminal/agent-browser.json` hardcodes `9222`.

Preferred change:

- Convert `terminal/agent-browser.json` to a template, for example:

```text
terminal/agent-browser.json.template
```

- Render `~/.agent-browser/config.json` from setup with `__AGENT_BROWSER_DIA_PORT__`.
- Keep `terminal/agent-browser.chrome.json` static.
- Add doctor parity check: rendered Dia config port equals `AGENT_BROWSER_DIA_PORT`.

Alternative:

- Remove the port override and treat `9222` as a hard invariant everywhere.

Current preference: keep the env override and render the config.

### 5. Harden `scripts/codex.sh`

Problem: Codex config rendering uses raw string substitution and raw local fragment injection, then replaces the destination without validating the generated TOML.

Change:

- TOML-escape substituted string values.
- Validate any injected `CODEX_NODE_REPL_ENV_FILE` content before inclusion.
- Render to a temp file.
- Parse the temp file with Python `tomllib`.
- Replace `~/.codex/config.toml` only after validation passes.
- Leave the old config untouched on failure.

Validation:

```sh
/bin/bash scripts/codex.sh --dry-run
/bin/bash scripts/setup.sh --dry-run --no-brew
bun run doctor
```

## Phase 3: Doctor Coverage

### 6. Extend `scripts/doctor.sh`

Add checks for:

- `~/.config/karabiner/karabiner.json` symlink.
- `~/.macos` symlink.
- `system/karabiner` JSON parse.
- `macos/.macos` Bash parse.
- rendered Dia agent-browser config port equals `AGENT_BROWSER_DIA_PORT`.
- Codex runtime paths exist and are executable where appropriate:
  - notify command;
  - node REPL command;
  - `CODEX_CLI_PATH`;
  - `NODE_REPL_NODE_PATH`;
  - `NODE_REPL_NODE_MODULE_DIRS`.
- Dia listener binding if inspectable; warn if bound to `*`, `0.0.0.0`, or another non-loopback address.
- duplicate skill folder names across `SKILLS_BASE` and `DOT_SKILL_SOURCES`.
- broken skill symlinks in `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`.

Keep doctor read-only.

Validation:

```sh
bun run doctor
```

## Phase 4: Setup Decomposition

Do this after Phases 1-3 are complete and stable.

### Target structure

```text
scripts/
├── setup.sh
├── codex.sh
├── doctor.sh
└── lib/
    ├── progress.sh
    ├── env.sh
    ├── render.sh
    ├── links.sh
    ├── brew.sh
    ├── shell.sh
    ├── dia.sh
    └── skills.sh
```

### Library ownership

`env.sh`

- env loading;
- defaults;
- validation;
- truthy / path / list helpers;
- env-file normalization.

`render.sh`

- template substitution;
- managed-file rendering;
- shell quoting if shared;
- generated-file validation hooks where appropriate.

`links.sh`

- backup manifest;
- existing target backup;
- symlink creation;
- legacy link cleanup helpers.

`brew.sh`

- Homebrew installation;
- Brewfile resolution;
- Brewfile check/install loop.

`shell.sh`

- shell env rendering;
- Fish/Zsh config setup;
- login shell resolution;
- `/etc/shells` handling;
- default shell application;
- legacy Fish split cleanup.

`dia.sh`

- Dia CDP URL/domain/service helpers;
- Dia process detection;
- LaunchAgent load/kickstart;
- CDP health wait.

`skills.sh`

- skill source scanning;
- base/extra skill linking;
- duplicate detection;
- prune state handling.

### Orchestration target

After decomposition, `scripts/setup.sh` should read roughly like:

```sh
parse_args "$@"
load_env_file "$DOT_ENV_FILE"
apply_defaults
validate_setup_env
print_setup_summary

install_brew_layers
ensure_tools_home

setup_shells
setup_terminal
setup_editor
setup_system
setup_agents

finish_message
```

### Decomposition rules

- Move code first; do not redesign at the same time.
- Preserve dry-run output semantics.
- Preserve backup manifest behavior.
- Preserve existing setup flags.
- Validate after each extraction.

## Validation Gate

Run after each implementation phase:

```sh
bunx biome check .
shfmt -d -i 4 -ci scripts/*.sh scripts/lib/*.sh shell/zsh/functions/*.sh terminal/bin/* macos/.macos
shellcheck scripts/*.sh scripts/lib/*.sh shell/zsh/functions/*.sh terminal/bin/* macos/.macos
zsh -n shell/zsh/zshrc shell/zsh/zprofile shell/zsh/zshrc.local.example shell/zsh/functions/update.sh shell/zsh/functions/agent-browser.sh
fish --no-config --no-execute shell/fish/config.fish shell/fish/functions.fish shell/fish/local.fish.example
/bin/bash scripts/setup.sh --dry-run --no-brew
bun run doctor
git diff --check
git status --short --branch
```

## Suggested Commit Batches

Batch 1: practical hardening

- `setup.env.example` first-pass safety;
- env-file normalization;
- Fish PATH order;
- Dia config rendering;
- Codex rendered TOML validation;
- doctor coverage.

Batch 2: setup decomposition

- split `scripts/setup.sh` into `env`, `render`, `links`, `brew`, `shell`, `dia`, and `skills`;
- keep behavior stable;
- avoid unrelated cleanup.
