# Skills included

Every skill below is installed together by `/secondbrain`. Invoke one by name (for example `/wiki-ingest`) or describe the job naturally; the agent picks the workflow. Back to the [README](../README.md).

## Bring knowledge in

- **`wiki-ingest`** — ingest local files, URLs, or batches; try “ingest this PDF” or
  “add these files to my wiki.”
- **`defuddle`** — turn a cluttered article page into clean Markdown before ingesting;
  try “clean and ingest this URL.”
- **`yt-fetch`** — fetch a YouTube transcript and metadata, then hand it to ingest;
  try “add this YouTube video to my wiki.”
- **`x-fetch`** — fetch an X (Twitter) post's text and metadata, transcribing any
  video in it on-device, then hand it to ingest; try “ingest this tweet.”
- **`voice-fetch`** — transcribe a voice memo or audio file on-device, then ingest it;
  try “transcribe and ingest this `.m4a`.”
- **`code-fetch`** — read a local or remote repository and create one semantic digest
  covering its purpose, architecture, APIs, and operation; try “ingest this repo.”
- **`notebooklm-ingest`** — synthesize several sources with NotebookLM or pull an
  existing notebook into the wiki; try “combine these links into one research report.”
- **`autoresearch`** — research a topic iteratively on the web and file the findings;
  try “research passkeys deeply and build a wiki on it.”
- **`save`** — turn the current conversation, answer, or insight into a structured wiki
  note; try “save this analysis to my wiki.”

## Use and develop what you know

- **`wiki-query`** — answer from the vault with citations in quick, standard, or deep
  mode; try “based on my wiki, what do I know about passkeys?”
- **`wiki-retrieve`** — opt-in hybrid BM25 and semantic retrieval for relevant passages;
  try “find the most relevant chunks about authentication.”
- **`think`** — apply a structured ten-principle thinking loop to a difficult problem;
  try “think this decision through.”
- **`new-idea`** — scaffold a greenfield project from thesis through decisions and spec;
  try “start a new idea for an AI support product.”
- **`canvas`** — create or update Obsidian canvases with notes, text, images, and PDFs;
  try “make a canvas for this project.”
- **`obsidian-bases`** — create dynamic table, card, or list views over vault notes;
  try “make a reading-list base grouped by status.”
- **`wiki-mode`** — organize new material using Generic, LYT, PARA, or Zettelkasten;
  try “switch this vault to PARA mode.”

## Maintain the knowledge base

- **`wiki-lint`** — a deterministic engine finds orphan pages, dead links, and missing
  metadata (same report whether Claude, Codex, or Copilot runs it), then the model adds
  stale claims and provenance gaps; try “health-check my wiki.”
- **`wiki-archive`** — move retired pages or cold raw sources out of the live graph while
  preserving their bookkeeping; try “archive this finished project.”
- **`wiki-delete`** — safely delete a page after showing its backlinks and impact;
  try “delete this wiki page.”
- **`wiki-fold`** — roll recent log entries into an extractive summary page; try “fold
  the wiki log.”
- **`wiki-cli`** — read, write, search, and modify notes through Obsidian CLI with a
  filesystem fallback; this transport is normally selected automatically.
- **`obsidian-markdown`** — apply correct wikilinks, embeds, callouts, properties, tags,
  and other Obsidian syntax; it supports note-writing workflows automatically.

## Set up and learn the system

- **`wiki`** — scaffold the wiki from a one-sentence description and manage its hot
  cache; start with `/wiki` after installation.
- **`secondbrain`** — install and configure the complete SecondBrain stack; run
  `/secondbrain` to set up or update a machine.
- **`secondbrain-doctor`** — verify the stack and diagnose MCP connectivity; try “check
  my second brain.”
- **`mode-fit`** — a three-question check that the wiki mode `/wiki` chose fits how
  you will use the vault; adds missing folders and filing rules or hands you a rebuild
  prompt. Runs as the last setup step; re-run with `/mode-fit` any time.
- **`brain-dump`** — an interactive tutorial covering ingestion, research, origination,
  maintenance, sync, wiki modes, and optional features; run `/brain-dump` whenever you
  need a tour.
