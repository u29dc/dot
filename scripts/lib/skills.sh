#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

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
