"""Cuts the generated art sheets into cells (v0.10.5 W3-A1).

Run from the repo root: python -I scripts/art/split_sheets.py [--workbook PATH] [--only ASSET_ID] [--dry-run]
Reads the "Prompts" sheet of docs/art/prompts/ZD_CARD_ICONS.xlsx (stdlib only: an xlsx is a zip of XML). For each
row whose sheet exists at <sheet_folder>/<image_name>, cuts it by `grid` (columns x rows) into equal cells in
reading order (left to right, top to bottom), names them by the row's `cells` list (an empty name "" skips that cell), resizes each to
`cell_final_size` (Lanczos, alpha kept) and writes them to `cells_folder`. A row whose sheet is missing is skipped
and listed. Needs Pillow and numpy (pip install pillow numpy) except with --dry-run.

W3-O15: the generated sheets do not keep their icons inside the equal grid: in 35 of the 92 cells an icon crosses
the grid line (alpha up to 254 on the cell's edge), so a plain grid cut clipped icons and pulled slivers of the
neighbours in. The cut is content-aware: the opaque parts (alpha >= 16) are grouped into blobs, each blob belongs
to the cell holding its centre, and each icon is cut as a square of one cell's size centred on its own blobs (larger
only if the icon is). Pixels of the other cells' blobs are cleared; everything else is copied as is (no fade, no
threshold: the background between icons is already alpha 0-2).
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


SCALE = 4  # blobs are found on a quarter-size mask
SOLID = 16  # alpha at or above this is part of an icon


def _blobs(mask):
    """Labels 8-connected blobs of a bool mask (pure numpy/python, no scipy). Returns (labels, count)."""
    import numpy as np

    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    count = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if labels[y0, x0]:
            continue
        count += 1
        labels[y0, x0] = count
        stack = [(y0, x0)]
        while stack:
            y, x = stack.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = count
                        stack.append((ny, nx))
    return labels, count


def cut_cells(sheet, cols, rows):
    """One RGBA image per cell in reading order, each a square centred on that cell's own icon."""
    import numpy as np
    from PIL import Image

    px = np.asarray(sheet).copy()
    h, w = px.shape[:2]
    cw, ch = w // cols, h // rows
    a = px[..., 3]
    small = a[: h // SCALE * SCALE, : w // SCALE * SCALE].reshape(h // SCALE, SCALE, w // SCALE, SCALE).max(axis=(1, 3))
    labels, count = _blobs(small >= SOLID)
    owner = np.zeros(count + 1, dtype=np.int32) - 1
    for lab in range(1, count + 1):
        ys, xs = np.nonzero(labels == lab)
        wt = small[ys, xs].astype(float)
        cy = (ys * wt).sum() / wt.sum() * SCALE
        cx = (xs * wt).sum() / wt.sum() * SCALE
        owner[lab] = min(int(cy // ch), rows - 1) * cols + min(int(cx // cw), cols - 1)
    cell_of = owner[labels]  # -1 where no blob
    cell_of = np.repeat(np.repeat(cell_of, SCALE, axis=0), SCALE, axis=1)
    full = np.full((h, w), -1, dtype=np.int32)
    full[: cell_of.shape[0], : cell_of.shape[1]] = cell_of
    out = []
    side0 = max(cw, ch)
    for i in range(cols * rows):
        ys, xs = np.nonzero(full == i)
        if len(ys) == 0:
            cx0, cy0, side = (i % cols) * cw + cw // 2, (i // cols) * ch + ch // 2, side0
        else:
            y1, y2, x1, x2 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            cx0, cy0 = (x1 + x2) // 2, (y1 + y2) // 2
            side = max(side0, int(max(y2 - y1, x2 - x1) * 1.04))
        cell = px.copy()
        cell[(full >= 0) & (full != i), 3] = 0  # the neighbours' icons
        canvas = np.zeros((side, side, 4), dtype=np.uint8)
        sx, sy = cx0 - side // 2, cy0 - side // 2
        dx1, dy1 = max(0, -sx), max(0, -sy)
        sx1, sy1 = max(0, sx), max(0, sy)
        sx2, sy2 = min(w, sx + side), min(h, sy + side)
        canvas[dy1 : dy1 + sy2 - sy1, dx1 : dx1 + sx2 - sx1] = cell[sy1:sy2, sx1:sx2]
        out.append(Image.fromarray(canvas, "RGBA"))
    return out


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
            for name in filter(None, cells):
                print("would write", os.path.join(r["cells_folder"], name))
            continue
        os.makedirs(out, exist_ok=True)
        sheet = image.open(src).convert("RGBA")
        for i, cell in enumerate(cut_cells(sheet, cols, rows)):
            if not cells[i]:  # an empty cell (name "") is not written
                continue
            cell.resize((fw, fh), image.LANCZOS).save(os.path.join(out, cells[i]))
            written += 1
        print("%s: %d cells -> %s" % (r["image_name"], len(list(filter(None, cells))), r["cells_folder"]))
    print("written:", written)
    for m in missing:
        print("missing sheet (skipped):", m)


if __name__ == "__main__":
    main()
