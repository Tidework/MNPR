"""Make src/towns.json: every city in the UK (official city status), the cities of
Ireland, and Douglas on the Isle of Man, biggest first, as [name, lat, lng],
followed by large towns (60,000 people or more) as [name, lat, lng, 1].

Positions and populations come from GeoNames cities1000 (CC BY 4.0,
https://download.geonames.org/export/dump/cities1000.zip). Each city below has a
rough position so the right place is picked when names repeat (Newport, Bangor, Perth).

Run: python3 tools/cities.py cities1000.txt src/towns.json
"""
import csv, json, math, sys

CITIES = [
    # England
    ("Bath", 51.38, -2.36), ("Birmingham", 52.48, -1.90), ("Bradford", 53.79, -1.75), ("Brighton", 50.83, -0.14),
    ("Bristol", 51.45, -2.59), ("Cambridge", 52.20, 0.12), ("Canterbury", 51.28, 1.08), ("Carlisle", 54.89, -2.93),
    ("Chelmsford", 51.73, 0.47), ("Chester", 53.19, -2.89), ("Chichester", 50.84, -0.78), ("Colchester", 51.89, 0.90),
    ("Coventry", 52.41, -1.51), ("Derby", 52.92, -1.48), ("Doncaster", 53.52, -1.13), ("Durham", 54.78, -1.57),
    ("Ely", 52.40, 0.26), ("Exeter", 50.72, -3.53), ("Gloucester", 51.86, -2.24), ("Hereford", 52.06, -2.72),
    ("Hull", 53.74, -0.33, "Kingston upon Hull"), ("Lancaster", 54.05, -2.80), ("Leeds", 53.80, -1.55),
    ("Leicester", 52.64, -1.13), ("Lichfield", 52.68, -1.83), ("Lincoln", 53.23, -0.54), ("Liverpool", 53.41, -2.98),
    ("London", 51.51, -0.13), ("Manchester", 53.48, -2.24), ("Milton Keynes", 52.04, -0.76),
    ("Newcastle", 54.97, -1.61, "Newcastle upon Tyne"), ("Norwich", 52.63, 1.30), ("Nottingham", 52.95, -1.15),
    ("Oxford", 51.75, -1.26), ("Peterborough", 52.57, -0.24), ("Plymouth", 50.37, -4.14), ("Portsmouth", 50.80, -1.09),
    ("Preston", 53.76, -2.70), ("Ripon", 54.14, -1.52), ("St Albans", 51.75, -0.34), ("Salford", 53.49, -2.29),
    ("Salisbury", 51.07, -1.79), ("Sheffield", 53.38, -1.47), ("Southampton", 50.90, -1.40),
    ("Southend-on-Sea", 51.54, 0.71), ("Stoke-on-Trent", 53.00, -2.18), ("Sunderland", 54.91, -1.38),
    ("Truro", 50.26, -5.05), ("Wakefield", 53.68, -1.50), ("Wells", 51.21, -2.65), ("Winchester", 51.06, -1.31),
    ("Wolverhampton", 52.59, -2.13), ("Worcester", 52.19, -2.22), ("York", 53.96, -1.08),
    # Scotland
    ("Aberdeen", 57.15, -2.09), ("Dundee", 56.46, -2.97), ("Dunfermline", 56.07, -3.46), ("Edinburgh", 55.95, -3.19),
    ("Glasgow", 55.86, -4.25), ("Inverness", 57.48, -4.22), ("Perth", 56.40, -3.43), ("Stirling", 56.12, -3.94),
    # Wales
    ("Bangor", 53.23, -4.13), ("Cardiff", 51.48, -3.18), ("Newport", 51.58, -2.99), ("St Asaph", 53.26, -3.44),
    ("St Davids", 51.88, -5.27), ("Swansea", 51.62, -3.94), ("Wrexham", 53.05, -2.99),
    # Northern Ireland
    ("Armagh", 54.35, -6.65), ("Belfast", 54.60, -5.93), ("Derry", 54.99, -7.31), ("Lisburn", 54.51, -6.04),
    ("Newry", 54.18, -6.34),
    # Ireland and the Isle of Man
    ("Dublin", 53.35, -6.26), ("Cork", 51.90, -8.47), ("Limerick", 52.66, -8.63), ("Galway", 53.27, -9.05),
    ("Waterford", 52.26, -7.11), ("Kilkenny", 52.65, -7.25), ("Douglas", 54.15, -4.48),
]

# Large towns: GeoNames entries that are districts or areas rather than towns, and renamed labels.
NOT_TOWNS = {"High Peak", "Fylde", "Rossendale", "Saint Peters", "Buckley", "Tonypandy", "Rhondda",
             "Tallaght", "Newtownabbey", "Sale"}  # the last three are suburbs of Dublin, Belfast and Manchester
NOT_LONDON = {"Watford"}  # inside the London cut-off but its own town
RENAME = {"Ellesmere Port Town": "Ellesmere Port", "Royal Tunbridge Wells": "Tunbridge Wells"}
TOWN_MIN = 60000

places = []
for r in csv.reader(open(sys.argv[1], encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE):
    if r[8] in ("GB", "IE", "IM") and r[6] == "P":
        names = {r[1].lower(), r[2].lower()} | {n.lower() for n in r[3].split(",")}
        places.append((names, float(r[4]), float(r[5]), int(r[14] or 0), r[1], r[7]))

out = []
for c in CITIES:
    label, lat, lng = c[:3]
    want = {label.lower(), (c[3] if len(c) > 3 else label).lower(), label.lower().replace("st ", "saint ")}
    near = [p for p in places if p[0] & want and math.hypot(p[1] - lat, p[2] - lng) < 0.3]
    if near:
        best = max(near, key=lambda p: p[3])
        out.append((best[3], label, round(best[1], 3), round(best[2], 3)))
    else:
        print("no GeoNames match, using rough position:", label)
        out.append((0, label, lat, lng))
out.sort(key=lambda t: -t[0])

km = lambda a, b, c, d: math.hypot((a - c) * 111, (b - d) * 111 * 0.6)
towns = []
for names, lat, lng, pop, name, code in sorted(places, key=lambda p: -p[3]):
    if pop < TOWN_MIN:
        break
    if code == "PPLX" or name in NOT_TOWNS or (km(lat, lng, 51.507, -0.128) < 26 and name not in NOT_LONDON):  # London boroughs
        continue
    if any(km(lat, lng, la, lo) < 7 for _, _, la, lo in out + towns):  # part of a city or a town already in
        continue
    towns.append((pop, RENAME.get(name, name), round(lat, 3), round(lng, 3)))

data = [[n, la, lo] for _, n, la, lo in out] + [[n, la, lo, 1] for _, n, la, lo in towns]
json.dump(data, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(out), "cities and", len(towns), "towns:", ", ".join(n for _, n, _, _ in towns))
