#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154
set -Eeuo pipefail

# Dotfiles setup entrypoint. See AGENTS.md for the fresh-machine runbook.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR
# shellcheck source=scripts/lib/progress.sh
source "$DOTFILES_DIR/scripts/lib/progress.sh"

dot_setup_error() {
    local status=$?
    local line="${BASH_LINENO[0]:-${LINENO}}"
    local command="${BASH_COMMAND:-unknown}"

    dot_progress_fail "Setup failed (exit $status) at line $line: $command"
    exit "$status"
}

trap dot_setup_error ERR

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

load_env_file "$DOT_ENV_FILE"

dot_default() {
    local name="$1"
    local value="$2"
    if [ -z "${!name+x}" ]; then
        printf -v "$name" '%s' "$value"
        export "${name?}"
    fi
}

dot_default DOT_BREWFILES "homebrew/Brewfile.primary"
dot_default DOT_DEFAULT_SHELL "none"
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

write_shell_env_file() {
    local shell="$1"
    local dest="$2"
    local label="$3"
    local tmp
    local var
    local vars=(
        DOTFILES_DIR
        DOT_ENV_FILE
        DOT_BREWFILES
        DOT_DEFAULT_SHELL
        DOT_ENABLE_DIA
        DOT_ENABLE_ONEPASSWORD
        DOT_ENABLE_SYSTEM_EXTENSIONS
        DOT_ENABLE_CODEX_CONFIG
        DOT_ENABLE_GIT_CONFIG
        TOOLS_HOME
        SKILLS_BASE
        DOT_SKILL_SOURCES
        DOT_PRUNE_EXTRA_SKILLS
        DOT_DIA_APP
        AGENT_BROWSER_DIA_PORT
        CODEX_NODE_REPL_ENV_FILE
        DOT_CODEX_NOTIFY_COMMAND
        DOT_CLOUDSTORAGE_HOME
        DOT_DROPBOX_HOME
        DOT_VAULT_HOME
        DOT_GDRIVE_HOME
        HOMEBREW_NO_ENV_HINTS
        BAT_PAGER
        BAT_STYLE
        EZA_DEFAULT_IGNORE
        BUF_HOME
        CHO_HOME
        FIN_HOME
        GRN_HOME
        LET_HOME
        PDF_HOME
        TAO_HOME
        BUF
        CHO
        FIN
        GRN
        LET
        PDF
        TAO
    )

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if ! grep -Fq "dotfiles-managed:" "$dest" 2>/dev/null; then
            backup_existing_target "setup.env" "$dest" "backup-generated"
        fi
    fi

    dot_apply mkdir -p "$(dirname "$dest")"

    if dot_dry_run; then
        dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
        return 0
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/dot-shell-env.XXXXXX")"
    {
        printf '# dotfiles-managed: generated by scripts/setup.sh from setup.env\n'
        printf '# Do not edit directly; update setup.env and rerun setup.\n'
        case "$shell" in
            zsh) printf 'export DOT_ZSH_ENV_FILE=%s\n' "$(dot_shell_quote "$dest")" ;;
            fish) printf 'set -gx DOT_FISH_ENV_FILE %s\n' "$(dot_shell_quote "$dest")" ;;
        esac
        for var in "${vars[@]}"; do
            write_shell_env_var "$shell" "$var"
        done
    } >"$tmp"
    mv "$tmp" "$dest"
    dot_manifest_append "render" "setup.env" "$dest"
    dot_progress_status "RENDER" "$DOT_PROGRESS_BLUE" "$label -> $dest"
}

write_shell_env_files() {
    write_shell_env_file zsh "$HOME/.config/dot/env.zsh" "Zsh env"
    write_shell_env_file fish "$HOME/.config/dot/env.fish" "Fish env"
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

ensure_shell_allowed() {
    local shell_path="$1"

    if grep -Fxq "$shell_path" /etc/shells 2>/dev/null; then
        dot_progress_ok "Login shell allowed: $shell_path"
        return 0
    fi

    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "printf '%s\\n' '$shell_path' | sudo tee -a /etc/shells >/dev/null"
        return 0
    fi

    if [ ! -t 0 ]; then
        dot_progress_warn "Default shell not in /etc/shells: $shell_path"
        dot_progress_info "Run manually: printf '%s\\n' '$shell_path' | sudo tee -a /etc/shells >/dev/null"
        return 1
    fi

    dot_progress_run "Adding login shell to /etc/shells: $shell_path"
    if printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null; then
        dot_progress_ok "Login shell allowed: $shell_path"
    else
        dot_progress_fail "Could not add login shell to /etc/shells: $shell_path"
        return 1
    fi
}

apply_default_shell() {
    local shell_path
    local current_shell
    local login_user

    if [ -z "${DOT_DEFAULT_SHELL:-}" ] || [ "$DOT_DEFAULT_SHELL" = "none" ]; then
        dot_progress_skip "Default login shell (DOT_DEFAULT_SHELL=none)"
        return 0
    fi

    if ! shell_path="$(resolve_default_shell_path)"; then
        dot_progress_fail "Requested default shell is unavailable: $DOT_DEFAULT_SHELL"
        return 1
    fi

    if [ ! -x "$shell_path" ]; then
        dot_progress_fail "Requested default shell is not executable: $shell_path"
        return 1
    fi

    if ! ensure_shell_allowed "$shell_path"; then
        dot_progress_skip "Default login shell unchanged"
        return 0
    fi

    current_shell="$(current_login_shell)"
    if [ "$current_shell" = "$shell_path" ]; then
        dot_progress_ok "Default login shell already set: $shell_path"
        return 0
    fi

    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "chsh -s $shell_path $(id -un)"
        return 0
    fi

    if [ ! -t 0 ]; then
        dot_progress_warn "Default login shell is $current_shell; expected $shell_path"
        dot_progress_info "Run manually: chsh -s '$shell_path' '$(id -un)'"
        return 0
    fi

    login_user="$(id -un)"
    dot_progress_run "Setting default login shell: $shell_path"
    chsh -s "$shell_path" "$login_user" >/dev/null
    dot_progress_ok "Default login shell set: $shell_path"
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

remove_legacy_managed_link() {
    local dest="$1"
    local legacy_prefix="$2"
    local link_target

    [ -L "$dest" ] || return 0

    link_target="$(readlink "$dest")"
    case "$link_target" in
        "$legacy_prefix"/*)
            if dot_dry_run; then
                dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "rm $dest"
            else
                rm "$dest"
                dot_manifest_append "remove" "$link_target" "$dest"
                dot_progress_status "REMOVE" "$DOT_PROGRESS_YELLOW" "Legacy managed link: $dest"
            fi
            ;;
    esac
}

remove_empty_legacy_dir() {
    local dir="$1"

    [ -d "$dir" ] || return 0

    if find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
        return 0
    fi

    if dot_dry_run; then
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "rmdir $dir"
    else
        rmdir "$dir"
        dot_manifest_append "remove-dir" "$dir" "$dir"
        dot_progress_status "REMOVE" "$DOT_PROGRESS_YELLOW" "Empty legacy directory: $dir"
    fi
}

cleanup_legacy_fish_split() {
    local dest

    for dest in "$HOME"/.config/fish/conf.d/*.fish; do
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        remove_legacy_managed_link "$dest" "$DOTFILES_DIR/shell/fish/conf.d"
    done

    for dest in "$HOME"/.config/fish/functions/*.fish; do
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        remove_legacy_managed_link "$dest" "$DOTFILES_DIR/shell/fish/functions"
    done

    remove_empty_legacy_dir "$HOME/.config/fish/conf.d"
    remove_empty_legacy_dir "$HOME/.config/fish/functions"
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

dia_main_pids() {
    pgrep -x Dia 2>/dev/null || true
}

dia_main_commands() {
    local pid
    local process_command

    while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        process_command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        case "$process_command" in
            "$AGENT_BROWSER_DIA_BIN" | "$AGENT_BROWSER_DIA_BIN "*)
                printf '%s\n' "$process_command"
                ;;
        esac
    done < <(dia_main_pids)
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
write_shell_env_files
link_file "$DOTFILES_DIR/shell/zsh/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/shell/zsh/zprofile" "$HOME/.zprofile"
if [ -f "$HOME/.zshrc.local" ]; then
    dot_progress_skip "Local shell overrides already exist: $HOME/.zshrc.local"
elif dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp shell/zsh/zshrc.local.example $HOME/.zshrc.local"
else
    cp "$DOTFILES_DIR/shell/zsh/zshrc.local.example" "$HOME/.zshrc.local"
    dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "zshrc.local.example -> $HOME/.zshrc.local"
fi
cleanup_legacy_fish_split
link_file "$DOTFILES_DIR/shell/fish/config.fish" "$HOME/.config/fish/config.fish"
link_file "$DOTFILES_DIR/shell/fish/functions.fish" "$HOME/.config/fish/functions.fish"
if [ -f "$HOME/.config/fish/local.fish" ]; then
    dot_progress_skip "Local Fish overrides already exist: $HOME/.config/fish/local.fish"
elif dot_dry_run; then
    dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "cp shell/fish/local.fish.example $HOME/.config/fish/local.fish"
else
    mkdir -p "$HOME/.config/fish"
    cp "$DOTFILES_DIR/shell/fish/local.fish.example" "$HOME/.config/fish/local.fish"
    dot_progress_status "COPY" "$DOT_PROGRESS_BLUE" "local.fish.example -> $HOME/.config/fish/local.fish"
fi
apply_default_shell

dot_progress_section "Terminal configurations"
link_file "$DOTFILES_DIR/terminal/starship-dark.toml" "$HOME/.config/starship/starship-dark.toml"
link_file "$DOTFILES_DIR/terminal/starship-light.toml" "$HOME/.config/starship/starship-light.toml"
link_file "$DOTFILES_DIR/terminal/bottom.toml" "$HOME/.config/bottom/bottom.toml"
link_file "$DOTFILES_DIR/terminal/atuin.toml" "$HOME/.config/atuin/config.toml"
link_file "$DOTFILES_DIR/terminal/bat" "$HOME/.config/bat/config"
link_file "$DOTFILES_DIR/terminal/ignore" "$HOME/.ignore"
link_file "$DOTFILES_DIR/terminal/bin/buf" "$HOME/.local/bin/buf"
link_file "$DOTFILES_DIR/terminal/bin/cho" "$HOME/.local/bin/cho"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-chrome" "$HOME/.local/bin/agent-browser-chrome"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia" "$HOME/.local/bin/agent-browser-dia"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia-off" "$HOME/.local/bin/agent-browser-dia-off"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia-on" "$HOME/.local/bin/agent-browser-dia-on"
link_file "$DOTFILES_DIR/terminal/bin/agent-browser-dia-status" "$HOME/.local/bin/agent-browser-dia-status"
link_file "$DOTFILES_DIR/terminal/bin/delta-themed" "$HOME/.local/bin/delta-themed"
link_file "$DOTFILES_DIR/terminal/bin/fin" "$HOME/.local/bin/fin"
link_file "$DOTFILES_DIR/terminal/bin/grn" "$HOME/.local/bin/grn"
link_file "$DOTFILES_DIR/terminal/bin/let" "$HOME/.local/bin/let"
link_file "$DOTFILES_DIR/terminal/bin/pdf" "$HOME/.local/bin/pdf"
link_file "$DOTFILES_DIR/terminal/bin/tao" "$HOME/.local/bin/tao"
link_file "$DOTFILES_DIR/terminal/bin/upd" "$HOME/.local/bin/upd"

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
dot_progress_info "Restart terminal; use fish or zsh to switch shells explicitly"
dot_progress_info "Next verification: bun run doctor"
