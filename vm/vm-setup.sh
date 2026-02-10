#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# VM SETUP -- One-time provisioning for sandbox-dev base image
# ==============================================================================
#
# Run inside the VM with dotfiles mounted via VirtioFS:
#   bash "/Volumes/My Shared Files/dotfiles/vm/vm-setup.sh"
#
# After this script completes, manually run:
#   gh auth login
#   command claude login
#   codex login
#   amp login
#   # Add ~/.ssh/id_ed25519_signing_agent.pub as a GitHub SSH signing key
#   # Append API keys to ~/.zshrc.local
#   # Grant Full Disk Access to Terminal.app in System Settings
# ==============================================================================

DOTFILES_MOUNT="/Volumes/My Shared Files/dotfiles"

if [ ! -d "$DOTFILES_MOUNT" ]; then
    echo "[ERROR] Dotfiles mount not found at: $DOTFILES_MOUNT"
    echo "Boot the VM with: tart run sandbox-dev --dir=dotfiles:\$HOME/Git/dot"
    exit 1
fi

echo "Starting VM provisioning..."
echo

# 1. Install Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "[1/10] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[1/10] Homebrew already installed"
fi

# 2. Install packages from VM Brewfile
echo "[2/10] Installing Homebrew packages..."
brew bundle install --file="$DOTFILES_MOUNT/vm/Brewfile"
echo

# 3. Clone dotfiles to ~/Git/dot
echo "[3/10] Cloning dotfiles..."
mkdir -p "$HOME/Git"
if [ -d "$HOME/Git/dot" ]; then
    echo "  dotfiles already cloned at ~/Git/dot"
else
    git clone https://github.com/u29dc/dot.git "$HOME/Git/dot"
fi

# 3b. Sync latest changes from mount to clone (preserve .git)
rsync -a --exclude='.git' "$DOTFILES_MOUNT/" "$HOME/Git/dot/"

# 4. Run setup from clone (so symlinks point to ~/Git/dot/...)
echo "[4/10] Linking dotfiles (VM mode)..."
bash "$HOME/Git/dot/scripts/setup.sh" --vm --link-only

# 5. Generate SSH key
echo "[5/10] Generating SSH key..."
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo "  SSH key already exists"
else
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "sandbox@vm"
    echo "  Public key:"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

# 5b. Authorize host SSH access (key-based)
echo "[5b/10] Setting up sandbox SSH key for host access..."
if [ ! -f "$DOTFILES_MOUNT/vm/sandbox_key" ]; then
    SANDBOX_KEY="/tmp/sandbox_key"
    ssh-keygen -t ed25519 -f "$SANDBOX_KEY" -N "" -C "sandbox-host"
    mkdir -p "$HOME/.ssh"
    cat "${SANDBOX_KEY}.pub" >> "$HOME/.ssh/authorized_keys"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/authorized_keys"
    cp "$SANDBOX_KEY" "$DOTFILES_MOUNT/vm/sandbox_key"
    chmod 600 "$DOTFILES_MOUNT/vm/sandbox_key"
    rm "$SANDBOX_KEY" "${SANDBOX_KEY}.pub"
else
    echo "  Sandbox SSH key already provisioned"
fi

# 5c. Generate SSH signing key for non-interactive verified commits
echo "[5c/10] Generating SSH signing key..."
SIGNING_KEY="$HOME/.ssh/id_ed25519_signing_agent"
if [ -f "$SIGNING_KEY" ]; then
    echo "  Signing key already exists"
else
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$SIGNING_KEY" -N "" -C "sandbox-signing@vm"
fi
echo "  Signing public key:"
cat "${SIGNING_KEY}.pub"
echo "  Add this key in GitHub: Settings -> SSH and GPG keys -> New SSH signing key"

# 6. Configure git credential helper for HTTPS
echo "[6/10] Setting up git credential helper..."
if gh auth status &>/dev/null; then
    gh auth setup-git
else
    echo "  [SKIP] gh not authenticated yet -- run 'gh auth setup-git' after 'gh auth login'"
fi

# 7. Create workspace symlink and local directory
echo "[7/10] Creating workspace and local directories..."
mkdir -p "$HOME/local"
if [ ! -e "$HOME/workspace" ]; then
    ln -s "/Volumes/My Shared Files/workspace" "$HOME/workspace"
fi

# 8. Set hostname
echo "[8/10] Setting hostname..."
sudo scutil --set HostName sandbox
sudo scutil --set LocalHostName sandbox
sudo scutil --set ComputerName sandbox

# 8b. Harden SSH (disable password auth)
echo "[8b/10] Hardening SSH..."
sudo sed -i '' 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i '' 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# 9. Install Claude Code globally
echo "[9/10] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

# 10. Write shell aliases and env vars to ~/.zshrc.local
echo "[10/10] Writing sandbox shell config..."
if ! grep -q "Sandbox VM aliases" "$HOME/.zshrc.local" 2>/dev/null; then
    cat >> "$HOME/.zshrc.local" << 'EOF'

# Sandbox VM aliases
alias claude='claude --dangerously-skip-permissions'

# VM-local caches (fast APFS instead of VirtioFS)
export CARGO_TARGET_DIR="$HOME/local/cargo-target"
export BUN_INSTALL_CACHE_DIR="$HOME/local/bun-cache"
EOF
    echo "  sandbox config written to ~/.zshrc.local"
else
    echo "  sandbox config already present in ~/.zshrc.local"
fi

echo
echo "VM provisioning complete."
echo
echo "Next steps (manual):"
echo "  1. gh auth login"
echo "  2. command claude login / codex login / amp login"
echo "  3. Add ~/.ssh/id_ed25519_signing_agent.pub as GitHub SSH signing key"
echo "  4. Append API keys to ~/.zshrc.local"
echo "  5. Grant Full Disk Access to Terminal.app in System Settings"
echo "  6. sudo shutdown -h now"
