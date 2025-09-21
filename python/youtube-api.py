# youtube_fetch.py
# Standard-library YouTube Data API v3 client for stats + comments
# Usage (CLI):
#   export YT_API_KEY=YOUR_KEY
#   python youtube_fetch.py https://www.youtube.com/watch?v=dQw4w9WgXcQ --comments 10

import os, json, sys, time
from urllib.parse import urlencode, urlparse, parse_qs
from urllib.request import Request, urlopen

YOUTUBE_API = "https://www.googleapis.com/youtube/v3"

# ---------- low-level HTTP ----------

def http_get_json(path: str, params: dict, timeout: int = 12) -> dict:
    """GET {YOUTUBE_API}/{path}?params and return parsed JSON; raise on non-200."""
    url = f"{YOUTUBE_API}/{path}?{urlencode(params)}"
    req = Request(url, headers={"User-Agent": "yt-fetch/1.0"})
    with urlopen(req, timeout=timeout) as r:
        body = r.read().decode("utf-8")
        if r.status != 200:
            raise RuntimeError(f"HTTP {r.status}: {body[:200]}")
        return json.loads(body)

# ---------- helpers ----------

def extract_video_id(video: str) -> str:
    """
    Accept a video ID or a YouTube URL and return the video ID.
    Supports: https://www.youtube.com/watch?v=ID, youtu.be/ID, shorts/ID.
    """
    # Already looks like an ID (11 chars typical, but be permissive)
    if "/" not in video and "?" not in video and "&" not in video:
        return video

    u = urlparse(video)
    if "youtu.be" in u.netloc:
        return u.path.strip("/")

    if "youtube.com" in u.netloc:
        # watch?v=, shorts/, embed/
        qs = parse_qs(u.query)
        if "v" in qs:
            return qs["v"][0]
        parts = [p for p in u.path.split("/") if p]
        if parts and parts[0] in {"shorts", "embed"} and len(parts) > 1:
            return parts[1]
    raise ValueError(f"Could not extract video ID from: {video}")

# ---------- public API ----------

def get_video_stats(video: str, api_key: str | None = None) -> dict:
    """
    Return basic stats for a video: title, channel, publishedAt, viewCount, likeCount, commentCount.
    """
    api_key = api_key or os.getenv("YT_API_KEY")
    if not api_key:
        raise RuntimeError("Missing API key. Set YT_API_KEY or pass api_key=...")

    vid = extract_video_id(video)
    data = http_get_json(
        "videos",
        {
            "part": "snippet,statistics",
            "id": vid,
            "key": api_key,
        },
    )

    items = data.get("items", [])
    if not items:
        raise ValueError(f"No video found for id={vid}")

    item = items[0]
    snippet = item.get("snippet", {})
    stats = item.get("statistics", {})

    # likeCount may be absent if disabled; handle gracefully
    return {
        "video_id": vid,
        "title": snippet.get("title"),
        "channelTitle": snippet.get("channelTitle"),
        "publishedAt": snippet.get("publishedAt"),
        "viewCount": int(stats.get("viewCount", 0)),
        "likeCount": int(stats.get("likeCount", 0)) if "likeCount" in stats else None,
        "commentCount": int(stats.get("commentCount", 0)) if "commentCount" in stats else None,
    }

def get_top_comments(
    video: str,
    api_key: str | None = None,
    max_comments: int = 20,
    order: str = "relevance",  # "relevance" or "time"
    throttle_sec: float = 0.0,  # be nice if looping pages
) -> list[dict]:
    """
    Return top-level comments up to max_comments.
    Each item: {author, text, likeCount, publishedAt, updatedAt}
    """
    api_key = api_key or os.getenv("YT_API_KEY")
    if not api_key:
        raise RuntimeError("Missing API key. Set YT_API_KEY or pass api_key=...")

    vid = extract_video_id(video)
    results: list[dict] = []
    page_token = None

    while len(results) < max_comments:
        page_size = min(100, max_comments - len(results))
        params = {
            "part": "snippet",
            "videoId": vid,
            "maxResults": page_size,
            "order": order,
            "key": api_key,
        }
        if page_token:
            params["pageToken"] = page_token

        data = http_get_json("commentThreads", params)
        for it in data.get("items", []):
            sn = it["snippet"]["topLevelComment"]["snippet"]
            results.append(
                {
                    "author": sn.get("authorDisplayName"),
                    "text": sn.get("textDisplay"),  # HTML; use textOriginal for plain text
                    "likeCount": int(sn.get("likeCount", 0)),
                    "publishedAt": sn.get("publishedAt"),
                    "updatedAt": sn.get("updatedAt"),
                }
            )
            if len(results) >= max_comments:
                break

        page_token = data.get("nextPageToken")
        if not page_token:
            break
        if throttle_sec > 0:
            time.sleep(throttle_sec)

    return results

def get_video_with_comments(video: str, max_comments: int = 10, api_key: str | None = None) -> dict:
    """
    Convenience wrapper: returns stats + top comments in one dict.
    """
    stats = get_video_stats(video, api_key=api_key)
    comments = get_top_comments(video, api_key=api_key, max_comments=max_comments)
    return {"stats": stats, "comments": comments}

# ---------- CLI demo ----------

if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="Fetch YouTube stats and comments")
    p.add_argument("video", help="YouTube video ID or URL")
    p.add_argument("--comments", type=int, default=5, help="How many top-level comments to fetch")
    p.add_argument("--order", default="relevance", choices=["relevance", "time"])
    args = p.parse_args()

    out = get_video_with_comments(args.video, max_comments=args.comments)
    print(json.dumps(out, indent=2))