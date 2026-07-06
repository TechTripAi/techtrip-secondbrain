---
description: Bootstrap a generic out-of-the-box LLM Wiki second brain on this Mac (Obsidian + claude-obsidian + MCP + sync). Interactive and idempotent.
---

Read the `secondbrain` skill. Then run the bootstrap workflow, interactively.

1. Run `bash bin/precheck.sh` and summarize what is PRESENT vs MISSING.
2. Confirm the user is on macOS and that Claude Code is already installed (prereqs).
3. Ask ONE question up front: "Where should the vault live?" (default `~/LLM-Wiki`).
4. Walk the steps in order, pausing at each confirm prompt and explaining what it does:
   deps → Obsidian → claude-obsidian plugin → scaffold vault → MCP → sync → doctor.
   Never pass `--yes` unless the user asks for an unattended run; offer `--dry-run`
   first if they want a preview.
5. Finish with `bash bin/doctor.sh <path>`, report the health table, and tell them the
   manual follow-ups: open the vault in Obsidian + enable community plugins, reload
   Claude Code, run `/wiki` to scaffold content, and `notebooklm login` if they'll use
   notebooklm-ingest.
6. Offer the guided tour: ask if they'd like to run **`/brain-dump`** now — a guided
   walkthrough of how to use the wiki (every ingestion type, `.raw/`, the hot cache,
   keeping it lean) that hands them prompts to run themselves. Offer it; never auto-run
   it. They can run it any time later.

If a vault already exists at the chosen path, skip scaffolding and run `doctor.sh` to
report current state, then offer to fill any gaps.
