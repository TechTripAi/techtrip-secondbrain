---
name: notebooklm-ingest
description: "Synthesize sources (YouTube, articles, PDFs) into a NotebookLM report and land it in the wiki with no manual copy-paste. Two modes: CREATE a new notebook from URLs, or PULL an existing notebook you already curated. Downloads the report markdown to .raw/ and hands off to wiki-ingest. Triggers on: notebooklm, notebooklm ingest, notebooklm pull, synthesize these sources, research report from these links, notebook from urls, pull my notebook, batch analyze sources."
allowed-tools: Read Bash
---

# notebooklm-ingest: NotebookLM → Wiki (no manual step)

Offloads heavy multi-source synthesis to Google's NotebookLM, then pulls the
result straight into `.raw/` as a wiki-ingest-ready markdown file. The point is
to **eliminate the manual copy-paste** from the NotebookLM UI that the usual
workflow requires: the report is generated headlessly and downloaded to disk.

This skill **only writes to `.raw/`**. `/wiki-ingest` stays the single mutation
path into `wiki/`.

**When to reach for this vs. the direct fetchers:**
- 1 article → `defuddle`. 1 video → `/yt-fetch`. These are faster, free, and
  need no Google account.
- *Many* sources synthesized together, or you want a deliverable (audio
  overview, infographic, flashcards, mind-map) → **this skill**. Highest value
  for building `ai-training` material.

---

## Install & one-time auth

```bash
uv tool install notebooklm-py     # installs the `notebooklm` CLI to ~/.local/bin
notebooklm login                  # opens a browser; log into Google once
notebooklm doctor                 # confirm auth + profile are healthy
```

Ensure `~/.local/bin` is on your PATH (the scripts add it defensively). Auth is
a **you** step — the skill never logs in on your behalf.

---

## Usage

Two modes. Both end with a file in `.raw/notebooklm/` carrying full frontmatter
(`source_type: research-report`, `title`, `fetched`, `notebook_id`, and the
`sources:` list) — no hand-editing — then you `ingest` it.

### Mode A — CREATE a new notebook from URLs
Use when you have a fresh set of links to synthesize.

```bash
.claude/skills/notebooklm-ingest/scripts/nlm-ingest.sh \
  "AI agent frameworks in 2026" \
  "https://www.youtube.com/watch?v=AAA" \
  "https://www.youtube.com/watch?v=BBB" \
  "https://some.substack.com/p/a-take"
```

### Mode B — PULL an existing notebook (selective, by notebook)
Use when you've already curated a notebook in the NotebookLM UI and just want
*that one* in the wiki. Select by id prefix **or** title substring.

```bash
notebooklm list                       # see your notebooks + ids
.claude/skills/notebooklm-ingest/scripts/nlm-pull.sh "AI agent frameworks"
# reuse the latest existing report by default; regenerate with:
.claude/skills/notebooklm-ingest/scripts/nlm-pull.sh "AI agent frameworks" --fresh
```

`nlm-pull` reads the notebook's real title and source list from
`notebooklm metadata`, so the frontmatter reflects what's actually in the
notebook. It pulls **one** notebook per run — nothing else is touched.

### Then, either mode:
```bash
ingest .raw/notebooklm/<slug>-<date>.md
```

---

## What the scripts do

**`nlm-ingest.sh` (create):**
1. `notebooklm list` as an auth guard (fails fast with a login hint).
2. `notebooklm create "<topic>" --json` → parses the new notebook id.
3. `notebooklm source add "<url>" -n <id>` for each URL (auto-detects
   YouTube/article/PDF).
4. `notebooklm generate report "<topic>" -n <id> --wait` — blocks until done.
5. `notebooklm download report <tmp> -n <id> --force` → markdown to disk.
6. Prepends wiki-ingest frontmatter → `.raw/notebooklm/<slug>-<date>.md`.

**`nlm-pull.sh` (existing):**
1. Auth guard, then resolve the selector (id prefix or title substring) to one
   notebook via `notebooklm list --json` — errors on ambiguous/no match.
2. `notebooklm metadata -n <id> --json` → real title + source list.
3. Reuse vs. regenerate: if `--fresh` **or** the notebook has no report yet,
   `generate report --wait`; otherwise reuse the latest existing report.
4. `notebooklm download report <tmp> -n <id> --force` → markdown to disk.
5. Prepends frontmatter (title/sources from metadata) → same `.raw/` path.

---

## Deliverables beyond the report (optional)

NotebookLM can also generate `audio`, `infographic`, `flashcards`, `mind-map`,
`slide-deck`, and more. To produce one against the same notebook after an ingest
run, reuse its id (printed as `notebook_id` in the file's frontmatter):

```bash
notebooklm generate infographic -n <notebook_id> --wait
notebooklm download infographic ./out/ -n <notebook_id>
```

These are teaching/marketing artifacts — keep them in `.raw/notebooklm/` or an
Area's project folder; they are outputs, not wiki substrate.

---

## Notes / limitations

- `notebooklm-py` is an **unofficial** client; NotebookLM UI changes can break
  it. If a step fails, `notebooklm doctor` first, then re-auth.
- Up to ~50 sources per notebook.
- Cost model: generation runs on Google's compute, **not** your Claude tokens.
  Only the later `ingest` step (Claude reading the downloaded report) uses
  Claude tokens — same as any other source.
- The notebook persists in your NotebookLM account; delete stale ones with
  `notebooklm delete <id>` if you don't want them accumulating.

---

## Integration with /wiki-ingest

Identical handoff to `defuddle` and `/yt-fetch`: file in `.raw/` → `ingest` →
source summary + entities + concepts filed into the shared substrate, `log.md`
updated. Because the report already cites its sources in frontmatter, cross-refs
resolve cleanly on ingest.
