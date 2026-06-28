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

    dot_default DOT_BREWFILES "homebrew/Brewfile.primary"
    dot_default DOT_DEFAULT_SHELL "none"
    dot_default DOT_ENABLE_DIA 1
    dot_default DOT_ENABLE_ONEPASSWORD 0
    dot_default DOT_ENABLE_SYSTEM_EXTENSIONS 1
    dot_default DOT_ENABLE_CODEX_CONFIG 1
    dot_default DOT_ENABLE_GIT_CONFIG 0
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

dot_validate_port() {
    local name="$1"
    local value="${!name:-}"

    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le 65535 ]; then
        return 0
    fi

    fail "$name must be an integer TCP port from 1 to 65535"
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
    local brewfile
    local brewfile_path
    local source

    dot_validate_bool DOT_ENABLE_DIA || true
    dot_validate_bool DOT_ENABLE_ONEPASSWORD || true
    dot_validate_bool DOT_ENABLE_SYSTEM_EXTENSIONS || true
    dot_validate_bool DOT_ENABLE_CODEX_CONFIG || true
    dot_validate_bool DOT_ENABLE_GIT_CONFIG || true
    dot_validate_bool DOT_PRUNE_EXTRA_SKILLS || true

    case "${DOT_DEFAULT_SHELL:-}" in
        "" | none | zsh | fish | /*) ;;
        *) fail "DOT_DEFAULT_SHELL must be fish, zsh, none, blank, or an absolute shell path" ;;
    esac

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
        dot_validate_port AGENT_BROWSER_DIA_PORT || true
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

resolve_default_shell_path() {
    case "${DOT_DEFAULT_SHELL:-}" in
        "" | none)
            return 1
            ;;
        zsh)
            if [ -x /bin/zsh ]; then
                printf '%s\n' /bin/zsh
            else
                command -v zsh
            fi
            ;;
        fish)
            if command -v fish >/dev/null 2>&1; then
                command -v fish
            elif [ -x /opt/homebrew/bin/fish ]; then
                printf '%s\n' /opt/homebrew/bin/fish
            elif [ -x /usr/local/bin/fish ]; then
                printf '%s\n' /usr/local/bin/fish
            else
                return 1
            fi
            ;;
        /*)
            printf '%s\n' "$DOT_DEFAULT_SHELL"
            ;;
    esac
}

current_login_shell() {
    local shell=""

    if command -v dscl >/dev/null 2>&1 && [ -n "${USER:-}" ]; then
        shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    fi

    if [ -z "$shell" ]; then
        shell="${SHELL:-}"
    fi

    printf '%s\n' "$shell"
}

check_default_shell() {
    local shell_path
    local current_shell
    local shell_entry_count

    if [ -z "${DOT_DEFAULT_SHELL:-}" ] || [ "$DOT_DEFAULT_SHELL" = "none" ]; then
        ok "default login shell unmanaged"
        return 0
    fi

    if ! shell_path="$(resolve_default_shell_path)"; then
        fail "requested default shell unavailable: $DOT_DEFAULT_SHELL"
        return 0
    fi

    if [ ! -x "$shell_path" ]; then
        fail "requested default shell is not executable: $shell_path"
    fi

    shell_entry_count="$(grep -Fxc "$shell_path" /etc/shells 2>/dev/null || printf '0')"
    if [ "$shell_entry_count" -eq 1 ]; then
        ok "default shell allowed: $shell_path"
    elif [ "$shell_entry_count" -gt 1 ]; then
        warn "default shell appears $shell_entry_count times in /etc/shells: $shell_path"
    else
        warn "default shell missing from /etc/shells: $shell_path"
    fi

    current_shell="$(current_login_shell)"
    if [ "$current_shell" = "$shell_path" ]; then
        ok "default login shell active: $shell_path"
    else
        warn "default login shell is $current_shell; expected $shell_path"
    fi
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

json_get() {
    local path="$1"
    local expr="$2"

    python3 - "$path" "$expr" <<'PY'
import json
import sys

path, expr = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    value = json.load(handle)

for part in expr.split("."):
    if isinstance(value, list):
        value = value[int(part)]
    else:
        value = value[part]

if isinstance(value, (dict, list)):
    print(json.dumps(value, separators=(",", ":")))
else:
    print(value)
PY
}

toml_get() {
    local path="$1"
    local expr="$2"

    python3 - "$path" "$expr" <<'PY'
import sys

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError as exc:
        raise SystemExit("Python TOML parser unavailable") from exc

path, expr = sys.argv[1], sys.argv[2]
with open(path, "rb") as handle:
    value = tomllib.load(handle)

for part in expr.split("."):
    if isinstance(value, list):
        value = value[int(part)]
    else:
        value = value[part]

if isinstance(value, (dict, list)):
    raise SystemExit(f"{expr} is not scalar")
print(value)
PY
}

check_json_file() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        fail "$label missing: $path"
        return
    fi

    if python3 -m json.tool "$path" >/dev/null 2>&1; then
        ok "$label parses as JSON"
    else
        fail "$label does not parse as JSON: $path"
    fi
}

check_bash_parse() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        fail "$label missing: $path"
        return
    fi

    if /bin/bash -n "$path" >/dev/null 2>&1; then
        ok "$label parses as Bash"
    else
        fail "$label does not parse as Bash: $path"
    fi
}

filter_privacy_allowlist() {
    grep -Ev '^SETUP\.md:[0-9]+:(ssh -T git@github\.com|git remote set-url origin git@github\.com:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git)$' || true
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
            xargs rg -n --hidden --no-messages -e "$base_pattern" 2>/dev/null |
                filter_privacy_allowlist || true
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
                            xargs rg -n --hidden --fixed-strings --no-messages -e "$pattern" 2>/dev/null |
                                filter_privacy_allowlist || true
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
                git grep --cached -n -E "$base_pattern" -- . ':!scripts/doctor.sh' 2>/dev/null |
                filter_privacy_allowlist || true
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
    local notify_command
    local node_repl_command
    local codex_cli_path
    local node_path
    local module_dirs
    local module_dir
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
        return
    fi

    notify_command="$(toml_get "$config" "notify.0" 2>/dev/null || true)"
    node_repl_command="$(toml_get "$config" "mcp_servers.node_repl.command" 2>/dev/null || true)"
    codex_cli_path="$(toml_get "$config" "mcp_servers.node_repl.env.CODEX_CLI_PATH" 2>/dev/null || true)"
    node_path="$(toml_get "$config" "mcp_servers.node_repl.env.NODE_REPL_NODE_PATH" 2>/dev/null || true)"
    module_dirs="$(toml_get "$config" "mcp_servers.node_repl.env.NODE_REPL_NODE_MODULE_DIRS" 2>/dev/null || true)"

    check_executable_path "$notify_command" "Codex notify command"
    check_executable_path "$node_repl_command" "Codex node REPL command"
    check_executable_path "$codex_cli_path" "Codex CLI path"
    check_executable_path "$node_path" "Codex node path"

    while IFS= read -r module_dir; do
        [ -n "$module_dir" ] || continue
        check_directory_path "$module_dir" "Codex node module dir"
    done <<EOF
$(printf '%s\n' "$module_dirs" | tr ':' '\n')
EOF
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
    local config="$HOME/.agent-browser/config.json"
    local rendered_port
    local listeners
    check_managed_file "$plist" "Dia LaunchAgent"
    check_abs_file "$config"
    check_json_file "$config" "agent-browser Dia config"
    rendered_port="$(json_get "$config" "cdp" 2>/dev/null || true)"
    if [ "$rendered_port" = "$port" ]; then
        ok "agent-browser Dia port matches setup env: $port"
    else
        fail "agent-browser Dia port mismatch: config=${rendered_port:-missing} env=$port"
    fi

    if curl -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
        ok "Dia CDP healthy on port $port"
    else
        warn "Dia CDP not healthy on port $port"
    fi

    if command -v lsof >/dev/null 2>&1; then
        listeners="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
        if printf '%s\n' "$listeners" | grep -Eq '127\.0\.0\.1|::1'; then
            ok "Dia CDP listener is loopback-bound"
        elif [ -n "$listeners" ]; then
            warn "Dia CDP listener may not be loopback-only"
            printf '%s\n' "$listeners"
        else
            warn "Dia CDP listener not found by lsof"
        fi
    else
        warn "lsof unavailable; skipped Dia listener binding check"
    fi

    if command -v agent-browser >/dev/null 2>&1; then
        ok "agent-browser available"
    else
        warn "agent-browser unavailable"
    fi
}

check_fish_syntax() {
    if ! command -v fish >/dev/null 2>&1; then
        warn "fish unavailable; skipped Fish syntax checks"
        return
    fi

    if fish --no-config --no-execute \
        "$DOTFILES_DIR/shell/fish/config.fish" \
        "$DOTFILES_DIR/shell/fish/functions.fish" \
        "$DOTFILES_DIR/shell/fish/local.fish.example" >/dev/null 2>&1; then
        ok "Fish config parses"
    else
        fail "Fish config does not parse"
    fi
}

check_no_legacy_fish_split_links() {
    local dest
    local link_target

    for dest in "$HOME"/.config/fish/conf.d/*.fish "$HOME"/.config/fish/functions/*.fish; do
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        [ -L "$dest" ] || continue
        link_target="$(readlink "$dest")"
        case "$link_target" in
            "$DOTFILES_DIR/shell/fish/conf.d"/* | "$DOTFILES_DIR/shell/fish/functions"/*)
                fail "legacy Fish split symlink remains: $dest"
                ;;
        esac
    done
}

count_skill_entries() {
    local dir="$1"
    local entry
    local count=0

    if [ ! -d "$dir" ]; then
        printf '0\n'
        return
    fi

    for entry in "$dir"/*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        if [ -f "$entry/SKILL.md" ]; then
            count=$((count + 1))
        fi
    done

    printf '%s\n' "$count"
}

check_skill_source() {
    local label="$1"
    local path="$2"
    local count

    if [ -z "$path" ]; then
        ok "$label not configured"
        return
    fi

    if [ ! -d "$path" ]; then
        warn "$label missing: $(dot_redact_path "$path")"
        return
    fi

    count="$(count_skill_entries "$path")"
    if [ "$count" -gt 0 ]; then
        ok "$label contains $count skills"
    else
        warn "$label has no direct child SKILL.md folders: $(dot_redact_path "$path")"
    fi
}

check_skill_target() {
    local path="$1"
    local label="$2"
    local count

    if [ ! -d "$path" ]; then
        warn "$label missing: $path"
        return
    fi

    count="$(count_skill_entries "$path")"
    if [ "$count" -gt 0 ]; then
        ok "$label has $count linked skills"
    else
        warn "$label has no linked skills"
    fi
}

check_broken_skill_links() {
    local path="$1"
    local label="$2"
    local broken=""

    if [ ! -d "$path" ]; then
        warn "$label missing: $path"
        return
    fi

    broken="$(find "$path" -type l ! -exec test -e {} \; -print 2>/dev/null || true)"
    if [ -n "$broken" ]; then
        fail "$label contains broken skill symlinks"
        printf '%s\n' "$broken"
    else
        ok "$label has no broken skill symlinks"
    fi
}

check_duplicate_skill_sources() {
    local temp
    local source
    local skill
    local name
    local duplicates

    temp="$(mktemp "${TMPDIR:-/tmp}/dot-skill-sources.XXXXXX")"
    {
        printf '%s\n' "${SKILLS_BASE:-}"
        dot_each_colon_item "${DOT_SKILL_SOURCES:-}"
    } | while IFS= read -r source; do
        [ -d "$source" ] || continue
        for skill in "$source"/*; do
            [ -f "$skill/SKILL.md" ] || continue
            name="$(basename "$skill")"
            printf '%s\t%s\n' "$name" "$skill"
        done
    done >"$temp"

    duplicates="$(cut -f1 "$temp" | sort | uniq -d || true)"
    if [ -n "$duplicates" ]; then
        warn "duplicate skill names across configured sources"
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            grep -F "${name}"$'\t' "$temp"
        done <<EOF
$duplicates
EOF
    else
        ok "no duplicate skill names across configured sources"
    fi

    rm -f "$temp"
}

check_configured_path() {
    local name="$1"
    local label="$2"
    local value="${!name:-}"

    if [ -z "$value" ]; then
        ok "$label not configured"
        return
    fi

    if [ -e "$value" ]; then
        ok "$label exists: $(dot_redact_path "$value")"
    else
        warn "$label configured but missing: $(dot_redact_path "$value")"
    fi
}

check_executable_path() {
    local path="$1"
    local label="$2"

    if [ -z "$path" ]; then
        warn "$label not configured"
        return
    fi

    if [ -x "$path" ]; then
        ok "$label executable: $(dot_redact_path "$path")"
    else
        fail "$label missing or not executable: $(dot_redact_path "$path")"
    fi
}

check_directory_path() {
    local path="$1"
    local label="$2"

    if [ -z "$path" ]; then
        warn "$label not configured"
        return
    fi

    if [ -d "$path" ]; then
        ok "$label directory exists: $(dot_redact_path "$path")"
    else
        fail "$label directory missing: $(dot_redact_path "$path")"
    fi
}

check_git_signing_readiness() {
    local signing_key

    if ! truthy "${DOT_ENABLE_GIT_CONFIG:-0}"; then
        ok "git signing unmanaged"
        return
    fi

    signing_key="$(git config --global --get user.signingkey 2>/dev/null || true)"
    if [ -n "$signing_key" ]; then
        ok "git signing key configured"
    else
        warn "git signing key missing from global config"
    fi

    if [ -s "${DOT_GIT_ALLOWED_SIGNERS_FILE:-$HOME/.config/git/allowed-signers}" ]; then
        ok "git allowed signers file is nonempty"
    else
        warn "git allowed signers file empty or missing"
    fi
}

check_post_setup_checklist() {
    local source

    say ""
    say "Post-setup checklist"

    check_configured_path DOT_DROPBOX_HOME "Dropbox home"
    check_configured_path DOT_VAULT_HOME "Vault home"
    check_configured_path DOT_GDRIVE_HOME "Google Drive home"

    check_skill_source "base skill source" "${SKILLS_BASE:-}"
    while IFS= read -r source; do
        [ -n "$source" ] || continue
        check_skill_source "extra skill source" "$source"
    done <<EOF
$(dot_each_colon_item "${DOT_SKILL_SOURCES:-}")
EOF

    check_skill_target "$HOME/.claude/skills" "Claude skills"
    check_skill_target "$HOME/.codex/skills" "Codex skills"
    check_skill_target "$HOME/.agents/skills" "Shared agent skills"
    check_broken_skill_links "$HOME/.claude/skills" "Claude skills"
    check_broken_skill_links "$HOME/.codex/skills" "Codex skills"
    check_broken_skill_links "$HOME/.agents/skills" "Shared agent skills"
    check_duplicate_skill_sources
    check_git_signing_readiness

    ok "manual app sign-in remains external: 1Password, Codex, Dia, Dropbox, and Google Drive"
}

say "Dot doctor"
load_setup_env
apply_defaults
validate_setup_env

check_file "setup.env.example"
check_file "homebrew/Brewfile.primary"
check_file "agents/codex.toml"
check_file "shell/zsh/zshrc"
check_file "shell/zsh/zprofile"
check_file "shell/zsh/zshrc.local.example"
check_file "shell/fish/config.fish"
check_file "shell/fish/functions.fish"
check_file "shell/fish/local.fish.example"
check_file "system/gitconfig.template"
check_file "system/git-allowed-signers.template"
check_file "system/1password.agent.toml.template"
check_file "system/launchagents/com.u29dc.dia-cdp.plist.template"
check_file "system/karabiner"
check_file "macos/.macos"
check_file "terminal/ssh.template"
check_file "terminal/agent-browser.json.template"
check_gitignore
check_legacy_local_files
check_json_file "$DOTFILES_DIR/system/karabiner" "Karabiner source"
check_bash_parse "$DOTFILES_DIR/macos/.macos" "macOS preferences source"

say ""
say "Tool wrappers"
for tool in agent-browser-chrome agent-browser-dia agent-browser-dia-off agent-browser-dia-on agent-browser-dia-status buf cho fin grn let pdf tao upd; do
    check_wrapper "$tool"
done

say ""
say "Brewfiles"
check_brewfiles

say ""
say "Linked config"
check_managed_file "$HOME/.config/dot/env.zsh" "Zsh env"
check_managed_file "$HOME/.config/dot/env.fish" "Fish env"
check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/shell/zsh/zshrc"
check_symlink "$HOME/.zprofile" "$DOTFILES_DIR/shell/zsh/zprofile"
check_symlink "$HOME/.config/fish/config.fish" "$DOTFILES_DIR/shell/fish/config.fish"
check_symlink "$HOME/.config/fish/functions.fish" "$DOTFILES_DIR/shell/fish/functions.fish"
if truthy "${DOT_ENABLE_SYSTEM_EXTENSIONS:-0}"; then
    check_symlink "$HOME/.config/karabiner/karabiner.json" "$DOTFILES_DIR/system/karabiner"
    check_symlink "$HOME/.macos" "$DOTFILES_DIR/macos/.macos"
fi
check_no_legacy_fish_split_links
check_fish_syntax
check_default_shell
check_managed_file "$HOME/.ssh/config" "SSH config"
check_abs_file "$HOME/.agent-browser/config.json"
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

check_post_setup_checklist

if ! privacy_scan; then
    status=1
fi

exit "$status"
