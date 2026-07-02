---
description: Integrity-check a techtrip-secondbrain vault and repair Obsidian MCP connectivity (registered-but-won't-connect). Safe to run anytime.
---

Read the `secondbrain-doctor` skill. Then:

1. Resolve the vault path (arg, saved setup path, or ask; default `~/LLM-Wiki`).
2. Run `bash bin/doctor.sh <vault>` and summarize the health table.
3. If any MCP row is red, or the user reports the `obsidian` server won't connect, run
   `bash bin/repair-mcp.sh <vault>` and walk the interactive repairs, explaining each
   before confirming. Don't pass `--yes` unless asked.
4. Re-run `bin/repair-mcp.sh <vault>` to confirm green, and remind the user that a
   freshly re-registered MCP server needs a Claude reload before its tools resolve.
