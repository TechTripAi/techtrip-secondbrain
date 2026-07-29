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

**Shell — run from inside the vault** (resolve the script from the `scripts/`
dir next to this SKILL.md — installs live in the plugin cache, not
`.claude/skills/`):
```bash
<skill-dir>/scripts/new-idea.sh <slug> \
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

On an upgrade, setup runs the narrow `migrate-origination-metadata.sh` helper:
it adds the missing `project.md` template field and the marked session-ritual
check without replacing unrelated workflow customizations. Independently, the
scaffolder validates all five generated pages and repairs missing/invalid
`updated:` values, so an old vault-local template cannot create stale metadata.

## After the script runs (agent steps)

1. **Register in [[index]]** — add a bullet under `## Active projects`
   (create the heading if the vault doesn't have one yet):
   `- [[projects/<slug>/project|<Title>]] — <one-line> ; see [[projects/<slug>/thesis|thesis]]`
2. **Log it** — append a `scaffold` entry to [[log]] (newest-first) naming the
   project and its claim.
3. **Kick off the loop** — confirm the thesis claim, seed `open-questions.md`
   with the real unknowns, and point the user at [[origination-workflow]].
4. **Check the scaffold** — all five project files must have an `updated:`
   frontmatter date. The script repairs a missing field in legacy vault-local
   templates, but the agent owns this final semantic check.

## Hygiene

Origination projects are divergent workbenches, so they rot as orphans if
abandoned. The rule (teach it when scaffolding): **graduate or archive — don't
hoard open projects.** `bin/doctor.sh` / `/secondbrain-doctor` reports, per
project, when an `active` project has gone stale (no file touched in 30+ days)
or was never registered in `wiki/index.md`. The report is advisory only —
whether to graduate, archive, or keep mulling is the user's call.

### Session metadata contract

Origination is agent-authored living content. Whenever a session meaningfully
changes `project.md`, `thesis.md`, `open-questions.md`, `decisions.md`, `spec.md`,
or a substrate content page promoted/edited during the work, **add or set its
`updated: YYYY-MM-DD` to today as part of the same logical edit**. At session
end, review the changed content pages and verify the date on each. `index.md`,
`log.md`, and `hot.md` are operational pages and are exempt.

For `decisions.md`, append-only governs the decision records; bumping the
frontmatter `updated:` date when appending a `Dn` is required and does not
rewrite history. Git auto-commit only records the resulting files — it never
repairs metadata — so do not delegate this check to a hook.

## Notes

- In-app alternative: point Obsidian's core **Templates** plugin at
  `wiki/meta/templates/origination-project/` to stamp files by hand without this
  skill. The skill is the automation / other-tool (Cursor, Claude) path.
- The loop this bootstraps: **Frame → Mull → Decide → Reconcile → Log →
  Graduate**, with `decisions.md` as the append-only ADR spine. Graduation
  feeds the outputs back through the normal ingest loop — origination and
  ingestion meet at Graduate.
