# Changelog

All notable changes to `claude-secondbrain` are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
