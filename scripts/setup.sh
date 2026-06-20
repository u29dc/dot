#!/usr/bin/env bash
# shellcheck disable=SC2154
set -Eeuo pipefail

# Dotfiles setup entrypoint. See AGENTS.md for the fresh-machine runbook.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR
# shellcheck source=shell/functions/progress.sh
source "$DOTFILES_DIR/shell/functions/progress.sh"

dot_setup_error() {
    local status=$?
    local line="${BASH_LINENO[0]:-${LINENO}}"
    local command="${BASH_COMMAND:-unknown}"

    dot_progress_fail "Setup failed (exit $status) at line $line: $command"
    exit "$status"
}

trap dot_setup_error ERR

DOT_KNOWN_ENV_VARS=(
    DOT_BREWFILES
    DOT_TOOLS_HOME
    TOOLS_HOME
    SKILLS_BASE
    DOT_SKILL_SOURCES
    DOT_PRUNE_EXTRA_SKILLS
    DOT_SKILL_ROOTS_STATE
    DOT_ENABLE_DIA
    DOT_ENABLE_ONEPASSWORD
    DOT_ENABLE_SYSTEM_EXTENSIONS
    DOT_ENABLE_CODEX_CONFIG
    DOT_ENABLE_GIT_CONFIG
    DOT_CODEX_NOTIFY_COMMAND
    DOT_DIA_APP
    DOT_DIA_LOG_DIR
    AGENT_BROWSER_DIA_PORT
    CODEX_NODE_REPL_ENV_FILE
    DOT_GIT_USER_NAME
    DOT_GIT_USER_EMAIL
    DOT_GIT_SIGNING_KEY
    DOT_GIT_ALLOWED_SIGNERS_FILE
    DOT_OP_VAULT
    DOT_OP_SSH_AUTH_ITEM
    DOT_OP_SSH_SIGN_ITEM
)

NO_BREW=false
DRY_RUN=false
DOT_ENV_FILE="${DOT_ENV_FILE:-$DOTFILES_DIR/setup.env}"

usage() {
    cat <<'USAGE'
Usage: setup.sh [--dry-run] [--no-brew] [--env-file PATH]

Setup reads machine-local values from setup.env by default. Create it with:
  cp setup.env.example setup.env
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-brew)
            NO_BREW=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --env-file)
            if [ "$#" -lt 2 ]; then
                dot_progress_fail "--env-file requires a value"
                exit 2
            fi
            DOT_ENV_FILE="${2:-}"
            shift 2
            ;;
        --env-file=*)
            DOT_ENV_FILE="${1#--env-file=}"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            dot_progress_fail "Unknown argument: $1"
            usage >&2
            exit 2
            ;;
    esac
done

capture_process_env() {
    local var
    for var in "${DOT_KNOWN_ENV_VARS[@]}"; do
        eval "DOT_PROCESS_HAS_$var=\"\${$var+x}\""
        eval "DOT_PROCESS_VAL_$var=\"\${$var-}\""
    done
}

restore_process_env() {
    local var has value
    for var in "${DOT_KNOWN_ENV_VARS[@]}"; do
        has="$(eval "printf '%s' \"\$DOT_PROCESS_HAS_$var\"")"
        if [ -n "$has" ]; then
            value="$(eval "printf '%s' \"\$DOT_PROCESS_VAL_$var\"")"
            printf -v "$var" '%s' "$value"
            export "${var?}"
        fi
    done
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

capture_process_env
load_env_file "$DOT_ENV_FILE"
restore_process_env

dot_default() {
    local name="$1"
    local value="$2"
    if [ -z "${!name+x}" ]; then
        printf -v "$name" '%s' "$value"
        export "${name?}"
    fi
}

dot_default DOT_BREWFILES "homebrew/Brewfile.base"
dot_default DOT_ENABLE_DIA 1
dot_default DOT_ENABLE_ONEPASSWORD 1
dot_default DOT_ENABLE_SYSTEM_EXTENSIONS 1
dot_default DOT_ENABLE_CODEX_CONFIG 1
dot_default DOT_ENABLE_GIT_CONFIG 1

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

DOT_RUN_ID="${DOT_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
DOT_BACKUP_DIR="${DOT_BACKUP_DIR:-$HOME/.dotfiles-backups/$DOT_RUN_ID}"
DOT_BACKUP_MANIFEST="$DOT_BACKUP_DIR/manifest.tsv"

AGENT_BROWSER_DIA_APP="$DOT_DIA_APP"
AGENT_BROWSER_DIA_BIN="$AGENT_BROWSER_DIA_APP/Contents/MacOS/Dia"
AGENT_BROWSER_DIA_LAUNCH_AGENT="com.u29dc.dia-cdp"

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

dot_manifest_append() {
    local action="$1"
    local src="$2"
    local dest="$3"
    local backup="${4:-}"

    dot_dry_run && return 0
    mkdir -p "$DOT_BACKUP_DIR"
    if [ ! -f "$DOT_BACKUP_MANIFEST" ]; then
        printf 'action\tsource\tdestination\tbackup\n' >"$DOT_BACKUP_MANIFEST"
    fi
    printf '%s\t%s\t%s\t%s\n' "$action" "$src" "$dest" "$backup" >>"$DOT_BACKUP_MANIFEST"
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

backup_existing_target() {
    local src="$1"
    local dest="$2"
    local action="$3"
    local backup
    local rel

    [ -e "$dest" ] || [ -L "$dest" ] || return 0

    rel="${dest#/}"
    backup="$DOT_BACKUP_DIR/$rel"
    dot_progress_status "BACKUP" "$DOT_PROGRESS_YELLOW" "$dest -> $backup"
    dot_apply mkdir -p "$(dirname "$backup")"

    if dot_dry_run; then
        dot_manifest_append "$action" "$src" "$dest" "$backup"
        return 0
    fi

    if [ -L "$dest" ]; then
        cp -P "$dest" "$backup"
        rm "$dest"
    else
        mv "$dest" "$backup"
    fi
    dot_manifest_append "$action" "$src" "$dest" "$backup"
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

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if ! grep -Fq "dotfiles-managed:" "$dest" 2>/dev/null; then
            backup_existing_target "$template" "$dest" "backup-generated"
        fi
    fi

    dot_apply mkdir -p "$(dirname "$dest")"

    if dot_dry_run; then
        dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
        return 0
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/dot-render.XXXXXX")"
    render_template_to_file "$template" "$tmp"
    mv "$tmp" "$dest"
    dot_manifest_append "render" "$template" "$dest"
    dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
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

link_file() {
    local src="$1"
    local dest="$2"

    if [ ! -e "$src" ]; then
        dot_progress_skip "Source not found: $src"
        return 0
    fi

    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$src" ]; then
            dot_progress_ok "Already linked: $dest"
            return 0
        fi

        dot_apply rm "$dest"
        dot_manifest_append "remove-symlink" "$src" "$dest"
    elif [ -e "$dest" ]; then
        backup_existing_target "$src" "$dest" "backup"
    fi

    dot_apply mkdir -p "$(dirname "$dest")"
    dot_apply ln -s "$src" "$dest"
    dot_manifest_append "link" "$src" "$dest"

    if dot_dry_run; then
        dot_progress_status "LINK" "$DOT_PROGRESS_BLUE" "$(basename "$src") -> $dest"
        return 0
    fi

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        dot_progress_status "LINK" "$DOT_PROGRESS_BLUE" "$(basename "$src") -> $dest"
    else
        dot_progress_fail "Failed to create symlink: $dest"
        return 1
    fi
}

link_skills_from_source() {
    local target="$1"
    local src_dir="$2"
    local skill
    local name

    if [ ! -d "$src_dir" ]; then
        dot_progress_skip "Skills source not found: $src_dir"
        return 0
    fi

    for skill in "$src_dir"/*/; do
        [ -d "$skill" ] || continue
        name="$(basename "$skill")"
        case "$name" in .*) continue ;; esac
        [ -f "$skill/SKILL.md" ] || continue
        link_file "${skill%/}" "$target/$name"
    done
}

is_source_configured() {
    local target_path="$1"
    local source

    case "$target_path" in
        "$SKILLS_BASE" | "$SKILLS_BASE"/*) return 0 ;;
    esac

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        case "$target_path" in
            "$source" | "$source"/*) return 0 ;;
        esac
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF

    return 1
}

is_source_known() {
    local target_path="$1"
    local source

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        case "$target_path" in
            "$source" | "$source"/*) return 0 ;;
        esac
    done <<EOF
$KNOWN_EXTRA_SKILL_SOURCES
EOF

    return 1
}

remove_inactive_extra_skill_links() {
    local target="$1"
    local link
    local target_path
    local action

    [ -d "$target" ] || return 0
    dot_truthy "$DOT_PRUNE_EXTRA_SKILLS" || return 0

    for link in "$target"/*; do
        [ -L "$link" ] || continue
        target_path="$(readlink "$link")"
        is_source_configured "$target_path" && continue
        is_source_known "$target_path" || continue

        action="remove-inactive-extra-skill"
        dot_progress_status "REMOVE" "$DOT_PROGRESS_YELLOW" "$link"
        dot_apply rm "$link"
        dot_manifest_append "$action" "$target_path" "$link"
    done
}

read_known_extra_skill_sources() {
    local source
    KNOWN_EXTRA_SKILL_SOURCES=""

    if [ -f "$DOT_SKILL_ROOTS_STATE" ]; then
        while IFS= read -r source; do
            [ -n "$source" ] || continue
            KNOWN_EXTRA_SKILL_SOURCES="${KNOWN_EXTRA_SKILL_SOURCES}${source}
"
        done <"$DOT_SKILL_ROOTS_STATE"
    fi

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        KNOWN_EXTRA_SKILL_SOURCES="${KNOWN_EXTRA_SKILL_SOURCES}${source}
"
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF
}

write_extra_skill_sources_state() {
    local source

    dot_dry_run && return 0

    mkdir -p "$(dirname "$DOT_SKILL_ROOTS_STATE")"
    : >"$DOT_SKILL_ROOTS_STATE"
    while IFS= read -r source; do
        [ -n "$source" ] || continue
        [ -d "$source" ] || continue
        printf '%s\n' "$source" >>"$DOT_SKILL_ROOTS_STATE"
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF
}

link_skills() {
    local target="$1"
    local source

    dot_apply mkdir -p "$target"
    remove_inactive_extra_skill_links "$target"
    link_skills_from_source "$target" "$SKILLS_BASE"

    while IFS= read -r source; do
        [ -n "$source" ] || continue
        [ -d "$source" ] || continue
        dot_progress_info "Extra skills source active"
        link_skills_from_source "$target" "$source"
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF
}

dia_cdp_url() {
    printf 'http://127.0.0.1:%s/json/version\n' "$AGENT_BROWSER_DIA_PORT"
}

dia_launch_agent_domain() {
    printf 'gui/%s\n' "$UID"
}

dia_launch_agent_service() {
    printf '%s/%s\n' "$(dia_launch_agent_domain)" "$AGENT_BROWSER_DIA_LAUNCH_AGENT"
}

dia_cdp_healthy() {
    curl -fsS "$(dia_cdp_url)" >/dev/null 2>&1
}

wait_for_dia_cdp() {
    local tries="${1:-40}"
    local i

    for ((i = 0; i < tries; i++)); do
        if dia_cdp_healthy; then
            return 0
        fi
        sleep 0.25
    done

    return 1
}

dia_main_commands() {
    ps -axo command= | awk -v bin="$AGENT_BROWSER_DIA_BIN" 'index($0, bin) { print }'
}

dia_running_without_cdp() {
    local commands
    commands="$(dia_main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1 && return 1
    return 0
}

dia_running_with_cdp() {
    local commands
    commands="$(dia_main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1
}

dia_gui_domain_available() {
    launchctl print "$(dia_launch_agent_domain)" >/dev/null 2>&1
}

dia_launch_agent_loaded() {
    launchctl print "$(dia_launch_agent_service)" >/dev/null 2>&1
}

setup_dia_cdp() {
    local plist_path
    local domain_target
    local service_target

    plist_path="$HOME/Library/LaunchAgents/${AGENT_BROWSER_DIA_LAUNCH_AGENT}.plist"
    domain_target="$(dia_launch_agent_domain)"
    service_target="$(dia_launch_agent_service)"

    if dot_dry_run; then
        dot_progress_skip "Dia CDP startup (--dry-run)"
        return 0
    fi

    if [ ! -f "$plist_path" ]; then
        dot_progress_skip "Dia LaunchAgent not rendered: $plist_path"
        return 0
    fi

    if [ ! -x "$AGENT_BROWSER_DIA_BIN" ]; then
        dot_progress_skip "Dia.app not found: $AGENT_BROWSER_DIA_APP"
        return 0
    fi

    if ! command -v launchctl >/dev/null 2>&1; then
        dot_progress_skip "launchctl not available"
        return 0
    fi

    if ! dia_gui_domain_available; then
        dot_progress_skip "GUI launchctl domain unavailable: $domain_target"
        return 0
    fi

    if dia_cdp_healthy; then
        dot_progress_ok "Dia CDP already available on port $AGENT_BROWSER_DIA_PORT"
        return 0
    fi

    if dia_running_without_cdp; then
        dot_progress_skip "Dia is already running without CDP. Quit Dia, then run agent-browser-dia-on or rerun setup."
        return 0
    fi

    if dia_running_with_cdp; then
        if wait_for_dia_cdp 20; then
            dot_progress_ok "Dia CDP became healthy on port $AGENT_BROWSER_DIA_PORT"
        else
            dot_progress_skip "Dia is already running with a CDP flag, but port $AGENT_BROWSER_DIA_PORT is not healthy yet."
        fi
        return 0
    fi

    dot_progress_run "Starting Dia CDP LaunchAgent"
    if dia_launch_agent_loaded; then
        launchctl kickstart -k "$service_target"
    else
        launchctl bootstrap "$domain_target" "$plist_path"
    fi

    if wait_for_dia_cdp; then
        dot_progress_ok "Dia CDP ready on port $AGENT_BROWSER_DIA_PORT"
    else
        dot_progress_warn "Dia LaunchAgent loaded, but CDP did not become healthy on port $AGENT_BROWSER_DIA_PORT"
    fi
}

validate_setup_env

dot_progress_title "Dotfiles setup"
dot_progress_info "Directory: $DOTFILES_DIR"
dot_progress_info "Env file: $DOT_ENV_FILE"
dot_progress_info "Backup dir: $DOT_BACKUP_DIR"

if dot_dry_run; then
    dot_progress_info "Mode: dry-run"
fi

dot_progress_info "Homebrew layers:"
while IFS= read -r brewfile; do
    [ -n "$brewfile" ] || continue
    dot_progress_info "  - $brewfile"
done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF

if [ "$NO_BREW" = true ]; then
    dot_progress_skip "Homebrew packages (--no-brew)"
elif dot_dry_run; then
    dot_progress_skip "Homebrew packages (--dry-run)"
else
    if ! command -v brew >/dev/null 2>&1; then
        dot_progress_run_step --stream "Installing Homebrew" install_homebrew
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        dot_progress_ok "Homebrew available"
    fi

    while IFS= read -r brewfile; do
        [ -n "$brewfile" ] || continue
        install_brewfile "$(dot_abs_path "$brewfile")"
    done <<EOF
$(dot_each_colon_item "$DOT_BREWFILES")
EOF
fi

if dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "mkdir -p $TOOLS_HOME"
else
    dot_progress_run_step "Creating tool home" mkdir -p "$TOOLS_HOME"
fi

dot_progress_section "Shell configurations"
link_file "$DOTFILES_DIR/shell/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/shell/zprofile" "$HOME/.zprofile"
if [ -f "$HOME/.zshrc.local" ]; then
    dot_progress_skip "Local shell overrides already exist: $HOME/.zshrc.local"
elif dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp shell/zshrc.local.example $HOME/.zshrc.local"
else
    cp "$DOTFILES_DIR/shell/zshrc.local.example" "$HOME/.zshrc.local"
    dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "zshrc.local.example -> $HOME/.zshrc.local"
fi

dot_progress_section "Terminal configurations"
link_file "$DOTFILES_DIR/terminal/starship-dark.toml" "$HOME/.config/starship/starship-dark.toml"
link_file "$DOTFILES_DIR/terminal/starship-light.toml" "$HOME/.config/starship/starship-light.toml"
link_file "$DOTFILES_DIR/terminal/bottom.toml" "$HOME/.config/bottom/bottom.toml"
link_file "$DOTFILES_DIR/terminal/atuin.toml" "$HOME/.config/atuin/config.toml"
link_file "$DOTFILES_DIR/terminal/bat" "$HOME/.config/bat/config"
link_file "$DOTFILES_DIR/terminal/ignore" "$HOME/.ignore"
link_file "$DOTFILES_DIR/terminal/bin/buf" "$HOME/.local/bin/buf"
link_file "$DOTFILES_DIR/terminal/bin/cho" "$HOME/.local/bin/cho"
link_file "$DOTFILES_DIR/terminal/bin/delta-themed" "$HOME/.local/bin/delta-themed"
link_file "$DOTFILES_DIR/terminal/bin/fin" "$HOME/.local/bin/fin"
link_file "$DOTFILES_DIR/terminal/bin/grn" "$HOME/.local/bin/grn"
link_file "$DOTFILES_DIR/terminal/bin/let" "$HOME/.local/bin/let"
link_file "$DOTFILES_DIR/terminal/bin/pdf" "$HOME/.local/bin/pdf"
link_file "$DOTFILES_DIR/terminal/bin/tao" "$HOME/.local/bin/tao"

link_file "$DOTFILES_DIR/biome.json" "$HOME/.config/biome/biome.json"
link_file "$DOTFILES_DIR/tsconfig.json" "$HOME/.config/typescript/tsconfig.json"
link_file "$DOTFILES_DIR/bunfig.toml" "$HOME/.bunfig.toml"
link_file "$DOTFILES_DIR/uv.toml" "$HOME/.config/uv/uv.toml"

dot_progress_section "Editor configurations"
link_file "$DOTFILES_DIR/editor/settings.json" "$HOME/.config/zed/settings.json"
link_file "$DOTFILES_DIR/editor/keymap.json" "$HOME/.config/zed/keymap.json"

dot_progress_section "Additional terminal configurations"
write_managed_file "$DOTFILES_DIR/terminal/ssh.template" "$HOME/.ssh/config" "SSH config"
link_file "$DOTFILES_DIR/terminal/neofetch" "$HOME/.config/neofetch/config.conf"
link_file "$DOTFILES_DIR/terminal/statusline" "$HOME/.config/ccstatusline/settings.json"
link_file "$DOTFILES_DIR/terminal/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link_file "$DOTFILES_DIR/terminal/yt-dlp" "$HOME/.config/yt-dlp/config"
link_file "$DOTFILES_DIR/terminal/agent-browser.json" "$HOME/.agent-browser/config.json"
link_file "$DOTFILES_DIR/terminal/agent-browser.chrome.json" "$HOME/.agent-browser/chrome.json"

dot_progress_section "System configurations"
if dot_truthy "$DOT_ENABLE_GIT_CONFIG"; then
    write_managed_file "$DOTFILES_DIR/system/gitconfig.template" "$HOME/.gitconfig" "gitconfig"
    write_managed_file "$DOTFILES_DIR/system/git-allowed-signers.template" "$DOT_GIT_ALLOWED_SIGNERS_FILE" "git allowed signers"
else
    dot_progress_skip "Git config generation (DOT_ENABLE_GIT_CONFIG!=1)"
fi

if dot_truthy "$DOT_ENABLE_SYSTEM_EXTENSIONS"; then
    link_file "$DOTFILES_DIR/system/karabiner" "$HOME/.config/karabiner/karabiner.json"
    link_file "$DOTFILES_DIR/macos/.macos" "$HOME/.macos"
else
    dot_progress_skip "System extension configs (DOT_ENABLE_SYSTEM_EXTENSIONS!=1)"
fi

if dot_truthy "$DOT_ENABLE_ONEPASSWORD"; then
    write_managed_file "$DOTFILES_DIR/system/1password.agent.toml.template" "$HOME/.config/1Password/ssh/agent.toml" "1Password SSH agent"
else
    dot_progress_skip "1Password SSH agent config (DOT_ENABLE_ONEPASSWORD!=1)"
fi

if dot_truthy "$DOT_ENABLE_DIA"; then
    write_managed_file "$DOTFILES_DIR/system/launchagents/com.u29dc.dia-cdp.plist.template" "$HOME/Library/LaunchAgents/com.u29dc.dia-cdp.plist" "Dia CDP LaunchAgent"
    setup_dia_cdp
else
    dot_progress_skip "Dia CDP LaunchAgent (DOT_ENABLE_DIA!=1)"
fi

dot_progress_section "Agent configurations"
link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link_file "$DOTFILES_DIR/agents/claude.json" "$HOME/.claude/settings.json"
read_known_extra_skill_sources
link_skills "$HOME/.claude/skills"

link_file "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
if dot_truthy "$DOT_ENABLE_CODEX_CONFIG"; then
    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "scripts/codex.sh --dest $HOME/.codex/config.toml"
    else
        DOT_BACKUP_DIR="$DOT_BACKUP_DIR" DOT_BACKUP_MANIFEST="$DOT_BACKUP_MANIFEST" TOOLS_HOME="$TOOLS_HOME" CODEX_NODE_REPL_ENV_FILE="$CODEX_NODE_REPL_ENV_FILE" DOT_CODEX_NOTIFY_COMMAND="$DOT_CODEX_NOTIFY_COMMAND" "$DOTFILES_DIR/scripts/codex.sh" --dest "$HOME/.codex/config.toml"
    fi
else
    dot_progress_skip "Codex config generation (DOT_ENABLE_CODEX_CONFIG!=1)"
fi
link_skills "$HOME/.codex/skills"
link_skills "$HOME/.agents/skills"
write_extra_skill_sources_state

dot_progress_ok "Setup complete"
dot_progress_info "Restart terminal or run: source ~/.zshrc"
