#!/bin/bash
# Copilot CLI parity port of the claude-obsidian Stop hook.
# If wiki pages (other than hot.md itself) changed and remain uncommitted,
# block the stop once and ask the agent to refresh the hot cache.
#
# Copilot's agentStop has no loop_limit (unlike Cursor), and a "block"
# decision re-prompts the agent — so a per-session sentinel in $TMPDIR caps
# the reminder at one per session, or the disabled-auto-commit case would
# block forever.
INPUT=$(cat)

allow() { printf '{"decision":"allow","reason":""}'; exit 0; }

{ [ -d wiki ] && [ -d .git ]; } || allow
git diff --name-only HEAD 2>/dev/null | grep '^wiki/' | grep -qv '^wiki/hot\.md$' || allow

SESSION_ID=""
if command -v node >/dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$INPUT" | node -e '
    let d = ""; process.stdin.on("data", c => d += c).on("end", () => {
      try { process.stdout.write(String(JSON.parse(d).sessionId || "")); } catch {}
    });
  ' 2>/dev/null | tr -cd 'A-Za-z0-9._-')
fi
if [ -n "$SESSION_ID" ]; then
  SENTINEL="${TMPDIR:-/tmp}/tsb-stop-reminder-${SESSION_ID}"
  [ -e "$SENTINEL" ] && allow
  : > "$SENTINEL" 2>/dev/null
fi

printf '%s' '{"decision":"block","reason":"WIKI_CHANGED: Wiki pages were modified this session. Please update wiki/hot.md with a brief summary of what changed (under 500 words). Use the hot cache format: Last Updated, Key Recent Facts, Recent Changes, Active Threads. Keep it factual. Overwrite the file completely. It is a cache, not a journal."}'
exit 0
