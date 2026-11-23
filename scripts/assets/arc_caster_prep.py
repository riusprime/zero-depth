"""Prepares the owner's Arc Caster (unprocessed_images/models_v0120_b/arc_caster.glb) for the game:
assets/models/enemies/arc_caster.glb, cut into the parts ArcCasterAvatar animates.

The raw file is a Tripo export: one textured mesh (4,916 triangles, a 2048 px colour map; the hull and three small
loose rune shards round the hood), one unit tall, no rig, Y up, its front (the charcoal face plate with its violet gem
visor under the tall pointed hood) on +Z: a robe of overlapping violet plates down to a hem of grey spikes with bone
tips, the right hand gripping a tall grey staff whose forked cradle holds a pale violet crystal, the free left arm hanging
with its claws open. The raw file stays untouched. This script, reusing mi_prep's reader, normals and glb writer and the
Frost Spitter prep's colour sampling, cut caps and smoothing:
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres the robe's middle on x/z (the staff
   stands off to its right) with the hem on y = 0 and scales it evenly to HEIGHT_M (the Cinder Priest model it wore until now: 1.75 m with the staff);
2. cuts it into the parts that move, by place and colour (the hull is one piece): the staff (with the hand on it and
   the crystal), the staff arm (shoulder to the hand), the free arm's upper half and forearm (with its claws), the three
   shards (the loose pieces), the hood (above the shoulders, with the face plate and the visor), the torso (the chest
   plates from the waist up: the rig's root), and the robe in two tiers (waist to knee, knee to the hem's spikes) so
   the hem lags and sways behind the robe. Every part node's origin is its pivot (the shoulder, the elbow, the grip,
   the neck, the waist, the knee, the hood's middle for the shards);
3. caps the cuts (a fan over each part's cut edges facing the part across the cut), in the charcoal of the body;
4. sorts each triangle into a surface by the colour map under it: `glow` (the crystal's pale violet on the staff, the
   visor's gem on the hood), `role` (the saturated violet plates: their texels greyscale in the map so the game tints
   them in the kind's role colour) and `base` (the charcoal, the greys, the bone tips);
5. keeps every triangle (under the 5k budget: no simplification), the owner's UVs and colour map, halved to TEX_PX;
6. writes assets/models/enemies/arc_caster.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and size, the triangles after (per part: total, glow, role, the pivot), the
caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).

Run from the repo root:  python scripts/assets/arc_caster_prep.py
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

SRC = "unprocessed_images/models_v0120_b/arc_caster.glb"
DST = "assets/models/enemies/arc_caster.glb"
ID = "arc_caster"
HEIGHT_M = 1.75
TEX_PX = 1024
## A loose piece under this many triangles is a rune shard.
SHARD_TRIS = 60

# Places in raw units, the game frame (+X front, +Z the caster's right, the hem on y = 0, centred on x/z).
## The staff: its line (x, z) up its whole height, its reach round the line, the cradle's height and reach, the grip.
STAFF_XZ = (0.134, 0.186)
STAFF_REACH = 0.03
CRADLE_Y = 0.835
CRADLE_REACH = 0.08
GRIP = (0.134, 0.605, 0.186)
GRIP_REACH = 0.045
## The staff arm: shoulder, elbow (the hand is at GRIP); the free arm: shoulder, elbow, wrist, claw tips.
ARM_R = ((0.03, 0.585, 0.05), (0.06, 0.535, 0.11), GRIP)
ARM_L = ((0.025, 0.59, -0.135), (0.05, 0.49, -0.2), (0.085, 0.37, -0.245), (0.08, 0.31, -0.24))
ARM_REACH = 0.045
## The cuts across the robe: the neck (above it the hood), the waist (above it the torso), the knee (above it the
## upper tier of the robe, under it the hem).
NECK_Y = 0.645
WAIST_Y = 0.42
KNEE_Y = 0.22
## The visor's gem: within VISOR_R of VISOR_C, bright.
VISOR_C = (0.11, 0.715, -0.015)
VISOR_R = 0.06


def lum_of(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def role_texels(rgb):
    """The violet plates: saturated, blue over red, not dark."""
    return (fsp.sat_of(rgb) >= 0.42) & (rgb[..., 2] >= rgb[..., 0]) & (rgb.max(-1) >= 0.25)


def crystal_texels(rgb):
    """The crystal's pale violet: bright, red and blue both high."""
    return (lum_of(rgb) >= 0.45) & (rgb[..., 0] >= 0.55) & (rgb[..., 2] >= 0.6)


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


def parts_of(c, tcol, nb, tl, sizes, mid):
    """Per triangle centre: its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["torso"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    grey = fsp.sat_of(tcol) < 0.3
    piv = {}
    # The shards: the loose pieces, ordered round the hood.
    small = [p for p in np.unique(tl) if sizes[p] < SHARD_TRIS]
    small.sort(key=lambda p: np.arctan2(c[tl == p, 2].mean() - mid[1], c[tl == p, 0].mean() - mid[0]))
    taken = np.zeros(n, bool)
    for k, p in enumerate(small):
        m = tl == p
        lab[m] = "shard_%d" % k
        piv["shard_%d" % k] = np.array([mid[0], c[m, 1].mean(), mid[1]])
        taken |= m
    # The staff with its cradle and crystal, and the hand round it.
    d_staff = np.hypot(x - STAFF_XZ[0], z - STAFF_XZ[1])
    staff = (d_staff < np.where(y > CRADLE_Y, CRADLE_REACH, STAFF_REACH)) & ~taken
    # Over the shoulders, what is nearer the staff's line than the hood's middle is the cradle's prongs.
    staff |= (y > NECK_Y + 0.1) & (d_staff < np.hypot(x - mid[0], z - mid[1])) & ~taken
    staff |= (np.linalg.norm(c - np.asarray(GRIP), axis=1) < GRIP_REACH) & grey & ~taken
    lab[staff] = "staff"
    piv["staff"] = np.asarray(GRIP)
    taken |= staff
    # The arms (grey, near their bone lines).
    arm_r = (poly_dist(c, ARM_R) < ARM_REACH) & grey & ~taken & (y > WAIST_Y)
    lab[arm_r] = "arm_r"
    piv["arm_r"] = np.asarray(ARM_R[0])
    taken |= arm_r
    d_u = fsp.seg_dist(c, ARM_L[0], ARM_L[1])
    d_l = poly_dist(c, ARM_L[1:])
    arm = (np.minimum(d_u, d_l) < ARM_REACH) & grey & ~taken & (z < -0.1)
    lab[arm & (d_u <= d_l)] = "arm_l_u"
    lab[arm & (d_u > d_l)] = "arm_l_l"
    piv["arm_l_u"] = np.asarray(ARM_L[0])
    piv["arm_l_l"] = np.asarray(ARM_L[1])
    taken |= arm
    free = ~taken
    lab[free & (y > NECK_Y)] = "hood"
    lab[free & (y <= WAIST_Y) & (y > KNEE_Y)] = "hem_u"
    lab[free & (y <= KNEE_Y)] = "hem_l"
    piv["hood"] = np.array([mid[0], NECK_Y, mid[1]])
    piv["torso"] = np.array([mid[0], WAIST_Y, mid[1]])
    piv["hem_u"] = np.array([mid[0], WAIST_Y, mid[1]])
    piv["hem_l"] = np.array([mid[0], KNEE_Y, mid[1]])
    band = lambda y0: (np.abs(y - y0) < 0.04) & free  # noqa: E731
    lab = fsp.smooth(lab, nb, band(NECK_Y), "hood", "torso")
    lab = fsp.smooth(lab, nb, band(WAIST_Y), "torso", "hem_u")
    lab = fsp.smooth(lab, nb, band(KNEE_Y), "hem_u", "hem_l")
    return lab, piv


def main():
    fsp.SRC = SRC
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = fsp.load()
    s = HEIGHT_M / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = fsp.tri_colour(colour, UVw, J)
    tl, sizes = loose_pieces(pinv, J)
    # The robe's middle (x, z): the hull's triangles between the knee and the neck, off the staff.
    robe = (cen[:, 1] > KNEE_Y) & (cen[:, 1] < NECK_Y) & (np.hypot(cen[:, 0] - STAFF_XZ[0], cen[:, 2] - STAFF_XZ[1]) > 0.1)
    mid = (round(float(np.median(cen[robe, 0])), 3), round(float(np.median(cen[robe, 2])), 3))
    part, pivots = parts_of(cen, tcol, fsp.neighbours(pinv[J]), tl, sizes, mid)
    glow = np.zeros(len(J), int)
    glow[(part == "staff") & (cen[:, 1] > CRADLE_Y) & crystal_texels(tcol)] = 2
    near_visor = np.linalg.norm(cen - np.asarray(VISOR_C), axis=1) < VISOR_R
    glow[(part == "hood") & near_visor & visor_texels(tcol)] = 2
    # The robe's middle on x = z = 0 (the turn's axis: the staff stands off to the side).
    off = np.array([mid[0], 0.0, mid[1]])
    W = (Wr - off) * s
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
        pivot = (pivots[pn] - off) * s
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
    role_px = role_texels(img) & ~crystal_texels(img)
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
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "tex": TEX_PX, "mid": mid,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
