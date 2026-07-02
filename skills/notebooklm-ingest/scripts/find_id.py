#!/usr/bin/env python3
"""Read a --json payload on stdin and print the first string `id` found (any depth)."""
import json
import sys


def find(o):
    if isinstance(o, dict):
        v = o.get("id")
        if isinstance(v, str) and v:
            return v
        for x in o.values():
            r = find(x)
            if r:
                return r
    elif isinstance(o, list):
        for x in o:
            r = find(x)
            if r:
                return r
    return None


try:
    print(find(json.load(sys.stdin)) or "")
except Exception:
    print("")
