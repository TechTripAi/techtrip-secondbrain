---
description: Interactive, hands-on tutorial for using your techtrip-secondbrain LLM Wiki — walks you through every ingestion type (files, URLs, YouTube, NotebookLM), .raw/, the hot cache, and keeping the vault lean. Live, exitable, re-runnable.
---

Read the `brain-dump` skill. Then run the interactive tutorial.

- It is **vault-agnostic**: locate the current vault (or ask which one to use) before
  any live exercise — never assume a specific path.
- It is a **live** tutorial: anything the user chooses to ingest becomes a **real,
  permanent** page in their wiki. Confirm and say so before each ingest; do **not** clean
  up afterward.
- Show the menu, act only on the chosen section, and **return to the menu** after each.
- Every prompt must let the user type `quit` / `exit` — honor it immediately.
- Hand off actual ingestion to the existing triggers (`ingest …`, `yt-fetch`,
  `notebooklm-ingest`, `wiki-lint`, `wiki-fold`); don't reimplement them.

This tour is re-runnable any time — it is not a one-and-done.
