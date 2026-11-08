"""v0.11.0 Step O17a: prepares the owner's Scrap Hound (unprocessed_images/models_v0110/scrap_hound.glb) for the game:
assets/models/enemies/scrap_hound.glb, cut into the parts ScrapHoundAvatar animates.

The raw file is a Tripo export: one textured mesh (9,584 triangles, a 2048 px colour map), about one unit long, no rig,
its front already on +X (the snout and the visor), Y up, standing mid-stride (the far hind leg ahead of the near one).
The raw file stays untouched. This script, reusing mi_prep's reader, simplifier (Godot's on Windows: GODOT=<godot>),
normals and glb writer (through mi2_prep, which imports it):
1. puts it in the game's frame (centred on x/z, its feet on y = 0) and scales it evenly to HEIGHT_M (the request row:
   about 0.7 m at the shoulder; 1.1 m long);
2. cuts it into the parts that move (PARTS): the chest and the hips (`body_f`, `body_r`: the spine bends between
   them), the head, the tail, and each leg's upper and lower half (`leg_fr_u`, `leg_fr_l`, ... : f/h front/hind, r/l
   the hound's right (+Z) / left side). A leg's triangles are the ones near its bone line (CHAINS, fitted to the raw
   mesh 2026-11-08), split at the knee / elbow; every part node's origin is its pivot (the hip, the knee, the neck,
   the spine joint, the tail's root);
3. sorts each triangle into a surface by the colour map under it: `glow` (the gem visor: pure red, nothing else on the
   head front is), `role` (the red-orange shell plates: their texels turned greyscale in the map so the game tints
   them in the kind's role colour, as mi_prep's enemies) and `base` (the charcoal frame, the grey limbs, the bone
   claws);
4. simplifies each part (and in it the visor apart) to its share of BUDGET_TRIS with Godot's simplifier, borders
   locked. Unlike mi_prep it keeps the owner's own UV layout (the mesh is welded by position and UV, so the seams are
   locked borders and every kept vertex keeps its UV) and the owner's colour map, halved to TEX_PX: no new atlas, so
   xatlas isn't needed (it has no Windows wheel for this Python);
5. writes assets/models/enemies/scrap_hound.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and file size, the triangles after (per part, with the visor's share and
the pivot), the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).

Run from the repo root:  GODOT=<godot executable> python -I scripts/assets/o17_prep_scrap_hound.py
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
import mi2_prep  # noqa: E402  (its mi_prep: the reader, simplifier, normals and glb writer)

mi_prep = mi2_prep.mi_prep

SRC = "unprocessed_images/models_v0110/scrap_hound.glb"
DST = "assets/models/enemies/scrap_hound.glb"
HEIGHT_M = 0.70
BUDGET_TRIS = 6000
TEX_PX = 1024

## The bone lines (raw model units: the raw file is already centred with its feet on y = 0) of each leg, hip or
## shoulder first, then the knee / elbow, then down to the toe; and the reach (raw units) round each segment that is
## still that leg. The upper half is the first segment's.
CHAINS = {
    "fr": [(0.20, 0.36, 0.105), (0.228, 0.18, 0.135), (0.355, 0.07, 0.155), (0.46, 0.012, 0.165)],
    "fl": [(0.22, 0.36, -0.105), (0.258, 0.19, -0.145), (0.375, 0.075, -0.157), (0.48, 0.012, -0.16)],
    "hr": [(-0.09, 0.42, 0.105), (-0.02, 0.275, 0.13), (-0.205, 0.235, 0.138), (-0.255, 0.065, 0.175),
           (-0.17, 0.012, 0.19)],
    "hl": [(-0.07, 0.42, -0.105), (-0.01, 0.285, -0.14), (-0.16, 0.167, -0.152), (-0.125, 0.055, -0.182),
           (-0.045, 0.012, -0.186)],
}
REACH = {"fr": (0.07, 0.055, 0.075), "fl": (0.07, 0.055, 0.075), "hr": (0.075, 0.055, 0.05, 0.075),
         "hl": (0.075, 0.055, 0.05, 0.075)}
## Above this (raw y) a triangle is the body's flank, not a leg's (front, hind); and nearer the middle than LEG_Z.
LEG_TOP = {"f": 0.33, "h": 0.38}
LEG_Z = 0.065
## The spine joint (raw x, y) the chest and the hips meet at; the neck (the head is what lies ahead of NECK_X); the
## tail's root (the tail is what lies behind TAIL_X above TAIL_Y). The spine and the neck turn about points up at the
## shell's line, so the plates on top barely part as they bend (the belly and the chin, seen less, take the gap).
SPINE = (0.03, 0.52)
NECK_X = 0.31
NECK = (0.29, 0.46)
## Over the neck the shell's plates stay on the chest (above HEAD_SHELL[0] and behind HEAD_SHELL[1], raw y and x): the
## head turns under them, so no gap opens on top.
HEAD_SHELL = (0.45, 0.38)
TAIL_X = -0.30
TAIL_Y = 0.38
TAIL = (-0.29, 0.455)
## The visor's texels: bright pure red (the plates are red-orange: their green is a third of their red or more), only
## on the head's front (raw x past VISOR_X).
VISOR_X = 0.40
## The plates' saturation floor (the shell's are over 0.43; the bone claws' about 0.31).
ROLE_SAT = 0.45


def glow_texels(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r >= 0.3) & (g <= 0.2 * r) & (b <= 0.2 * r)


def role_texels(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return (sat >= ROLE_SAT) & ~glow_texels(rgb)


def sample(colour, uv):
    h, w = colour.shape[:2]
    x = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
    y = np.clip((uv[:, 1] * h).astype(int), 0, h - 1)
    return colour[y, x]


def tri_colour(colour, UVw, T):
    """The colour under each triangle: the mean of its centre's and its corners' pulled a third of the way in."""
    c = UVw[T].mean(1)
    acc = sample(colour, c)
    for k in range(3):
        acc = acc + sample(colour, UVw[T[:, k]] * (2.0 / 3.0) + c / 3.0)
    return acc / 4.0


def seg_dist(p, a, b):
    a, b = np.asarray(a), np.asarray(b)
    d = b - a
    t = np.clip(((p - a) @ d) / (d @ d), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * d), axis=1)


def parts_of(c):
    """Per triangle centre (raw units): its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["body_r"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab[x > SPINE[0]] = "body_f"
    piv = {"body_f": (SPINE[0], SPINE[1], 0.0), "body_r": (SPINE[0], SPINE[1], 0.0)}
    taken = np.zeros(n, bool)
    head_zone = (x > VISOR_X - 0.02) & (y > 0.15)
    for leg, chain in CHAINS.items():
        segs = len(chain) - 1
        d = np.stack([seg_dist(c, chain[k], chain[k + 1]) for k in range(segs)], 1)
        near = np.argmin(d, 1)
        within = d[np.arange(n), near] < np.asarray(REACH[leg])[near]
        side = z > 0 if leg[1] == "r" else z < 0
        low = (y < LEG_TOP[leg[0]]) & (np.abs(z) > LEG_Z)
        low |= y < 0.2  # under the belly every triangle near the line is the leg's
        m = within & side & low & ~taken & ~head_zone
        lab[m & (near == 0)] = "leg_%s_u" % leg
        lab[m & (near > 0)] = "leg_%s_l" % leg
        piv["leg_%s_u" % leg] = chain[0]
        piv["leg_%s_l" % leg] = chain[1]
        taken |= m
    # What is left low (a heel, a claw past the reach) goes to the nearest leg on its side.
    left = ~taken & ~head_zone & (y < 0.2)
    if left.any():
        best = np.full(n, np.inf)
        for leg, chain in CHAINS.items():
            segs = len(chain) - 1
            d = np.stack([seg_dist(c, chain[k], chain[k + 1]) for k in range(segs)], 1)
            near = np.argmin(d, 1)
            dn = d[np.arange(n), near]
            m = left & (dn < best)
            lab[m & (near == 0)] = "leg_%s_u" % leg
            lab[m & (near > 0)] = "leg_%s_l" % leg
            best = np.where(m, dn, best)
        taken |= left
    head = (x > NECK_X) & ((y < HEAD_SHELL[0]) | (x > HEAD_SHELL[1])) & ~taken
    lab[head] = "head"
    piv["head"] = (NECK[0], NECK[1], 0.0)
    tail = (x < TAIL_X) & (y > TAIL_Y) & ~taken
    lab[tail] = "tail"
    piv["tail"] = (TAIL[0], TAIL[1], 0.0)
    return lab, {k: np.asarray(v, float) for k, v in piv.items()}


def main():
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    lo, hi = P0.min(0), P0.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    s = HEIGHT_M / (hi[1] - lo[1])
    raw = P0 - centre
    # Welded by position and UV: the seams stay apart (locked borders), every vertex keeps its UV.
    eps = (hi - lo).max() * 2e-5
    key = np.concatenate([np.round(raw / eps), np.round(UV * 1e6)], 1).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    Wr = raw[first]
    UVw = UV[first]
    J = inv[I0]
    J = J[(J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])]
    # The same vertices welded by position alone (the normals smooth across the seams).
    pkey = np.round(Wr / eps).astype(np.int64)
    _, pinv = np.unique(pkey, axis=0, return_inverse=True)
    pinv = pinv.ravel()
    cen = Wr[J].mean(1)
    part, pivots = parts_of(cen)
    tcol = tri_colour(colour, UVw, J)
    glow = (glow_texels(tcol) & (cen[:, 0] > VISOR_X)).astype(int) * 2
    W = Wr * s  # metres
    groups = sorted({(p, k) for p, k in zip(part, glow)})
    total = len(J)
    scale = 1.0
    for _attempt in range(6):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (glow == g[1])
            share = max(int(round(BUDGET_TRIS * scale * m.sum() / total)), 24 if g[1] == 2 else 12)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=True)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= BUDGET_TRIS * 1.02:
            break
        scale *= BUDGET_TRIS / tris_after * 0.97
    # Normals over the whole position-welded mesh, every part at once (no crease where two parts meet, nor at the
    # UV seams); corners flat per face after.
    order = [pn for pn in sorted(pivots) if any(g[0] == pn and len(simplified[g]) for g in groups)]
    per_part = {pn: np.concatenate([simplified[g] for g in groups if g[0] == pn]) for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    nodes = []
    report = {}
    at = 0
    for pn in order:
        T = per_part[pn]
        cn = cn_all[at : at + len(T)]
        at += len(T)
        K = np.concatenate([np.full(len(simplified[g]), g[1]) for g in groups if g[0] == pn])
        rest = K != 2
        K[rest] = role_texels(tri_colour(colour, UVw, T[rest])).astype(int)
        pivot = pivots[pn] * s
        prims = []
        for k in (0, 1, 2):
            sel = np.where(K == k)[0]
            if len(sel) == 0:
                continue
            Ts = T[sel]
            pos = W[Ts].reshape(-1, 3) - pivot
            nrm = cn[sel].reshape(-1, 3)
            uv = UVw[Ts].reshape(-1, 2)
            prims.append((k, pos, nrm, uv, np.arange(len(pos)).reshape(-1, 3)))
        nodes.append((pn, pivot, prims))
        report[pn] = [len(T), int((K == 2).sum()), int((K == 1).sum()), [round(float(v), 3) for v in pivot]]
    # The colour map: the role plates' texels greyscale (the game multiplies them by the role colour), halved.
    img = colour.copy()
    role_px = role_texels(img)
    lum = img @ np.array([0.299, 0.587, 0.114])
    if role_px.any():
        g = np.clip(lum / max(lum[role_px].mean(), 1e-3) * 0.82, 0, 1)
        img[role_px] = g[role_px, None]
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, "scrap_hound", nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    print(json.dumps({
        "id": "scrap_hound", "raw": SRC, "raw_tris": len(I0), "raw_bytes": os.path.getsize(SRC), "tris": tris_after,
        "budget": BUDGET_TRIS, "tex": TEX_PX, "backend": mi_prep.BACKEND,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
