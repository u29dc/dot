#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

dot_render_line() {
    local line="$1"
    local dia_bin="$AGENT_BROWSER_DIA_BIN"
    local dia_stdout="$DOT_DIA_LOG_DIR/com.u29dc.dia-cdp.log"
    local dia_stderr="$DOT_DIA_LOG_DIR/com.u29dc.dia-cdp.err"
    local git_allowed_signer_principals="${DOT_GIT_ALLOWED_SIGNER_PRINCIPALS:-${DOT_GIT_USER_EMAIL:-}}"
    local git_allowed_signer="$git_allowed_signer_principals ${DOT_GIT_SIGNING_KEY:-}"
    local ssh_identity_agent="  # IdentityAgent disabled by DOT_ENABLE_ONEPASSWORD=0"

    line="${line//__HOME__/$HOME}"
    line="${line//__DOTFILES_DIR__/$DOTFILES_DIR}"
    line="${line//__TOOLS_HOME__/$TOOLS_HOME}"
    line="${line//__GIT_USER_NAME__/${DOT_GIT_USER_NAME:-}}"
    line="${line//__GIT_USER_EMAIL__/${DOT_GIT_USER_EMAIL:-}}"
    line="${line//__GIT_SIGNING_KEY__/${DOT_GIT_SIGNING_KEY:-}}"
    line="${line//__GIT_ALLOWED_SIGNERS_FILE__/$DOT_GIT_ALLOWED_SIGNERS_FILE}"
    line="${line//__GIT_ALLOWED_SIGNER__/$git_allowed_signer}"
    line="${line//__OP_VAULT__/${DOT_OP_VAULT:-}}"
    line="${line//__OP_SSH_AUTH_ITEM__/${DOT_OP_SSH_AUTH_ITEM:-}}"
    line="${line//__OP_SSH_SIGN_ITEM__/${DOT_OP_SSH_SIGN_ITEM:-}}"
    if dot_truthy "$DOT_ENABLE_ONEPASSWORD"; then
        ssh_identity_agent='  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'
    fi
    line="${line//__SSH_IDENTITY_AGENT__/$ssh_identity_agent}"
    line="${line//__DIA_APP_BIN__/$dia_bin}"
    line="${line//__AGENT_BROWSER_DIA_PORT__/$AGENT_BROWSER_DIA_PORT}"
    line="${line//__DIA_STDOUT_LOG__/$dia_stdout}"
    line="${line//__DIA_STDERR_LOG__/$dia_stderr}"
    printf '%s\n' "$line"
}

render_template_to_file() {
    local template="$1"
    local dest="$2"
    local line

    while IFS= read -r line || [ -n "$line" ]; do
        dot_render_line "$line"
    done <"$template" >"$dest"
}

# Install a generated file. Unchanged content is left alone; unmanaged files are
# backed up first. Changed destinations are recorded for dot_changed_in_run.
install_generated_file() {
    local tmp="$1"
    local dest="$2"
    local label="$3"
    local source="$4"

    if { [ -e "$dest" ] || [ -L "$dest" ]; } && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        dot_progress_ok "$label already current: $dest"
        return 0
    fi

    DOT_CHANGED_FILES="${DOT_CHANGED_FILES:-}${dest}"$'\n'
    if dot_dry_run; then
        rm -f "$tmp"
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "render $label -> $dest"
        return 0
    fi

    if { [ -e "$dest" ] || [ -L "$dest" ]; } && ! grep -Fq "dotfiles-managed:" "$dest" 2>/dev/null; then
        backup_existing_target "$source" "$dest" "backup-generated"
    fi

    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
    dot_manifest_append "render" "$source" "$dest"
    dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
}

dot_changed_in_run() {
    case $'\n'"${DOT_CHANGED_FILES:-}" in
        *$'\n'"$1"$'\n'*) return 0 ;;
    esac
    return 1
}

write_managed_file() {
    local template="$1"
    local dest="$2"
    local label="$3"
    local tmp

    if [ ! -f "$template" ]; then
        dot_progress_fail "Template not found: $template"
        return 1
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/dot-render.XXXXXX")"
    render_template_to_file "$template" "$tmp"
    install_generated_file "$tmp" "$dest" "$label" "$template"
}

dot_shell_quote() {
    local value="$1"
    value="${value//\'/\'\\\'\'}"
    printf "'%s'" "$value"
}

write_shell_env_var() {
    local shell="$1"
    local name="$2"
    local value="${!name-}"

    case "$shell" in
        zsh) printf 'export %s=%s\n' "$name" "$(dot_shell_quote "$value")" ;;
        fish) printf 'set -gx %s %s\n' "$name" "$(dot_shell_quote "$value")" ;;
        *)
            dot_progress_fail "Unknown shell env target: $shell"
            return 1
            ;;
    esac
}
