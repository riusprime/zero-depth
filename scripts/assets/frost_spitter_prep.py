"""Prepares the owner's Frost Spitter (unprocessed_images/models_v0120/frost_spitter.glb) for the game:
assets/models/enemies/frost_spitter.glb, cut into the parts FrostSpitterAvatar animates.

The raw file is a Tripo export: one closed textured mesh (4,796 triangles, a 2048 px colour map), about one unit
long, no rig, Y up, its front (the charcoal face plate with its gem visor over the mouth slit, the big pale throat sac
under it) on +Z, under a faceted blue shell, on four segmented legs (the front pair reaching forward, the hind pair
bent back). The raw file stays untouched. This script, reusing mi_prep's reader, normals and glb writer (through
mi2_prep, which imports it):
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres it on x/z with its feet on y = 0 and
   scales it evenly to HEIGHT_M (the request row: about 0.85 m; it is then 1.1 m long);
2. cuts it into the parts that move (the mesh is one closed hull, so the cuts are made by place and colour): the shell
   (the blue hood with its icicles, above the rim), the body (the charcoal torso and the mouth's lower lip: the rig's
   root), the head (the face plate above the mouth slit with the visor: it hinges at the back of the slit, so a nod up
   opens the mouth), the sac (the pale throat sac) and each leg's upper half (hip to knee) and lower half (the foot
   and its bone claws). A leg's triangles are the ones near its bone line (LEGS, fitted to the raw mesh);
   every part node's origin is its pivot (the hip, the knee, the hinge, the sac's root, the shell's rim centre);
3. caps the cuts (the hull is hollow: a part turning or swelling would show through it): a fan over each part's cut
   edges facing the part across the cut; the body's cap under the sac glows with it (when the sac empties, the throat
   still glows), the others charcoal (none on the shell: its underside is never seen);
4. sorts each triangle into a surface by the colour map under it: `glow` (the whole sac; on the head, the gem visor),
   `role` (the saturated blue plates of the shell and the leg cuffs, by role_map's rules: the texels under the role
   triangles turned greyscale in the map so the game tints them in the kind's role colour) and `base` (the charcoal, the
   greys, the frost-white, the icicles, the bone claws);
5. keeps every triangle (the raw mesh is already under the 5k budget: no simplification) and the owner's own UV layout
   and colour map, halved to TEX_PX;
6. writes assets/models/enemies/frost_spitter.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and file size, the triangles after (per part: total, glow, role, the
pivot), the caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json
by hand).

Run from the repo root:  python scripts/assets/frost_spitter_prep.py
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
import role_map  # noqa: E402

mi_prep = mi2_prep.mi_prep

SRC = "unprocessed_images/models_v0120/frost_spitter.glb"
DST = "assets/models/enemies/frost_spitter.glb"
HEIGHT_M = 0.85
TEX_PX = 1024

## Each leg (raw units, the game frame: +X front, +Z the spitter's right): its hip (where it leaves the body under the
## shell), its knee (the wrist under the front legs' blue cuff, the hock under the hind legs') and its foot's tip.
## fr / fl: the front pair (reaching forward to the claws), br / bl: the hind pair (bent back, the foot under the hock).
LEGS = {
    "fr": ((0.15, 0.31, 0.225), (0.235, 0.115, 0.31), (0.44, 0.02, 0.30)),
    "fl": ((0.15, 0.31, -0.225), (0.235, 0.115, -0.31), (0.44, 0.02, -0.30)),
    "br": ((-0.17, 0.31, 0.215), (-0.405, 0.14, 0.235), (-0.41, 0.01, 0.265)),
    "bl": ((-0.17, 0.31, -0.215), (-0.405, 0.14, -0.235), (-0.41, 0.01, -0.265)),
}
## The reach (raw units) round the upper and the lower line that is still that leg; above LEG_TOP it is the shell; a
## leg starts LEG_Z off the middle (the body's flank is inside it).
REACH = (0.085, 0.095)
LEG_TOP = 0.365
LEG_Z = 0.165
## Under FOOT_Y nothing is the body: a claw splayed past the reach (the hind feet's outer claws) goes to the nearest
## foot.
FOOT_Y = 0.1
## The head: ahead of HEAD_X, within HEAD_Z of the middle, between the mouth slit (MOUTH_Y) and HEAD_TOP, the dark face
## plate (under HEAD_DARK) or the visor; its pivot (the hinge at the back of the slit).
HEAD_X = 0.255
HEAD_Z = 0.175
MOUTH_Y = 0.428
HEAD_TOP = 0.575
HEAD_DARK = 0.5
HINGE = (0.30, 0.43, 0.0)
## The sac: pale ice-blue within SAC_R of SAC_C (and within SAC_Z of the middle, under SAC_TOP); its pivot (its root
## under the jaw, where it swells and empties from).
SAC_C = (0.27, 0.27, 0.0)
SAC_R = 0.2
SAC_Z = 0.2
SAC_TOP = 0.425
SAC_ROOT = (0.2, 0.36, 0.0)
## The shell: above SHELL_Y (and not the head, not a leg); its pivot (the rim's centre, where it lifts and tips from).
SHELL_Y = 0.395
SHELL_PIVOT = (-0.02, 0.42, 0.0)
## The plates' saturation floor (the shell's blue plates are over 0.55; its pale patches, the sac and the greys under).
ROLE_SAT = 0.55


def sat_of(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    return (mx - mn) / np.maximum(mx, 1e-6)


def visor_texels(rgb):
    """The gem visor's bright cyan (blue near full, green over a third, red low)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (b >= 0.8) & (g >= 0.35) & (r <= 0.45)


def pale_ice(rgb):
    """The sac's pale ice-blue: bright, blue over red, not the shell's deep blue."""
    r, b = rgb[..., 0], rgb[..., 2]
    return (b >= 0.6) & (b >= r + 0.15) & (r >= 0.25)


def role_texels(rgb):
    mx = rgb.max(-1)
    blue = rgb[..., 2] >= rgb[..., 0]
    return (sat_of(rgb) >= ROLE_SAT) & (mx >= 0.3) & blue & ~visor_texels(rgb)


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


def neighbours(J):
    """Each triangle's edge neighbours (by welded vertex index): a list of lists."""
    edges = {}
    for t, tri in enumerate(J):
        for k in range(3):
            e = tuple(sorted((tri[k], tri[(k + 1) % 3])))
            edges.setdefault(e, []).append(t)
    nb = [[] for _ in range(len(J))]
    for ts in edges.values():
        for a in ts:
            for b in ts:
                if a != b:
                    nb[a].append(b)
    return nb


def smooth(lab, nb, band, a, b, passes=3):
    """A triangle in `band` labelled a or b takes what most of its a / b neighbours are."""
    for _ in range(passes):
        new = lab.copy()
        for t in np.where(band)[0]:
            if lab[t] not in (a, b):
                continue
            ns = [lab[k] for k in nb[t] if lab[k] in (a, b)]
            if len(ns) >= 2:
                s = sum(1 for v in ns if v == a)
                if s * 2 > len(ns):
                    new[t] = a
                elif s * 2 < len(ns):
                    new[t] = b
        lab = new
    return lab


def parts_of(c, tcol, nb):
    """Per triangle centre (raw units, game frame): its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    best = np.full(n, np.inf)
    taken = np.zeros(n, bool)
    for leg, (hip, knee, tip) in LEGS.items():
        hip, knee, tip = np.asarray(hip), np.asarray(knee), np.asarray(tip)
        d0 = seg_dist(c, hip, knee)
        d1 = seg_dist(c, knee, tip)
        side = z * np.sign(hip[2]) > LEG_Z
        near_u = (d0 < REACH[0]) & (d0 <= d1)
        near_l = (d1 < REACH[1]) & (d1 < d0)
        dn = np.minimum(d0, d1)
        m = (near_u | near_l) & side & (y < LEG_TOP) & (dn < best)
        lab[m & near_u] = "leg_%s_u" % leg
        lab[m & near_l] = "leg_%s_l" % leg
        best = np.where(m, dn, best)
        taken |= m
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    stray = np.where((y < FOOT_Y) & ~taken)[0]
    if len(stray):
        feet = list(LEGS)
        d = np.stack([seg_dist(c[stray], LEGS[f][1], LEGS[f][2]) for f in feet], 1)
        for t, k in zip(stray, d.argmin(1)):
            lab[t] = "leg_%s_l" % feet[k]
        taken[stray] = True
    sac = (
        (np.linalg.norm(c - np.asarray(SAC_C), axis=1) < SAC_R) & (np.abs(z) < SAC_Z) & (y < SAC_TOP)
        & pale_ice(tcol) & ~taken
    )
    lab[sac] = "sac"
    piv["sac"] = np.asarray(SAC_ROOT)
    face = (tcol.max(-1) < HEAD_DARK) | visor_texels(tcol)
    head = (x > HEAD_X) & (np.abs(z) < HEAD_Z) & (y > MOUTH_Y) & (y < HEAD_TOP) & ~taken & ~sac & face
    lab[head] = "head"
    piv["head"] = np.asarray(HINGE)
    free = ~taken & ~sac & ~head
    lab[free & (y > SHELL_Y)] = "shell"
    piv["shell"] = np.asarray(SHELL_PIVOT)
    # Smooth the cuts: the shell's rim, the sac's edge, the face plate's edge.
    lab = smooth(lab, nb, (y > SHELL_Y - 0.04) & (y < SHELL_Y + 0.05) & ~taken, "shell", "body")
    lab = smooth(lab, nb, (np.linalg.norm(c - np.asarray(SAC_C), axis=1) < SAC_R + 0.03) & ~taken, "sac", "body", 2)
    lab = smooth(lab, nb, (x > HEAD_X - 0.03) & (y > MOUTH_Y - 0.02) & ~taken, "head", "shell", 2)
    return lab, piv


def cut_caps(part_tris, pinv, W, glow_pairs, uncapped):
    """Caps over each part's cut edges: {part: [(surface, triangles (k, 3, 3) metres)]}. A cut edge is an edge
    (welded by position) of one triangle of part A and one of part B; A's cap is a fan from those edges to their mean,
    each triangle wound to face B (from A's triangles at the cut toward B's): glow on the pairs in glow_pairs, else
    base. Parts in `uncapped` get none (the shell: its underside is never seen)."""
    owner = {}
    for pn, T in part_tris.items():
        for t, tri in enumerate(pinv[T]):
            for k in range(3):
                e = (min(tri[k], tri[(k + 1) % 3]), max(tri[k], tri[(k + 1) % 3]))
                owner.setdefault(e, []).append((pn, t))
    pos_of = {}
    for pn, T in part_tris.items():
        for tri_w, tri_p in zip(T, pinv[T]):
            for k in range(3):
                pos_of[tri_p[k]] = W[tri_w[k]]
    by_pair = {}
    for e, ps in owner.items():
        if len(ps) == 2 and ps[0][0] != ps[1][0]:
            (a, ta), (b, tb) = ps
            by_pair.setdefault((a, b), []).append((e, ta, tb))
            by_pair.setdefault((b, a), []).append((e, tb, ta))
    caps = {}
    for (a, b), es in by_pair.items():
        if len(es) < 3 or a in uncapped:
            continue
        verts = np.array([pos_of[v] for e, _, _ in es for v in e])
        centre = verts.mean(0)
        ca = np.mean([W[part_tris[a][t]].mean(0) for _, t, _ in es], 0)
        cb = np.mean([W[part_tris[b][t]].mean(0) for _, _, t in es], 0)
        toward = cb - ca
        tris = []
        for e, _, _ in es:
            pa, pb = pos_of[e[0]], pos_of[e[1]]
            if np.cross(pb - pa, centre - pa) @ toward < 0:
                pa, pb = pb, pa
            tris.append([pa, pb, centre])
        surf = 2 if (a, b) in glow_pairs else 0
        caps.setdefault(a, []).append((surf, np.array(tris)))
    return caps


def load():
    """The raw mesh in the game frame (raw units), welded: (welded positions, their UVs, triangles, the position-weld
    index, the colour map, the raw positions' bounds, the raw triangle count)."""
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)  # a quarter turn about +Y: the raw +Z front to +X
    lo, hi = P0.min(0), P0.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    raw = P0 - centre
    # Welded by position and UV: the seams stay apart, every vertex keeps its UV.
    eps = (hi - lo).max() * 2e-5
    key = np.concatenate([np.round(raw / eps), np.round(UV * 1e6)], 1).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    Wr = raw[first]
    UVw = UV[first]
    J = inv[I0]
    J = J[(J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])]
    # The same vertices welded by position alone (the normals smooth across the seams; the cuts are found on it).
    pkey = np.round(Wr / eps).astype(np.int64)
    _, pinv = np.unique(pkey, axis=0, return_inverse=True)
    return Wr, UVw, J, pinv.ravel(), colour, (lo, hi), len(I0)


def main():
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = load()
    s = HEIGHT_M / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, neighbours(pinv[J]))
    glow = np.zeros(len(J), int)
    glow[part == "sac"] = 2
    glow[(part == "head") & visor_texels(tcol)] = 2
    W = Wr * s  # metres
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    # Normals over the whole position-welded mesh, every part at once (no crease where two parts meet, nor at the UV
    # seams); corners flat per face after.
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = cut_caps(per_part, pinv, W, {("body", "sac")}, {"shell"})
    # A charcoal texel for the dark caps (the darkest body triangle's centre).
    body_m = part == "body"
    lum = tcol @ np.array([0.299, 0.587, 0.114])
    dark_uv = UVw[J[body_m][np.argmin(np.where(lum[body_m] > 0.03, lum[body_m], 9.0))]].mean(0)
    nodes = []
    report = {}
    cap_report = {}
    at = 0
    role_tris, other_tris = [], []
    for pn in order:
        T = per_part[pn]
        cn = cn_all[at : at + len(T)]
        at += len(T)
        K = glow[part == pn].copy()
        rest = K != 2
        # The royal-blue swirls are role where they cover a real share of a triangle (role_map); the pale ice is base.
        K[rest] = (role_map.texel_share(colour, UVw, T[rest], role_texels) >= role_map.ROLE_SHARE).astype(int)
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
    # The colour map: the role triangles' texels greyscale (the game multiplies them by the role colour), halved.
    img = role_map.tinted_map(colour, UVw, np.concatenate(role_tris), np.concatenate(other_tris), role_texels)
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, "frost_spitter", nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    print(json.dumps({
        "id": "frost_spitter", "raw": SRC, "raw_tris": raw_tris, "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
