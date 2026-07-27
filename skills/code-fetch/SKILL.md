---
name: code-fetch
description: "Front door for codebases going into the wiki: whenever a repository (local path or git URL) should be ingested, this distills it via graphify's local tree-sitter AST pass into ONE wiki-ingest-ready digest (source_type: codebase) in .raw/code/, then hands off to ingest. Ingesting a codebase file-by-file is the anti-pattern this prevents — a repo holds thousands of files and the wiki wants its context, not its contents. Triggers on: code-fetch, ingest this codebase, ingest this repo, add this repository to my wiki, save this codebase to the wiki, understand this codebase, map this repo, a local repo path or github.com/git URL aimed at ingest."
allowed-tools: Read Bash
---

# code-fetch: Codebase Digest Fetcher

The codebase counterpart to `defuddle`. `defuddle` strips a web page down to
its readable content; `code-fetch` strips a repository down to its structure —
god nodes (core abstractions), cross-module connections, import cycles, layout,
and the author's README framing — using [graphify](https://github.com/Graphify-Labs/graphify)
(Graphify-Labs, Apache-2.0) for a fully local tree-sitter AST pass. No LLM
call, no API key, no data egress. Output is one markdown digest with
frontmatter matching the raw-source schema, so `/wiki-ingest` consumes it with
zero changes.

Like `defuddle`, this skill **only writes to `.raw/`** (via stdout redirect).
It never touches `wiki/`. `/wiki-ingest` remains the single mutation path into
the knowledge graph.

---

## Front door for codebase sources

You are the **codebase adapter** for the wiki. Whenever the user wants a
repository in their wiki — "ingest this codebase", "add this repo", a local
path or a `github.com` URL aimed at ingest — **do the fetch here first**, then
hand off to `ingest`. This matters because ingesting a codebase file-by-file
is an anti-pattern: repos hold hundreds-to-thousands of files, and filing them
individually floods the wiki with pages nobody asked for. The wiki should hold
the codebase's *context* — what it is, its core abstractions, how its parts
connect — in one digest page.

The handoff is fixed, and you do **not** reimplement it:
1. `code-fetch` the path/URL → structural digest lands in `.raw/code/<slug>.md`.
2. Then trigger the normal `ingest .raw/code/<slug>.md` — that is
   `wiki-ingest`'s job. You only produce the raw file; you never write into
   `wiki/`.

The clone (for URL sources) and graphify's working index are temp dirs deleted
on exit — only the digest markdown survives. Nothing of the repository itself
enters the vault.

If `graphify` is missing, **do not work around it** — say so and point the
user at `/secondbrain-doctor` (or `/secondbrain`) to enable the Code feature.
This skill fetches; it does not install or replace techtrip-secondbrain's
setup tooling.

---

## Install

```bash
uv tool install graphifyy      # graphify — local AST codebase analyzer
```

Verify: `graphify --help` (the PyPI package is `graphifyy`; the CLI is
`graphify`).

---

## Usage

Run the script from the `scripts/` directory **next to this SKILL.md** (resolve
the path from wherever you read this file — installs live in the plugin cache /
harness symlink dirs, not `.claude/skills/`).

### Fetch to stdout (inspect first)
```bash
<skill-dir>/scripts/code-fetch.sh ~/projects/my-repo
<skill-dir>/scripts/code-fetch.sh https://github.com/owner/repo
```

### Save to .raw/ then ingest (the normal path)
```bash
mkdir -p .raw/code
SLUG="repo-name-$(date +%Y-%m-%d)"
<skill-dir>/scripts/code-fetch.sh https://github.com/owner/repo > ".raw/code/$SLUG.md"
# then:
ingest .raw/code/$SLUG.md
```

The script already emits full frontmatter (`source_url`/`source_path`,
`source_type: codebase`, `title`, `commit`, `file_count`, `languages`,
`fetched`) — do **not** hand-add a header the way you would after a bare
`defuddle` run.

---

## What it does

1. Resolves the source: a git URL is shallow-cloned (`--depth 1`) into a temp
   dir; a local path is used in place, read-only. Dash-prefixed arguments are
   refused (a prompt-injected "ingest --evil-flag" can't smuggle options).
2. `graphify extract <src> --code-only --out <tmp>` — deterministic local
   tree-sitter AST extraction across ~15 languages. `--code-only` skips
   docs/PDFs/images so no LLM is ever invoked and no API key is needed.
3. `graphify cluster-only --no-label --no-viz` — generates `GRAPH_REPORT.md`
   without the LLM community-naming pass or the HTML visualization.
4. Emits to **stdout**: frontmatter + directory layout + README excerpt + the
   report's Summary, God Nodes, Surprising Connections, and Import Cycles
   (capped). The noisy unlabeled community listings are dropped.
5. Temp clone and graph index are deleted on exit.

---

## When to use

**Use code-fetch when:** the source is a repository — local checkout or git
URL — and you want the wiki to understand what it is and how it's shaped
(your own projects, dependencies you're evaluating, reference codebases).

**Skip / use something else when:**
- The source is an article or blog post → use `defuddle`.
- The source is a YouTube video → use `yt-fetch`.
- You want *live* structural queries while coding in the repo (callers,
  blast radius) → that's a coding-session tool (e.g. graphify's own MCP mode),
  not a wiki ingest. The wiki holds the digest; your editor holds the index.
- You want deep per-module documentation of a repo → run graphify's full
  `/graphify --wiki` flow yourself and ingest *selected* articles deliberately;
  never bulk-ingest its whole output.

---

## Notes / limitations

- The digest is structural, not semantic: god nodes and edges are AST-derived
  (94%+ tagged EXTRACTED on typical repos; INFERRED edges are marked as such).
  The summarization into wiki pages is `wiki-ingest`'s job.
- Languages outside graphify's AST set (e.g. shell-only repos) yield thin
  graphs; the digest still carries layout + README + file stats, which is
  often enough context. Note it in the ingest if the graph section is sparse.
- Private git URLs use your ambient git credentials; nothing extra is stored.
- A specific branch: set `CODE_FETCH_BRANCH=<branch>` in the environment —
  the script honors it. **Never edit the shipped script** — for marketplace
  installs it lives in the plugin cache, which is read-only by convention.

---

## Integration with /wiki-ingest

Same handoff as `defuddle`: the file lands in `.raw/code/`, then
`ingest .raw/code/<slug>.md` files the source summary, entities, and concepts
into the shared substrate and appends to `wiki/log.md`. Expect 1–3 wiki pages
per codebase (the project itself, maybe a core-architecture concept) — never
one page per source file.
