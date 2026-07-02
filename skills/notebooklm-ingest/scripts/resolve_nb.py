#!/usr/bin/env python3
"""Resolve a notebook selector to a single id.

stdin: `notebooklm list --json` output (array of notebooks, or a dict wrapping one).
argv[1]: selector — an id prefix OR a case-insensitive title substring.

Prints the matching id to stdout on a UNIQUE match (exit 0). On zero or
ambiguous matches, prints a diagnostic to stderr and exits nonzero.
"""
import json
import sys


def notebooks(payload):
    if isinstance(payload, list):
        return [n for n in payload if isinstance(n, dict)]
    if isinstance(payload, dict):
        for k in ("notebooks", "results", "items", "data"):
            v = payload.get(k)
            if isinstance(v, list):
                return [n for n in v if isinstance(n, dict)]
        if "id" in payload:
            return [payload]
    return []


def main():
    if len(sys.argv) < 2 or not sys.argv[1]:
        sys.exit("resolve_nb.py: missing selector")
    sel = sys.argv[1]
    sel_l = sel.lower()
    try:
        nbs = notebooks(json.load(sys.stdin))
    except Exception as e:
        sys.exit(f"resolve_nb.py: could not parse notebook list ({e})")

    matches = []
    for n in nbs:
        nid = str(n.get("id") or "")
        title = str(n.get("title") or "")
        if nid == sel or nid.startswith(sel) or sel_l in title.lower():
            matches.append((nid, title))

    if len(matches) == 1:
        print(matches[0][0])
        return
    if not matches:
        sys.exit(f"resolve_nb.py: no notebook matches '{sel}'. Run: notebooklm list")
    lines = "\n".join(f"  {i} — {t}" for i, t in matches)
    sys.exit(f"resolve_nb.py: '{sel}' is ambiguous, matches:\n{lines}\n"
             "Use a longer prefix or a fuller title.")


if __name__ == "__main__":
    main()
