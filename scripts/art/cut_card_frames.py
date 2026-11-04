"""Cuts the owner's card frame sheet and the dissolve noise (v0.10.5 W3-O15).

Run from the repo root: python scripts/art/cut_card_frames.py (needs pip install pillow numpy).
art_raw/frames/card_frames_8.webp (1536x1024, alpha): the top row holds 4 carved slate card frames, the bottom row the
same 4 focused (an icy blue rim and glow). Each frame's body (alpha >= 128) is centred on one canvas size shared by
all 8, so a frame and its focused twin line up and the glow has room: assets/ui/card_frames/frame_<1..4>.png and
frame_<1..4>_focus.png. art_raw/frames/dissolve_noise.webp (1254x1254 grey cloud noise) is saved as a 512x512 grey
PNG, assets/ui/fx/dissolve_noise.png, and its seams are measured (printed). Pixels are copied as they are.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = os.path.join(ROOT, "art_raw", "frames", "card_frames_8.webp")
NOISE = os.path.join(ROOT, "art_raw", "frames", "dissolve_noise.webp")
OUT = os.path.join(ROOT, "assets", "ui", "card_frames")
FX = os.path.join(ROOT, "assets", "ui", "fx")
CANVAS = (360, 480)
NOISE_SIZE = 512


def _runs(v):
    out, start = [], None
    for i, x in enumerate(v):
        if x and start is None:
            start = i
        if not x and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(v)))
    return out


def frames():
    px = np.asarray(Image.open(SHEET).convert("RGBA"))
    a = px[..., 3]
    cols = _runs((a > 16).any(0))
    rows = _runs((a > 16).any(1))
    assert len(cols) == 4 and len(rows) == 2, (cols, rows)
    os.makedirs(OUT, exist_ok=True)
    cw, ch = CANVAS
    for ri, (y1, y2) in enumerate(rows):
        for ci, (x1, x2) in enumerate(cols):
            pad = 32
            sx1, sy1 = max(0, x1 - pad), max(0, y1 - pad)
            sub = px[sy1 : y2 + pad, sx1 : x2 + pad]
            body = sub[..., 3] >= 128
            ys, xs = np.nonzero(body)
            bx1, bx2, by1, by2 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            cx, cy = sx1 + (bx1 + bx2) // 2, sy1 + (by1 + by2) // 2
            canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
            ox, oy = cx - cw // 2, cy - ch // 2
            # copy only this frame's neighbourhood (the sheet's other frames are > 30 px away)
            lx1, ly1 = max(ox, x1 - pad), max(oy, y1 - pad)
            lx2, ly2 = min(ox + cw, x2 + pad), min(oy + ch, y2 + pad)
            canvas[ly1 - oy : ly2 - oy, lx1 - ox : lx2 - ox] = px[ly1:ly2, lx1:lx2]
            name = "frame_%d%s.png" % (ci + 1, "_focus" if ri else "")
            Image.fromarray(canvas, "RGBA").save(os.path.join(OUT, name))
            edge = np.concatenate([canvas[0, :, 3], canvas[-1, :, 3], canvas[:, 0, 3], canvas[:, -1, 3]])
            print(
                "%s: body %dx%d, pad l%d t%d, canvas edge alpha max %d"
                % (name, bx2 - bx1, by2 - by1, (cw - (bx2 - bx1)) // 2, (ch - (by2 - by1)) // 2, edge.max())
            )


def noise():
    im = Image.open(NOISE).convert("L")
    n = np.asarray(im).astype(float)
    inner_x = np.abs(np.diff(n, axis=1)).mean()
    inner_y = np.abs(np.diff(n, axis=0)).mean()
    seam_x = np.abs(n[:, 0] - n[:, -1]).mean()
    seam_y = np.abs(n[0, :] - n[-1, :]).mean()
    print(
        "noise %s: mean step between neighbours x %.2f y %.2f; across the wrap x %.2f y %.2f (tileable if close)"
        % (im.size, inner_x, inner_y, seam_x, seam_y)
    )
    os.makedirs(FX, exist_ok=True)
    im.resize((NOISE_SIZE, NOISE_SIZE), Image.LANCZOS).save(os.path.join(FX, "dissolve_noise.png"))


if __name__ == "__main__":
    frames()
    noise()
