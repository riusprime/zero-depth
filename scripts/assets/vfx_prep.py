"""Prepares the owner's VFX textures (unprocessed_images/vfx/) for the game (docs/art/VFX_REQUESTS.md).

Each upload is on pure black; the game needs transparency. Per kind:
- glow (flames, explosion fireballs, sparks, lightning): alpha = the brightest channel, colour un-premultiplied
  (so additive or alpha blending gives the uploaded look on any background);
- mask (smoke puffs, scorch mark): greyscale; alpha = luminance; colour white (the engine tints it);
- cutout (debris chunks): solid objects; alpha = a soft threshold on brightness, colour kept;
- noise (fire noise, electric noise): greyscale, made seamless by offset-and-blend, no alpha.
Sizes: sheets 1024 px, noise 512 px. Writes assets/textures/vfx/<id>.png and prints each sha256.
Phase 2 uploads came in other layouts (1536 x 1024, four in a row): GRIDS names each one's layout; its variants
are cut out, each trimmed to its content and centred in a cell of a square 2 x 2 sheet (or the whole square, for a
single image). GAIN raises a mask's alpha (thin grey wisps that would otherwise be too faint).

Run from the repo root: python3 -I scripts/assets/vfx_prep.py   (needs Pillow and numpy)
"""

import hashlib
import os
import sys

import numpy as np
from PIL import Image

SRC = "unprocessed_images/vfx"
OUT = "assets/textures/vfx"
SHEET_PX = 1024
NOISE_PX = 512
KINDS = {
    "fx_flame_shapes": "glow",
    "fx_explosion_burst": "glow",
    "fx_spark_shapes": "glow",
    "fx_lightning_bolts": "glow",
    "fx_smoke_puffs": "mask",
    "fx_scorch_mark": "mask",
    "fx_debris_chunks": "cutout",
    "fx_fire_noise": "noise",
    "fx_electric_noise": "noise",
    # Phase 2 (frost, venom, void, bleed).
    "fx_frost_mark": "mask",
    "fx_frost_burst": "mask",
    "fx_liquid_splash": "mask",
    "fx_splatter_mark": "mask",
    "fx_bubbles": "mask",
    "fx_void_tendrils": "mask",
    "fx_void_rift": "glow",
    "fx_void_noise": "noise",
}
## The upload's layout (columns, rows) for the phase 2 sheets that are re-gridded; (1, 1) = one image, centred.
GRIDS = {
    "fx_frost_mark": (1, 1),
    "fx_frost_burst": (1, 1),
    "fx_liquid_splash": (2, 2),
    "fx_splatter_mark": (2, 2),
    "fx_bubbles": (2, 2),
    "fx_void_tendrils": (2, 2),
    "fx_void_rift": (4, 1),
}
GAIN = {"fx_void_tendrils": 1.7}
## Margin round each re-gridded variant, as a share of its cell.
MARGIN = 0.06


def glow(rgb: np.ndarray) -> np.ndarray:
    a = rgb.max(axis=2, keepdims=True)
    colour = np.where(a > 1e-3, rgb / np.maximum(a, 1e-3), 0.0)
    return np.concatenate([colour, a], axis=2)


def mask(rgb: np.ndarray, gain: float = 1.15) -> np.ndarray:
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    a = np.clip(lum[..., None] * gain, 0.0, 1.0)
    return np.concatenate([np.ones_like(rgb), a], axis=2)


def cutout(rgb: np.ndarray) -> np.ndarray:
    m = rgb.max(axis=2, keepdims=True)
    a = np.clip((m - 0.04) / 0.06, 0.0, 1.0)
    return np.concatenate([rgb, a], axis=2)


def seamless(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    rolled = np.roll(np.roll(img, h // 2, axis=0), w // 2, axis=1)
    y = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h / 2)
    x = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w / 2)
    m = np.outer(np.clip((y - 0.15) / 0.5, 0, 1), np.clip((x - 0.15) / 0.5, 0, 1))[..., None]
    m = m * m * (3 - 2 * m)
    return img * m + rolled * (1 - m)


def _span(occupied: np.ndarray) -> tuple:
    """The content's first and last index along one axis, leaving out a small strip of content at either edge cut
    off from the rest by empty space (a neighbouring variant's stray drop that crosses the cell line)."""
    idx = np.nonzero(occupied)[0]
    runs = np.split(idx, np.nonzero(np.diff(idx) > 4)[0] + 1)
    n = len(occupied)
    if len(runs) > 1 and runs[0][0] == 0 and len(runs[0]) < n * 0.1:
        runs = runs[1:]
    if len(runs) > 1 and runs[-1][-1] == n - 1 and len(runs[-1]) < n * 0.1:
        runs = runs[:-1]
    return int(runs[0][0]), int(runs[-1][-1])


def _trim(img: Image.Image) -> Image.Image:
    """The image cropped to its content (anything brighter than near-black)."""
    g = np.asarray(img.convert("L")) > 12
    if not g.any():
        return img
    y0, y1 = _span(g.any(axis=1))
    x0, x1 = _span(g.any(axis=0))
    return img.crop((x0, y0, x1 + 1, y1 + 1))


def regrid(src: Image.Image, cols: int, rows: int, px: int) -> Image.Image:
    """Cuts a cols x rows upload into its variants and lays them out as a square 2 x 2 sheet (or one image)."""
    out = Image.new("RGB", (px, px), (0, 0, 0))
    w, h = src.size
    cells = [
        src.crop((c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows))
        for r in range(rows)
        for c in range(cols)
    ]
    n = 1 if cols * rows == 1 else 2
    cell = px // n
    inner = int(cell * (1.0 - 2.0 * MARGIN))
    for i, part in enumerate(cells):
        part = _trim(part)
        k = inner / max(part.size)
        part = part.resize((max(1, round(part.size[0] * k)), max(1, round(part.size[1] * k))), Image.LANCZOS)
        x = (i % n) * cell + (cell - part.size[0]) // 2
        y = (i // n) * cell + (cell - part.size[1]) // 2
        out.paste(part, (x, y))
    return out


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for vid, kind in KINDS.items():
        src = Image.open(os.path.join(SRC, vid + ".png")).convert("RGB")
        px = NOISE_PX if kind == "noise" else SHEET_PX
        if vid in GRIDS:
            src = regrid(src, GRIDS[vid][0], GRIDS[vid][1], px)
        rgb = np.asarray(src.resize((px, px), Image.LANCZOS)).astype(float) / 255.0
        if kind == "noise":
            out = seamless(rgb.mean(axis=2, keepdims=True).repeat(3, axis=2))
            img = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8), "RGB")
        else:
            if kind == "mask":
                out = mask(rgb, GAIN.get(vid, 1.15))
            else:
                out = {"glow": glow, "cutout": cutout}[kind](rgb)
            img = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8), "RGBA")
        path = os.path.join(OUT, vid + ".png")
        img.save(path)
        print("%s  %8d  %s" % (hashlib.sha256(open(path, "rb").read()).hexdigest(), os.path.getsize(path), path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
