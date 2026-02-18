#!/usr/bin/env python3
import html
import re
import sys
import urllib.parse
import urllib.request
import urllib.error
from html.parser import HTMLParser


class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self._parts = []
        self._skip_depth = 0
        self._skip_tags = {"script", "style", "noscript", "template", "svg"}
        self._block_tags = {
            "p", "div", "section", "article", "header", "footer", "aside",
            "li", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "h6", "pre",
            "blockquote", "tr", "table", "br", "hr"
        }

    def handle_starttag(self, tag, attrs):
        lower = tag.lower()
        if lower in self._skip_tags:
            self._skip_depth += 1
            return
        if self._skip_depth == 0 and lower in self._block_tags:
            self._parts.append("\n")

    def handle_endtag(self, tag):
        lower = tag.lower()
        if lower in self._skip_tags and self._skip_depth > 0:
            self._skip_depth -= 1
            return
        if self._skip_depth == 0 and lower in self._block_tags:
            self._parts.append("\n")

    def handle_data(self, data):
        if self._skip_depth > 0:
            return
        text = data.strip()
        if text:
            self._parts.append(text)

    def text(self):
        merged = " ".join(self._parts)
        merged = re.sub(r"[ \t]+\n", "\n", merged)
        merged = re.sub(r"\n[ \t]+", "\n", merged)
        merged = re.sub(r"\n{3,}", "\n\n", merged)
        return merged.strip()


def normalize_url(url: str) -> str:
    cleaned = url.strip()
    cleaned = cleaned.strip("<>[](){}\"'")
    cleaned = cleaned.rstrip(".,;:")

    # Handle DuckDuckGo redirect links if the model passes one directly.
    if "duckduckgo.com/l/?" in cleaned:
        parsed_redirect = urllib.parse.urlparse(cleaned)
        query = urllib.parse.parse_qs(parsed_redirect.query)
        unwrapped = query.get("uddg", [""])[0]
        if unwrapped:
            cleaned = urllib.parse.unquote(unwrapped)

    parsed = urllib.parse.urlparse(cleaned)
    if parsed.scheme:
        return cleaned

    # Support input like "sensepost.com" or "sensepost.com/path".
    if parsed.netloc:
        return "https://" + parsed.netloc + parsed.path

    return "https://" + cleaned


def request_headers() -> dict:
    return {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/122.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
    }


def fetch(url: str, max_chars: int = 8000) -> str:
    normalized = normalize_url(url)
    request = urllib.request.Request(normalized, headers=request_headers())
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            content_type = response.headers.get("Content-Type", "")
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        if error.code == 999:
            raise RuntimeError(
                "HTTP 999 (request denied). This site is blocking automated fetches; try another result URL."
            ) from error
        raise

    if "html" in content_type.lower() or re.search(r"<html|<body|<p|<script|<style", body, flags=re.I):
        parser = TextExtractor()
        parser.feed(body)
        text = html.unescape(parser.text())
    else:
        text = body

    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    if len(text) > max_chars:
        text = text[:max_chars] + "\n\n[truncated]"
    return text


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: fetch_url.py <url>", file=sys.stderr)
        return 2

    url = sys.argv[1].strip()
    if not url:
        print("url must be non-empty", file=sys.stderr)
        return 2

    try:
        print(fetch(url))
    except Exception as error:
        print(f"fetch_url failed: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
