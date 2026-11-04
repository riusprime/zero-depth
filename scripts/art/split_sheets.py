"""Cuts the generated art sheets into cells (v0.10.5 W3-A1).

Run from the repo root: python -I scripts/art/split_sheets.py [--workbook PATH] [--only ASSET_ID] [--dry-run]
Reads the "Prompts" sheet of docs/art/prompts/ZD_CARD_ICONS.xlsx (stdlib only: an xlsx is a zip of XML). For each
row whose sheet exists at <sheet_folder>/<image_name>, cuts it by `grid` (columns x rows) into equal cells in
reading order (left to right, top to bottom), names them by the row's `cells` list, resizes each to
`cell_final_size` (Lanczos, alpha kept) and writes them to `cells_folder`. A row whose sheet is missing is skipped
and listed. Needs Pillow (pip install pillow) except with --dry-run.
"""
import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORKBOOK = os.path.join(ROOT, "docs", "art", "prompts", "ZD_CARD_ICONS.xlsx")
NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"


def _col(ref):
    letters = "".join(ch for ch in ref if ch.isalpha())
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n - 1


def read_rows(path, sheet_name="Prompts"):
    """The sheet's rows as dicts keyed by the header row (inline and shared strings)."""
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        for si in ET.fromstring(z.read("xl/sharedStrings.xml")).iter(NS + "si"):
            shared.append("".join(t.text or "" for t in si.iter(NS + "t")))
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    names = [s.get("name") for s in wb.iter(NS + "sheet")]
    sheet = ET.fromstring(z.read("xl/worksheets/sheet%d.xml" % (names.index(sheet_name) + 1)))
    table = []
    for row in sheet.iter(NS + "row"):
        vals = {}
        for c in row.iter(NS + "c"):
            t = c.get("t")
            v = c.find(NS + "v")
            if t == "inlineStr":
                val = "".join(x.text or "" for x in c.iter(NS + "t"))
            elif v is None:
                val = ""
            elif t == "s":
                val = shared[int(v.text)]
            else:
                val = v.text
            vals[_col(c.get("r"))] = val
        table.append(vals)
    head = table[0]
    return [{head[i]: r.get(i, "") for i in head} for r in table[1:] if r]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workbook", default=WORKBOOK)
    ap.add_argument("--only", default="", help="split only this asset_id")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    image = None
    if not a.dry_run:
        try:
            from PIL import Image as image
        except ImportError:
            sys.exit("Pillow is missing: pip install pillow")
    missing = []
    written = 0
    for r in read_rows(a.workbook):
        if a.only and r["asset_id"] != a.only:
            continue
        cols, rows = (int(x) for x in r["grid"].lower().split("x"))
        cells = json.loads(r["cells"])
        if len(cells) != cols * rows:
            sys.exit("%s: %d cells for a %s grid" % (r["asset_id"], len(cells), r["grid"]))
        fw, fh = (int(x) for x in r["cell_final_size"].lower().split("x"))
        src = os.path.join(ROOT, r["sheet_folder"], r["image_name"])
        out = os.path.join(ROOT, r["cells_folder"])
        if not os.path.exists(src):
            missing.append(os.path.relpath(src, ROOT))
            continue
        if a.dry_run:
            for name in cells:
                print("would write", os.path.join(r["cells_folder"], name))
            continue
        os.makedirs(out, exist_ok=True)
        sheet = image.open(src).convert("RGBA")
        w, h = sheet.size
        for i, name in enumerate(cells):
            cx, cy = i % cols, i // cols
            box = (cx * w // cols, cy * h // rows, (cx + 1) * w // cols, (cy + 1) * h // rows)
            cell = sheet.crop(box).resize((fw, fh), image.LANCZOS)
            cell.save(os.path.join(out, name))
            written += 1
        print("%s: %d cells -> %s" % (r["image_name"], len(cells), r["cells_folder"]))
    print("written:", written)
    for m in missing:
        print("missing sheet (skipped):", m)


if __name__ == "__main__":
    main()
