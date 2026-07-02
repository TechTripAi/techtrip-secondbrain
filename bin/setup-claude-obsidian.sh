#!/usr/bin/env bash
# claude-secondbrain — install the claude-obsidian plugin from ITS OWN marketplace.
# We do not vendor AgriciDaniel's work; we pull it at install time.
# Idempotent + interactive. Usage: bash bin/setup-claude-obsidian.sh [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${CSB_ARGS[@]:-}"

step "claude-obsidian plugin (pulled from AgriciDaniel's marketplace)"
have_cmd claude || die "Claude Code CLI not found. Install Claude Code first (prerequisite)."

ID="$(manifest_get 'm.claudePlugins[0].id')"
MP="$(manifest_get 'm.claudePlugins[0].marketplace')"
SLUG="$(manifest_get 'm.claudePlugins[0].slug')"

if claude plugin list 2>/dev/null | grep -q "$ID"; then
  ok "$ID already installed"; exit 0
fi

if confirm "Add marketplace '$MP' and install '$SLUG' ?"; then
  run "Adding marketplace $MP" -- claude plugin marketplace add "$MP" || \
    info "marketplace add returned non-zero (may already be added) — continuing"
  run "Installing $SLUG" -- claude plugin install "$SLUG"
  ok "$ID installed"
  info "Reload/restart Claude Code so the plugin's skills + hooks activate."
else
  warn "Skipped claude-obsidian install. The vault runtime (skills/hooks) won't exist without it."
fi
