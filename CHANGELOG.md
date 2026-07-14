# Changelog

All notable changes to `techtrip-secondbrain` are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.5] — 2026-07-14

The maintenance release. Split by the repo's own seam — read-only reporting
here, reconciling mutations in the claude-obsidian fork (v1.9.3, pinned via
`manifest.json testedVersion`).

### Added
- **`doctor` — "Wiki maintenance" section** (report-only, like every doctor
  row): **orphaned provenance** (source pages whose `raw_file:`/`sources:`
  pointer names a deleted or moved `.raw/` file — silent rot nothing else
  surfaces between lint runs), **`.raw/` pile-up** (inbox files never
  recorded in `.raw/.manifest.json` — pending work, not clutter), **aging
  pages** (`updated:` past 90 days; `evergreen`/`archived`/`retracted` and
  meta/fold/archive paths exempt), and **archive tiers** (informational
  presence of `.archive/` and `wiki/archives/`). Every remedy routes to the
  fork's content skills or `/brain-dump` §9 — doctor never mutates content.
- **`/brain-dump` §9 rebuilt as a maintenance topic menu** (numbering
  unchanged; §10 stays the feature-toggle reference): 9a freshness (lint's
  Staleness Aging + stale claims, four refresh paths), 9b bad sources
  (contradiction model + the retraction flow), 9c `.raw/` inbox (never
  hand-delete — archive so provenance follows the file), 9d safe page
  deletion (blast radius first; `log.md` history never scrubbed), 9e
  archiving (warm in-vault tiers + the **passive archive vault** rule:
  never install Local REST API there — the live vault's MCP owns port
  27124), 9f the once-over cadence (lint / fold / doctor).
- **`secondbrain-doctor` skill** — workflow step for the new maintenance
  rows: content decisions have no auto-repair; route to `lint the wiki`,
  ingest/archive prompts, or `/brain-dump` §9.
- **`/brain-dump` §11 — Second machine & sync** ("Where to go next" moves
  to §12; §10 doesn't move): clone the vault remote, idempotent
  `/secondbrain` with a per-machine REST key, then Shell-only
  pull-before/push-after under the single-writer rule — with the token
  economics called out explicitly (sync costs zero AI; batch ingests;
  cheap models for wiki work; `hot.md`'s ~500-token session start pays on
  both machines).

### Changed
- `manifest.json` claude-obsidian pin: `testedVersion` 1.9.2 → **1.9.3**
  (the fork's maintenance suite: `wiki-delete`, `wiki-archive`, source
  retraction, lint checks for orphaned provenance + staleness aging).
  Fork-posture note updated: fixes **plus maintenance additions proposed
  upstream as candidate PRs** — no silent divergence.

## [0.2.4] — 2026-07-13

### Added
- **`bin/disarm-dragonscale.sh` — turns off claude-obsidian's silently
  self-arming DragonScale addressing.** DragonScale Mechanism 2 is
  feature-detected from files *inside the vault*: an executable
  `scripts/allocate-address.sh` plus a `.vault-meta/` dir (which
  techtrip-secondbrain creates for its own mode/transport state) arms it, and
  every ingest then assigns `address:` frontmatter from a monotonic counter in
  `.vault-meta/address-counter.txt`. That counter is guarded by machine-local
  `flock` only — duplicate-address and merge-conflict bait under this
  project's two-machine git model, and DragonScale is out of scope here (see
  README). The disarmer removes only the arming files (allocator script,
  counter, `tiling-thresholds.json`, `legacy-pages.txt`) behind a
  **default-no** confirm with a backup to
  `~/.config/techtrip-secondbrain/dragonscale-backups/`; existing `address:`
  fields, the tiling/boundary diagnostic scripts, `.raw/.manifest.json`, and
  the plugin cache are never touched. Vaults that want DragonScale just
  answer no; re-arm any time via claude-obsidian's `setup-dragonscale.sh`.
  - `doctor` gained a report-only **"DragonScale addressing"** section with
    three states: armed / off-but-stale-state-files / not armed.
  - `bin/update.sh` runs the disarm check right after the permission prune
    (new step 6; later steps renumbered) — it no-ops green on unarmed vaults.
- **`bin/prune-permissions.sh` — cleans up permission rules stranded by plugin
  updates.** Claude Code saves approved rules into `settings.local.json` with
  the versioned plugin-cache path baked in
  (`…/plugins/cache/<marketplace>/<plugin>/<version>/…`); every plugin update
  moves that root, leaving dead rules that can never match again — the user
  gets re-prompted and Claude's built-in `/doctor` flags them as invalid
  (found via exactly that report on a second machine). The pruner removes
  **only** provably dead rules — the version dir is missing or superseded by a
  newer installed version — so a removal can only ever cause a one-time
  re-prompt, never grant anything. It covers `~/.claude/settings.local.json`
  and `<vault>/.claude/settings.local.json`, backs each file up to
  `~/.config/techtrip-secondbrain/permission-backups/` before editing
  (atomic tmp+rename write), and is confirm-gated, idempotent, and
  `--dry-run`/`--yes` aware. Glob rules (`…/cache/**`) are never touched.
  - `doctor` gained a report-only **"Permission rules (settings.local.json)"**
    section: a dead-rule count per file with the pruner as the remediation
    arrow. Detection lives in `scripts/common.sh` (`stale_permission_rules`)
    so doctor and pruner can never disagree.
  - `bin/update.sh` offers the prune right after the plugin updates that cause
    the staleness (new step 5; later steps renumbered).
  - The `secondbrain-doctor` skill routes the repair (runs the pruner
    in-session for marketplace installs and explains the re-approval story).

## [0.2.3] — 2026-07-13

### Added
- **`/new-idea` — greenfield origination-project scaffolder** (ported from the
  author's vault, where it proved itself in daily use). The generative
  *front-half* of the pipeline: where ingest distills an existing source,
  origination starts from an idea — *you are the source*. The skill stamps
  `wiki/projects/<slug>/` (project tracker, thesis workbench, open-questions
  backlog, append-only ADR-style `decisions.md`, spec-as-graduation-gate) from a
  template, fills `{{title}}`/`{{date}}` (node-based — no new runtime deps),
  seeds the working claim, and leaves the graph updates (`index.md`/`log.md`
  registration) to the agent — same single-mutation-path discipline as
  `yt-fetch`/`wiki-ingest`. Graduation feeds the outputs back through the normal
  ingest loop, keeping origination inside the LLM-wiki model rather than beside it.
  - **Vault artifacts ship with the plugin** (`assets/vault/`):
    `wiki/meta/origination-workflow.md` (the Frame → Mull → Decide → Reconcile →
    Log → Graduate loop) + the five project templates.
    `bin/setup-vault.sh` seeds them (`cp -n` — never clobbers user edits), and
    the skill self-seeds the templates on pre-existing vaults.
  - **`doctor` gained a report-only "Origination projects" section**: flags an
    `active` project untouched for 30+ days (*stale — graduate or archive*) and
    a project folder never registered in `wiki/index.md` (*unindexed*). Advisory
    only — content decisions are the user's; the `secondbrain-doctor` skill
    offers help but never auto-mutates. Lives here (not in claude-obsidian's
    `wiki-lint`) because the fork policy is bug-fixes-only, no feature divergence.
  - `/brain-dump` gained **Section 6 — Start a new idea (origination)**; former
    Sections 6–10 renumbered to 7–11 (the optional-features standing reference
    is now **Section 10**, was §9).

### Fixed (security + robustness hardening — full-repo review)
- **`repair-mcp.sh`'s re-register repair actually repairs now.** It rebuilt
  child flags with `${TSB_DRY_RUN:+--dry-run}` — but the var is always set
  (`"0"`/`"1"`), so `:+` appended `--dry-run` unconditionally and the
  `setup-mcp.sh` call was a permanent no-op. Flags are exported; the child just
  inherits them.
- **Manifest command strings are no longer executed through a shell.**
  `setup-deps.sh` / `setup-features.sh` ran manifest `install`/`probe`/`login`
  strings via `bash -c` — an arbitrary-code channel for anyone who could edit
  `manifest.json`. New `manifest_argv` helper splits them into fixed argv with
  no shell interpretation, rejects metacharacters, and allowlists the leading
  tool (`brew`/`uv`/`notebooklm`).
- **Community-plugin installs are validated end-to-end.**
  `install-obsidian-plugin.sh` now whitelists the shape of plugin id / repo /
  tag (they become path + URL segments), downloads into a staging dir and
  verifies **all** sha256 hashes before anything moves into the live
  `.obsidian/plugins/` dir (no partial installs, no unverified `main.js` ever
  loadable), and **hard-fails** a manifest-listed plugin with a missing hash
  (previously warn-and-install, which silently bypassed the supply-chain
  guard). `pin-obsidian-plugins.sh` validates the tag it gets from the GitHub
  API before building download URLs from it.
- **No-TTY prompts no longer consent on the user's behalf.** `confirm_yes`
  treated a failed `/dev/tty` read as Enter (= yes), so a headless run could
  auto-accept installs the consent tiering says need a human. Both `confirm`
  and `confirm_yes` now decline with a warning when there is no TTY (pass
  `--yes` to auto-confirm deliberately).
- **Secrets stay off argv and out of dry-run transcripts.** `run`'s dry-run
  echo redacts `KEY=`/`TOKEN=`/`SECRET=`/`PASSWORD=` values (previously
  `setup-mcp.sh --dry-run` printed the real REST key); the doctor/repair curl
  probes pass the bearer key via `--config` process substitution instead of
  argv; `setup-mcp.sh` hands the new key to node via env, not argv.
- **`yt-fetch` hardened against option smuggling and frontmatter injection.**
  The URL must be http(s) and is passed to `yt-dlp` after `--` (a dash-prefixed
  "URL" from a prompt-injected page can no longer become `--exec`);
  `yt_emit.py` validates + JSON-escapes `webpage_url` before emitting YAML
  (title/author already were).
- **Sturdier plumbing in `common.sh`:** `parse_common_flags` supports `--`;
  the documented idiom is now `set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}` (the
  old `"${TSB_ARGS[@]:-}"` injected a phantom empty positional — all 11 call
  sites updated); `manifest_get` dies cleanly on unreadable/invalid JSON;
  `load_vault_path` rejects a corrupted state file (must be one absolute path).
- **Anchored presence checks.** `claude mcp list` greps anchor to the
  `name:` column and `claude plugin list` greps are fixed-string; doctor reads
  `community-plugins.json` membership via node (JSON, not substring grep) and
  sanitizes the remote version string it prints.
- **`new-idea.sh`:** the seeded claim is inserted via a function replacement so
  a claim containing `$&`/`$'` can't corrupt the thesis.

### Changed
- `hooks/hooks.json` is now the bare schema-valid `{ "hooks": {} }` (the design
  note moved to `hooks/README.md`, which already carried it).
- `manifest.json`: `skills` now lists `secondbrain` + `secondbrain-doctor`
  (completeness); the MCP note documents the process-wide blast radius of
  `NODE_TLS_REJECT_UNAUTHORIZED=0` and why it's acceptable here
  (localhost-only server).
- Docs de-drifted: `yt-fetch` SKILL no longer tells users to edit the cached
  script (cookies via `YT_FETCH_COOKIES_BROWSER`, correct `--sub-lang` list);
  skill examples drop hardcoded `.claude/skills/` paths (wrong for marketplace
  installs); secondbrain references stop listing `yt-dlp` as a required dep
  (it's the consent-gated youtube feature); `list-to-table` attribution fixed
  to `kepano/list-to-table`; AGENTS.md's release rule names the real version
  field (`.claude-plugin/plugin.json`, not `manifest.json`).

## [0.2.2] — 2026-07-13

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

### Changed
- **`bin/*.sh` is now consistently marked as the git-clone door.** README, the
  skills, and doctor's output footer all route marketplace installs to the skills
  (`/secondbrain`, `/secondbrain-doctor`) instead of bash commands — a marketplace
  install has no repo to run `bin/` from, so the skills are its only interface.
- **README explains the two-step marketplace update** (`marketplace update`
  refreshes only the catalog clone; `claude plugin update` is what copies the new
  version into the cache and re-points the registry pin) and notes the updater
  compares manifest versions, not file contents. AGENTS.md gained the matching
  convention: every release that changes shipped files must bump the plugin
  manifest's `version`, or installed machines stay on the old cached snapshot.

### Added
- **`doctor` now reports update availability** for both plugins: the installed
  cache version vs the `version` in `.claude-plugin/plugin.json` on each repo's
  `main` (one short `curl` per plugin; offline skips the check, never fails it).
  Combined with the periodic-doctor habit, users now *hear about* new releases
  instead of having to think to check. The `secondbrain-doctor` skill routes the
  update by install path (marketplace → `claude plugin update` + `/secondbrain`
  re-run; clone → `git pull` + `bin/update.sh`).

## [0.2.1] — 2026-07-13

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
