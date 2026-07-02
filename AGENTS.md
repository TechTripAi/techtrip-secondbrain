# AGENTS.md

Guidance for AI coding agents (Cursor, Codex, etc.) working in this repository.

## What this is

**`techtrip-secondbrain`** is a Claude Code plugin that bootstraps a generic,
out-of-the-box LLM Wiki "second brain" on a fresh **macOS** machine. It is an
**orchestrator / enhancement layer, not a fork**: the actual wiki runtime is
[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) by AgriciDaniel
(MIT), which this project **installs from his marketplace at setup time** and never
vendors, copies, or modifies. `techtrip-secondbrain` only fills the gaps that plugin
leaves manual: installing Obsidian + community plugins, wiring/repairing the Obsidian
MCP server, git + optional Syncthing sync, and the ported source skills.

## Architecture

- **`manifest.json`** — single source of truth (binaries, apps, community plugins,
  claude-obsidian entry, MCP server, skills). `precheck` audits against it; every
  `setup-*.sh` reads it. Change what gets installed here, not in the scripts.
- **`bin/*.sh`** — idempotent setup steps run in order:
  `precheck → setup-deps → setup-obsidian → setup-claude-obsidian → setup-vault → setup-mcp → setup-sync → doctor` (+ `repair-mcp`)
- **`scripts/common.sh`** — sourced by every script: logging, `confirm()`, `run()`,
  dry-run, `manifest_get`, vault-path state, claude-obsidian locate/version helpers.
- **`scripts/install-obsidian-plugin.sh`** — installs a community plugin by downloading
  GitHub-release assets into `<vault>/.obsidian/plugins/<id>/`.
- **`skills/`** — `secondbrain` (setup orchestrator) + `secondbrain-doctor` (integrity
  check + MCP repair) + ported `yt-fetch` / `notebooklm-ingest`.

## Conventions

- **Source `common.sh`** in every `bin/`/`scripts/` file. New scripts must begin with
  `source .../scripts/common.sh` then `parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"`.
- **Respect `--dry-run` and `--yes`**: any mutation must go through `run "<desc>" -- <cmd>`
  (honors dry-run) or be guarded by `[ "$TSB_DRY_RUN" = 1 ]`. Flags are exported so
  child scripts inherit them — do not break that.
- **Idempotent**: detect already-present state and skip. A second run must mutate
  nothing and report green.
- **`TSB_` is the env-var prefix** — never reintroduce the old `CSB_` prefix.
- **JSON is read/written with `node`** (a hard dependency), not `jq` or `sed`.
- **`manifest_get`** newline-terminates list output so `while read` keeps the last
  line — preserve that behavior when editing it.
- **Never write into `~/.claude/plugins/cache/**`** — install claude-obsidian via the
  official CLI, read/execute it, but never patch it.
- **MCP is machine-global**: user scope in `~/.claude.json`, one server, port 27124,
  one key. Design assumes one vault per machine.
- **Auth probes must hit `/vault/`** (authenticated), not `/` (public, 200s with any
  key) — otherwise the key handshake is not validated.
- **Attribution**: wherever code references claude-obsidian's repo, credit AgriciDaniel
  with the URL. Never ship his `WIKI.md`/`CLAUDE.md`/config — those arrive via his plugin.

## Validate Changes

```bash
for f in bin/*.sh scripts/*.sh; do bash -n "$f"; done  # syntax check
bash bin/precheck.sh                                    # report-only audit
bash bin/setup-vault.sh ~/llm-wiki-test --dry-run --yes # dry-run, no mutations
bash bin/setup-vault.sh ~/llm-wiki-test --yes && bash bin/doctor.sh ~/llm-wiki-test
rm -rf ~/llm-wiki-test                                  # clean up
```

A real run only downloads into a throwaway vault and does not touch global
`~/.claude.json` when the `obsidian` MCP server is already registered.

## Scope & Constraints

- macOS-only MVP; generic empty scaffold (no personal content).
- Deferred: Windows/Linux, cloning personal content, `pocket-sync`,
  auto-installing Claude Code/Homebrew, multi-vault-per-machine.
- License: **FSL-1.1-MIT** — source-available, converts to MIT 2 years after each
  release. Copyright 2026 Terry Trippany (Try AI Solutions).
- Owner/repo: `TechTripAi/techtrip-secondbrain`.
