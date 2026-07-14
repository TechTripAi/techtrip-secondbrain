#!/usr/bin/env bash
# techtrip-secondbrain — enable OPTIONAL features on demand.
#
# The base second brain ships lean. Their *skills* always ship with the plugin;
# this script installs the runtime each one needs, so you can turn features on
# now — or come back and add one later. Driven by manifest.json → optionalFeatures,
# which splits them in two:
#   - defaultEnabled:true  (YouTube/yt-dlp, Voice/whisperkit-cli) — harmless
#     freebies: passive CLIs, no daemon, no credentials, no data egress. Prompt
#     defaults to YES; Enter installs, 'n' skips.
#   - consentNote          (NotebookLM) — needs an explicit opt-in (data egress
#     to Google). The note is printed before a default-NO confirm.
# The secondbrain skill asks about each feature inline during setup and drives
# this script per answer — nothing is deferred to "run it later" by default.
#
# Idempotent + interactive: already-enabled features report green and mutate
# nothing. Re-run any time to add a feature.
#
# Usage:
#   bash bin/setup-features.sh [/path/to/vault] [--yes] [--dry-run]
#   bash bin/setup-features.sh [/path/to/vault] youtube|voice|notebooklm
set -euo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BIN_DIR/../scripts/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}
require_macos

# Split positional args into an optional vault path and an optional feature id.
VAULT_ARG=""; ONLY=""
for a in "$@"; do
  case "$a" in
    youtube|voice|notebooklm) ONLY="$a" ;;
    *) VAULT_ARG="$a" ;;
  esac
done
VAULT="$(default_vault_path "$VAULT_ARG")"

step "Optional features"
info "Vault: $VAULT"
[ -n "$ONLY" ] && info "Targeting only: $ONLY"
info "Skills ship regardless; this installs the runtime they need. Safe to re-run"
info "to add a feature later. YouTube is a default-yes freebie; NotebookLM needs"
info "an explicit opt-in (you'll see why before the prompt)."

# ── youtube (yt-fetch → yt-dlp) — the default-yes freebie ────────────────────
feature_youtube() {
  step "YouTube transcripts (yt-fetch)"
  if have_cmd yt-dlp; then ok "yt-dlp already installed — yt-fetch is ready"; return; fi
  local install; install="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="youtube").install')"
  info "yt-fetch needs yt-dlp to pull a video's transcript + metadata."
  info "It's a passive CLI binary — no daemon, no credentials — so this defaults to yes."
  have_cmd brew || { warn "Homebrew required for '$install'. Run bin/setup-deps.sh first."; return; }
  if confirm_yes "Enable YouTube — run '$install'?"; then
    manifest_argv "brew" "$install"
    run "Installing yt-dlp" -- "${TSB_CMD_ARGV[@]}"
    ok "yt-fetch ready. Try: 'ingest this youtube url <link>'"
  else info "Skipped YouTube. Enable later: bash bin/setup-features.sh youtube"; fi
}

# ── voice (voice-fetch → whisperkit-cli) — the other default-yes freebie ─────
# After the binary lands, offer a one-time model warm-up: transcribing a
# 1-second generated clip pulls the CoreML model from Hugging Face (inbound
# public files only — the audio itself never leaves the machine) AND proves the
# whole pipeline before setup ends. Skippable; declining just defers the same
# download to the first real transcription. Warm-up failure is a warn, never a
# setup failure.
voice_warmup() {
  local cache="$HOME/Documents/huggingface/models/argmaxinc/whisperkit-coreml"
  if [ -d "$cache" ] && [ -n "$(ls -A "$cache" 2>/dev/null)" ]; then
    ok "transcription model already cached — voice-fetch is fully local now"
    return 0
  fi
  info "One-time model download: WhisperKit fetches its CoreML model from Hugging"
  info "Face on first use (inbound files only — your audio never leaves the Mac)."
  info "Doing it now takes about a minute and verifies the whole pipeline; skipping"
  info "just means your first real transcription does the download instead."
  if ! confirm_yes "Download the transcription model now (one-time)?"; then
    info "Skipped. The first transcription will download it automatically."
    return 0
  fi
  if [ "$TSB_DRY_RUN" = 1 ]; then
    info "[dry-run] would generate a 1s clip via 'say' and transcribe it to pull the model"
    return 0
  fi
  local clipdir clip warm_ok=0
  clipdir="$(mktemp -d)"; clip="$clipdir/warmup.m4a"
  if say -o "$clip" "warm up" 2>/dev/null && whisperkit-cli transcribe --audio-path "$clip" >/dev/null 2>&1; then
    warm_ok=1
  fi
  rm -rf "$clipdir"
  if [ "$warm_ok" = 1 ]; then
    ok "model cached + pipeline verified — voice-fetch is fully local now"
  else
    warn "Warm-up didn't complete (offline? interrupted download?). No harm done —"
    warn "the model will download automatically at your first transcription."
  fi
}

feature_voice() {
  step "Voice memos / audio transcription (voice-fetch)"
  if have_cmd whisperkit-cli; then
    ok "whisperkit-cli already installed — voice-fetch is ready"
    voice_warmup
    return
  fi
  local install; install="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="voice").install')"
  info "voice-fetch transcribes local audio (Voice Memos, mp3, wav, …) on-device"
  info "via WhisperKit (CoreML/Neural Engine) — no cloud, no credentials, no daemon."
  have_cmd brew || { warn "Homebrew required for '$install'. Run bin/setup-deps.sh first."; return; }
  if confirm_yes "Enable voice/audio — run '$install'?"; then
    manifest_argv "brew" "$install"
    run "Installing whisperkit-cli" -- "${TSB_CMD_ARGV[@]}"
    voice_warmup
    ok "voice-fetch ready. Try: 'transcribe <audio-file>' or '/voice-fetch <audio-file>'"
  else info "Skipped voice/audio. Enable later: bash bin/setup-features.sh voice"; fi
}

# ── notebooklm (notebooklm-ingest → notebooklm-py + login) — explicit opt-in ──
feature_notebooklm() {
  step "NotebookLM synthesis (notebooklm-ingest)"
  local install login probe consent
  install="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").install')"
  login="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").login')"
  probe="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").authProbe')"
  consent="$(manifest_get 'm.optionalFeatures.find(f=>f.id==="notebooklm").consentNote')"

  # uv is required (also powers the MCP server) — it is NOT optional.
  if ! have_cmd uv; then
    warn "uv is missing — it's a core dependency. Run bin/setup-deps.sh, then re-run this."
    return
  fi

  if ! have_cmd notebooklm; then
    info "notebooklm-ingest uses the unofficial notebooklm-py CLI."
    warn "Heads up: $consent"
    if confirm "Install the NotebookLM CLI — run '$install'?"; then
      manifest_argv "uv" "$install"
      run "Installing notebooklm-py" -- "${TSB_CMD_ARGV[@]}"
    else info "Skipped NotebookLM. Enable later: bash bin/setup-features.sh notebooklm"; return; fi
  else
    ok "notebooklm CLI already installed"
  fi

  # Auth is a one-time interactive OAuth we can't run unattended.
  if [ "$TSB_DRY_RUN" = "1" ]; then info "[dry-run] would check auth with: $probe"; return; fi
  manifest_argv "notebooklm" "$probe"
  if have_cmd notebooklm && "${TSB_CMD_ARGV[@]}" >/dev/null 2>&1; then
    ok "NotebookLM already authenticated — notebooklm-ingest is ready"
  else
    warn "NotebookLM not authenticated yet."
    info "Run this one-time interactive login (opens a Google OAuth flow):"
    info "  $login"
    if [ "$TSB_ASSUME_YES" != "1" ] && confirm "Run '$login' now (interactive)?"; then
      manifest_argv "notebooklm" "$login"
      "${TSB_CMD_ARGV[@]}" </dev/tty || warn "Login did not complete. Re-run '$login' when ready."
    fi
  fi
}

if [ -z "$ONLY" ] || [ "$ONLY" = youtube ];    then feature_youtube;    fi
if [ -z "$ONLY" ] || [ "$ONLY" = voice ];      then feature_voice;      fi
if [ -z "$ONLY" ] || [ "$ONLY" = notebooklm ]; then feature_notebooklm; fi

step "Optional features complete"
info "Add another any time: bash bin/setup-features.sh [youtube|voice|notebooklm]"
