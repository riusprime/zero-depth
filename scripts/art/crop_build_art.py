#!/usr/bin/env python3
"""Crops the owner's build-picker art into game textures (v0.6.1 Step PQ, PLAN row R2b).

Sources (the owner's own art, delivered 2026-10-09, transparent backgrounds):
- docs/roadmap/v0.6.1/refs/build_title_plaque.webp  one wide title plaque (cyan left, amber right)
- docs/roadmap/v0.6.1/refs/build_card_frames.webp   two portrait frames side by side (Blade cyan, Gun amber)
- docs/roadmap/v0.6.1/refs/build_emblems.webp       two emblems side by side (crystal sword, crystal pistol)

Output: assets/ui/build_picker/title_plaque.png, frame_blade.png, frame_gun.png, emblem_blade.png, emblem_gun.png and
assets/ui/build_picker/manifest.json (id, path, sha256, size, the dark panel's rectangle for the frames and the plaque, the
sources and the licence).

    python3 scripts/art/crop_build_art.py            # writes the PNGs and the manifest
    python3 scripts/art/crop_build_art.py --check    # crops in memory, exits 1 if a file differs from disk

The clean-up is the card frames' (scripts/art/crop_card_frames.py: load_rgba, clean_alpha, components, png_bytes)
and the dark panel walk is the plaques' (scripts/art/crop_plaques.py: panel_box). Pieces of one sheet are split by
connected parts (a loose crystal or a slash arc belongs to the column its centre sits in), trimmed, and the pieces of
one kind share one canvas (frames bottom-aligned, emblems centred). Needs Pillow. The output is deterministic.
"""

import argparse
import hashlib
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import crop_card_frames as cf  # noqa: E402
import crop_plaques as cp  # noqa: E402

ROOT = cf.ROOT
OUT = "assets/ui/build_picker"
LICENCE = "The owner's own art (Rius, delivered 2026-10-09 for v0.6.1 R2b); no third-party art"
PAD = 4
## sheet, column count, ids left to right, canvas alignment, whether the piece has a dark panel
SHEETS = [
    ("docs/roadmap/v0.6.1/refs/build_title_plaque.webp", 1, ["title_plaque"], "centre", True),
    ("docs/roadmap/v0.6.1/refs/build_card_frames.webp", 2, ["frame_blade", "frame_gun"], "bottom", True),
    ("docs/roadmap/v0.6.1/refs/build_emblems.webp", 2, ["emblem_blade", "emblem_gun"], "centre", False),
]


def split(im, cols):
    w = im.size[0]
    cells = [[] for _ in range(cols)]
    for pts in cf.components(im):
        cx = sum(p[0] for p in pts) / len(pts)
        cells[min(cols - 1, int(cx // (w / cols)))].extend(pts)
    src = im.load()
    out = []
    for pts in cells:
        x0 = min(p[0] for p in pts)
        y0 = min(p[1] for p in pts)
        x1 = max(p[0] for p in pts) + 1
        y1 = max(p[1] for p in pts) + 1
        f = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        fp = f.load()
        for x, y in pts:
            fp[x - x0, y - y0] = src[x, y]
        out.append(f)
    return out


def on_canvas(parts, align):
    fw = max(f.size[0] for f in parts) + PAD * 2
    fh = max(f.size[1] for f in parts) + PAD * 2
    out = []
    for f in parts:
        canvas = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        y = fh - PAD - f.size[1] if align == "bottom" else (fh - f.size[1]) // 2
        canvas.paste(f, ((fw - f.size[0]) // 2, y))
        out.append(canvas)
    return out


def build():
    files = {}
    entries = []
    sources = []
    for src, cols, ids, align, has_panel in SHEETS:
        path = os.path.join(ROOT, src)
        sources.append({"path": src, "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest()})
        im = cf.clean_alpha(cf.load_rgba(path))
        for pid, f in zip(ids, on_canvas(split(im, cols), align)):
            data = cf.png_bytes(f)
            rel = "%s/%s.png" % (OUT, pid)
            files[rel] = data
            e = {
                "id": pid,
                "path": rel,
                "source": src,
                "sha256": hashlib.sha256(data).hexdigest(),
                "size": [f.size[0], f.size[1]],
            }
            if has_panel:
                e["panel"] = cp.panel_box(f)
            entries.append(e)
    manifest = {
        "generator": "scripts/art/crop_build_art.py",
        "sources": sources,
        "licence": LICENCE,
        "pieces": entries,
    }
    files[OUT + "/manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
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
