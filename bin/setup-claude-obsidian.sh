#!/usr/bin/env bash
# techtrip-secondbrain — install the claude-obsidian plugin from TechTrip's maintained fork.
#
# claude-obsidian is by AgriciDaniel (MIT):
#   profile:  https://github.com/AgriciDaniel
#   upstream: https://github.com/AgriciDaniel/claude-obsidian
#   fork:     https://github.com/TechTripAi/claude-obsidian  (bug-fixes-only; tracks upstream)
# We do NOT vendor or copy his work into this repo. We install from a lightly-patched
# fork (fixes upstream is backlogged on, e.g. issue #116) so users get a working plugin;
# those fixes are filed upstream too. Marketplace/slug come from manifest.json. See ATTRIBUTION.md.
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

# `claude plugin list` prints the full `id@marketplace` slug, so we can tell the fork
# apart from an upstream (or any other) install. (`|| true` guards `set -e`: grep exits
# non-zero when nothing matches.)
INSTALLED_SLUG="$(claude plugin list 2>/dev/null | grep -oE "${ID}@[a-z0-9._-]+" | head -1 || true)"

if [ "$INSTALLED_SLUG" = "$SLUG" ]; then
  ok "$SLUG already installed (maintained fork)"; version_notice; exit 0
fi

if [ -n "$INSTALLED_SLUG" ]; then
  # Installed, but from a different marketplace (e.g. upstream agricidaniel). Migrate so
  # the machine gets the fork's bug fixes instead of silently keeping the broken copy.
  warn "claude-obsidian is installed as '$INSTALLED_SLUG', not the maintained fork ('$SLUG')."
  info "The fork carries fixes upstream is backlogged on (e.g. the invalid SessionStart hook, issue #116)."
  if confirm "Migrate to the fork (uninstall '$INSTALLED_SLUG', then install '$SLUG')?"; then
    run "Uninstalling $INSTALLED_SLUG" -- claude plugin uninstall "$INSTALLED_SLUG" \
      || warn "uninstall returned non-zero — continuing"
    run "Adding marketplace $MP" -- claude plugin marketplace add "$MP" \
      || info "marketplace add returned non-zero (may already be added) — continuing"
    run "Installing $SLUG" -- claude plugin install "$SLUG"
    ok "Migrated to $SLUG"; version_notice
    info "Reload/restart Claude Code so the fork's skills + hooks activate."
  else
    warn "Kept '$INSTALLED_SLUG'. You'll keep hitting already-fixed bugs until you migrate."
  fi
  exit 0
fi

# Nothing installed → fresh install from the fork.
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
