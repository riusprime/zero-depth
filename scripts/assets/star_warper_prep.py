"""Prepares the owner's Star Warper (unprocessed_images/models_v0120_b/star_warper.glb) for the game:
assets/models/enemies/star_warper.glb, cut into the parts StarWarperAvatar animates.

The raw file is a Tripo export: one textured mesh (4,834 triangles, a 2048 px colour map; the hull and three small
loose star shards round the head), one unit tall, no rig, Y up, its front (the charcoal face plate with its violet gem
visor in the middle of the big five-pointed violet star that is its head) on +Z: a narrow hourglass charcoal torso with
violet hip plates, two long thin grey arms spread low ending in bone blade claws, and no legs: a long tapering grey
segmented tail curling under it and back. The owner, on the model having no legs: it might be a "floating" creature,
so the game floats it. The raw file stays untouched. This script, reusing mi_prep's reader, normals and glb writer and
the Frost Spitter prep's colour sampling, cut caps and smoothing:
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres it on x/z with the tail's lowest point
   on y = 0 and scales it evenly to HEIGHT_M (the stand-in's 1.15 m);
2. cuts it into the parts that move, by place and colour: the head (the star with its face plate and visor, above the
   neck), each arm's upper half (shoulder to elbow) and forearm (with the claws), the tail in three segments (the root,
   the middle, the curl) so it trails and sways as a chain, the three shards (the loose pieces) and the torso with its
   hip plates (the rig's root). Every part node's origin is its pivot (the neck, the shoulder, the elbow, each tail
   joint, the head's middle for the shards);
3. caps the cuts (a fan over each part's cut edges facing the part across the cut), in the charcoal of the body;
4. sorts each triangle into a surface by the colour map under it: `glow` (the visor's gem; the three shards whole, so
   they glow as the star gathers), `role` (the saturated violet plates of the star and the hips: their texels greyscale
   in the map so the game tints them in the kind's role colour) and `base` (the charcoal, the greys, the bone claws);
5. keeps every triangle (under the 5k budget: no simplification), the owner's UVs and colour map, halved to TEX_PX;
6. writes assets/models/enemies/star_warper.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and size, the triangles after (per part: total, glow, role, the pivot), the
caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).

Run from the repo root:  python scripts/assets/star_warper_prep.py
Needs numpy, Pillow, scipy (mi_prep's imports; xatlas is stubbed when missing: this script never calls it).
"""

import hashlib
import io
import json
import os
import sys
import types

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import xatlas  # noqa: F401  (mi_prep imports it at the top; this script keeps the owner's UVs instead)
except ImportError:
    sys.modules["xatlas"] = types.ModuleType("xatlas")
import frost_spitter_prep as fsp  # noqa: E402  (the colour sampling, the cut caps, the smoothing)

mi_prep = fsp.mi_prep

SRC = "unprocessed_images/models_v0120_b/star_warper.glb"
DST = "assets/models/enemies/star_warper.glb"
ID = "star_warper"
HEIGHT_M = 1.15
TEX_PX = 1024
## A loose piece under this many triangles is a star shard.
SHARD_TRIS = 60

# Places in raw units, the game frame (+X front, +Z the Warper's right, the tail's low point on y = 0, centred on x/z).
## The neck (above it the head); each arm (on the right, mirrored for the left): shoulder, elbow, wrist, the outer claw's
## tip, the inner claw's tip.
NECK = (0.03, 0.6, 0.0)
ARM = ((0.02, 0.565, 0.085), (0.005, 0.495, 0.2), (0.04, 0.425, 0.335), (0.07, 0.28, 0.45))
CLAW_LOW = (0.07, 0.24, 0.3)
ARM_REACH = 0.06
## Off the middle by ARM_Z, under the neck, near its bone line (or past 0.2: the claws), it is an arm.
ARM_Z = 0.1
## The tail: under TAIL_Y (within TAIL_Z of the middle), cut at its joints [name, height, pivot].
TAIL_Y = 0.3
TAIL_Z = 0.17
TAIL = (("tail_a", 0.3, (0.0, 0.3, 0.0)), ("tail_b", 0.2, (-0.085, 0.2, 0.03)), ("tail_c", 0.11, (-0.145, 0.11, 0.07)))
## The visor's gem: within VISOR_R of VISOR_C, bright.
VISOR_C = (0.17, 0.715, 0.0)
VISOR_R = 0.045


def lum_of(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def role_texels(rgb):
    """The violet plates: saturated, blue over red, not dark."""
    return (fsp.sat_of(rgb) >= 0.42) & (rgb[..., 2] >= rgb[..., 0]) & (rgb.max(-1) >= 0.25)


def visor_texels(rgb):
    """The gem's bright violet."""
    return (lum_of(rgb) >= 0.36) & (fsp.sat_of(rgb) >= 0.3) & (rgb[..., 2] >= 0.7)


def poly_dist(p, pts):
    return np.min([fsp.seg_dist(p, pts[k], pts[k + 1]) for k in range(len(pts) - 1)], axis=0)


def loose_pieces(pinv, J):
    """Each triangle's piece (by shared welded positions) and the pieces' sizes."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components

    T = pinv[J]
    r = np.concatenate([T[:, 0], T[:, 1], T[:, 2]])
    c = np.concatenate([T[:, 1], T[:, 2], T[:, 0]])
    n = int(pinv.max()) + 1
    _, lab = connected_components(coo_matrix((np.ones(len(r)), (r, c)), shape=(n, n)), directed=False)
    tl = lab[T[:, 0]]
    return tl, np.bincount(tl)


def parts_of(c, tcol, nb, tl, sizes):
    """Per triangle centre: its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["torso"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"torso": np.array([0.0, TAIL_Y, 0.0])}
    head_mid = np.array([NECK[0], 0.78, NECK[2]])
    small = [p for p in np.unique(tl) if sizes[p] < SHARD_TRIS]
    small.sort(key=lambda p: np.arctan2(c[tl == p, 2].mean(), c[tl == p, 1].mean() - head_mid[1]))
    taken = np.zeros(n, bool)
    for k, p in enumerate(small):
        m = tl == p
        lab[m] = "shard_%d" % k
        piv["shard_%d" % k] = head_mid
        taken |= m
    head = (y > NECK[1]) & ~taken
    lab[head] = "head"
    piv["head"] = np.asarray(NECK)
    taken |= head
    for side, name in ((-1.0, "l"), (1.0, "r")):
        pts = [np.array([p[0], p[1], p[2] * side]) for p in ARM]
        low = np.array([CLAW_LOW[0], CLAW_LOW[1], CLAW_LOW[2] * side])
        d_u = fsp.seg_dist(c, pts[0], pts[1])
        d_l = np.minimum(poly_dist(c, pts[1:]), fsp.seg_dist(c, pts[2], low))
        arm = (z * side > ARM_Z) & ((np.minimum(d_u, d_l) < ARM_REACH) | (z * side > 0.2)) & ~taken
        lab[arm & (d_u <= d_l)] = "arm_%s_u" % name
        lab[arm & (d_u > d_l)] = "arm_%s_l" % name
        piv["arm_%s_u" % name] = pts[0]
        piv["arm_%s_l" % name] = pts[1]
        taken |= arm
    for k, (name, top, pivot) in enumerate(TAIL):
        below = TAIL[k + 1][1] if k + 1 < len(TAIL) else -1.0
        m = (y < top) & (y >= below) & (np.abs(z) < TAIL_Z) & ~taken
        lab[m] = name
        piv[name] = np.asarray(pivot)
    free = ~taken
    band = lambda y0: (np.abs(y - y0) < 0.03) & free  # noqa: E731
    lab = fsp.smooth(lab, nb, band(TAIL[0][1]), "torso", "tail_a")
    lab = fsp.smooth(lab, nb, band(TAIL[1][1]), "tail_a", "tail_b")
    lab = fsp.smooth(lab, nb, band(TAIL[2][1]), "tail_b", "tail_c")
    return lab, piv


def main():
    fsp.SRC = SRC
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = fsp.load()
    s = HEIGHT_M / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = fsp.tri_colour(colour, UVw, J)
    tl, sizes = loose_pieces(pinv, J)
    part, pivots = parts_of(cen, tcol, fsp.neighbours(pinv[J]), tl, sizes)
    glow = np.zeros(len(J), int)
    near_visor = np.linalg.norm(cen - np.asarray(VISOR_C), axis=1) < VISOR_R
    glow[(part == "head") & near_visor & visor_texels(tcol)] = 2
    glow[np.char.startswith(part.astype(str), "shard")] = 2
    W = Wr * s
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = fsp.cut_caps(per_part, pinv, W, set(), set())
    lum = lum_of(tcol)
    body_m = part == "torso"
    dark_uv = UVw[J[body_m][np.argmin(np.where(lum[body_m] > 0.03, lum[body_m], 9.0))]].mean(0)
    nodes, report, cap_report = [], {}, {}
    at = 0
    for pn in order:
        T = per_part[pn]
        cn = cn_all[at : at + len(T)]
        at += len(T)
        K = glow[part == pn].copy()
        rest = K != 2
        K[rest] = role_texels(fsp.tri_colour(colour, UVw, T[rest])).astype(int)
        pivot = pivots[pn] * s
        prims = []
        for k in (0, 1, 2):
            sel = np.where(K == k)[0]
            pos_l, nrm_l, uv_l = [], [], []
            if len(sel):
                Ts = T[sel]
                pos_l.append(W[Ts].reshape(-1, 3) - pivot)
                nrm_l.append(cn[sel].reshape(-1, 3))
                uv_l.append(UVw[Ts].reshape(-1, 2))
            for surf, tris in caps.get(pn, []):
                if surf != k:
                    continue
                fn = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
                fn = fn / np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
                pos_l.append(tris.reshape(-1, 3) - pivot)
                nrm_l.append(np.repeat(fn, 3, axis=0))
                uv_l.append(np.tile(dark_uv, (len(tris) * 3, 1)))
                cap_report[pn] = cap_report.get(pn, 0) + len(tris)
            if not pos_l:
                continue
            pos = np.concatenate(pos_l)
            prims.append((k, pos, np.concatenate(nrm_l), np.concatenate(uv_l), np.arange(len(pos)).reshape(-1, 3)))
        nodes.append((pn, pivot, prims))
        report[pn] = [len(T), int((K == 2).sum()), int((K == 1).sum()), [round(float(v), 3) for v in pivot]]
    img = colour.copy()
    role_px = role_texels(img)
    lum_px = lum_of(img)
    g = np.clip(lum_px / max(lum_px[role_px].mean(), 1e-3) * 0.82, 0, 1)
    img[role_px] = g[role_px, None]
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, ID, nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    print(json.dumps({
        "id": ID, "raw": SRC, "raw_tris": raw_tris, "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
