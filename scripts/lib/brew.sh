#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

install_homebrew() {
    local installer
    installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return $?
    /bin/bash -c "$installer"
}

install_brewfile() {
    local file="$1"
    if brew bundle check --no-upgrade --file="$file" >/dev/null; then
        dot_progress_ok "Homebrew layer satisfied: ${file#"$DOTFILES_DIR"/}"
        return 0
    fi

    dot_progress_run_step --stream "Installing ${file#"$DOTFILES_DIR"/}" brew bundle install --no-upgrade --file="$file"
}
