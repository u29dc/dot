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

    is_spinner_supported() {
        [ -t 1 ] || return 1
        [ "${TERM:-}" != "dumb" ] || return 1
        return 0
    }

    locale_is_utf8() {
        local locale_value="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
        case "$locale_value" in
            *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) return 0 ;;
            *) return 1 ;;
        esac
    }

    spinner_frame() {
        local frame_index="$1"
        if locale_is_utf8; then
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

    terminal_columns() {
        local cols='80'
        if command -v tput >/dev/null 2>&1; then
            cols="$(tput cols 2>/dev/null || printf '80')"
        fi
        case "$cols" in
            '' | *[!0-9]*) cols='80' ;;
        esac
        printf '%s' "$cols"
    }

    truncate_text() {
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

    render_spinner_line() {
        local label="$1"
        local frame="$2"
        local elapsed="$3"
        local cols
        local reserved_width=20
        local max_label_width
        local display_label

        cols="$(terminal_columns)"
        max_label_width=$((cols - reserved_width))
        if [ "$max_label_width" -lt 10 ]; then
            max_label_width=10
        fi

        display_label="$(truncate_text "$label" "$max_label_width")"
        printf '\r\033[2K%b[%s]%b %s (%s)' "$BLUE" "$frame" "$RESET" "$display_label" "$elapsed"
    }

    clear_spinner_line() {
        printf '\r\033[2K'
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

    is_manual_installer_only_failure() {
        local output="$1"
        [ -n "$output" ] || return 1

        printf '%s\n' "$output" | awk '
            /^Error:/ {
                has_error = 1
                if ($0 !~ /^Error: Not upgrading [0-9]+ `installer manual` casks?\.$/) {
                    bad_error = 1
                }
            }
            END {
                if (has_error && !bad_error) {
                    exit 0
                }
                exit 1
            }
        '
    }

    extract_manual_installer_casks() {
        local output="$1"
        [ -n "$output" ] || return 0

        printf '%s\n' "$output" | awk '
            /^Error: Not upgrading [0-9]+ `installer manual` casks?\.$/ {
                collect = 1
                next
            }
            collect {
                if ($0 ~ /^==>/ || $0 ~ /^Error:/ || $0 ~ /^[[:space:]]*$/) {
                    collect = 0
                    next
                }
                if ($0 ~ /^[a-z0-9@._+-]+$/) {
                    print $0
                }
            }
        '
    }

    filter_ignored_items() {
        local items="$1"
        local ignored="$2"
        if [ -z "$ignored" ]; then
            printf '%s' "$items"
            return 0
        fi

        awk '
            NR == FNR {
                if (NF) {
                    ignored[$0] = 1
                }
                next
            }
            NF && !($0 in ignored) {
                print $0
            }
        ' <(printf '%s\n' "$ignored") <(printf '%s\n' "$items")
    }

    run_step() {
        local stream_mode=0
        local allow_manual_cask=0
        while [ $# -gt 0 ]; do
            case "${1:-}" in
                --stream)
                    stream_mode=1
                    shift
                    ;;
                --allow-manual-cask)
                    allow_manual_cask=1
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
        local switched_to_stream=0
        local previous_int_trap=""
        local previous_term_trap=""
        local process_state=""
        local downgraded_manual_cask=0
        local manual_casks=""

        if [ "$stream_mode" -eq 1 ]; then
            output_file="$(mktemp "${TMPDIR:-/tmp}/upd-step-stream.XXXXXX" 2>/dev/null)"
            printf '%b[RUN ]%b %s...\n' "$BLUE" "$RESET" "$label"
            if [ -n "$output_file" ]; then
                "$@" > >(tee "$output_file") 2>&1 || step_status=$?
                output_text="$(cat "$output_file" 2>/dev/null)"
            else
                "$@" || step_status=$?
            fi

            if [ "$allow_manual_cask" -eq 1 ] && [ "$step_status" -ne 0 ] && is_manual_installer_only_failure "$output_text"; then
                downgraded_manual_cask=1
                manual_casks="$(extract_manual_installer_casks "$output_text")"
                if [ -n "$manual_casks" ]; then
                    manual_casks_ignored="$(
                        printf '%s\n%s\n' "$manual_casks_ignored" "$manual_casks" |
                            awk 'NF && !seen[$0]++'
                    )"
                fi
                step_status=0
            fi

            elapsed=$((SECONDS - step_start))
            if [ "$step_status" -eq 0 ]; then
                printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(format_time "$elapsed")"
                if [ "$downgraded_manual_cask" -eq 1 ]; then
                    echo -e "${YELLOW}[WARN]${RESET} Installer-manual casks were skipped by Homebrew; continuing."
                fi
            else
                printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(format_time "$elapsed")"
            fi
            rm -f "$output_file"
            return "$step_status"
        fi

        output_file="$(mktemp "${TMPDIR:-/tmp}/upd-step.XXXXXX" 2>/dev/null)"
        if [ -z "$output_file" ]; then
            printf '%b[RUN ]%b %s...\n' "$BLUE" "$RESET" "$label"
            local output=""
            output="$("$@" 2>&1)" || step_status=$?

            local elapsed_fallback=$((SECONDS - step_start))
            if [ "$step_status" -eq 0 ]; then
                printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(format_time "$elapsed_fallback")"
            else
                printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(format_time "$elapsed_fallback")"
                if [ -n "$output" ]; then
                    printf '%b%s%b\n' "$DIM" "$output" "$RESET"
                fi
            fi
            return "$step_status"
        fi

        if is_spinner_supported; then
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
            trap 'interrupted_signal=1; [ -n "$command_pid" ] && kill "$command_pid" 2>/dev/null; clear_spinner_line' INT TERM

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
                            switched_to_stream=1
                            kill "$command_pid" 2>/dev/null
                            clear_spinner_line
                            printf '%b[WARN]%b %s paused for terminal input; rerunning this command in foreground.\n' "$YELLOW" "$RESET" "$label"
                            run_step --stream "$label" "$@"
                            step_status=$?
                            break
                            ;;
                    esac
                fi

                frame="$(spinner_frame "$frame_index")"
                elapsed="$(format_time "$((SECONDS - step_start))")"
                render_spinner_line "$label" "$frame" "$elapsed"
                frame_index=$((frame_index + 1))
                sleep 0.1
            done

            if [ "$interrupted_signal" -eq 0 ] && [ "$switched_to_stream" -eq 0 ]; then
                wait "$command_pid" || step_status=$?
            else
                wait "$command_pid" 2>/dev/null || true
            fi
            clear_spinner_line

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
            printf '%b[OK  ]%b %s (%s)\n' "$BLUE" "$RESET" "$label" "$(format_time "$elapsed")"
        else
            printf '%b[FAIL]%b %s (%s)\n' "$RED" "$RESET" "$label" "$(format_time "$elapsed")"
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

    apply_step_result() {
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

    ensure_sudo_session() {
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
    local manual_casks_ignored=""

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

    ensure_sudo_session "$cask_before_count" "prompt" || return 1

    local step_result=0

    run_step "Refreshing Homebrew metadata" brew update
    step_result=$?
    apply_step_result "$step_result" || return $?

    if [ "$formula_before_count" -gt 0 ]; then
        run_step "Upgrading formulae" brew upgrade
        step_result=$?
        apply_step_result "$step_result" || return $?
    else
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading formulae (none outdated)."
    fi

    if [ "$cask_before_count" -gt 0 ]; then
        # Refresh ticket right before cask upgrades to reduce chance of mid-step prompts.
        ensure_sudo_session 1 "refresh" || return 1
        run_step --stream --allow-manual-cask "Upgrading casks (greedy)" brew upgrade --cask --greedy
        step_result=$?
        apply_step_result "$step_result" || return $?
    else
        echo -e "${YELLOW}[SKIP]${RESET} Upgrading casks (none outdated)."
    fi

    run_step "Removing stale dependencies" brew autoremove
    step_result=$?
    apply_step_result "$step_result" || return $?

    run_step "Cleaning old versions and cache" brew cleanup -s --prune=all
    step_result=$?
    apply_step_result "$step_result" || return $?

    local formula_after
    local cask_after
    local cask_after_effective
    formula_after="$(brew outdated --formula 2>/dev/null || true)"
    cask_after="$(brew outdated --cask --greedy 2>/dev/null || true)"
    cask_after_effective="$(filter_ignored_items "$cask_after" "$manual_casks_ignored")"

    local formula_after_count
    local cask_after_count
    local total_after
    formula_after_count="$(count_items "$formula_after")"
    cask_after_count="$(count_items "$cask_after_effective")"
    total_after=$((formula_after_count + cask_after_count))

    local overall_elapsed=$((SECONDS - overall_start))

    if [ "$failed" -ne 0 ]; then
        echo -e "${RED}[FAIL]${RESET} Homebrew update finished with errors in $(format_time "$overall_elapsed")."
        return 1
    fi

    if [ "$total_after" -eq 0 ]; then
        if [ -n "$manual_casks_ignored" ]; then
            echo -e "${YELLOW}[WARN]${RESET} Manual-install casks skipped by Homebrew: $(summarize_items "$manual_casks_ignored")"
        fi
        echo -e "${BLUE}Homebrew update complete in $(format_time "$overall_elapsed").${RESET}"
        return 0
    fi

    echo -e "${YELLOW}[WARN]${RESET} ${total_after} package(s) remain outdated after update."
    if [ "$formula_after_count" -gt 0 ]; then
        echo -e "${DIM}Remaining formulae: $(summarize_items "$formula_after")${RESET}"
    fi
    if [ "$cask_after_count" -gt 0 ]; then
        echo -e "${DIM}Remaining casks: $(summarize_items "$cask_after_effective")${RESET}"
    fi
    if [ -n "$manual_casks_ignored" ]; then
        echo -e "${YELLOW}[WARN]${RESET} Manual-install casks skipped by Homebrew: $(summarize_items "$manual_casks_ignored")"
    fi
    echo -e "${YELLOW}[WARN]${RESET} Review pinned/held packages or run commands manually."
    return 1
}
