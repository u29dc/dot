#!/usr/bin/env bash
# Read-only health and privacy checks for the checkout and the managed $HOME.
# shellcheck disable=SC2034,SC2154
set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR
for lib in progress env links render targets plugins skills agents shell; do
    # shellcheck source=/dev/null
    source "$DOTFILES_DIR/scripts/lib/$lib.sh"
done

# Shared helpers must never write: everything below runs in dry-run mode.
DRY_RUN=true
NO_BREW=true
DOT_ENV_FILE="${DOT_ENV_FILE:-$DOTFILES_DIR/setup.env}"
status=0
have_uv=0

ok() { dot_progress_ok "$@"; }
warn() { dot_progress_warn "$@"; }
fail() {
    dot_progress_fail "$@"
    status=1
}

heading() {
    dot_progress_section "$1"
}

doctor_python() {
    uv run --quiet --no-project --python '>=3.11' python - "$@"
}

json_valid() {
    doctor_python "$1" <<'PY' >/dev/null 2>&1
import json, sys
json.load(open(sys.argv[1], encoding="utf-8"))
PY
}

# Print one scalar from a JSON or TOML file; dotted path, list indexes allowed.
config_get() {
    doctor_python "$1" "$2" <<'PY' 2>/dev/null
import json, sys, tomllib
path, expr = sys.argv[1], sys.argv[2]
with open(path, "rb") as handle:
    value = tomllib.load(handle) if path.endswith(".toml") else json.load(handle)
for part in expr.split("."):
    value = value[int(part)] if isinstance(value, list) else value[part]
if isinstance(value, (dict, list)):
    raise SystemExit(1)
print(value)
PY
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

# Compare freshly generated content ($1, removed afterwards) with the live file.
check_generated() {
    local tmp="$1"
    local dest="$2"
    local label="$3"

    if [ ! -e "$dest" ]; then
        fail "$label missing: $dest"
    elif cmp -s "$tmp" "$dest"; then
        ok "$label current"
    else
        warn "$label differs from its template; rerun setup to apply: $dest"
    fi
    rm -f "$tmp"
}

check_executable_path() {
    local path="$1"
    local label="$2"
    if [ -z "$path" ]; then
        warn "$label not configured"
    elif [ -x "$path" ]; then
        ok "$label executable: $(dot_redact_path "$path")"
    else
        fail "$label missing or not executable: $(dot_redact_path "$path")"
    fi
}

check_configured_path() {
    local name="$1"
    local label="$2"
    local value="${!name:-}"
    if [ -z "$value" ]; then
        ok "$label not configured"
    elif [ -e "$value" ]; then
        ok "$label exists: $(dot_redact_path "$value")"
    else
        warn "$label configured but missing: $(dot_redact_path "$value")"
    fi
}

check_environment() {
    if [ -f "$DOT_ENV_FILE" ]; then
        initialize_setup_environment
    else
        fail "setup env missing: $DOT_ENV_FILE (cp setup.env.example setup.env)"
        dot_apply_defaults
    fi
    validate_setup_env || status=1

    if git -C "$DOTFILES_DIR" check-ignore -q setup.env && git -C "$DOTFILES_DIR" check-ignore -q homebrew/Brewfile.local; then
        ok "setup.env and homebrew/Brewfile.local are ignored"
    else
        fail "setup.env or homebrew/Brewfile.local is not ignored"
    fi
    if [ -e "$DOTFILES_DIR/profiles/local.env" ]; then
        fail "legacy private env exists; migrate or delete: profiles/local.env"
    fi
    if command -v uv >/dev/null 2>&1; then
        have_uv=1
    else
        have_uv=0
        fail "uv unavailable; config parsing and agent checks are skipped"
    fi
}

check_repository() {
    local section condition src dest label

    heading "Repository"
    for src in setup.env.example homebrew/Brewfile.primary agents/claude.json agents/codex.toml shell/zsh/zshrc.local.example shell/fish/local.fish.example; do
        [ -f "$DOTFILES_DIR/$src" ] || fail "required file missing: $src"
    done
    while IFS='|' read -r section condition src dest; do
        [ -e "$DOTFILES_DIR/$src" ] || fail "link source missing: $src"
    done <<EOF
$(dot_link_targets)
EOF
    while IFS='|' read -r section condition src dest label; do
        [ -f "$DOTFILES_DIR/$src" ] || fail "template missing: $src"
    done <<EOF
$(dot_render_targets)
EOF
    ok "managed sources and templates present"

    if [ "$have_uv" = 0 ]; then
        :
    elif json_valid "$DOTFILES_DIR/system/karabiner/karabiner.json"; then
        ok "Karabiner config parses as JSON"
    else
        fail "Karabiner config does not parse: system/karabiner/karabiner.json"
    fi
    if /bin/bash -n "$DOTFILES_DIR/macos/.macos" 2>/dev/null; then
        ok "macOS preferences script parses as Bash"
    else
        fail "macOS preferences script does not parse: macos/.macos"
    fi
    if command -v fish >/dev/null 2>&1; then
        if fish --no-config --no-execute "$DOTFILES_DIR/shell/fish/config.fish" "$DOTFILES_DIR/shell/fish/functions.fish" "$DOTFILES_DIR/shell/fish/local.fish.example" >/dev/null 2>&1; then
            ok "Fish config parses"
        else
            fail "Fish config does not parse"
        fi
    else
        warn "fish unavailable; skipped Fish syntax check"
    fi
}

check_homebrew() {
    local brewfile

    heading "Homebrew"
    if ! command -v brew >/dev/null 2>&1; then
        warn "brew unavailable; skipped layer checks"
        return
    fi
    while IFS= read -r brewfile; do
        [ -n "$brewfile" ] || continue
        if brew bundle check --no-upgrade --file="$(dot_abs_path "$brewfile")" </dev/null >/dev/null 2>&1; then
            ok "layer satisfied: $brewfile"
        else
            warn "layer not fully satisfied: $brewfile (run setup)"
        fi
    done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF
}

check_links() {
    local section condition src dest label prefix tool shell tmp
    local shell_path current_shell

    heading "Linked config"
    while IFS='|' read -r section condition src dest; do
        dot_target_enabled "$condition" || continue
        check_symlink "$dest" "$DOTFILES_DIR/$src"
    done <<EOF
$(dot_link_targets)
EOF
    for tool in "$DOTFILES_DIR"/terminal/bin/*; do
        [ -f "$tool" ] && [ -x "$tool" ] || continue
        case "$(basename "$tool")" in .* | _*) continue ;; esac
        check_symlink "$HOME/.local/bin/$(basename "$tool")" "$tool"
    done
    while IFS='|' read -r prefix dest; do
        if [ -L "$dest" ]; then
            warn "retired link remains (setup removes it): $dest"
        fi
    done <<EOF
$(dot_legacy_targets)
EOF
    for dest in "$HOME"/.config/fish/conf.d/*.fish "$HOME"/.config/fish/functions/*.fish; do
        [ -L "$dest" ] || continue
        case "$(readlink "$dest")" in
            "$DOTFILES_DIR/shell/fish/"*) fail "legacy Fish split symlink remains: $dest" ;;
        esac
    done

    heading "Generated config"
    while IFS='|' read -r shell dest label; do
        tmp="$(mktemp "${TMPDIR:-/tmp}/dot-doctor.XXXXXX")"
        shell_env_content "$shell" "$dest" >"$tmp"
        check_generated "$tmp" "$dest" "$label"
    done <<EOF
$(dot_shell_env_targets)
EOF
    while IFS='|' read -r section condition src dest label; do
        dot_target_enabled "$condition" || continue
        tmp="$(mktemp "${TMPDIR:-/tmp}/dot-doctor.XXXXXX")"
        render_template_to_file "$DOTFILES_DIR/$src" "$tmp"
        check_generated "$tmp" "$dest" "$label"
    done <<EOF
$(dot_render_targets)
EOF

    if [ -z "${DOT_DEFAULT_SHELL:-}" ] || [ "$DOT_DEFAULT_SHELL" = none ]; then
        ok "default login shell unmanaged"
    elif ! shell_path="$(resolve_default_shell_path)"; then
        fail "requested default shell unavailable: $DOT_DEFAULT_SHELL"
    else
        grep -Fxq "$shell_path" /etc/shells 2>/dev/null || warn "default shell missing from /etc/shells: $shell_path"
        current_shell="$(current_login_shell)"
        if [ "$current_shell" = "$shell_path" ]; then
            ok "default login shell active: $shell_path"
        else
            warn "default login shell is $current_shell; expected $shell_path"
        fi
    fi

    if command -v fastfetch >/dev/null 2>&1 && [ -f "$HOME/.config/fastfetch/config.jsonc" ]; then
        if fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --pipe true >/dev/null 2>&1; then
            ok "Fastfetch config loads"
        else
            fail "Fastfetch config does not load"
        fi
    fi
}

check_tools() {
    local name path

    heading "Tool binaries"
    for name in cho fin let tao; do
        path="$TOOLS_HOME/$name/$name"
        if [ -x "$path" ]; then
            ok "$name backing binary"
        else
            warn "$name backing binary missing: $(dot_redact_path "$path")"
        fi
    done
}

check_agents() {
    local config="$HOME/.codex/config.toml"
    local source module_dir

    heading "Agents"
    if [ "$have_uv" = 0 ]; then
        warn "agent checks skipped without uv"
        return
    fi
    if [ -L "$HOME/.claude/settings.json" ]; then
        warn "Claude settings are still a symlink; rerun setup to make them local"
    fi
    if json_valid "$HOME/.claude/settings.json"; then
        ok "Claude settings parse as JSON"
    else
        fail "Claude settings missing or invalid: $HOME/.claude/settings.json"
    fi
    sync_claude_settings || status=1
    [ "$DOT_AGENT_CONFIG_CHANGED" = 0 ] || warn "Claude settings differ from agents/claude.json; rerun setup to apply"

    if dot_truthy "$DOT_ENABLE_CODEX_CONFIG"; then
        sync_codex_config || status=1
        [ "$DOT_AGENT_CONFIG_CHANGED" = 0 ] || warn "Codex config differs from agents/codex.toml; rerun setup to apply"
        # The ChatGPT app owns these paths; stale ones break browser use.
        check_executable_path "$(config_get "$config" notify.0)" "Codex notify command"
        check_executable_path "$(config_get "$config" mcp_servers.node_repl.command)" "Codex node REPL command"
        check_executable_path "$(config_get "$config" mcp_servers.node_repl.env.CODEX_CLI_PATH)" "Codex CLI path"
        while IFS= read -r module_dir; do
            [ -n "$module_dir" ] || continue
            [ -d "$module_dir" ] || fail "Codex node module dir missing: $(dot_redact_path "$module_dir")"
        done <<EOF
$(config_get "$config" mcp_servers.node_repl.env.NODE_REPL_NODE_MODULE_DIRS | tr ':' '\n')
EOF
    fi

    check_skill_source "base skill source" "$SKILLS_BASE"
    while IFS= read -r source; do
        [ -n "$source" ] || continue
        check_skill_source "extra skill source" "$source"
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF
    check_skill_target "$HOME/.claude/skills" "Claude skills"
    check_skill_target "$HOME/.codex/skills" "Codex skills"
    check_skill_target "$HOME/.agents/skills" "Shared agent skills"
    check_duplicate_skill_names
}

count_skill_entries() {
    local dir="$1"
    local entry
    local count=0

    if [ ! -d "$dir" ]; then
        printf '0\n'
    elif dot_is_plugin "$dir"; then
        count_skill_entries "$dir/skills"
    elif [ -f "$dir/SKILL.md" ]; then
        printf '1\n'
    else
        for entry in "$dir"/*; do
            if dot_is_plugin "$entry"; then
                count=$((count + $(count_skill_entries "$entry/skills")))
            elif [ -f "$entry/SKILL.md" ]; then
                count=$((count + 1))
            fi
        done
        printf '%s\n' "$count"
    fi
}

check_skill_source() {
    local label="$1"
    local path="$2"
    local count

    if [ ! -d "$path" ]; then
        warn "$label missing: $(dot_redact_path "$path")"
        return
    fi
    if ! uv run --quiet --no-project --python '>=3.11' "$DOTFILES_DIR/scripts/plugins.py" list "$path" </dev/null >/dev/null; then
        fail "$label has an invalid plugin manifest: $(dot_redact_path "$path")"
    elif dot_is_plugin "$path"; then
        ok "$label is a complete plugin (mode: $DOT_PLUGIN_MODE)"
    else
        count="$(count_skill_entries "$path")"
        if [ "$count" -gt 0 ]; then
            ok "$label contains $count skills"
        else
            warn "$label has no SKILL.md or child skill folders: $(dot_redact_path "$path")"
        fi
    fi
}

check_skill_target() {
    local path="$1"
    local label="$2"
    local broken

    if [ ! -d "$path" ]; then
        warn "$label missing: $path"
        return
    fi
    ok "$label has $(count_skill_entries "$path") linked skills"
    broken="$(find "$path" -type l ! -exec test -e {} \; -print 2>/dev/null || true)"
    if [ -n "$broken" ]; then
        fail "$label contains broken skill symlinks"
        printf '%s\n' "$broken"
    fi
}

check_duplicate_skill_names() {
    local listing source skill duplicates

    listing="$(
        {
            printf '%s\n' "$SKILLS_BASE"
            dot_each_colon_item "$DOT_SKILL_SOURCES"
        } | while IFS= read -r source; do
            [ -d "$source" ] || continue
            dot_is_plugin "$source" && continue
            if [ -f "$source/SKILL.md" ]; then
                printf '%s\t%s\n' "$(basename "$source")" "$source"
                continue
            fi
            for skill in "$source"/*; do
                dot_is_plugin "$skill" && continue
                [ -f "$skill/SKILL.md" ] && printf '%s\t%s\n' "$(basename "$skill")" "$skill"
            done
        done
    )"
    duplicates="$(printf '%s\n' "$listing" | cut -f1 | sort | uniq -d)"
    if [ -n "$duplicates" ]; then
        warn "duplicate skill names across configured sources: $(printf '%s' "$duplicates" | tr '\n' ' ')"
    else
        ok "no duplicate skill names across configured sources"
    fi
}

check_git() {
    heading "Git and SSH"
    if ! dot_truthy "$DOT_ENABLE_GIT_CONFIG"; then
        ok "Git config unmanaged"
        return
    fi
    if [ -n "$(git config --global --get user.signingkey 2>/dev/null || true)" ]; then
        ok "Git signing key configured"
    else
        warn "Git signing key missing from global config"
    fi
    if [ -s "$DOT_GIT_ALLOWED_SIGNERS_FILE" ]; then
        ok "Git allowed signers file is nonempty"
    else
        warn "Git allowed signers file empty or missing"
    fi
    if ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com 2>&1 | grep -Eq "successfully authenticated|Hi .*!"; then
        ok "GitHub SSH authenticated"
    else
        warn "GitHub SSH did not authenticate in batch mode"
    fi
    if dot_truthy "$DOT_ENABLE_ONEPASSWORD"; then
        if command -v op >/dev/null 2>&1; then
            ok "op available"
        else
            fail "op unavailable"
        fi
    fi
}

check_dia() {
    local port="$AGENT_BROWSER_DIA_PORT"
    local config="$HOME/.agent-browser/config.json"
    local rendered_port listeners

    heading "Dia and agent-browser"
    if ! dot_truthy "$DOT_ENABLE_DIA"; then
        ok "Dia CDP unmanaged"
        return
    fi
    rendered_port="$(config_get "$config" cdp || true)"
    if [ "$have_uv" = 0 ]; then
        :
    elif [ "$rendered_port" = "$port" ]; then
        ok "agent-browser Dia port matches setup env: $port"
    else
        fail "agent-browser Dia port mismatch: config=${rendered_port:-missing} env=$port"
    fi
    if curl -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
        ok "Dia CDP healthy on port $port"
    else
        warn "Dia CDP not healthy on port $port (agent-browser-dia-on starts it)"
    fi
    listeners="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
    if printf '%s\n' "$listeners" | grep -Eq '127\.0\.0\.1|::1'; then
        ok "Dia CDP listener is loopback-bound"
    elif [ -n "$listeners" ]; then
        warn "Dia CDP listener may not be loopback-only"
        printf '%s\n' "$listeners"
    fi
    if command -v agent-browser >/dev/null 2>&1; then
        ok "agent-browser available"
    else
        warn "agent-browser unavailable"
    fi
}

check_local_paths() {
    heading "Local paths"
    check_configured_path DOT_DROPBOX_HOME "Dropbox home"
    check_configured_path DOT_VAULT_HOME "Vault home"
    check_configured_path DOT_GDRIVE_HOME "Google Drive home"
    ok "manual app sign-in remains external: 1Password, Codex, Dia, Dropbox, and Google Drive"
}

# Lines are "path:line:content". Reserved example domains and Git host
# usernames are not personal data; a line is reported only if something else
# still matches once they are removed.
privacy_filter() {
    local pattern="$1"
    local line content

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        content="${line#*:*:}"
        content="$(printf '%s\n' "$content" | sed -E 's/[[:alnum:]_.%+-]+@(example\.(com|org|net)|github\.com|gitlab\.com)//g')"
        if printf '%s\n' "$content" | grep -Eq -e "$pattern"; then
            printf '%s\n' "$line"
        fi
    done
}

privacy_scan() {
    local pattern='/Users/[[:alnum:]_.-]+|Library/CloudStorage/Dropbox/[^"[:space:]]+|NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S|marketplaces\..*source =|^\[projects\."/Users/[[:alnum:]_.-]+|(^|[[:space:]="'\''`])[[:alnum:]_.%+]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|vault = "[^_][^"]*"'
    local blocklist="${DOT_PRIVACY_BLOCKLIST:-}"
    local matches entry

    heading "Privacy scan"
    if ! command -v rg >/dev/null 2>&1; then
        fail "ripgrep unavailable; privacy scan skipped"
        return
    fi
    scan_files() {
        (
            cd "$DOTFILES_DIR" || exit 1
            { git ls-files -z && git ls-files -z --others --exclude-standard; } |
                tr '\0' '\n' | sort -u | grep -v '^scripts/doctor\.sh$' | tr '\n' '\0' |
                xargs -0 rg -n --no-messages "$@" 2>/dev/null
        ) || true
    }

    matches="$(scan_files -e "$pattern" | privacy_filter "$pattern")"
    if [ -n "$blocklist" ] && [ -f "$blocklist" ]; then
        while IFS= read -r entry; do
            case "$entry" in "" | \#*) continue ;; esac
            matches="$matches"$'\n'"$(scan_files --fixed-strings -e "$entry")"
        done <"$blocklist"
    fi
    matches="$(printf '%s\n' "$matches" | awk 'NF')"

    if [ -n "$matches" ]; then
        fail "tracked or untracked nonignored files contain local/private-looking strings"
        printf '%s\n' "$matches"
        return
    fi
    ok "no local/private-looking strings in tracked or untracked files"

    if ! git -C "$DOTFILES_DIR" diff --cached --quiet --exit-code; then
        matches="$(git -C "$DOTFILES_DIR" grep --cached -n -E "$pattern" -- . ':!scripts/doctor.sh' 2>/dev/null | privacy_filter "$pattern")"
        if [ -n "$matches" ]; then
            fail "staged files contain local/private-looking strings"
            printf '%s\n' "$matches"
        else
            ok "no local/private-looking strings staged"
        fi
    fi
}

dot_progress_title "Dot doctor"
check_environment
check_repository
check_homebrew
check_links
check_tools
check_agents
check_git
check_dia
check_local_paths
privacy_scan

exit "$status"
