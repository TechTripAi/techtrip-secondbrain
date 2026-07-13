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
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

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

# If the upstream marketplace is still registered but nothing is installed from
# it, offer to unregister it. This is OUR config to manage (the install flow
# adds marketplaces), it's one-command reversible, and leaving it risks a future
# bare `claude plugin install claude-obsidian` resolving to the broken upstream
# build. We never remove a marketplace that still serves an installed plugin.
UPSTREAM="$(manifest_get 'm.claudePlugins[0].upstream')"
cleanup_upstream_marketplace() {
  local up_mp
  up_mp="$(printf '%s' "$UPSTREAM" | tr '[:upper:]/' '[:lower:]-')"
  [ "$up_mp" = "${SLUG#*@}" ] && return 0   # fork IS upstream — nothing to do
  claude plugin marketplace list 2>/dev/null | grep -q "$up_mp" || return 0
  if claude plugin list 2>/dev/null | grep -qE "@${up_mp}\b"; then
    info "Marketplace '$up_mp' still serves an installed plugin — leaving it registered."
    return 0
  fi
  info "The upstream marketplace '$up_mp' is still registered but unused. Removing it"
  info "prevents a future 'claude plugin install $ID' from resolving to upstream's"
  info "broken build instead of the fork."
  if confirm "Unregister marketplace '$up_mp'? (reversible: claude plugin marketplace add $UPSTREAM)"; then
    run "Removing marketplace $up_mp" -- claude plugin marketplace remove "$up_mp" || \
      warn "marketplace remove returned non-zero (continuing)"
  else
    info "Left registered."
  fi
}

if [ "$INSTALLED_SLUG" = "$SLUG" ]; then
  ok "$SLUG already installed (maintained fork)"
  # Already on the fork — offer an in-place update so bin/update.sh (which
  # delegates here) actually refreshes claude-obsidian instead of no-opping.
  if confirm "Check for a newer $SLUG and update in place?"; then
    run "Updating $SLUG" -- claude plugin update "$SLUG" || \
      warn "Update for $SLUG reported an issue (continuing)."
  fi
  cleanup_upstream_marketplace
  version_notice; exit 0
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
    ok "Migrated to $SLUG"
    cleanup_upstream_marketplace
    version_notice
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
