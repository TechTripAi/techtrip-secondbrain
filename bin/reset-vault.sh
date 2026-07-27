#!/usr/bin/env bash
# techtrip-secondbrain — reset a vault to empty, backup first. Two depths:
#
#   content reset (default)  Empty the knowledge (wiki/ .raw/ .vault-meta/
#                            _attachments/ _templates/ + scaffold root files)
#                            but KEEP the wiring: .obsidian/ (community
#                            plugins + REST key), git history, harness
#                            artifacts. MCP keeps working; the reset is a
#                            commit, so old content stays in history.
#
#   --scorch                 Retire the whole vault (mv aside, nothing
#                            deleted) and re-scaffold fresh at the same path
#                            via setup-vault.sh. Prints the setup-mcp.sh
#                            reminder — the REST key retires with the old
#                            vault, so MCP must be re-keyed.
#
# Backups are NOT optional: a tar.gz snapshot always; a git bundle too when
# the vault is a repo. Both are verified before anything destructive runs.
# Restore: tar -xzf <tgz> -C <parent>   |   git clone <bundle> <dir>
#
# Idempotent + interactive. Usage:
#   bash bin/reset-vault.sh [/path/to/vault] [--scorch] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"

SCORCH=0
_args=()
for a in "$@"; do
  case "$a" in
    --scorch) SCORCH=1 ;;
    *) _args+=("$a") ;;
  esac
done
parse_common_flags ${_args[@]+"${_args[@]}"}; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}
require_macos

VAULT="$(default_vault_path "${1:-}")"
STAMP="$(date +%Y-%m-%d-%H%M%S)"
BACKUP_DIR="${TSB_BACKUP_DIR:-$HOME/vault-backups}"

[ -d "$VAULT" ] || die "Vault not found at $VAULT — nothing to reset."
# Canonicalize BEFORE the safety guards: a trailing slash, relative path, or
# `..` segment must not slip past them (and would break the basename/dirname
# used for backup file names).
VAULT="$(cd "$VAULT" && pwd -P)" || die "Cannot resolve vault path."

step "Vault reset ($([ "$SCORCH" = "1" ] && echo "scorched earth" || echo "content reset"))"
info "Vault:   $VAULT"
info "Backups: $BACKUP_DIR"
case "$VAULT" in
  "$HOME"|/|"") die "Refusing to reset '$VAULT' — not a vault path." ;;
esac
[ -d "$VAULT/wiki" ] || [ -d "$VAULT/.obsidian" ] || \
  die "$VAULT has neither wiki/ nor .obsidian/ — doesn't look like a vault; refusing."
# Canonicalize BACKUP_DIR the same way before comparing (macOS: /tmp vs
# /private/tmp would defeat a plain prefix match). It may not exist yet, so
# resolve its deepest existing ancestor and re-append the rest.
_probe="$BACKUP_DIR"
while [ -n "$_probe" ] && [ ! -d "$_probe" ]; do _probe="$(dirname "$_probe")"; done
BACKUP_DIR="$(cd "${_probe:-/}" && pwd -P)${BACKUP_DIR#"$_probe"}"
unset _probe
case "$BACKUP_DIR/" in
  "$VAULT"/*) die "Backup dir ($BACKUP_DIR) is inside the vault — the snapshot would try to archive itself and a reset could delete it. Set TSB_BACKUP_DIR outside the vault." ;;
esac

# ── Obsidian must not be writing the vault mid-reset ──────────────────────────
if pgrep -x Obsidian >/dev/null 2>&1; then
  warn "Obsidian is running. It holds the vault open and rewrites .obsidian/ state."
  confirm "Continue anyway? (Recommended: quit Obsidian first)" || die "Aborted — quit Obsidian and re-run."
fi

# ── Backup (mandatory, verified) ──────────────────────────────────────────────
step "Backup"
TGZ="$BACKUP_DIR/$(basename "$VAULT")-$STAMP.tgz"
BUNDLE="$BACKUP_DIR/$(basename "$VAULT")-$STAMP.bundle"
run "Create backup dir" -- mkdir -p "$BACKUP_DIR"

if [ -d "$VAULT/.git" ]; then
  # Capture uncommitted work as a real commit (not a stash) so both the
  # bundle and post-reset history contain it. `git add -A` first: `commit -am`
  # alone would silently drop untracked files from the history backup.
  if [ -n "$(git -C "$VAULT" status --porcelain 2>/dev/null)" ]; then
    run "Commit uncommitted vault changes (pre-reset snapshot)" -- bash -c \
      'cd "$1" && git add -A && git -c commit.gpgsign=false commit -qm "chore: pre-reset snapshot ($2)"' _ "$VAULT" "$STAMP"
  fi
  run "Write git bundle (full history)" -- git -C "$VAULT" bundle create "$BUNDLE" --all
else
  warn "Vault is not a git repo — file snapshot only (no history bundle)."
  warn "Both backup forms are recommended: run bin/setup-sync.sh to git-enable the vault."
  confirm "Continue with tar.gz snapshot as the only backup?" || die "Aborted. Nothing changed."
fi

run "Write tar.gz snapshot" -- tar -czf "$TGZ" -C "$(dirname "$VAULT")" "$(basename "$VAULT")"

# Verify — an unverified backup is a hope, not a backup.
if [ "$TSB_DRY_RUN" != "1" ]; then
  tar -tzf "$TGZ" >/dev/null || die "tar backup failed verification: $TGZ"
  ok "Snapshot verified: $TGZ ($(du -h "$TGZ" | cut -f1))"
  if [ -f "$BUNDLE" ]; then
    git bundle verify "$BUNDLE" >/dev/null 2>&1 || die "git bundle failed verification: $BUNDLE"
    ok "History bundle verified: $BUNDLE"
  fi
fi

# ── Reset ─────────────────────────────────────────────────────────────────────
if [ "$SCORCH" = "1" ]; then
  step "Scorched earth: retire vault, re-scaffold fresh"
  RETIRED="$VAULT-retired-$STAMP"
  [ -e "$RETIRED" ] && die "Retire target already exists: $RETIRED — mv would nest the vault inside it; remove or rename it first."
  confirm_phrase "scorch my vault" \
    "About to move $VAULT → $RETIRED and scaffold a NEW empty vault at $VAULT." \
    || die "Aborted. Nothing changed (backups kept)."
  run "Retire old vault" -- mv "$VAULT" "$RETIRED"
  # TSB_DRY_RUN / TSB_ASSUME_YES are exported (common.sh), so the repo's own
  # setup-vault.sh inherits them — no flag forwarding needed. `if !` keeps a
  # scaffold failure from set-e-exiting without telling the user where the
  # old vault went.
  SCAFFOLD_OK=1
  if SETUP="$(find_claude_obsidian_setup)"; then
    run "Scaffold fresh vault (claude-obsidian setup-vault)" -- bash "$SETUP" "$VAULT" || SCAFFOLD_OK=0
  elif [ -x "$REPO_ROOT/bin/setup-vault.sh" ]; then
    run "Scaffold fresh vault (setup-vault.sh)" -- bash "$REPO_ROOT/bin/setup-vault.sh" "$VAULT" || SCAFFOLD_OK=0
  else
    warn "No setup-vault.sh found — scaffold manually: bash bin/setup-vault.sh '$VAULT'"
  fi
  if [ "$SCAFFOLD_OK" != "1" ]; then
    err "Scaffold failed. Your data is safe: old vault at $RETIRED, backups at $BACKUP_DIR."
    die "Fix the scaffold error and re-run: bash bin/setup-vault.sh '$VAULT'"
  fi
  step "Scorched-earth reset complete"
  warn "MCP re-key required: the REST API key retired with the old vault."
  info "Run: bash bin/setup-mcp.sh '$VAULT'"
  info "Then open the new vault in Obsidian (enable community plugins when asked)"
  info "and remove the retired vault from Obsidian's vault switcher."
  info "Old vault kept at: $RETIRED (delete yourself when confident)"
else
  step "Content reset: empty the knowledge, keep the wiring"
  info "Removes: wiki/ .raw/ .vault-meta/ _attachments/ _templates/ WIKI.md *.canvas *.base"
  info "Keeps:   .obsidian/ .git/ AGENTS.md .cursor/ .github/"
  confirm_phrase "reset my vault" "About to empty the vault content at $VAULT." \
    || die "Aborted. Nothing changed (backups kept)."
  for d in wiki .raw .vault-meta _attachments _templates; do
    [ -e "$VAULT/$d" ] && run "Remove $d/" -- rm -rf "$VAULT/$d"
  done
  # Scaffold-generated root files; -f tolerates absence, glob may not match.
  run "Remove scaffold root files" -- bash -c \
    'cd "$1" && rm -f WIKI.md ./*.canvas ./*.base 2>/dev/null || true' _ "$VAULT"
  if [ -d "$VAULT/.git" ]; then
    # Skip cleanly when nothing is staged; fail LOUDLY on a real commit error
    # (a bare `|| true` would hide e.g. a missing git identity).
    run "Commit the reset" -- bash -c \
      'cd "$1" && git add -A && { git diff --cached --quiet || git -c commit.gpgsign=false commit -qm "reset: empty vault (backup: $2)"; }' _ "$VAULT" "$TGZ"
  fi
  step "Content reset complete"
  info "Re-scaffold structure with /wiki in Claude Code, or: bash bin/setup-vault.sh '$VAULT'"
  info "MCP untouched — .obsidian/ and its REST key were preserved."
  if [ -d "$VAULT/.git" ]; then
    info "Old content remains in git history and in: $TGZ"
  else
    info "Old content remains in: $TGZ"
  fi
fi

step "Post-reset check"
if [ -x "$REPO_ROOT/bin/doctor.sh" ]; then
  info "Recommended: bash bin/doctor.sh '$VAULT'"
else
  info "Recommended: run /secondbrain-doctor in Claude Code."
fi
