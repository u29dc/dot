#!/usr/bin/env bash
set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOT_ENV_FILE="${DOT_ENV_FILE:-$DOTFILES_DIR/setup.env}"
status=0

say() {
    printf '%s\n' "$*"
}

ok() {
    printf '[OK  ] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*"
}

fail() {
    printf '[FAIL] %s\n' "$*"
    status=1
}

load_setup_env() {
    if [ ! -f "$DOT_ENV_FILE" ]; then
        fail "setup env missing: $DOT_ENV_FILE"
        return 0
    fi

    # shellcheck source=/dev/null
    set -a
    source "$DOT_ENV_FILE"
    set +a
    ok "setup env loaded"
}

dot_default() {
    local name="$1"
    local value="$2"
    if [ -z "${!name+x}" ]; then
        printf -v "$name" '%s' "$value"
        export "${name?}"
    fi
}

apply_defaults() {
    if [ -n "${DOT_TOOLS_HOME:-}" ] && [ -z "${TOOLS_HOME:-}" ]; then
        TOOLS_HOME="$DOT_TOOLS_HOME"
        export TOOLS_HOME
    fi

    dot_default DOT_BREWFILES "homebrew/Brewfile.base"
    dot_default DOT_ENABLE_DIA 1
    dot_default DOT_ENABLE_ONEPASSWORD 1
    dot_default DOT_ENABLE_SYSTEM_EXTENSIONS 1
    dot_default DOT_ENABLE_CODEX_CONFIG 1
    dot_default DOT_ENABLE_GIT_CONFIG 1
    dot_default DOT_PRUNE_EXTRA_SKILLS 0
    dot_default TOOLS_HOME "$HOME/.tools"
    dot_default SKILLS_BASE "$DOTFILES_DIR/agents/skills"
    dot_default DOT_SKILL_SOURCES ""
    dot_default DOT_DIA_APP "/Applications/Dia.app"
    dot_default DOT_DIA_LOG_DIR "$HOME/Library/Logs"
    dot_default DOT_GIT_ALLOWED_SIGNERS_FILE "$HOME/.config/git/allowed-signers"
    dot_default AGENT_BROWSER_DIA_PORT 9222
}

truthy() {
    [ "${1:-0}" = "1" ]
}

dot_require() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        fail "missing required setup env: $name"
        return 1
    fi
}

dot_validate_bool() {
    local name="$1"
    case "${!name:-}" in
        0 | 1) ;;
        *)
            fail "$name must be 0 or 1"
            return 1
            ;;
    esac
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
    local brewfile
    local brewfile_path
    local source

    dot_validate_bool DOT_ENABLE_DIA || true
    dot_validate_bool DOT_ENABLE_ONEPASSWORD || true
    dot_validate_bool DOT_ENABLE_SYSTEM_EXTENSIONS || true
    dot_validate_bool DOT_ENABLE_CODEX_CONFIG || true
    dot_validate_bool DOT_ENABLE_GIT_CONFIG || true
    dot_validate_bool DOT_PRUNE_EXTRA_SKILLS || true

    if truthy "${DOT_ENABLE_GIT_CONFIG:-}"; then
        dot_require DOT_GIT_USER_NAME || true
        dot_require DOT_GIT_USER_EMAIL || true
        dot_require DOT_GIT_SIGNING_KEY || true
        dot_require DOT_GIT_ALLOWED_SIGNERS_FILE || true
    fi

    if truthy "${DOT_ENABLE_ONEPASSWORD:-}"; then
        dot_require DOT_OP_VAULT || true
        dot_require DOT_OP_SSH_AUTH_ITEM || true
        dot_require DOT_OP_SSH_SIGN_ITEM || true
    fi

    if truthy "${DOT_ENABLE_DIA:-}"; then
        dot_require DOT_DIA_APP || true
        dot_require DOT_DIA_LOG_DIR || true
        dot_require AGENT_BROWSER_DIA_PORT || true
    fi

    if [ -z "${DOT_BREWFILES:-}" ]; then
        fail "DOT_BREWFILES must contain at least one Brewfile"
    fi

    while IFS= read -r brewfile; do
        [ -n "$brewfile" ] || continue
        brewfile_path="$(dot_abs_path "$brewfile")"
        if [ ! -f "$brewfile_path" ]; then
            fail "Homebrew layer not found: $brewfile"
        fi
    done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF

    if [ ! -d "${SKILLS_BASE:-}" ]; then
        fail "base skill source not found: $(dot_redact_path "${SKILLS_BASE:-}")"
    fi

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        if [ ! -d "$source" ]; then
            warn "extra skills source not found and will be skipped: $(dot_redact_path "$source")"
        fi
    done <<EOF
$(dot_each_colon_item "${DOT_SKILL_SOURCES:-}")
EOF
}

check_file() {
    local path="$1"
    if [ -e "$DOTFILES_DIR/$path" ]; then
        ok "$path"
    else
        fail "$path missing"
    fi
}

check_abs_file() {
    local path="$1"
    if [ -f "$path" ]; then
        ok "$path"
    else
        fail "$path missing"
    fi
}

check_wrapper() {
    local name="$1"
    local path="$DOTFILES_DIR/terminal/bin/$name"
    if [ ! -f "$path" ]; then
        fail "terminal/bin/$name missing"
        return
    fi
    if [ ! -x "$path" ]; then
        fail "terminal/bin/$name is not executable"
        return
    fi
    ok "terminal/bin/$name"
}

check_symlink() {
    local dest="$1"
    local src="$2"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        ok "$dest -> ${src#"$DOTFILES_DIR"/}"
    else
        fail "$dest is not linked to ${src#"$DOTFILES_DIR"/}"
    fi
}

check_managed_file() {
    local path="$1"
    local label="$2"
    if [ ! -f "$path" ]; then
        fail "$label missing: $path"
        return
    fi
    if grep -Fq "dotfiles-managed:" "$path"; then
        ok "$label managed"
    else
        fail "$label is not dotfiles-managed: $path"
    fi
}

privacy_scan() {
    local pattern_file="${DOT_PRIVACY_BLOCKLIST:-}"
    local matches=""
    local base_pattern
    local files
    local cached_matches=""

    base_pattern='/Users/[[:alnum:]_.-]+|Library/CloudStorage/Dropbox/[^"[:space:]]+|NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S|marketplaces\..*source =|^\[projects\."/Users/[[:alnum:]_.-]+|(^|[[:space:]="'\''`])[[:alnum:]_.%+]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|vault = "[^_][^"]*"'
    files="$(
        {
            git -C "$DOTFILES_DIR" ls-files
            git -C "$DOTFILES_DIR" ls-files --others --exclude-standard
        } | sort -u | grep -v '^scripts/doctor\.sh$'
    )"

    say ""
    say "Privacy scan"

    matches="$(
        cd "$DOTFILES_DIR" &&
            printf '%s\n' "$files" |
            xargs rg -n --hidden --no-messages -e "$base_pattern" 2>/dev/null || true
    )"

    if [ -n "$pattern_file" ] && [ -f "$pattern_file" ]; then
        matches="$(
            {
                printf '%s\n' "$matches"
                while IFS= read -r pattern; do
                    [ -n "$pattern" ] || continue
                    case "$pattern" in \#*) continue ;; esac
                    (
                        cd "$DOTFILES_DIR" &&
                            printf '%s\n' "$files" |
                            xargs rg -n --hidden --fixed-strings --no-messages -e "$pattern" 2>/dev/null || true
                    )
                done <"$pattern_file"
            } | awk 'NF'
        )"
    fi

    if [ -n "$matches" ]; then
        warn "tracked or untracked nonignored files contain local/private-looking strings"
        printf '%s\n' "$matches"
        return 1
    fi

    if ! git -C "$DOTFILES_DIR" diff --cached --quiet --exit-code; then
        cached_matches="$(
            cd "$DOTFILES_DIR" &&
                git grep --cached -n -E "$base_pattern" -- . ':!scripts/doctor.sh' 2>/dev/null || true
        )"

        if [ -n "$cached_matches" ]; then
            warn "staged files contain local/private-looking strings"
            printf '%s\n' "$cached_matches"
            return 1
        fi
        ok "no staged local/private-looking strings found"
    elif ! git -C "$DOTFILES_DIR" diff --quiet --exit-code; then
        warn "staged privacy scan skipped because changes are not staged; stage intended files before final public commit"
    fi

    ok "no tracked local/private-looking strings found"
}

check_legacy_local_files() {
    if [ -e "$DOTFILES_DIR/profiles/local.env" ]; then
        fail "legacy private env exists; migrate/delete: profiles/local.env"
    else
        ok "no legacy profiles/local.env"
    fi
}

check_gitignore() {
    if git -C "$DOTFILES_DIR" check-ignore -q setup.env; then
        ok "setup.env ignored"
    else
        fail "setup.env is not ignored"
    fi

    if git -C "$DOTFILES_DIR" check-ignore -q homebrew/Brewfile.local; then
        ok "homebrew/Brewfile.local ignored"
    else
        fail "homebrew/Brewfile.local is not ignored"
    fi
}

check_brewfiles() {
    local old_ifs item path
    [ -n "${DOT_BREWFILES:-}" ] || {
        fail "DOT_BREWFILES empty"
        return
    }

    old_ifs="$IFS"
    IFS=':'
    for item in $DOT_BREWFILES; do
        [ -n "$item" ] || continue
        case "$item" in
            /*) path="$item" ;;
            *) path="$DOTFILES_DIR/$item" ;;
        esac
        check_abs_file "$path"
        if command -v brew >/dev/null 2>&1; then
            if brew bundle check --no-upgrade --file="$path" >/dev/null 2>&1; then
                ok "brew layer satisfied: $item"
            else
                warn "brew layer not fully satisfied: $item"
            fi
        fi
    done
    IFS="$old_ifs"
}

check_codex_config() {
    local config="$HOME/.codex/config.toml"
    check_managed_file "$config" "Codex config"
    if command -v python3 >/dev/null 2>&1; then
        if python3 - "$config" <<'PY' >/dev/null 2>&1; then
import sys
try:
    import tomllib
except ModuleNotFoundError:
    raise SystemExit(0)
with open(sys.argv[1], "rb") as f:
    tomllib.load(f)
PY
            ok "Codex config parses as TOML"
        else
            fail "Codex config does not parse as TOML"
        fi
    else
        warn "python3 unavailable; skipped Codex TOML parse"
    fi
}

check_onepassword() {
    check_managed_file "$HOME/.config/1Password/ssh/agent.toml" "1Password SSH agent config"
    if command -v op >/dev/null 2>&1; then
        ok "op available"
    else
        fail "op unavailable"
    fi
}

check_git_setup() {
    check_managed_file "$HOME/.gitconfig" "Git config"
    check_managed_file "${DOT_GIT_ALLOWED_SIGNERS_FILE:-$HOME/.config/git/allowed-signers}" "Git allowed signers"

    if ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com 2>&1 | grep -Eq "successfully authenticated|Hi .*!"; then
        ok "GitHub SSH authenticated"
    else
        warn "GitHub SSH did not authenticate in batch mode"
    fi
}

check_dia() {
    local plist="$HOME/Library/LaunchAgents/com.u29dc.dia-cdp.plist"
    local port="${AGENT_BROWSER_DIA_PORT:-9222}"
    check_managed_file "$plist" "Dia LaunchAgent"
    if curl -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
        ok "Dia CDP healthy on port $port"
    else
        warn "Dia CDP not healthy on port $port"
    fi
    if command -v agent-browser >/dev/null 2>&1; then
        ok "agent-browser available"
    else
        warn "agent-browser unavailable"
    fi
}

say "Dot doctor"
load_setup_env
apply_defaults
validate_setup_env

check_file "setup.env.example"
check_file "homebrew/Brewfile.base"
check_file "agents/codex.toml"
check_file "system/gitconfig.template"
check_file "system/git-allowed-signers.template"
check_file "system/1password.agent.toml.template"
check_file "system/launchagents/com.u29dc.dia-cdp.plist.template"
check_file "terminal/ssh.template"
check_gitignore
check_legacy_local_files

say ""
say "Tool wrappers"
for tool in buf cho fin grn let pdf tao; do
    check_wrapper "$tool"
done

say ""
say "Brewfiles"
check_brewfiles

say ""
say "Linked config"
check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/shell/zshrc"
check_symlink "$HOME/.zprofile" "$DOTFILES_DIR/shell/zprofile"
check_managed_file "$HOME/.ssh/config" "SSH config"
check_symlink "$HOME/.agent-browser/config.json" "$DOTFILES_DIR/terminal/agent-browser.json"
check_symlink "$HOME/.agent-browser/chrome.json" "$DOTFILES_DIR/terminal/agent-browser.chrome.json"

if truthy "${DOT_ENABLE_GIT_CONFIG:-0}"; then
    check_git_setup
fi
if truthy "${DOT_ENABLE_ONEPASSWORD:-0}"; then
    check_onepassword
fi
if truthy "${DOT_ENABLE_CODEX_CONFIG:-0}"; then
    check_codex_config
fi
if truthy "${DOT_ENABLE_DIA:-0}"; then
    check_dia
fi

if ! privacy_scan; then
    status=1
fi

exit "$status"
