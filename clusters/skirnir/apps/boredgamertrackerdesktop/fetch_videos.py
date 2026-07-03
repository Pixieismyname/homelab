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

import json
import os
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

import yaml

CHANNEL_ID = "UC7W5LTUy7DJYpx0cpVKJe0g"
FEED_URL = f"https://www.youtube.com/feeds/videos.xml?channel_id={CHANNEL_ID}"
SITE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "site")
DB_PATH = os.path.join(SITE_DIR, "videos.yaml")
KEY_PATH = os.path.join(SITE_DIR, "key.json")

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


def _api_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def load_key_config():
    if not os.path.exists(KEY_PATH):
        return {}
    with open(KEY_PATH, "r", encoding="utf-8") as f:
        return json.load(f) or {}


def resolve_channel_id(api_key, handle_raw):
    handle = handle_raw.strip()
    if re.match(r"^UC[\w-]{20,}$", handle):
        return handle
    cleaned = handle.lstrip("@")
    url = ("https://www.googleapis.com/youtube/v3/channels"
           f"?part=id&forHandle={urllib.parse.quote(cleaned)}&key={urllib.parse.quote(api_key)}")
    data = _api_get(url)
    items = data.get("items") or []
    if not items:
        raise RuntimeError("handle not found")
    return items[0]["id"]


def check_video_commented(video_id, api_key, channel_id):
    """Mirrors the client-side check in comment-tracker.html: scans up to
    3 pages (300 comments) of top-level commentThreads for a match on
    authorChannelId, newest first."""
    page_token = ""
    for _ in range(3):
        url = ("https://www.googleapis.com/youtube/v3/commentThreads"
               f"?part=snippet&videoId={video_id}&maxResults=100&order=time"
               f"&key={urllib.parse.quote(api_key)}")
        if page_token:
            url += f"&pageToken={page_token}"
        data = _api_get(url)
        for item in data.get("items", []):
            top = (item.get("snippet") or {}).get("topLevelComment", {}).get("snippet", {})
            author = (top.get("authorChannelId") or {}).get("value")
            if author == channel_id:
                return True
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    return False


def verify_comments(db):
    """Auto-checks (via the YouTube Data API) whether the configured channel
    has commented on each video not already confirmed, and writes the result
    into each entry as `commented: true/false` so it's shared across devices
    instead of living only in a single browser's local storage. Skips videos
    already confirmed True to keep API quota use bounded and shrinking over
    time as more videos get confirmed."""
    cfg = load_key_config()
    api_key = cfg.get("apiKey")
    handle = cfg.get("handle")
    if not api_key or not handle:
        print("No API key/handle saved yet - skipping comment verification.", file=sys.stderr)
        return 0

    try:
        channel_id = resolve_channel_id(api_key, handle)
    except Exception as e:
        print(f"Could not resolve channel id for '{handle}': {e}", file=sys.stderr)
        return 0

    checked = 0
    for v in db.values():
        if v.get("commented"):
            continue
        try:
            v["commented"] = check_video_commented(v["id"], api_key, channel_id)
            checked += 1
        except Exception as e:
            print(f"Comment check failed for {v['id']}: {e}", file=sys.stderr)
    return checked


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
        prev_commented = db.get(v["id"], {}).get("commented")
        if prev_commented is not None:
            v["commented"] = prev_commented
        db[v["id"]] = v  # add new, and refresh title/thumb if it changed

    checked = verify_comments(db)

    save_db(db)
    print(f"Synced. {added} new video(s), {len(db)} total tracked in videos.yaml. "
          f"Checked comments on {checked} video(s).")


if __name__ == "__main__":
    main()
