"""v0.8.0 Step N10 (owners O66, O67): prepares the owner's wall textures (docs/art/requests/v0.8.0_walls.md, delivered
2026-10-17 in unprocessed_images/walls/, each 1536 x 1024 RGB) for the procedural walls (ProceduralWall, option A).

- tex_wall_<biome> (the face): its left and right edges cross-faded over BAND of its width (tx2_prep.wrap on that
  axis only) so it repeats along a wall; not across its height: the walls map it once from the top down (its rust
  drips and frost stay at the wall's top), so its top and bottom never meet.
- tex_wall_top_<biome> (the broken top seen from above): cross-faded on both axes (it tiles over the walls' tops).
Both are then brightened so their mean is TEXTURE_MEAN, kit_prep.py's MODEL_MEAN for the kit's textures (one factor
for all three channels, so the colours keep their hue; the uploads average 0.23-0.57, which reads black under the
night moods). Both keep their 3:2 shape and size (1536 x 1024; the game maps metres to it at that aspect, ProceduralWall.FACE_M and
TOP_M). Writes assets/textures/kit/<id>.png and prints each sha256 and the seam check (the mean step across the
wrapped edge against the mean step between neighbouring pixels: equal means no seam).

Run from the repo root: python3 -I scripts/assets/n10_wall_prep.py   (needs Pillow and numpy)
"""

import importlib.util
import os
import sys

import numpy as np
from PIL import Image

_spec = importlib.util.spec_from_file_location("tx2_prep", os.path.join(os.path.dirname(__file__), "tx2_prep.py"))
tx2_prep = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tx2_prep)

SRC = "unprocessed_images/walls"
OUT = "assets/textures/kit"
BIOMES = ["ruins", "night_rocks", "red_canyon", "frozen_shore", "starfall"]
BAND = 0.06
TEXTURE_MEAN = 0.55


def wrap_x(img: np.ndarray, band: int) -> np.ndarray:
    """tx2_prep.wrap on the horizontal axis only."""
    n = img.shape[1]
    keep = n - band
    t = np.linspace(0.0, 1.0, band)
    t = (t * t * (3.0 - 2.0 * t)).reshape(1, band, 1)
    body = img[:, :keep].copy()
    body[:, :band] = img[:, keep:] * (1.0 - t) + img[:, :band] * t
    return body


def prep(tid: str, both: bool) -> None:
    src = Image.open(os.path.join(SRC, tid + ".png")).convert("RGB")
    w, h = src.size
    arr = np.asarray(src).astype(float) / 255.0
    print("%s source:    %s" % (tid, tx2_prep.seam(arr)))
    band = int(w * BAND)
    if both:
        arr = tx2_prep.wrap(arr, band)
    else:
        arr = wrap_x(arr, band)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).round().astype(np.uint8), "RGB").resize((w, h), Image.LANCZOS)
    arr = np.asarray(img).astype(float) / 255.0
    arr = np.clip(arr * (TEXTURE_MEAN / arr.mean()), 0.0, 1.0)
    print("%s installed: %s" % (tid, tx2_prep.seam(arr)))
    tx2_prep._save(arr, "RGB", os.path.join(OUT, tid + ".png"))


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for b in BIOMES:
        prep("tex_wall_" + b, False)
        prep("tex_wall_top_" + b, True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
