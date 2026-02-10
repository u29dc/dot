# VM Sandbox

Tart-based macOS VM for running agentic tools (Claude Code, Codex, AMP) with full permissions inside a contained environment. Host keeps minimal permissions.

## Daily workflow

```bash
cd ~/Git/some-project
sandbox
# now inside VM at ~/workspace
claude          # aliased to claude --dangerously-skip-permissions
exit            # VM auto-cleaned up
```

## Options

```bash
sandbox ~/Git/other-project       # mount specific path
sandbox --ro                      # read-only mount (rsyncs to VM-local, excludes .git for speed)
sandbox --ro-git                  # read-only mount + include .git (slower, better git tooling support)
sandbox -e "claude 'fix tests'"   # run command, auto-cleanup after
sandbox --doctor                  # run host + VM smoke checks
sandbox -n sandbox-a              # named VM (for concurrent runs)
sandbox -s                        # stop running sandbox
sandbox -s -n sandbox-a           # stop a named one
sandbox -r                        # reset (delete + fresh clone + start)
```

## Architecture

```
Host                              VM (ephemeral APFS clone)
~/Git/project  ──VirtioFS──>  ~/workspace (symlink to /Volumes/My Shared Files/workspace)
                               ~/local/<hash>/node_modules
                               ~/local/<hash>/.next
                               ~/local/<hash>/.svelte-kit
                               ~/local/<hash>/.venv
```

Edits flow both directions instantly. Heavy artifact dirs (node_modules, .next, etc.) are symlinked to VM-local APFS for performance.

## Security model

- Host OS isolation: strong. Agents run inside ephemeral VM clones, not on host.
- Project data isolation: partial by design. Default mode mounts host project read/write for fast iteration.
- Read-only mode: use `--ro` / `--ro-git` when you want containment without host writes.
- VM SSH host checking from host helper uses ephemeral trust settings (local Tart workflow convenience).
- `claude` alias uses `--dangerously-skip-permissions` inside VM only; VM boundary is the safety control.

## Health checks

Run this from host:

```bash
sandbox --doctor
```

Checks included:

- Host prerequisites: `tart`, `ssh`, `gh`, base image presence, sandbox key presence/permissions.
- In-VM smoke test: `gh auth`, SSH GitHub auth handshake, git signing config, signing key presence.

## What persists vs. ephemeral

Persists (in `sandbox-dev` base image):

- Homebrew packages, CLI tools
- Auth: `gh auth`, `claude login`, `codex login`, `amp login`
- API keys in `~/.zshrc.local`
- SSH keys, git config, shell config, dotfile symlinks
- SSH signing key: `~/.ssh/id_ed25519_signing_agent` (for verified commits)

Ephemeral (destroyed on `exit`):

- The ephemeral clone
- Files written outside the mounted workspace
- VM-local artifact caches

## Verified commits in VM (non-interactive)

This setup supports verified commits without Touch ID prompts:

- Push auth: `gh auth login` + `gh auth setup-git` (HTTPS credentials).
- Commit signing: SSH signing key at `~/.ssh/id_ed25519_signing_agent`.
- Git config in VM enables SSH commit signing by default.

One-time action after provisioning:

1. Copy `~/.ssh/id_ed25519_signing_agent.pub`.
2. Add it in GitHub: `Settings -> SSH and GPG keys -> New SSH signing key`.

Security note:

- This key is for signing only, not SSH auth.
- It is non-interactive by design; treat the VM base image as sensitive and rotate key if leaked.

## Key/token rotation runbook

Use this if credentials expire or you suspect compromise.

1. Revoke compromised credentials in GitHub:
   - Remove stale SSH auth keys.
   - Remove stale SSH signing keys.
   - Revoke stale PATs (if any).
2. Boot base image and rotate VM signing key:
   - `tart run sandbox-dev --no-graphics --dir=dotfiles:~/Git/dot`
   - SSH in and run:
   - `rm -f ~/.ssh/id_ed25519_signing_agent ~/.ssh/id_ed25519_signing_agent.pub`
   - `bash "/Volumes/My Shared Files/dotfiles/vm/vm-setup.sh"`
3. Add new signing key to GitHub:
   - Copy `~/.ssh/id_ed25519_signing_agent.pub`
   - Add at `Settings -> SSH and GPG keys -> New SSH signing key`
4. Refresh GH auth in VM:
   - `gh auth login -h github.com`
   - `gh auth setup-git`
5. Validate:
   - `sandbox --doctor`
   - Create/push a test commit and confirm `Verified` badge.
6. Shutdown base image:
   - `sudo shutdown -h now`

## Updating the base image

```bash
tart run sandbox-dev --no-graphics --dir=dotfiles:~/Git/dot
# SSH in via: ssh admin@$(tart ip sandbox-dev)
# update packages, re-run setup, etc.
sudo shutdown -h now
```

All future `sandbox` clones inherit the updates.

## Initial provisioning

One-time setup for a fresh base image. Already done if you're reading this.

```bash
tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest sandbox-dev
tart run sandbox-dev --no-graphics --dir=dotfiles:$HOME/Git/dot
# SSH in, then:
bash "/Volumes/My Shared Files/dotfiles/vm/vm-setup.sh"
# Follow manual steps printed at the end (gh auth, agent logins, GitHub signing key, API keys)
sudo shutdown -h now
```

## Files in this directory

- `vm-setup.sh` -- one-time provisioning script for the base image
- `Brewfile` -- headless CLI packages (no casks, no media tools)
- `gitconfig` -- git config with SSH commit signing (no 1Password dependency)
- `ssh-config` -- SSH config without 1Password agent
- `sandbox_key` -- host->VM SSH private key generated during provisioning (gitignored, local secret)
