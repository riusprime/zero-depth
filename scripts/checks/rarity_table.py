import csv
import glob
import re
from collections import Counter

mig = open("data/wand/migration.tres").read()
old = set(re.findall(r'&"(\w+)"', re.search(r"old_ids = .*", mig).group(0)))
names = {}
for row in csv.reader(open("locale/strings.csv")):
    if len(row) >= 3:
        names[row[0]] = (row[1], row[2])
T = {0: "Common", 1: "Rare", 2: "Legendary", 3: "Epic"}
order = {"Common": 0, "Rare": 1, "Epic": 2, "Legendary": 3}
rows = []
for f in sorted(glob.glob("data/items/*.tres")):
    s = open(f).read()
    cid = re.search(r'^id = &"(\w+)"', s, re.M).group(1)
    if cid in old:
        continue
    m = re.search(r"^rarity = (\d)", s, re.M)
    r = int(m.group(1)) if m else 0
    w = re.search(r'^requires_weapon = &"(\w+)"', s, re.M)
    w = w.group(1) if w else "both"
    k = int(re.search(r"^kind = (\d+)", s, re.M).group(1))
    tags = re.search(r"tags = PackedStringArray\((.*)\)", s)
    tags = tags.group(1) if tags else ""
    kind = "trigger" if k == 32 else ("wand card (Lv 1-5)" if '"wand"' in tags else "passive")
    nk = re.search(r'^name_key = &"(\w+)"', s, re.M).group(1)
    rows.append((order[T[r]], w, cid, names.get(nk, ("?", "?"))[0], kind, T[r]))
rows.sort()
print("| Tier | Card | id | Weapon | Kind |")
print("|---|---|---|---|---|")
for o, w, cid, n, kind, t in rows:
    print(f"| {t} | {n} | `{cid}` | {w} | {kind} |")
print()
print(dict(Counter(r[5] for r in rows)))
