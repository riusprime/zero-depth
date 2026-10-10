#!/usr/bin/env python3
"""Crops the owner's 12 empty wide crystal plaques into game textures (v0.6.1 Step PQ, PLAN row R1).

Source: docs/roadmap/v0.6.1/refs/plaque_templates_empty.webp (the owner's own art, 1984 x 793, a 4 x 3 grid of wide
plaques). Output: assets/ui/plaques/plaque_<colour>.png (RGBA, every plaque the same size) and
assets/ui/plaques/manifest.json (id, path, sha256, size, the dark panel's rectangle, the nine-slice margins, the
source and the licence).

    python3 scripts/art/crop_plaques.py            # writes the PNGs and the manifest
    python3 scripts/art/crop_plaques.py --check    # crops in memory, exits 1 if a file differs from disk

The background, alpha clean-up and defringe are the card frames' (scripts/art/crop_card_frames.py: load_rgba,
clean_alpha, components, png_bytes are reused as they are). Each plaque is cut by its connected parts (the loose
crystals belong to the cell their centre sits in), trimmed and centred on one canvas of the largest box.

Nine-slice margins (left, top, right, bottom, in plaque pixels): the left and right margins cover the crystal
end-clusters and every loose gem near them: they stop where the columns become "plain" (every column from there to
the centre has the same opaque top and bottom as the centre column, within PLAIN_TOL px). The top and bottom margins
leave a middle band of MIDDLE_BAND px inside the dark panel, so a taller plaque stretches only plain panel rows.
Needs Pillow (pip install pillow). The output is deterministic.
"""

import argparse
import hashlib
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import crop_card_frames as cf  # noqa: E402  (the card frames' cropper: one way to clean the owner's sheets)

ROOT = cf.ROOT
SOURCE = "docs/roadmap/v0.6.1/refs/plaque_templates_empty.webp"
OUT_DIR = os.path.join(ROOT, "assets", "ui", "plaques")
LICENCE = "The owner's own art (Rius, delivered 2026-10-09 for v0.6.1 R1); no third-party art"

COLS, ROWS = 4, 3
## The grid's colours in reading order, named after the card frame of the same colour (CardFrames.TINT): the owner's
## sheet has the card frames' first eight in the same order; its last row is gold, violet, slate (the indigo slot)
## and orange (measured hue in the evidence, docs/roadmap/v0.6.1/evidence/PLAQUES.md).
IDS = [
    "red", "blue", "amber", "purple",
    "green", "silver", "pink", "cyan",
    "gold", "violet", "indigo", "orange",
]
PAD = 4
PLAIN_TOL = 3
MIDDLE_BAND = 8
## The dark panel: from the plaque's centre, the run of opaque pixels whose brightest channel stays within PANEL_TOL
## of the centre pixel's (the panels differ in brightness by colour, so no fixed threshold).
PANEL_TOL = 28
## Text keeps this far (px) inside the clear part of the panel.
TEXT_INSET = 6


def cut_plaques(im):
    w, h = im.size
    cw, ch = w / COLS, h / ROWS
    cells = [[] for _ in range(COLS * ROWS)]
    for pts in cf.components(im):
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        cells[min(ROWS - 1, int(cy // ch)) * COLS + min(COLS - 1, int(cx // cw))].extend(pts)
    src = im.load()
    parts = []
    for pts in cells:
        x0 = min(p[0] for p in pts)
        y0 = min(p[1] for p in pts)
        x1 = max(p[0] for p in pts) + 1
        y1 = max(p[1] for p in pts) + 1
        f = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        fp = f.load()
        for x, y in pts:
            fp[x - x0, y - y0] = src[x, y]
        parts.append(f)
    fw = max(f.size[0] for f in parts) + PAD * 2
    fh = max(f.size[1] for f in parts) + PAD * 2
    out = []
    for f in parts:
        canvas = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        canvas.paste(f, ((fw - f.size[0]) // 2, (fh - f.size[1]) // 2))
        out.append(canvas)
    return out


def column_span(px, x, h):
    """The first and last opaque row of column x (None when empty)."""
    top = bottom = None
    for y in range(h):
        if px[x, y][3] > 0:
            if top is None:
                top = y
            bottom = y
    return top, bottom


def panel_box(f):
    """[x, y, w, h]: the dark inner panel, walked out from the centre along the centre row and column."""
    w, h = f.size
    px = f.load()
    cx, cy = w // 2, h // 2
    base = max(px[cx, cy][:3])

    def inside(x, y):
        r, g, b, a = px[x, y]
        return a == 255 and abs(max(r, g, b) - base) <= PANEL_TOL

    x0 = cx
    while x0 > 0 and inside(x0 - 1, cy):
        x0 -= 1
    x1 = cx
    while x1 < w - 1 and inside(x1 + 1, cy):
        x1 += 1
    y0 = cy
    while y0 > 0 and inside(cx, y0 - 1):
        y0 -= 1
    y1 = cy
    while y1 < h - 1 and inside(cx, y1 + 1):
        y1 += 1
    return [x0, y0, x1 - x0 + 1, y1 - y0 + 1]


def text_box(f, panel):
    """[x, y, w, h]: the widest run of columns, over the panel's rows (less TEXT_INSET px top and bottom), where every
    pixel is panel-dark: where text can sit without touching a crystal or the bevel."""
    w, h = f.size
    px = f.load()
    cx = w // 2
    base = max(px[cx, h // 2][:3])
    y0 = panel[1] + TEXT_INSET
    y1 = panel[1] + panel[3] - TEXT_INSET

    def clear(x):
        for y in range(y0, y1):
            r, g, b, a = px[x, y]
            if a != 255 or abs(max(r, g, b) - base) > PANEL_TOL:
                return False
        return True

    x0 = cx
    while x0 > 0 and clear(x0 - 1):
        x0 -= 1
    x1 = cx
    while x1 < w - 1 and clear(x1 + 1):
        x1 += 1
    return [x0 + TEXT_INSET, y0, x1 - x0 + 1 - 2 * TEXT_INSET, y1 - y0]


def nine_slice(f, panel):
    """[left, top, right, bottom] margins: the end-clusters outside, a plain middle band inside the panel."""
    w, h = f.size
    px = f.load()
    cx = panel[0] + panel[2] // 2
    ref = column_span(px, cx, h)

    def plain(x):
        t, b = column_span(px, x, h)
        return t is not None and abs(t - ref[0]) <= PLAIN_TOL and abs(b - ref[1]) <= PLAIN_TOL

    left = cx
    while left > 0 and plain(left - 1):
        left -= 1
    right = cx
    while right < w - 1 and plain(right + 1):
        right += 1
    mid = panel[1] + panel[3] // 2
    top = mid - MIDDLE_BAND // 2
    bottom = h - (top + MIDDLE_BAND)
    return [left, top, w - 1 - right, bottom]


def build():
    im = cf.clean_alpha(cf.load_rgba(os.path.join(ROOT, SOURCE)))
    plaques = cut_plaques(im)
    files = {}
    entries = []
    for pid, f in zip(IDS, plaques):
        data = cf.png_bytes(f)
        rel = "assets/ui/plaques/plaque_%s.png" % pid
        files[rel] = data
        panel = panel_box(f)
        entries.append(
            {
                "id": pid,
                "path": rel,
                "sha256": hashlib.sha256(data).hexdigest(),
                "size": [f.size[0], f.size[1]],
                "panel": panel,
                "text": text_box(f, panel),
                "nine_slice": nine_slice(f, panel),
            }
        )
    manifest = {
        "generator": "scripts/art/crop_plaques.py",
        "source": SOURCE,
        "source_sha256": hashlib.sha256(open(os.path.join(ROOT, SOURCE), "rb").read()).hexdigest(),
        "licence": LICENCE,
        "plaques": entries,
    }
    files["assets/ui/plaques/manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    files = build()
    bad = 0
    for rel, data in files.items():
        path = os.path.join(ROOT, rel)
        if args.check:
            if not os.path.exists(path) or open(path, "rb").read() != data:
                print("differs:", rel)
                bad += 1
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as fh:
                fh.write(data)
            print("wrote", rel)
    if args.check:
        print("check: %d file(s) differ" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
