# Fish entrypoint. Keep this compact and source shared functions from
# ~/.config/fish/functions.fish.

# Dotfiles checkout and machine-local setup facts. setup.sh renders env.fish
# from setup.env; fallback values keep Fish usable before setup has run.
set -q DOTFILES_DIR; or set -gx DOTFILES_DIR "$HOME/Git/dot"
set -q DOT_ENV_FILE; or set -gx DOT_ENV_FILE "$DOTFILES_DIR/setup.env"
set -q DOT_FISH_ENV_FILE; or set -gx DOT_FISH_ENV_FILE "$HOME/.config/dot/env.fish"

if test -f "$DOT_FISH_ENV_FILE"
    source "$DOT_FISH_ENV_FILE"
end

set -q TOOLS_HOME; or set -gx TOOLS_HOME "$HOME/.tools"
set -q SKILLS_BASE; or set -gx SKILLS_BASE "$DOTFILES_DIR/agents/skills"

set -q BUF_HOME; or set -gx BUF_HOME "$TOOLS_HOME/buf"
set -q CHO_HOME; or set -gx CHO_HOME "$TOOLS_HOME/cho"
set -q FIN_HOME; or set -gx FIN_HOME "$TOOLS_HOME/fin"
set -q GRN_HOME; or set -gx GRN_HOME "$TOOLS_HOME/grn"
set -q LET_HOME; or set -gx LET_HOME "$TOOLS_HOME/let"
set -q PDF_HOME; or set -gx PDF_HOME "$TOOLS_HOME/pdf"
set -q TAO_HOME; or set -gx TAO_HOME "$TOOLS_HOME/tao"

set -q BUF; or set -gx BUF "$BUF_HOME/buf"
set -q CHO; or set -gx CHO "$CHO_HOME/cho"
set -q FIN; or set -gx FIN "$FIN_HOME/fin"
set -q GRN; or set -gx GRN "$GRN_HOME/grn"
set -q LET; or set -gx LET "$LET_HOME/let"
set -q PDF; or set -gx PDF "$PDF_HOME/pdf"
set -q TAO; or set -gx TAO "$TAO_HOME/tao"

set -q HOMEBREW_NO_ENV_HINTS; or set -gx HOMEBREW_NO_ENV_HINTS 1
set -q BAT_PAGER; or set -gx BAT_PAGER ""
set -q BAT_STYLE; or set -gx BAT_STYLE "numbers,changes"
set -q EZA_DEFAULT_IGNORE; or set -gx EZA_DEFAULT_IGNORE "node_modules|.cache|cache|dist|build|.next|.nuxt|.turbo|coverage|.pytest_cache|__pycache__|.venv|venv|.env"

# Runtime PATH. Use --path so setup remains declarative instead of mutating Fish
# universal variables.
fish_add_path --path --move "$HOME/.bun/bin"
fish_add_path --path --move "$HOME/bin"
fish_add_path --path --move /opt/homebrew/bin
fish_add_path --path --move /opt/homebrew/sbin
fish_add_path --path --move "$HOME/.local/bin"
fish_add_path --path --move "/Applications/Obsidian.app/Contents/MacOS"

if test -f "$HOME/.config/fish/functions.fish"
    source "$HOME/.config/fish/functions.fish"
else if test -f "$DOTFILES_DIR/shell/fish/functions.fish"
    source "$DOTFILES_DIR/shell/fish/functions.fish"
end

set -g fish_greeting
functions -q starship_theme; and starship_theme

if status is-interactive
    command -q zoxide; and zoxide init fish | source
    command -q atuin; and atuin init fish | source
    if test "$TERM" != dumb
        command -q starship; and starship init fish | source
    end
    command -q uv; and uv generate-shell-completion fish | source

    if test -f "$HOME/.config/broot/launcher/fish/br"
        source "$HOME/.config/broot/launcher/fish/br"
    end
end

if test -f "$HOME/.config/fish/local.fish"
    source "$HOME/.config/fish/local.fish"
end
