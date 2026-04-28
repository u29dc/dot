#!/usr/bin/env bash
# Shared progress/status UI for repo-managed shell scripts.

if [ -z "${DOT_PROGRESS_RED+x}" ]; then
    DOT_PROGRESS_RED='\x1b[31m'
fi
if [ -z "${DOT_PROGRESS_BLUE+x}" ]; then
    DOT_PROGRESS_BLUE='\x1b[34m'
fi
if [ -z "${DOT_PROGRESS_YELLOW+x}" ]; then
    DOT_PROGRESS_YELLOW='\x1b[33m'
fi
if [ -z "${DOT_PROGRESS_DIM+x}" ]; then
    DOT_PROGRESS_DIM='\x1b[2m'
fi
if [ -z "${DOT_PROGRESS_RESET+x}" ]; then
    DOT_PROGRESS_RESET='\x1b[0m'
fi

dot_progress_format_time() {
    local total_seconds="$1"
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))

    if [ "$minutes" -gt 0 ]; then
        printf '%sm %ss' "$minutes" "$seconds"
    else
        printf '%ss' "$seconds"
    fi
}

dot_progress_status() {
    local label="$1"
    local color="$2"
    shift 2

    printf '%b[%-4s]%b %s\n' "$color" "$label" "$DOT_PROGRESS_RESET" "$*"
}

dot_progress_info() {
    dot_progress_status "INFO" "$DOT_PROGRESS_BLUE" "$@"
}

dot_progress_ok() {
    dot_progress_status "OK" "$DOT_PROGRESS_BLUE" "$@"
}

dot_progress_run() {
    dot_progress_status "RUN" "$DOT_PROGRESS_BLUE" "$@"
}

dot_progress_skip() {
    dot_progress_status "SKIP" "$DOT_PROGRESS_YELLOW" "$@"
}

dot_progress_warn() {
    dot_progress_status "WARN" "$DOT_PROGRESS_YELLOW" "$@"
}

dot_progress_fail() {
    dot_progress_status "FAIL" "$DOT_PROGRESS_RED" "$@"
}

dot_progress_title() {
    local label="$1"

    printf '%b%s%b\n' "$DOT_PROGRESS_BLUE" "$label" "$DOT_PROGRESS_RESET"
}

dot_progress_section() {
    printf '\n'
    dot_progress_title "$1"
}

dot_progress_is_spinner_supported() {
    [ -t 1 ] || return 1
    [ "${TERM:-}" != "dumb" ] || return 1
    return 0
}

dot_progress_locale_is_utf8() {
    local locale_value="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
    case "$locale_value" in
        *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) return 0 ;;
        *) return 1 ;;
    esac
}

dot_progress_spinner_glyph() {
    local frame_index="$1"
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
}

dot_progress_spinner_frame() {
    local frame_index="$1"
    local status_text=""
    local offset=""

    if dot_progress_locale_is_utf8; then
        for offset in 0 3 6 9; do
            status_text="${status_text}$(dot_progress_spinner_glyph "$((frame_index + offset))")"
        done
        printf '%s' "$status_text"
    else
        # shellcheck disable=SC1003
        case $((frame_index % 4)) in
            0) printf '|/-\\' ;;
            1) printf '/-\\|' ;;
            2) printf '-\\|/' ;;
            *) printf '\\|/-' ;;
        esac
    fi
}

dot_progress_terminal_columns() {
    local cols='80'
    if command -v tput >/dev/null 2>&1; then
        cols="$(tput cols 2>/dev/null || printf '80')"
    fi
    case "$cols" in
        '' | *[!0-9]*) cols='80' ;;
    esac
    printf '%s' "$cols"
}

dot_progress_truncate_text() {
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

dot_progress_render_spinner_line() {
    local label="$1"
    local frame="$2"
    local elapsed="$3"
    local cols
    local reserved_width=20
    local max_label_width
    local display_label

    cols="$(dot_progress_terminal_columns)"
    max_label_width=$((cols - reserved_width))
    if [ "$max_label_width" -lt 10 ]; then
        max_label_width=10
    fi

    display_label="$(dot_progress_truncate_text "$label" "$max_label_width")"
    printf '\r\033[2K%b[%-4s]%b %s (%s)' "$DOT_PROGRESS_BLUE" "$frame" "$DOT_PROGRESS_RESET" "$display_label" "$elapsed"
}

dot_progress_clear_spinner_line() {
    printf '\r\033[2K'
}

dot_progress_run_step() {
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
        dot_progress_run "$label..."
        "$@" || step_status=$?
        elapsed=$((SECONDS - step_start))
        if [ "$step_status" -eq 0 ]; then
            dot_progress_ok "$label ($(dot_progress_format_time "$elapsed"))"
        else
            dot_progress_fail "$label ($(dot_progress_format_time "$elapsed"))"
        fi
        return "$step_status"
    fi

    output_file="$(mktemp "${TMPDIR:-/tmp}/dot-progress-step.XXXXXX" 2>/dev/null)"
    if [ -z "$output_file" ]; then
        dot_progress_run "$label..."
        local output=""
        output="$("$@" 2>&1)" || step_status=$?

        local elapsed_fallback=$((SECONDS - step_start))
        if [ "$step_status" -eq 0 ]; then
            dot_progress_ok "$label ($(dot_progress_format_time "$elapsed_fallback"))"
        else
            dot_progress_fail "$label ($(dot_progress_format_time "$elapsed_fallback"))"
            if [ -n "$output" ]; then
                printf '%b%s%b\n' "$DOT_PROGRESS_DIM" "$output" "$DOT_PROGRESS_RESET"
            fi
        fi
        return "$step_status"
    fi

    if dot_progress_is_spinner_supported; then
        # Prevent interactive job-control messages from corrupting spinner output.
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
        trap 'interrupted_signal=1; [ -n "$command_pid" ] && kill "$command_pid" 2>/dev/null; dot_progress_clear_spinner_line' INT TERM

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
                        dot_progress_clear_spinner_line
                        dot_progress_warn "$label paused waiting for terminal input. Not rerunning automatically to avoid duplicate changes."
                        break
                        ;;
                esac
            fi

            frame="$(dot_progress_spinner_frame "$frame_index")"
            elapsed="$(dot_progress_format_time "$((SECONDS - step_start))")"
            dot_progress_render_spinner_line "$label" "$frame" "$elapsed"
            frame_index=$((frame_index + 1))
            sleep 0.1
        done

        if [ "$interrupted_signal" -eq 0 ] && [ "$paused_for_tty" -eq 0 ]; then
            wait "$command_pid" || step_status=$?
        else
            wait "$command_pid" 2>/dev/null || true
        fi
        dot_progress_clear_spinner_line

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
        dot_progress_run "$label..."
        "$@" >"$output_file" 2>&1 || step_status=$?
    fi

    elapsed=$((SECONDS - step_start))
    if [ "$step_status" -eq 0 ]; then
        dot_progress_ok "$label ($(dot_progress_format_time "$elapsed"))"
    else
        dot_progress_fail "$label ($(dot_progress_format_time "$elapsed"))"
        if [ -s "$output_file" ]; then
            output_text="$(cat "$output_file")"
            printf '%b%s%b\n' "$DOT_PROGRESS_DIM" "$output_text" "$DOT_PROGRESS_RESET"
        else
            printf '%b(no output)%b\n' "$DOT_PROGRESS_DIM" "$DOT_PROGRESS_RESET"
        fi
    fi

    rm -f "$output_file"
    return "$step_status"
}
