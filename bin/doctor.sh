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

# Origination projects (report-only; content decisions — graduate vs archive —
# are the user's, so there is no auto-repair; see the new-idea skill). A project
# is 'stale' when project.md says status: active but nothing in its folder was
# touched in 30+ days, and 'unindexed' when it was never registered in
# wiki/index.md (the agent-side step after /new-idea scaffolds).
if [ -d "$VAULT/wiki/projects" ] && ls -1 "$VAULT/wiki/projects"/*/ >/dev/null 2>&1; then
  step "Origination projects (wiki/projects/)"
  for pdir in "$VAULT/wiki/projects"/*/; do
    slug="$(basename "$pdir")"
    status="$(awk -F': *' '/^status:/{gsub(/["\047]/,"",$2);print $2;exit}' "$pdir/project.md" 2>/dev/null)"
    issues=""
    if [ "$status" = "active" ] || [ -z "$status" ]; then
      recent="$(find "$pdir" -type f -mtime -30 -print -quit 2>/dev/null)"
      [ -z "$recent" ] && issues="stale (30+ days untouched) — graduate or archive (origination-workflow)"
    fi
    if [ -f "$VAULT/wiki/index.md" ] && ! grep -qF "projects/$slug/" "$VAULT/wiki/index.md" 2>/dev/null; then
      issues="${issues:+$issues; }not in wiki/index.md — register it (see the new-idea skill)"
    fi
    if [ -n "$issues" ]; then
      row "$slug" "$BADM  $issues"
    else
      row "$slug" "$OKM${status:+ ($status)}"
    fi
  done
fi

# Wiki content maintenance (report-only; every remedy is a content decision the
# user makes through the fork's skills — wiki-lint, wiki-delete, wiki-archive —
# or a deliberate edit, so there is no auto-repair here). Four signals:
# - orphaned provenance: a source page's raw_file:/sources: pointer targets a
#   .raw/ file that was deleted or moved by hand (silent rot; nothing else
#   surfaces it between lint runs)
# - .raw pile-up: inbox files never recorded in .raw/.manifest.json — pending
#   work, not clutter; ingest or deliberately archive them
# - aging pages: updated: older than 90 days (evergreen/archived/retracted and
#   meta/fold/archive paths exempt) — YYYY-MM-DD compares correctly as strings
# - archive tiers: informational presence of the two warm archive folders
if [ -d "$VAULT/wiki" ]; then
  step "Wiki maintenance (content, report-only)"
  cutoff="$(date -v-90d +%F 2>/dev/null || true)"
  orphaned=0; aging=0
  while IFS= read -r -d '' page; do
    case "$page" in
      */wiki/folds/*|*/wiki/meta/*|*/wiki/archives/*) continue ;;
    esac
    case "$(basename "$page")" in
      index.md|_index.md|log.md|hot.md|overview.md|dashboard.md) continue ;;
    esac
    # Frontmatter block only (between the first pair of --- fences).
    fm="$(awk '/^---$/{n++;next} n==1{print} n>=2{exit}' "$page" 2>/dev/null)"
    [ -n "$fm" ] || continue
    # Provenance pointers: raw_file: scalar plus any "[[.raw/...]]" sources entry.
    while IFS= read -r raw; do
      [ -n "$raw" ] || continue
      if [ ! -e "$VAULT/$raw" ]; then
        orphaned=$((orphaned+1))
        [ "$orphaned" -le 3 ] && row "  $(basename "$page" .md)" "$BADM  $raw missing (deleted? archived without repointing?)"
      fi
    done < <(printf '%s\n' "$fm" | awk -F': *' '/^raw_file:/{gsub(/["\047]/,"",$2);print $2}
                                                /\[\[\.raw\//{sub(/.*\[\[/,"");sub(/\]\].*/,"");print}')
    # Aging: updated: past the cutoff, unless the status opts the page out.
    if [ -n "$cutoff" ]; then
      status="$(printf '%s\n' "$fm" | awk -F': *' '/^status:/{gsub(/["\047]/,"",$2);print $2;exit}')"
      updated="$(printf '%s\n' "$fm" | awk -F': *' '/^updated:/{gsub(/["\047]/,"",$2);print $2;exit}')"
      case "$status" in evergreen|archived|retracted) ;; *)
        [ -n "$updated" ] && [ "$updated" \< "$cutoff" ] && aging=$((aging+1)) ;;
      esac
    fi
  done < <(find "$VAULT/wiki" -type f -name '*.md' -print0 2>/dev/null)
  if [ "$orphaned" = 0 ]; then row "orphaned provenance" "$OKM"
  else row "orphaned provenance" "$BADM  $orphaned pointer(s) → 'lint the wiki' lists them all"; fi
  if [ "$aging" = 0 ]; then row "aging pages (90+ days)" "$OKM"
  else row "aging pages (90+ days)" "$BADM  $aging page(s) untouched → 'lint the wiki' groups them by status"; fi

  # .raw pile-up: manifest keys once via node, then a pure-bash membership check.
  if [ -d "$VAULT/.raw" ]; then
    ingested="$(node -e '
      try{const m=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      process.stdout.write(Object.keys(m.sources||{}).join("\n"))}catch(e){}
    ' "$VAULT/.raw/.manifest.json" 2>/dev/null)"
    pending=0; examples=""
    while IFS= read -r -d '' f; do
      rel="${f#"$VAULT"/}"
      printf '%s\n' "$ingested" | grep -qxF "$rel" && continue
      pending=$((pending+1))
      [ "$pending" -le 3 ] && examples="${examples:+$examples, }${rel#.raw/}"
    done < <(find "$VAULT/.raw" -type f ! -name '.*' -print0 2>/dev/null)
    if [ "$pending" = 0 ]; then row ".raw/ inbox" "$OKM (everything ingested)"
    else row ".raw/ inbox" "$BADM  $pending file(s) never ingested: $examples${pending:+ }— ingest or archive deliberately"; fi
  fi

  # Archive tiers (informational, never a failure).
  for tier in ".archive" "wiki/archives"; do
    if [ -d "$VAULT/$tier" ]; then
      n="$(find "$VAULT/$tier" -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')"
      row "$tier/" "${_C_DIM}present ($n file(s))${_C_RESET}"
    else
      row "$tier/" "${_C_DIM}not created yet (made on first archive)${_C_RESET}"
    fi
  done
fi

# DragonScale addressing (report-only). claude-obsidian's opt-in Mechanism 2 is
# feature-detected from vault files: an executable scripts/allocate-address.sh
# plus a .vault-meta/ dir (which WE create for mode/transport state) arms it,
# and every ingest then assigns address: fields from a flock-guarded counter —
# machine-local locking, so the two-machine git model can mint duplicate
# addresses and the counter file becomes merge-conflict bait. Out of scope for
# this project (see README); disarm-dragonscale.sh removes the arming files
# (consent-gated, backed up). Counter/state files without the allocator script
# are inert residue — reported dimmer, same remedy.
step "DragonScale addressing (opt-in claude-obsidian extension)"
ds_residue=""
for f in ".vault-meta/address-counter.txt" ".vault-meta/tiling-thresholds.json" ".vault-meta/legacy-pages.txt"; do
  [ -e "$VAULT/$f" ] && ds_residue=1
done
if [ -x "$VAULT/scripts/allocate-address.sh" ]; then
  row "addressing (Mechanism 2)" "$BADM  ARMED — ingest will assign addresses → bin/disarm-dragonscale.sh"
elif [ -n "$ds_residue" ]; then
  row "addressing (Mechanism 2)" "$BADM  off, but stale state files remain → bin/disarm-dragonscale.sh"
else
  row "addressing (Mechanism 2)" "$OKM not armed"
fi

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
  # JSON via node (repo convention): an exact array-membership check, not a
  # substring grep that an id embedded in another string would satisfy.
  if [ -f "$CP" ]; then
    MANIFEST="" node -e '
      try{const a=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      process.exit(Array.isArray(a)&&a.includes(process.argv[2])?0:1)}catch(e){process.exit(1)}
    ' "$CP" "$id" 2>/dev/null && enabled=1
  fi
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
  if claude plugin list 2>/dev/null | grep -qF claude-obsidian; then
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
  # Anchored to the server-name column ("obsidian: …"), not a substring match.
  claude mcp list 2>/dev/null | grep -qE '^obsidian:' \
    && row "obsidian MCP server" "$OKM" || row "obsidian MCP server" "$BADM  → bin/setup-mcp.sh"
else
  row "claude CLI" "$BADM  (install Claude Code)"
fi

# Update availability (informational — one short network probe per plugin; being
# offline skips the check, never fails it). Latest = the version field of
# .claude-plugin/plugin.json on each repo's main branch; installed = the newest
# version dir in the plugin cache.
step "Plugin updates"
remote_plugin_version() {  # <owner/repo> → version on main, or empty
  # The version string comes from the network and gets printed to the terminal —
  # sanitize it to version-ish characters so a compromised repo can't emit
  # escape sequences into the report.
  curl -fsS -m 3 "https://raw.githubusercontent.com/$1/main/.claude-plugin/plugin.json" 2>/dev/null \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const v=String(JSON.parse(s).version||"");process.stdout.write(/^[0-9A-Za-z.-]{1,32}$/.test(v)?v:"")}catch(e){}})' 2>/dev/null
}
update_row() {  # <label> <installed> <owner/repo> <how-to-update hint>
  local label="$1" inst="$2" repo="$3" hint="$4" latest
  if [ -z "$inst" ]; then
    row "$label" "${_C_DIM}not installed${_C_RESET}"
    return 0
  fi
  latest="$(remote_plugin_version "$repo")"
  if [ -z "$latest" ]; then
    row "$label" "v$inst (update check skipped — offline?)"
  elif [ "$(printf '%s\n%s\n' "$latest" "$inst" | sort -V | tail -1)" = "$inst" ]; then
    row "$label" "$OKM v$inst (latest)"
  else
    row "$label" "$BADM  v$inst → v$latest available → $hint"
  fi
}
TSB_INST="$(ls -1d "$HOME"/.claude/plugins/cache/*/techtrip-secondbrain/*/ 2>/dev/null | sort -V | tail -1)"
TSB_INST="${TSB_INST:+$(basename "$TSB_INST")}"
TSB_REPO="$(node -e 'try{process.stdout.write((require(process.argv[1]).repository||"").replace(/^https:\/\/github\.com\//,""))}catch(e){}' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null)"
[ -n "$TSB_REPO" ] && update_row "techtrip-secondbrain" "$TSB_INST" "$TSB_REPO" "see 'Updating' in the README"
CO_INST="$(claude_obsidian_installed_version 2>/dev/null || true)"
CO_REPO="$(manifest_get 'm.claudePlugins[0].marketplace')"
[ -n "$CO_REPO" ] && update_row "claude-obsidian (fork)" "$CO_INST" "$CO_REPO" "/secondbrain updates it (never 'claude plugin update' it directly)"

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

# Dead plugin-cache permission rules (report-only). Claude Code saves approved
# rules into settings.local.json with the versioned plugin-cache path baked in;
# every plugin update strands them — same root cause as stale harness links
# above. Harmless but noisy: the rules never match again, the user gets
# re-prompted, and Claude's built-in /doctor flags them as invalid.
step "Permission rules (settings.local.json)"
check_permission_rules() {
  local pf="$1" n
  if [ ! -f "$pf" ]; then
    row "${pf/#$HOME/~}" "${_C_DIM}not present${_C_RESET}"
    return 0
  fi
  n="$(stale_permission_rules "$pf" | grep -c . || true)"
  if [ "${n:-0}" = 0 ]; then
    row "${pf/#$HOME/~}" "$OKM"
  else
    row "${pf/#$HOME/~}" "$BADM  $n dead rule(s) (stranded by plugin updates) → bin/prune-permissions.sh"
  fi
}
check_permission_rules "$HOME/.claude/settings.local.json"
if [ "$VAULT/.claude/settings.local.json" != "$HOME/.claude/settings.local.json" ]; then
  check_permission_rules "$VAULT/.claude/settings.local.json"
fi

# Live REST API probe (only meaningful if Obsidian is running)
step "Live REST API probe (optional)"
if [ -f "$DATA" ]; then
  KEY="$(node -e 'try{process.stdout.write(require(process.argv[1]).apiKey||"")}catch(e){}' "$DATA" 2>/dev/null)"
  # Probe an AUTHENTICATED endpoint (/vault/) — the root / is unauthenticated and
  # 200s with any/no key, so it can't validate the handshake.
  # Key rides in a curl config via process substitution, not argv (ps-visible).
  if [ -n "$KEY" ] && curl -fsk -m 3 --config <(printf 'header = "Authorization: Bearer %s"\n' "$KEY") https://127.0.0.1:27124/vault/ >/dev/null 2>&1; then
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
