#!/bin/bash
# Cursor parity port of the claude-obsidian Stop hook.
# If wiki pages changed this session and remain uncommitted, ask the agent
# to refresh the hot cache before finishing.
cat > /dev/null  # consume hook stdin

if [ -d wiki ] && [ -d .git ] && git diff --name-only HEAD 2>/dev/null | grep -q '^wiki/'; then
  printf '%s' '{"followup_message": "WIKI_CHANGED: Wiki pages were modified this session. Please update wiki/hot.md with a brief summary of what changed (under 500 words). Use the hot cache format: Last Updated, Key Recent Facts, Recent Changes, Active Threads. Keep it factual. Overwrite the file completely. It is a cache, not a journal."}'
fi
exit 0
