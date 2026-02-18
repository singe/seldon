#!/usr/bin/env python3
import html
import re
import sys
import urllib.parse
import urllib.request
from html.parser import HTMLParser


class DuckDuckGoHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.results = []
        self._in_title = False
        self._title_parts = []
        self._snippet_parts = []
        self._current_url = None
        self._capture_snippet = False

    def handle_starttag(self, tag, attrs):
        attrs_map = dict(attrs)
        class_attr = attrs_map.get("class", "")

        if tag == "a" and "result__a" in class_attr:
            self._in_title = True
            self._title_parts = []
            self._snippet_parts = []
            self._capture_snippet = False
            self._current_url = normalize_result_url(attrs_map.get("href", ""))
            return

        if tag in {"a", "div"} and (
            "result__snippet" in class_attr or
            "result-snippet" in class_attr
        ):
            self._capture_snippet = True

    def handle_data(self, data):
        text = data.strip()
        if not text:
            return
        if self._in_title:
            self._title_parts.append(text)
        elif self._capture_snippet and self._current_url:
            self._snippet_parts.append(text)

    def handle_endtag(self, tag):
        if tag == "a" and self._in_title:
            self._in_title = False
            title = " ".join(self._title_parts).strip()
            if title and self._current_url:
                self.results.append({
                    "title": html.unescape(title),
                    "url": self._current_url,
                    "snippet": "",
                })
            return

        if tag in {"a", "div"} and self._capture_snippet:
            self._capture_snippet = False
            snippet = " ".join(self._snippet_parts).strip()
            if snippet and self.results:
                self.results[-1]["snippet"] = html.unescape(snippet)
            self._snippet_parts = []


def normalize_result_url(url: str) -> str:
    if not url:
        return ""

    parsed = urllib.parse.urlparse(url)

    if parsed.netloc.endswith("duckduckgo.com") and parsed.path.startswith("/l/"):
        query = urllib.parse.parse_qs(parsed.query)
        target = query.get("uddg", [""])[0]
        if target:
            return urllib.parse.unquote(target)

    if url.startswith("//"):
        return "https:" + url

    return url


def search(query: str, n: int) -> str:
    encoded = urllib.parse.quote_plus(query)
    url = f"https://duckduckgo.com/html/?q={encoded}"

    request = urllib.request.Request(url, headers={"User-Agent": "seldon-tools/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        body = response.read().decode("utf-8", errors="replace")

    parser = DuckDuckGoHTMLParser()
    parser.feed(body)

    # Fallback for minor markup drift.
    if not parser.results:
        pattern = re.compile(
            r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
            flags=re.I | re.S,
        )
        for match in pattern.finditer(body):
            href = normalize_result_url(html.unescape(match.group(1)))
            title = re.sub(r"<[^>]+>", "", match.group(2)).strip()
            title = html.unescape(title)
            if href and title:
                parser.results.append({"title": title, "url": href, "snippet": ""})
            if len(parser.results) >= n:
                break

    if not parser.results:
        return f"No results found for: {query}"

    lines = [f"Top {min(n, len(parser.results))} results for '{query}':"]
    for idx, result in enumerate(parser.results[:n], start=1):
        lines.append(f"{idx}. {result['title']}\n   URL: {result['url']}")
        if result["snippet"]:
            lines.append(f"   {result['snippet']}")

    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: web_search.py <search_terms> <n>", file=sys.stderr)
        return 2

    query = sys.argv[1].strip()
    if not query:
        print("search_terms must be non-empty", file=sys.stderr)
        return 2

    try:
        n = int(sys.argv[2])
    except ValueError:
        print("n must be an integer", file=sys.stderr)
        return 2

    if n <= 0:
        print("n must be greater than 0", file=sys.stderr)
        return 2

    try:
        print(search(query, n))
    except Exception as error:
        print(f"web_search failed: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
