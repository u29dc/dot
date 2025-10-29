#!/usr/bin/env bash
# System update function

upd() {
    # color scheme (ANSI escape codes)
    local RED='\x1b[31m'
    local BLUE='\x1b[34m'
    local YELLOW='\x1b[33m'
    local DIM='\x1b[2m'
    local RESET='\x1b[0m'

    # Timing capture mechanism: EPOCHREALTIME provides microsecond precision (bash 5+)
    # Fallback to date command for older bash versions
    get_timestamp() {
        if [ -n "$BASH_VERSION" ] && [ "${BASH_VERSINFO[0]}" -ge 5 ]; then
            echo "$EPOCHREALTIME"
        else
            date +%s.%N
        fi
    }

    # Format elapsed time: <1s shows ms, ≥1s shows s with 2 decimals
    format_time() {
        local elapsed=$1
        local seconds=$(echo "$elapsed" | awk '{printf "%.3f", $1}')
        if (($(echo "$seconds < 1" | bc -l 2>/dev/null || echo 0))); then
            local ms=$(echo "$seconds * 1000" | awk '{printf "%.0f", $1}')
            echo "${ms}ms"
        else
            echo "$(echo "$seconds" | awk '{printf "%.2f", $1}')s"
        fi
    }

    # Simple dot animation: cycles through . .. ...
    show_dots() {
        local dots=""
        while true; do
            for i in 1 2 3; do
                dots=$(printf '.%.0s' $(seq 1 "$i"))
                printf "\r%s   " "$dots"
                sleep 0.5
            done
        done
    }

    # Start dot animation and check what's outdated
    set +m # Disable job control messages
    show_dots &
    local dots_pid=$!

    local check_start=$(get_timestamp)
    local outdated_formulae=$(brew outdated --formula 2>/dev/null)
    local outdated_casks=$(brew outdated --cask 2>/dev/null)
    local check_elapsed=$(echo "$(get_timestamp) - $check_start" | bc 2>/dev/null || echo "0")
    local check_time=$(format_time "$check_elapsed")

    # Stop animation and clear line
    kill "$dots_pid" 2>/dev/null
    wait "$dots_pid" 2>/dev/null
    set -m # Re-enable job control
    printf "\r\033[K"

    # Count outdated packages
    local formula_count=0
    local cask_count=0
    if [ -n "$outdated_formulae" ]; then
        formula_count=$(echo "$outdated_formulae" | wc -l | tr -d ' ')
    fi
    if [ -n "$outdated_casks" ]; then
        cask_count=$(echo "$outdated_casks" | wc -l | tr -d ' ')
    fi

    local total_outdated=$((formula_count + cask_count))

    # No updates case
    if [ "$total_outdated" -eq 0 ]; then
        echo -e "${BLUE}Everything up to date (checked in ${check_time}).${RESET}"
        return 0
    fi

    # Update Homebrew with dot animation
    set +m # Disable job control messages
    show_dots &
    dots_pid=$!

    local update_start=$(get_timestamp)
    local update_output
    local update_result

    update_output=$(brew update 2>&1 && brew upgrade 2>&1 && brew upgrade --cask 2>&1)
    update_result=$?

    local update_elapsed=$(echo "$(get_timestamp) - $update_start" | bc 2>/dev/null || echo "0")
    local update_time=$(format_time "$update_elapsed")

    # Stop animation and clear line
    kill "$dots_pid" 2>/dev/null
    wait "$dots_pid" 2>/dev/null
    set -m # Re-enable job control
    printf "\r\033[K"

    if [ "$update_result" -eq 0 ]; then
        # Success case: show summary
        echo -e "${BLUE}Updated ${formula_count} formulae and ${cask_count} casks in ${update_time}.${RESET}"

        # Cleanup old versions with dot animation
        set +m # Disable job control messages
        show_dots &
        dots_pid=$!

        local cleanup_start=$(get_timestamp)
        local cleanup_output
        local cleanup_result

        cleanup_output=$(brew cleanup -s 2>&1)
        cleanup_result=$?

        local cleanup_elapsed=$(echo "$(get_timestamp) - $cleanup_start" | bc 2>/dev/null || echo "0")
        local cleanup_time=$(format_time "$cleanup_elapsed")

        # Stop animation and clear line
        kill "$dots_pid" 2>/dev/null
        wait "$dots_pid" 2>/dev/null
        set -m # Re-enable job control
        printf "\r\033[K"

        if [ "$cleanup_result" -eq 0 ]; then
            echo -e "${BLUE}Cleaned up in ${cleanup_time}.${RESET}"
        else
            echo -e "${RED}[FAIL]${RESET} Cleanup failed in ${cleanup_time}"
            echo -e "${DIM}${cleanup_output}${RESET}"
        fi
    else
        # Update error case: expand to multi-line with details
        echo -e "${RED}[FAIL]${RESET} Update failed after ${update_time}"
        echo -e "${DIM}Attempted to update ${total_outdated} packages (${formula_count} formulae, ${cask_count} casks)${RESET}"
        echo -e "${DIM}${update_output}${RESET}"
        echo ""
        echo -e "${YELLOW}[WARN]${RESET} Run 'brew update && brew upgrade' manually to see full errors"
        return 1
    fi

}
