"""The role plates of an enemy model on its one shared colour map, for the enemy preps.

An enemy's glb has three surfaces over the same colour map: `base` (drawn as painted), `role` (the game multiplies it
by the kind's role colour, so its texels are greyscale in the map) and `glow`. Each triangle is on exactly one
surface, but the owner's maps paint the plates' colour, their pale wear and highlights and their dark seams texel by
texel, across triangle edges. So:
- a triangle is role when a real share of the texels under it are the plate colour (texel_share), not by the colour
  at its middle: a plate triangle carrying a highlight across its middle otherwise stays on base;
- pale triangles touching the plates join them (grow): a plate is one surface, so no base triangle sits inside it;
- the map greys exactly the texels the role triangles cover (tinted_map), all of them (wear and seams become lighter and
  darker tint), and leaves every other texel as painted. Greying the plate colour wherever it is painted instead put
  grey texels under base triangles, which the game draws untinted: the white facets and specks on the shells.
Needs numpy and Pillow.
"""

import numpy as np
from PIL import Image, ImageDraw

## Barycentric points a triangle's texels are read at (its centre, its corners and its edges' middles pulled in).
SAMPLE_AT = np.array([
    [1 / 3, 1 / 3, 1 / 3], [0.7, 0.15, 0.15], [0.15, 0.7, 0.15], [0.15, 0.15, 0.7],
    [0.425, 0.425, 0.15], [0.15, 0.425, 0.425], [0.425, 0.15, 0.425],
])
## The share of a triangle's texels on the plate colour that makes it a role plate.
ROLE_SHARE = 0.3
## The plates' mean texel in the greyscale map: an average plate texel shows the role colour at this share.
PLATE_GREY = 0.82
LUMA = np.array([0.299, 0.587, 0.114])


def sample(colour, uv):
    h, w = colour.shape[:2]
    x = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
    y = np.clip((uv[:, 1] * h).astype(int), 0, h - 1)
    return colour[y, x]


def texel_share(colour, UVw, T, test):
    """Per triangle: the share of the texels under it (at SAMPLE_AT) that pass `test` (rgb array -> bool array)."""
    uv = UVw[T]
    hit = [test(sample(colour, np.einsum("k,tkc->tc", w, uv))) for w in SAMPLE_AT]
    return np.mean(hit, axis=0)


def grow(k, nb, candidates, passes=4):
    """`k` (per triangle: 1 role) with each candidate triangle that shares an edge with a role triangle made role,
    repeated `passes` times (the wear along a plate's edge can be a few triangles deep). nb: each triangle's edge
    neighbours."""
    k = k.copy()
    left = candidates & (k != 1)
    for _ in range(passes):
        add = [t for t in np.where(left)[0] if any(k[o] == 1 for o in nb[t])]
        if not add:
            break
        k[add] = 1
        left[add] = False
    return k


def footprint(size, UVw, T):
    """The texels the triangles cover in a colour map of `size` (h, w): a mask."""
    h, w = size
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    for tri in UVw[T]:
        d.polygon([(float(u) * w, float(v) * h) for u, v in tri], fill=255)
    return np.asarray(im) > 0


def tinted_map(colour, UVw, role_tris, other_tris, plate_test):
    """The colour map with every texel the role triangles cover in greyscale, scaled so the plate texels (plate_test)
    average PLATE_GREY, and every other texel as painted; the role footprint grows 2 texels into texels no triangle
    covers, so mipmaps do not bleed colour into it."""
    img = colour.copy()
    role = footprint(img.shape[:2], UVw, role_tris)
    other = footprint(img.shape[:2], UVw, other_tris)
    grown = role.copy()
    for _ in range(2):
        grown = grown | np.roll(grown, 1, 0) | np.roll(grown, -1, 0) | np.roll(grown, 1, 1) | np.roll(grown, -1, 1)
    grey = role | (grown & ~other)
    lum = img @ LUMA
    plate = role & plate_test(img)
    if plate.any():
        g = np.clip(lum / max(lum[plate].mean(), 1e-3) * PLATE_GREY, 0, 1)
        img[grey] = g[grey, None]
    return img
