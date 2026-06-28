#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

dot_render_line() {
    local line="$1"
    local dia_bin="$AGENT_BROWSER_DIA_BIN"
    local dia_stdout="$DOT_DIA_LOG_DIR/com.u29dc.dia-cdp.log"
    local dia_stderr="$DOT_DIA_LOG_DIR/com.u29dc.dia-cdp.err"
    local git_allowed_signer="${DOT_GIT_USER_EMAIL:-} ${DOT_GIT_SIGNING_KEY:-}"
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

write_managed_file() {
    local template="$1"
    local dest="$2"
    local label="$3"
    local tmp

    if [ ! -f "$template" ]; then
        dot_progress_fail "Template not found: $template"
        return 1
    fi

    dot_apply mkdir -p "$(dirname "$dest")"

    if dot_dry_run; then
        dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
        return 0
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/dot-render.XXXXXX")"
    render_template_to_file "$template" "$tmp"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if cmp -s "$tmp" "$dest"; then
            rm -f "$tmp"
            dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label already current: $dest"
            return 0
        fi

        if ! grep -Fq "dotfiles-managed:" "$dest" 2>/dev/null; then
            backup_existing_target "$template" "$dest" "backup-generated"
        fi
    fi

    mv "$tmp" "$dest"
    dot_manifest_append "render" "$template" "$dest"
    dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
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
