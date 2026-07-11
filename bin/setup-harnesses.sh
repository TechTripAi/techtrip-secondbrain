#!/usr/bin/env bash
# setup-harnesses.sh — make the second brain harness-agnostic.
#
# Two independent jobs, both idempotent:
#
#   1. MACHINE level: symlink the installed skills (claude-obsidian suite +
#      this plugin's source skills) into the cross-vendor skill directories
#      (~/.agents/skills/ always; ~/.codex/skills/ when Codex is present or
#      confirmed) so Cursor, Codex, and other harnesses discover the same
#      SKILL.md files Claude Code uses. Links point at the newest installed
#      plugin version; re-run after `bin/update.sh` to re-point them.
#
#   2. VAULT level (when a vault path is given or saved): stamp the
#      harness-parity artifacts from templates/harness/ into the vault —
#      AGENTS.md (the agent operating contract, all harnesses read it),
#      .cursor/hooks.json + .cursor/hooks/*.sh (Cursor ports of the
#      claude-obsidian hooks), and .cursor/rules/wiki-vault.mdc.
#      Existing files are never overwritten; drift is reported instead.
#
# Usage:
#   bash bin/setup-harnesses.sh [vault-path] [--dry-run] [--yes]
#   bash bin/setup-harnesses.sh --skip-vault      # machine-level links only

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"

require_macos

SKIP_VAULT=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --skip-vault) SKIP_VAULT=1 ;;
    *) ARGS+=("$a") ;;
  esac
done

TEMPLATES="$REPO_ROOT/templates/harness"
[ -d "$TEMPLATES" ] || die "templates/harness/ missing — reinstall or git pull."

# ── Collect installed skill directories ───────────────────────────────────────
# Newest installed version of each plugin's skills/ dir.
skill_source_dirs() {
  local d
  for d in \
    "$(ls -1d "$HOME"/.claude/plugins/cache/*/claude-obsidian/*/skills 2>/dev/null | sort -V | tail -1)" \
    "$(ls -1d "$HOME"/.claude/plugins/cache/*/techtrip-secondbrain/*/skills 2>/dev/null | sort -V | tail -1)"; do
    [ -n "$d" ] && [ -d "$d" ] && printf '%s\n' "$d"
  done
}

# ── Step 1: machine-level skill links ─────────────────────────────────────────
link_skills_into() {
  local target="$1" src skill name linked=0 skipped=0
  run "create $target" -- mkdir -p "$target"
  while IFS= read -r src; do
    for skill in "$src"/*/; do
      [ -d "$skill" ] || continue
      [ -f "$skill/SKILL.md" ] || continue
      name="$(basename "$skill")"
      # ln -sfn is idempotent and re-points stale links after plugin updates.
      if [ -e "$target/$name" ] && [ ! -L "$target/$name" ]; then
        warn "$target/$name exists and is not a symlink — leaving it alone."
        skipped=$((skipped+1))
        continue
      fi
      run "link $name" -- ln -sfn "${skill%/}" "$target/$name"
      linked=$((linked+1))
    done
  done < <(skill_source_dirs)
  ok "$target: $linked skill link(s) current, $skipped skipped."
}

step "Machine-level skill discovery (cross-harness)"
if [ -z "$(skill_source_dirs)" ]; then
  warn "No installed plugin skills found under ~/.claude/plugins/cache/ — run bin/setup-claude-obsidian.sh first."
else
  # ~/.agents/skills is the emerging cross-vendor convention; always safe.
  link_skills_into "$HOME/.agents/skills"

  # ~/.codex/skills only if Codex is present (or the user opts in anyway).
  if [ -d "$HOME/.codex" ] || have_cmd codex; then
    link_skills_into "$HOME/.codex/skills"
  elif confirm "Codex not detected — link skills into ~/.codex/skills anyway?"; then
    link_skills_into "$HOME/.codex/skills"
  else
    info "Skipping ~/.codex/skills (no Codex on this machine)."
  fi
fi

# ── Step 2: vault-level parity artifacts ──────────────────────────────────────
# Copy a template into the vault only if the destination does not exist.
# Existing files are the owner's — report drift, never overwrite.
stamp() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      ok "$(basename "$dst") already current."
    else
      warn "$dst exists and differs from the template — left untouched (diff manually if curious)."
    fi
    return 0
  fi
  run "install $dst" -- mkdir -p "$(dirname "$dst")"
  run "copy $(basename "$src")" -- cp "$src" "$dst"
}

if [ "$SKIP_VAULT" = "1" ]; then
  info "Vault stamping skipped (--skip-vault)."
else
  VAULT="$(default_vault_path "${ARGS[0]:-}")"
  if [ ! -d "$VAULT/wiki" ]; then
    warn "No wiki/ under $VAULT — skipping vault-level stamping (pass the vault path explicitly, or run setup-vault.sh first)."
  else
    step "Vault-level harness parity: $VAULT"
    stamp "$TEMPLATES/AGENTS.md"                            "$VAULT/AGENTS.md"
    stamp "$TEMPLATES/cursor/hooks.json"                    "$VAULT/.cursor/hooks.json"
    stamp "$TEMPLATES/cursor/hooks/wiki-autocommit.sh"      "$VAULT/.cursor/hooks/wiki-autocommit.sh"
    stamp "$TEMPLATES/cursor/hooks/wiki-stop-reminder.sh"   "$VAULT/.cursor/hooks/wiki-stop-reminder.sh"
    stamp "$TEMPLATES/cursor/hooks/wiki-session-start.sh"   "$VAULT/.cursor/hooks/wiki-session-start.sh"
    stamp "$TEMPLATES/cursor/rules/wiki-vault.mdc"          "$VAULT/.cursor/rules/wiki-vault.mdc"
    if [ -d "$VAULT/.cursor/hooks" ]; then
      run "make Cursor hooks executable" -- chmod +x \
        "$VAULT/.cursor/hooks/wiki-autocommit.sh" \
        "$VAULT/.cursor/hooks/wiki-stop-reminder.sh" \
        "$VAULT/.cursor/hooks/wiki-session-start.sh"
    fi
    save_vault_path "$VAULT"
    info "Restart Cursor after first install so the hooks load."
  fi
fi

step "Done"
ok "Harness setup complete. Claude Code needs nothing; Cursor picks up .cursor/; Codex reads AGENTS.md + ~/.agents/skills (or ~/.codex/skills)."
