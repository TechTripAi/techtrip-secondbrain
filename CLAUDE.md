# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**`techtrip-secondbrain`** is a Claude Code plugin that bootstraps a generic,
out-of-the-box LLM Wiki "second brain" on a fresh **macOS** machine. It is an
**orchestrator / enhancement layer, not a fork**: the actual wiki runtime is
[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) by AgriciDaniel
(MIT), which this project **installs from his marketplace at setup time** and never
vendors, copies, or modifies. `techtrip-secondbrain` only fills the gaps that plugin
leaves manual: installing Obsidian + community plugins, wiring/repairing the Obsidian
MCP server, git + optional Syncthing sync, and the ported source skills. See
`ATTRIBUTION.md`.

Install (same model as claude-obsidian):
```
claude plugin marketplace add TechTripAi/techtrip-secondbrain
claude plugin install techtrip-secondbrain@techtrip-secondbrain
```

## Architecture

- **`manifest.json`** — single source of truth (binaries, apps, community plugins,
  claude-obsidian entry, MCP server, skills). `precheck` audits against it; every
  `setup-*.sh` reads it. Change what gets installed here, not in the scripts.
- **`bin/*.sh`** — the setup workflow, run in order: `precheck` → `setup-deps` →
  `setup-obsidian` → `setup-claude-obsidian` → `setup-vault` → `setup-mcp` →
  `setup-sync` → `doctor` (+ `repair-mcp`). Each is **idempotent** and **interactive**.
- **`scripts/common.sh`** — sourced by everything: logging, `confirm()`, `run()`,
  dry-run, `manifest_get`, vault-path state, claude-obsidian locate/version helpers.
- **`scripts/install-obsidian-plugin.sh`** — installs a community plugin by
  downloading its GitHub-release assets into `<vault>/.obsidian/plugins/<id>/` (no
  Obsidian plugin CLI exists). Downloads are pinned to the manifest's `tag` and
  verified against its `sha256` map; a mismatch aborts the install. Refresh pins
  with `scripts/pin-obsidian-plugins.sh` and review the manifest diff before
  committing.
- **`skills/`** — `secondbrain` (setup orchestrator) + `secondbrain-doctor` (integrity
  check + MCP repair) + `brain-dump` (instructional usage tutorial — hands the user
  prompts to run, executes nothing; vault-agnostic, re-runnable) + ported `yt-fetch` /
  `notebooklm-ingest`. Each has a matching
  `commands/*.md` where relevant.

## Conventions (follow these when editing)

- **Every `bin/`/`scripts/` file sources `common.sh`** and uses its helpers — never
  reimplement logging or confirm. New scripts: `source .../scripts/common.sh`,
  `parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"`.
- **Respect `--dry-run` and `--yes`.** Any mutation must go through `run "<desc>" --
  <cmd>` (honors dry-run) or be guarded by `[ "$TSB_DRY_RUN" = 1 ]`. Flags are
  **exported** so child scripts inherit them — do not break that.
- **Idempotent:** detect already-present state and skip; a second run must mutate
  nothing and report green.
- **`TSB_` is the env-var prefix** (was `CSB_`; don't reintroduce `CSB_`).
- **JSON is read/written with `node`** (a hard dependency), not `jq`/`sed`.
- **`manifest_get`** newline-terminates list output so bash `while read` keeps the
  last line — keep that when editing it.
- **Never write into `~/.claude/plugins/cache/**` (his plugin).** We install it via
  the official CLI, read/execute it, but never patch it.
- **MCP is machine-global** (user scope in `~/.claude.json`, one server / one port
  27124 / one key). Design assumes **one vault per machine**.
- **Two-machine model:** one vault mirrored by Syncthing; **git on the primary
  machine only** — secondaries never `git init` the vault (that's what keeps
  claude-obsidian's auto-commit inert there and histories from diverging). Both
  machines share one REST API key; `.stignore` excludes machine-local
  `.vault-meta/locks` + `transport.json` and is per-device (never synced).
- **`hooks/hooks.json` is intentionally `{ "hooks": {} }`** — the schema-valid "no
  hooks" form. Never delete the `hooks` key (plugin load error) and never populate it
  with vault runtime hooks — claude-obsidian owns those, and plugin hooks are
  machine-global, so duplicates double-fire. See `hooks/README.md` for the design
  consideration.
- **Auth probes must hit `/vault/`** (authenticated), not `/` (public, 200s with any
  key) — otherwise the key handshake isn't actually validated.
- **Attribution:** wherever code references claude-obsidian's repo, credit AgriciDaniel
  with the URL. Never ship his `WIKI.md`/`CLAUDE.md`/config — those arrive via his
  plugin.

## Testing

No test suite yet. Validate changes with:
```
for f in bin/*.sh scripts/*.sh; do bash -n "$f"; done      # syntax
bash bin/precheck.sh                                        # report-only audit
bash bin/setup-vault.sh ~/llm-wiki-test --dry-run --yes     # dry-run (no mutations)
bash bin/setup-vault.sh ~/llm-wiki-test --yes && bash bin/doctor.sh ~/llm-wiki-test
rm -rf ~/llm-wiki-test                                      # clean up throwaway vault
```
A real run only downloads into a throwaway vault and does not touch global
`~/.claude.json` when the `obsidian` MCP server is already registered.

## Scope

macOS-only MVP; generic empty scaffold (no personal content). Deferred: Windows/Linux,
cloning personal content, `pocket-sync`, auto-installing Claude Code/Homebrew,
multi-vault-per-machine.

## Meta

- License: **FSL-1.1-MIT** (`LICENSE.md`) — source-available, converts to MIT 2 years
  after each release. Copyright 2026 Terry Trippany (Try AI Solutions).
- Owner/repo: `TechTripAi/techtrip-secondbrain`.
