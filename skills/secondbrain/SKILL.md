---
name: secondbrain
description: >
  Bootstrap a generic, out-of-the-box LLM Wiki "second brain" on a fresh Mac.
  Installs Obsidian + community plugins, pulls the claude-obsidian plugin from its
  own marketplace, scaffolds a clean vault, wires the Obsidian MCP server, ships the
  yt-fetch + notebooklm-ingest source skills, and sets up git + optional Syncthing
  sync. Interactive and idempotent. Triggers on: "set up my second brain",
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
7. **Sync** — `bash bin/setup-sync.sh <path>` (git by default, optional Syncthing).
   See `references/sync.md`.
8. **Verify** — `bash bin/doctor.sh <path>` and report the health table.

Once the path is chosen in step 5, the scripts remember it (state file), so later
steps can be run without re-passing it — but passing it explicitly is always fine.

## After setup — what to tell the user

- Open the vault in Obsidian; if prompted, trust the vault and enable community
  plugins (Settings → Community plugins).
- Run `/wiki` (from the now-installed `claude-obsidian` plugin) to scaffold content
  from a one-sentence description of what the vault is for.
- The source skills `yt-fetch` and `notebooklm-ingest` are available immediately;
  `notebooklm-ingest` needs a one-time `notebooklm login` (interactive OAuth).

## Manual steps you cannot automate (call these out)

- **Claude Code itself** must already be installed (a Claude plugin can't install it).
- **Homebrew** install (if missing) is a single official one-liner the user runs.
- **NotebookLM login** is interactive OAuth.
- Enabling community plugins on **first Obsidian launch** is a click in the UI.
