---
description: Teaching guide for using your techtrip-secondbrain LLM Wiki — explains every ingestion type (files, URLs, YouTube, NotebookLM), topic research via autoresearch, starting a greenfield idea via new-idea, .raw/, the hot cache, maintenance (freshness, retracting bad sources, safe deletion, archiving), and enabling/disabling optional features, and hands you the exact prompts to run yourself. Re-runnable.
---

Read the `brain-dump` skill. Then run it as a teaching guide.

- **Teach, never execute.** Hand the user copy-paste prompts to run themselves; do NOT
  run ingests, fetchers, lint, or fold, and do NOT read or modify their vault.
- **It's a conversation, not a mode.** Never tell the user to type `quit`/`exit`/`stop`
  (those can end their Claude session). If they say they're done or change the subject,
  just wrap up. Never emit anything that ends the session.
- **Defer, don't replace.** If a prerequisite is missing, point the user at
  `/secondbrain-doctor` or `/secondbrain` — brain-dump installs/repairs nothing.
- **Vault-agnostic.** Use generic placeholders (`.raw/articles/…`); never hardcode a
  path. Layout under `.raw/` is a convention — flat or foldered both ingest fine.
- **Teach the engine:** `.raw/` is a plain folder of source files; `ingest` reads
  whatever is in it and builds `wiki/` from it. Files stay in `.raw/` permanently.
- **Two cwd rules (state both):** starting `claude`/running prompts needs no `cd` (the
  `obsidian` MCP is machine-global); but a *terminal* command writing to `.raw/…` is
  relative to the shell — `cd <vault>` first or use an absolute path.
- **Label every block.** Mark each as **Prompt — type into Claude Code** (`ingest …`,
  `lint the wiki`, `fold the log …`) or **Shell — run in your terminal** (`defuddle … >
  file`, `yt-dlp …`, `cp …`, `ls -R .raw`) so wiki prompts aren't mistaken for shell.
- **Give a fallback per ingest type.** `ingest <url>` often gets blocked (Cloudflare /
  bot walls / JS-only pages); when it does, have the user fetch it themselves into
  `.raw/` (defuddle-cli, curl, yt-dlp, or Finder "Save As"), then `ingest` the local file.
- **Model choice:** feeding the wiki is light work — a faster/cheaper model is fine; the
  top-tier "complex" models are for coding, not ingest/lint/query.
- **PRO-TIP, offered once:** suggest running the handed-over prompts in a **second,
  side-by-side Claude Code terminal** so wiki work stays out of the walkthrough — not
  required, just nicer; the same session is fine too.
- **Autoresearch takes a topic, not a source (Section 5):** to "research a source,"
  ingest the source first, then `/autoresearch` the topic or claim it raised — the
  ingest goes first so the researched pages cross-link to it.
- **Origination is the divergent direction (Section 6):** `/new-idea` scaffolds a
  greenfield project (thesis → decisions → spec) when there's no source because the
  user *is* the source. Teach the hygiene rule: graduate or archive — don't hoard
  open projects (`/secondbrain-doctor` reports stale ones).
- **Maintenance is a topic menu (Section 9):** freshness (lint's aging + stale-claims
  reports), retracting bad sources, `.raw/` inbox hygiene (never hand-delete — archive,
  so provenance pointers follow the file), safe page deletion (blast radius shown
  first), and archiving — warm in-vault tiers plus a **passive** cold vault that must
  never get the Local REST API plugin (the live vault's MCP owns port 27124).
- **Optional features (Section 10):** brain-dump is the standing reference for turning
  YouTube / NotebookLM on or off after setup — enabling routes through
  `/secondbrain` (idempotent), disabling is a plain `brew`/`uv` uninstall the user
  runs themselves. Remind the user once, up front, that this section exists.
- **Second machine & sync (Section 11):** plain git — clone the vault remote, run
  `/secondbrain` (idempotent; mints a per-machine REST key), then the recurring sync
  is Shell-only (`git pull` before, `git push` after; single-writer rule). Stress the
  thrift point: sync costs **zero AI tokens** — never spend a prompt on a `git pull`.
- Show the menu, explain the chosen section, then invite the next one.

This tour is re-runnable any time — it is not a one-and-done. Say so, and mention it
again at the close (it's also how they flip optional features later).
