#!/usr/bin/env bash
set -euo pipefail

BUFFER_PATH="${1:-stdin.md}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPACTOR="$SCRIPT_DIR/markdown.py"
LOCAL_PRETTIER="$SCRIPT_DIR/../node_modules/.bin/prettier"
PRETTIER_VERSION="3.9.5"

export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if [ -x "$LOCAL_PRETTIER" ]; then
    "$LOCAL_PRETTIER" --stdin-filepath "$BUFFER_PATH" | "$COMPACTOR"
    exit 0
fi

if command -v prettier >/dev/null 2>&1; then
    prettier --stdin-filepath "$BUFFER_PATH" | "$COMPACTOR"
    exit 0
fi

if command -v bunx >/dev/null 2>&1; then
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    (
        cd "$tmp_dir"
        bunx --bun "prettier@$PRETTIER_VERSION" --stdin-filepath "$BUFFER_PATH"
    ) | "$COMPACTOR"
    exit 0
fi

"$COMPACTOR"
