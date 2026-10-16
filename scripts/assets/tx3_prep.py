"""v0.8.0 TX3: prepares the owner's menu, glyph and ambient textures (docs/art/requests/v0.8.0_textures.md).

Sources (1254 px squares): unprocessed_images/v080_tex/ (RGB) and unprocessed_images/vfx/ (RGBA). Per id:
- tex_menu_stone (512, grey): the Ember stone slabs' grain (EmberStone.grain). The slabs multiply their colour by it,
  so it is the upload's luminance remapped round 0.82 (its 5th..95th percentile to about 0.64..0.98; the mortar lines
  darker), grey, no alpha. Kept low in contrast so text reads on top.
- tex_menu_stone_wall (1024, colour): the main menu's own backdrop (MenuBackdrop), as uploaded, downscaled.
- ui_element_glyphs, ui_element_glyphs_2 (512, 2 x 2): the element glyphs (ElementGlyphs). Carved stone on black:
  cutout (alpha a soft threshold on brightness, colour kept), as fx_debris_chunks.
- fx_ember_sparks, fx_star_motes (512, 2 x 2): ambient particles. The upload's alpha is laid over black first (its
  transparent pixels carry stray colour), then glow (alpha the brightest channel, colour un-premultiplied), as the
  other glow sheets (scripts/assets/vfx_prep.py).
Writes assets/textures/ui/<id>.png and assets/textures/vfx/<id>.png and prints each one's sha256 and size.

Run from the repo root: python3 -I scripts/assets/tx3_prep.py   (needs Pillow and numpy)
"""

import hashlib
import os
import sys

import numpy as np
from PIL import Image

TEX = "unprocessed_images/v080_tex"
VFX = "unprocessed_images/vfx"
UI_OUT = "assets/textures/ui"
VFX_OUT = "assets/textures/vfx"
## id: (source folder, output folder, size px, kind)
JOBS = {
    "tex_menu_stone": (TEX, UI_OUT, 512, "grain"),
    "tex_menu_stone_wall": (TEX, UI_OUT, 1024, "colour"),
    "ui_element_glyphs": (TEX, UI_OUT, 512, "cutout"),
    "ui_element_glyphs_2": (TEX, UI_OUT, 512, "cutout"),
    "fx_ember_sparks": (VFX, VFX_OUT, 512, "glow"),
    "fx_star_motes": (VFX, VFX_OUT, 512, "glow"),
}
## The grain's centre and its gain per unit of luminance (starting values).
GRAIN_MID = 0.82
GRAIN_GAIN = 2.7


def _rgb(path: str, px: int) -> np.ndarray:
    """The upload as float RGB at px, any alpha laid over black."""
    img = Image.open(path)
    if img.mode == "RGBA":
        a = np.asarray(img).astype(float) / 255.0
        rgb = a[..., :3] * a[..., 3:4]
        img = Image.fromarray((rgb * 255).round().astype(np.uint8), "RGB")
    img = img.convert("RGB").resize((px, px), Image.LANCZOS)
    return np.asarray(img).astype(float) / 255.0


def grain(rgb: np.ndarray) -> np.ndarray:
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    g = np.clip(GRAIN_MID + (lum - lum.mean()) * GRAIN_GAIN, 0.35, 1.0)
    return np.repeat(g[..., None], 3, axis=2)


def glow(rgb: np.ndarray) -> np.ndarray:
    a = rgb.max(axis=2, keepdims=True)
    colour = np.where(a > 1e-3, rgb / np.maximum(a, 1e-3), 0.0)
    return np.concatenate([colour, a], axis=2)


def cutout(rgb: np.ndarray) -> np.ndarray:
    m = rgb.max(axis=2, keepdims=True)
    a = np.clip((m - 0.04) / 0.06, 0.0, 1.0)
    return np.concatenate([rgb, a], axis=2)


def main() -> int:
    for vid, (src, out, px, kind) in JOBS.items():
        os.makedirs(out, exist_ok=True)
        rgb = _rgb(os.path.join(src, vid + ".png"), px)
        if kind == "grain":
            data, mode = grain(rgb), "RGB"
        elif kind == "colour":
            data, mode = rgb, "RGB"
        else:
            data, mode = {"glow": glow, "cutout": cutout}[kind](rgb), "RGBA"
        img = Image.fromarray((np.clip(data, 0, 1) * 255).round().astype(np.uint8), mode)
        path = os.path.join(out, vid + ".png")
        img.save(path, optimize=True)
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
        print("%s  %8d  %s" % (digest, os.path.getsize(path), path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
