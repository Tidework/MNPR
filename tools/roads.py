"""Make src/roads.json: motorways and A roads in Great Britain, projected for the
app's map and simplified.

Source: OS Open Roads (Ordnance Survey, Open Government Licence v3), shapefile
download: https://api.os.uk/downloads/v1/products/OpenRoads/downloads
Needs: pip install pyshp pyproj

Run: python3 tools/roads.py <folder with *_RoadLink.shp> src/roads.json
Output: {"m": [...], "p": [...], "a": [...]} for motorways, primary A roads
(green-sign routes) and other A roads. Each entry is [road number, flat list of
x,y map units times 10]. The projection must match K, LON0, LAT1 and S in
src/page.html.
"""
import glob, json, math, sys
from collections import defaultdict
import shapefile
from pyproj import Transformer

K = math.cos(math.radians(54.5))
LON0, LAT1, S = -11.0, 61.0, 100
TOL = {"m": 0.35, "p": 0.45, "a": 0.6}  # simplification, in map units (1 unit is about 1 km north-south)
to_wgs = Transformer.from_crs("EPSG:27700", "EPSG:4326", always_xy=True)


def simplify(pts, eps):
    if len(pts) < 3:
        return pts
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


def chain(segs):
    """Join segments that share end points into longer lines."""
    key = lambda p: (round(p[0]), round(p[1]))
    ends = defaultdict(list)
    for i, s in enumerate(segs):
        ends[key(s[0])].append(i)
        ends[key(s[-1])].append(i)
    used, lines = set(), []
    for i in range(len(segs)):
        if i in used:
            continue
        used.add(i)
        line = list(segs[i])
        for forward in (True, False):
            while True:
                tip = key(line[-1] if forward else line[0])
                nxt = next((j for j in ends[tip] if j not in used), None)
                if nxt is None:
                    break
                used.add(nxt)
                s = segs[nxt]
                if key(s[0]) != tip:
                    s = s[::-1]
                line = line + s[1:] if forward else s[::-1][:-1] + line
        lines.append(line)
    return lines


groups = defaultdict(list)
for shp in sorted(glob.glob(sys.argv[1] + "/*_RoadLink.shp")):
    r = shapefile.Reader(shp, encoding="latin-1")
    names = [f[0] for f in r.fields[1:]]
    for sr in r.iterShapeRecords():
        rec = dict(zip(names, sr.record))
        cls, num = rec["class"], rec["roadNumber"].strip()
        if cls not in ("Motorway", "A Road") or rec["formOfWay"] in ("Slip Road", "Roundabout"):
            continue
        kind = "m" if cls == "Motorway" or "(M)" in num else ("p" if rec["primary"] == "true" else "a")
        groups[(kind, num)].append([tuple(p) for p in sr.shape.points])

out = {"m": [], "p": [], "a": []}
for (kind, num), segs in groups.items():
    for line in chain(segs):
        lon, lat = to_wgs.transform([p[0] for p in line], [p[1] for p in line])
        pts = [((lo - LON0) * K * S, (LAT1 - la) * S) for lo, la in zip(lon, lat)]
        pts = simplify(pts, TOL[kind])
        length = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
        if length < (0.5 if kind == "m" else 1.5):  # scraps too short to see on the map
            continue
        flat = [v for p in pts for v in (round(p[0] * 10), round(p[1] * 10))]
        out[kind].append([num, flat])
json.dump(out, open(sys.argv[2], "w"), separators=(",", ":"))
print({k: (len(v), sum(len(x[1]) // 2 for x in v)) for k, v in out.items()})
