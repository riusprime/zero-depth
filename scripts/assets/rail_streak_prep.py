"""Prepares the owner's rail streak (unprocessed_images/models_v0120_b/fx_rail_streak.png, docs/art/requests/
v0.12.0_models.md section 26) for the game: assets/textures/vfx/fx_rail_streak.png.

The upload is four variants of one rail-gun streak stacked in rows (thick; thin with a bright knot; medium; thin with a
knot near its start), each running the full width on black. The game lays the streak down in tiles of a fixed length
at the strip's own aspect (RailStreakViews), so nothing here may stretch it: every band is cut out by the empty rows
round it and scaled by ONE factor for both axes, then centred in its own row of a 2 x 1 sheet (2048 x 1024, four rows
of 256 px). One row is then exactly 8 times as long as it is tall, and the four streaks keep their thicknesses
relative to each other. The owner's colours are kept (RGB on black, drawn additively); a column of black the upload
has at its right edge is cut off first, so tiles laid end to end meet without a gap.

Run from the repo root: python scripts/assets/rail_streak_prep.py   (needs Pillow and numpy)
"""

import hashlib
import os
import sys

import numpy as np
from PIL import Image

SRC = "unprocessed_images/models_v0120_b/fx_rail_streak.png"
OUT = "assets/textures/vfx/fx_rail_streak.png"
W = 2048
ROWS = 4
ROW_H = 256


def bands(px: np.ndarray) -> list:
    """The four streaks' row spans (first, last), split at the empty rows between them."""
    occ = px.max(axis=2) > 0.05
    idx = np.nonzero(occ.any(axis=1))[0]
    runs = [r for r in np.split(idx, np.nonzero(np.diff(idx) > 1)[0] + 1) if len(r) > 3]
    if len(runs) != ROWS:
        raise SystemExit("expected %d streaks, found %d" % (ROWS, len(runs)))
    return [(int(r[0]), int(r[-1])) for r in runs]


def main() -> int:
    px = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32) / 255.0
    cols = np.nonzero((px.max(axis=2) > 0.05).any(axis=0))[0]
    px = px[:, int(cols[0]) : int(cols[-1]) + 1]
    k = W / px.shape[1]  # the one scale, for both axes
    out = np.zeros((ROWS * ROW_H, W, 3), np.float32)
    for r, (y0, y1) in enumerate(bands(px)):
        part = px[y0 : y1 + 1]
        h = round(part.shape[0] * k)
        if h > ROW_H:
            raise SystemExit("streak %d is %d px tall, over its %d px row" % (r, h, ROW_H))
        img = Image.fromarray((part * 255).round().astype(np.uint8), "RGB").resize((W, h), Image.LANCZOS)
        y = r * ROW_H + (ROW_H - h) // 2
        out[y : y + h] = np.asarray(img).astype(np.float32) / 255.0
        print("streak %d: rows %d-%d of the upload, %d px tall in its row" % (r, y0, y1, h))
    Image.fromarray((out * 255).round().astype(np.uint8), "RGB").save(OUT, optimize=True)
    data = open(OUT, "rb").read()
    print("%s  %8d  %s  (scale %.4f)" % (hashlib.sha256(data).hexdigest(), len(data), OUT, k))
    return 0


if __name__ == "__main__":
    sys.exit(main())
