#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

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
    dot_ensure_dir "$(dirname "$backup")"

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

# Copy the current content into the run backup, leaving the live file in place
# until the caller replaces it atomically. Symlinks are dereferenced.
backup_copy_target() {
    local src="$1"
    local dest="$2"
    local action="$3"
    local backup="$DOT_BACKUP_DIR/${dest#/}"

    [ -e "$dest" ] || return 0
    dot_progress_status "BACKUP" "$DOT_PROGRESS_YELLOW" "$dest -> $backup"
    dot_dry_run && return 0

    mkdir -p "$(dirname "$backup")"
    cp -pL "$dest" "$backup"
    dot_manifest_append "$action" "$src" "$dest" "$backup"
}

link_file() {
    local src="$1"
    local dest="$2"
    local previous

    if [ ! -e "$src" ]; then
        dot_progress_skip "Source not found: $src"
        return 0
    fi

    if [ -L "$dest" ]; then
        previous="$(readlink "$dest")"
        if [ "$previous" = "$src" ]; then
            dot_progress_ok "Already linked: $dest"
            return 0
        fi

        # The replaced link target is recorded so the change can be reverted.
        dot_apply rm "$dest"
        dot_manifest_append "replace-symlink" "$src" "$dest" "$previous"
    elif [ -e "$dest" ]; then
        backup_existing_target "$src" "$dest" "backup"
    fi

    dot_ensure_dir "$(dirname "$dest")"
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

# Link every executable in a directory, skipping dot and underscore helpers,
# then drop links into that directory whose source no longer exists.
link_executables() {
    local src_dir="$1"
    local dest_dir="$2"
    local src
    local link

    for src in "$src_dir"/*; do
        [ -f "$src" ] && [ -x "$src" ] || continue
        case "$(basename "$src")" in .* | _*) continue ;; esac
        link_file "$src" "$dest_dir/$(basename "$src")"
    done

    for link in "$dest_dir"/*; do
        [ -L "$link" ] && [ ! -e "$link" ] || continue
        remove_legacy_managed_link "$link" "$src_dir"
    done
}

remove_legacy_managed_link() {
    local dest="$1"
    local legacy_prefix="$2"
    local link_target

    [ -L "$dest" ] || return 0

    link_target="$(readlink "$dest")"
    case "$link_target" in
        "$legacy_prefix" | "$legacy_prefix"/*)
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
