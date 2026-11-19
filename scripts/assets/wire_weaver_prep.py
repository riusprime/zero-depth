"""Prepares the owner's Wire Weaver (unprocessed_images/models_v0120/wire_weaver.glb) for the game:
assets/models/enemies/wire_weaver.glb, cut into the parts WireWeaverAvatar animates.

The raw file is a Tripo export: one closed textured mesh (4,882 triangles, a 2048 px colour map), about one unit
across, no rig, Y up, its front (the round face socket and its hexagonal gem visor) already on +X. A charcoal hull
under a yellow ridged shell, a cable spool on its back (a drum between two discs on an axle, held by a bracket), two
claw arms reaching forward and FOUR thin legs set round it unevenly (one behind, one back-right, one left, one
front-right: the model's own layout, kept). It carries no cable posts: WireWeaverAvatar builds the two it carries in
code, in the look of the posts it plants. The raw file stays untouched. This script (the Kiln Beetle's path,
o17_prep_kiln_beetle.py, reusing its colour sampling and cut caps, and mi_prep's reader, normals and glb writer):
1. keeps the frame (+X the front already), centres it on x/z with its feet on y = 0 and scales it evenly to HEIGHT_M
   (the request row: about 1.0 m);
2. cuts it into the parts that move (the mesh is one closed hull, so the cuts are made by place): the spool (the
   coiled drum between the discs, turning on its axle; the discs, the bracket and the axle pins stay on the body), the
   head (the face socket with
   the gem, in front of HEAD_X), each leg's upper half (from its hip under the hull, through its knuckle, to the
   orange ring above the shin) and lower half (the shin and its bone tip), each arm's upper half (shoulder to elbow)
   and lower half (forearm and claw), and the body (the hull, the shell and the bracket: the rig's root). A limb's
   triangles are the ones near its bone line (LEGS, ARMS: read off the raw mesh's slices); every part node's origin is
   its pivot;
3. caps the cuts (the hull and the limbs are hollow: a part turning would show through): a charcoal fan over each
   part's cut edges facing the part across the cut, inside the closed hull, unseen until a part moves;
4. sorts each triangle into a surface by the colour map under it: `glow` (the gem visor: the hexagon at the face
   socket's middle), `role` (the yellow shell plates and rings: their texels turned greyscale in the map so the game
   tints them in the kind's role colour) and `base` (the charcoal, the grey limbs, the bone tips);
5. keeps every triangle (the raw count is under the enemy budget: no simplifier) and the owner's own UV layout and
   colour map, halved to TEX_PX;
6. writes assets/models/enemies/wire_weaver.glb (one node per part, three materials base / role / glow), and finds
   in the map the texels the carried posts' grey and dark take their colour from (post_uvs: pasted into
   WireWeaverAvatar's POST_UVS by hand).
It prints one JSON line: the raw triangles and file size, the triangles after (per part: total, glow, role, the
pivot), the caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json
by hand). `--debug=<png>` instead draws each triangle in its part's colour from the top, the side and the front.

Run from the repo root:  python scripts/assets/wire_weaver_prep.py
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
import mi2_prep  # noqa: E402  (its mi_prep: the reader, normals and glb writer)
import o17_prep_kiln_beetle as beetle  # noqa: E402  (the colour sampling and the cut caps)

mi_prep = mi2_prep.mi_prep

SRC = "unprocessed_images/models_v0120/wire_weaver.glb"
DST = "assets/models/enemies/wire_weaver.glb"
HEIGHT_M = 1.0
TEX_PX = 1024

## Each leg (raw units, the game frame: +X front, +Z its right): its hip (where the thigh leaves the hull), its knuckle
## (where the thigh turns down), its knee (the orange ring above the shin: the lower half's pivot) and its foot.
## rc: behind, rr: back right, ml: left, fr: front right (under the right arm).
LEGS = {
    "rc": ((-0.27, 0.44, -0.01), (-0.42, 0.41, -0.008), (-0.457, 0.27, -0.014), (-0.458, 0.0, -0.022)),
    "rr": ((-0.18, 0.44, 0.19), (-0.31, 0.42, 0.322), (-0.343, 0.27, 0.367), (-0.344, 0.0, 0.377)),
    "ml": ((-0.13, 0.44, -0.21), (-0.081, 0.42, -0.314), (-0.064, 0.27, -0.348), (-0.045, 0.0, -0.364)),
    "fr": ((0.035, 0.39, 0.16), (0.082, 0.335, 0.201), (0.15, 0.262, 0.231), (0.19, 0.0, 0.245)),
}
## Each arm: its shoulder (under the shell's brim), its elbow (the lower half's pivot), its wrist and its claw's tip.
## r: the right arm (rising to a high elbow), l: the left (a long low reach; its elbow is the bone knuckle near the
## wrist).
ARMS = {
    "r": ((0.125, 0.53, 0.22), (0.235, 0.409, 0.275), (0.374, 0.259, 0.267), (0.47, 0.17, 0.256)),
    "l": ((0.133, 0.439, -0.204), (0.336, 0.364, -0.293), (0.40, 0.33, -0.29), (0.47, 0.27, -0.289)),
}
## The reach (raw units) round a leg's and an arm's bone line that is still that limb (the claws and knuckles are
## wider than the shins).
LEG_REACH = 0.05
ARM_REACH = (0.055, 0.075)
## The spool: the coiled drum between the two discs (the discs, their hubs, the axle pins and the bracket's struts
## crossing in front of them stay on the body: a turning disc would tear from the struts). Its axle (x, y; along z,
## the drum's middle), the coil's reach from it and how far out along z it goes (to the discs' inner faces); its pivot
## is the axle's middle.
AXLE = (-0.205, 0.818)
SPOOL_R = 0.168
SPOOL_Z = 0.195
## The head: the round face socket and its gem, ahead of HEAD_X, within HEAD_Z of the middle, between HEAD_Y; its
## pivot (the neck, inside the hull behind the socket).
HEAD_X = 0.255
HEAD_Z = 0.14
HEAD_Y = (0.46, 0.745)
NECK = (0.2, 0.6, 0.0)
## The gem visor: the triangles within GEM_R of the gem's middle on the face (the hexagon and its rim).
GEM = (0.335, 0.598, 0.0)
GEM_R = 0.065


def seg_near(c, pts, reach):
    """Each centre's distance to the polyline `pts` and the index of its nearest segment."""
    best = np.full(len(c), np.inf)
    which = np.zeros(len(c), int)
    for k in range(len(pts) - 1):
        d = beetle.seg_dist(c, pts[k], pts[k + 1])
        closer = d < best
        best = np.where(closer, d, best)
        which = np.where(closer, k, which)
    return best, which


def parts_of(c, tcol, pinv_J=None):
    """Per triangle centre (raw units): its part; and each part's pivot (raw units). With `pinv_J` (each triangle's
    position-welded corners) a piece of the body cut off from the rest (a claw's finger past its bone line's reach)
    goes to the part it touches, so nothing floats when the limbs move."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    best = np.full(n, np.inf)
    for leg, (hip, knuckle, knee, foot) in LEGS.items():
        hip, knuckle, knee, foot = (np.asarray(p) for p in (hip, knuckle, knee, foot))
        d, seg = seg_near(c, [hip, knuckle, knee, foot], LEG_REACH)
        out = knuckle - hip
        beyond = (c - hip) @ (out / np.linalg.norm(out)) > -0.005
        m = (d < LEG_REACH) & beyond & (d < best)
        lab[m & (seg < 2)] = "leg_%s_u" % leg
        lab[m & (seg == 2)] = "leg_%s_l" % leg
        best = np.where(m, d, best)
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    for arm, (shoulder, elbow, wrist, tip) in ARMS.items():
        shoulder, elbow, wrist, tip = (np.asarray(p) for p in (shoulder, elbow, wrist, tip))
        d, seg = seg_near(c, [shoulder, elbow, wrist, tip], ARM_REACH[1])
        reach = np.where(seg == 0, ARM_REACH[0], ARM_REACH[1])
        out = elbow - shoulder
        beyond = (c - shoulder) @ (out / np.linalg.norm(out)) > -0.005
        m = (d < reach) & beyond & (d < best) & (y < 0.6)
        lab[m & (seg == 0)] = "arm_%s_u" % arm
        lab[m & (seg > 0)] = "arm_%s_l" % arm
        best = np.where(m, d, best)
        piv["arm_%s_u" % arm] = shoulder
        piv["arm_%s_l" % arm] = elbow
    free = lab == "body"
    role = beetle.role_texels(tcol)
    r = np.hypot(x - AXLE[0], y - AXLE[1])
    spool = free & (r < SPOOL_R) & (np.abs(z) < SPOOL_Z) & ~role
    lab[spool] = "spool"
    piv["spool"] = np.array([AXLE[0], AXLE[1], 0.0])
    head = free & (x > HEAD_X) & (np.abs(z) < HEAD_Z) & (y > HEAD_Y[0]) & (y < HEAD_Y[1]) & ~role
    head |= free & (np.linalg.norm(c - np.asarray(GEM), axis=1) < GEM_R) & (x > HEAD_X)
    lab[head] = "head"
    piv["head"] = np.asarray(NECK)
    if pinv_J is not None:
        lab = _stray_body(lab, c, pinv_J)
    return lab, piv


def _stray_body(lab, c, pinv_J):
    """The body's pieces apart from its largest go to the nearest triangle of another part."""
    body = np.where(lab == "body")[0]
    parent = {}

    def find(v):
        while parent.setdefault(v, v) != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for t in body:
        a, b, d = pinv_J[t]
        parent[find(a)] = find(b)
        parent[find(b)] = find(d)
    root = np.array([find(pinv_J[t][0]) for t in body])
    keys, counts = np.unique(root, return_counts=True)
    main = keys[np.argmax(counts)]
    others = np.where(lab != "body")[0]
    out = lab.copy()
    for k in keys:
        if k == main:
            continue
        piece = body[root == k]
        d = np.linalg.norm(c[others][None, :, :] - c[piece][:, None, :], axis=2)
        out[piece] = lab[others[np.argmin(d.min(0))]]
    return out


def cut_caps(part_tris, pinv, W):
    """Caps over each part's cut edges: {part: [(surface, triangles (k, 3, 3) metres)]}, as the Kiln Beetle's
    (beetle.cut_caps) but one fan per closed run of cut edges: a part cut from another in two places (a claw touching a
    leg, an arm's root and its elbow) gets two caps, never one fan stretched across the gap between them."""
    whole = beetle.cut_caps(part_tris, pinv, W, set(), set())
    caps = {}
    for pn, fans in whole.items():
        for surf, tris in fans:
            # Each fan triangle is (edge start, edge end, centre): group its edges into runs sharing a corner.
            ends = [(tuple(np.round(t[0], 7)), tuple(np.round(t[1], 7))) for t in tris]
            parent = {}

            def find(v):
                while parent.setdefault(v, v) != v:
                    parent[v] = parent[parent[v]]
                    v = parent[v]
                return v

            for a, b in ends:
                parent[find(a)] = find(b)
            runs = {}
            for k, (a, _b) in enumerate(ends):
                runs.setdefault(find(a), []).append(k)
            for ks in runs.values():
                if len(ks) < 3:
                    continue
                run = tris[ks].copy()
                centre = run[:, :2].reshape(-1, 3).mean(0)
                run[:, 2] = centre
                caps.setdefault(pn, []).append((surf, run))
    return caps


## The carried posts' looks (WireWeaverAvatar builds them in code: their grey rod and dark foot): the colours they
## should take from the map, so a VAT crowd (which multiplies every plate by the map at its UV) draws them as the live
## avatar does.
POST_LOOKS = {"grey": "#8A817C", "dark": "#5F5551"}


def post_uvs(img):
    """For each POST_LOOKS colour, the UV (glTF: from the top left) of the middle of the most uniform 9 px patch of the
    map closest to it, and that patch's colour."""
    from scipy.ndimage import uniform_filter

    mean = np.stack([uniform_filter(img[..., k], 9) for k in range(3)], -1)
    var = sum(uniform_filter(img[..., k] ** 2, 9) - mean[..., k] ** 2 for k in range(3))
    out = {}
    for name, hexc in POST_LOOKS.items():
        want = np.array([int(hexc[i : i + 2], 16) / 255.0 for i in (1, 3, 5)])
        score = np.linalg.norm(mean - want, axis=-1) + 20.0 * np.sqrt(np.maximum(var, 0.0))
        y, x = np.unravel_index(np.argmin(score), score.shape)
        uv = [round((x + 0.5) / img.shape[1], 5), round((y + 0.5) / img.shape[0], 5)]
        out[name] = [uv, [round(float(v), 3) for v in mean[y, x]]]
    return out


def load():
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    lo, hi = P0.min(0), P0.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    return P0 - centre, UV, I0, colour, HEIGHT_M / (hi[1] - lo[1]), lo, hi


def welded(raw, UV, I0, lo, hi):
    """Welded by position and UV (the seams stay apart, every vertex keeps its UV), and the same vertices welded by
    position alone (pinv: the normals smooth across the seams; the cuts are found on it)."""
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
    return Wr, UVw, J, pinv.ravel()


PART_COLOURS = {
    "body": (90, 90, 90), "head": (255, 0, 255), "spool": (0, 200, 255),
    "leg_rc_u": (255, 0, 0), "leg_rc_l": (128, 0, 0), "leg_rr_u": (0, 255, 0), "leg_rr_l": (0, 120, 0),
    "leg_ml_u": (0, 0, 255), "leg_ml_l": (0, 0, 120), "leg_fr_u": (255, 160, 0), "leg_fr_l": (140, 80, 0),
    "arm_r_u": (255, 255, 0), "arm_r_l": (160, 160, 0), "arm_l_u": (0, 255, 200), "arm_l_l": (0, 140, 110),
}


def debug(out):
    from PIL import ImageDraw

    raw, UV, I0, colour, _s, lo, hi = load()
    Wr, UVw, J, pinv = welded(raw, UV, I0, lo, hi)
    cen = Wr[J].mean(1)
    part, _ = parts_of(cen, beetle.tri_colour(colour, UVw, J), pinv[J])
    size = 700
    sheet = Image.new("RGB", (size * 3, size), "white")
    views = ((0, 2, 1, 1.0), (0, 1, 2, 1.0), (2, 1, 0, 1.0))  # top (x, z), side (x, y), front (z, y)
    for k, (a0, a1, depth, sign) in enumerate(views):
        im = Image.new("RGB", (size, size), "white")
        d = ImageDraw.Draw(im)
        order = np.argsort(sign * cen[:, depth])
        for t in order:
            v = Wr[J[t]]
            yy = v[:, a1] if a1 != 1 else 0.5 - v[:, 1]
            pts = [(size / 2 + v[q, a0] * size * 0.9, size / 2 + yy[q] * size * 0.9) for q in range(3)]
            d.polygon(pts, fill=PART_COLOURS.get(part[t], (0, 0, 0)), outline=(0, 0, 0))
        sheet.paste(im, (k * size, 0))
    sheet.save(out)
    print(json.dumps({p: int((part == p).sum()) for p in PART_COLOURS}))


def main():
    for a in sys.argv[1:]:
        if a.startswith("--debug="):
            debug(a[len("--debug="):])
            return 0
    raw, UV, I0, colour, s, lo, hi = load()
    Wr, UVw, J, pinv = welded(raw, UV, I0, lo, hi)
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, pinv[J])
    W = Wr * s  # metres
    gem = (part == "head") & (np.linalg.norm(cen - np.asarray(GEM), axis=1) < GEM_R)
    gem &= beetle.role_texels(tcol) | beetle.glow_texels(tcol)
    surf = np.where(gem, 2, beetle.role_texels(tcol).astype(int))
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    per_surf = {pn: surf[part == pn] for pn in order}
    # Normals over the whole position-welded mesh, every part at once (no crease where two parts meet, nor at the
    # UV seams).
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = cut_caps(per_part, pinv, W)
    # A charcoal texel for the caps (the darkest body triangle's centre).
    body_m = part == "body"
    lum = tcol @ np.array([0.299, 0.587, 0.114])
    dark_uv = UVw[J[body_m][np.argmin(np.where(lum[body_m] > 0.03, lum[body_m], 9.0))]].mean(0)
    nodes = []
    report = {}
    cap_report = {}
    at = 0
    for pn in order:
        T = per_part[pn]
        K = per_surf[pn]
        cn = cn_all[at : at + len(T)]
        at += len(T)
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
            for cs, tris in caps.get(pn, []):
                if cs != k:
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
    # The colour map: the role plates' texels greyscale (the game multiplies them by the role colour), halved.
    img = colour.copy()
    role_px = beetle.role_texels(img)
    lum_px = img @ np.array([0.299, 0.587, 0.114])
    if role_px.any():
        g = np.clip(lum_px / max(lum_px[role_px].mean(), 1e-3) * 0.82, 0, 1)
        img[role_px] = g[role_px, None]
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    looks = post_uvs(np.asarray(Image.open(io.BytesIO(buf.getvalue())).convert("RGB")).astype(float) / 255.0)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, "wire_weaver", nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    print(json.dumps({
        "id": "wire_weaver", "raw": SRC, "raw_tris": len(I0), "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(per_part[pn]) for pn in order)), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report, "post_uvs": looks,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
