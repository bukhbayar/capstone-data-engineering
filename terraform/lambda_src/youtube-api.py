import os, json, csv, io, time
from urllib.parse import urlencode, urlparse, parse_qs
from urllib.request import Request, urlopen

import boto3

YOUTUBE_API = "https://www.googleapis.com/youtube/v3"

def http_get_json(path: str, params: dict, timeout: int = 12) -> dict:
    url = f"{YOUTUBE_API}/{path}?{urlencode(params)}"
    req = Request(url, headers={"User-Agent": "yt-lambda/1.0"})
    with urlopen(req, timeout=timeout) as r:
        body = r.read().decode("utf-8")
        if r.status != 200:
            raise RuntimeError(f"HTTP {r.status}: {body[:200]}")
        return json.loads(body)

def get_secret_value(secret_name: str) -> str:
    sm = boto3.client("secretsmanager")
    resp = sm.get_secret_value(SecretId=secret_name)
    secret = resp.get("SecretString", "")
    # accept raw string or {"api_key":"..."}
    try:
        j = json.loads(secret)
        return j.get("api_key", secret)
    except Exception:
        return secret

def search_videos(api_key: str, query: str, max_results: int = 5) -> list[dict]:
    data = http_get_json(
        "search",
        {
            "part": "snippet",
            "q": query,
            "type": "video",
            "maxResults": max(1, min(50, max_results)),
            "key": api_key,
        },
    )
    vids = []
    for it in data.get("items", []):
        try:
            # Add defensive programming
            if "id" not in it or "videoId" not in it["id"]:
                print(f"Skipping item without videoId: {json.dumps(it)}")
                continue

            vids.append({
                "video_id": it["id"]["videoId"],
                "title": it.get("snippet", {}).get("title", ""),
                "channelTitle": it.get("snippet", {}).get("channelTitle", ""),
                "publishedAt": it.get("snippet", {}).get("publishedAt", ""),
            })
        except Exception as e:
            print(f"Error processing video item: {str(e)}")
            print(f"Problem item: {json.dumps(it)}")
            continue

    return vids

def get_video_stats(api_key: str, video_ids: list[str]) -> dict[str, dict]:
    if not video_ids:
        return {}
    data = http_get_json(
        "videos",
        {
            "part": "statistics",
            "id": ",".join(video_ids),
            "key": api_key,
        },
    )
    out = {}
    for it in data.get("items", []):
        stats = it.get("statistics", {})
        out[it["id"]] = {
            "viewCount": int(stats.get("viewCount", 0)),
            "likeCount": int(stats.get("likeCount")) if "likeCount" in stats else None,
            "commentCount": int(stats.get("commentCount")) if "commentCount" in stats else None,
        }
    return out

def get_top_comments(api_key: str, video_id: str, max_comments: int = 10) -> list[dict]:
    results, token = [], None
    remaining = max(0, max_comments)
    while remaining > 0:
        page_size = min(100, remaining)
        params = {
            "part": "snippet",
            "videoId": video_id,
            "maxResults": page_size,
            "order": "relevance",
            "key": api_key,
        }
        if token: params["pageToken"] = token
        data = http_get_json("commentThreads", params)
        for it in data.get("items", []):
            sn = it["snippet"]["topLevelComment"]["snippet"]
            results.append({
                "video_id": video_id,
                "author": sn.get("authorDisplayName"),
                "text": sn.get("textOriginal"),
                "likeCount": int(sn.get("likeCount", 0)),
                "publishedAt": sn.get("publishedAt"),
            })
            remaining -= 1
            if remaining <= 0:
                break
        token = data.get("nextPageToken")
        if not token:
            break
        time.sleep(0.1)
    return results

def put_s3_json(bucket: str, key: str, obj: dict):
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(obj, ensure_ascii=False, indent=2).encode("utf-8"),
        ContentType="application/json; charset=utf-8",
    )

def put_s3_csv(bucket: str, key: str, rows: list[dict]):
    if not rows:
        rows = []
    fieldnames = sorted({k for r in rows for k in r.keys()}) if rows else []
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=fieldnames)
    if fieldnames:
        w.writeheader()
        for r in rows:
            w.writerow(r)
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=buf.getvalue().encode("utf-8"),
        ContentType="text/csv; charset=utf-8",
    )

def handler(event, context):
    secret_name   = os.environ["SECRET_NAME"]
    bucket        = os.environ["OUTPUT_BUCKET"]
    prefix        = os.environ.get("OUTPUT_PREFIX", "youtube/output").rstrip("/")
    query         = os.environ.get("YT_QUERY", "data engineering")
    max_videos    = int(os.environ.get("MAX_VIDEOS", "5"))
    max_comments  = int(os.environ.get("MAX_COMMENTS", "10"))

    api_key = get_secret_value(secret_name)
    if not api_key:
        return {"statusCode": 400, "body": "Missing API key in Secrets Manager"}

    # Search videos
    videos = search_videos(api_key, query, max_videos)
    stats  = get_video_stats(api_key, [v["video_id"] for v in videos])

    # Attach stats and collect comments
    all_comments = []
    for v in videos:
        s = stats.get(v["video_id"], {})
        v.update(s)
        if max_comments > 0:
            all_comments.extend(get_top_comments(api_key, v["video_id"], max_comments))

    # Write to S3 (timestamped keys)
    ts = time.strftime("%Y%m%dT%H%M%S")
    base = f"{prefix}/{ts}_{query.replace(' ','_')}"

    put_s3_json(bucket, f"{base}_videos.json", {"query": query, "videos": videos})
    put_s3_csv(bucket,  f"{base}_videos.csv",  videos)
    put_s3_json(bucket, f"{base}_comments.json", {"query": query, "comments": all_comments})
    put_s3_csv(bucket,  f"{base}_comments.csv",  all_comments)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "query": query,
            "videos_written": len(videos),
            "comments_written": len(all_comments),
            "s3_prefix": f"s3://{bucket}/{prefix}/"
        })
    }