"""Prepares the owner's VFX textures (unprocessed_images/vfx/) for the game (docs/art/VFX_REQUESTS.md).

Each upload is on pure black; the game needs transparency. Per kind:
- glow (flames, explosion fireballs, sparks, lightning): alpha = the brightest channel, colour un-premultiplied
  (so additive or alpha blending gives the uploaded look on any background);
- mask (smoke puffs, scorch mark): greyscale; alpha = luminance; colour white (the engine tints it);
- cutout (debris chunks): solid objects; alpha = a soft threshold on brightness, colour kept;
- noise (fire noise, electric noise): greyscale, made seamless by offset-and-blend, no alpha.
Sizes: sheets 1024 px, noise 512 px. Writes assets/textures/vfx/<id>.png and prints each sha256.

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
}


def glow(rgb: np.ndarray) -> np.ndarray:
    a = rgb.max(axis=2, keepdims=True)
    colour = np.where(a > 1e-3, rgb / np.maximum(a, 1e-3), 0.0)
    return np.concatenate([colour, a], axis=2)


def mask(rgb: np.ndarray) -> np.ndarray:
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    a = np.clip(lum[..., None] * 1.15, 0.0, 1.0)
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


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for vid, kind in KINDS.items():
        src = Image.open(os.path.join(SRC, vid + ".png")).convert("RGB")
        px = NOISE_PX if kind == "noise" else SHEET_PX
        rgb = np.asarray(src.resize((px, px), Image.LANCZOS)).astype(float) / 255.0
        if kind == "noise":
            out = seamless(rgb.mean(axis=2, keepdims=True).repeat(3, axis=2))
            img = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8), "RGB")
        else:
            out = {"glow": glow, "mask": mask, "cutout": cutout}[kind](rgb)
            img = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8), "RGBA")
        path = os.path.join(OUT, vid + ".png")
        img.save(path)
        print("%s  %8d  %s" % (hashlib.sha256(open(path, "rb").read()).hexdigest(), os.path.getsize(path), path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
