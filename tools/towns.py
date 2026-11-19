"""Make src/towns.json: towns and villages in the UK, Ireland and the Isle of Man,
most important first, as [name, lat, lng].

Source: GeoNames cities1000 (CC BY 4.0, https://www.geonames.org/),
https://download.geonames.org/export/dump/cities1000.zip

Run: python3 tools/towns.py cities1000.txt src/towns.json
Order is by population. Neighbourhoods inside a bigger place (PPLX) count for a
tenth, so they appear only once you zoom in past the towns around them.
"""
import csv, json, sys

src, out = sys.argv[1], sys.argv[2]
towns = []
for r in csv.reader(open(src, encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE):
    if r[8] not in ("GB", "IE", "IM") or r[6] != "P":
        continue
    pop = int(r[14] or 0)
    weight = pop / 10 if r[7] == "PPLX" else pop
    towns.append((weight, r[1], round(float(r[4]), 3), round(float(r[5]), 3)))
towns.sort(key=lambda t: -t[0])
json.dump([[n, la, lo] for _, n, la, lo in towns], open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(towns), "towns")
