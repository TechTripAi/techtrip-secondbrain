#!/bin/bash
# Copilot CLI parity port of the claude-obsidian SessionStart hook.
# Clears stale wiki locks, then injects wiki/hot.md into the session as
# additionalContext (Copilot hooks, unlike Cursor's, can inject context).
# Also warns (once, in-context) when the vault's stamped parity artifacts
# predate the installed techtrip-secondbrain plugin. Any failure in the
# staleness check degrades to "no warning" — it must never block startup.
cat > /dev/null  # consume hook stdin

[ -x scripts/wiki-lock.sh ] && bash scripts/wiki-lock.sh clear-stale --max-age 3600 >/dev/null 2>&1

PARITY_WARN=""
newest="$(ls -1d "$HOME"/.claude/plugins/cache/*/techtrip-secondbrain/*/ 2>/dev/null | sort -V | tail -1)"
newest="$(basename "${newest%/}" 2>/dev/null)"
if [ -n "$newest" ] && [ -f .vault-meta/harness-parity.json ] && command -v node >/dev/null 2>&1; then
  stamped="$(node -e 'try{process.stdout.write(String(JSON.parse(require("fs").readFileSync(".vault-meta/harness-parity.json","utf8")).stampedBy||""))}catch{}' 2>/dev/null)"
  if [ -n "$stamped" ] && [ "$stamped" != "$newest" ] && \
     [ "$(printf '%s\n%s\n' "$stamped" "$newest" | sort -V | tail -1)" = "$newest" ]; then
    PARITY_WARN="NOTE: this vault's harness parity artifacts were stamped by techtrip-secondbrain $stamped but $newest is installed — tell the owner to re-run /secondbrain (git clones: bash bin/setup-harnesses.sh <vault>) so the hook ports pick up any changes."
  fi
fi

# Output must be single-line JSON; node handles the string escaping.
if command -v node >/dev/null 2>&1; then
  PARITY_WARN="$PARITY_WARN" node -e '
    const fs = require("fs");
    let hot = ""; try { hot = fs.readFileSync("wiki/hot.md", "utf8"); } catch {}
    const parts = [];
    if (process.env.PARITY_WARN) parts.push(process.env.PARITY_WARN);
    if (hot) parts.push("Contents of wiki/hot.md (the vault hot cache — recent state, active threads, next actions):\n\n" + hot);
    process.stdout.write(parts.length ? JSON.stringify({ additionalContext: parts.join("\n\n") }) : "{}");
  ' 2>/dev/null || printf '{}'
else
  printf '{}'
fi
exit 0
