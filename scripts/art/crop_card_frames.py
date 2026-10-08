#!/usr/bin/env python3
"""Crops the owner's 12 empty card frames into game textures (v0.5.5 Step CD, PLAN row A4).

Source: docs/roadmap/v0.5.5/refs/card_templates_empty.webp (the owner's own art, 1536 x 1024, a 6 x 2 grid of
crystal frames). Output: assets/ui/cards/frame_<colour>.png (RGBA, every frame the same size) and
assets/ui/cards/manifest.json (id, path, sha256, size, the dark panel's rectangle, the source and the licence).

    python3 scripts/art/crop_card_frames.py            # writes the PNGs and the manifest
    python3 scripts/art/crop_card_frames.py --check    # crops in memory, exits 1 if a file differs from disk

How the background goes:
- The delivered webp already carries an alpha channel (its background is transparent, alpha 0). When an image
  arrives without one (a white background), the background is flood-filled from the image's edges with a colour
  tolerance (FLOOD_TOL) instead, so white inside a frame is never removed.
- WebP noise: alpha below ALPHA_FLOOR becomes 0, alpha above ALPHA_SOLID becomes 255 (the panel never lets the
  world through).
- Defringe: one pass of a 1-px alpha erode on edge pixels whose colour is light (a white halo), then every
  partly transparent pixel takes the colour of its most opaque neighbour, so no light fringe shows on a dark game.
- Each frame is cut by connected parts (the loose crystals around a frame belong to the cell their centre sits in),
  trimmed to its own box and centred on one canvas of the largest box (bottom-aligned: the bases line up).

The panel rectangle in the manifest is the largest axis-aligned box of dark, opaque pixels inside the frame: where
the card's text goes. Needs Pillow (pip install pillow). The output is deterministic.
"""

import argparse
import hashlib
import json
import os
import sys
from collections import deque

from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = "docs/roadmap/v0.5.5/refs/card_templates_empty.webp"
OUT_DIR = os.path.join(ROOT, "assets", "ui", "cards")
MANIFEST = os.path.join(OUT_DIR, "manifest.json")
LICENCE = "The owner's own art (Rius, delivered 2026-10-08 for v0.5.5 A4); no third-party art"

COLS, ROWS = 6, 2
## The grid's colours in reading order (PLAN v0.5.5 "Card frame colours").
IDS = [
    "red", "blue", "amber", "purple", "green", "silver",
    "pink", "cyan", "orange", "violet", "gold", "indigo",
]
ALPHA_FLOOR = 24
ALPHA_SOLID = 232
FLOOD_TOL = 40
PAD = 4
## A pixel counts as "dark panel" when opaque and its brightest channel is at most this.
DARK_MAX = 72


def load_rgba(path):
    im = Image.open(path).convert("RGBA")
    lo, _hi = im.getchannel("A").getextrema()
    if lo >= 250:  # no transparency delivered: remove the white background by flood fill from the edges
        im = flood_background(im)
    return im


def flood_background(im):
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, _a = px[x, y]
        if 255 - min(r, g, b) > FLOOD_TOL:
            continue
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return im


def clean_alpha(im):
    w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < ALPHA_FLOOR:
                px[x, y] = (0, 0, 0, 0)
            elif a > ALPHA_SOLID:
                px[x, y] = (r, g, b, 255)
    # Erode light edge pixels by 1 px (a white halo left by a white background).
    alpha = im.getchannel("A")
    eroded = alpha.filter(ImageFilter.MinFilter(3))
    ep = eroded.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and ep[x, y] == 0 and min(r, g, b) > 200:
                px[x, y] = (0, 0, 0, 0)
    # Defringe: partly transparent pixels take the colour of their most opaque neighbour.
    src = im.copy().load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if 0 < a < 255:
                best = (a, r, g, b)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            nr, ng, nb, na = src[nx, ny]
                            if na > best[0]:
                                best = (na, nr, ng, nb)
                px[x, y] = (best[1], best[2], best[3], a)
    return im


def components(im):
    """Connected parts of non-transparent pixels: a list of (pixel list, bbox)."""
    w, h = im.size
    a = im.getchannel("A").load()
    label = [0] * (w * h)
    parts = []
    for sy in range(h):
        for sx in range(w):
            if a[sx, sy] == 0 or label[sy * w + sx]:
                continue
            n = len(parts) + 1
            q = deque([(sx, sy)])
            label[sy * w + sx] = n
            pts = []
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and not label[ny * w + nx]:
                        label[ny * w + nx] = n
                        q.append((nx, ny))
            parts.append(pts)
    return parts


def cut_frames(im):
    w, h = im.size
    cw, ch = w / COLS, h / ROWS
    cells = [[] for _ in range(COLS * ROWS)]
    for pts in components(im):
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        cells[min(ROWS - 1, int(cy // ch)) * COLS + min(COLS - 1, int(cx // cw))].extend(pts)
    src = im.load()
    frames = []
    for pts in cells:
        x0 = min(p[0] for p in pts)
        y0 = min(p[1] for p in pts)
        x1 = max(p[0] for p in pts) + 1
        y1 = max(p[1] for p in pts) + 1
        f = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        fp = f.load()
        for x, y in pts:
            fp[x - x0, y - y0] = src[x, y]
        frames.append(f)
    fw = max(f.size[0] for f in frames) + PAD * 2
    fh = max(f.size[1] for f in frames) + PAD * 2
    out = []
    for f in frames:
        canvas = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        canvas.paste(f, ((fw - f.size[0]) // 2, fh - PAD - f.size[1]))
        out.append(canvas)
    return out


def panel_rect(f):
    """The largest box of dark opaque pixels (maximal rectangle in a histogram per row)."""
    w, h = f.size
    px = f.load()
    heights = [0] * w
    best = (0, 0, 0, 0, 0)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            heights[x] = heights[x] + 1 if a == 255 and max(r, g, b) <= DARK_MAX else 0
        stack = []
        for x in range(w + 1):
            hx = heights[x] if x < w else 0
            start = x
            while stack and stack[-1][1] >= hx:
                start, sh = stack.pop()
                area = sh * (x - start)
                if area > best[0]:
                    best = (area, start, y - sh + 1, x - start, sh)
            stack.append((start, hx))
    return [best[1], best[2], best[3], best[4]]


def png_bytes(img):
    from io import BytesIO

    buf = BytesIO()
    img.save(buf, format="PNG", optimize=False, compress_level=9)
    return buf.getvalue()


def build():
    im = clean_alpha(load_rgba(os.path.join(ROOT, SOURCE)))
    frames = cut_frames(im)
    files = {}
    entries = []
    for fid, f in zip(IDS, frames):
        data = png_bytes(f)
        rel = "assets/ui/cards/frame_%s.png" % fid
        files[rel] = data
        entries.append(
            {
                "id": fid,
                "path": rel,
                "sha256": hashlib.sha256(data).hexdigest(),
                "size": [f.size[0], f.size[1]],
                "panel": panel_rect(f),
            }
        )
    manifest = {
        "generator": "scripts/art/crop_card_frames.py",
        "source": SOURCE,
        "source_sha256": hashlib.sha256(open(os.path.join(ROOT, SOURCE), "rb").read()).hexdigest(),
        "licence": LICENCE,
        "frames": entries,
    }
    files["assets/ui/cards/manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
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
