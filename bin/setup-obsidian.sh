#!/usr/bin/env bash
# techtrip-secondbrain — install the Obsidian desktop app (brew cask).
# Idempotent + interactive. Usage: bash bin/setup-obsidian.sh [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}
require_macos

step "Obsidian desktop app"
CHECK="$(manifest_get 'm.apps[0].check')"
CASK="$(manifest_get 'm.apps[0].cask')"

if [ -e "$CHECK" ]; then ok "Obsidian already installed ($CHECK)"; exit 0; fi
have_cmd brew || die "Homebrew required. Run bin/setup-deps.sh first."

# Prefer a manual install? The DMG from https://obsidian.md/download works
# too — the app-bundle probe passes either way.
info "Manual alternative: download from https://obsidian.md/download"
offer_install "Obsidian" "brew" "brew install --cask $CASK" "path:$CHECK" skip \
  || warn "Skipped Obsidian. Install it before setup-vault/setup-mcp; precheck will flag it."
