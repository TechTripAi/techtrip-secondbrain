#!/usr/bin/env bash
# techtrip-secondbrain — install the claude-obsidian plugin from ITS OWN marketplace.
#
# claude-obsidian is by AgriciDaniel (MIT):
#   profile: https://github.com/AgriciDaniel
#   repo:    https://github.com/AgriciDaniel/claude-obsidian
# We do NOT vendor or fork his work — we pull it at install time so users always get
# his upstream updates. See ATTRIBUTION.md.
#
# Idempotent + interactive. Usage: bash bin/setup-claude-obsidian.sh [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"

step "claude-obsidian plugin — by AgriciDaniel (https://github.com/AgriciDaniel/claude-obsidian)"
have_cmd claude || die "Claude Code CLI not found. Install Claude Code first (prerequisite)."

ID="$(manifest_get 'm.claudePlugins[0].id')"
MP="$(manifest_get 'm.claudePlugins[0].marketplace')"
SLUG="$(manifest_get 'm.claudePlugins[0].slug')"
TESTED="$(manifest_get 'm.claudePlugins[0].testedVersion')"

# Compare installed vs tested version and warn (the CLI can't pin versions).
version_notice() {
  local have; have="$(claude_obsidian_installed_version 2>/dev/null || true)"
  if [ -n "$have" ] && [ -n "$TESTED" ] && [ "$have" != "$TESTED" ]; then
    warn "Installed claude-obsidian is v$have; techtrip-secondbrain was tested against v$TESTED."
    warn "If the scaffold misbehaves, that version drift is the first thing to suspect."
  elif [ -n "$have" ]; then
    info "claude-obsidian v$have (matches tested v$TESTED)."
  fi
}

if claude plugin list 2>/dev/null | grep -q "$ID"; then
  ok "$ID already installed"; version_notice; exit 0
fi

if confirm "Add marketplace '$MP' and install '$SLUG' ?"; then
  run "Adding marketplace $MP" -- claude plugin marketplace add "$MP" || \
    info "marketplace add returned non-zero (may already be added) — continuing"
  run "Installing $SLUG" -- claude plugin install "$SLUG"
  ok "$ID installed"
  version_notice
  info "Reload/restart Claude Code so the plugin's skills + hooks activate."
else
  warn "Skipped claude-obsidian install. The vault runtime (skills/hooks) won't exist without it."
fi
