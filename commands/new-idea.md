---
description: Scaffold a new greenfield origination project in the vault — stamps wiki/projects/<slug>/ (project, thesis, open-questions, decisions, spec) from the origination template, seeds the working claim, then registers it in index.md and log.md. The generative front-half of the pipeline; distinct from ingesting a source.
---

Read the `new-idea` skill and follow it.

- Run its `scripts/new-idea.sh <slug> [--title …] [--claim …]` from inside the
  vault to stamp `wiki/projects/<slug>/` from the origination template. Ask for
  the slug and the one-line working claim if the user didn't give them.
- The script only scaffolds files. **You do the graph updates**: register the
  project in `wiki/index.md` (under `## Active projects`), append a `scaffold`
  entry to `wiki/log.md`, then help seed `open-questions.md` and point the user
  at `wiki/meta/origination-workflow.md` for the loop
  (Frame → Mull → Decide → Reconcile → Log → Graduate).
- If the vault is missing the templates or workflow page, the script self-seeds
  the templates; for anything else defer to `/secondbrain` (idempotent re-run) —
  never hand-write setup artifacts.
