#!/bin/bash
# Cursor parity port of the claude-obsidian PostToolUse auto-commit hook.
# Auto-commits wiki/, .raw/, and .vault-meta/ after file edits.
# Kill switch: touch .vault-meta/auto-commit.disabled
cat > /dev/null  # consume hook stdin

[ -d .git ] || exit 0
[ -f .vault-meta/auto-commit.disabled ] && exit 0

# Defer while any wiki locks are held (mirrors the Claude hook's guard).
if [ -x scripts/wiki-lock.sh ]; then
  LOCK_LIST=$(bash scripts/wiki-lock.sh list 2>/dev/null)
  LOCK_RC=$?
  if [ "$LOCK_RC" != "0" ]; then
    mkdir -p .vault-meta 2>/dev/null
    printf '%s wiki-lock list failed rc=%s; deferred auto-commit\n' \
      "$(date '+%Y-%m-%dT%H:%M:%SZ')" "$LOCK_RC" >> .vault-meta/hook.log 2>/dev/null
    exit 0
  fi
  [ -n "$LOCK_LIST" ] && exit 0
fi

git add -- wiki/ .raw/ .vault-meta/ 2>/dev/null && \
  (git diff --cached --quiet -- wiki/ .raw/ .vault-meta/ || \
   git commit -m "wiki: auto-commit $(date '+%Y-%m-%d %H:%M')" -- wiki/ .raw/ .vault-meta/ 2>/dev/null) || true
exit 0
