#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
# Managed file inventory shared by setup.sh and doctor.sh. Rows are
# pipe-separated; sources are relative to DOTFILES_DIR, and a condition is the
# name of a 0/1 setup variable or "-" for always.
#
# biome.json and tsconfig.json are shared base configs: other repositories
# "extends" them through ~/.config/biome and ~/.config/typescript (or ../dot),
# so neither tool reading those paths on its own does not make them unused.

# section|condition|source|destination
dot_link_targets() {
    printf '%s|%s|%s|%s\n' \
        shell - shell/zsh/zshrc "$HOME/.zshrc" \
        shell - shell/zsh/zprofile "$HOME/.zprofile" \
        shell - shell/fish/config.fish "$HOME/.config/fish/config.fish" \
        shell - shell/fish/functions.fish "$HOME/.config/fish/functions.fish" \
        terminal - terminal/starship-dark.toml "$HOME/.config/starship/starship-dark.toml" \
        terminal - terminal/starship-light.toml "$HOME/.config/starship/starship-light.toml" \
        terminal - terminal/bottom.toml "$HOME/.config/bottom/bottom.toml" \
        terminal - terminal/atuin.toml "$HOME/.config/atuin/config.toml" \
        terminal - terminal/bat "$HOME/.config/bat/config" \
        terminal - terminal/ignore "$HOME/.ignore" \
        terminal - terminal/fastfetch.jsonc "$HOME/.config/fastfetch/config.jsonc" \
        terminal - terminal/statusline "$HOME/.config/ccstatusline/settings.json" \
        terminal - terminal/ghostty "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
        terminal - terminal/yt-dlp "$HOME/.config/yt-dlp/config" \
        terminal - terminal/agent-browser.chrome.json "$HOME/.agent-browser/chrome.json" \
        terminal - bunfig.toml "$HOME/.bunfig.toml" \
        terminal - uv.toml "$HOME/.config/uv/uv.toml" \
        terminal - biome.json "$HOME/.config/biome/biome.json" \
        terminal - tsconfig.json "$HOME/.config/typescript/tsconfig.json" \
        editor - editor/settings.json "$HOME/.config/zed/settings.json" \
        editor - editor/keymap.json "$HOME/.config/zed/keymap.json" \
        system - system/gitignore "$HOME/.config/git/ignore" \
        system DOT_ENABLE_SYSTEM_EXTENSIONS system/karabiner "$HOME/.config/karabiner" \
        system DOT_ENABLE_SYSTEM_EXTENSIONS macos/.macos "$HOME/.macos" \
        agents - agents/AGENTS.md "$HOME/.claude/CLAUDE.md" \
        agents - agents/AGENTS.md "$HOME/.codex/AGENTS.md"
}

# section|condition|template|destination|label
dot_render_targets() {
    printf '%s|%s|%s|%s|%s\n' \
        terminal - terminal/ssh.template "$HOME/.ssh/config" "SSH config" \
        terminal - terminal/agent-browser.json.template "$HOME/.agent-browser/config.json" "agent-browser Dia config" \
        system DOT_ENABLE_GIT_CONFIG system/gitconfig.template "$HOME/.gitconfig" "Git config" \
        system DOT_ENABLE_GIT_CONFIG system/git-allowed-signers.template "$DOT_GIT_ALLOWED_SIGNERS_FILE" "Git allowed signers" \
        system DOT_ENABLE_ONEPASSWORD system/1password.agent.toml.template "$HOME/.config/1Password/ssh/agent.toml" "1Password SSH agent" \
        system DOT_ENABLE_DIA system/launchagents/com.u29dc.dia-cdp.plist.template "$HOME/Library/LaunchAgents/com.u29dc.dia-cdp.plist" "Dia CDP LaunchAgent"
}

# Retired destinations: source prefix|destination. Links that still point into
# the prefix are removed, then their directory if it became empty.
dot_legacy_targets() {
    printf '%s|%s\n' \
        terminal "$HOME/.config/neofetch/config.conf"
}

dot_target_enabled() {
    [ "$1" = - ] || dot_truthy "${!1:-0}"
}
