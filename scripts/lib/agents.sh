#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

# Merge a tracked settings template into a live agent settings file. Unchanged
# files are left untouched; changed files are backed up, then replaced
# atomically. Sets DOT_AGENT_CONFIG_CHANGED to 1 when a merge changes the file.
sync_agent_config() {
    local kind="$1"
    local template="$2"
    local dest="$3"
    local label="$4"
    shift 4
    local tmp
    local report
    local line

    DOT_AGENT_CONFIG_CHANGED=0
    dot_require_command uv "to merge $label" || return 1
    tmp="$(mktemp "${TMPDIR:-/tmp}/dot-agent-config.XXXXXX")"
    if ! report="$(uv run --quiet --no-project --python '>=3.11' "$DOTFILES_DIR/scripts/merge_agent_config.py" "$kind" "$template" "$dest" "$tmp" --report "$@")"; then
        rm -f "$tmp"
        dot_progress_fail "$label could not be merged; left unchanged: $dest"
        return 1
    fi

    if [ "$report" = unchanged ] && [ ! -L "$dest" ]; then
        rm -f "$tmp"
        dot_progress_ok "$label already current: $dest"
        return 0
    fi

    DOT_AGENT_CONFIG_CHANGED=1
    while IFS= read -r line; do
        case "$line" in
            changed | unchanged) ;;
            *) dot_progress_status "DIFF" "$DOT_PROGRESS_DIM" "$line" ;;
        esac
    done <<EOF
$report
EOF

    if dot_dry_run; then
        rm -f "$tmp"
        dot_progress_status "PLAN" "$DOT_PROGRESS_DIM" "merge $label -> $dest"
        return 0
    fi

    backup_copy_target "$template" "$dest" "backup-agent-config"
    mkdir -p "$(dirname "$dest")"
    # mv replaces a legacy settings symlink itself; never write through it.
    mv "$tmp" "$dest"
    dot_manifest_append "merge" "$template" "$dest"
    dot_progress_status "MERGE" "$DOT_PROGRESS_BLUE" "$label -> $dest"
}

sync_claude_settings() {
    sync_agent_config json "$DOTFILES_DIR/agents/claude.json" "${1:-$HOME/.claude/settings.json}" "Claude settings"
}

sync_codex_config() {
    sync_agent_config toml "$DOTFILES_DIR/agents/codex.toml" "${1:-$HOME/.codex/config.toml}" "Codex config" \
        --var "HOME=$HOME" \
        --var "TOOLS_HOME=$TOOLS_HOME" \
        --var "CODEX_NOTIFY_COMMAND=$DOT_CODEX_NOTIFY_COMMAND"
}

# Complete agent state shared by setup.sh and plugins.sh: policy links,
# settings, plugin snapshots and skill links.
sync_agents() {
    local section condition src dest

    while IFS='|' read -r section condition src dest; do
        [ "$section" = agents ] || continue
        link_file "$DOTFILES_DIR/$src" "$dest"
    done <<EOF
$(dot_link_targets)
EOF

    sync_claude_settings
    if dot_truthy "$DOT_ENABLE_CODEX_CONFIG"; then
        sync_codex_config
    else
        dot_progress_skip "Codex config merge (DOT_ENABLE_CODEX_CONFIG!=1)"
    fi

    # Retire packaged snapshots before links appear, so one name never loads twice.
    install_plugins
    read_known_extra_skill_sources
    link_skills "$HOME/.claude/skills"
    link_skills "$HOME/.codex/skills"
    link_skills "$HOME/.agents/skills"
    write_extra_skill_sources_state
}
