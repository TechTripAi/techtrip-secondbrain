---
type: meta
title: "Origination Workflow — Greenfield Loop"
created: "2026-07-13"
tags:
  - meta
  - workflow
  - origination
---

# Origination Workflow — Greenfield Loop

The generative **front-half** of the vault's pipeline. The ingest loop
(`/wiki-ingest`) is *convergent* — it takes an existing source and distills it
into the shared graph. **Origination is *divergent*** — you produce knowledge
that doesn't exist yet (a thesis, load-bearing decisions, a spec). There's no
source to distill; **you are the source.**

This is **not** an "AI-optional" track. Origination leans on AI exactly as hard
as ingest does (research, drafting decisions, stress-testing arguments) — the
difference is the **mode of work**, not the amount of AI.

> **The finish line of origination *is* ingestion.** When the thinking is worked
> out, its outputs become sources/concepts and enter the substrate the normal
> way, then the project archives. Origination and ingestion are two halves of
> one pipeline; they meet at **Graduate**.

## When to use this (vs. ingest)

| | Ingest (`/wiki-ingest`) | Origination (this doc) |
| --- | --- | --- |
| Trigger | you have a source (URL, video, PDF, repo) | you have an *idea* to work out |
| Direction | converge → distill into substrate | diverge → generate new knowledge |
| Home | `wiki/sources,concepts,entities` (substrate) | `wiki/projects/<slug>/` (workspace) |
| Output | cross-linked substrate pages | thesis → spec → (tool/article) |
| Ends by | filing into the graph | **graduating into ingest** |

## The loop

**Frame → Mull → Decide → Reconcile → Log → Graduate**

1. **Frame** — open the project (`wiki/projects/<slug>/` from the
   [[templates/origination-project/project|template]], via `/new-idea` or the
   Obsidian Templates plugin). Write the **one-line claim** as a blockquote in
   `thesis.md`; seed `open-questions.md` with the unknowns.
2. **Mull** — a thinking session (with AI or solo) against the thesis + open
   questions. This is where research and argument happen.
3. **Decide** — when a **load-bearing** call surfaces, append a `Dn` entry to
   `decisions.md` (**append at the bottom, ascending**: Context / Decision / Nuances / Consequences)
   and mark the matching item `RESOLVED → Dn` in `open-questions.md`.
4. **Reconcile** — update `thesis.md` so the argument reflects the decision;
   surface any *new* open questions the decision created.
5. **Log** — append a `decision` entry to [[log]].
6. **Graduate** — see below.

### Session ritual (end of every session)

Before you stop, ask three things:

1. **Did a load-bearing decision surface?** If yes → is it a `Dn` in
   `decisions.md`?
2. **Are `open-questions.md` and `thesis.md` reconciled** with what we decided?
3. **Did anything harden** enough to promote to the substrate? (see Graduate)

If you can't answer yes/handled to all three, you're not done — capture before
you close. The whole point is that the thinking survives the session.

## The five project files

| File | Role | Mutability |
| --- | --- | --- |
| `project.md` | the tracker — outcome, status, next action | living |
| `thesis.md` | the **workbench** — the evolving argument; allowed to be messy | rewritten freely |
| `open-questions.md` | the **backlog** — unknowns; items get `RESOLVED → Dn` | append + resolve |
| `decisions.md` | the **ADR log** — load-bearing calls, append-only, ascending (D1 top, latest at bottom) + an Index | append-only |
| `spec.md` | the **graduation gate** — the buildable bridge once the thesis is sound | fills over time |

### `decisions.md` is the spine

It's a lightweight **ADR** (Architecture Decision Record) log and it is the
device that keeps the discipline honest — and portable across tools (you, Claude,
Cursor all append to the same log). Rules:

- **Append-only, ascending.** `D1` at the top; append each new `Dn` at the
  bottom, so the reading order matches the numbering and later decisions follow
  the earlier ones they build on. A short **Index** at the top lists every `Dn`
  for a one-glance view. Never rewrite a past decision; supersede it with a new
  `Dn` that references the old one.
- **One `Dn` per load-bearing call.** Format: Context / Decision / Nuances /
  Consequences / Basis.
- **Every `Dn` closes a loop:** mark its `open-questions.md` item resolved and
  drop a `decision` line in [[log]].

## Graduate (the seam into ingest)

Two motions, and you do **both**:

- **Early — promote hardened concepts continuously.** The moment an idea in the
  project firms up into a distinct, reusable concept, promote it to
  `wiki/concepts/` (or an entity to `wiki/entities/`), cross-linked to its
  ancestors. The substrate grows *during* origination — you don't wait for the
  whole project.
- **At finish — ingest the whole.** When the thinking is worked out, treat the
  project's outputs (`thesis.md`, `spec.md`, `decisions.md`) as material and
  **ingest them into the substrate** via the normal ingest loop:
  a `wiki/sources/` summary page + any remaining concept/entity pages, cross-
  linked, with [[index]]/[[log]] updated. Then **archive** the project folder
  (e.g. to `wiki/archives/<year>/`). The thesis piece can also ship
  independently as an article at any point — it isn't blocked on the tool.

Don't hoard open projects: a project that stops moving should **graduate or
archive**. `/secondbrain-doctor` reports origination projects that have gone
stale or were never registered in [[index]].

## Related

- [[index]] · [[log]]
- `/new-idea` — scaffolds a project from the template
- `/wiki-ingest` — the ingest loop this graduates into
