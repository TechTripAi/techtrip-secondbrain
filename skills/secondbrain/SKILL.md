---
name: secondbrain
description: >
  Bootstrap a generic, out-of-the-box LLM Wiki "second brain" on a fresh Mac.
  Installs Obsidian + community plugins, pulls the claude-obsidian plugin from its
  own marketplace, scaffolds a clean vault, wires the Obsidian MCP server, ships the
  yt-fetch + notebooklm-ingest source skills, and sets up git sync + backup.
  Interactive and idempotent. Triggers on: "set up my second brain",
  "/secondbrain", "bootstrap the wiki", "install the llm wiki on this machine",
  "clone my obsidian setup", "new machine setup".
allowed-tools: Read Bash
---

# secondbrain: LLM Wiki bootstrapper

You install a **generic, empty-but-fully-wired** LLM Wiki on this machine, then hand
off to the `claude-obsidian` plugin for day-to-day use. You do **not** copy any
personal content — you produce a clean starter vault the user grows themselves.

This skill is a thin **orchestrator** over the `bin/` scripts in this plugin. The
real logic lives in those scripts (idempotent + interactive); you run them in order,
explain what each does, and stop at anything that needs a human decision.

## Golden rules

- **Interactive & reversible.** Every install is behind a confirm prompt. Never pass
  `--yes` unless the user explicitly asks for an unattended run. Offer `--dry-run`
  first if the user wants to preview.
- **Idempotent.** Safe to re-run; scripts detect already-present state and skip.
- **macOS only** for now. If `uname -s` isn't `Darwin`, stop and say so.
- **Never vendor `claude-obsidian`.** It is pulled from AgriciDaniel's marketplace at
  install time (`bin/setup-claude-obsidian.sh`), never copied into this repo.
- **Secrets stay local.** The Obsidian REST API key is generated on this machine and
  written only to the vault's (gitignored) `data.json` and `~/.claude.json`.

## Workflow

Run these from the plugin root. Read the matching `references/` doc before each step
if you need detail; summarize it for the user rather than dumping it.

1. **Precheck** — `bash bin/precheck.sh`. Report what's PRESENT / MISSING. See
   `references/precheck.md`.
2. **Dependencies** — `bash bin/setup-deps.sh` (Homebrew + uv, yt-dlp, node).
3. **Obsidian** — `bash bin/setup-obsidian.sh` (installs the app). See
   `references/obsidian.md`.
4. **claude-obsidian plugin** — `bash bin/setup-claude-obsidian.sh` (marketplace add
   + plugin install). Tell the user to reload Claude Code afterward so its skills +
   hooks activate.
5. **Scaffold the vault** — ask the user for a vault path (default `~/LLM-Wiki`), then
   `bash bin/setup-vault.sh <path>`. This runs claude-obsidian's own scaffold and
   installs the community plugins. See `references/plugins.md`.
6. **MCP** — `bash bin/setup-mcp.sh <path>` (generate REST key + register the
   `obsidian` MCP server). See `references/mcp.md`. Note: it only answers once Obsidian
   is open with the Local REST API plugin enabled, and needs a Claude reload.
7. **Sync** — `bash bin/setup-sync.sh <path>` (git only: init + remote guidance;
   offers to remove a legacy vault `.stignore` but never uninstalls Syncthing
   itself — external software). See `references/sync.md`.
8. **Optional features — ask inline, you drive.** Do **not** defer this to "run
   `setup-features.sh` later" — ask about each feature as part of setup, right now,
   then run `bash bin/setup-features.sh <path> <feature>` per answer. The three
   features are not equal; frame each honestly:
   - **YouTube (yt-fetch)** — the freebie. `yt-dlp` is a passive CLI binary (no
     daemon, no credentials, no data egress), so **recommend yes**; the script's
     prompt defaults to yes. Ask: "Want to ingest YouTube videos?"
   - **NotebookLM (notebooklm-ingest)** — **explicit opt-in.** It sends the user's
     sources to Google for synthesis and needs a one-time interactive
     `notebooklm login` (OAuth) — say both *before* asking. Never enable it
     unprompted.

   A "no" costs nothing: the skills still ship, and any feature can be enabled later
   by re-running `/secondbrain` (the answer for marketplace installs — only
   git-clone users can also run `bash bin/setup-features.sh <path>
   youtube|notebooklm` directly). `/brain-dump` has a section teaching users how to
   turn any feature on or off after the fact.
9. **Cross-harness links** — `bash bin/setup-harnesses.sh <path>`. Symlinks the
   installed skills into `~/.agents/skills` (and `~/.codex/skills` when Codex is
   present) and stamps `AGENTS.md` + Cursor hook/rule parity artifacts into the
   vault so Cursor and Codex discover the same skills Claude Code uses. Claude Code
   itself needs none of this, but run the step by default — it's idempotent, its
   `ln -sfn` re-points stale links, and **on a `/secondbrain` re-run after a plugin
   update this step is what moves the links to the new version** (marketplace users
   have no `bin/update.sh`; this is their re-point path). `doctor` flags stale
   links if it's ever skipped.
10. **Post-build checkout** — defer to the **`secondbrain-doctor`** skill. On any setup
   error or a red MCP row, **run the doctor yourself, in-session** — the user should
   never have to exit and re-enter Claude Code to diagnose or repair. Run
   `bash bin/doctor.sh <path>` (read-only, safe to auto-run); if any MCP row is red, run
   `bash bin/repair-mcp.sh <path>` and walk its confirm prompts inline. Report the
   health table. (The `obsidian` MCP will read red until Obsidian is open with the Local
   REST API plugin enabled **and Claude has been reloaded** — a still-red probe right
   after a fresh re-registration is expected, not a failure; say so.)

Once the path is chosen in step 5, the scripts remember it (state file), so later
steps can be run without re-passing it — but passing it explicitly is always fine.

## After setup — what to tell the user

- **Reload Claude Code first.** The new plugin, skills, and hooks only activate after a
  reload — run `/reload-skills` and `/reload-plugins`, or **restart Claude Code** if
  those aren't available. Do this before expecting `/wiki`, `/brain-dump`, or the
  `obsidian` MCP to work.
- Open the vault in Obsidian; if prompted, trust the vault and enable community
  plugins (Settings → Community plugins).
- Run `/wiki` (from the now-installed `claude-obsidian` plugin) to scaffold content
  from a one-sentence description of what the vault is for.
- Recap the optional-feature answers from step 8: which of YouTube / NotebookLM
  are on. Anything declined can be enabled later — re-run `/secondbrain`, or ask
  `/brain-dump`, which has a section walking through turning any feature on or off.
  (Only mention `bash bin/setup-features.sh <path> <feature>` to users who cloned
  the git repo — marketplace installs have no repo to run it from; the skills are
  their interface.)
- **Plant the periodic-doctor habit.** Mention once: `/secondbrain-doctor` is
  read-only and safe to run any time — a periodic check (monthly is plenty, or
  whenever something feels off) catches drift early. Updates end with it
  automatically, so it's never *required* after updating — this is just a habit,
  not homework.
- **Offer the guided tour.** Once doctor is green, tell the user they can run
  **`/brain-dump`** any time for a guided walkthrough of how to use the wiki (every
  ingestion type, `.raw/`, the hot cache, keeping it lean) — including how to enable or
  disable the optional features later. Offer to start it now — do not auto-run it.

## Manual steps you cannot automate (call these out)

- **Claude Code itself** must already be installed (a Claude plugin can't install it).
- **Homebrew** install (if missing) is a single official one-liner the user runs.
- **NotebookLM login** is interactive OAuth.
- Enabling community plugins on **first Obsidian launch** is a click in the UI.
