"""Prepares the owner's Mine Layer (unprocessed_images/models_v0120_b/mine_layer.glb) for the game:
assets/models/enemies/mine_layer.glb, cut into the parts MineLayerModel animates on HordeAvatar's batched path.

The raw file is a Tripo export: one closed textured mesh (4,662 triangles, a 2048 px colour map), one unit long, no
rig, Y up, its front (the grey visor over the glowing eye) on +Z: a low segmented crawler under dark-yellow plates on
six short two-part legs, an open hopper box on its rear holding two spiked mines. The raw file stays untouched. This
script, reusing mi_prep's reader, normals, simplifier and glb writer and the Frost Spitter's and Warden's helpers:
1. turns it to the game's frame (+X the front), centres it with its feet on y = 0 and scales it evenly to LENGTH_M
   long (about the code body's footprint: 0.8 m long, 0.6 m wide, 0.39 m tall);
2. simplifies it to TARGET_TRIS (a horde body: the batched path draws many; the UV seams stay locked);
3. cuts it into the parts that move, by place: the body (the rig's torso), the head (the visor and the eye: it looks
   round at its neck), the hopper (the box with the front mine, tipping back at its front edge), the hatch (the box's
   rear wall, hinged at its foot: it swings open to let a mine out), the mine (the rear one: it rolls to the hatch and
   drops), and each leg's upper and lower half (LEGS: hip, knee, the claw's tip, refined to the mesh's lowest points);
4. caps the cuts, dark;
5. sorts each triangle into a surface by the colour map: `glow` (the yellow face under the visor), `role` (the dark-yellow
   plates: their texels greyscale in the map, tinted in the bomber's role colour) and `base` (the charcoal, the greys,
   the bone claws, the mines);
6. keeps the owner's UVs and colour map (halved to TEX_PX) and writes assets/models/enemies/mine_layer.glb.
It prints one JSON line (raw and kept triangles, parts, caps, size, file, sha256: pasted into the manifest by hand).
With --labels <prefix> it saves each triangle's centre and part for looking at the cut.

Run from the repo root:  python scripts/assets/mine_layer_prep.py   (GODOT=<godot executable> for the simplifier
where the meshoptimizer package is missing)
"""

import hashlib
import io
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import frost_spitter_prep as fsp  # noqa: E402
import warden_prep  # noqa: E402

mi_prep = fsp.mi_prep

SRC = "unprocessed_images/models_v0120_b/mine_layer.glb"
DST = "assets/models/enemies/mine_layer.glb"
NAME = "mine_layer"
LENGTH_M = 0.8
TARGET_TRIS = 3000
TEX_PX = 1024

## Each leg on the right (+Z; the left mirrored, its tip refined on its own): hip (where it leaves the body), knee (the
## arch's top), the claw's tip. f: the front pair (angled forward), m: the middle, b: the back.
LEGS = {
    "f": ((0.3, 0.14, 0.17), (0.35, 0.19, 0.23), (0.39, 0.0, 0.26)),
    "m": ((0.1, 0.16, 0.2), (0.12, 0.2, 0.29), (0.14, 0.0, 0.36)),
    "b": ((-0.17, 0.16, 0.2), (-0.17, 0.2, 0.29), (-0.17, 0.0, 0.37)),
}
REACH = (0.075, 0.075)
LEG_Z = 0.19
## The head: ahead of HEAD_X and under HEAD_TOP (the plates over it stay the body); its pivot (the neck).
HEAD_X = 0.38
HEAD_TOP = 0.27
## The eye: the yellow face under the visor, under EYE_TOP on the head (it glows).
EYE_TOP = 0.24
NECK = (0.36, 0.15, 0.0)
## The hopper: behind HOPPER_X and over HOPPER_Y; its hinge (the box's front foot, where it tips back from). The hatch:
## its rear wall behind HATCH_X; its hinge at its foot. The rear mine: within MINE_R of MINE_C, over HOPPER_Y.
HOPPER_X = -0.115
HOPPER_Y = 0.235
HOPPER_HINGE = (-0.13, 0.24, -0.04)
HATCH_X = -0.435
HATCH_HINGE = (-0.46, 0.24, -0.04)
MINE_C = (-0.36, 0.39, -0.11)
MINE_R = 0.115
MINE_SPLIT_X = -0.29
ROLE_SAT = 0.45


def role_texels(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (fsp.sat_of(rgb) >= ROLE_SAT) & (rgb.max(-1) >= 0.25) & (r >= b) & (g >= b) & (r - g < 0.45)


def mirror(p, side):
    return np.array([p[0], p[1], p[2] * side])


def legs_fitted(c):
    """Each leg's (hip, knee, tip) (raw units): the guesses, the tip moved to the lowest triangles near it."""
    out = {}
    for name, (hip, knee, tip) in LEGS.items():
        for side, sn in ((1.0, "r"), (-1.0, "l")):
            h, k, t = mirror(hip, side), mirror(knee, side), mirror(tip, side)
            near = (np.linalg.norm(c[:, [0, 2]] - t[[0, 2]], axis=1) < 0.08) & (c[:, 1] < 0.05)
            if near.sum() >= 3:
                t = np.array([c[near, 0].mean(), 0.0, c[near, 2].mean()])
                k = np.array([k[0] + (t[0] - mirror(tip, side)[0]), k[1], k[2] + (t[2] - mirror(tip, side)[2]) * 0.5])
            out[name + sn] = (h, k, t)
    return out


def parts_of(c, tcol, nb):
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    taken = np.zeros(n, bool)
    best = np.full(n, np.inf)
    for leg, (hip, knee, tip) in legs_fitted(c).items():
        d0, d1 = fsp.seg_dist(c, hip, knee), fsp.seg_dist(c, knee, tip)
        side = z * np.sign(hip[2]) > LEG_Z
        near_u = (d0 < REACH[0]) & (d0 <= d1)
        near_l = (d1 < REACH[1]) & (d1 < d0)
        dn = np.minimum(d0, d1)
        m = (near_u | near_l) & side & (y < 0.26) & (dn < best)
        lab[m & near_u] = "leg_%s_u" % leg
        lab[m & near_l] = "leg_%s_l" % leg
        best = np.where(m, dn, best)
        taken |= m
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    head = (x > HEAD_X) & (y < HEAD_TOP) & ~taken & (~role_texels(tcol) | (y < EYE_TOP))
    lab[head] = "head"
    piv["head"] = np.asarray(NECK)
    mine = (np.linalg.norm(c - np.asarray(MINE_C), axis=1) < MINE_R) & (x < MINE_SPLIT_X) & (y > 0.3) & ~taken
    hatch = (x < HATCH_X) & (y > HOPPER_Y) & ~taken & ~mine
    hopper = (x < HOPPER_X) & (y > HOPPER_Y) & ~taken & ~mine & ~hatch
    lab[hopper] = "hopper"
    lab[hatch] = "hatch"
    lab[mine] = "mine"
    piv["hopper"] = np.asarray(HOPPER_HINGE)
    piv["hatch"] = np.asarray(HATCH_HINGE)
    piv["mine"] = np.asarray(MINE_C)
    lab = fsp.smooth(lab, nb, (x > HEAD_X - 0.03) & ~taken, "head", "body", 2)
    return lab, piv


def main():
    labels = sys.argv[sys.argv.index("--labels") + 1] if "--labels" in sys.argv else None
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = warden_prep.load(SRC)
    J = mi_prep.simplify(Wr, J, TARGET_TRIS, True)
    J = J[(J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])]
    s = LENGTH_M / (hi[0] - lo[0])
    cen = Wr[J].mean(1)
    tcol = fsp.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, fsp.neighbours(pinv[J]))
    if labels:
        np.save(labels + "_c.npy", cen)
        np.save(labels + "_lab.npy", part)
        np.save(labels + "_tc.npy", tcol)
    glow = np.zeros(len(J), int)
    glow[(part == "head") & (cen[:, 1] < EYE_TOP) & role_texels(tcol)] = 2
    W = Wr * s
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = fsp.cut_caps(per_part, pinv, W, set(), set())
    lum = tcol @ np.array([0.299, 0.587, 0.114])
    body_m = part == "body"
    dark_uv = UVw[J[body_m][np.argmin(np.where(lum[body_m] > 0.03, lum[body_m], 9.0))]].mean(0)
    glow_part = {pn: glow[part == pn] for pn in order}
    nodes, report, cap_report = warden_prep.write_parts(
        order, per_part, glow_part, cn_all, caps, pivots, s, W, UVw, colour, dark_uv, role_texels
    )
    img = colour.copy()
    role_px = role_texels(img)
    lum_px = img @ np.array([0.299, 0.587, 0.114])
    if role_px.any():
        g = np.clip(lum_px / max(lum_px[role_px].mean(), 1e-3) * 0.82, 0, 1)
        img[role_px] = g[role_px, None]
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, NAME, nodes, buf.getvalue(), mats)
    print(json.dumps({
        "id": NAME, "raw": SRC, "raw_tris": raw_tris, "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in (hi - lo) * s], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
