"""Prepares the owner's Glacier Turtle (unprocessed_images/models_v0120/glacier_turtle.glb) for the game:
assets/models/enemies/glacier_turtle.glb, cut into the parts GlacierTurtleAvatar animates.

The raw file is a Tripo export: one textured mesh (4,734 triangles, a 2048 px colour map), one unit long, no rig, Y up,
already facing +X (the game's front): a squat charcoal body under a domed carapace of pale ice slabs with icicles and
spikes, a short neck and a dark face block with a cyan gem visor, four thick segmented legs with bone toes, and in front
of it, standing on the ground apart from the body (its own connected piece), the curved wall of faceted ice slabs it
holds as a shield. The owner's model carries no bronze: every colour is kept as delivered (no texel is turned
greyscale for a role tint, so the ice stays ice). The raw file stays untouched. This script, reusing mi_prep's reader,
normals and glb writer and frost_spitter_prep's cutting helpers:
1. centres it on x/z with its feet on y = 0 and scales it evenly to HEIGHT_M (it is then 1.33 m long, the shield's
   face about at the sim's 0.6 m radius);
2. cuts it into the parts that move: the shield (the separate piece), each leg's upper half (from under the carapace
   to the knee) and lower half (the foot and its bone toes: a leg's triangles are the ones within LEG_R of its upright
   axis, LEGS fitted to the raw mesh), the head (the face block and the neck: it turns at the neck's root), the
   carapace (the pale ice above the body) and the body (the charcoal belly and flanks: the rig's root); every part
   node's origin is its pivot (the hip, the knee, the neck, the carapace's centre, the shield's front foot);
3. caps the cuts (the hull is hollow: a part turning or lifting would show through it): a fan over each part's cut
   edges facing the part across the cut, charcoal (none on the carapace: its underside is never seen; the shield has
   no cut);
4. sorts each triangle into a surface by the colour map under it: `glow` (the head's cyan gem visor) and `base`
   (everything else; no `role` surface: see above);
5. keeps every triangle (the raw mesh is under the 5k budget: no simplification) and the owner's own UV layout and
   colour map, halved to TEX_PX;
6. writes assets/models/enemies/glacier_turtle.glb (one node per part, the three materials base / role / glow).
It prints one JSON line: the raw triangles and file size, the triangles after (per part: total, glow, role, the
pivot), the caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json
by hand).

Run from the repo root:  python scripts/assets/glacier_turtle_prep.py
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
import frost_spitter_prep as fsp  # noqa: E402  (the colour sampling, the smoothing and the caps)

mi_prep = fsp.mi_prep

SRC = "unprocessed_images/models_v0120/glacier_turtle.glb"
DST = "assets/models/enemies/glacier_turtle.glb"
HEIGHT_M = 0.9
TEX_PX = 1024

## Each leg (raw units, +X front, +Z the turtle's right): its hip (under the carapace), its knee (above the foot) and
## its foot's tip (the toes' front: the hind feet's turn back). fr / fl: the front pair, br / bl: the hind pair. A
## leg's triangles are those within LEG_R of its upright axis (the knee's x, z) under LEG_TOP; the foot is the part
## under KNEE_Y.
LEGS = {
    "fr": ((0.14, 0.28, 0.21), (0.15, 0.12, 0.26), (0.21, 0.01, 0.29)),
    "fl": ((0.14, 0.28, -0.21), (0.15, 0.12, -0.26), (0.21, 0.01, -0.29)),
    "br": ((-0.31, 0.28, 0.21), (-0.32, 0.12, 0.26), (-0.38, 0.01, 0.3)),
    "bl": ((-0.31, 0.28, -0.21), (-0.32, 0.12, -0.26), (-0.38, 0.01, -0.3)),
}
LEG_R = 0.135
LEG_TOP = 0.3
KNEE_Y = 0.12
## Above ICE_Y a leg's ice triangle is the carapace's (an icicle hanging over it) when it joins the carapace's dome
## (over BACK_SEED) through ice.
ICE_Y = 0.2
BACK_SEED = 0.4
## Under FOOT_Y nothing is the body: a toe splayed past the reach goes to the nearest foot.
FOOT_Y = 0.07
## The head: ahead of HEAD_X, within HEAD_Z of the middle, above HEAD_Y, not the ice (but its brow); its pivot (the
## neck's root).
HEAD_X = 0.13
HEAD_Z = 0.15
HEAD_Y = 0.22
NECK = (0.1, 0.36, 0.0)
## The head's ice brow: ice ahead of BROW_X (past the carapace's front rim) and under BROW_TOP is the head's.
BROW_X = 0.19
BROW_TOP = 0.53
## The visor: head triangles ahead of VISOR_X whose blue is over their red by VISOR_BLUE.
VISOR_X = 0.25
VISOR_BLUE = 0.22
## The carapace: ice texels above BACK_Y; its pivot (its centre over the body, where it lifts and tips from).
BACK_Y = 0.15
BACK_PIVOT = (-0.14, 0.32, 0.0)
## The shield's pivot (its front foot on the ground: a hit tips its top back, a fall lays it on its face).
SHIELD_PIVOT = (0.47, 0.0, 0.0)
## A texel is ice (the carapace's slabs, frost and icicles) over this luminance, or blue enough.
ICE_LUM = 0.42


def ice_texels(rgb):
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    blue = (rgb[..., 2] - rgb[..., 0]) >= 0.22
    return (lum >= ICE_LUM) | (blue & (lum >= 0.3))


def visor_tris(rgb, c):
    """The cyan gem visor on the face block's front (the triangles' mean colour: the gem's cyan dimmed by its ring;
    the ice brow over it is paler: more red)."""
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    return (b - r >= VISOR_BLUE) & (g >= 0.24) & (r <= 0.16) & (c[:, 0] > VISOR_X)


def parts_of(c, tcol, nb, shield):
    """Per triangle centre (raw units): its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    lab[shield] = "shield"
    piv["shield"] = np.asarray(SHIELD_PIVOT)
    taken = shield.copy()
    ice = ice_texels(tcol)
    for leg, (hip, knee, _tip) in LEGS.items():
        hip, knee = np.asarray(hip), np.asarray(knee)
        r = np.hypot(x - knee[0], z - knee[2])
        m = (r < LEG_R) & (y < LEG_TOP) & ~taken
        lab[m & (y >= KNEE_Y)] = "leg_%s_u" % leg
        lab[m & (y < KNEE_Y)] = "leg_%s_l" % leg
        taken |= m
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    stray = np.where((y < FOOT_Y) & ~taken)[0]
    if len(stray):
        feet = list(LEGS)
        d = np.stack([fsp.seg_dist(c[stray], LEGS[f][1], LEGS[f][2]) for f in feet], 1)
        for t, k in zip(stray, d.argmin(1)):
            lab[t] = "leg_%s_l" % feet[k]
        taken[stray] = True
    brow = (x > BROW_X) & (y < BROW_TOP)
    head = (x > HEAD_X) & (np.abs(z) < HEAD_Z) & (y > HEAD_Y) & ~taken & (~ice | brow)
    lab[head] = "head"
    piv["head"] = np.asarray(NECK)
    # The carapace: the ice reached from its dome (over BACK_SEED) through ice triangles, the icicles over a leg's top
    # among them; a leg's own frost (not reached) stays the leg's, the body's the body's.
    legs = np.array([str(v).startswith("leg_") for v in lab])
    can = ice & ~head & ~shield & (y > BACK_Y) & (~legs | (y > ICE_Y))
    back = np.zeros(n, bool)
    todo = list(np.where(can & (y > BACK_SEED))[0])
    back[todo] = True
    while todo:
        t = todo.pop()
        for k in nb[t]:
            if can[k] and not back[k]:
                back[k] = True
                todo.append(k)
    lab[back] = "carapace"
    taken |= back & legs
    piv["carapace"] = np.asarray(BACK_PIVOT)
    # Smooth the cuts: the carapace's rim on the body, the face block's edge.
    free = ~taken
    lab = fsp.smooth(lab, nb, free & (y > BACK_Y - 0.03), "carapace", "body")
    lab = fsp.smooth(lab, nb, free & (x > HEAD_X - 0.03) & (y > HEAD_Y - 0.03), "head", "carapace", 2)
    lab = fsp.smooth(lab, nb, free & (x > HEAD_X - 0.03) & (y > HEAD_Y - 0.03), "head", "body", 2)
    return lab, piv


def load():
    """The raw mesh (raw units, centred, feet on y = 0), welded: (welded positions, their UVs, triangles, the
    position-weld index, the colour map, the bounds, the raw triangle count, the shield's triangles: a mask)."""
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    lo, hi = P0.min(0), P0.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    raw = P0 - centre
    eps = (hi - lo).max() * 2e-5
    key = np.concatenate([np.round(raw / eps), np.round(UV * 1e6)], 1).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    Wr = raw[first]
    UVw = UV[first]
    J = inv[I0]
    J = J[(J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])]
    pkey = np.round(Wr / eps).astype(np.int64)
    _, pinv = np.unique(pkey, axis=0, return_inverse=True)
    pinv = pinv.ravel()
    # The shield: the connected piece (by position) ahead of the body.
    comp = mi_prep.components(int(pinv.max()) + 1, pinv[J])
    tc = comp[pinv[J[:, 0]]]
    front = max(np.unique(tc), key=lambda k: Wr[J[tc == k]].reshape(-1, 3)[:, 0].min())
    return Wr, UVw, J, pinv, colour, (lo, hi), len(I0), tc == front


def main():
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris, shield = load()
    s = HEIGHT_M / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = fsp.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, fsp.neighbours(pinv[J]), shield)
    glow = np.zeros(len(J), int)
    glow[(part == "head") & visor_tris(tcol, cen)] = 2
    W = Wr * s  # metres
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = fsp.cut_caps(per_part, pinv, W, set(), {"carapace"})
    body_m = part == "body"
    lum = tcol @ np.array([0.299, 0.587, 0.114])
    dark_uv = UVw[J[body_m][np.argmin(np.where(lum[body_m] > 0.03, lum[body_m], 9.0))]].mean(0)
    nodes = []
    report = {}
    cap_report = {}
    at = 0
    for pn in order:
        T = per_part[pn]
        cn = cn_all[at : at + len(T)]
        at += len(T)
        K = glow[part == pn].copy()
        pivot = pivots[pn] * s
        prims = []
        for k in (0, 2):
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
        report[pn] = [len(T), int((K == 2).sum()), 0, [round(float(v), 3) for v in pivot]]
    pil = Image.fromarray(np.clip(colour * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, "glacier_turtle", nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    feet = {leg: [round(float(v) * s, 3) for v in tip] for leg, (_h, _k, tip) in LEGS.items()}
    print(json.dumps({
        "id": "glacier_turtle", "raw": SRC, "raw_tris": raw_tris, "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in ext], "scale": round(float(s), 4), "feet": feet, "path": DST,
        "bytes": os.path.getsize(DST), "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
