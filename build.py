"""Build index.html from src/page.html, the map outlines in src/uk.json,
the city list in src/towns.json, the roads in src/roads.json, the plate
rules in supabase/functions/confirm-plate/plates.js and the database
address in src/config.json.

Run: python3 build.py
Writes index.html (the full page, the live site) and preview.html (the same
page without the <html>/<head> wrapper and without the database address, for
the claude.ai artifact preview, which plays on one device only).
"""
import json
from pathlib import Path

root = Path(__file__).parent
page = (root / "src" / "page.html").read_text()
plates = (root / "supabase" / "functions" / "confirm-plate" / "plates.js").read_text().replace("export function", "function")
config = json.loads((root / "src" / "config.json").read_text())


def fill(cfg):
    return (page.replace("__PATHS__", (root / "src" / "uk.json").read_text().strip())
                .replace("__TOWNS__", (root / "src" / "towns.json").read_text(encoding="utf-8").strip())
                .replace("__ROADS__", (root / "src" / "roads.json").read_text().strip())
                .replace("__PLATES__", plates.strip())
                .replace("__CONFIG__", json.dumps(cfg)))


head, rest = fill(config).split("<!-- page -->", 1)
full = (
    "<!doctype html>\n<html lang=\"en-GB\">\n<head>\n<meta charset=\"utf-8\">\n"
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n"
    + head + "</head>\n<body>\n" + rest + "\n</body>\n</html>\n"
)
(root / "index.html").write_text(full)
(root / "preview.html").write_text(fill({"supabaseUrl": "", "supabaseKey": ""}))
print("Built index.html and preview.html")
