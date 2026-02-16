#!/usr/bin/env bash
# System update function

upd() {
    # ANSI colors
    local RED='\x1b[31m'
    local BLUE='\x1b[34m'
    local YELLOW='\x1b[33m'
    local DIM='\x1b[2m'
    local RESET='\x1b[0m'

    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}[FAIL]${RESET} Homebrew is not installed or not in PATH."
        return 1
    fi

    format_time() {
        local total_seconds="$1"
        local minutes=$((total_seconds / 60))
        local seconds=$((total_seconds % 60))

        if [ "$minutes" -gt 0 ]; then
            printf '%sm %ss' "$minutes" "$seconds"
        else
            printf '%ss' "$seconds"
        fi
    }

    count_items() {
        local items="$1"
        if [ -z "$items" ]; then
            echo "0"
            return 0
        fi
        printf '%s\n' "$items" | awk 'NF {count++} END {print count + 0}'
    }

    summarize_items() {
        local items="$1"
        local limit="${2:-6}"
        local total
        local sample
        local extra

        total="$(count_items "$items")"
        if [ "$total" -eq 0 ]; then
            echo "none"
            return 0
        fi

        sample="$(
            printf '%s\n' "$items" |
                awk 'NF {print $1}' |
                head -n "$limit" |
                awk 'BEGIN { ORS = "" } { if (NR > 1) printf ", "; printf "%s", $0 } END { print "" }'
        )"

        if [ "$total" -le "$limit" ]; then
            echo "$sample"
            return 0
        fi

        extra=$((total - limit))
        echo "${sample}, and ${extra} more"
    }

    run_step() {
        local label="$1"
        shift

        local step_start=$SECONDS
        local output=""
        local status=0

        printf '%b[RUN ]%b %s...\n' "$BLUE" "$RESET" "$label"
        output="$("$@" 2>&1)" || status=$?

        local elapsed=$((SECONDS - step_start))
        if [ "$status" -eq 0 ]; then
            printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(format_time "$elapsed")"
        else
            printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(format_time "$elapsed")"
            if [ -n "$output" ]; then
                printf '%b%s%b\n' "$DIM" "$output" "$RESET"
            fi
        fi

        return "$status"
    }

    local overall_start=$SECONDS
    local failed=0

    # Include greedy cask checks so auto-updating casks can still be reported/upgraded.
    local formula_before
    local cask_before
    formula_before="$(brew outdated --formula 2>/dev/null || true)"
    cask_before="$(brew outdated --cask --greedy 2>/dev/null || true)"

    local formula_before_count
    local cask_before_count
    local total_before
    formula_before_count="$(count_items "$formula_before")"
    cask_before_count="$(count_items "$cask_before")"
    total_before=$((formula_before_count + cask_before_count))

    if [ "$total_before" -eq 0 ]; then
        echo -e "${BLUE}No outdated formulae/casks found before update.${RESET}"
    else
        echo -e "${BLUE}Outdated before update:${RESET} ${formula_before_count} formulae, ${cask_before_count} casks"
        if [ "$formula_before_count" -gt 0 ]; then
            echo -e "${DIM}Formulae: $(summarize_items "$formula_before")${RESET}"
        fi
        if [ "$cask_before_count" -gt 0 ]; then
            echo -e "${DIM}Casks: $(summarize_items "$cask_before")${RESET}"
        fi
    fi

    run_step "Refreshing Homebrew metadata" brew update || failed=1

    if [ "$formula_before_count" -gt 0 ]; then
        run_step "Upgrading formulae" brew upgrade || failed=1
    else
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading formulae (none outdated)."
    fi

    if [ "$cask_before_count" -gt 0 ]; then
        run_step "Upgrading casks (greedy)" brew upgrade --cask --greedy || failed=1
    else
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading casks (none outdated)."
    fi

    run_step "Removing stale dependencies" brew autoremove || failed=1
    run_step "Cleaning old versions and cache" brew cleanup -s --prune=all || failed=1

    local formula_after
    local cask_after
    formula_after="$(brew outdated --formula 2>/dev/null || true)"
    cask_after="$(brew outdated --cask --greedy 2>/dev/null || true)"

    local formula_after_count
    local cask_after_count
    local total_after
    formula_after_count="$(count_items "$formula_after")"
    cask_after_count="$(count_items "$cask_after")"
    total_after=$((formula_after_count + cask_after_count))

    local overall_elapsed=$((SECONDS - overall_start))

    if [ "$failed" -ne 0 ]; then
        echo -e "${RED}[FAIL]${RESET} Homebrew update finished with errors in $(format_time "$overall_elapsed")."
        return 1
    fi

    if [ "$total_after" -eq 0 ]; then
        echo -e "${BLUE}Homebrew update complete in $(format_time "$overall_elapsed").${RESET}"
        return 0
    fi

    echo -e "${YELLOW}[WARN]${RESET} ${total_after} package(s) remain outdated after update."
    if [ "$formula_after_count" -gt 0 ]; then
        echo -e "${DIM}Remaining formulae: $(summarize_items "$formula_after")${RESET}"
    fi
    if [ "$cask_after_count" -gt 0 ]; then
        echo -e "${DIM}Remaining casks: $(summarize_items "$cask_after")${RESET}"
    fi
    echo -e "${YELLOW}[WARN]${RESET} Review pinned/held packages or run commands manually."
    return 1
}
