#!/usr/bin/env bash
# techtrip-secondbrain — precheck (report-only).
# Audits this machine against manifest.json and prints PRESENT / MISSING for every
# binary, app, Claude plugin, and MCP server. Mutates nothing; always exits 0.
#
# Usage: bash bin/precheck.sh
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"

PRESENT_MARK="${_C_GRN}present${_C_RESET}"
MISSING_MARK="${_C_YEL}missing${_C_RESET}"
OPTIONAL_MARK="${_C_DIM}optional (off)${_C_RESET}"
missing=0

row() { printf '   %-28s %s\n' "$1" "$2"; }

step "techtrip-secondbrain precheck"
info "Manifest: $MANIFEST"
if [ "$(uname -s)" = "Darwin" ]; then ok "macOS ($(sw_vers -productVersion 2>/dev/null || echo '?'))"
else warn "Non-macOS host ($(uname -s)) — MVP targets macOS; installers may not work."; fi

# ── Binaries ─────────────────────────────────────────────────────────────────
step "Binaries"
while IFS=$'\t' read -r cmd label install optional; do
  [ -n "$cmd" ] || continue
  if have_cmd "$cmd"; then row "$label ($cmd)" "$PRESENT_MARK"
  elif [ "$optional" = "1" ]; then row "$label ($cmd)" "$OPTIONAL_MARK  → bin/setup-features.sh"
  else row "$label ($cmd)" "$MISSING_MARK  → $install"; missing=$((missing+1)); fi
done < <(manifest_get 'm.binaries.map(b=>[b.cmd,b.label||b.cmd,b.install||"",b.optional?"1":"0"].join("\t")).join("\n")')

# ── Apps ─────────────────────────────────────────────────────────────────────
step "Applications"
while IFS=$'\t' read -r name check cask; do
  [ -n "$name" ] || continue
  if [ -e "$check" ]; then row "$name" "$PRESENT_MARK"
  else row "$name" "$MISSING_MARK  → brew install --cask $cask"; missing=$((missing+1)); fi
done < <(manifest_get 'm.apps.map(a=>[a.name,a.check,a.cask||""].join("\t")).join("\n")')

# ── Claude plugins ───────────────────────────────────────────────────────────
step "Claude Code plugins"
if have_cmd claude; then
  plugins_out="$(claude plugin list 2>/dev/null || true)"
  while IFS=$'\t' read -r id slug tested; do
    [ -n "$id" ] || continue
    # -F: the id is a literal, not a regex; word-ish anchor avoids substring
    # false-positives (an id appearing inside another plugin's description).
    if printf '%s' "$plugins_out" | grep -qF "$id"; then
      # claude-obsidian (AgriciDaniel) can't be version-pinned via the CLI, so
      # testedVersion is advisory: report drift as a note, never a failure.
      have=""; [ -n "$tested" ] && have="$(claude_obsidian_installed_version 2>/dev/null || true)"
      if [ -n "$have" ] && [ -n "$tested" ] && [ "$have" != "$tested" ]; then
        row "$id" "$PRESENT_MARK  ${_C_DIM}v$have ≠ tested v$tested (version drift)${_C_RESET}"
      else
        row "$id" "$PRESENT_MARK${have:+ v$have}"
      fi
    else row "$id" "$MISSING_MARK  → claude plugin install $slug"; missing=$((missing+1)); fi
  done < <(manifest_get 'm.claudePlugins.map(p=>[p.id,p.slug,p.testedVersion||""].join("\t")).join("\n")')
else
  warn "claude CLI not found — install Claude Code first (prerequisite)."; missing=$((missing+1))
fi

# ── MCP servers ──────────────────────────────────────────────────────────────
step "MCP servers"
if have_cmd claude; then
  mcp_out="$(claude mcp list 2>/dev/null || true)"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    # Anchor to the "name: command…" column — a substring match would
    # false-positive on a different server whose command mentions the name.
    if printf '%s' "$mcp_out" | grep -qE "^${name}:"; then row "$name" "$PRESENT_MARK"
    else row "$name" "$MISSING_MARK  → bin/setup-mcp.sh"; missing=$((missing+1)); fi
  done < <(manifest_get 'm.mcpServers.map(s=>s.name).join("\n")')
else
  row "obsidian" "$MISSING_MARK  (claude CLI unavailable)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
step "Summary"
if [ "$missing" -eq 0 ]; then ok "All manifest items present. Run bin/setup-vault.sh to scaffold a vault."
else warn "$missing item(s) missing. Run bin/setup-deps.sh, setup-obsidian.sh, setup-claude-obsidian.sh, setup-mcp.sh (or the /secondbrain skill) to fill the gaps."; fi
exit 0
