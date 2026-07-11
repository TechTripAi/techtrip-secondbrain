#!/bin/bash
# Cursor parity port of the claude-obsidian SessionStart hook.
# Clears stale wiki locks; the hot-cache read is handled by the
# wiki-vault rule since Cursor hooks don't inject context at start.
cat > /dev/null  # consume hook stdin

[ -x scripts/wiki-lock.sh ] && bash scripts/wiki-lock.sh clear-stale --max-age 3600 >/dev/null 2>&1
exit 0
