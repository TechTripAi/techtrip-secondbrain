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
#      claude-obsidian hooks), .cursor/rules/wiki-vault.mdc, and
#      .github/hooks/wiki-vault.json + .github/hooks/*.sh (Copilot CLI ports
#      of the same hooks — hot-cache injection, auto-commit, stop reminder).
#      Existing files are never overwritten; drift is reported instead.
#
# Usage:
#   bash bin/setup-harnesses.sh [vault-path] [--dry-run] [--yes]
#   bash bin/setup-harnesses.sh --skip-vault      # machine-level links only

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

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

# The cross-vendor Agent Skills spec caps SKILL.md `description` at 1024
# chars; Copilot CLI enforces it and silently skips over-limit skills. Claude
# Code doesn't care, so an oversized description only surfaces as a skill
# missing from other harnesses — warn here, where the skills get exported.
check_description_lengths() {
  local src skill len
  while IFS= read -r src; do
    for skill in "$src"/*/; do
      [ -f "$skill/SKILL.md" ] || continue
      len="$(node -e '
        const s = require("fs").readFileSync(process.argv[1], "utf8");
        const fm = s.match(/^---\n([\s\S]*?)\n---/);
        if (!fm) { console.log(0); process.exit(0); }
        const lines = fm[1].split("\n");
        let cap = false, buf = [];
        for (const l of lines) {
          if (/^description:/.test(l)) { cap = true; const r = l.replace(/^description:\s*[|>]?-?\s*/, ""); if (r) buf.push(r); continue; }
          if (cap) { if (/^\S/.test(l)) break; buf.push(l.trim()); }
        }
        console.log(buf.join(" ").replace(/^"|"$/g, "").trim().length);
      ' "$skill/SKILL.md" 2>/dev/null || echo 0)"
      if [ "${len:-0}" -gt 1024 ]; then
        warn "$(basename "$skill") SKILL.md description is $len chars (> the Agent Skills spec's 1024 cap) — Copilot CLI will skip this skill; shorten the description."
      fi
    done
  done < <(skill_source_dirs)
}

step "Machine-level skill discovery (cross-harness)"
if [ -z "$(skill_source_dirs)" ]; then
  warn "No installed plugin skills found under ~/.claude/plugins/cache/ — run bin/setup-claude-obsidian.sh first."
else
  check_description_lengths
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
      warn "$dst exists and differs from the template — left untouched. If you never customized it: rm it and re-run to adopt the new template; if you did: port wanted changes manually (diff against $src)."
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
    stamp "$TEMPLATES/copilot/hooks/wiki-vault.json"        "$VAULT/.github/hooks/wiki-vault.json"
    stamp "$TEMPLATES/copilot/hooks/wiki-autocommit.sh"     "$VAULT/.github/hooks/wiki-autocommit.sh"
    stamp "$TEMPLATES/copilot/hooks/wiki-stop-reminder.sh"  "$VAULT/.github/hooks/wiki-stop-reminder.sh"
    stamp "$TEMPLATES/copilot/hooks/wiki-session-start.sh"  "$VAULT/.github/hooks/wiki-session-start.sh"
    if [ -d "$VAULT/.cursor/hooks" ]; then
      run "make Cursor hooks executable" -- chmod +x \
        "$VAULT/.cursor/hooks/wiki-autocommit.sh" \
        "$VAULT/.cursor/hooks/wiki-stop-reminder.sh" \
        "$VAULT/.cursor/hooks/wiki-session-start.sh"
    fi
    if [ -d "$VAULT/.github/hooks" ]; then
      run "make Copilot hooks executable" -- chmod +x \
        "$VAULT/.github/hooks/wiki-autocommit.sh" \
        "$VAULT/.github/hooks/wiki-stop-reminder.sh" \
        "$VAULT/.github/hooks/wiki-session-start.sh"
    fi

    # Record which plugin version stamped the vault, so the session-start hook
    # ports and doctor.sh can flag stale parity artifacts (stamp() never
    # overwrites, so staleness is otherwise invisible). Only rewritten when the
    # version changed — an idempotent re-run must not dirty the vault.
    PLUGIN_VERSION="$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).version||""))' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null)"
    PARITY_MARKER="$VAULT/.vault-meta/harness-parity.json"
    if [ -n "$PLUGIN_VERSION" ]; then
      STAMPED_BY="$(node -e 'try{process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).stampedBy||""))}catch{}' "$PARITY_MARKER" 2>/dev/null)"
      if [ "$STAMPED_BY" = "$PLUGIN_VERSION" ]; then
        ok "harness-parity.json already current (stampedBy $PLUGIN_VERSION)."
      elif [ "$TSB_DRY_RUN" = 1 ]; then
        info "[dry-run] write $PARITY_MARKER (stampedBy: $PLUGIN_VERSION)"
      else
        mkdir -p "$VAULT/.vault-meta"
        node -e 'require("fs").writeFileSync(process.argv[1], JSON.stringify({ stampedBy: process.argv[2] }, null, 2) + "\n")' "$PARITY_MARKER" "$PLUGIN_VERSION"
        ok "harness-parity.json → stampedBy $PLUGIN_VERSION"
      fi
    fi
    save_vault_path "$VAULT"
    info "Restart Cursor after first install so the hooks load."
  fi
fi

step "Done"
ok "Harness setup complete. Claude Code needs nothing; Cursor picks up .cursor/; Copilot CLI picks up .github/hooks/; Codex reads AGENTS.md + ~/.agents/skills (or ~/.codex/skills)."
