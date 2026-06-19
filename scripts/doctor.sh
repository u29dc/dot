#!/usr/bin/env bash
set -u

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

check_file() {
    local path="$1"
    if [ -e "$DOTFILES_DIR/$path" ]; then
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
        warn "terminal/bin/$name is not executable"
        return
    fi
    ok "terminal/bin/$name"
}

privacy_scan() {
    local pattern_file="${DOT_PRIVACY_BLOCKLIST:-}"
    local matches=""
    local base_pattern
    local files

    base_pattern='/Users/han|Library/CloudStorage/Dropbox/VAULT|NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S|marketplaces\..*source =|^\[projects\."/Users/han|han@|vault = "Personal"'
    files="$(
        {
            git -C "$DOTFILES_DIR" ls-files
            git -C "$DOTFILES_DIR" ls-files --others --exclude-standard
        } | sort -u |
            grep -v '^scripts/doctor\.sh$' |
            grep -v '^system/gitconfig$' |
            grep -v '^system/git-allowed-signers$' |
            grep -v '^system/launchagents/com\.u29dc\.dia-cdp\.plist$' |
            grep -v '^system/1password$'
    )"

    say ""
    say "Privacy scan"

    matches="$(
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
                    printf '%s\n' "$files" |
                        xargs rg -n --hidden --fixed-strings --no-messages -e "$pattern" 2>/dev/null || true
                done <"$pattern_file"
            } | awk 'NF'
        )"
    fi

    if [ -n "$matches" ]; then
        warn "tracked or untracked nonignored files contain local/private-looking strings"
        printf '%s\n' "$matches"
        return 1
    fi

    ok "no tracked local/private-looking strings found"
}

say "Dot doctor"
check_file "homebrew/Brewfile.base"
check_file "homebrew/Brewfile.profile1"
check_file "homebrew/Brewfile.profile2"
check_file "agents/codex.toml"

say ""
say "Tool wrappers"
for tool in buf cho fin grn let pdf tao; do
    check_wrapper "$tool"
done

if ! privacy_scan; then
    status=1
fi

exit "$status"
