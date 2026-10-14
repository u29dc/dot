#!/usr/bin/env bash
# shellcheck disable=SC2154

dot_is_plugin() {
    [ -f "$1/plugin.json" ] || [ -f "$1/.claude-plugin/plugin.json" ] || [ -f "$1/.codex-plugin/plugin.json" ]
}

install_plugins() {
    local source
    local action
    local -a sources=("$SKILLS_BASE")
    while IFS= read -r source; do
        [ -n "$source" ] && sources+=("$source")
    done <<EOF
$(dot_each_colon_item "$DOT_SKILL_SOURCES")
EOF
    case "${DOT_PLUGIN_MODE:-link}" in
        link) action=disable-snapshots ;;
        package) action=install ;;
        *)
            dot_progress_fail "DOT_PLUGIN_MODE must be link or package"
            return 1
            ;;
    esac
    dot_require_command uv "to reconcile agent plugins" || return 1
    if dot_dry_run; then
        uv run --no-project --python '>=3.11' "$DOTFILES_DIR/scripts/plugins.py" "$action" "${sources[@]}" --dry-run
    else
        uv run --no-project --python '>=3.11' "$DOTFILES_DIR/scripts/plugins.py" "$action" "${sources[@]}"
    fi
}
