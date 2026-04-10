#!/usr/bin/env bash
# agent-browser helpers

AGENT_BROWSER_DIA_PORT="${AGENT_BROWSER_DIA_PORT:-9222}"
AGENT_BROWSER_DIA_URL="http://127.0.0.1:${AGENT_BROWSER_DIA_PORT}/json/version"
AGENT_BROWSER_DIA_APP="/Applications/Dia.app"
AGENT_BROWSER_DIA_BIN="$AGENT_BROWSER_DIA_APP/Contents/MacOS/Dia"
AGENT_BROWSER_DIA_LAUNCH_AGENT="com.u29dc.dia-cdp"

agent_browser_dia__domain_target() {
    printf 'gui/%s\n' "$(id -u)"
}

agent_browser_dia__service_target() {
    printf '%s/%s\n' "$(agent_browser_dia__domain_target)" "$AGENT_BROWSER_DIA_LAUNCH_AGENT"
}

agent_browser_dia__launch_agent_path() {
    printf '%s/Library/LaunchAgents/%s.plist\n' "$HOME" "$AGENT_BROWSER_DIA_LAUNCH_AGENT"
}

agent_browser_dia__service_loaded() {
    launchctl print "$(agent_browser_dia__service_target)" >/dev/null 2>&1
}

agent_browser_dia__gui_available() {
    launchctl print "$(agent_browser_dia__domain_target)" >/dev/null 2>&1
}

agent_browser_dia__cdp_payload() {
    command curl -fsS "$AGENT_BROWSER_DIA_URL"
}

agent_browser_dia__cdp_healthy() {
    agent_browser_dia__cdp_payload >/dev/null 2>&1
}

agent_browser_dia__wait_for_cdp() {
    local tries="${1:-40}"
    local i

    for ((i = 0; i < tries; i++)); do
        if agent_browser_dia__cdp_healthy; then
            return 0
        fi
        sleep 0.25
    done

    return 1
}

agent_browser_dia__main_commands() {
    ps -axo command= | awk '/\/Applications\/Dia.app\/Contents\/MacOS\/Dia( |$)/ { print }'
}

agent_browser_dia__main_running_without_cdp() {
    local commands
    commands="$(agent_browser_dia__main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1 && return 1
    return 0
}

agent_browser_dia__main_running_with_cdp() {
    local commands
    commands="$(agent_browser_dia__main_commands)"
    [ -n "$commands" ] || return 1

    printf '%s\n' "$commands" | grep -F -- "--remote-debugging-port=${AGENT_BROWSER_DIA_PORT}" >/dev/null 2>&1
}

agent-browser-dia() {
    local cfg
    cfg="$HOME/.agent-browser/config.json"

    if [ ! -f "$cfg" ]; then
        echo "Dia agent-browser config not found: $cfg" >&2
        return 1
    fi

    command agent-browser --config "$cfg" "$@"
}

agent-browser-chrome() {
    local cfg
    cfg="$HOME/.agent-browser/chrome.json"

    if [ ! -f "$cfg" ]; then
        echo "Chrome agent-browser config not found: $cfg" >&2
        return 1
    fi

    command agent-browser --config "$cfg" "$@"
}

agent-browser-dia-on() {
    local domain_target service_target plist_path
    domain_target="$(agent_browser_dia__domain_target)"
    service_target="$(agent_browser_dia__service_target)"
    plist_path="$(agent_browser_dia__launch_agent_path)"

    if [ ! -x "$AGENT_BROWSER_DIA_BIN" ]; then
        echo "Dia.app not found: $AGENT_BROWSER_DIA_APP" >&2
        return 1
    fi

    if [ ! -f "$plist_path" ]; then
        echo "Dia LaunchAgent not found: $plist_path" >&2
        return 1
    fi

    if ! agent_browser_dia__gui_available; then
        echo "GUI launchctl domain unavailable: $domain_target" >&2
        return 1
    fi

    if agent_browser_dia__cdp_healthy; then
        echo "Dia CDP already available on port $AGENT_BROWSER_DIA_PORT."
        return 0
    fi

    if agent_browser_dia__main_running_without_cdp; then
        echo "Dia is already running without CDP. Quit Dia, then run agent-browser-dia-on." >&2
        return 1
    fi

    if agent_browser_dia__main_running_with_cdp; then
        if agent_browser_dia__wait_for_cdp 20; then
            echo "Dia CDP became healthy on port $AGENT_BROWSER_DIA_PORT."
            return 0
        fi

        echo "Dia is already running with a CDP flag, but port $AGENT_BROWSER_DIA_PORT is not healthy." >&2
        return 1
    fi

    if agent_browser_dia__service_loaded; then
        launchctl kickstart -k "$service_target"
    else
        launchctl bootstrap "$domain_target" "$plist_path"
    fi

    if agent_browser_dia__wait_for_cdp; then
        echo "Dia CDP ready on port $AGENT_BROWSER_DIA_PORT."
        return 0
    fi

    echo "Dia LaunchAgent started, but CDP did not become healthy on port $AGENT_BROWSER_DIA_PORT." >&2
    return 1
}

agent-browser-dia-off() {
    local service_target
    service_target="$(agent_browser_dia__service_target)"

    if ! agent_browser_dia__gui_available; then
        echo "GUI launchctl domain unavailable: $(agent_browser_dia__domain_target)" >&2
        return 1
    fi

    if ! agent_browser_dia__service_loaded; then
        echo "Dia LaunchAgent is not loaded."
        return 0
    fi

    launchctl bootout "$service_target"
    echo "Dia LaunchAgent unloaded."
}

agent-browser-dia-status() {
    local payload
    local commands
    local service_state="unloaded"
    local process_state="stopped"

    if agent_browser_dia__service_loaded; then
        service_state="loaded"
    fi

    commands="$(agent_browser_dia__main_commands)"
    if [ -n "$commands" ]; then
        process_state="running"
        if agent_browser_dia__main_running_with_cdp; then
            process_state="${process_state} (cdp)"
        else
            process_state="${process_state} (no cdp)"
        fi
    fi

    printf 'Service: %s (%s)\n' "$service_state" "$AGENT_BROWSER_DIA_LAUNCH_AGENT"
    printf 'Process: %s\n' "$process_state"
    printf 'Endpoint: %s\n' "$AGENT_BROWSER_DIA_URL"

    if ! payload="$(agent_browser_dia__cdp_payload 2>/dev/null)"; then
        printf 'CDP: unavailable\n'
        return 1
    fi

    printf 'CDP: healthy\n'
    if command -v jq >/dev/null 2>&1; then
        printf 'Browser: %s\n' "$(printf '%s' "$payload" | jq -r '.Browser')"
        printf 'WebSocket: %s\n' "$(printf '%s' "$payload" | jq -r '.webSocketDebuggerUrl')"
    else
        printf '%s\n' "$payload"
    fi
}
