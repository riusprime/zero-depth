"""v0.8.0 Step N10: puts the wall styles' shots side by side (scripts/shots/walls_n10.gd writes them under
build/shots/n10/<walls>/<biome>_<spot>.png). Per biome and spot, the styles found (old, a, b, in that order) are
scaled to WIDTH px wide, labelled and joined left to right into docs/roadmap/v0.8.0/evidence/n10_shots/
<biome>_<spot>.jpg. Prints each file written.

v0.8.0 O68 (the grain fix): build/shots/n10/a_grain_old (grain=old: option A before the fix) beside
build/shots/n10/a (after) into grain_<biome>_<spot>.jpg; and, where walls_n10.gd saved a pan frame (<spot>_pan.png,
the camera 0.13 m on), the shimmer: the frame and its pan frame aligned by the best whole-pixel shift (within
SHIFT px, on the grey image), then the mean absolute difference left over (0-255; lower: steadier; the edges and the
sub-pixel move remain in it for both, so only the before/after comparison means anything).

Run from the repo root: python3 -I scripts/shots/n10_sheet.py   (needs Pillow)
"""

import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SRC = "build/shots/n10"
OUT = "docs/roadmap/v0.8.0/evidence/n10_shots"
STYLES = [("old", "today: kit pieces"), ("a", "A: procedural ruin"), ("b", "B: kit, fitted + decimated")]
WIDTH = 640
SHIFT = 12
GRAIN = [("a_grain_old", "A before O68 (2.4 m tiles, no mipmaps)"), ("a", "A after O68 (4 m tiles, mipmaps, offsets)")]


def _label(img, label):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 8 + 6 * len(label), 20], fill=(0, 0, 0))
    d.text((4, 4), label, fill=(255, 255, 255))


def _join(tiles):
    sheet = Image.new("RGB", (sum(t.width for t in tiles) + 4 * (len(tiles) - 1), tiles[0].height), (0, 0, 0))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 4
    return sheet


def shimmer(a_path, b_path):
    a = np.asarray(Image.open(a_path).convert("L")).astype(float)
    b = np.asarray(Image.open(b_path).convert("L")).astype(float)
    best = None
    m = SHIFT
    core = a[m:-m, m:-m]
    for dy in range(-m, m + 1):
        for dx in range(-m, m + 1):
            d = np.abs(core - b[m + dy : a.shape[0] - m + dy, m + dx : a.shape[1] - m + dx]).mean()
            if best is None or d < best[0]:
                best = (d, dx, dy)
    return best


def grain() -> None:
    for path in sorted(glob.glob(os.path.join(SRC, "a_grain_old", "*.png"))):
        key = os.path.basename(path)[:-4]
        if key.endswith("_pan"):
            continue
        tiles = []
        for tag, label in GRAIN:
            p = os.path.join(SRC, tag, key + ".png")
            if not os.path.exists(p):
                continue
            img = Image.open(p).convert("RGB")
            img = img.resize((WIDTH, int(img.height * WIDTH / img.width)), Image.LANCZOS)
            _label(img, label)
            tiles.append(img)
            pan = os.path.join(SRC, tag, key + "_pan.png")
            if os.path.exists(pan):
                d, dx, dy = shimmer(p, pan)
                print("shimmer %-12s %-16s %.2f (aligned at %d,%d px)" % (tag, key, d, dx, dy))
        if len(tiles) == 2:
            out = os.path.join(OUT, "grain_" + key + ".jpg")
            _join(tiles).save(out, quality=85)
            print(out)


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    keys = set()
    for path in glob.glob(os.path.join(SRC, "*", "*.png")):
        if not path.endswith("_pan.png"):
            keys.add(os.path.basename(path)[:-4])
    for key in sorted(keys):
        tiles = []
        for style, label in STYLES:
            path = os.path.join(SRC, style, key + ".png")
            if not os.path.exists(path):
                continue
            img = Image.open(path).convert("RGB")
            img = img.resize((WIDTH, int(img.height * WIDTH / img.width)), Image.LANCZOS)
            _label(img, label)
            tiles.append(img)
        if len(tiles) < 2:
            continue
        out = os.path.join(OUT, key + ".jpg")
        _join(tiles).save(out, quality=82)
        print(out)
    grain()
    return 0


if __name__ == "__main__":
    sys.exit(main())
