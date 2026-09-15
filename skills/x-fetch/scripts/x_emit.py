#!/usr/bin/env python3
"""Turn yt-dlp info.json files for ONE X post (+ optional transcripts) into a
wiki-ingest-ready markdown doc.

Usage:
  x_emit.py --videos <meta-dir>                       # video entry ids, one per line
  x_emit.py <meta-dir> <transcript-dir> <status-id>   # markdown doc -> stdout

<meta-dir> holds the *.info.json yt-dlp wrote for the post. A text-only post
yields one file; a multi-video post yields one playlist file plus one per clip.
<transcript-dir> holds <video-id>.txt files produced by whisperkit-cli (may be
empty or missing). Nothing is written to disk; the caller redirects stdout into
.raw/posts/ exactly like yt-fetch / defuddle.
"""
import datetime
import glob
import json
import os
import re
import sys


def flat(s):
    """Collapse untrusted metadata to a single line (no control chars)."""
    return re.sub(r"[\x00-\x1f\x7f]+", " ", str(s or "")).strip()


def body_text(s):
    """Keep newlines in post text, drop every other control character."""
    s = str(s or "").replace("\r\n", "\n").replace("\r", "\n")
    return re.sub(r"[\x00-\x09\x0b-\x1f\x7f]+", " ", s).strip()


def load_entries(meta_dir):
    entries = []
    for path in sorted(glob.glob(os.path.join(meta_dir, "*.info.json"))):
        try:
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
        except (OSError, ValueError):
            continue
        if isinstance(d, dict):
            entries.append(d)
    return entries


def video_entries(entries):
    vids = [e for e in entries if e.get("formats")]

    def order(e):
        m = re.search(r"#(\d+)\s*$", str(e.get("title") or ""))
        return (int(m.group(1)) if m else 0, str(e.get("id") or ""))

    return sorted(vids, key=order)


def post_entry(entries, status_id):
    for e in entries:
        if e.get("_type") == "playlist":
            return e
    for e in entries:
        if str(e.get("id") or "") == status_id:
            return e
    return entries[0] if entries else {}


def fmt_date(upload_date):
    up = str(upload_date or "")
    if len(up) == 8 and up.isdigit():
        return f"{up[0:4]}-{up[4:6]}-{up[6:8]}"
    return ""


def fmt_duration(entry):
    """m:ss (or h:mm:ss) from yt-dlp's numeric duration; '' when unknown."""
    d = entry.get("duration")
    if not isinstance(d, (int, float)) or d < 0:
        return ""
    d = int(round(d))
    h, rem = divmod(d, 3600)
    m, sec = divmod(rem, 60)
    return f"{h}:{m:02d}:{sec:02d}" if h else f"{m}:{sec:02d}"


def load_meta(post, status_id):
    # webpage_url is extractor-supplied metadata (untrusted like title/author):
    # flatten control chars and require a plain http(s) URL, else fall back to
    # the canonical x.com form built from the status id.
    url = flat(post.get("webpage_url"))
    if not re.match(r"^https?://\S+$", url):
        url = f"https://x.com/i/status/{status_id}" if status_id else ""
    handle = flat(post.get("uploader_id")).lstrip("@")
    name = flat(post.get("uploader") or post.get("channel")) or handle
    text = body_text(post.get("description"))
    snippet = flat(text.split("\n", 1)[0])
    if len(snippet) > 80:
        snippet = snippet[:79].rstrip() + "…"
    if snippet:
        title = f"{name} on X: {snippet}"
    else:
        title = f"{name} on X: post {status_id}".strip()
    return {
        "title": title,
        "name": name,
        "handle": handle,
        "date_published": fmt_date(post.get("upload_date")),
        "url": url,
        "text": text,
        "likes": post.get("like_count"),
        "reposts": post.get("repost_count"),
    }


def read_transcript(tx_dir, vid):
    path = os.path.join(tx_dir, f"{vid}.txt")
    try:
        with open(path, encoding="utf-8") as f:
            t = f.read()
    except (OSError, ValueError):
        return ""
    t = re.sub(r"[ \t]+$", "", body_text(t), flags=re.M)
    return t if t.strip() else ""


def main():
    argv = sys.argv[1:]
    if len(argv) == 2 and argv[0] == "--videos":
        for e in video_entries(load_entries(argv[1])):
            print(flat(e.get("id")))
        return
    if len(argv) != 3:
        sys.exit("usage: x_emit.py --videos <meta-dir> | x_emit.py <meta-dir> <transcript-dir> <status-id>")

    meta_dir, tx_dir, status_id = argv
    status_id = re.sub(r"\D", "", status_id)
    entries = load_entries(meta_dir)
    if not entries:
        sys.exit("x_emit.py: no info.json found")
    post = post_entry(entries, status_id)
    videos = video_entries(entries)
    meta = load_meta(post, status_id)
    transcripts = [(v, read_transcript(tx_dir, flat(v.get("id")))) for v in videos]
    transcribed = any(t for _, t in transcripts)
    today = datetime.date.today().isoformat()

    # json.dumps yields a correctly escaped YAML double-quoted scalar — a title
    # containing quotes or trailing backslashes can't break out of the frontmatter.
    print("---")
    print(f"source_url: {json.dumps(meta['url'])}")
    print(f"url: {json.dumps(meta['url'])}")
    print("source_type: post")
    print("platform: x")
    print(f"post_id: {json.dumps(status_id)}")
    print(f"title: {json.dumps(meta['title'])}")
    print(f"author: {json.dumps(meta['name'])}")
    print(f"author_handle: {json.dumps(meta['handle'])}")
    print(f"date_published: {meta['date_published']}")
    print(f"fetched: {today}")
    print(f"has_video: {'true' if videos else 'false'}")
    print(f"video_count: {len(videos)}")
    if transcribed:
        print("transcriber: whisperkit-cli (on-device)")
    print("tags:")
    print("  - source")
    print("  - post")
    print("  - x")
    if videos:
        print("  - video")
    print("---")
    print()
    print(f"# {meta['title']}")
    print()

    byline = []
    if meta["handle"]:
        byline.append(f"@{meta['handle']}")
    if meta["date_published"]:
        byline.append(f"Posted: {meta['date_published']}")
    if videos:
        byline.append("1 video" if len(videos) == 1 else f"{len(videos)} videos")
    if isinstance(meta["likes"], int):
        byline.append(f"Likes: {meta['likes']}")
    if isinstance(meta["reposts"], int):
        byline.append(f"Reposts: {meta['reposts']}")
    if byline:
        print(f"_{' · '.join(byline)}_")
        print()

    print("## Post")
    print()
    if meta["text"]:
        # Blockquote the post verbatim: it reads as "the post said", and a
        # hostile post can't inject headings, frontmatter fences, or callouts
        # into the document's own structure.
        for line in meta["text"].split("\n"):
            print(f"> {line}".rstrip())
    else:
        print("> [!warning] No post text could be read (media-only post, or the "
              "extractor returned nothing). Ingest metadata only or add a manual summary.")
    print()

    if videos and not transcribed:
        clips = ", ".join(
            f"clip {i} ({fmt_duration(v) or 'unknown length'})" for i, (v, _) in enumerate(transcripts, 1))
        print("> [!warning] This post carries video but no transcript was produced — "
              "the Voice feature (`whisperkit-cli`) is not installed, transcription was "
              "skipped, or it failed. Ingest the post text only, or enable Voice via "
              "`/secondbrain` and re-run x-fetch.")
        print(f"> Video: {clips}.")
        print()
        return

    for i, (v, t) in enumerate(transcripts, 1):
        heading = "Video transcript" if len(transcripts) == 1 else f"Video {i} transcript"
        print(f"## {heading}")
        print()
        dur = fmt_duration(v)
        if t:
            print(f"_Duration: {dur or 'unknown'} · Transcribed on-device (whisperkit-cli)_")
            print()
            print(t)
        else:
            print(f"> [!warning] No transcript for this clip ({dur or 'unknown length'}: "
                  "silent, music-only, or transcription failed).")
        print()

if __name__ == "__main__":
    main()
