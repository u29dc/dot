#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

install_homebrew() {
    local installer
    installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return $?
    /bin/bash -c "$installer"
}

# brew bundle list is slow; read each layer's entries once per run.
load_brewfile_entries() {
    local file="$1"

    [ "${DOT_BREWFILE_LOADED:-}" = "$file" ] && return 0
    DOT_BREWFILE_FORMULAE="$(brew bundle list --formula --file="$file" 2>/dev/null || true)"
    DOT_BREWFILE_CASKS="$(brew bundle list --cask --file="$file" 2>/dev/null || true)"
    DOT_BREWFILE_LOADED="$file"
}

brewfile_has_formula() {
    load_brewfile_entries "$1"
    printf '%s\n' "$DOT_BREWFILE_FORMULAE" | grep -Fxq "$2"
}

brewfile_has_cask() {
    load_brewfile_entries "$1"
    printf '%s\n' "$DOT_BREWFILE_CASKS" | grep -Fxq "$2"
}

brew_formula_installed() {
    brew list --formula "$1" >/dev/null 2>&1
}

# Conflicting casks cannot be swapped by brew bundle. Swapping an app such as a
# running terminal is left to the user, so setup stops with the exact commands.
require_cask_migration() {
    local file="$1"
    local obsolete="$2"
    local replacement="$3"

    brewfile_has_cask "$file" "$replacement" || return 0
    brew list --cask "$obsolete" >/dev/null 2>&1 || return 0

    dot_progress_fail "Cask $replacement replaces the installed, conflicting cask $obsolete"
    dot_progress_info "Run once, ideally from Terminal.app, then rerun setup (app settings are kept):"
    dot_progress_info "  brew uninstall --cask $obsolete && brew install --cask $replacement"
    return 1
}

restore_formula_link() {
    local obsolete="$1"
    local replacement="$2"

    brew unlink "$replacement" >/dev/null 2>&1 || true
    dot_progress_run_step --stream "Restoring Homebrew formula: $obsolete" brew link "$obsolete"
}

migrate_conflicting_formula() {
    local file="$1"
    local obsolete="$2"
    local replacement="$3"

    brewfile_has_formula "$file" "$replacement" || return 0
    brew_formula_installed "$obsolete" || return 0

    if brew_formula_installed "$replacement"; then
        dot_progress_run_step --stream "Unlinking Homebrew formula: $obsolete" brew unlink "$obsolete"
        if dot_progress_run_step --stream "Linking Homebrew formula: $replacement" brew link --overwrite "$replacement"; then
            return 0
        fi

        dot_progress_warn "Could not link $replacement; restoring $obsolete"
        restore_formula_link "$obsolete" "$replacement"
        return 1
    fi

    dot_progress_run_step --stream "Fetching Homebrew formula: $replacement" brew fetch "$replacement"
    dot_progress_run_step --stream "Unlinking Homebrew formula: $obsolete" brew unlink "$obsolete"
    if dot_progress_run_step --stream "Installing Homebrew formula: $replacement" brew install "$replacement"; then
        return 0
    fi

    dot_progress_warn "Could not install $replacement; restoring $obsolete"
    restore_formula_link "$obsolete" "$replacement"
    return 1
}

cleanup_obsolete_formula() {
    local file="$1"
    local obsolete="$2"
    local replacement="$3"

    brewfile_has_formula "$file" "$replacement" || return 0
    brew_formula_installed "$replacement" || return 0
    brew_formula_installed "$obsolete" || return 0

    dot_progress_run_step --stream "Removing obsolete Homebrew formula: $obsolete" brew uninstall "$obsolete"
}

prepare_brewfile_migrations() {
    local file="$1"

    require_cask_migration "$file" ghostty ghostty@tip || return 1
    migrate_conflicting_formula "$file" tldr tlrc
}

finish_brewfile_migrations() {
    local file="$1"

    cleanup_obsolete_formula "$file" neofetch fastfetch
    cleanup_obsolete_formula "$file" tldr tlrc
}

install_brewfile() {
    local file="$1"

    prepare_brewfile_migrations "$file" || return $?
    if brew bundle check --no-upgrade --file="$file" >/dev/null; then
        finish_brewfile_migrations "$file"
        dot_progress_ok "Homebrew layer satisfied: ${file#"$DOTFILES_DIR"/}"
        return 0
    fi

    dot_progress_run_step --stream "Installing ${file#"$DOTFILES_DIR"/}" brew bundle install --no-upgrade --file="$file" || return $?
    finish_brewfile_migrations "$file"
}
