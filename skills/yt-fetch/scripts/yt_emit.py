#!/usr/bin/env python3
"""Turn a yt-dlp info.json + auto-sub .vtt into a wiki-ingest-ready markdown doc.

Usage: yt_emit.py <info.json> [<subtitles.vtt>]

Prints YAML frontmatter (matching the raw-source schema wiki-ingest expects)
followed by the cleaned transcript body to stdout. Nothing is written to disk;
the caller redirects stdout into .raw/videos/ exactly like defuddle.
"""
import datetime
import json
import re
import sys


def load_meta(info_path):
    with open(info_path, encoding="utf-8") as f:
        d = json.load(f)
    up = d.get("upload_date") or ""
    if len(up) == 8:
        up = f"{up[0:4]}-{up[4:6]}-{up[6:8]}"
    else:
        up = ""
    return {
        "title": (d.get("title") or "").strip(),
        "author": (d.get("uploader") or d.get("channel") or "").strip(),
        "date_published": up,
        "url": (d.get("webpage_url") or "").strip(),
        "duration": d.get("duration_string") or "",
    }


def clean_vtt(vtt_path):
    """Strip WEBVTT cruft and collapse YouTube's rolling auto-caption repeats."""
    raw_lines = []
    with open(vtt_path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith(("WEBVTT", "NOTE", "STYLE", "Kind:", "Language:")):
                continue
            if "-->" in line:
                continue
            if re.match(r"^\d+$", line):  # cue index
                continue
            line = re.sub(r"<[^>]+>", "", line)  # inline word-timing tags
            line = line.strip()
            if line:
                raw_lines.append(line)

    # Collapse the incremental reveal pattern (prev is a prefix of cur, etc.)
    out = []
    for l in raw_lines:
        if out:
            if l == out[-1]:
                continue
            if l.startswith(out[-1]):
                out[-1] = l  # rolling extension of the same caption
                continue
            if out[-1].startswith(l):
                continue  # shorter prefix of what we already kept
        out.append(l)
    return "\n".join(out)


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: yt_emit.py <info.json> [<subtitles.vtt>]")
    meta = load_meta(sys.argv[1])
    body = ""
    if len(sys.argv) > 2 and sys.argv[2]:
        try:
            body = clean_vtt(sys.argv[2])
        except FileNotFoundError:
            body = ""

    today = datetime.date.today().isoformat()
    title = meta["title"].replace('"', "'")
    author = meta["author"].replace('"', "'")

    print("---")
    print(f"source_url: {meta['url']}")
    print(f"url: {meta['url']}")
    print("source_type: video")
    print(f'title: "{title}"')
    print(f'author: "{author}"')
    print(f"date_published: {meta['date_published']}")
    print(f"fetched: {today}")
    print("tags:")
    print("  - source")
    print("  - video")
    print("---")
    print()
    if not body:
        print("> [!warning] No captions were available for this video. "
              "The transcript is empty; ingest metadata only or add a manual summary.")
    else:
        print(f"# {meta['title']}\n")
        if meta["duration"]:
            print(f"_Channel: {meta['author']} · Duration: {meta['duration']} · "
                  f"Published: {meta['date_published']}_\n")
        print(body)


if __name__ == "__main__":
    main()
