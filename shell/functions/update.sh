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

    upd__format_time() {
        local total_seconds="$1"
        local minutes=$((total_seconds / 60))
        local seconds=$((total_seconds % 60))

        if [ "$minutes" -gt 0 ]; then
            printf '%sm %ss' "$minutes" "$seconds"
        else
            printf '%ss' "$seconds"
        fi
    }

    upd__is_spinner_supported() {
        [ -t 1 ] || return 1
        [ "${TERM:-}" != "dumb" ] || return 1
        return 0
    }

    upd__locale_is_utf8() {
        local locale_value="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
        case "$locale_value" in
            *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) return 0 ;;
            *) return 1 ;;
        esac
    }

    upd__spinner_frame() {
        local frame_index="$1"
        if upd__locale_is_utf8; then
            case $((frame_index % 10)) in
                0) printf '⠋' ;;
                1) printf '⠙' ;;
                2) printf '⠹' ;;
                3) printf '⠸' ;;
                4) printf '⠼' ;;
                5) printf '⠴' ;;
                6) printf '⠦' ;;
                7) printf '⠧' ;;
                8) printf '⠇' ;;
                *) printf '⠏' ;;
            esac
        else
            # shellcheck disable=SC1003
            case $((frame_index % 4)) in
                0) printf '|' ;;
                1) printf '/' ;;
                2) printf '-' ;;
                *) printf '\\' ;;
            esac
        fi
    }

    upd__terminal_columns() {
        local cols='80'
        if command -v tput >/dev/null 2>&1; then
            cols="$(tput cols 2>/dev/null || printf '80')"
        fi
        case "$cols" in
            '' | *[!0-9]*) cols='80' ;;
        esac
        printf '%s' "$cols"
    }

    upd__truncate_text() {
        local text="$1"
        local max_length="$2"
        if [ "$max_length" -le 0 ]; then
            printf ''
            return 0
        fi

        if [ "${#text}" -le "$max_length" ]; then
            printf '%s' "$text"
            return 0
        fi

        if [ "$max_length" -le 3 ]; then
            printf '%s' "${text:0:${max_length}}"
            return 0
        fi

        printf '%s...' "${text:0:$((max_length - 3))}"
    }

    upd__render_spinner_line() {
        local label="$1"
        local frame="$2"
        local elapsed="$3"
        local cols
        local reserved_width=20
        local max_label_width
        local display_label

        cols="$(upd__terminal_columns)"
        max_label_width=$((cols - reserved_width))
        if [ "$max_label_width" -lt 10 ]; then
            max_label_width=10
        fi

        display_label="$(upd__truncate_text "$label" "$max_label_width")"
        printf '\r\033[2K%b[%s]%b %s (%s)' "$BLUE" "$frame" "$RESET" "$display_label" "$elapsed"
    }

    upd__clear_spinner_line() {
        printf '\r\033[2K'
    }

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
        local stream_mode=0
        while [ $# -gt 0 ]; do
            case "${1:-}" in
                --stream)
                    stream_mode=1
                    shift
                    ;;
                *)
                    break
                    ;;
            esac
        done

        local label="$1"
        shift

        local step_start=$SECONDS
        local output_file=""
        local step_status=0
        local command_pid=""
        local frame_index=0
        local frame=""
        local elapsed=""
        local output_text=""
        local bash_monitor_was_on=0
        local interrupted_signal=0
        local previous_int_trap=""
        local previous_term_trap=""
        local process_state=""
        local paused_for_tty=0

        if [ "$stream_mode" -eq 1 ]; then
            printf '%b[RUN ]%b %s...\n' "$BLUE" "$RESET" "$label"
            "$@" || step_status=$?
            elapsed=$((SECONDS - step_start))
            if [ "$step_status" -eq 0 ]; then
                printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(upd__format_time "$elapsed")"
            else
                printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(upd__format_time "$elapsed")"
            fi
            return "$step_status"
        fi

        output_file="$(mktemp "${TMPDIR:-/tmp}/upd-step.XXXXXX" 2>/dev/null)"
        if [ -z "$output_file" ]; then
            printf '%b[RUN ]%b %s...\n' "$BLUE" "$RESET" "$label"
            local output=""
            output="$("$@" 2>&1)" || step_status=$?

            local elapsed_fallback=$((SECONDS - step_start))
            if [ "$step_status" -eq 0 ]; then
                printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(upd__format_time "$elapsed_fallback")"
            else
                printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(upd__format_time "$elapsed_fallback")"
                if [ -n "$output" ]; then
                    printf '%b%s%b\n' "$DIM" "$output" "$RESET"
                fi
            fi
            return "$step_status"
        fi

        if upd__is_spinner_supported; then
            # Prevent interactive job-control messages ([n] pid / done) from corrupting spinner output.
            if [ -n "${ZSH_VERSION:-}" ]; then
                setopt localoptions nomonitor nonotify
            elif [ -n "${BASH_VERSION:-}" ]; then
                case "$-" in
                    *m*)
                        bash_monitor_was_on=1
                        set +m
                        ;;
                esac
            fi

            previous_int_trap="$(trap -p INT || true)"
            previous_term_trap="$(trap -p TERM || true)"
            trap 'interrupted_signal=1; [ -n "$command_pid" ] && kill "$command_pid" 2>/dev/null; upd__clear_spinner_line' INT TERM

            "$@" >"$output_file" 2>&1 &
            command_pid=$!

            while kill -0 "$command_pid" 2>/dev/null; do
                if [ "$interrupted_signal" -ne 0 ]; then
                    break
                fi

                if [ $((frame_index % 10)) -eq 0 ]; then
                    process_state="$(ps -o stat= -p "$command_pid" 2>/dev/null | awk '{print $1}')"
                    case "$process_state" in
                        T*)
                            paused_for_tty=1
                            kill "$command_pid" 2>/dev/null || true
                            upd__clear_spinner_line
                            printf '%b[WARN]%b %s paused waiting for terminal input. Not rerunning automatically to avoid duplicate changes.\n' "$YELLOW" "$RESET" "$label"
                            break
                            ;;
                    esac
                fi

                frame="$(upd__spinner_frame "$frame_index")"
                elapsed="$(upd__format_time "$((SECONDS - step_start))")"
                upd__render_spinner_line "$label" "$frame" "$elapsed"
                frame_index=$((frame_index + 1))
                sleep 0.1
            done

            if [ "$interrupted_signal" -eq 0 ] && [ "$paused_for_tty" -eq 0 ]; then
                wait "$command_pid" || step_status=$?
            else
                wait "$command_pid" 2>/dev/null || true
            fi
            upd__clear_spinner_line

            if [ "$paused_for_tty" -ne 0 ] && [ "$step_status" -eq 0 ]; then
                step_status=125
            fi
            if [ "$interrupted_signal" -ne 0 ] && [ "$step_status" -eq 0 ]; then
                step_status=130
            fi

            if [ "$bash_monitor_was_on" -eq 1 ]; then
                set -m
            fi

            if [ -n "$previous_int_trap" ]; then
                eval "$previous_int_trap"
            else
                trap - INT
            fi
            if [ -n "$previous_term_trap" ]; then
                eval "$previous_term_trap"
            else
                trap - TERM
            fi
        else
            printf '%b[RUN ]%b %s...\n' "$BLUE" "$RESET" "$label"
            "$@" >"$output_file" 2>&1 || step_status=$?
        fi

        elapsed=$((SECONDS - step_start))
        if [ "$step_status" -eq 0 ]; then
            printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(upd__format_time "$elapsed")"
        else
            printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(upd__format_time "$elapsed")"
            if [ -s "$output_file" ]; then
                output_text="$(cat "$output_file")"
                printf '%b%s%b\n' "$DIM" "$output_text" "$RESET"
            else
                printf '%b(no output)%b\n' "$DIM" "$RESET"
            fi
        fi

        rm -f "$output_file"
        return "$step_status"
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
        echo -e "${RED}[FAIL]${RESET} Homebrew update finished with errors in $(upd__format_time "$overall_elapsed")."
        return 1
    fi

    if [ "$total_after" -eq 0 ]; then
        if [ -n "$manual_casks_after" ]; then
            echo -e "${YELLOW}[WARN]${RESET} Manual-install casks skipped by Homebrew: $(upd__summarize_items "$manual_casks_after")"
        fi
        echo -e "${BLUE}Homebrew update complete in $(upd__format_time "$overall_elapsed").${RESET}"
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
