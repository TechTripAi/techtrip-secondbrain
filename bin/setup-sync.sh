#!/usr/bin/env bash
# techtrip-secondbrain — set up vault sync.
#   Default: git (already auto-committed by claude-obsidian's PostToolUse hook) —
#            just init the repo and optionally add a remote.
#   Optional: Syncthing for real-time LAN sync, with a .stignore that keeps it from
#            fighting git (.git, workspace.json, .trash, .DS_Store excluded).
# Idempotent + interactive.
# Usage: bash bin/setup-sync.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

VAULT="$(default_vault_path "${1:-}")"
step "Vault sync"
info "Vault: $VAULT"
[ -d "$VAULT" ] || die "Vault not found at $VAULT — run bin/setup-vault.sh first."

# ── Git (default) ────────────────────────────────────────────────────────────
step "Git"
if [ -d "$VAULT/.git" ]; then
  ok "Git repo already initialized"
else
  if confirm "Initialize a git repo in the vault (recommended — enables auto-commit + backup)?"; then
    run "git init" -- git -C "$VAULT" init -q
    run "initial commit" -- bash -c "cd '$VAULT' && git add -A && git commit -qm 'chore: initial vault scaffold' || true"
    ok "Git initialized"
  fi
fi
if [ -d "$VAULT/.git" ] && ! git -C "$VAULT" remote get-url origin >/dev/null 2>&1; then
  info "No 'origin' remote set. Add one to sync/back up off-machine, e.g.:"
  info "  git -C '$VAULT' remote add origin git@github.com:TechTripAi/<vault-repo>.git"
  info "  git -C '$VAULT' push -u origin main"
fi

# ── Syncthing (optional) ─────────────────────────────────────────────────────
step "Syncthing (optional real-time LAN sync)"
if confirm "Set up Syncthing for real-time sync across your Macs?"; then
  if ! have_cmd syncthing; then
    have_cmd brew || die "Homebrew required for Syncthing. Run bin/setup-deps.sh."
    run "Install Syncthing" -- brew install syncthing
  else ok "Syncthing already installed"; fi
  run "Start Syncthing service" -- brew services start syncthing || true

  STIGNORE="$VAULT/.stignore"
  if [ ! -f "$STIGNORE" ]; then
    if [ "$TSB_DRY_RUN" = "1" ]; then info "[dry-run] would write $STIGNORE"
    else
      cat > "$STIGNORE" <<'EOF'
// techtrip-secondbrain: keep Syncthing and git from fighting.
.git
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash
.DS_Store
EOF
      ok "Wrote .stignore (excludes .git, workspace.json, .trash, .DS_Store)"
    fi
  else ok ".stignore already present"; fi

  info "Finish pairing in the Syncthing UI: http://127.0.0.1:8384"
  info "  1. On each Mac: brew install syncthing && brew services start syncthing"
  info "  2. Add Remote Device (exchange Device IDs), then share the vault folder."
  warn "Single-writer rule: edit on one machine at a time; concurrent edits create"
  warn ".sync-conflict copies. Git history stays authoritative on the committing machine."
else
  info "Skipping Syncthing. Git remains the sync/backup path."
fi

step "Sync setup complete"
