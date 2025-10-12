#!/usr/bin/env bash
# System update function - Updates all Homebrew packages

upd() {
    # Colors for output
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local YELLOW='\033[0;33m'
    local CYAN='\033[0;36m'
    local NC='\033[0m' # No Color

    # Spinner characters
    local SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

    # Function to show spinner while command runs
    run_with_spinner() {
        # Handle job control for different shells
        if [ -n "$ZSH_VERSION" ]; then
            # Zsh-specific job control
            setopt local_options no_notify no_monitor
        elif [ -n "$BASH_VERSION" ]; then
            # Bash-specific job control
            local old_monitor_mode=$(set -o | grep monitor | awk '{print $2}')
            set +m
        fi

        local msg="$1"
        shift
        local cmd="$*"

        # Start spinner in background
        (
            local i=0
            while true; do
                printf "\r[${SPINNER[$i]}] %-40s" "$msg"
                i=$(((i + 1) % 10))
                sleep 0.1
            done
        ) &
        local spinner_pid=$!
        disown "$spinner_pid" 2>/dev/null

        # Run command and capture exit code
        local exit_code
        eval "$cmd" >/dev/null 2>&1
        exit_code=$?

        # Stop spinner
        kill "$spinner_pid" 2>/dev/null
        wait "$spinner_pid" 2>/dev/null

        # Restore Bash job control if needed
        if [ -n "$BASH_VERSION" ] && [ "$old_monitor_mode" = "on" ]; then
            set -m
        fi

        # Clear the spinner line
        printf "\r%-50s\r" ""

        return "$exit_code"
    }

    echo "${BLUE}System Update${NC}"
    echo "─────────────"

    # Check what's outdated before updating
    echo -n "Checking for updates..."
    local outdated_formulae=$(brew outdated --formula 2>/dev/null)
    local outdated_casks=$(brew outdated --cask 2>/dev/null)
    printf "\r%-30s\r" "" # Clear the checking message

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

    if [ "$total_outdated" -eq 0 ]; then
        echo "${GREEN}✓${NC} Everything is up to date!"
        return 0
    fi

    echo "${YELLOW}Found $total_outdated package(s) to update${NC}"
    echo ""

    # Update Homebrew
    run_with_spinner "Updating Homebrew packages..." "brew update && brew upgrade && brew upgrade --cask"
    local update_result=$?

    if [ "$update_result" -eq 0 ]; then
        echo "${GREEN}✓${NC} Updates completed successfully"
        echo ""

        # Show what was updated
        if [ "$formula_count" -gt 0 ]; then
            echo "${CYAN}Updated formulae:${NC}"
            echo "$outdated_formulae" | while read -r line; do
                echo "  • $line"
            done
            echo ""
        fi

        if [ "$cask_count" -gt 0 ]; then
            echo "${CYAN}Updated casks:${NC}"
            echo "$outdated_casks" | while read -r line; do
                echo "  • $line"
            done
            echo ""
        fi

        echo "${GREEN}All updates complete!${NC}"
        echo ""

        # Cleanup old versions
        echo "${CYAN}Cleaning up...${NC}"
        run_with_spinner "Removing old versions..." "brew cleanup -s"
        local cleanup_result=$?

        if [ "$cleanup_result" -eq 0 ]; then
            echo "${GREEN}✓${NC} Cleanup complete"

            # Show space saved
            local saved=$(brew cleanup -ns 2>/dev/null | grep "Pruned" | awk '{print $2" "$3}')
            if [ -n "$saved" ]; then
                echo "${CYAN}Disk space saved: $saved${NC}"
            fi
        else
            echo "${YELLOW}⚠${NC} Cleanup completed with warnings"
        fi
    else
        echo "${RED}✗${NC} Update failed"
        echo "Run 'brew update && brew upgrade' manually to see errors"
    fi
}
