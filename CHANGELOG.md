# Changelog

All notable changes to `techtrip-secondbrain` are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.1] — 2026-07-13

### Fixed
- **Marketplace installs never got cross-harness links created or re-pointed.**
  `setup-harnesses.sh` was only invoked by `bin/update.sh` — a script marketplace
  users don't have — so the documented `/secondbrain` setup/update flow skipped it
  entirely: Cursor/Codex symlinks were never created at setup, and after a
  `claude plugin update` any existing links kept serving the old cached version.
  Self-healing, doctor-first fix:
  - The `secondbrain` skill and command gained a **harnesses step** (after optional
    features, before doctor) — a `/secondbrain` re-run after a plugin update now
    re-points the links, which is the marketplace users' update path.
  - `bin/doctor.sh` gained a report-only **"Cross-harness skill links"** section:
    `off` when never set up (informational), **stale** when a link's cache target
    was pruned or a newer plugin version is installed.
  - The `secondbrain-doctor` skill self-heals a stale row in-session by running
    `setup-harnesses.sh` and re-checking.

### Added
- `/brain-dump` gained **Section 5 — Research a topic (autoresearch)**: teaches
  that `/autoresearch` takes a *topic, not a source*, shows a standalone research
  prompt, and the two-step "research a source" pattern (ingest the source first,
  then autoresearch the topic it raised, so the researched pages cross-link to it).
  Sections 5–9 renumbered to 6–10; the optional-features standing reference is now
  **Section 9** (was §8). Doc-only release — no script, manifest, or setup changes;
  delivered to every harness by the normal update path (`bin/update.sh` re-runs
  `setup-harnesses.sh`, whose `ln -sfn` re-points the Cursor/Codex/`~/.agents`
  skill symlinks at the new plugin version).

## [0.2.0] — 2026-07-11

### Fixed
- **`bin/update.sh` never actually updated either plugin.**
  `claude plugin update <name>` fails with "Plugin not found" unless given the
  full `name@marketplace` spec — the failure was masked by the script's
  continue-on-warn. update.sh now reads the exact spec off `claude plugin list`.
  Likewise, `setup-claude-obsidian.sh` treated "already on the fork" as done and
  exited without checking for a newer version; it now offers a confirm-gated
  in-place `claude plugin update` of the fork slug.

### Added
- **Stale upstream-marketplace cleanup.** After migrating to the fork (or on any
  later run once already on it), `setup-claude-obsidian.sh` detects the upstream
  `agricidaniel-claude-obsidian` marketplace registration lingering with no
  plugin installed from it and offers a confirm-gated
  `claude plugin marketplace remove` — preventing a future bare
  `claude plugin install claude-obsidian` from resolving to upstream's broken
  build. Never removes a marketplace that still serves an installed plugin.

### Removed
- **Syncthing support dropped entirely — git is the only sync path.** The optional
  feature, its `setup-features.sh` branch, the doctor row, and the
  primary/secondary two-machine model are gone; a second machine is now a plain
  `git clone` with pull-before / push-after under the single-writer rule.
  `bin/setup-sync.sh` is git-only; if the vault still has the `.stignore` an
  earlier release wrote, it offers a confirm-gated removal of that file only —
  the Syncthing install itself is external software the user may rely on for
  other purposes, so it is never stopped or uninstalled (the script prints the
  manual commands instead). Rationale: a background network daemon,
  per-device pairing, and `.sync-conflict` copies were standing complexity that
  real-time mirroring doesn't earn in a single-writer workflow — and it forced a
  shared REST API key across machines, which git-only removes.

### Changed
- **Optional features are now asked inline during setup, with tiered consent.**
  `/secondbrain` no longer defers features to "run `setup-features.sh` later" — it
  asks about each one during setup and drives `bin/setup-features.sh <vault>
  <feature>` per answer. The tiers (declared in `manifest.json → optionalFeatures`):
  - **YouTube (`yt-dlp`)** — `defaultEnabled: true`: a harmless passive CLI (no
    daemon, no credentials, no data egress), so its prompt defaults to **yes**
    (new `confirm_yes()` in `scripts/common.sh`; Enter installs, `n` skips).
  - **NotebookLM** — explicit opt-in with a `consentNote` printed before a
    default-no confirm (data egress to Google + interactive OAuth).
- `/brain-dump` gained **Section 8 — Optional features on/off**: the standing,
  re-runnable reference for checking (`/secondbrain-doctor`), enabling
  (`/secondbrain`), and disabling (`brew`/`uv` uninstall) each feature; the tour now
  reminds users up front and at close that it exists for exactly this.

## [0.1.0] — unreleased

Initial MVP: bootstrap a generic, out-of-the-box LLM Wiki second brain on macOS.

### Added
- Claude Code plugin packaging (`.claude-plugin/plugin.json` + `marketplace.json`).
- `manifest.json` — single source of truth for binaries, apps, plugins, MCP server,
  and skills.
- `bin/` interactive, idempotent setup scripts: `precheck`, `setup-deps`,
  `setup-obsidian`, `setup-claude-obsidian`, `setup-vault`, `setup-mcp`, `setup-sync`,
  `doctor`. All support `--dry-run` and `--yes`.
- `scripts/common.sh` (logging, confirm gate, dry-run, manifest reader, vault-path
  state) and `scripts/install-obsidian-plugin.sh` (GitHub-release plugin installer).
- `secondbrain` orchestrator skill + `/secondbrain` command + phase reference docs.
- Ported `yt-fetch` and `notebooklm-ingest` source skills.
- Generic starter canvas; git + optional Syncthing sync setup.

### Notes
- Bootstraps and depends on `claude-obsidian` (AgriciDaniel), pulled from its own
  marketplace at install time — never vendored.
- macOS only; produces a generic empty scaffold (no personal content).
