"""v0.8.0 Step TX2: prepares the owner's ground, impact and surface textures (docs/art/requests/v0.8.0_textures.md)
for the game. Sources: unprocessed_images/vfx/ (effects) and unprocessed_images/v080_tex/ (surfaces), all 1254 px
(the steam and the crystal sheets 1536 x 1024, the dust ring 1287 x 1222).

Per kind (the helpers glow / regrid are vfx_prep.py's, loaded from beside this file):
- rgba (rock burst, acid splat, skid marks, light ring): the upload already has transparency; resized only;
- glow (steam puffs, crystal shatter: RGB on black, a 3 x 2 upload re-gridded to a 2 x 2 sheet): alpha = the
  brightest channel, colour un-premultiplied (as vfx_prep's glow);
- cracks (ground cracks, painted on brown ground, not on black): alpha = the glowing crack (red over green, or a
  bright red channel), colour kept, so the shaders use alpha as the crack's shape and tint it;
- dust (dust ring, painted on brown ground): alpha = the pale dust (bright) or the grey stones (unsaturated), colour
  kept;
- surface (lava flow, lava crust, the four marker fills, spike stone): RGB colour; alpha = the texture's glowing or
  bright features (per id, SURFACES; never below ALPHA_FLOOR), which the shaders heat; cross-faded at the edges so the tile has no seam.
Sizes: sheets 1024 px, the light ring and every surface 512 px. Writes assets/textures/vfx/<id>.png (effects) and
assets/textures/kit/<id>.png (surfaces) and prints each sha256 and each tile's seam check (the mean step across the
wrapped edge against the mean step between neighbouring pixels: equal means no seam).

Run from the repo root: python3 -I scripts/assets/tx2_prep.py   (needs Pillow and numpy)
"""

import hashlib
import importlib.util
import os
import sys

import numpy as np
from PIL import Image

_spec = importlib.util.spec_from_file_location("vfx_prep", os.path.join(os.path.dirname(__file__), "vfx_prep.py"))
vfx_prep = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vfx_prep)

VFX_SRC = "unprocessed_images/vfx"
TEX_SRC = "unprocessed_images/v080_tex"
VFX_OUT = "assets/textures/vfx"
TEX_OUT = "assets/textures/kit"
SHEET_PX = 1024
SMALL_PX = 512
## Effects: id -> kind.
EFFECTS = {
    "fx_ground_cracks": "cracks",
    "fx_rock_burst": "rgba",
    "fx_dust_ring": "dust",
    "fx_light_ring": "rgba",
    "fx_acid_splat": "rgba",
    "fx_steam_puffs": "glow",
    "fx_skid_marks": "rgba",
    "fx_crystal_shatter": "glow",
}
SMALL = {"fx_light_ring"}
## The 3 x 2 uploads (1536 x 1024) are four variants in a 2 x 2 layout already (two empty thirds), re-gridded.
GRIDS = {"fx_steam_puffs": (2, 2), "fx_crystal_shatter": (2, 2)}
## Surfaces: id -> (source folder, feature). Feature: what the alpha marks (the part the shaders heat).
SURFACES = {
    "fx_lava_flow": (VFX_SRC, "bright"),
    "tex_lava_crust": (TEX_SRC, "hot"),
    "tex_mark_steel": (TEX_SRC, "scratch"),
    "tex_mark_hazard": (TEX_SRC, "amber"),
    "tex_mark_acid": (TEX_SRC, "green"),
    "tex_mark_light": (TEX_SRC, "gold"),
    "tex_stone_spike": (TEX_SRC, "hot"),
}
## The edge cross-fade (share of the source's width) that makes a tile wrap.
BAND = 0.06
## A surface's least alpha (see main).
ALPHA_FLOOR = 8.0 / 255.0


def _smooth(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def cracks(rgb: np.ndarray) -> np.ndarray:
    r, g = rgb[..., 0], rgb[..., 1]
    a = np.maximum(_smooth(r - g, 0.24, 0.4), _smooth(r, 0.62, 0.8))
    return np.concatenate([rgb, a[..., None]], axis=2)


def dust(rgb: np.ndarray) -> np.ndarray:
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    pale = _smooth(lum, 0.46, 0.58)
    stone = _smooth(0.1 - sat, 0.0, 0.04) * _smooth(lum, 0.12, 0.2)
    return np.concatenate([rgb, np.maximum(pale, stone)[..., None]], axis=2)


def feature(rgb: np.ndarray, kind: str) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    if kind == "bright":  # the lava's yellow veins
        return _smooth(g, 0.45, 0.8)
    if kind == "hot":  # glowing orange-red seams and cracks over dark or grey rock
        return _smooth(r - b, 0.3, 0.55) * _smooth(r, 0.45, 0.7)
    if kind == "scratch":  # the steel's pale scratches over the plate (brighter than its neighbourhood)
        blur = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(_blur(9))).astype(float) / 255.0
        return _smooth(lum - blur, 0.03, 0.12)
    if kind == "amber":  # the hazard stripes' paint
        return _smooth(r - b, 0.25, 0.45)
    if kind == "green":  # the acid's pools
        return _smooth(g - (r + b) * 0.5, 0.2, 0.4)
    if kind == "gold":  # the light's seams over the violet stone
        return _smooth((r + g) * 0.5 - b, 0.05, 0.2)
    raise ValueError(kind)


def _blur(radius: int):
    from PIL import ImageFilter

    return ImageFilter.GaussianBlur(radius)


def wrap(img: np.ndarray, band: int) -> np.ndarray:
    """A tile that wraps: the last `band` pixels on each axis cross-fade into the first ones (the tile is `band`
    smaller). Structure stays sharp everywhere but in the band."""
    for axis in (1, 0):
        n = img.shape[axis]
        keep = n - band
        t = np.linspace(0.0, 1.0, band)
        t = t * t * (3.0 - 2.0 * t)
        shape = [1, 1, 1]
        shape[axis] = band
        t = t.reshape(shape)
        head = np.take(img, range(0, band), axis=axis)
        tail = np.take(img, range(keep, n), axis=axis)
        body = np.take(img, range(0, keep), axis=axis).copy()
        idx = [slice(None)] * 3
        idx[axis] = slice(0, band)
        body[tuple(idx)] = tail * (1.0 - t) + head * t
        img = body
    return img


def hazard_period(rgb: np.ndarray) -> int:
    """The hazard stripes' period (px): the autocorrelation of the amber mask, summed over rows and over columns,
    peaks again one period on (after its first dip); the rows' and the columns' periods averaged."""
    m = feature(rgb, "amber")
    out = []
    for lines in (m, m.T):
        ac = 0.0
        for k in range(lines.shape[0] // 12, lines.shape[0], lines.shape[0] // 12):
            r = lines[k] - lines[k].mean()
            ac = ac + np.correlate(r, r, mode="full")[len(r) - 1 :]
        dip = int(np.argmin(ac[: len(ac) * 9 // 16]))
        out.append(dip + int(np.argmax(ac[dip : len(ac) * 3 // 4])))
    return int(round(sum(out) / 2.0))


def seam(img: np.ndarray) -> str:
    rgb = img[..., :3] * 255.0
    adj_x = np.abs(np.diff(rgb, axis=1)).mean()
    adj_y = np.abs(np.diff(rgb, axis=0)).mean()
    wrap_x = np.abs(rgb[:, 0] - rgb[:, -1]).mean()
    wrap_y = np.abs(rgb[0] - rgb[-1]).mean()
    return "seam x %.1f (neighbours %.1f)  y %.1f (neighbours %.1f)" % (wrap_x, adj_x, wrap_y, adj_y)


def _save(arr: np.ndarray, mode: str, path: str) -> None:
    Image.fromarray((np.clip(arr, 0, 1) * 255).round().astype(np.uint8), mode).save(path, optimize=True)
    data = open(path, "rb").read()
    print("%s  %8d  %s" % (hashlib.sha256(data).hexdigest(), len(data), path))


def main() -> int:
    os.makedirs(VFX_OUT, exist_ok=True)
    os.makedirs(TEX_OUT, exist_ok=True)
    for vid, kind in EFFECTS.items():
        src = Image.open(os.path.join(VFX_SRC, vid + ".png"))
        px = SMALL_PX if vid in SMALL else SHEET_PX
        if kind == "rgba":
            arr = np.asarray(src.convert("RGBA").resize((px, px), Image.LANCZOS)).astype(float) / 255.0
            _save(arr, "RGBA", os.path.join(VFX_OUT, vid + ".png"))
            continue
        src = src.convert("RGB")
        if vid in GRIDS:
            src = vfx_prep.regrid(src, GRIDS[vid][0], GRIDS[vid][1], px)
        rgb = np.asarray(src.resize((px, px), Image.LANCZOS)).astype(float) / 255.0
        out = {"glow": vfx_prep.glow, "cracks": cracks, "dust": dust}[kind](rgb)
        _save(out, "RGBA", os.path.join(VFX_OUT, vid + ".png"))
    for tid, (folder, feat) in SURFACES.items():
        src = Image.open(os.path.join(folder, tid + ".png")).convert("RGB")
        rgb = np.asarray(src).astype(float) / 255.0
        if tid == "tex_mark_hazard":
            # Diagonal stripes tile only over a whole number of periods: crop to the most periods that fit (the
            # cross-fade band included), so the stripes run on across the wrap.
            p = hazard_period(rgb)
            n = int((rgb.shape[1] * (1.0 - BAND)) // p)
            band = int(rgb.shape[1] * BAND)
            side = n * p + band
            rgb = rgb[:side, :side]
            print("tex_mark_hazard: stripe period %d px, %d periods, crop %d px" % (p, n, side))
        else:
            band = int(rgb.shape[1] * BAND)
        print("%s source:   %s" % (tid, seam(rgb)))
        rgb = wrap(rgb, band)
        # The alpha never reaches 0: the importer's fix_alpha_border repaints fully transparent pixels, and a
        # surface's colour is used everywhere (the feature only says where it heats).
        a = ALPHA_FLOOR + (1.0 - ALPHA_FLOOR) * feature(rgb, feat)
        out = np.concatenate([rgb, a[..., None]], axis=2)
        # Colour and alpha resized apart: an RGBA resize premultiplies, darkening the colour where the alpha is low.
        img = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8), "RGBA")
        bands = [b.resize((SMALL_PX, SMALL_PX), Image.LANCZOS) for b in img.split()]
        arr = np.asarray(Image.merge("RGBA", bands)).astype(float) / 255.0
        print("%s installed: %s" % (tid, seam(arr)))
        dest = VFX_OUT if tid.startswith("fx_") else TEX_OUT
        _save(arr, "RGBA", os.path.join(dest, tid + ".png"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
