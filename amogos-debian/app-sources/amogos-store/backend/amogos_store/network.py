# Catalog requests use bounded responses and public HTTPS destinations, including redirects.
import hashlib
import html
import ipaddress
import json
import pathlib
import re
import socket
import time
import tempfile
import os
import urllib.parse
import urllib.request
from .runtime import StoreError

AGENT = "AmogOS-2-Pro-App-Store/0.1"


def public_url(url):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.port not in (None, 443):
        raise StoreError("The download source must use public HTTPS.")
    try:
        addresses = socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)
    except OSError as error:
        raise StoreError("The download host could not be reached.") from error
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):
        raise StoreError("Local and private download addresses are not supported.")
    return url


class PublicRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        public_url(url)
        return super().redirect_request(request, fp, code, message, headers, url)


def open_url(url, body=None, timeout=35):
    public_url(url)
    request = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers={"User-Agent": AGENT, "Accept": "application/json", "Content-Type": "application/json"})
    return urllib.request.build_opener(PublicRedirect()).open(request, timeout=timeout)


def cached(url, body=None):
    key=hashlib.sha256((url+json.dumps(body,sort_keys=True)).encode()).hexdigest()
    path=pathlib.Path.home()/".cache/amogos-store/catalog"/(key+".json")
    try:
        return json.loads(path.read_text())
    except (OSError,ValueError):
        return None


def fetch(url, body=None, age=900):
    key = hashlib.sha256((url+json.dumps(body, sort_keys=True)).encode()).hexdigest()
    cache = pathlib.Path.home()/".cache/amogos-store/catalog"
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = cache/(key+".json")
    if path.is_file() and time.time()-path.stat().st_mtime < age:
        try:
            return json.loads(path.read_text())
        except ValueError:
            pass
    try:
        with open_url(url, body) as response:
            raw = response.read(12*1024*1024+1)
        if len(raw)>12*1024*1024:
            raise StoreError("The catalog response was too large.")
        data = json.loads(raw)
        fd,temporary = tempfile.mkstemp(prefix=".catalog-",dir=cache)
        with os.fdopen(fd,"w") as file:
            json.dump(data,file)
        pathlib.Path(temporary).replace(path)
        return data
    except Exception as error:
        if path.is_file():
            data = json.loads(path.read_text())
            if isinstance(data, dict):
                data["_stale"] = True
            return data
        raise StoreError("This catalog is currently unavailable. Check your connection and try again.") from error


def plain(value):
    return html.unescape(re.sub(r"<[^>]+>", " ", str(value or ""))).strip()


def image_url(value):
    text = str(value or "")
    if text.startswith("http://"):
        text = "https://"+text[7:]
    return text if text.startswith("https://") else ""
