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
sandbox --ro                      # read-only mount (rsyncs to VM-local)
sandbox -e "claude 'fix tests'"   # run command, auto-cleanup after
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

## What persists vs. ephemeral

Persists (in `sandbox-dev` base image):

- Homebrew packages, CLI tools
- Auth: `gh auth`, `claude login`, `codex login`, `amp login`
- API keys in `~/.zshrc.local`
- SSH keys, git config, shell config, dotfile symlinks

Ephemeral (destroyed on `exit`):

- The ephemeral clone
- Files written outside the mounted workspace
- VM-local artifact caches

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
# Follow manual steps printed at the end (gh auth, claude login, API keys, etc.)
sudo shutdown -h now
```

## Files in this directory

- `vm-setup.sh` -- one-time provisioning script for the base image
- `Brewfile` -- headless CLI packages (no casks, no media tools)
- `gitconfig` -- git config without 1Password signing
- `ssh-config` -- SSH config without 1Password agent

