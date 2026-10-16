"""v0.8.0 TX1: prepares the owner's attack textures (docs/art/requests/v0.8.0_textures.md, the A rows TX1 installs)
from unprocessed_images/vfx/ into assets/textures/vfx/, as vfx_prep.py does for the first VFX textures.

These uploads came with an alpha channel already (a transparent background, its colour left as junk), so each is first
laid on black (colour x alpha), then turned into a two-channel greyscale mask (an LA PNG) the game tints with its own
colours per boss, enemy and look (palette A and the enemy colours stay the code's):
- glow (beams, impacts, aim lines, sigils, trails): A = the brightest channel (as vfx_prep's glow: brightness becomes
  coverage), L = the whiteness (the darkest channel over the brightest: 1 at a white-hot core, 0 at a pure colour), so
  a shader draws mix(tint, hot, L) * A;
- core (the orb cores): A = the upload's own alpha (the object's outline), L = the lightness ((max + min) / 2: dark
  rock plates low, glowing cracks and white-hot spots high), which the orb shader tints with the look's core colour.
Layouts: "2x2" sheets are cut in quarters, each variant trimmed to its content and centred in a cell of a square 2 x 2
sheet (vfx_prep.regrid); "1x4" strips are cut into their four bands (by the empty rows between them), each band
stretched to fill one row of a square sheet at full width (so a beam's seamless left and right ends stay seamless).
Sizes (power of two): the orb sheets and the aim lines 512 px (the orb_cores_2 upload is 500 px; the shots are small
on screen), the rest 1024 px. Writes assets/textures/vfx/<id>.png and prints each sha256 and size.

Run from the repo root: python3 -I scripts/assets/vfx_prep_attacks.py   (needs Pillow and numpy)
"""

import hashlib
import os
import sys

import numpy as np
from PIL import Image

SRC = "unprocessed_images/vfx"
OUT = "assets/textures/vfx"
## id: (kind, layout, size).
SPECS = {
    "fx_orb_cores": ("core", "2x2", 512),
    "fx_orb_cores_2": ("core", "2x2", 512),
    "fx_orb_cores_final": ("core", "2x2", 512),
    "fx_trails": ("glow", "1x4", 1024),
    "fx_beam": ("glow", "1x4", 1024),
    "fx_beam_impact": ("glow", "2x2", 1024),
    "fx_aim_lines": ("glow", "1x4", 512),
    "fx_cast_sigils": ("glow", "2x2", 1024),
}
## Margin round each variant, as a share of its cell (2 x 2) or of its row's height (1 x 4).
MARGIN = 0.06
STRIP_MARGIN = 0.04


def _on_black(img: Image.Image) -> np.ndarray:
    a = np.asarray(img.convert("RGBA")).astype(float) / 255.0
    return np.concatenate([a[..., :3] * a[..., 3:4], a[..., 3:4]], axis=2)


def _span(occupied: np.ndarray) -> tuple:
    """As vfx_prep._span: the content's first and last index, leaving out a small stray strip at either edge."""
    idx = np.nonzero(occupied)[0]
    runs = np.split(idx, np.nonzero(np.diff(idx) > 4)[0] + 1)
    n = len(occupied)
    if len(runs) > 1 and runs[0][0] == 0 and len(runs[0]) < n * 0.1:
        runs = runs[1:]
    if len(runs) > 1 and runs[-1][-1] == n - 1 and len(runs[-1]) < n * 0.1:
        runs = runs[:-1]
    return int(runs[0][0]), int(runs[-1][-1])


def _occupied(px: np.ndarray) -> np.ndarray:
    return px[..., :3].max(axis=2) > 0.05


def _trim(px: np.ndarray) -> np.ndarray:
    g = _occupied(px)
    if not g.any():
        return px
    y0, y1 = _span(g.any(axis=1))
    x0, x1 = _span(g.any(axis=0))
    return px[y0 : y1 + 1, x0 : x1 + 1]


def _resize(px: np.ndarray, w: int, h: int) -> np.ndarray:
    chans = [
        np.asarray(Image.fromarray(px[..., c].astype(np.float32), "F").resize((w, h), Image.LANCZOS))
        for c in range(px.shape[2])
    ]
    return np.clip(np.stack(chans, axis=2), 0.0, 1.0)


def grid(px: np.ndarray, size: int) -> np.ndarray:
    """A 2 x 2 upload re-laid as a square 2 x 2 sheet, each quarter's variant trimmed and centred in its cell."""
    out = np.zeros((size, size, px.shape[2]))
    h, w = px.shape[:2]
    cell = size // 2
    inner = int(cell * (1.0 - 2.0 * MARGIN))
    for i in range(4):
        c, r = i % 2, i // 2
        part = _trim(px[r * h // 2 : (r + 1) * h // 2, c * w // 2 : (c + 1) * w // 2])
        k = inner / max(part.shape[:2])
        pw, ph = max(1, round(part.shape[1] * k)), max(1, round(part.shape[0] * k))
        part = _resize(part, pw, ph)
        x = c * cell + (cell - pw) // 2
        y = r * cell + (cell - ph) // 2
        out[y : y + ph, x : x + pw] = part
    return out


def strips(px: np.ndarray, size: int) -> np.ndarray:
    """A 1 x 4 upload (four bands stacked) re-laid as a square sheet, each band filling its row at full width."""
    rows = _occupied(px).any(axis=1)
    idx = np.nonzero(rows)[0]
    runs = [r for r in np.split(idx, np.nonzero(np.diff(idx) > 1)[0] + 1) if len(r) > 3]
    h = px.shape[0]
    if len(runs) != 4:
        bands = [(k * h // 4, (k + 1) * h // 4 - 1) for k in range(4)]
    else:
        bands = [(int(r[0]), int(r[-1])) for r in runs]
    out = np.zeros((size, size, px.shape[2]))
    row = size // 4
    inner = int(row * (1.0 - 2.0 * STRIP_MARGIN))
    for k, (y0, y1) in enumerate(bands):
        part = _resize(px[y0 : y1 + 1], size, inner)
        y = k * row + (row - inner) // 2
        out[y : y + inner] = part
    return out


def encode(px: np.ndarray, kind: str) -> Image.Image:
    rgb = px[..., :3]
    hi = rgb.max(axis=2)
    lo = rgb.min(axis=2)
    if kind == "glow":
        a = hi
        lum = np.where(hi > 1e-3, lo / np.maximum(hi, 1e-3), 0.0)
    else:
        a = px[..., 3]
        safe = np.maximum(a, 1e-3)
        lum = np.where(a > 1e-3, (hi + lo) * 0.5 / safe, 0.0)  # the lightness of the un-premultiplied colour
    la = np.stack([np.clip(lum, 0, 1), np.clip(a, 0, 1)], axis=2)
    return Image.fromarray((la * 255).round().astype(np.uint8), "LA")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for vid, (kind, layout, size) in SPECS.items():
        px = _on_black(Image.open(os.path.join(SRC, vid + ".png")))
        px = grid(px, size) if layout == "2x2" else strips(px, size)
        img = encode(px, kind)
        path = os.path.join(OUT, vid + ".png")
        img.save(path, optimize=True)
        print("%s  %8d  %s" % (hashlib.sha256(open(path, "rb").read()).hexdigest(), os.path.getsize(path), path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
