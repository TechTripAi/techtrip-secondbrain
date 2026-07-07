# Changelog

All notable changes to `techtrip-secondbrain` are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed
- **Optional features are now asked inline during setup, with tiered consent.**
  `/secondbrain` no longer defers features to "run `setup-features.sh` later" — it
  asks about each one during setup and drives `bin/setup-features.sh <vault>
  <feature>` per answer. The tiers (declared in `manifest.json → optionalFeatures`):
  - **YouTube (`yt-dlp`)** — `defaultEnabled: true`: a harmless passive CLI (no
    daemon, no credentials, no data egress), so its prompt defaults to **yes**
    (new `confirm_yes()` in `scripts/common.sh`; Enter installs, `n` skips).
  - **NotebookLM** and **Syncthing** — explicit opt-in with a `consentNote` printed
    before a default-no confirm (data egress to Google + interactive OAuth;
    background network daemon that only pays off with a second Mac).
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
