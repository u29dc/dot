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
set -q CARGO_HOME; or set -gx CARGO_HOME "$HOME/.cargo"

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

# Runtime PATH. One ordered call preserves Zsh parity while --path avoids
# mutating Fish universal variables.
fish_add_path --path --move \
    "$HOME/.bun/bin" \
    "$HOME/bin" \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    "$HOME/.local/bin" \
    "$CARGO_HOME/bin" \
    "/Applications/Obsidian.app/Contents/MacOS"

if test -f "$HOME/.config/fish/functions.fish"
    source "$HOME/.config/fish/functions.fish"
else if test -f "$DOTFILES_DIR/shell/fish/functions.fish"
    source "$DOTFILES_DIR/shell/fish/functions.fish"
end

set -g fish_greeting
functions -q starship_theme; and starship_theme

function _dot_source_cached_init --argument-names cache_name command_name
    set -l cmd_args $argv[3..-1]
    set -l bin_path (command -s "$command_name" 2>/dev/null)
    test -n "$bin_path"; or return 0

    set -l cache_dir "$HOME/.cache/dot/shell"
    if set -q XDG_CACHE_HOME
        set cache_dir "$XDG_CACHE_HOME/dot/shell"
    end

    set -l cache_file "$cache_dir/$cache_name.fish"
    mkdir -p "$cache_dir"; or return 0

    if not test -s "$cache_file"; or test "$bin_path" -nt "$cache_file"
        set -l temp_file "$cache_file.$fish_pid.tmp"

        if command "$command_name" $cmd_args >"$temp_file" 2>/dev/null
            command mv -f "$temp_file" "$cache_file"
        else
            command rm -f "$temp_file"
        end
    end

    test -s "$cache_file"; and source "$cache_file"
end

if status is-interactive
    _dot_source_cached_init zoxide-init zoxide init fish
    _dot_source_cached_init atuin-init atuin init fish
    if test "$TERM" != dumb
        _dot_source_cached_init starship-init starship init fish
    end
    _dot_source_cached_init uv-completion uv generate-shell-completion fish

    if test -f "$HOME/.config/broot/launcher/fish/br"
        source "$HOME/.config/broot/launcher/fish/br"
    end
end

if test -f "$HOME/.config/fish/local.fish"
    source "$HOME/.config/fish/local.fish"
end
