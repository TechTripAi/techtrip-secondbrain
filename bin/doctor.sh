#!/usr/bin/env bash
# techtrip-secondbrain — post-install health check for a scaffolded vault.
# Report-only; always exits 0. Usage: bash bin/doctor.sh [/path/to/vault]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"

VAULT="$(default_vault_path "${1:-}")"
OKM="${_C_GRN}ok${_C_RESET}"; BADM="${_C_YEL}check${_C_RESET}"
row() { printf '   %-40s %s\n' "$1" "$2"; }

step "techtrip-secondbrain doctor"
info "Vault: $VAULT"

# Vault scaffold
[ -d "$VAULT/wiki" ] && row "wiki/ tree" "$OKM" || row "wiki/ tree" "$BADM  → bin/setup-vault.sh"

# Required binaries (manifest-driven; includes claude-obsidian runtime deps like flock).
# Optional binaries are reported by the optional-features section below, not here.
step "Required binaries"
while IFS=$'\t' read -r cmd label install; do
  [ -n "$cmd" ] || continue
  have_cmd "$cmd" && row "$label ($cmd)" "$OKM" \
    || row "$label ($cmd)" "$BADM  → $install"
done < <(manifest_get 'm.binaries.filter(b=>!b.optional).map(b=>[b.cmd,b.label||b.cmd,b.install||""].join("\t")).join("\n")')

# Community plugins present + enabled
step "Community plugins"
CP="$VAULT/.obsidian/community-plugins.json"
while IFS= read -r id; do
  [ -n "$id" ] || continue
  present=0; enabled=0
  [ -f "$VAULT/.obsidian/plugins/$id/main.js" ] && present=1
  [ -f "$CP" ] && grep -q "\"$id\"" "$CP" && enabled=1
  if [ "$present" = 1 ] && [ "$enabled" = 1 ]; then row "$id" "$OKM"
  else row "$id" "$BADM  (files:$present enabled:$enabled)"; fi
done < <(manifest_get 'm.obsidianPlugins.map(p=>p.id).join("\n")')

# MCP key handshake: data.json apiKey == ~/.claude.json OBSIDIAN_API_KEY
step "MCP key handshake"
DATA="$VAULT/.obsidian/plugins/obsidian-local-rest-api/data.json"
CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$DATA" ] && [ -f "$CLAUDE_JSON" ]; then
  match="$(node -e '
    try{
      const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const c=JSON.parse(require("fs").readFileSync(process.argv[2],"utf8"));
      const s=(c.mcpServers&&c.mcpServers.obsidian)||{};
      const envKey=(s.env&&s.env.OBSIDIAN_API_KEY)||"";
      process.stdout.write(d.apiKey && envKey && d.apiKey===envKey ? "yes":"no");
    }catch(e){process.stdout.write("no")}
  ' "$DATA" "$CLAUDE_JSON" 2>/dev/null)"
  [ "$match" = yes ] && row "REST API key == MCP env key" "$OKM" \
    || row "REST API key == MCP env key" "$BADM  → bin/setup-mcp.sh"
else
  row "REST API key == MCP env key" "$BADM  (data.json or ~/.claude.json missing)"
fi

# claude-obsidian plugin + skills
step "Claude Code"
if have_cmd claude; then
  if claude plugin list 2>/dev/null | grep -q claude-obsidian; then
    cov="$(claude_obsidian_installed_version 2>/dev/null || true)"
    tested="$(manifest_get 'm.claudePlugins[0].testedVersion')"
    if [ -n "$cov" ] && [ -n "$tested" ] && [ "$cov" != "$tested" ]; then
      row "claude-obsidian plugin" "$BADM  v$cov ≠ tested v$tested (AgriciDaniel; version drift)"
    else
      row "claude-obsidian plugin" "$OKM${cov:+ v$cov} (by AgriciDaniel)"
    fi
    # Installed from the maintained fork, or a stale upstream/other copy? The fork
    # carries the bug fixes; an upstream slug means this machine misses them.
    # (`|| true` guards the no-match grep; doctor has no `set -e` but keep it clean.)
    want_slug="$(manifest_get 'm.claudePlugins[0].slug')"
    have_slug="$(claude plugin list 2>/dev/null | grep -oE 'claude-obsidian@[a-z0-9._-]+' | head -1 || true)"
    if [ -n "$have_slug" ] && [ "$have_slug" != "$want_slug" ]; then
      row "claude-obsidian source" "$BADM  '$have_slug' ≠ fork '$want_slug' → bin/setup-claude-obsidian.sh migrates"
    elif [ -n "$have_slug" ]; then
      row "claude-obsidian source" "$OKM (maintained fork)"
    fi
    # Some builds (upstream ≤1.9.2) ship a type:"prompt" hook under SessionStart, which
    # supports only command/mcp_tool → harmless startup validation warning on stricter
    # clients. REPORT-ONLY: secondbrain never patches the installed cache (AGENTS.md
    # invariant); the fix lives in the maintained fork, so the remedy is to
    # migrate/reinstall from it (setup-claude-obsidian.sh).
    coh="$(ls -1 "$HOME"/.claude/plugins/cache/*/claude-obsidian/*/hooks/hooks.json 2>/dev/null | sort -V | tail -1)"
    if [ -n "$coh" ]; then
      bad="$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const ss=(j.hooks&&j.hooks.SessionStart)||[];let n=0;for(const g of ss)if(g&&Array.isArray(g.hooks))for(const h of g.hooks)if(h&&h.type==="prompt")n++;process.stdout.write(String(n))}catch(e){process.stdout.write("0")}' "$coh" 2>/dev/null)"
      if [ "${bad:-0}" != 0 ]; then
        row "SessionStart hooks valid" "$BADM  ($bad unsupported prompt hook(s) → bin/setup-claude-obsidian.sh installs the fixed fork)"
      else
        row "SessionStart hooks valid" "$OKM"
      fi
    fi
  else row "claude-obsidian plugin" "$BADM  → bin/setup-claude-obsidian.sh"; fi
  claude mcp list 2>/dev/null | grep -q obsidian \
    && row "obsidian MCP server" "$OKM" || row "obsidian MCP server" "$BADM  → bin/setup-mcp.sh"
else
  row "claude CLI" "$BADM  (install Claude Code)"
fi

# Optional features (informational — never a failure; enable via setup-features.sh)
step "Optional features (off by default)"
ONM="${_C_GRN}on${_C_RESET}"; OFFM="${_C_DIM}off${_C_RESET}"
while IFS=$'\t' read -r id label binary; do
  [ -n "$id" ] || continue
  if [ "$id" = notebooklm ]; then
    # 'on' = CLI installed; auth is a separate one-time step.
    have_cmd notebooklm && row "$label" "$ONM (run 'notebooklm login' once if unauthed)" \
      || row "$label" "$OFFM  → bin/setup-features.sh notebooklm"
  else
    have_cmd "$binary" && row "$label" "$ONM" \
      || row "$label" "$OFFM  → bin/setup-features.sh $id"
  fi
done < <(manifest_get 'm.optionalFeatures.map(f=>[f.id,f.label,f.binary||""].join("\t")).join("\n")')

# Cross-harness skill links (informational — Claude Code itself never needs them).
# A link is stale when its cache target was pruned or a newer plugin version is
# installed; that happens when the plugin was updated without re-running
# setup-harnesses.sh (bin/update.sh and the /secondbrain re-run both do).
step "Cross-harness skill links (Cursor/Codex)"
check_harness_links() {
  local dir="$1" total=0 stale=0 l dest plugdir newest
  if [ ! -d "$dir" ]; then
    row "$dir" "$OFFM  → bin/setup-harnesses.sh"
    return 0
  fi
  for l in "$dir"/*; do
    [ -L "$l" ] || continue
    dest="$(readlink "$l" 2>/dev/null)" || continue
    case "$dest" in "$HOME"/.claude/plugins/cache/*) ;; *) continue ;; esac
    total=$((total+1))
    plugdir="${dest%/skills/*}"                                  # …/<plugin>/<version>
    newest="$(ls -1d "${plugdir%/*}"/*/ 2>/dev/null | sort -V | tail -1)"
    newest="${newest%/}"
    if [ ! -d "$dest" ] || { [ -n "$newest" ] && [ "$plugdir" != "$newest" ]; }; then
      stale=$((stale+1))
    fi
  done
  if [ "$total" = 0 ]; then
    row "$dir" "$OFFM  → bin/setup-harnesses.sh"
  elif [ "$stale" = 0 ]; then
    row "$dir" "$OKM ($total link(s) current)"
  else
    row "$dir" "$BADM  $stale of $total link(s) stale → bin/setup-harnesses.sh re-points"
  fi
}
check_harness_links "$HOME/.agents/skills"
if [ -d "$HOME/.codex" ] || have_cmd codex; then
  check_harness_links "$HOME/.codex/skills"
fi

# Live REST API probe (only meaningful if Obsidian is running)
step "Live REST API probe (optional)"
if [ -f "$DATA" ]; then
  KEY="$(node -e 'try{process.stdout.write(require(process.argv[1]).apiKey||"")}catch(e){}' "$DATA" 2>/dev/null)"
  # Probe an AUTHENTICATED endpoint (/vault/) — the root / is unauthenticated and
  # 200s with any/no key, so it can't validate the handshake.
  if [ -n "$KEY" ] && curl -fsk -m 3 -H "Authorization: Bearer $KEY" https://127.0.0.1:27124/vault/ >/dev/null 2>&1; then
    row "https://127.0.0.1:27124/vault/" "$OKM (authenticated — key valid)"
  else
    row "https://127.0.0.1:27124/vault/" "$BADM  (no auth: Obsidian closed, plugin off, or key mismatch)"
  fi
fi

step "Doctor complete"
info "The bin/*.sh remediation paths above are direct doors for git-clone installs."
info "Marketplace install? Use the skills — /secondbrain re-runs any setup step and"
info "/secondbrain-doctor drives repairs; both run these scripts for you."
exit 0
