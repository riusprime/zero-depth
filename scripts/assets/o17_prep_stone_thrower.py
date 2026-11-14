"""v0.11.0 O17c: prepares the owner's Stone Thrower (unprocessed_images/models_v0110/stone_thrower.glb) for the game:
assets/models/enemies/stone_thrower.glb, cut into the parts StoneThrowerAvatar poses.

The raw file is a Tripo export: one textured mesh (9,770 triangles, a 2048 px colour map), about one unit across, Y up,
its front raw +Z, no rig. It holds two connected pieces: the brute and, beside its left hand, the rock it throws (the
owner, 2026-11-08: "The rock thrower has the rock separated"). The raw file stays untouched. This script (mi_prep's
enemy path, with its shared weld, simplify, bake and glb writer):
1. turns it into the game's frame (front +X, Y up, +Z the figure's right), centres the brute (not the rock) on x/z with
   the feet at y = 0 and scales it evenly to HEIGHT (the art list's 1.6 m, arms down);
2. cuts it into parts (parts_of): the rock (its own piece, re-centred on its middle: the avatar holds it in the hands),
   the head, each arm in two (upper arm from the shoulder; forearm and hand from the elbow), each leg (from the hip),
   and the torso with the carapace (`body`), each a glTF node with its origin at its pivot;
3. sorts each triangle into `base` (the charcoal, the greys, the bone), `role` (the bronze carapace plates: greyscale
   in the colour map, the game tints them tank bronze) and `glow` (the visor gem), simplifies each part and surface
   apart (borders locked; Godot's simplifier on a PC without meshoptimizer) to BUDGET triangles, gives them one new
   atlas (gd_atlas.py: Godot's xatlas, as this PC's Python has no xatlas package) and bakes the raw colour map onto it;
4. writes assets/models/enemies/stone_thrower.glb and prints one JSON line (raw and new triangles per part, the file's
   size and sha256: pasted into assets/models/manifest.json by hand).

Run from the repo root:  GODOT=<godot executable> python scripts/assets/o17_prep_stone_thrower.py
Needs numpy, Pillow, scipy and Godot 4.7 (the simplifier and the atlas).
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
    import xatlas  # noqa: F401  (mi_prep imports it; this script's atlas is gd_atlas's)
except ImportError:
    sys.modules["xatlas"] = types.ModuleType("xatlas")
import gd_atlas  # noqa: E402
import mi2_prep  # noqa: E402,F401  (the shared path's entry; mi_prep holds the functions)
import mi_prep  # noqa: E402

RID = "stone_thrower"
SRC = "unprocessed_images/models_v0110/stone_thrower.glb"
DST = "assets/models/enemies/stone_thrower.glb"
HEIGHT = 1.6
YAW = 90.0  # raw +Z (the face) onto +X
BUDGET = 6000
TEX_PX = 1024
## Texel classes (mi_prep.classify_texels): role saturation floor, glow value floor, glow saturation floor.
THRESHOLDS = (0.55, 0.95, 0.8)


def game_frame(P):
    """Raw -> game: the turn, then the brute (the largest piece) centred on x/z, the feet at 0, scaled to HEIGHT."""
    a = np.radians(YAW)
    R = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    return P @ R.T


def load():
    P0, UV, I, colour = mi_prep.read_glb(SRC)
    Q = game_frame(P0)
    ext = Q.max(0) - Q.min(0)
    W0, J0, keep = mi_prep.weld(Q, I, ext.max() * 2e-5)
    J0 = J0[keep]
    comp = mi_prep.components(len(W0), J0)
    tc = comp[J0[:, 0]]
    body = tc == np.argmax(np.bincount(tc))
    bv = W0[np.unique(J0[body])]
    lo, hi = bv.min(0), bv.max(0)
    shift = np.array([(lo[0] + hi[0]) / 2, min(lo[1], Q[:, 1].min()), (lo[2] + hi[2]) / 2])
    s = HEIGHT / (hi[1] - lo[1])
    P = (Q - shift) * s
    return P, UV, I, colour


## The joints (game frame, metres, the figure's right side; the left mirrors z): read off the raw model's renders.
SHOULDER = np.array([0.0, 1.12, 0.44])
ELBOW = np.array([0.04, 0.8, 0.56])
WRIST = np.array([0.16, 0.41, 0.62])
PELVIS = np.array([0.0, 0.62, 0.0])
HIP = np.array([0.0, 0.6, 0.17])
NECK = np.array([0.3, 0.9, 0.0])
## The cuts: an arm is outside ARM_Z (and under the carapace's role plates above CARAPACE_Y); the forearm below the
## elbow's height; a leg under LEG_Y inside ARM_Z; the head in front of HEAD_X between HEAD_Y, inside HEAD_Z.
ARM_Z = 0.37
CARAPACE_Y = 0.72
LEG_Y = 0.52
HEAD_X = 0.24
HEAD_Y = (0.88, 1.22)
HEAD_Z = 0.19
TOE_Y = 0.15
TOE_Z = 0.45


def parts_of(W, J, comp, cls):
    """Per welded triangle: its part, and each part's pivot (game frame, metres). `cls`: each triangle's texel class
    (mi_prep.classify_texels: 1 the role plates, the carapace)."""
    c = W[J].mean(1)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    n = len(J)
    lab = np.array(["body"] * n, dtype=object)
    piv = {"body": PELVIS.copy()}
    tc = comp[J[:, 0]]
    rock = tc != np.argmax(np.bincount(tc))
    lab[rock] = "rock"
    rv = W[np.unique(J[rock])]
    piv["rock"] = (rv.min(0) + rv.max(0)) / 2
    shell = (cls == 1) & (y > CARAPACE_Y)
    free = (lab == "body") & ~shell
    for side, sfx in ((1.0, "r"), (-1.0, "l")):
        mirror = np.array([1.0, 1.0, side])
        toe = (y < TOE_Y) & (z * side < TOE_Z)  # the outer toes reach past ARM_Z: they stay the foot's
        arm = free & (z * side > ARM_Z) & (y < 1.32) & ~toe
        fore = arm & (y < ELBOW[1])
        hand = fore & (y < WRIST[1])
        lab[arm & ~fore] = "arm_" + sfx
        piv["arm_" + sfx] = SHOULDER * mirror
        lab[fore & ~hand] = "fore_" + sfx
        piv["fore_" + sfx] = ELBOW * mirror
        lab[hand] = "hand_" + sfx
        piv["hand_" + sfx] = WRIST * mirror
        leg = free & (y < LEG_Y) & (z * side > 0.0) & ((z * side <= ARM_Z) | toe)
        lab[leg] = "leg_" + sfx
        piv["leg_" + sfx] = HIP * mirror
    head = free & (lab == "body") & (x > HEAD_X) & (y > HEAD_Y[0]) & (y < HEAD_Y[1]) & (np.abs(z) < HEAD_Z)
    lab[head] = "head"
    piv["head"] = NECK
    return lab, piv


def classes(source, W, J):
    fn, _ = mi_prep.face_normals(W, J)
    t, b = source.nearest(W[J].mean(1), fn, k=6)
    return mi_prep.classify_texels(source.colour_at(t, b), THRESHOLDS)


def debug_parts():
    P, UV, I, colour = load()
    ext = P.max(0) - P.min(0)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    J = J[keep]
    comp = mi_prep.components(len(W), J)
    source = mi_prep.Source(P, UV, I, colour)
    cls = classes(source, W, J)
    lab, piv = parts_of(W, J, comp, cls)
    if os.environ.get("O17_CLS"):
        lab = np.array(["base", "role", "glow"], dtype=object)[cls]
        piv = {k: np.zeros(3) for k in ("base", "role", "glow")}
    uvt = UV[I[keep]].mean(1)
    h, w = colour.shape[:2]
    px = np.clip((uvt[:, 0] * w).astype(int), 0, w - 1)
    py = np.clip((uvt[:, 1] * h).astype(int), 0, h - 1)
    return W, J, lab, piv, colour[py, px]


def main():
    P, UV, I, colour = load()
    source = mi_prep.Source(P, UV, I, colour)
    ext = P.max(0) - P.min(0)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    J = J[keep]
    comp = mi_prep.components(len(W), J)
    cls = classes(source, W, J)
    part, pivots = parts_of(W, J, comp, cls)
    # Simplified apart: each part, and in it the visor's glowing gem (small: it must survive), borders locked; the
    # grey and bronze triangles are told apart after (mi_prep's enemy path).
    glow = np.where(cls == 2, 2, 0)
    groups = sorted({(p, k) for p, k in zip(part, glow)}, key=lambda g: (g[0], g[1]))
    total = len(J)
    scale = 1.0
    for _attempt in range(6):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (glow == g[1])
            share = max(int(round(BUDGET * scale * m.sum() / total)), 24 if g[1] == 2 else 12)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=len(groups) > 1)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= BUDGET * 1.02:
            break
        scale *= BUDGET / tris_after * 0.97
    for g in groups:
        T = simplified[g]
        if g[1] == 2 or len(T) == 0:
            simplified[g] = (T, np.full(len(T), g[1]))
            continue
        fn, _ = mi_prep.face_normals(W, T)
        t, b = source.nearest(W[T].mean(1), fn, k=6)
        k = mi_prep.classify_texels(source.colour_at(t, b), THRESHOLDS).clip(0, 1)
        if g[0] != "body":
            k[:] = 0  # the bronze is the carapace's (the torso's); a chip on a limb stays grey
        simplified[g] = (T, k)
    order = sorted(pivots)
    per_part = {}
    for pn in order:
        T = np.concatenate([simplified[g][0] for g in groups if g[0] == pn] or [np.zeros((0, 3), np.int64)])
        K = np.concatenate([simplified[g][1] for g in groups if g[0] == pn] or [np.zeros(0, int)])
        if len(T) == 0:
            continue
        used, inv = np.unique(T.ravel(), return_inverse=True)
        V = W[used]
        Tl = inv.reshape(-1, 3)
        fnv = np.zeros_like(V)
        fn, area = mi_prep.face_normals(V, Tl)
        for c3 in range(3):
            np.add.at(fnv, Tl[:, c3], fn * area[:, None])
        fnv /= np.maximum(np.linalg.norm(fnv, axis=1), 1e-12)[:, None]
        per_part[pn] = (V, Tl, K, fnv)
    names = [pn for pn in order if pn in per_part]
    aw, ah, charts = gd_atlas.unwrap([(per_part[pn][0], per_part[pn][1], per_part[pn][3]) for pn in names], TEX_PX)
    img = np.zeros((TEX_PX, TEX_PX, 3))
    filled = np.zeros((TEX_PX, TEX_PX), bool)
    nodes = []
    for mi, pn in enumerate(names):
        V, Tl, K, _fnv = per_part[pn]
        vmap, idx, uvs = charts[mi]
        pos = V[vmap]
        corner_n = mi_prep.corner_normals(V, Tl)
        uv_px = uvs * np.array([aw, ah]) * (TEX_PX / max(aw, ah, 1))
        fnp, _ = mi_prep.face_normals(pos, idx)
        p3, n3, wh = mi_prep.rasterise_faces(uv_px, idx, pos, fnp, TEX_PX)
        if len(p3):
            t, b = source.nearest(p3, n3)
            img[wh[:, 1], wh[:, 0]] = source.colour_at(t, b)
            filled[wh[:, 1], wh[:, 0]] = True
        cp = pos[idx].reshape(-1, 3)
        cn = corner_n.reshape(-1, 3)
        cu = (uvs[idx] * np.array([aw, ah]) / max(aw, ah, 1)).reshape(-1, 2)
        prims = []
        for k in (0, 1, 2):
            sel = np.where(K == k)[0]
            if len(sel) == 0:
                continue
            ci = (sel[:, None] * 3 + np.arange(3)[None]).ravel()
            prims.append((k, cp[ci] - pivots[pn], cn[ci], cu[ci], np.arange(len(ci)).reshape(-1, 3)))
        nodes.append((pn, pivots[pn], prims))
    img = mi_prep.dilate(img, filled, mi_prep.PAD_PX * 2)
    # The bronze plates' texels in greyscale (the game multiplies them by the kind's role colour).
    cls_px = mi_prep.classify_texels(img, THRESHOLDS)
    lum = img @ np.array([0.299, 0.587, 0.114])
    role_px = cls_px == 1
    if role_px.any():
        g = np.clip(lum / max(lum[role_px].mean(), 1e-3) * 0.82, 0, 1)
        img[role_px] = g[role_px, None]
    buf = io.BytesIO()
    Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8)).save(buf, "JPEG",
                                                                             quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, RID, nodes, buf.getvalue(), mats)
    src_tris = len(I)
    print(json.dumps({
        "id": RID, "raw": SRC, "raw_tris": src_tris, "raw_bytes": os.path.getsize(SRC), "tris": int(tris_after),
        "budget": BUDGET, "tex": TEX_PX, "atlas": [aw, ah], "backend": mi_prep.BACKEND + "+gd_unwrap",
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": {pn: [len(per_part[pn][1]), int((per_part[pn][2] == 1).sum()), int((per_part[pn][2] == 2).sum()),
                       [round(float(v), 3) for v in pivots[pn]]] for pn in names},
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
