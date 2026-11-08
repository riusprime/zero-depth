"""v0.11.0 Step O17e: prepares the owner's Kiln Beetle (unprocessed_images/models_v0110/kiln_beetle.glb) for the game:
assets/models/enemies/kiln_beetle.glb, cut into the parts KilnBeetleAvatar animates.

The raw file is a Tripo export: one closed textured mesh (9,518 triangles, a 2048 px colour map), about one unit
across, no rig, Y up, its front (the shield-shaped face plate and its gem visor) on +Z, standing on EIGHT short legs
(four a side: the request asked for six; the model has eight, and all eight walk). The raw file stays untouched. This
script, reusing mi_prep's reader, simplifier (Godot's on Windows: GODOT=<godot>), normals and glb writer (through
mi2_prep, which imports it):
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres it on x/z with its feet on y = 0 and
   scales it evenly to HEIGHT_M (the request row: about 0.7 m; 1.07 m long);
2. cuts it into the parts that move (the mesh is one closed hull, so the cuts are made by place): the shell (the
   yellow dome with its vents, above the rim), the body (the charcoal underside: the rig's root), the head (the face
   plate between the front legs) and each leg's upper half (the coxa and the grey femur, from its hip under the rim
   to its knee) and lower half (the bone claw). A leg's triangles are the ones near its bone line (LEGS, fitted to the
   raw mesh 2026-11-08); every part node's origin is its pivot (the hip, the knee, the neck, the shell's rim centre);
3. caps the cuts (the hull is hollow: a part turning would show through it): a fan over each part's cut edges facing
   the part across the cut, on the body under the shell a GLOW cap (the molten kiln belly: when the shell lifts or
   swells, the gap glows), the others charcoal (none on the shell: its underside is never seen). The caps sit inside
   the closed hull, unseen until a part moves;
4. sorts each triangle into a surface by the colour map under it: `glow` (the vents' and the belly's red-orange and
   their hot cores; on the head, the gem visor), `role` (the yellow shell plates: their texels turned greyscale in the
   map so the game tints them in the kind's role colour) and `base` (the charcoal, the grey legs, the bone claws);
5. simplifies each part (and in it each surface apart) to its share of BUDGET_TRIS with Godot's simplifier, borders
   locked, keeping the owner's own UV layout (welded by position and UV: the seams are locked borders) and the owner's
   colour map, halved to TEX_PX (no new atlas: xatlas has no Windows wheel for this Python; it is stubbed);
6. writes assets/models/enemies/kiln_beetle.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and file size, the triangles after (per part: total, glow, role, the
pivot), the caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json
by hand).

Run from the repo root:  GODOT=<godot executable> python -I scripts/assets/o17_prep_kiln_beetle.py
Needs numpy, Pillow, scipy (mi_prep's imports; xatlas is stubbed when missing: this script never calls it).
"""

import hashlib
import io
import json
import math
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

SRC = "unprocessed_images/models_v0110/kiln_beetle.glb"
DST = "assets/models/enemies/kiln_beetle.glb"
HEIGHT_M = 0.70
BUDGET_TRIS = 5200
TEX_PX = 1024

## Each leg (raw units, the game frame: +X front, +Z the beetle's right): its direction (degrees from +X toward +Z),
## and along it [r, y] of the hip (under the shell's rim), the knee (where the grey femur meets the bone claw) and the
## claw's tip. r: right 1..4 front to rear, l: left.
LEGS = {
    "r1": (24.7, (0.31, 0.22), (0.455, 0.115), (0.535, 0.01)),
    "r2": (64.5, (0.30, 0.23), (0.445, 0.105), (0.495, 0.01)),
    "r3": (113.1, (0.31, 0.24), (0.48, 0.095), (0.53, 0.005)),
    "r4": (150.1, (0.34, 0.24), (0.505, 0.115), (0.555, 0.02)),
    "l1": (-25.1, (0.31, 0.22), (0.455, 0.115), (0.535, 0.01)),
    "l2": (-71.3, (0.30, 0.23), (0.445, 0.105), (0.495, 0.01)),
    "l3": (-113.0, (0.31, 0.24), (0.48, 0.095), (0.53, 0.005)),
    "l4": (-149.5, (0.34, 0.24), (0.505, 0.115), (0.555, 0.02)),
}
## The reach (raw units) round the femur's and the claw's line that is still that leg; above LEG_TOP it is the shell.
REACH = (0.078, 0.06)
LEG_TOP = 0.30
## The head: ahead of HEAD_X, within HEAD_Z of the middle, below HEAD_TOP (the face plate under the shell's front);
## its pivot (the neck).
HEAD_X = 0.295
HEAD_Z = 0.135
HEAD_TOP = 0.335
NECK = (0.26, 0.19, 0.0)
## The shell: above SHELL_Y, or shell-coloured (yellow plate or glowing vent) above SHELL_MIN; its pivot (the rim's
## centre, where it lifts and swells from).
SHELL_Y = 0.31
SHELL_MIN = 0.165
SHELL_PIVOT = (-0.02, 0.25, 0.0)
## The plates' saturation floor (the yellow shell's are over 0.8; the bone claws' about 0.3).
ROLE_SAT = 0.55


def glow_texels(rgb):
    """The vents' and the belly's red-orange and their hot near-white cores (the shell's yellow has green over half
    its red and no blue)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    ember = (r >= 0.55) & (g <= 0.5 * r) & (b <= 0.25 * r)
    core = (r >= 0.93) & (g >= 0.72) & (b >= 0.3)
    return ember | core


def role_texels(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return (sat >= ROLE_SAT) & (mx >= 0.3) & ~glow_texels(rgb)


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


def leg_points(leg):
    ang, hip, knee, tip = LEGS[leg]
    u = np.array([math.cos(math.radians(ang)), 0.0, math.sin(math.radians(ang))])
    return [u * q[0] + np.array([0.0, q[1], 0.0]) for q in (hip, knee, tip)], u


def neighbours(J):
    """Each triangle's edge neighbours (by welded vertex index): a list of arrays."""
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


def parts_of(c, tcol, nb):
    """Per triangle centre (raw units, game frame): its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    shellish = role_texels(tcol) | glow_texels(tcol)
    piv = {"body": np.zeros(3)}
    taken = np.zeros(n, bool)
    best = np.full(n, np.inf)
    for leg in LEGS:
        (hip, knee, tip), u = leg_points(leg)
        d0 = seg_dist(c, hip, knee)
        d1 = seg_dist(c, knee, tip)
        r = c @ u
        side = z > 0 if leg[0] == "r" else z < 0
        beyond = r > hip @ u - 0.015
        near_u = (d0 < REACH[0]) & (d0 <= d1)
        near_l = (d1 < REACH[1]) & (d1 < d0)
        dn = np.minimum(d0, d1)
        m = (near_u | near_l) & side & beyond & (y < LEG_TOP) & ~(shellish & (y > 0.2)) & (dn < best)
        lab[m & near_u] = "leg_%s_u" % leg
        lab[m & near_l] = "leg_%s_l" % leg
        best = np.where(m, dn, best)
        taken |= m
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    head = (x > HEAD_X) & (np.abs(z) < HEAD_Z) & (y < HEAD_TOP) & ~taken & ~(role_texels(tcol) & (y > 0.25))
    lab[head] = "head"
    piv["head"] = np.asarray(NECK)
    free = ~taken & ~head
    shell = free & ((y > SHELL_Y) | (shellish & (y > SHELL_MIN)))
    lab[shell] = "shell"
    # Smooth the shell's rim: a band triangle takes what most of its neighbours are (three passes).
    band = free & (y > SHELL_MIN - 0.03) & (y < SHELL_Y + 0.04)
    for _ in range(3):
        new = lab.copy()
        for t in np.where(band)[0]:
            ns = [lab[k] for k in nb[t] if lab[k] in ("shell", "body")]
            if len(ns) >= 2:
                s = sum(1 for v in ns if v == "shell")
                if s * 2 > len(ns):
                    new[t] = "shell"
                elif s * 2 < len(ns):
                    new[t] = "body"
        lab = new
    piv["shell"] = np.asarray(SHELL_PIVOT)
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


def main():
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)  # a quarter turn about +Y: the raw +Z front to +X
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
    # The same vertices welded by position alone (the normals smooth across the seams; the cuts are found on it).
    pkey = np.round(Wr / eps).astype(np.int64)
    _, pinv = np.unique(pkey, axis=0, return_inverse=True)
    pinv = pinv.ravel()
    cen = Wr[J].mean(1)
    tcol = tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, neighbours(pinv[J]))
    glow = glow_texels(tcol).astype(int) * 2
    glow[(part == "head") & role_texels(tcol)] = 2  # the gem visor's yellow core with its rim
    glow[np.array([p.startswith("leg") for p in part])] = 0  # (no glow on the legs)
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
    order = [pn for pn in sorted(pivots) if any(g[0] == pn and len(simplified[g]) for g in groups)]
    per_part = {pn: np.concatenate([simplified[g] for g in groups if g[0] == pn]) for pn in order}
    # Normals over the whole position-welded mesh, every part at once (no crease where two parts meet, nor at the
    # UV seams); corners flat per face after.
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = cut_caps(per_part, pinv, W, {("body", "shell")}, {"shell"})
    # A charcoal texel for the dark caps (the darkest body triangle's centre).
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
        K = np.concatenate([np.full(len(simplified[g]), g[1]) for g in groups if g[0] == pn])
        rest = K != 2
        K[rest] = role_texels(tri_colour(colour, UVw, T[rest])).astype(int)
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
    # The colour map: the role plates' texels greyscale (the game multiplies them by the role colour), halved.
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
    mi_prep.write_glb(DST, "kiln_beetle", nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    print(json.dumps({
        "id": "kiln_beetle", "raw": SRC, "raw_tris": len(I0), "raw_bytes": os.path.getsize(SRC), "tris": tris_after,
        "caps": cap_report, "budget": BUDGET_TRIS, "tex": TEX_PX, "backend": mi_prep.BACKEND,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
