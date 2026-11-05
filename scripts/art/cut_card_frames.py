"""Cuts the owner's card frame sheet and the dissolve noise (v0.10.5 W3-O15).

Run from the repo root: python scripts/art/cut_card_frames.py [--backs] (--backs cuts card_backs_8.webp the same way
into assets/ui/card_backs/back_<1..4>[_focus].png) (needs pip install pillow numpy).
art_raw/frames/card_frames_8.webp (1536x1024, alpha): the top row holds 4 carved slate card frames, the bottom row the
same 4 focused (an icy blue rim and glow). Each frame's body (alpha >= 128) is centred on one canvas size shared by
all 8, so a frame and its focused twin line up and the glow has room: assets/ui/card_frames/frame_<1..4>.png and
frame_<1..4>_focus.png. art_raw/frames/dissolve_noise.webp (1254x1254 grey cloud noise) is saved as a 512x512 grey
PNG, assets/ui/fx/dissolve_noise.png, and its seams are measured (printed). Pixels are copied as they are.
--special (v0.10.5 W3-P10, owner 2026-11-05): art_raw/frames/card_special_6.webp (1536x1024, alpha), 3 x 2: the top row
the Constellation card (front, back, selected front), the bottom row the Starbound card. The front and back of each
go to assets/ui/card_frames/frame_<kind>.png and assets/ui/card_backs/back_<kind>.png; the selected fronts are not cut
(owner: "maybe we can skip this and add the own game selection").
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = os.path.join(ROOT, "art_raw", "frames", "card_frames_8.webp")
NOISE = os.path.join(ROOT, "art_raw", "frames", "dissolve_noise.webp")
BACKS = os.path.join(ROOT, "art_raw", "frames", "card_backs_8.webp")
SPECIAL = os.path.join(ROOT, "art_raw", "frames", "card_special_6.webp")
OUT = os.path.join(ROOT, "assets", "ui", "card_frames")
OUT_BACKS = os.path.join(ROOT, "assets", "ui", "card_backs")
FX = os.path.join(ROOT, "assets", "ui", "fx")
CANVAS = (400, 520)
NOISE_SIZE = 512
SPECIAL_SCALE = 433.0 / 457.0  # --special: body height to the W3-O15 frames
FADE = 16  # px: the canvas's outer ring fades to transparent


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


def frames(sheet=SHEET, out=OUT, prefix="frame", ncols=4, name_of=None):
    px = np.asarray(Image.open(sheet).convert("RGBA"))
    a = px[..., 3]
    rows = _runs((a > 16).any(1))
    assert len(rows) == 2, rows
    cols_of = []
    for y1, y2 in rows:
        cols = _runs((a[y1:y2] > 16).any(0))
        if len(cols) != ncols:  # the focused row's glows touch: take the bodies (alpha >= 128) and cut between them
            cols = _runs((a[y1:y2] >= 128).any(0))
        assert len(cols) == ncols, cols
        cols_of.append(cols)
    os.makedirs(out, exist_ok=True)
    cw, ch = CANVAS
    for ri, (y1, y2) in enumerate(rows):
        cols = cols_of[ri]
        for ci, (x1, x2) in enumerate(cols):
            pad = 60
            # never reach past the midpoint to the neighbouring card (the glows can touch)
            wx1 = max(0, x1 - pad, (cols[ci - 1][1] + x1) // 2 if ci > 0 else 0)
            wx2 = min(px.shape[1], x2 + pad, (x2 + cols[ci + 1][0]) // 2 if ci < ncols - 1 else px.shape[1])
            wy1 = max(0, y1 - pad, (rows[ri - 1][1] + y1) // 2 if ri > 0 else 0)  # nor to the other row's
            wy2 = min(px.shape[0], y2 + pad, (y2 + rows[ri + 1][0]) // 2 if ri < len(rows) - 1 else px.shape[0])
            sx1, sy1 = wx1, wy1
            sub = px[sy1:wy2, wx1:wx2]
            body = sub[..., 3] >= 128
            ys, xs = np.nonzero(body)
            bx1, bx2, by1, by2 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            cx, cy = sx1 + (bx1 + bx2) // 2, sy1 + (by1 + by2) // 2
            canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
            ox, oy = cx - cw // 2, cy - ch // 2
            # copy only this frame's neighbourhood (the sheet's other frames are > 30 px away)
            lx1, ly1 = max(ox, wx1), max(oy, wy1)
            lx2, ly2 = min(ox + cw, wx2), min(oy + ch, wy2)
            canvas[ly1 - oy : ly2 - oy, lx1 - ox : lx2 - ox] = px[ly1:ly2, lx1:lx2]
            # the sheet itself clips a glow at its own edge (a back at the sheet's bottom): fade the outer ring to 0
            dx = np.minimum(np.arange(cw), cw - 1 - np.arange(cw))
            dy = np.minimum(np.arange(ch), ch - 1 - np.arange(ch))
            ramp = np.minimum(dx[None, :], dy[:, None])
            fade = np.clip(ramp / float(FADE), 0.0, 1.0)
            canvas[..., 3] = (canvas[..., 3] * fade).astype(np.uint8)
            name = "%s_%d%s.png" % (prefix, ci + 1, "_focus" if ri else "")
            if name_of is not None:
                dest = name_of(ri, ci)
                if dest is None:
                    continue
                out, name = dest
                # this sheet's cards are drawn larger than the W3-O15 frames (body ~339x457 vs 302x433): scale the
                # canvas about its centre so the body is as tall as theirs (SPECIAL_SCALE), the width follows
                big = Image.fromarray(canvas, "RGBA")
                sw, sh = round(cw * SPECIAL_SCALE), round(ch * SPECIAL_SCALE)
                small = big.resize((sw, sh), Image.LANCZOS)
                canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
                canvas[(ch - sh) // 2 : (ch - sh) // 2 + sh, (cw - sw) // 2 : (cw - sw) // 2 + sw] = np.asarray(small)
            Image.fromarray(canvas, "RGBA").save(os.path.join(out, name))
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
    if "--special" in sys.argv:
        kinds = ("constellation", "starbound")

        def _special(ri, ci):
            if ci == 0:
                return OUT, "frame_%s.png" % kinds[ri]
            if ci == 1:
                return OUT_BACKS, "back_%s.png" % kinds[ri]
            return None

        frames(SPECIAL, OUT, "special", 3, _special)
    elif "--backs" in sys.argv:  # v0.10.5 W3-S13: card_backs_8.webp -> assets/ui/card_backs/back_<1..4>[_focus].png
        frames(BACKS, OUT_BACKS, "back")
    else:
        frames()
        noise()
