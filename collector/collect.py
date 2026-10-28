"""Collects YouTube + sentiment stats per contestant and updates data.json.
Env: YOUTUBE_API_KEY (required), GEMINI_API_KEY (optional, sentiment).
No third-party dependencies."""
import json, os, re, datetime as dt, urllib.request, urllib.parse

YT = os.environ["YOUTUBE_API_KEY"]
GEM = os.environ.get("GEMINI_API_KEY")
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
SHOW = os.environ.get("SHOW_NAME", "Bigg Boss")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)

def yt(path, **p):
    p["key"] = YT
    return get(f"https://www.googleapis.com/youtube/v3/{path}?" + urllib.parse.urlencode(p))

def seconds(iso):
    m = re.match(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", iso)
    h, mi, s = (int(x or 0) for x in m.groups())
    return h * 3600 + mi * 60 + s

def positive_ratio(comments):
    """AI step: Gemini returns share of positive comments (0..1)."""
    if not GEM or not comments:
        return 0.5
    prompt = ("Classify each comment as positive or negative about the person. "
              "Reply ONLY with the fraction positive as a number 0-1.\n\n" + "\n".join(comments[:40]))
    body = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode()
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={GEM}",
        body, {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            t = json.load(r)["candidates"][0]["content"]["parts"][0]["text"]
        return min(1.0, max(0.0, float(re.search(r"[\d.]+", t).group())))
    except Exception:
        return 0.5

def collect(name):
    since = (dt.datetime.utcnow() - dt.timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    s = yt("search", part="id", q=f"{name} {SHOW}", type="video",
           publishedAfter=since, maxResults=25, order="viewCount")
    ids = [i["id"]["videoId"] for i in s.get("items", [])]
    videos = shorts = comments = 0
    sample = []
    if ids:
        v = yt("videos", part="contentDetails,statistics", id=",".join(ids))
        for it in v["items"]:
            if seconds(it["contentDetails"]["duration"]) <= 60:
                shorts += 1
            else:
                videos += 1
            comments += int(it["statistics"].get("commentCount", 0))
        try:
            c = yt("commentThreads", part="snippet", videoId=ids[0], maxResults=40, order="relevance")
            sample = [x["snippet"]["topLevelComment"]["snippet"]["textDisplay"][:200] for x in c["items"]]
        except Exception:
            pass
    pos = positive_ratio(sample)
    # Instagram/Facebook posts: add counts here once Meta Graph API is approved.
    ig_fb = 0
    score = round(5 * videos + 3 * shorts + 4 * ig_fb + 0.02 * comments * (0.5 + pos), 1)
    return dict(videos=videos, shorts=shorts, comments=comments, ig_fb=ig_fb,
                positive=round(pos, 2), score=score)

def main():
    names = json.load(open(os.path.join(ROOT, "contestants.json")))
    path = os.path.join(ROOT, "data.json")
    data = json.load(open(path)) if os.path.exists(path) else {"contestants": {}}
    today = dt.date.today().isoformat()
    for n in names:
        data["contestants"].setdefault(n, {})[today] = collect(n)
    data["updated"] = dt.datetime.utcnow().isoformat() + "Z"
    json.dump(data, open(path, "w"), indent=1)

if __name__ == "__main__":
    main()
