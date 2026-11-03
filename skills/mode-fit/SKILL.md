---
name: mode-fit
description: >
  One-time post-install conversation that checks whether the wiki mode chosen in
  /wiki actually fits how the user will use the vault. Three questions with examples
  (what goes into .raw/, what should come out, who reads it), a verdict (fits /
  insufficient / wrong), and a concrete fix: folders and filing rules to add, or a
  rebuild via /wiki while the vault is still empty. Records the rationale in the
  vault CLAUDE.md and log. Re-runnable later, but warns that restructuring after
  sources exist is a migration. Triggers on: /mode-fit, mode fit, is my mode right,
  did I pick the right mode, check my wiki mode, which mode should I use, change
  wiki mode, my vault layout doesn't fit, add folders to my wiki.
allowed-tools: Read Bash Edit Write
---

# mode-fit: does the chosen mode match the use?

You run a **short, interactive conversation** after the vault is scaffolded and a mode
has been chosen in `/wiki`, to catch the case where that choice was uninformed,
wrong, or not sufficient. The `secondbrain` setup skill calls you as its last step;
users can also run you any time with `/mode-fit`.

Why this exists: `/wiki` asks one question and scaffolds. A user who picks from
one-line labels often learns the difference between modes only after the first
ingest, when switching has become a migration. This step is the cheap moment to
get it right, while `.raw/` is still empty.

## What a mode is (say this in one sentence if the user asks)

A mode is a folder set plus the filing rules in the vault `CLAUDE.md`, not an
Obsidian feature. Nothing enforces it except Claude reading those rules at the start
of every ingest. The full reference is claude-obsidian's
`skills/wiki/references/modes.md`; the user-facing summary is `/brain-dump`
Section 14. Read the reference before giving a verdict.

## Golden rules

- **Three questions, then a verdict.** Do not interview. Each question comes with
  two or three concrete examples so the user can answer by pointing at one.
- **Empty-vault check first.** Count ingested material:
  `find <vault>/.raw -type f ! -name '.manifest.json' ! -name '.gitkeep' | wc -l`
  and `ls <vault>/wiki/sources/ | grep -vc _index.md`. If both are zero, a rebuild is
  cheap and you may offer it. If either is non-zero, say so plainly: restructuring is
  now a migration (pages must be re-filed), so the safe outcome is *adding* folders
  and rules, not rebuilding. Never rebuild a non-empty vault without an explicit yes.
- **You do not scaffold.** A rebuild is `/wiki`'s job. You hand the user the exact
  `/wiki` prompt with the mode decision already in it, or you add folders and filing
  rules yourself for the "insufficient" case (that is additive and safe).
- **You do not install anything.** Runtime questions go to `/secondbrain` and
  `/secondbrain-doctor`.
- **Never touch `.raw/`.**
- **Record the decision.** Whatever the verdict, write it down (see Output). Six
  months later the vault should say why it is shaped the way it is.
- **Vault path:** argument, then the saved setup path (`~/.config/techtrip-secondbrain/vault-path`),
  then `~/LLM-Wiki`. Read the vault `CLAUDE.md` `Mode:` line and `wiki/index.md` to
  learn the current mode before asking anything.

## The three questions

Ask them one at a time, in this order. Keep each to two lines plus examples.

**1. What will you actually drop into `.raw/` most often?**
Examples: *articles and YouTube videos about a field* (E or D) · *meeting
transcripts and Slack exports* (C) · *a codebase's README, git log, and issues* (B) ·
*crawl exports and Search Console data* (A) · *chapter notes and highlights from a
book or course* (F) · *journal entries and voice memos about my own life* (D).

**2. What do you want out the other end?**
Examples: *answers to questions* (any mode) · *articles or posts I will publish*
(needs a `writing/` folder, no mode has one) · *working code* (concepts and entities
are enough; Mode B only if one repo is central) · *decisions with a record* (C, or
`projects/` via `/new-idea`) · *progress on goals* (D) · *a thesis or state of the
field* (E).

**3. Who reads it, and how fast does the subject change?**
Examples: *just me* · *a team that needs stakeholder and decision pages* (C) ·
*a fast-moving field where claims go stale in months* (add the `[!stale]` rule and
a `gaps/` folder; E's `contradicts` field earns its keep).

## Mapping answers to a verdict

| Verdict | Meaning | What you do |
|---------|---------|-------------|
| **Fits** | the chosen mode's folders cover the inputs and the outputs | say so in two sentences, record the rationale, stop |
| **Insufficient** | the mode is right but an output or input has no home (most common: `writing/` for articles, `papers/` for academic sources, `gaps/` for a fast-moving field, `projects/` missing) | list the folders and the one filing rule each needs; on a yes, add them: folder, `_index.md`, index section, CSS color if the vault has `vault-colors.css`, and the rules appended to the vault `CLAUDE.md` "Filing rules" block (create the block if absent) |
| **Wrong** | the atomic unit is wrong (goal pages for a research vault, module pages for a personal one) | name the right mode, combination, or custom mode; if the vault is empty, hand the user the `/wiki` prompt to rebuild with that decision stated; if not empty, add the missing folders and rules instead and say the old folders can be archived later with `wiki-archive` |

Rules of thumb while mapping:

- Inputs pick the base mode. Outputs add folders. Readers and churn add rules.
- Two modes combined is fine; keep folder names distinct (B and C both have
  `decisions/`). Three or more means the filing rules must be unusually explicit.
- A custom mode is the normal outcome, not an edge case. Name it.
- Every mode keeps `sources/`, `concepts/`, `entities/`, `questions/`, `projects/`:
  the runtime skills file there regardless. If any is missing, that is an
  "insufficient" finding on its own.

## Output (always, whatever the verdict)

1. **Vault `CLAUDE.md`:** add or replace a `## Mode rationale` block directly under
   the `Mode:` / `Purpose:` header lines:

   ```markdown
   ## Mode rationale

   Checked YYYY-MM-DD with /mode-fit. Inputs: <answer 1>. Outputs: <answer 2>.
   Readers and churn: <answer 3>. Verdict: <fits | insufficient | wrong>.
   <One sentence on what was added or changed, or "No change.">
   ```

   If the verdict changed the mode, also update the `Mode:` line.
2. **`wiki/log.md`:** a `mode-fit` entry at the TOP (append-only, newest first)
   naming the verdict and any folders added.
3. **`wiki/hot.md`:** one line under Active Threads only if something changed.
4. Tell the user the vault's auto-commit hook will pick the edits up, and that
   `/mode-fit` can be re-run if their use drifts, with the migration caveat.

## The /wiki hand-off prompt (for "wrong" on an empty vault)

Give the user this to paste, filled in:

```
/wiki — rebuild this vault as <mode / combination / custom "<name>">: base <X>,
plus <folders>, because I will mostly ingest <answer 1> and I want <answer 2> out.
Keep sources, concepts, entities, questions, projects. Write the filing rules into
CLAUDE.md.
```

Say that `/wiki` will remove the old mode's empty folders and pages, and that git
has the previous scaffold if they want it back.

## How to think

Listen for the output, not the input. Users describe what they will read; the
mismatch is almost always on what they will *make* from it. "I research AI" sounds
like Mode E, and it is, but "to write articles" is the half no mode covers. Ask the
second question even when the first seems to settle it.
