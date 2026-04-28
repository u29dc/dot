#!/usr/bin/env bash
# System update function

# shellcheck source=shell/functions/progress.sh
source "${DOTFILES_DIR:-$HOME/Git/dot}/shell/functions/progress.sh"

upd() {
    # ANSI colors
    local RED="$DOT_PROGRESS_RED"
    local BLUE="$DOT_PROGRESS_BLUE"
    local YELLOW="$DOT_PROGRESS_YELLOW"
    local DIM="$DOT_PROGRESS_DIM"
    local RESET="$DOT_PROGRESS_RESET"

    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}[FAIL]${RESET} Homebrew is not installed or not in PATH."
        return 1
    fi

    upd__count_items() {
        local items="$1"
        if [ -z "$items" ]; then
            echo "0"
            return 0
        fi
        printf '%s\n' "$items" | awk 'NF {count++} END {print count + 0}'
    }

    upd__summarize_items() {
        local items="$1"
        local limit="${2:-6}"
        local total
        local sample
        local extra

        total="$(upd__count_items "$items")"
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

    upd__json_outdated_casks() {
        local json_payload="$1"
        [ -n "$json_payload" ] || return 0
        command -v ruby >/dev/null 2>&1 || return 0

        printf '%s\n' "$json_payload" | ruby -rjson -e '
            begin
              data = JSON.parse(STDIN.read)
              (data["casks"] || []).each do |cask|
                token = cask["token"] || cask["full_token"]
                puts(token) if token.is_a?(String) && !token.empty?
              end
            rescue JSON::ParserError
            end
        ' 2>/dev/null
    }

    upd__manual_casks_from_tokens() {
        local tokens="$1"
        local info_json=""
        local token=""
        local -a token_args=()
        [ -n "$tokens" ] || return 0
        command -v ruby >/dev/null 2>&1 || return 2

        while IFS= read -r token; do
            [ -n "$token" ] || continue
            token_args+=("$token")
        done <<<"$tokens"

        [ "${#token_args[@]}" -gt 0 ] || return 0

        info_json="$(brew info --cask --json=v2 "${token_args[@]}" 2>/dev/null)" || return 3
        [ -n "$info_json" ] || return 3

        printf '%s\n' "$info_json" | ruby -rjson -e '
            begin
              data = JSON.parse(STDIN.read)
              (data["casks"] || []).each do |cask|
                token = cask["token"] || cask["name"] || cask["full_token"]
                next unless token.is_a?(String) && !token.empty?
                artifacts = cask["artifacts"]
                next unless artifacts.is_a?(Array)

                manual_installer = artifacts.any? do |artifact|
                  next false unless artifact.is_a?(Hash)
                  installers = artifact["installer"]
                  next false unless installers.is_a?(Array)
                  installers.any? { |entry| entry.is_a?(Hash) && entry.key?("manual") }
                end

                puts(token) if manual_installer
              end
            rescue JSON::ParserError
              exit 4
            end
        ' 2>/dev/null || return 4
    }

    upd__manual_cask_detection_reason() {
        local status="${1:-0}"
        case "$status" in
            2) printf 'ruby runtime unavailable' ;;
            3) printf 'Homebrew cask metadata unavailable' ;;
            4) printf 'Homebrew cask metadata parse failure' ;;
            *) printf 'detection failure (status %s)' "$status" ;;
        esac
    }

    upd__filter_excluded_items() {
        local items="$1"
        local excluded="$2"
        if [ -z "$excluded" ]; then
            printf '%s' "$items"
            return 0
        fi

        awk '
            NR == FNR {
                if (NF) {
                    excluded[$0] = 1
                }
                next
            }
            NF && !($0 in excluded) {
                print $0
            }
        ' <(printf '%s\n' "$excluded") <(printf '%s\n' "$items")
    }

    upd__run_step() {
        dot_progress_run_step "$@"
    }

    upd__apply_step_result() {
        local step_result="$1"
        if [ "$step_result" -eq 130 ] || [ "$step_result" -eq 143 ]; then
            echo -e "${YELLOW}[WARN]${RESET} Update interrupted."
            return 130
        fi
        if [ "$step_result" -ne 0 ]; then
            failed=1
        fi
        return 0
    }

    upd__ensure_sudo_session() {
        local require_sudo="${1:-0}"
        local mode="${2:-prompt}"
        [ "$require_sudo" -gt 0 ] || return 0

        if ! command -v sudo >/dev/null 2>&1; then
            return 0
        fi

        if sudo -n true >/dev/null 2>&1; then
            if [ "$mode" = "refresh" ]; then
                sudo -n -v >/dev/null 2>&1 || true
            fi
            return 0
        fi

        if [ "$mode" = "refresh" ]; then
            return 0
        fi

        if [ ! -t 0 ] || [ ! -t 1 ]; then
            echo -e "${YELLOW}[WARN]${RESET} Sudo may be requested during cask upgrade (no interactive TTY)."
            return 0
        fi

        printf '%b[RUN ]%b Please enter your password...\n' "$BLUE" "$RESET"
        if sudo -v; then
            if sudo -n true >/dev/null 2>&1; then
                printf '%b[OK  ]%b Administrator session ready.\n' "$BLUE" "$RESET"
            else
                echo -e "${YELLOW}[WARN]${RESET} Sudo credentials cannot be cached on this system; prompts may still appear during cask upgrades."
            fi
            return 0
        fi

        echo -e "${RED}[FAIL]${RESET} Failed to authenticate sudo session."
        return 1
    }

    local overall_start=$SECONDS
    local failed=0

    # Include greedy cask checks so auto-updating casks can still be reported/upgraded.
    local formula_before
    local cask_before_json
    local cask_before
    local manual_casks_before
    local actionable_casks_before
    local manual_cask_detection_before_status=0
    formula_before="$(brew outdated --formula 2>/dev/null || true)"
    cask_before_json="$(brew outdated --cask --greedy --json=v2 2>/dev/null || true)"
    cask_before="$(upd__json_outdated_casks "$cask_before_json")"
    if [ -z "$cask_before" ]; then
        cask_before="$(brew outdated --cask --greedy 2>/dev/null || true)"
    fi
    manual_casks_before=""
    if [ -n "$cask_before" ]; then
        if manual_casks_before="$(upd__manual_casks_from_tokens "$cask_before")"; then
            :
        else
            manual_cask_detection_before_status=$?
            manual_casks_before=""
        fi
    fi
    if [ "$manual_cask_detection_before_status" -ne 0 ]; then
        actionable_casks_before=""
    else
        actionable_casks_before="$(upd__filter_excluded_items "$cask_before" "$manual_casks_before")"
    fi

    local formula_before_count
    local cask_before_count
    local actionable_cask_before_count
    local total_before
    formula_before_count="$(upd__count_items "$formula_before")"
    cask_before_count="$(upd__count_items "$cask_before")"
    actionable_cask_before_count="$(upd__count_items "$actionable_casks_before")"
    total_before=$((formula_before_count + cask_before_count))

    if [ "$total_before" -eq 0 ]; then
        echo -e "${BLUE}No outdated formulae/casks found before update.${RESET}"
    else
        echo -e "${BLUE}Outdated before update:${RESET} ${formula_before_count} formulae, ${cask_before_count} casks"
        if [ "$formula_before_count" -gt 0 ]; then
            echo -e "${DIM}Formulae: $(upd__summarize_items "$formula_before")${RESET}"
        fi
        if [ "$cask_before_count" -gt 0 ]; then
            echo -e "${DIM}Casks: $(upd__summarize_items "$cask_before")${RESET}"
        fi
    fi

    upd__ensure_sudo_session "$actionable_cask_before_count" "prompt" || return 1

    local step_result=0

    upd__run_step "Refreshing Homebrew metadata" brew update
    step_result=$?
    upd__apply_step_result "$step_result" || return $?

    if [ "$formula_before_count" -gt 0 ]; then
        upd__run_step "Upgrading formulae" brew upgrade --formula
        step_result=$?
        upd__apply_step_result "$step_result" || return $?
    else
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading formulae (none outdated)."
    fi

    if [ "$manual_cask_detection_before_status" -ne 0 ] && [ "$cask_before_count" -gt 0 ]; then
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading casks (manual-install cask detection unavailable: $(upd__manual_cask_detection_reason "$manual_cask_detection_before_status"))."
    elif [ "$actionable_cask_before_count" -gt 0 ]; then
        local cask_token=""
        local -a actionable_cask_args=()
        while IFS= read -r cask_token; do
            [ -n "$cask_token" ] || continue
            actionable_cask_args+=("$cask_token")
        done <<<"$actionable_casks_before"

        # Refresh ticket right before cask upgrades to reduce chance of mid-step prompts.
        upd__ensure_sudo_session "$actionable_cask_before_count" "refresh" || return 1
        upd__run_step --stream "Upgrading casks (greedy)" brew upgrade --cask --greedy "${actionable_cask_args[@]}"
        step_result=$?
        upd__apply_step_result "$step_result" || return $?
    elif [ "$cask_before_count" -gt 0 ]; then
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading casks (all outdated casks are installer-manual)."
    else
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading casks (none outdated)."
    fi

    upd__run_step "Removing stale dependencies" brew autoremove
    step_result=$?
    upd__apply_step_result "$step_result" || return $?

    upd__run_step "Cleaning old versions and cache" brew cleanup -s --prune=all
    step_result=$?
    upd__apply_step_result "$step_result" || return $?

    local formula_after
    local cask_after_json
    local cask_after
    local manual_casks_after
    local cask_after_effective
    local manual_cask_detection_after_status=0
    formula_after="$(brew outdated --formula 2>/dev/null || true)"
    cask_after_json="$(brew outdated --cask --greedy --json=v2 2>/dev/null || true)"
    cask_after="$(upd__json_outdated_casks "$cask_after_json")"
    if [ -z "$cask_after" ]; then
        cask_after="$(brew outdated --cask --greedy 2>/dev/null || true)"
    fi
    manual_casks_after=""
    cask_after_effective="$cask_after"
    if [ -n "$cask_after" ]; then
        if manual_casks_after="$(upd__manual_casks_from_tokens "$cask_after")"; then
            cask_after_effective="$(upd__filter_excluded_items "$cask_after" "$manual_casks_after")"
        else
            manual_cask_detection_after_status=$?
            manual_casks_after=""
        fi
    fi

    local formula_after_count
    local cask_after_count
    local total_after
    formula_after_count="$(upd__count_items "$formula_after")"
    cask_after_count="$(upd__count_items "$cask_after_effective")"
    total_after=$((formula_after_count + cask_after_count))

    local overall_elapsed=$((SECONDS - overall_start))

    if [ "$failed" -ne 0 ]; then
        echo -e "${RED}[FAIL]${RESET} Homebrew update finished with errors in $(dot_progress_format_time "$overall_elapsed")."
        return 1
    fi

    if [ "$total_after" -eq 0 ]; then
        if [ -n "$manual_casks_after" ]; then
            echo -e "${YELLOW}[WARN]${RESET} Manual-install casks skipped by Homebrew: $(upd__summarize_items "$manual_casks_after")"
        fi
        echo -e "${BLUE}Homebrew update complete in $(dot_progress_format_time "$overall_elapsed").${RESET}"
        return 0
    fi

    echo -e "${YELLOW}[WARN]${RESET} ${total_after} package(s) remain outdated after update."
    if [ "$formula_after_count" -gt 0 ]; then
        echo -e "${DIM}Remaining formulae: $(upd__summarize_items "$formula_after")${RESET}"
    fi
    if [ "$manual_cask_detection_after_status" -ne 0 ] && [ -n "$cask_after" ]; then
        echo -e "${YELLOW}[WARN]${RESET} Manual-install cask detection unavailable after update: $(upd__manual_cask_detection_reason "$manual_cask_detection_after_status")."
    fi
    if [ "$cask_after_count" -gt 0 ]; then
        echo -e "${DIM}Remaining casks: $(upd__summarize_items "$cask_after_effective")${RESET}"
    fi
    if [ -n "$manual_casks_after" ]; then
        echo -e "${YELLOW}[WARN]${RESET} Manual-install casks skipped by Homebrew: $(upd__summarize_items "$manual_casks_after")"
    fi
    echo -e "${YELLOW}[WARN]${RESET} Review pinned/held packages or run commands manually."
    return 1
}
