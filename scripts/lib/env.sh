#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

normalize_env_file_path() {
    local path="$1"
    local dir
    local base

    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *)
            dir="$(dirname "$path")"
            base="$(basename "$path")"
            if [ -d "$dir" ]; then
                printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
            else
                printf '%s/%s\n' "$(pwd -P)" "$path"
            fi
            ;;
    esac
}

load_env_file() {
    local path="$1"

    if [ ! -f "$path" ]; then
        dot_progress_fail "Setup env not found: $path"
        dot_progress_info "Create it from: cp setup.env.example setup.env"
        exit 2
    fi

    # shellcheck source=/dev/null
    set -a
    source "$path"
    set +a
    dot_progress_info "Loaded env: $path"
}

dot_default() {
    local name="$1"
    local value="$2"
    if [ -z "${!name+x}" ]; then
        printf -v "$name" '%s' "$value"
        export "${name?}"
    fi
}

initialize_setup_environment() {
    DOT_ENV_FILE="$(normalize_env_file_path "$DOT_ENV_FILE")"
    export DOT_ENV_FILE
    load_env_file "$DOT_ENV_FILE"

    dot_default DOT_BREWFILES "homebrew/Brewfile.primary"
    dot_default DOT_DEFAULT_SHELL "none"
    dot_default DOT_ENABLE_DIA 1
    dot_default DOT_ENABLE_ONEPASSWORD 0
    dot_default DOT_ENABLE_SYSTEM_EXTENSIONS 1
    dot_default DOT_ENABLE_CODEX_CONFIG 1
    dot_default DOT_ENABLE_GIT_CONFIG 0

    if [ -n "${DOT_TOOLS_HOME:-}" ] && [ -z "${TOOLS_HOME:-}" ]; then
        TOOLS_HOME="$DOT_TOOLS_HOME"
        export TOOLS_HOME
    fi

    dot_default TOOLS_HOME "$HOME/.tools"
    dot_default SKILLS_BASE "$DOTFILES_DIR/agents/skills"
    dot_default DOT_SKILL_SOURCES ""
    dot_default DOT_PRUNE_EXTRA_SKILLS 0
    dot_default DOT_SKILL_ROOTS_STATE "$HOME/.config/dot/extra-skill-roots"
    dot_default DOT_DIA_APP "/Applications/Dia.app"
    dot_default DOT_DIA_LOG_DIR "$HOME/Library/Logs"
    dot_default AGENT_BROWSER_DIA_PORT 9222
    dot_default CODEX_NODE_REPL_ENV_FILE "$HOME/.config/dot/codex-node-repl.env.toml"
    dot_default DOT_CODEX_NOTIFY_COMMAND "$HOME/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
    dot_default DOT_GIT_ALLOWED_SIGNERS_FILE "$HOME/.config/git/allowed-signers"

    BUF_HOME="$TOOLS_HOME/buf"
    CHO_HOME="$TOOLS_HOME/cho"
    FIN_HOME="$TOOLS_HOME/fin"
    GRN_HOME="$TOOLS_HOME/grn"
    LET_HOME="$TOOLS_HOME/let"
    PDF_HOME="$TOOLS_HOME/pdf"
    TAO_HOME="$TOOLS_HOME/tao"
    BUF="$BUF_HOME/buf"
    CHO="$CHO_HOME/cho"
    FIN="$FIN_HOME/fin"
    GRN="$GRN_HOME/grn"
    LET="$LET_HOME/let"
    PDF="$PDF_HOME/pdf"
    TAO="$TAO_HOME/tao"
    EZA_DEFAULT_IGNORE="node_modules|.cache|cache|dist|build|.next|.nuxt|.turbo|coverage|.pytest_cache|__pycache__|.venv|venv|.env"
    HOMEBREW_NO_ENV_HINTS=1
    BAT_PAGER=""
    BAT_STYLE="numbers,changes"

    DOT_RUN_ID="${DOT_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
    DOT_BACKUP_DIR="${DOT_BACKUP_DIR:-$HOME/.dotfiles-backups/$DOT_RUN_ID}"
    DOT_BACKUP_MANIFEST="$DOT_BACKUP_DIR/manifest.tsv"

    AGENT_BROWSER_DIA_APP="$DOT_DIA_APP"
    AGENT_BROWSER_DIA_BIN="$AGENT_BROWSER_DIA_APP/Contents/MacOS/Dia"
    AGENT_BROWSER_DIA_LAUNCH_AGENT="com.u29dc.dia-cdp"
}

dot_truthy() {
    [ "${1:-0}" = "1" ]
}

dot_dry_run() {
    [ "$DRY_RUN" = true ]
}

dot_apply() {
    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "$*"
        return 0
    fi

    "$@"
}

dot_require() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        dot_progress_fail "Missing required setup env: $name"
        return 1
    fi
}

dot_validate_bool() {
    local name="$1"
    case "${!name:-}" in
        0 | 1) ;;
        *)
            dot_progress_fail "$name must be 0 or 1"
            return 1
            ;;
    esac
}

dot_validate_port() {
    local name="$1"
    local value="${!name:-}"

    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le 65535 ]; then
        return 0
    fi

    dot_progress_fail "$name must be an integer TCP port from 1 to 65535"
    return 1
}

dot_abs_path() {
    local path="$1"
    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$DOTFILES_DIR" "$path" ;;
    esac
}

dot_each_colon_item() {
    local list="$1"
    local old_ifs item

    old_ifs="$IFS"
    IFS=':'
    for item in $list; do
        [ -n "$item" ] || continue
        printf '%s\n' "$item"
    done
    IFS="$old_ifs"
}

dot_redact_path() {
    local value="$1"
    value="${value//$HOME/\$HOME}"
    value="${value//$DOTFILES_DIR/\$DOTFILES_DIR}"
    printf '%s\n' "$value"
}

validate_setup_env() {
    local status=0
    local brewfile
    local brewfile_path
    local source

    dot_validate_bool DOT_ENABLE_DIA || status=1
    dot_validate_bool DOT_ENABLE_ONEPASSWORD || status=1
    dot_validate_bool DOT_ENABLE_SYSTEM_EXTENSIONS || status=1
    dot_validate_bool DOT_ENABLE_CODEX_CONFIG || status=1
    dot_validate_bool DOT_ENABLE_GIT_CONFIG || status=1
    dot_validate_bool DOT_PRUNE_EXTRA_SKILLS || status=1

    case "${DOT_DEFAULT_SHELL:-}" in
        "" | none | zsh | fish | /*) ;;
        *)
            dot_progress_fail "DOT_DEFAULT_SHELL must be fish, zsh, none, blank, or an absolute shell path"
            status=1
            ;;
    esac

    if dot_truthy "$DOT_ENABLE_GIT_CONFIG"; then
        dot_require DOT_GIT_USER_NAME || status=1
        dot_require DOT_GIT_USER_EMAIL || status=1
        dot_require DOT_GIT_SIGNING_KEY || status=1
        dot_require DOT_GIT_ALLOWED_SIGNERS_FILE || status=1
    fi

    if dot_truthy "$DOT_ENABLE_ONEPASSWORD"; then
        dot_require DOT_OP_VAULT || status=1
        dot_require DOT_OP_SSH_AUTH_ITEM || status=1
        dot_require DOT_OP_SSH_SIGN_ITEM || status=1
    fi

    if dot_truthy "$DOT_ENABLE_DIA"; then
        dot_require DOT_DIA_APP || status=1
        dot_require DOT_DIA_LOG_DIR || status=1
        dot_require AGENT_BROWSER_DIA_PORT || status=1
        dot_validate_port AGENT_BROWSER_DIA_PORT || status=1
    fi

    if [ -z "$DOT_BREWFILES" ]; then
        dot_progress_fail "DOT_BREWFILES must contain at least one Brewfile"
        status=1
    fi

    while IFS= read -r brewfile; do
        [ -n "$brewfile" ] || continue
        brewfile_path="$(dot_abs_path "$brewfile")"
        if [ ! -f "$brewfile_path" ]; then
            dot_progress_fail "Homebrew layer not found: $brewfile"
            status=1
        fi
    done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF

    if [ ! -d "$SKILLS_BASE" ]; then
        dot_progress_fail "Base skill source not found: $SKILLS_BASE"
        status=1
    fi

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        if [ ! -d "$source" ]; then
            dot_progress_warn "Extra skills source not found and will be skipped: $(dot_redact_path "$source")"
        fi
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF

    return "$status"
}
