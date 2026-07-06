#!/usr/bin/env bash
# techtrip-secondbrain — enable OPTIONAL features on demand.
#
# The base second brain ships lean: YouTube transcripts (yt-fetch), NotebookLM
# synthesis (notebooklm-ingest), and Syncthing real-time sync are all OFF by
# default. Their *skills* always ship with the plugin; this script installs the
# runtime each one needs, so you can turn features on now — or come back and add
# one later. Driven by manifest.json → optionalFeatures.
#
# Idempotent + interactive: already-enabled features report green and mutate
# nothing. Re-run any time to add a feature.
#
# Usage:
#   bash bin/setup-features.sh [/path/to/vault] [--yes] [--dry-run]
#   bash bin/setup-features.sh [/path/to/vault] youtube|notebooklm|syncthing
set -euo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BIN_DIR/../scripts/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

# Split positional args into an optional vault path and an optional feature id.
VAULT_ARG=""; ONLY=""
for a in "$@"; do
  case "$a" in
    youtube|notebooklm|syncthing) ONLY="$a" ;;
    *) VAULT_ARG="$a" ;;
  esac
done
VAULT="$(default_vault_path "$VAULT_ARG")"

step "Optional features"
info "Vault: $VAULT"
[ -n "$ONLY" ] && info "Targeting only: $ONLY"
info "Each feature is off until enabled here. Skills ship regardless; this installs"
info "the runtime they need. Safe to re-run to add a feature later."

# ── youtube (yt-fetch → yt-dlp) ──────────────────────────────────────────────
feature_youtube() {
  step "YouTube transcripts (yt-fetch)"
  if have_cmd yt-dlp; then ok "yt-dlp already installed — yt-fetch is ready"; return; fi
  local install; install="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="youtube").install')"
  info "yt-fetch needs yt-dlp to pull a video's transcript + metadata."
  have_cmd brew || { warn "Homebrew required for '$install'. Run bin/setup-deps.sh first."; return; }
  if confirm "Enable YouTube — run '$install'?"; then
    run "Installing yt-dlp" -- bash -c "$install"
    ok "yt-fetch ready. Try: 'ingest this youtube url <link>'"
  else info "Skipped YouTube. Enable later: bash bin/setup-features.sh youtube"; fi
}

# ── notebooklm (notebooklm-ingest → notebooklm-py + login) ───────────────────
feature_notebooklm() {
  step "NotebookLM synthesis (notebooklm-ingest)"
  local install login probe
  install="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").install')"
  login="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").login')"
  probe="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").authProbe')"

  # uv is required (also powers the MCP server) — it is NOT optional.
  if ! have_cmd uv; then
    warn "uv is missing — it's a core dependency. Run bin/setup-deps.sh, then re-run this."
    return
  fi

  if ! have_cmd notebooklm; then
    info "notebooklm-ingest uses the unofficial notebooklm-py CLI."
    if confirm "Install the NotebookLM CLI — run '$install'?"; then
      run "Installing notebooklm-py" -- bash -c "$install"
    else info "Skipped NotebookLM. Enable later: bash bin/setup-features.sh notebooklm"; return; fi
  else
    ok "notebooklm CLI already installed"
  fi

  # Auth is a one-time interactive OAuth we can't run unattended.
  if [ "$TSB_DRY_RUN" = "1" ]; then info "[dry-run] would check auth with: $probe"; return; fi
  if have_cmd notebooklm && $probe >/dev/null 2>&1; then
    ok "NotebookLM already authenticated — notebooklm-ingest is ready"
  else
    warn "NotebookLM not authenticated yet."
    info "Run this one-time interactive login (opens a Google OAuth flow):"
    info "  $login"
    if [ "$TSB_ASSUME_YES" != "1" ] && confirm "Run '$login' now (interactive)?"; then
      $login </dev/tty || warn "Login did not complete. Re-run '$login' when ready."
    fi
  fi
}

# ── syncthing (delegate to setup-sync.sh, which owns the .stignore logic) ─────
feature_syncthing() {
  step "Syncthing real-time LAN sync"
  if have_cmd syncthing && [ -f "$VAULT/.stignore" ]; then
    ok "Syncthing installed and vault has a .stignore — looks configured"
    info "Re-run bin/setup-sync.sh to re-check pairing/.stignore, or open http://127.0.0.1:8384"
    return
  fi
  info "Handing off to setup-sync.sh, which installs Syncthing and writes the"
  info "vault .stignore (keeps Syncthing and git from fighting). Answer 'yes' at"
  info "its Syncthing prompt."
  # setup-sync.sh is idempotent: an existing git repo reports green, then it
  # prompts for Syncthing. Flags are exported, so --yes/--dry-run carry through.
  run "Running setup-sync.sh" -- bash "$BIN_DIR/setup-sync.sh" "$VAULT"
}

if [ -z "$ONLY" ] || [ "$ONLY" = youtube ];    then feature_youtube;    fi
if [ -z "$ONLY" ] || [ "$ONLY" = notebooklm ]; then feature_notebooklm; fi
if [ -z "$ONLY" ] || [ "$ONLY" = syncthing ];  then feature_syncthing;  fi

step "Optional features complete"
info "Add another any time: bash bin/setup-features.sh [youtube|notebooklm|syncthing]"
