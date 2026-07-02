#!/usr/bin/env bash
# techtrip-secondbrain — install CLI dependencies via Homebrew (per manifest.json).
# Idempotent + interactive. Usage: bash bin/setup-deps.sh [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

step "Dependencies (Homebrew)"
if ! have_cmd brew; then
  warn "Homebrew is not installed. It's the base for every other install."
  info "Install it once with the official one-liner from https://brew.sh :"
  info '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  die "Re-run this script after Homebrew is installed."
fi
ok "Homebrew present"

# Install each missing manifest binary via its declared brew command.
while IFS=$'\t' read -r cmd label install; do
  [ -n "$cmd" ] || continue
  [ "$cmd" = "brew" ] && continue
  if have_cmd "$cmd"; then ok "$label ($cmd) already installed"; continue; fi
  # Only auto-run installs that are brew commands; anything else we just surface.
  case "$install" in
    "brew install "*)
      if confirm "Install $label with: $install ?"; then
        run "Installing $label" -- bash -c "$install"
        ok "$label installed"
      else warn "Skipped $label — some features will not work."; fi ;;
    *) warn "$label ($cmd) missing; install manually: $install" ;;
  esac
done < <(manifest_get 'm.binaries.map(b=>[b.cmd,b.label||b.cmd,b.install||""].join("\t")).join("\n")')

ok "Dependency check complete"
