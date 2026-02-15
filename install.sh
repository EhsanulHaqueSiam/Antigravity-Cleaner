#!/usr/bin/env bash
# ─── Antigravity Toolkit — One-liner Installer ───────────────────────────────
# Usage: curl -sL https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.sh | bash

set -e

REPO="EhsanulHaqueSiam/Antigravity-Cleaner"
SCRIPT="scripts/antigravity-cleaner.sh"
URL="https://raw.githubusercontent.com/$REPO/main/$SCRIPT"
DEST="/tmp/antigravity-cleaner.sh"

printf '\033[38;5;81m  Downloading Antigravity Toolkit…\033[0m\n'

if command -v curl >/dev/null 2>&1; then
    curl -sL "$URL" -o "$DEST"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$DEST" "$URL"
else
    printf '\033[38;5;203m  Error: curl or wget required.\033[0m\n'
    exit 1
fi

chmod +x "$DEST"
exec "$DEST" < /dev/tty
