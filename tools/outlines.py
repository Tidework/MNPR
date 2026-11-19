"""Make src/uk.json: UK, Ireland and Isle of Man outlines as SVG path strings,
projected for the app's map and simplified.

Source: Natural Earth 1:10m admin 0 countries (public domain), e.g.
https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries.geojson

Run: python3 tools/outlines.py ne_10m_admin_0_countries.geojson src/uk.json [tolerance]
The projection must match K, LON0, LAT1 and S in src/page.html.
"""
import json, math, sys

K = math.cos(math.radians(54.5))
LON0, LAT1, S = -11.0, 61.0, 100


def proj(lon, lat):
    return ((lon - LON0) * K * S, (LAT1 - lat) * S)


def simplify(pts, eps):
    """Douglas-Peucker, iterative."""
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        (ax, ay), (bx, by) = pts[i], pts[j]
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy) or 1e-9
        best, idx = 0, -1
        for k in range(i + 1, j):
            px, py = pts[k]
            d = abs(dy * px - dx * py + bx * ay - by * ax) / L
            if d > best:
                best, idx = d, k
        if best > eps:
            keep[idx] = True
            stack += [(i, idx), (idx, j)]
    return [p for p, k in zip(pts, keep) if k]


def ring_path(ring, eps, min_area):
    pts = [proj(*c[:2]) for c in ring]
    far = max(range(len(pts)), key=lambda k: (pts[k][0] - pts[0][0]) ** 2 + (pts[k][1] - pts[0][1]) ** 2)
    r = simplify(pts[:far + 1], eps)[:-1] + simplify(pts[far:], eps)
    if len(r) < 4:
        return ""
    area = abs(sum(r[i][0] * r[i - 1][1] - r[i - 1][0] * r[i][1] for i in range(len(r)))) / 2
    if area < min_area:
        return ""
    return "M" + "L".join(f"{x:.1f},{y:.1f}" for x, y in r) + "Z"


src, out = sys.argv[1], sys.argv[2]
eps = float(sys.argv[3]) if len(sys.argv) > 3 else 0.3
data = json.load(open(src))
paths = {}
for f in data["features"]:
    code = f["properties"].get("ADM0_A3")
    if code not in ("GBR", "IRL", "IMN"):
        continue
    g = f["geometry"]
    polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    paths[code] = "".join(ring_path(p[0], eps, 0.6) for p in polys)
json.dump(paths, open(out, "w"))
print({k: len(v) for k, v in paths.items()}, "bytes total", sum(map(len, paths.values())))
