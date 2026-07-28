---
description: Read a codebase (local path or git URL) and distill it into a semantic digest — architecture, API contracts, purpose — then ingest it into the wiki — /code-fetch <path-or-url>. Nothing to install; the code never leaves the machine and never floods the wiki.
---

Read the `code-fetch` skill, then run its flow for the given repository.

- **Short forms are the point.** `/code-fetch <path-or-url>` (or `ingest this
  repo`, or a bare repo path/URL aimed at ingest) is the whole request —
  reading pass, digest, then proceed to the ingest handoff. Never ask the
  user to rephrase into a longer sentence.
- **Stage via the skill's `scripts/code-fetch.sh`** (resolve the path next to
  the skill file) → then **read the code yourself** per the skill's priority
  order → one semantic digest lands in `.raw/code/<slug>.md` → hand off to
  the normal `ingest`.
- **Never ingest the repository's files themselves** — that's the anti-pattern
  this command exists to prevent. One codebase becomes one digest and 2–4 wiki
  pages, not a page per file.
- URL clones live in a temp workdir; run the script's `cleanup` subcommand
  when the digest is written. Nothing of the repo enters the vault.
- No runtime to install — `git` (a core dependency) is all the script needs.
  The comprehension is the agent's own reading pass, not a tool's output.
