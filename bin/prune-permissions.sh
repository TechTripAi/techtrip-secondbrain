#!/usr/bin/env bash
# techtrip-secondbrain — prune dead plugin-cache permission rules from
# settings.local.json.
#
# Claude Code saves approved permission rules with the versioned plugin-cache
# path baked in (~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/…).
# Every plugin update moves that root, so the old rules go permanently dead:
# they can never match a command again, the user gets re-prompted, and Claude's
# built-in /doctor flags them as invalid. This removes ONLY rules whose
# glob-free cache path is provably dead — the version dir is missing, or a
# newer version of that plugin is installed (old dirs can linger in the cache).
# Removing a dead rule can only ever cause a one-time re-prompt, never grant
# anything new. Everything else in the file is left alone (JSON re-serialized,
# 2-space indent).
#
# Scans the two files this stack writes to: ~/.claude/settings.local.json
# (user scope) and <vault>/.claude/settings.local.json (the vault project).
# Before editing a file, a timestamped backup lands in
# ~/.config/techtrip-secondbrain/permission-backups/.
#
# Idempotent + interactive; report-only under --dry-run.
# Usage: bash bin/prune-permissions.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

VAULT="$(default_vault_path "${1:-}")"
step "Prune dead plugin-cache permission rules"
info "Vault: $VAULT"
have_cmd node || die "node is required to edit settings JSON (brew install node)."

BACKUP_DIR="$TSB_STATE_DIR/permission-backups"
TOTAL_REMOVED=0

prune_file() {
  local f="$1" pretty stale n backup removed
  pretty="${f/#$HOME/~}"
  if [ ! -f "$f" ]; then
    info "$pretty — not present, nothing to prune."
    return 0
  fi
  stale="$(stale_permission_rules "$f")"
  if [ -z "$stale" ]; then
    ok "$pretty — no dead rules."
    return 0
  fi
  n="$(printf '%s\n' "$stale" | grep -c .)"
  warn "$pretty — $n dead rule(s) point at plugin-cache versions that are gone or superseded:"
  while IFS=$'\t' read -r list rule; do
    [ -n "$rule" ] || continue
    printf '      %s[%s]%s %s\n' "$_C_DIM" "$list" "$_C_RESET" "$rule"
  done <<<"$stale"
  if ! confirm_yes "Remove these $n rule(s) from $pretty? (a backup is kept first)"; then
    info "Left untouched."
    return 0
  fi
  if [ "$TSB_DRY_RUN" = 1 ]; then
    printf '%s  [dry-run]%s would back up %s to %s/ and remove the %s rule(s) above\n' \
      "$_C_YEL" "$_C_RESET" "$pretty" "${BACKUP_DIR/#$HOME/~}" "$n"
    return 0
  fi
  mkdir -p "$BACKUP_DIR"
  # $$ keeps same-second runs from silently overwriting an earlier backup.
  backup="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)-$$$(printf '%s' "$f" | tr '/' '_')"
  cp "$f" "$backup"
  # Exact-match removal of the rules the detector printed (list + rule string),
  # written atomically (tmp + rename) so a crash can't half-write the file.
  removed="$(printf '%s\n' "$stale" | node -e '
    const fs=require("fs");
    const file=process.argv[1];
    let s="";
    process.stdin.on("data",d=>s+=d).on("end",()=>{
      const dead=new Set(s.split("\n").filter(Boolean));
      const j=JSON.parse(fs.readFileSync(file,"utf8"));
      const p=(j&&j.permissions)||{};
      let removed=0;
      for(const list of ["allow","deny","ask"]){
        if(!Array.isArray(p[list]))continue;
        const before=p[list].length;
        p[list]=p[list].filter(r=>!(typeof r==="string"&&dead.has(list+"\t"+r)));
        removed+=before-p[list].length;
      }
      const tmp=file+".tsb-tmp";
      fs.writeFileSync(tmp,JSON.stringify(j,null,2)+"\n");
      fs.renameSync(tmp,file);
      process.stdout.write(String(removed));
    });
  ' "$f")"
  case "$removed" in ''|*[!0-9]*) die "unexpected prune result for $pretty: '$removed'" ;; esac
  ok "Removed $removed rule(s) from $pretty (backup: ${backup/#$HOME/~})"
  TOTAL_REMOVED=$((TOTAL_REMOVED + removed))
}

prune_file "$HOME/.claude/settings.local.json"
# Skip the vault file when it IS the user file (vault set to $HOME — unusual).
if [ "$VAULT/.claude/settings.local.json" != "$HOME/.claude/settings.local.json" ]; then
  prune_file "$VAULT/.claude/settings.local.json"
fi

step "Prune complete"
if [ "$TOTAL_REMOVED" -gt 0 ]; then
  info "Removed $TOTAL_REMOVED dead rule(s). Restart Claude Code sessions to pick up"
  info "the change. If you re-approve a command later, a fresh rule is saved against"
  info "the current plugin version — that is expected."
else
  info "Nothing removed."
fi
exit 0
