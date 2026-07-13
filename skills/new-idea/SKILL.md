---
name: new-idea
description: "Scaffold a new greenfield 'origination' project in the vault — the generative front-half of the pipeline (thesis → decisions → spec), distinct from source ingestion. Stamps wiki/projects/<slug>/ from the origination-project template, fills title/date, seeds the thesis claim, then the agent registers it in index.md/log.md. Triggers on: new-idea, new idea, start a new idea, new origination project, start a greenfield project, new thesis project, scaffold a project, start mulling a new idea."
allowed-tools: Read Bash Edit
---

# new-idea: Greenfield Project Scaffolder

Starts an **origination** project — see the vault's
`wiki/meta/origination-workflow.md` ([[origination-workflow]]). Origination is
the *generative* front-half of the vault's pipeline (you produce a thesis,
decisions, and a spec) as opposed to ingest, which distills an existing source.
The script only scaffolds files; **graph mutations (index/log) stay the agent's
job**, matching the single-mutation-path discipline that `/yt-fetch` and
`/wiki-ingest` follow.

## Usage

**Shell — run from inside the vault:**
```bash
.claude/skills/new-idea/scripts/new-idea.sh <slug> \
  --title "Human Title" \
  --claim "The one-line working claim, in the author's words."
```

- `slug` (required) — normalized to lowercase-hyphenated; becomes the folder name.
- `--title` (optional) — defaults to a Title-Cased version of the slug.
- `--claim` (optional) — seeds the `> **Working claim:**` blockquote in `thesis.md`.

The script copies `wiki/meta/templates/origination-project/` →
`wiki/projects/<slug>/` (project, thesis, open-questions, decisions, spec),
replaces `{{title}}`/`{{date}}`, and refuses to overwrite an existing folder.
Requires `node` (already a hard dependency of the stack).

**Old vaults self-heal:** if the vault predates this skill and has no
`wiki/meta/templates/origination-project/`, the script seeds it from the
plugin's bundled copy first (`assets/vault/wiki/meta/templates/…`), then
stamps. `bin/setup-vault.sh` seeds the same templates plus
`wiki/meta/origination-workflow.md` for new vaults — if the workflow page is
missing, point the user at `/secondbrain` to re-run setup (idempotent) rather
than writing it by hand.

## After the script runs (agent steps)

1. **Register in [[index]]** — add a bullet under `## Active projects`
   (create the heading if the vault doesn't have one yet):
   `- [[projects/<slug>/project|<Title>]] — <one-line> ; see [[projects/<slug>/thesis|thesis]]`
2. **Log it** — append a `scaffold` entry to [[log]] (newest-first) naming the
   project and its claim.
3. **Kick off the loop** — confirm the thesis claim, seed `open-questions.md`
   with the real unknowns, and point the user at [[origination-workflow]].

## Hygiene

Origination projects are divergent workbenches, so they rot as orphans if
abandoned. The rule (teach it when scaffolding): **graduate or archive — don't
hoard open projects.** `bin/doctor.sh` / `/secondbrain-doctor` reports, per
project, when an `active` project has gone stale (no file touched in 30+ days)
or was never registered in `wiki/index.md`. The report is advisory only —
whether to graduate, archive, or keep mulling is the user's call.

## Notes

- In-app alternative: point Obsidian's core **Templates** plugin at
  `wiki/meta/templates/origination-project/` to stamp files by hand without this
  skill. The skill is the automation / other-tool (Cursor, Claude) path.
- The loop this bootstraps: **Frame → Mull → Decide → Reconcile → Log →
  Graduate**, with `decisions.md` as the append-only ADR spine. Graduation
  feeds the outputs back through the normal ingest loop — origination and
  ingestion meet at Graduate.
