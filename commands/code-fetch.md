---
description: Distill a codebase (local path or git URL) into a single structural digest via graphify's local AST pass and ingest it into the wiki — /code-fetch <path-or-url>. Fully local, no API key; the code never leaves the machine and never floods the wiki.
---

Read the `code-fetch` skill, then run its flow for the given repository.

- **Short forms are the point.** `/code-fetch <path-or-url>` (or `ingest this
  repo`, or a bare repo path/URL aimed at ingest) is the whole request —
  digest, then proceed to the ingest handoff. Never ask the user to rephrase
  into a longer sentence.
- **Digest locally** via the skill's `scripts/code-fetch.sh` (resolve the path
  next to the skill file) → one digest lands in `.raw/code/<slug>.md` → hand
  off to the normal `ingest`.
- **Never ingest the repository's files themselves** — that's the anti-pattern
  this command exists to prevent. One codebase becomes one digest and 1–3 wiki
  pages, not a page per file.
- Clones and graph indexes live in temp dirs and are deleted after the digest;
  nothing of the repo enters the vault.
- If `graphify` is missing, **don't work around it** — the Code feature was
  declined at setup; point at `/secondbrain` to enable it (or
  `/secondbrain-doctor` to check state). This command never installs anything.
