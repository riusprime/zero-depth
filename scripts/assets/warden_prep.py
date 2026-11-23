"""Prepares the owner's Warden (unprocessed_images/models_v0120_b/warden.glb) for the game:
assets/models/enemies/warden.glb, cut into the parts WardenAvatar animates.

The raw file is a Tripo export: one closed textured mesh (4,892 triangles, a 2048 px colour map), about one unit tall,
no rig, Y up, its front (the sunken head with its glowing eye under the shell's lip) on +Z: a hulking rock golem under
a bronze shell, two boulder shoulders, forearms ending in big fists that rest on the ground in front of it, two short
legs. The raw file stays untouched. This script, reusing mi_prep's reader, normals and glb writer and the Frost
Spitter's cutting helpers:
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres it on x/z with its feet on y = 0 and
   scales it evenly to HEIGHT_M (the old Warden's 1.2 m; it is then 1.22 m wide);
2. cuts it into the parts that move, by place (the mesh is one closed hull): the body (torso, pelvis and shell: the
   rig's root), the head (the face under the shell's lip with the eye: it nods and turns at its neck), each arm's upper
   half (the shoulder boulder, turning at the shoulder) and lower half (forearm and fist, turning at the elbow), each
   leg's thigh, shin and foot (the foot turning at the ankle, so it can stay flat on the ground). A limb's triangles are the ones nearest its bone line (LIMBS, fitted to the
   raw mesh) within its reach; every part node's origin is its pivot;
3. caps the cuts (a fan over each part's cut edges facing the part across the cut), dark stone;
4. sorts each triangle into a surface by the colour map under it: `glow` (the eye's orange, and the dark seam that
   splits the shell's top: the Warden's glowing cracks), `role` (the bronze shell, by role_map's rules: the texels under
   the role triangles made greyscale in the map so the game tints them in the tank bronze) and `base` (the grey and
   charcoal stone);
5. keeps every triangle (under the 5k budget) and the owner's UVs and colour map, halved to TEX_PX;
6. writes assets/models/enemies/warden.glb (one node per part, materials base / role / glow).
It prints one JSON line (the raw and kept triangles, the parts, the caps, the size, the file and its sha256, pasted
into assets/models/manifest.json by hand). With --labels <prefix> it also saves each triangle's centre and part
(<prefix>_c.npy, <prefix>_lab.npy) for looking at the cut.

Run from the repo root:  python scripts/assets/warden_prep.py
Needs numpy, Pillow, scipy (mi_prep's imports; xatlas is stubbed when missing: this script never calls it).
"""

import hashlib
import io
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import frost_spitter_prep as fsp  # noqa: E402  (its cutting helpers; it stubs xatlas)
import role_map  # noqa: E402

mi_prep = fsp.mi_prep

SRC = "unprocessed_images/models_v0120_b/warden.glb"
DST = "assets/models/enemies/warden.glb"
NAME = "warden"
HEIGHT_M = 1.2
TEX_PX = 1024

## Each limb (raw units, the game frame: +X front, +Z the Warden's right; the left mirrored): its pivot, its joint and
## its end. The arms: the shoulder boulder's centre, the elbow behind the fist's top, the fist's knuckles on the
## ground. The legs: the hip, the knee, the toe; the foot (under FOOT_Y) turns at the ankle.
ARM = ((-0.02, 0.62, 0.35), (0.03, 0.42, 0.38), (0.2, 0.08, 0.33))
LEG = ((-0.07, 0.3, 0.18), (-0.08, 0.15, 0.18), (0.08, 0.02, 0.18))
ANKLE = (-0.06, 0.07, 0.18)
FOOT_Y = 0.075
## The reach round each bone line that is still that limb (upper, lower), and where a limb begins: an arm outside
## ARM_Z (the torso is inside), a leg under LEG_TOP and inside LEG_Z.
ARM_REACH = (0.2, 0.22)
ARM_Z = 0.235
LEG_REACH = (0.13, 0.15)
LEG_TOP = 0.3
LEG_Z = 0.29
## The head: ahead of HEAD_X, within HEAD_Z of the middle, between HEAD_LO and HEAD_HI, and not the bronze lip; its
## pivot (the neck, behind the face).
HEAD_X = 0.17
HEAD_Z = 0.2
HEAD_LO = 0.44
HEAD_HI = 0.74
NECK = (0.12, 0.56, 0.0)
EYE_X = 0.22
EYE_TOP = 0.62
## The bronze shell's saturation floor and brightness floor; the eye's glow (bright orange); the seam on the shell's top
## (dark texels over SEAM_Y on the shell).
ROLE_SAT = 0.45
ROLE_LUM = 0.3
SEAM_Y = 0.72
SEAM_LUM = 0.16


def mirror(p, side):
    return np.array([p[0], p[1], p[2] * side])


def role_texels(rgb):
    return (fsp.sat_of(rgb) >= ROLE_SAT) & (rgb.max(-1) >= ROLE_LUM) & (rgb[..., 0] > rgb[..., 2])


def eye_texels(rgb):
    return (rgb.max(-1) >= 0.45) & (fsp.sat_of(rgb) >= 0.6) & (rgb[..., 0] > rgb[..., 2])


def eye_of(c, tcol):
    """The eye: the hot orange in the face under the shell's lip (the bronze lip itself is above EYE_TOP)."""
    return eye_texels(tcol) & (c[:, 0] > EYE_X) & (c[:, 1] < EYE_TOP) & (np.abs(c[:, 2]) < HEAD_Z)


def load(src):
    """The raw mesh in the game frame (raw units), welded as the Frost Spitter's prep welds it."""
    P0, UV, I0, colour = mi_prep.read_glb(src)
    P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)
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
    return Wr, UVw, J, pinv.ravel(), colour, (lo - centre, hi - centre), len(I0)


def parts_of(c, tcol, nb):
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    taken = np.zeros(n, bool)
    for side, sn in ((1.0, "r"), (-1.0, "l")):
        s_out = z * side
        # The legs first (inside, low), then the arms (outside).
        hip, knee, toe = (mirror(p, side) for p in LEG)
        d0, d1 = fsp.seg_dist(c, hip, knee), fsp.seg_dist(c, knee, toe)
        m = (y < LEG_TOP) & (s_out > 0.0) & (s_out < LEG_Z) & (x < 0.13) & ~taken
        up = m & (d0 < LEG_REACH[0]) & (d0 <= d1)
        dn = m & (d1 < LEG_REACH[1]) & (d1 < d0)
        lab[up] = "leg_%s_u" % sn
        lab[dn] = "leg_%s_l" % sn
        taken |= up | dn
        piv["leg_%s_u" % sn] = hip
        piv["leg_%s_l" % sn] = knee
        sh, el, fist = (mirror(p, side) for p in ARM)
        d0, d1 = fsp.seg_dist(c, sh, el), fsp.seg_dist(c, el, fist)
        m = (s_out > ARM_Z) & ~taken & (y < 0.84)
        up = m & (d0 < ARM_REACH[0]) & (d0 <= d1) & (y > 0.4)
        dn = m & (d1 < ARM_REACH[1]) & ((d1 < d0) | (y <= 0.4))
        lab[up] = "arm_%s_u" % sn
        lab[dn] = "arm_%s_l" % sn
        taken |= up | dn
        piv["arm_%s_u" % sn] = sh
        piv["arm_%s_l" % sn] = el
    # Under the hips nothing is the body: a stray low piece goes to the nearest leg or fist.
    stray = np.where((y < 0.2) & ~taken)[0]
    if len(stray):
        ends = []
        for side, sn in ((1.0, "r"), (-1.0, "l")):
            ends.append(("leg_%s_l" % sn, mirror(LEG[1], side), mirror(LEG[2], side)))
            ends.append(("arm_%s_l" % sn, mirror(ARM[1], side), mirror(ARM[2], side)))
        d = np.stack([fsp.seg_dist(c[stray], a, b) for _, a, b in ends], 1)
        for t, k in zip(stray, d.argmin(1)):
            lab[t] = ends[k][0]
        taken[stray] = True
    for side, sn in ((1.0, "r"), (-1.0, "l")):
        foot = ((lab == "leg_%s_l" % sn) | (lab == "leg_%s_u" % sn)) & (y < FOOT_Y)
        lab[foot] = "leg_%s_f" % sn
        piv["leg_%s_f" % sn] = mirror(ANKLE, side)
    head = (
        (x > HEAD_X) & (np.abs(z) < HEAD_Z) & (y > HEAD_LO) & (y < HEAD_HI) & ~taken
        & (~role_texels(tcol) | eye_of(c, tcol))
    )
    lab[head] = "head"
    piv["head"] = np.asarray(NECK)
    lab = fsp.smooth(lab, nb, (x > HEAD_X - 0.04) & (np.abs(z) < HEAD_Z + 0.04) & ~taken, "head", "body", 2)
    return lab, piv


def main():
    labels = sys.argv[sys.argv.index("--labels") + 1] if "--labels" in sys.argv else None
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = load(SRC)
    s = HEIGHT_M / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = fsp.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, fsp.neighbours(pinv[J]))
    if labels:
        np.save(labels + "_c.npy", cen)
        np.save(labels + "_lab.npy", part)
        np.save(labels + "_tc.npy", tcol)
    lum = tcol @ np.array([0.299, 0.587, 0.114])
    glow = np.zeros(len(J), int)
    glow[eye_of(cen, tcol) & (part == "head")] = 2
    glow[(part == "body") & (cen[:, 1] > SEAM_Y) & (lum < SEAM_LUM)] = 2
    W = Wr * s
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = fsp.cut_caps(per_part, pinv, W, set(), set())
    body_m = part == "body"
    dark_uv = UVw[J[body_m][np.argmin(np.where(lum[body_m] > 0.03, lum[body_m], 9.0))]].mean(0)
    glow_part = {pn: glow[part == pn] for pn in order}
    nodes, report, cap_report, tris = write_parts(
        order, per_part, glow_part, cn_all, caps, pivots, s, W, UVw, colour, dark_uv
    )
    img = role_map.tinted_map(colour, UVw, tris[0], tris[1], role_texels)
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


def write_parts(order, per_part, glow_part, cn_all, caps, pivots, s, W, UVw, colour, dark_uv, role_fn=None):
    """Each part's primitives (base 0, role 1, glow 2: a triangle not glowing is role where role_map's share of its
    texels pass role_fn), its caps in the base surface at the dark texel; returns (nodes, report, cap report, (the role
    triangles, the others): the triangles role_map.tinted_map greys the map under). Shared with mine_layer_prep."""
    role_fn = role_fn or role_texels
    nodes, report, cap_report = [], {}, {}
    role_tris, other_tris = [], []
    at = 0
    for pn in order:
        T = per_part[pn]
        cn = cn_all[at : at + len(T)]
        at += len(T)
        K = glow_part[pn].copy()
        rest = K != 2
        K[rest] = (role_map.texel_share(colour, UVw, T[rest], role_fn) >= role_map.ROLE_SHARE).astype(int)
        role_tris.append(T[K == 1])
        other_tris.append(T[K != 1])
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
    return nodes, report, cap_report, (np.concatenate(role_tris), np.concatenate(other_tris))


if __name__ == "__main__":
    sys.exit(main())
