#!/usr/bin/env bash
# techtrip-secondbrain — set up vault sync.
#   Git only: claude-obsidian's PostToolUse hook auto-commits every write, so
#   git gives history, recovery, and (with a remote) off-machine backup.
#   Real-time multi-machine mirroring (Syncthing) was removed — it added a
#   background network daemon and conflict-copy complexity for marginal gain.
#   Use the git remote to move the vault between machines.
# Idempotent + interactive.
# Usage: bash bin/setup-sync.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

VAULT="$(default_vault_path "${1:-}")"
step "Vault sync (git)"
info "Vault: $VAULT"
[ -d "$VAULT" ] || die "Vault not found at $VAULT — run bin/setup-vault.sh first."

# ── Git ───────────────────────────────────────────────────────────────────────
if [ -d "$VAULT/.git" ]; then
  ok "Git repo already initialized"
else
  if confirm "Initialize a git repo in the vault (recommended — enables auto-commit + backup)?"; then
    run "git init" -- git -C "$VAULT" init -q
    run "initial commit" -- bash -c 'cd "$1" && git add -A && git commit -qm "chore: initial vault scaffold" || true' _ "$VAULT"
    ok "Git initialized"
  fi
fi
if [ -d "$VAULT/.git" ] && ! git -C "$VAULT" remote get-url origin >/dev/null 2>&1; then
  info "No 'origin' remote set. Add one to sync/back up off-machine, e.g.:"
  info "  git -C '$VAULT' remote add origin git@github.com:TechTripAi/<vault-repo>.git"
  info "  git -C '$VAULT' push -u origin main"
fi

# ── Legacy Syncthing cleanup ─────────────────────────────────────────────────
# Earlier releases offered Syncthing; if this machine still carries it, offer
# a teardown so no daemon lingers.
if have_cmd syncthing || [ -f "$VAULT/.stignore" ]; then
  step "Legacy Syncthing detected"
  warn "Syncthing support was removed from techtrip-secondbrain (git is the sync path)."
  if confirm "Remove Syncthing (stop service, uninstall, delete vault .stignore)?"; then
    if have_cmd syncthing; then
      run "Stop Syncthing service" -- brew services stop syncthing || true
      run "Uninstall Syncthing" -- brew uninstall syncthing || true
    fi
    if [ -f "$VAULT/.stignore" ]; then
      run "Remove vault .stignore" -- rm "$VAULT/.stignore"
    fi
    ok "Syncthing removed"
  else
    info "Left in place. Remove later: brew services stop syncthing && brew uninstall syncthing"
  fi
fi

step "Sync setup complete"
