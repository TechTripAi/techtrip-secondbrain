---
name: secondbrain-doctor
description: >
  Integrity check + repair for a techtrip-secondbrain LLM Wiki. Verifies the whole
  stack (vault scaffold, community plugins, MCP key handshake, claude-obsidian plugin)
  and diagnoses/repairs Obsidian MCP connectivity — especially the "obsidian MCP
  registered globally but fails to connect" failure. Safe to run anytime. The
  `secondbrain` setup skill defers to this for its post-build checkout. Triggers on:
  "/secondbrain-doctor", "check my second brain", "integrity check", "repair mcp",
  "obsidian mcp won't connect", "mcp not connecting", "verify my wiki setup",
  "post build checkout", "health check the vault".
allowed-tools: Read Bash
---

# secondbrain-doctor: integrity check + MCP repair

You verify a techtrip-secondbrain vault end-to-end and repair the most common
breakage — a registered-but-unreachable Obsidian MCP server. Runnable **anytime**,
not just at install. The `secondbrain` setup skill calls you for its final checkout.

Two scripts back this skill:

- **`bin/doctor.sh <vault>`** — read-only health table: `wiki/` tree, each community
  plugin (files present + enabled), the REST-API-key ↔ MCP-env-key match, the
  `claude-obsidian` plugin, the `obsidian` MCP registration, and a live REST probe.
- **`bin/repair-mcp.sh <vault>`** — deeper MCP diagnosis + **interactive repair**:
  uvx present, registered, key match, port 27124 listening, authenticated probe;
  then offers fixes (install uv, re-register with the correct key, open Obsidian +
  enable Local REST API, or advise a Claude reload / TLS-flag check).

## Workflow

1. Resolve the vault path (arg, or the saved path from setup, or ask; default
   `~/LLM-Wiki`).
2. Run `bash bin/doctor.sh <vault>` and summarize the table.
3. If anything MCP-related is red — or the user says the `obsidian` server "won't
   connect" — run `bash bin/repair-mcp.sh <vault>` and walk the interactive repairs,
   explaining each before confirming. Never pass `--yes` unless asked.
4. Re-run `bin/repair-mcp.sh <vault>` after repairs to confirm it goes green.

## Reading the "registered but fails to connect" case

This almost always means one of:

- **Obsidian isn't running / Local REST API is disabled** → nothing on port 27124.
  Fix: open the vault in Obsidian, enable the plugin. (The server only lives while
  Obsidian is open.)
- **Key mismatch** — the registration's `OBSIDIAN_API_KEY` no longer matches the
  vault's `data.json` `apiKey` (rotated key, or a fresh vault). Fix: re-register
  (`repair-mcp.sh` does `claude mcp remove` + `setup-mcp.sh`).
- **Stale connection** — registered, keys match, port up, but tools still fail. Fix:
  fully reload/restart Claude Code; a dead MCP session won't reconnect on its own.
- **Missing `uvx`** — the server can't launch. Fix: `brew install uv`.

See `../secondbrain/references/mcp.md` for the key-handshake details.

## Notes

- Report-only `doctor.sh` never mutates; `repair-mcp.sh` is confirm-gated and supports
  `--dry-run`.
- **Runs entirely in-session.** `doctor.sh` is read-only and safe to auto-run (including
  automatically when the setup skill hits an error), and `repair-mcp.sh`'s confirm
  prompts can be walked inline — the user never needs to exit and re-enter Claude Code to
  diagnose or repair. The one thing that *does* require a reload is a fresh MCP
  re-registration: its probe only flips green after Claude reloads.
- A newly (re)registered MCP server only becomes callable after a Claude reload — say
  so explicitly so the user isn't confused by a still-red probe immediately after.
