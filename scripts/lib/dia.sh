#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

dia_cdp_url() {
    printf 'http://127.0.0.1:%s/json/version\n' "$AGENT_BROWSER_DIA_PORT"
}

dia_launch_agent_domain() {
    printf 'gui/%s\n' "$UID"
}

dia_launch_agent_service() {
    printf '%s/%s\n' "$(dia_launch_agent_domain)" "$AGENT_BROWSER_DIA_LAUNCH_AGENT"
}

dia_cdp_healthy() {
    curl -fsS "$(dia_cdp_url)" >/dev/null 2>&1
}

wait_for_dia_cdp() {
    local tries="${1:-40}"
    local i

    for ((i = 0; i < tries; i++)); do
        if dia_cdp_healthy; then
            return 0
        fi
        sleep 0.25
    done

    return 1
}

dia_main_pids() {
    pgrep -x Dia 2>/dev/null || true
}

dia_main_commands() {
    local pid
    local process_command

    while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        process_command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        case "$process_command" in
            "$AGENT_BROWSER_DIA_BIN" | "$AGENT_BROWSER_DIA_BIN "*)
                printf '%s\n' "$process_command"
                ;;
        esac
    done < <(dia_main_pids)
}

dia_running_without_cdp() {
    local commands
    commands="$(dia_main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1 && return 1
    return 0
}

dia_running_with_cdp() {
    local commands
    commands="$(dia_main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1
}

dia_gui_domain_available() {
    launchctl print "$(dia_launch_agent_domain)" >/dev/null 2>&1
}

dia_launch_agent_loaded() {
    launchctl print "$(dia_launch_agent_service)" >/dev/null 2>&1
}

setup_dia_cdp() {
    local plist_path
    local domain_target
    local service_target

    plist_path="$HOME/Library/LaunchAgents/${AGENT_BROWSER_DIA_LAUNCH_AGENT}.plist"
    domain_target="$(dia_launch_agent_domain)"
    service_target="$(dia_launch_agent_service)"

    if dot_dry_run; then
        dot_progress_skip "Dia CDP startup (--dry-run)"
        return 0
    fi

    if [ ! -f "$plist_path" ]; then
        dot_progress_skip "Dia LaunchAgent not rendered: $plist_path"
        return 0
    fi

    if [ ! -x "$AGENT_BROWSER_DIA_BIN" ]; then
        dot_progress_skip "Dia.app not found: $AGENT_BROWSER_DIA_APP"
        return 0
    fi

    if ! command -v launchctl >/dev/null 2>&1; then
        dot_progress_skip "launchctl not available"
        return 0
    fi

    if ! dia_gui_domain_available; then
        dot_progress_skip "GUI launchctl domain unavailable: $domain_target"
        return 0
    fi

    if dia_cdp_healthy; then
        dot_progress_ok "Dia CDP already available on port $AGENT_BROWSER_DIA_PORT"
        return 0
    fi

    if dia_running_without_cdp; then
        dot_progress_skip "Dia is already running without CDP. Quit Dia, then run agent-browser-dia-on or rerun setup."
        return 0
    fi

    if dia_running_with_cdp; then
        if wait_for_dia_cdp 20; then
            dot_progress_ok "Dia CDP became healthy on port $AGENT_BROWSER_DIA_PORT"
        else
            dot_progress_skip "Dia is already running with a CDP flag, but port $AGENT_BROWSER_DIA_PORT is not healthy yet."
        fi
        return 0
    fi

    dot_progress_run "Starting Dia CDP LaunchAgent"
    if dia_launch_agent_loaded; then
        launchctl kickstart -k "$service_target"
    else
        launchctl bootstrap "$domain_target" "$plist_path"
    fi

    if wait_for_dia_cdp; then
        dot_progress_ok "Dia CDP ready on port $AGENT_BROWSER_DIA_PORT"
    else
        dot_progress_warn "Dia LaunchAgent loaded, but CDP did not become healthy on port $AGENT_BROWSER_DIA_PORT"
    fi
}
