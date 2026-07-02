#!/usr/bin/env python3
"""Read `notebooklm artifact list --type report --json` on stdin; print the
count of report artifacts (0 if none / unparseable)."""
import json
import sys


def items(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for k in ("artifacts", "results", "items", "data"):
            v = payload.get(k)
            if isinstance(v, list):
                return v
    return []


try:
    print(len(items(json.load(sys.stdin))))
except Exception:
    print(0)
