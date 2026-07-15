#!/bin/bash
# Copilot CLI parity port of the claude-obsidian PostToolUse auto-commit hook.
# Auto-commits wiki/, .raw/, and .vault-meta/ after tool use.
# Kill switch: touch .vault-meta/auto-commit.disabled
cat > /dev/null  # consume hook stdin

emit() { printf '{}'; exit 0; }  # Copilot hook output must be valid JSON

[ -d .git ] || emit
[ -f .vault-meta/auto-commit.disabled ] && emit

# Defer while any wiki locks are held (mirrors the Claude hook's guard).
if [ -x scripts/wiki-lock.sh ]; then
  LOCK_LIST=$(bash scripts/wiki-lock.sh list 2>/dev/null)
  LOCK_RC=$?
  if [ "$LOCK_RC" != "0" ]; then
    mkdir -p .vault-meta 2>/dev/null
    printf '%s wiki-lock list failed rc=%s; deferred auto-commit\n' \
      "$(date '+%Y-%m-%dT%H:%M:%SZ')" "$LOCK_RC" >> .vault-meta/hook.log 2>/dev/null
    emit
  fi
  [ -n "$LOCK_LIST" ] && emit
fi

git add -- wiki/ .raw/ .vault-meta/ 2>/dev/null && \
  (git diff --cached --quiet -- wiki/ .raw/ .vault-meta/ || \
   git commit -m "wiki: auto-commit $(date '+%Y-%m-%d %H:%M')" -- wiki/ .raw/ .vault-meta/ 2>/dev/null) || true
emit
