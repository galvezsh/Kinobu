# Wallhaven (wallhaven.cc) for Seasons: searches its public API and downloads wallpapers.
# Written by Kinobu: rewritten on every run and --update.
#
# No account and no key: what Wallhaven shows anyone without signing in. Every category
# (general, anime, people), only pictures marked safe for work (purity=100: the others need an
# account), wide ones (ratios=landscape). The pictures are downloaded by the user, on their own
# computer; Kinobu ships none. Nothing personal is sent (a plain User-Agent).
import shutil
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request

API = "https://wallhaven.cc/api/v1/search"
AGENT = "Kinobu-Seasons/0.1"
TIMEOUT = 20
HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".cache", "kinobu", "wallhaven")
SORTINGS = ("random", "relevance", "toplist", "date_added", "favorites")
# The colours Wallhaven can search by (its own fixed list)
COLOURS = ("660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc",
           "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00",
           "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc",
           "ffffff", "424153")


class WallhavenError(Exception):
    pass


def _get(url):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return response.read(), response.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        if e.code == 429:
            raise WallhavenError("too many searches in a minute: wait a moment") from e
        raise WallhavenError(f"Wallhaven answered {e.code}") from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise WallhavenError("no connection to wallhaven.cc") from e


def search(query="", sorting="random", page=1, seed="", colour="", atleast="1920x1080"):
    """One page of results: (pictures, next) where next is (page, seed) or None at the end.
    Each picture: id, url (its page), path (the file), thumb, resolution, size, type."""
    if sorting not in SORTINGS:
        raise ValueError(f"sorting must be one of {', '.join(SORTINGS)}")
    params = {"categories": "111", "purity": "100", "ratios": "landscape", "sorting": sorting,
              "page": str(max(1, int(page)))}
    if query.strip():
        params["q"] = query.strip()[:100]
    if seed and re.fullmatch(r"[A-Za-z0-9]{6}", seed):
        params["seed"] = seed
    if colour and colour.lower().lstrip("#") in COLOURS:
        params["colors"] = colour.lower().lstrip("#")
    if atleast and re.fullmatch(r"\d{3,5}x\d{3,5}", atleast):
        params["atleast"] = atleast
    raw, _ = _get(API + "?" + urllib.parse.urlencode(params))
    try:
        data = json.loads(raw)
    except ValueError as e:
        raise WallhavenError("Wallhaven sent something unexpected") from e
    pictures = []
    for item in data.get("data", []):
        if item.get("purity") != "sfw" or not str(item.get("path", "")).startswith("https://"):
            continue   # a second check: only safe pictures, only over HTTPS
        pictures.append(_picture(item))
    meta = data.get("meta", {})
    more = meta.get("current_page", 1) < meta.get("last_page", 1)
    return pictures, ((meta.get("current_page", 1) + 1, meta.get("seed") or "") if more else None)


def _picture(item):
    return {"id": item["id"], "url": item.get("url", ""), "path": item["path"],
            "thumb": item.get("thumbs", {}).get("large", ""),
            "resolution": item.get("resolution", ""), "size": item.get("file_size", 0),
            "type": item.get("file_type", "")}


def picture(wallhaven_id):
    """One picture by its id (the end of its page's address: wallhaven.cc/w/<id>)."""
    if not re.fullmatch(r"[A-Za-z0-9]{4,12}", wallhaven_id or ""):
        raise WallhavenError(f"'{wallhaven_id}' is not a Wallhaven id")
    raw, _ = _get(f"https://wallhaven.cc/api/v1/w/{wallhaven_id}")
    try:
        item = json.loads(raw)["data"]
    except (ValueError, KeyError) as e:
        raise WallhavenError("Wallhaven sent something unexpected") from e
    if item.get("purity") != "sfw" or not str(item.get("path", "")).startswith("https://"):
        raise WallhavenError(f"{wallhaven_id} is not available")
    return _picture(item)


def _save(url, dest):
    if os.path.isfile(dest) and os.path.getsize(dest) > 0:
        return dest
    raw, kind = _get(url)
    if not kind.startswith("image/"):
        raise WallhavenError("the file is not a picture")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    with open(tmp, "wb") as f:
        f.write(raw)
    os.replace(tmp, dest)
    return dest


def thumbnail(picture):
    """The picture's thumbnail, kept in the cache folder."""
    name = re.sub(r"[^A-Za-z0-9]", "", picture["id"]) + ".jpg"
    return _save(picture["thumb"], os.path.join(CACHE, "thumbs", name))


def _name(picture):
    ext = os.path.splitext(urllib.parse.urlparse(picture["path"]).path)[1].lower()
    if ext not in (".jpg", ".jpeg", ".png", ".webp"):
        ext = ".jpg"
    return "wallhaven-" + re.sub(r"[^A-Za-z0-9]", "", picture["id"]) + ext


def full(picture):
    """The full picture in the cache folder, to look at it closely before using it."""
    return _save(picture["path"], os.path.join(CACHE, "full", _name(picture)))


def download(picture, folder):
    """The full picture, saved as wallhaven-<id>.<ext> in folder (kept if it is already there;
    copied from the cache when it was looked at before)."""
    dest = os.path.join(folder, _name(picture))
    cached = os.path.join(CACHE, "full", _name(picture))
    if not os.path.isfile(dest) and os.path.isfile(cached):
        os.makedirs(folder, exist_ok=True)
        shutil.copyfile(cached, dest + ".part")
        os.replace(dest + ".part", dest)
    return _save(picture["path"], dest)
