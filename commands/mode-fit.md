---
description: Check whether the wiki mode chosen in /wiki fits how you will actually use the vault — three questions, a verdict, and either added folders and filing rules or a rebuild prompt. Cheapest right after setup while the vault is empty; re-runnable later with a migration caveat.
---

Read the `mode-fit` skill. Then:

1. Resolve the vault path (arg, saved setup path, or ask; default `~/LLM-Wiki`). Read
   the vault `CLAUDE.md` `Mode:` line and `wiki/index.md` to learn the current mode.
2. Run the empty-vault check. Say whether a rebuild is cheap (empty) or a migration
   (sources exist) before asking anything.
3. Ask the three questions one at a time, each with its examples. Do not interview.
4. Give the verdict (fits / insufficient / wrong) in two sentences with the reason.
5. Act per the skill's table: record only (fits), add folders and filing rules on a
   yes (insufficient), or hand over the filled-in `/wiki` rebuild prompt (wrong, empty
   vault). Never rebuild a non-empty vault; never touch `.raw/`; never install anything.
6. Always write the "Mode rationale" block to the vault `CLAUDE.md` and a `mode-fit`
   entry at the top of `wiki/log.md`.
