"""Build index.html from src/page.html and the map outlines in src/uk.json.

Run: python3 build.py
Writes index.html (the full page) and preview.html (the same page without
the <html>/<head> wrapper, for publishing as a claude.ai artifact).
"""
from pathlib import Path

root = Path(__file__).parent
page = (root / "src" / "page.html").read_text()
paths = (root / "src" / "uk.json").read_text().strip()
body = page.replace("__PATHS__", paths)

head, rest = body.split("<!-- page -->", 1)
full = (
    "<!doctype html>\n<html lang=\"en-GB\">\n<head>\n<meta charset=\"utf-8\">\n"
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
    + head + "</head>\n<body>\n" + rest + "\n</body>\n</html>\n"
)
(root / "index.html").write_text(full)
(root / "preview.html").write_text(body)
print("Built index.html and preview.html")
