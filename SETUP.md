# SETUP

Fresh macOS setup runbook for this dotfiles repository. Use it directly or ask an agent to follow it.

Setup is staged because a fresh Mac does not yet have Homebrew, 1Password SSH keys, Git signing, Dropbox paths, Codex state, or optional skill folders.

## 1. Order

```text
macOS
 -> Apple command line tools
 -> Homebrew
 -> 1Password and Codex
 -> clone this repo over HTTPS
 -> create setup.env
 -> first setup pass
 -> create or import SSH keys
 -> register GitHub keys
 -> final setup pass
 -> verification
```

`setup.env` is the single machine-local form. Create it from `setup.env.example`. It is ignored and must not be committed.

## 2. Bootstrap

```sh
xcode-select --install

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install --cask 1password 1password-cli codex codex-app

mkdir -p ~/Git
git clone https://github.com/u29dc/dot.git ~/Git/dot
cd ~/Git/dot
cp setup.env.example setup.env
```

Open and sign in to 1Password and Codex before continuing.

## 3. Agent Prompt

If using Codex on the new machine:

```text
Open ~/Git/dot.
Read AGENTS.md and SETUP.md.
Interview me for setup.env values.
Run a dry run before applying setup.
Do not enable Git or 1Password rendering until the 1Password SSH items exist and the GitHub public keys are registered.
```

Required answers: machine label, shell, Brewfiles, Git name/email, 1Password vault, SSH auth item, SSH signing item, public signing key, local cloud paths, extra skill paths, and feature toggles.

## 4. First Setup

Use this first-pass shape when SSH items are not ready:

```sh
DOT_BREWFILES="homebrew/Brewfile.primary"
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
bash ~/Git/dot/scripts/setup.sh --dry-run --no-brew
bash ~/Git/dot/scripts/setup.sh
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
DOT_GIT_ALLOWED_SIGNERS_FILE="$HOME/.config/git/allowed-signers"

DOT_OP_VAULT="Private"
DOT_OP_SSH_AUTH_ITEM="GitHub SSH Auth YYYY-MM MACHINE"
DOT_OP_SSH_SIGN_ITEM="GitHub SSH Sign YYYY-MM MACHINE"
```

`DOT_GIT_SIGNING_KEY` is the public signing key line, not the 1Password item name, fingerprint, or private key.

Optional local paths:

```sh
DOT_CLOUDSTORAGE_HOME="$HOME/Library/CloudStorage"
DOT_DROPBOX_HOME="$DOT_CLOUDSTORAGE_HOME/Dropbox"
DOT_VAULT_HOME="$DOT_DROPBOX_HOME/<vault-folder>"
DOT_GDRIVE_HOME=""
DOT_SKILL_SOURCES="$HOME/path/to/skills:$HOME/other/skills"
```

Leave unavailable paths blank.

## 7. Final Setup

```sh
bash ~/Git/dot/scripts/setup.sh --dry-run --no-brew
bash ~/Git/dot/scripts/setup.sh
~/Git/dot/scripts/doctor.sh
```

Switch this repo to SSH after GitHub SSH works:

```sh
cd ~/Git/dot
ssh -T git@github.com
git remote set-url origin git@github.com:u29dc/dot.git
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

## 9. Recovery

If setup validation fails, fix the named variable in `setup.env`.

```sh
bash ~/Git/dot/scripts/setup.sh --dry-run --no-brew
bash ~/Git/dot/scripts/setup.sh --no-brew
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

## 10. Safety

- Clone over HTTPS first; switch to SSH only after keys work.
- Do not commit `setup.env`.
- Do not commit private keys, tokens, auth state, local Codex state, machine IDs, Dropbox paths, or personal vault contents.
- Do not overwrite existing human app profiles casually.
- Do not reset the normal Dia profile.
- Use dry-run before applying setup on a new machine.
