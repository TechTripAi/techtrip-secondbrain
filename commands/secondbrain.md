---
description: Bootstrap a generic out-of-the-box LLM Wiki second brain on this Mac (Obsidian + claude-obsidian + MCP + sync). Interactive and idempotent.
---

Read the `secondbrain` skill. Then run the bootstrap workflow, interactively.

1. Run `bash bin/precheck.sh` and summarize what is PRESENT vs MISSING.
2. Confirm the user is on macOS and that Claude Code is already installed (prereqs).
3. Ask ONE question up front: "Where should the vault live?" (default `~/LLM-Wiki`).
4. Walk the steps in order, pausing at each confirm prompt and explaining what it does:
   deps → Obsidian → claude-obsidian plugin → scaffold vault → MCP → sync →
   **optional features** → doctor. Ask about each optional feature **inline** — don't
   defer to "run setup-features.sh later" — and drive `bash bin/setup-features.sh
   <path> <feature>` per answer: **YouTube (yt-fetch)** is the harmless freebie
   (passive `yt-dlp` binary — no daemon, no credentials; recommend yes, prompt
   defaults to yes); **NotebookLM** is explicit opt-in (sends the user's sources to
   Google + needs a one-time interactive `notebooklm login` — say both *before*
   asking); **Syncthing** is explicit opt-in (background network daemon — only worth
   it with a second Mac; if they don't have one, skip it). A "no" costs nothing:
   every feature can be enabled later. Never pass `--yes` unless the user asks for an
   unattended run; offer `--dry-run` first if they want a preview.
5. Finish with `bash bin/doctor.sh <path>`, report the health table, and tell them the
   manual follow-ups: **reload Claude Code first** (run `/reload-skills` and
   `/reload-plugins`, or restart Claude Code if those aren't available — the new skills,
   hooks, and MCP only activate after a reload), open the vault in Obsidian + enable
   community plugins, run `/wiki` to scaffold content, and recap which optional
   features they enabled — anything declined can be turned on later (re-run
   `/secondbrain`, or `bash bin/setup-features.sh <path> <feature>`; `/brain-dump` has
   a section on enabling/disabling features). On any error or red MCP row, run the
   doctor **in-session** (`bash bin/doctor.sh <path>`, then `bash bin/repair-mcp.sh
   <path>` if red) — the user never has to exit and re-enter to diagnose or repair.
6. Offer the guided tour: ask if they'd like to run **`/brain-dump`** now — a guided
   walkthrough of how to use the wiki (every ingestion type, `.raw/`, the hot cache,
   keeping it lean, and switching optional features on/off) that hands them prompts to
   run themselves. Offer it; never auto-run it. They can run it any time later.

If a vault already exists at the chosen path, skip scaffolding and run `doctor.sh` to
report current state, then offer to fill any gaps.
