#!/usr/bin/env python3
"""
Fetches the latest uploads from a YouTube channel's RSS feed and merges
them into videos.yaml, which acts as an append-only local database next
to comment-tracker.html.

Existing entries are NEVER removed - only added or refreshed (title/
thumbnail) - so videos that drop out of YouTube's "15 most recent" feed
stay in the tracker permanently.

Setup:
    pip install pyyaml
    python3 fetch_videos.py          # run once to create videos.yaml

Then schedule it, e.g. with cron (every 30 minutes):
    */30 * * * * /usr/bin/python3 /path/to/fetch_videos.py >> /path/to/fetch_videos.log 2>&1
"""

import os
import sys
import urllib.request
import xml.etree.ElementTree as ET

import yaml

CHANNEL_ID = "UC7W5LTUy7DJYpx0cpVKJe0g"
FEED_URL = f"https://www.youtube.com/feeds/videos.xml?channel_id={CHANNEL_ID}"
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "site", "videos.yaml")

NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "yt": "http://www.youtube.com/xml/schemas/2015",
    "media": "http://search.yahoo.com/mrss/",
}


def fetch_feed():
    req = urllib.request.Request(FEED_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read()


def parse_feed(xml_bytes):
    root = ET.fromstring(xml_bytes)
    videos = []
    for entry in root.findall("atom:entry", NS):
        vid_id_el = entry.find("yt:videoId", NS)
        if vid_id_el is None or not vid_id_el.text:
            continue
        vid_id = vid_id_el.text
        title_el = entry.find("atom:title", NS)
        published_el = entry.find("atom:published", NS)
        thumb_el = entry.find("media:group/media:thumbnail", NS)
        videos.append({
            "id": vid_id,
            "title": title_el.text if title_el is not None and title_el.text else "Untitled",
            "published": published_el.text if published_el is not None else "",
            "thumb": thumb_el.get("url") if thumb_el is not None
                     else f"https://i.ytimg.com/vi/{vid_id}/mqdefault.jpg",
        })
    return videos


def load_db():
    if not os.path.exists(DB_PATH):
        return {}
    with open(DB_PATH, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    return {v["id"]: v for v in data.get("videos", []) if v.get("id")}


def save_db(videos_by_id):
    videos = sorted(videos_by_id.values(), key=lambda v: v.get("published", ""), reverse=True)
    with open(DB_PATH, "w", encoding="utf-8") as f:
        yaml.safe_dump({"videos": videos}, f, sort_keys=False, allow_unicode=True)


def main():
    try:
        xml_bytes = fetch_feed()
    except Exception as e:
        print(f"Fetch failed: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        fresh = parse_feed(xml_bytes)
    except ET.ParseError as e:
        print(f"Feed parse failed: {e}", file=sys.stderr)
        sys.exit(1)

    if not fresh:
        print("Feed returned no entries - not touching videos.yaml.", file=sys.stderr)
        sys.exit(1)

    db = load_db()
    added = 0
    for v in fresh:
        if v["id"] not in db:
            added += 1
        db[v["id"]] = v  # add new, and refresh title/thumb if it changed

    save_db(db)
    print(f"Synced. {added} new video(s), {len(db)} total tracked in videos.yaml.")


if __name__ == "__main__":
    main()
