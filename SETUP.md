# SETUP

Fresh macOS setup runbook for this dotfiles repository. Use it directly or ask an agent to follow it.

Setup is staged because a fresh Mac does not yet have Homebrew, 1Password SSH keys, Git signing, Dropbox paths, Codex state, or optional skill folders.

## 1. Order

```text
macOS
 -> Apple command line tools
 -> Homebrew
 -> 1Password and ChatGPT
 -> clone this repo over HTTPS
 -> create setup.env
 -> first setup pass
 -> create or import SSH keys
 -> register GitHub keys
 -> final setup pass
 -> verification
```

`setup.env` is the single machine-local form. Create it from `setup.env.example`. It is ignored and must not be committed.

Setup defaults to a personal Mac. Homebrew layers are additive:
`homebrew/Brewfile.primary` is the shared baseline and
`homebrew/Brewfile.personal` adds personal-only apps. A work
machine omits the personal layer and keeps its own extras in an ignored
`homebrew/Brewfile.local`, which lists only those extras:

```sh
DOT_BREWFILES="homebrew/Brewfile.primary:homebrew/Brewfile.personal"  # personal Mac
DOT_BREWFILES="homebrew/Brewfile.primary:homebrew/Brewfile.local"     # work Mac
```

Do not copy the primary layer into the local one; a copy stops receiving
shared changes.

`DOT_ONEPASSWORD_CHANNEL` selects `stable` (default), `beta`, or `nightly` for
the 1Password package. Match that Mac's current release channel. Newer beta or
nightly data can require a newer app than the stable package; changing the
package channel does not downgrade the saved data. Keep this choice in the
ignored `setup.env` so another Mac can use a different channel.

## 2. Bootstrap

```sh
xcode-select --install

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install --cask 1password 1password-cli codex chatgpt

mkdir -p "$HOME/_git"
git clone https://github.com/u29dc/dot.git "$HOME/_git/dot"
cd "$HOME/_git/dot"
cp setup.env.example setup.env
```

`$HOME/_git/dot` is the suggested checkout location, not a runtime requirement.
Setup derives the repository root from `scripts/setup.sh`, so the checkout can
live elsewhere and the script can be invoked from any working directory.

Open and sign in to 1Password and ChatGPT, then select Codex before continuing.

## 3. Agent Prompt

If using Codex on the new machine:

```text
Open the cloned dotfiles repository.
Read AGENTS.md and SETUP.md.
Interview me for setup.env values.
Run a dry run before applying setup.
Do not enable Git or 1Password rendering until the 1Password SSH items exist and the GitHub public keys are registered.
```

Required answers: machine label, shell, Brewfiles, Git name/email, 1Password vault, SSH auth item, SSH signing item, public signing key, local cloud paths, extra skill paths, and feature toggles.

## 4. First Setup

Use this first-pass shape when SSH items are not ready:

```sh
DOT_BREWFILES="homebrew/Brewfile.primary:homebrew/Brewfile.personal"
DOT_DEFAULT_SHELL=fish

DOT_ENABLE_DIA=1
DOT_ENABLE_ONEPASSWORD=0
DOT_ENABLE_SYSTEM_EXTENSIONS=1
DOT_ENABLE_CODEX_CONFIG=1
DOT_ENABLE_GIT_CONFIG=0

DOT_DROPBOX_HOME=""
DOT_VAULT_HOME=""
DOT_GDRIVE_HOME=""
DOT_SKILL_SOURCES=""
```

Preview, then apply:

```sh
./scripts/setup.sh --dry-run --no-brew
./scripts/setup.sh
```

Restart the terminal after setup. Fish is the default when `DOT_DEFAULT_SHELL=fish`; Zsh remains available with `zsh`.

## 5. SSH And Signing

Use one SSH authentication key and one SSH signing key per machine.

Suggested 1Password item names:

```text
GitHub SSH Auth YYYY-MM MACHINE
GitHub SSH Sign YYYY-MM MACHINE
```

In 1Password, enable the SSH agent and create both SSH key items. In GitHub, add the auth public key as an authentication key and the signing public key as a signing key. GitHub requires separate registrations even if one key is reused; this setup prefers two keys.

## 6. Final Env

After the 1Password items exist and GitHub has the public keys:

```sh
DOT_ENABLE_ONEPASSWORD=1
DOT_ENABLE_GIT_CONFIG=1

DOT_GIT_USER_NAME="Your Name"
DOT_GIT_USER_EMAIL="your verified GitHub email"
DOT_GIT_SIGNING_KEY="ssh-ed25519 AAAA... signing-public-key ..."
DOT_GIT_ALLOWED_SIGNER_PRINCIPALS="old@example.com,your verified GitHub email"
DOT_GIT_ALLOWED_SIGNERS_FILE="$HOME/.config/git/allowed-signers"

DOT_OP_VAULT="Private"
DOT_OP_SSH_AUTH_ITEM="GitHub SSH Auth YYYY-MM MACHINE"
DOT_OP_SSH_SIGN_ITEM="GitHub SSH Sign YYYY-MM MACHINE"
```

`DOT_GIT_SIGNING_KEY` is the public signing key line, not the 1Password item name, fingerprint, or private key. `DOT_GIT_ALLOWED_SIGNER_PRINCIPALS` optionally accepts comma-separated historical and current commit emails for the same key; when blank, it defaults to `DOT_GIT_USER_EMAIL`.

Optional local paths:

```sh
DOT_CLOUDSTORAGE_HOME="$HOME/Library/CloudStorage"
DOT_DROPBOX_HOME="$DOT_CLOUDSTORAGE_HOME/Dropbox"
DOT_VAULT_HOME="$DOT_DROPBOX_HOME/<vault-folder>"
DOT_GDRIVE_HOME=""
DOT_SKILL_SOURCES="$HOME/path/to/skills:$HOME/other/skill"
```

Leave unavailable paths blank.
Use `:` between multiple sources. A source can be a standalone skill, a complete plugin, or a parent folder containing either. Plugin manifests take precedence over `SKILL.md`. Default `DOT_PLUGIN_MODE=link` symlinks the complete plugin root into the host skill directories, preserving sibling skills and shared resources. Source edits are available without copying or packaging; an already-running host may need skill discovery reloaded. Previously enabled `dot-local-<name>` snapshots for configured sources are disabled with settings backups. Claude reserves disabled installation names, so its user snapshots are backed up and unregistered through its CLI with persistent data preserved. Other plugin choices remain unchanged. Codex discovers the nested skills; Claude supports whole plugins in its skills directory. Host connection settings remain separate. Standalone skills keep their existing symlink behavior.

For agent-only maintenance without Homebrew, shell, or system setup:

```sh
/bin/bash scripts/plugins.sh --dry-run
/bin/bash scripts/plugins.sh
```

Both commands read configured sources from `setup.env`; `--env-file PATH` selects another local configuration. No MCP authentication or application restart is performed.

For an intentional packaged installation, set `DOT_PLUGIN_MODE=package` and remove the corresponding live root links first. Host catalogs are generated under `~/.local/share/dot/plugins/<host>/` and registered through the Codex and Claude CLIs. A source's `build/package.py --format codex|claude --output DIR` supplies its host package when present, with `scripts/package.py` supported for older sources; other complete plugins are copied intact. Previous catalogs are retained. Local manifests receive a `+local.<content-digest>` suffix while canonical versions stay unchanged. Matching installed content skips reinstallation. Changed content uses Claude's plugin update or Codex's plugin add and verifies the installed version. Packaged mode requires this refresh after source edits; it does not provide live source links.

Codex and Claude settings are generated local files. Shared preferences override matching preferences; runtime plugin selections and marketplace registrations retain their live values, with template entries supplying missing defaults. Model choices (`model`, plus Codex reasoning effort and service tier) are only seeded on a new machine, so in-app model changes survive setup. Existing MCP server entries, including the ChatGPT-managed `node_repl`, belong to the apps. Other local state, including Codex trusted projects, is preserved. Settings are rewritten only when the merge changes them, and are backed up first. Claude settings are no longer symlinked into tracked JSON, so plugin registration cannot write private paths into the repository.

## 7. Final Setup

```sh
./scripts/setup.sh --dry-run --no-brew
./scripts/setup.sh
./scripts/doctor.sh
```

Switch this repo to SSH after GitHub SSH works:

```sh
ssh -T git@github.com
git remote set-url origin git@github.com:u29dc/dot.git
```

Apply macOS preferences once; `--audit` previews every change without sudo:

```sh
~/.macos --audit
~/.macos
```

## 8. Verify

```sh
printf 'login shell: %s\n' "$SHELL"
fish --version
zsh --version

ssh-add -l
ssh -T git@github.com

git config --global --get user.name
git config --global --get user.email
git config --global --get user.signingkey

test -f ~/.codex/config.toml && echo "codex config exists"

agent-browser-dia-status
agent-browser-dia-on
agent-browser-dia get cdp-url
```

Optional signing smoke test:

```sh
git commit --allow-empty -m "test: verify signing"
git log --show-signature -1
git reset --soft HEAD~1
git reset
```

`agent-browser-dia open URL` navigates the controlled tab. To create a new tab:

```sh
agent-browser-dia tab new about:blank
```

## 9. Updating Another Mac

Commit and push shared repository changes from either Mac. Each Mac keeps its
own ignored `setup.env`, `homebrew/Brewfile.local`, and shell secrets. A pull
updates shared files without replacing those local files. Setup reads that
Mac's `setup.env` and never rewrites it. The filename is `setup.env`; `.env` is
also ignored, but setup does not read it automatically.

On the other Mac, run these commands from its existing checkout:

```sh
git status --short
git pull --ff-only
./scripts/setup.sh --dry-run --no-brew
./scripts/setup.sh
./scripts/doctor.sh
```

For config changes only, use `./scripts/setup.sh --no-brew`. Restart the shell
after setup so it loads the regenerated environment. Shared symlinked config
changes are visible after pulling; new links, generated settings, and packages
are applied by setup.

If the other Mac still has the uncommitted edits copied into this repository,
save them once before pulling:

```sh
git stash push --include-untracked -m "dot before shared update"
git pull --ff-only
```

This keeps ignored machine files in place. Keep the stash as a recovery copy;
the copied shared edits are already in the incoming commit. Check it for any
additional edits before deciding whether anything needs to be reapplied.

For a company Mac, keep its cloud paths, skill sources, and key choices in its
own `setup.env`. Select only the shared baseline unless it needs local extras:

```sh
DOT_BREWFILES="homebrew/Brewfile.primary"
# With company-specific extras in homebrew/Brewfile.local:
# DOT_BREWFILES="homebrew/Brewfile.primary:homebrew/Brewfile.local"
```

An older env that selects only `homebrew/Brewfile.local` keeps using that file;
it does not receive the shared package updates. Switch it to the shared layer
and keep only additional packages in the local layer. Until that Mac has its
own Git signing and 1Password SSH keys configured, use
`DOT_ENABLE_GIT_CONFIG=0` and `DOT_ENABLE_ONEPASSWORD=0`.

## 10. Recovery

If setup validation fails, fix the named variable in `setup.env`. If setup stops
because a cask replaces a conflicting installed cask (for example `ghostty` to
`ghostty@tip`), run the printed `brew uninstall`/`brew install` pair once, then
rerun setup.

```sh
./scripts/setup.sh --dry-run --no-brew
./scripts/setup.sh --no-brew
```

SSH checks:

```sh
ssh-add -l
cat ~/.ssh/config
cat ~/.config/1Password/ssh/agent.toml
ssh -T git@github.com
```

Git signing checks:

```sh
git config --global --get gpg.format
git config --global --get gpg.ssh.program
git config --global --get gpg.ssh.allowedSignersFile
git config --global --get user.signingkey
cat ~/.config/git/allowed-signers
```

## 11. Safety

- Clone over HTTPS first; switch to SSH only after keys work.
- Do not commit `setup.env`.
- Do not commit private keys, tokens, auth state, local Codex state, machine IDs, Dropbox paths, or personal vault contents.
- Do not overwrite existing human app profiles casually.
- Do not reset the normal Dia profile.
- Use dry-run before applying setup on a new machine.

The agent plugin/configuration workflow runs Python through `uv run --no-project --python ">=3.11"`; Homebrew setup includes `uv`. Subprocess helpers reuse that selected interpreter.
