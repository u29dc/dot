#!/usr/bin/env bash
# Shared Homebrew helpers.

dot_trust_brewfile_items() {
    local failed=0
    local item

    for item in \
        ampcode/tap/zvelte-check \
        anomalyco/tap/opencode \
        cirruslabs/cli/softnet \
        cirruslabs/cli/tart \
        lightpanda-io/browser/lightpanda \
        modem-dev/tap/hunk \
        openclaw/tap/gogcli \
        oven-sh/bun/bun \
        steipete/tap/gogcli \
        yfedoseev/tap/pdf-oxide; do
        if ! brew trust --formula "$item" >/dev/null 2>&1; then
            dot_progress_warn "Could not trust Homebrew formula: $item"
            failed=1
        fi
    done

    for item in \
        pluk-inc/tap/markdown-preview \
        rana-gmbh/netfluss/netfluss; do
        if ! brew trust --cask "$item" >/dev/null 2>&1; then
            dot_progress_warn "Could not trust Homebrew cask: $item"
            failed=1
        fi
    done

    return "$failed"
}
