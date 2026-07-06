#!/usr/bin/env python3
"""Read `notebooklm metadata --json` on stdin; emit slug, title, and sources.

Output (one per line):
  line 1: slug (filesystem-safe, from title)
  line 2: title
  line 3+: each source (url if present, else source title)
"""
import json
import re
import sys


def find_title(o):
    if isinstance(o, dict):
        t = o.get("title")
        if isinstance(t, str) and t:
            return t
        for v in o.values():
            r = find_title(v)
            if r:
                return r
    elif isinstance(o, list):
        for x in o:
            r = find_title(x)
            if r:
                return r
    return None


def collect_sources(o, out):
    if isinstance(o, dict):
        srcs = o.get("sources")
        if isinstance(srcs, list):
            for s in srcs:
                if isinstance(s, dict):
                    out.append(s.get("url") or s.get("title") or "")
                elif isinstance(s, str):
                    out.append(s)
        for v in o.values():
            collect_sources(v, out)
    elif isinstance(o, list):
        for x in o:
            collect_sources(x, out)


def flat(s):
    """One line per value: the output contract is line-based, so embedded
    newlines/control chars in untrusted metadata must never split a field."""
    return " ".join(str(s).split())


def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        d = {}
    title = flat(find_title(d) or "notebooklm")
    sources = []
    collect_sources(d, sources)
    sources = [flat(s) for s in sources]
    slug = re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", title.lower())).strip("-") or "notebooklm"
    print(slug)
    print(title)
    seen = set()
    for s in sources:
        if s and s not in seen:
            seen.add(s)
            print(s)


if __name__ == "__main__":
    main()
