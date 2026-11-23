"""Prepares the owner's Gravity Node (unprocessed_images/models_v0120/gravity_node.glb) for the game:
assets/models/enemies/gravity_node.glb, cut into the parts GravityNodeAvatar animates.

The raw file is a Tripo export: one closed textured mesh (4,736 triangles, a 2048 px colour map), about one unit
across, no rig, Y up, its front (the shield-shaped face plate and its gem) on +Z. A dark charcoal core between two
ridged shell halves (violet in the owner's map: their texels are made greyscale here, so the game tints them in the
kind's role colour), the face plate on the core's front over the gap, and three thin grey rings with bone studs
circling it at different tilts: two nearly level ones a little apart (fused along one side) and an upright one. The raw file stays untouched.
This script (the Wire Weaver's path, wire_weaver_prep.py, reusing its welding, stray pieces and cut caps, the Kiln
Beetle's colour sampling and mi_prep's reader, normals and glb writer):
1. turns it a quarter about +Y so its front is +X (the game's), centres it on x/z with its bottom on y = 0 and scales
   it evenly to HEIGHT_M (the request row: about a 0.9 m orb; the rings make it a little taller);
2. cuts it into the parts that move (the mesh is one closed hull, so the cuts are made by place and colour): each ring
   with its studs (the triangles near its circle, RINGS: fitted to the raw mesh, that are not violet shell), the upper
   and lower shell halves (the violet plates and the trims round them, above and below the gap), the core (the
   charcoal sphere inside, within CORE_R of its middle) and the body (the face plate with the gem, the rig's root); a
   stray piece of any part goes to the part it touches. Each part node's origin is its pivot: a ring's centre, a
   half's hinge at the back of the gap, the core's middle;
3. caps the cuts (a part moving would show through the hollow hull): a charcoal fan over each part's cut edges facing
   the part across the cut, one per closed run of cut edges;
4. sorts each triangle into a surface by the colour map under it: `glow` (the gem: the bright violet on the face
   plate), `role` (the shell plates' violet: greyscale in the map) and `base` (the charcoal, the grey rings, the bone
   studs);
5. keeps every triangle (the raw count is under the enemy budget: no simplifier) and the owner's own UV layout and
   colour map, halved to TEX_PX;
6. writes assets/models/enemies/gravity_node.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and file size, the triangles after (per part: total, glow, role, the
pivot), the caps, the size in metres, each ring's axis (its normal in the game frame: pasted into GravityNodeAvatar's
RING_AXES by hand), the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).
`--debug=<png>` instead draws each triangle in its part's colour from the top, the side and the front.

Run from the repo root:  python scripts/assets/gravity_node_prep.py
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
import o17_prep_kiln_beetle as beetle  # noqa: E402  (the colour sampling)
import wire_weaver_prep as weaver  # noqa: E402  (the welding and the cut caps)

mi_prep = mi2_prep.mi_prep

SRC = "unprocessed_images/models_v0120/gravity_node.glb"
DST = "assets/models/enemies/gravity_node.glb"
HEIGHT_M = 0.95
TEX_PX = 1024

## The orb's middle (raw units, the game frame, after centring: x/z centred, the bottom at y = 0).
MIDDLE = (0.0, 0.4925, 0.0)
## The rings' circles (raw units, the game frame): each one's normal, centre and radius, fitted to the raw mesh's grey
## triangles beyond the core (three circles at once: each triangle to its nearest, each circle refitted, until they
## settle), and the part each one goes to. The two nearly level rings (an outer and an inner one, tilted a little
## apart) are fused along one side in the owner's mesh, so they stay one part (ring_a, turning about the outer one's
## axis: the inner one rides it with a slight wobble); the upright one across the front is ring_b.
RINGS = {
    "level_outer": ((0.2531, 0.9673, -0.0135), (-0.0063, 0.4702, -0.0074), 0.4271, "ring_a"),
    "level_inner": ((0.2946, 0.9465, -0.1313), (-0.0283, 0.4786, 0.0262), 0.3885, "ring_a"),
    "upright": ((-0.921, 0.0707, 0.383), (-0.0121, 0.4931, 0.0315), 0.4329, "ring_b"),
}
## Each ring part's turning axis and pivot: its circle's normal and centre.
RING_AXES = {"ring_a": "level_outer", "ring_b": "upright"}
## A triangle within RING_REACH of a ring's circle (its tube and its studs) is that ring's, unless violet (the shell)
## or as dark as the core (RING_LUM: the rings are mid grey, the core and the gap's trims charcoal).
RING_LUM = 0.09
RING_REACH = 0.065
## The core: the charcoal sphere within CORE_R of the middle.
CORE_R = 0.3
## The gap between the halves (raw units from the middle's height): a half is what lies above GAP[1] (upper) or below
## GAP[0] (lower) outside the core.
GAP = (-0.06, 0.03)
## The face plate (the body): its charcoal ahead of FACE_X, within FACE_Z of the middle across, within FACE_Y of its
## height; and the gem on it: the bright violet within GEM_R of GEM.
FACE_X = 0.28
FACE_Z = 0.17
FACE_Y = (-0.28, 0.25)
GEM = (0.39, 0.525, 0.0)
GEM_R = 0.075
## The halves' hinges: the back of the gap (raw units, the game frame).
HINGE_U = (-0.36, 0.4925 + GAP[1], 0.0)
HINGE_L = (-0.36, 0.4925 + GAP[0], 0.0)
## The shell's violet (the role plates) and the gem's brighter violet.
ROLE_SAT = 0.3


def sat_of(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    return (mx - mn) / np.maximum(mx, 1e-6)


def violet(rgb):
    """The shell's violet plates and the gem: saturated, blue over green."""
    return (sat_of(rgb) >= ROLE_SAT) & (rgb[..., 2] > rgb[..., 1] + 0.05) & (rgb.max(-1) >= 0.12)


def gem_texels(rgb):
    return violet(rgb) & (rgb.max(-1) >= 0.45)


def gem(c, tcol):
    """The gem's triangles: bright violet near GEM."""
    return gem_texels(tcol) & (np.linalg.norm(c - np.asarray(GEM), axis=1) < GEM_R)


def ring_dist(c, ring):
    n, ctr, r = (np.asarray(v, float) for v in ring[:3])
    n = n / np.linalg.norm(n)
    q = c - ctr
    h = q @ n
    rr = np.linalg.norm(q - np.outer(h, n), axis=1)
    return np.hypot(rr - r, h)


def parts_of(c, tcol, pinv_J=None):
    """Per triangle centre (raw units, the game frame): its part; and each part's pivot (raw units). With `pinv_J`
    (each triangle's position-welded corners) each part's pieces apart from its largest go to the part they touch."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    mid = np.asarray(MIDDLE)
    q = c - mid
    rad = np.linalg.norm(q, axis=1)
    vio = violet(tcol)
    piv = {"body": mid.copy(), "core": mid.copy(), "shell_u": np.asarray(HINGE_U), "shell_l": np.asarray(HINGE_L)}
    best = np.full(n, np.inf)
    lit = tcol @ np.array([0.299, 0.587, 0.114]) >= RING_LUM
    for ring in RINGS.values():
        d = ring_dist(c, ring)
        m = (d < RING_REACH) & (d < best) & ~vio & lit
        lab[m] = ring[3]
        best = np.where(m, d, best)
    for name, circle in RING_AXES.items():
        piv[name] = np.asarray(RINGS[circle][1], float)
    free = lab == "body"
    face = (q[:, 0] > FACE_X) & (np.abs(q[:, 2]) < FACE_Z) & (q[:, 1] > FACE_Y[0]) & (q[:, 1] < FACE_Y[1]) & ~vio
    face |= gem(c, tcol)
    core = free & ~face & (rad < CORE_R) & ~vio
    lab[core] = "core"
    shell = free & ~face & ~core
    lab[shell & (q[:, 1] >= GAP[1])] = "shell_u"
    lab[shell & (q[:, 1] <= GAP[0])] = "shell_l"
    lab[shell & (q[:, 1] > GAP[0]) & (q[:, 1] < GAP[1])] = "core"
    if pinv_J is not None:
        lab = strays(lab, c, pinv_J)
    return lab, piv


def strays(lab, c, pinv_J, passes=3):
    """Each part's pieces apart from its largest (welded by position) go to the part of the nearest triangle outside
    that part."""
    for _ in range(passes):
        moved = 0
        for pn in sorted(set(lab)):
            idx = np.where(lab == pn)[0]
            parent = {}

            def find(v):
                while parent.setdefault(v, v) != v:
                    parent[v] = parent[parent[v]]
                    v = parent[v]
                return v

            for t in idx:
                a, b, d = pinv_J[t]
                parent[find(a)] = find(b)
                parent[find(b)] = find(d)
            root = np.array([find(pinv_J[t][0]) for t in idx])
            keys, counts = np.unique(root, return_counts=True)
            if len(keys) < 2:
                continue
            main_k = keys[np.argmax(counts)]
            others = np.where(lab != pn)[0]
            for k in keys:
                if k == main_k:
                    continue
                piece = idx[root == k]
                d = np.linalg.norm(c[others][None, :, :] - c[piece][:, None, :], axis=2)
                lab[piece] = lab[others[np.argmin(d.min(0))]]
                moved += len(piece)
        if moved == 0:
            break
    return lab


def load():
    """The raw mesh in the game frame (a quarter turn about +Y: the raw +Z front to +X), centred on x/z with its bottom
    on y = 0: (positions, UVs, triangles, the colour map, the scale to metres, the bounds)."""
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)
    lo, hi = P0.min(0), P0.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    return P0 - centre, UV, I0, colour, HEIGHT_M / (hi[1] - lo[1]), lo, hi


PART_COLOURS = {
    "body": (255, 0, 255), "core": (60, 60, 60), "shell_u": (255, 200, 0), "shell_l": (200, 120, 0),
    "ring_a": (0, 200, 255), "ring_b": (255, 40, 40),
}


def debug(out):
    from PIL import ImageDraw

    raw, UV, I0, colour, _s, lo, hi = load()
    Wr, UVw, J, pinv = weaver.welded(raw, UV, I0, lo, hi)
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, _ = parts_of(cen, tcol, pinv[J])
    gem_m = (part == "body") & gem(cen, tcol)
    size = 600
    sheet = Image.new("RGB", (size * 4, size), "white")
    # top (x, z; looking down), side (x, y; from +Z), front (z, y; from +X), back (from -X)
    views = ((0, 2, 1, 1.0, 1.0), (0, 1, 2, 1.0, 1.0), (2, 1, 0, 1.0, -1.0), (2, 1, 0, -1.0, 1.0))
    for k, (a0, a1, depth, sign, flip) in enumerate(views):
        im = Image.new("RGB", (size, size), "white")
        d = ImageDraw.Draw(im)
        order = np.argsort(sign * cen[:, depth])
        for t in order:
            v = Wr[J[t]]
            yy = v[:, a1] if a1 != 1 else 0.5 - v[:, 1]
            pts = [(size / 2 + flip * v[q, a0] * size * 0.9, size / 2 + yy[q] * size * 0.9) for q in range(3)]
            colr = (255, 255, 255) if gem_m[t] else PART_COLOURS.get(part[t], (0, 0, 0))
            d.polygon(pts, fill=colr, outline=(0, 0, 0))
        sheet.paste(im, (k * size, 0))
    sheet.save(out)
    print(json.dumps({p: int((part == p).sum()) for p in PART_COLOURS} | {"gem": int(gem_m.sum())}))


def main():
    for a in sys.argv[1:]:
        if a.startswith("--debug="):
            debug(a[len("--debug="):])
            return 0
    raw, UV, I0, colour, s, lo, hi = load()
    Wr, UVw, J, pinv = weaver.welded(raw, UV, I0, lo, hi)
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cen, tcol, pinv[J])
    W = Wr * s  # metres
    surf = np.where((part == "body") & gem(cen, tcol), 2, violet(tcol).astype(int))
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
    caps = weaver.cut_caps(per_part, pinv, W)
    # A charcoal texel for the caps (the darkest core triangle's centre).
    core_m = part == "core"
    lum = tcol @ np.array([0.299, 0.587, 0.114])
    dark_uv = UVw[J[core_m][np.argmin(np.where(lum[core_m] > 0.03, lum[core_m], 9.0))]].mean(0)
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
    # The colour map: every violet texel greyscale, the plates' bright highlights too (the game multiplies them by the
    # role colour; the gem's surface is the glow's, which draws no map), halved.
    img = colour.copy()
    role_px = violet(img)
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
    mi_prep.write_glb(DST, "gravity_node", nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    axes = {}
    for name, circle in RING_AXES.items():
        nrm, ctr, r, _part = RINGS[circle]
        nv = np.asarray(nrm) / np.linalg.norm(nrm)
        axes[name] = [[round(float(v), 4) for v in nv], round(float(r * s), 4)]
    print(json.dumps({
        "id": "gravity_node", "raw": SRC, "raw_tris": len(I0), "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(per_part[pn]) for pn in order)), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in ext], "scale": round(float(s), 5), "path": DST,
        "bytes": os.path.getsize(DST), "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report, "rings": axes,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
