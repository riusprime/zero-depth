"""Prepares the owner's three walking horde critters (unprocessed_images/models_v0120_b/<id>.glb) for the game:
assets/models/enemies/<id>.glb, cut into the parts CritterModel animates.

Each raw file is a Tripo export: one closed textured mesh (about 4.7k triangles, a 2048 px colour map), about one
unit across, no rig, Y up, its front on +Z:
- the Dust Mite: a low crimson dome on a charcoal underside, a face plate with a crimson gem eye, eight short legs
  (four a side) splayed out round it;
- the Ember Flea: a tall crimson hump leaning back with glowing ember cracks, a face plate low at the front, two big
  back legs folded high (thigh up and back to the knee, the shin down to the foot) and four short front legs;
- the Ice Crab: a wide flat crimson shell with pale ice facets at its rim on a charcoal slab, two claws held forward,
  eight short flat legs (four a side) held out sideways.
They come by the dozen in a surge, so each is simplified to about BUDGET_TRIS (the cut caps on top). The raw files stay
untouched. This script (hatchling_swarmer_prep.py's path: its reader, colour tests and islands; the Kiln Beetle's
colour sampling and cut caps; mi_prep's simplifier, normals and glb writer):
1. turns it to the game's frame (+X the front), centres it on x/z with its feet on y = 0 and scales it evenly to its
   HEIGHT_M (no taller than CritterBodies.HEIGHTS and about as wide as its collision circle);
2. cuts it into the parts that move: each leg (and the crab's claws, the flea's front legs) is a connected run of
   non-crimson triangles outside the body's footprint (CUT), named by its side and its place front to back, its pivot
   where it leaves the body; the flea's back legs are the triangles near their bone lines (BACK_LEGS), the thigh
   (hip to knee) and the shin (knee to foot). The rest is the body (the rig's root). Every part node's origin is its
   pivot;
3. simplifies each part's surfaces to its share of BUDGET_TRIS (borders locked, so the cuts stay matched);
4. caps the cuts (the hull is hollow): a charcoal fan over each part's cut edges;
5. sorts each triangle into a surface by the colour map under it: `glow` (the eye; the flea's ember cracks), `role`
   (the crimson shell: its texels greyscale in the map, the game tints them) and `base`;
6. keeps the owner's UV layout and colour map, halved to TEX_PX, and writes assets/models/enemies/<id>.glb.
It prints one JSON line per model: the raw triangles, the triangles after (per part: total, glow, role, the pivot), the
caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).
`--debug` instead draws each triangle in its part's colour from the top, the side and the front into build/prep/.

Run from the repo root:  python scripts/assets/critter_prep.py [dust_mite|ember_flea|ice_crab] [--debug]
(GODOT=<godot executable> when the Python meshoptimizer package is missing: mi_prep's simplifier then runs Godot's.)
"""

import hashlib
import io
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hatchling_swarmer_prep as hs  # noqa: E402  (the reader, the colour tests, islands; it stubs xatlas)

beetle = hs.beetle
mi_prep = hs.mi_prep

TEX_PX = 1024
## The triangles each model is simplified to (the cut caps come on top).
BUDGET_TRIS = 1300
## A run of leg triangles smaller than this is a speck of the body (it stays on it).
MIN_PART_TRIS = 10

## Per model (raw units, the game frame: +X front, +Z its right):
## - "height": the height in metres it is scaled to;
## - "cut": the leg runs: (y below, |z| over, x over, x under, the footprint ellipse's centre x, its half axes x and z):
##   a non-crimson triangle under that height, past that |z| and between those x, outside the ellipse, is a limb's;
## - "claws": the crab's claws, the same test ahead of the body (they are claw_r / claw_l);
## - "back_legs": the flea's two big legs, per side the hip, the knee and the foot (the thigh and the shin);
## - "eye": the eye's middle and reach (its bright red is the glow); "cracks": the flea's ember cracks glow too.
MODELS = {
    "dust_mite": {
        "height": 0.2,
        "cut": (0.2, 0.12, -9.0, 9.0, 0.0, 0.43, 0.31),
        "names": ("leg", 4),
        "eye": ((0.42, 0.13, 0.0), 0.08),
    },
    "ember_flea": {
        "height": 0.3,
        "cut": (0.26, 0.12, 0.1, 9.0, 0.24, 0.17, 0.17),
        "names": ("fleg", 2),
        "back_legs": {
            "r": ((0.02, 0.36, 0.27), (-0.34, 0.66, 0.29), (-0.27, 0.0, 0.29)),
            "l": ((0.02, 0.36, -0.27), (-0.34, 0.66, -0.29), (-0.27, 0.0, -0.29)),
        },
        "back_reach": 0.15,
        "eye": ((0.42, 0.12, 0.0), 0.08),
        "cracks": True,
    },
    "ice_crab": {
        "height": 0.15,
        "cut": (0.1, 0.12, -9.0, 0.22, -0.08, 0.32, 0.4),
        "names": ("leg", 4),
        "claws": (0.2, 0.05, 0.2, 9.0),
        "eye": ((0.27, 0.15, 0.0), 0.06),
    },
}

PART_COLOURS = {"body": (90, 90, 90), "claw_r": (250, 200, 60), "claw_l": (250, 140, 20)}
for _s, _side in enumerate("rl"):
    for _k in range(4):
        PART_COLOURS["leg_%s%d" % (_side, _k + 1)] = (40 + 50 * _k, 120 + 80 * _s, 220 - 40 * _k)
    for _k in range(2):
        PART_COLOURS["fleg_%s%d" % (_side, _k + 1)] = (60 + 90 * _k, 200, 80 + 120 * _s)
    PART_COLOURS["thigh_" + _side] = (200, 60 + 120 * _s, 220)
    PART_COLOURS["shin_" + _side] = (60, 60 + 120 * _s, 240)


def crack_texels(rgb):
    """The flea's ember cracks: bright orange (red full, green some, blue low)."""
    return (rgb[..., 0] >= 0.8) & (rgb[..., 1] >= 0.22) & (rgb[..., 1] <= 0.7) & (rgb[..., 2] <= 0.35)


def eye_texels(rgb):
    """The gem eye: bright, saturated red or pink-red."""
    return (rgb[..., 0] >= 0.75) & (rgb[..., 1] <= 0.35) & (rgb[..., 2] <= 0.55)


def runs(mask, nb):
    """The connected runs (edge neighbours) of the triangles in `mask`: a list of index arrays."""
    seen = np.zeros(len(mask), bool)
    out = []
    for t0 in np.where(mask)[0]:
        if seen[t0]:
            continue
        stack = [t0]
        seen[t0] = True
        run = []
        while stack:
            t = stack.pop()
            run.append(t)
            for k in nb[t]:
                if mask[k] and not seen[k]:
                    seen[k] = True
                    stack.append(k)
        out.append(np.array(run))
    return out


def root_of(c, run, cx, ax, az):
    """A limb's pivot: the middle of its triangles nearest the body (the ellipse's measure), at their height."""
    r = ((c[run, 0] - cx) / ax) ** 2 + (c[run, 2] / az) ** 2
    near = run[np.argsort(r)[: max(3, len(run) // 8)]]
    return c[near].mean(0)


def name_limbs(lab, piv, c, found, prefix, per_side):
    """Names the runs `found` ([run, pivot]) by side (+z right, -z left) and their place front to back."""
    for side, sign in (("r", 1.0), ("l", -1.0)):
        mine = [f for f in found if f[1][2] * sign > 0.0]
        mine.sort(key=lambda f: -len(f[0]))
        mine = mine[:per_side]
        mine.sort(key=lambda f: -f[1][0])
        for k, (run, p) in enumerate(mine):
            pn = "%s_%s%d" % (prefix, side, k + 1)
            lab[run] = pn
            piv[pn] = p


def parts_of(cfg, c, tcol, pinv_J):
    """Per triangle centre (raw units): its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    piv = {"body": np.zeros(3)}
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    nb = beetle.neighbours(pinv_J)
    red = hs.role_texels(tcol) & ~eye_texels(tcol)
    taken = np.zeros(n, bool)
    if "back_legs" in cfg:
        reach = cfg["back_reach"]
        for side, (hip, knee, foot) in cfg["back_legs"].items():
            hip, knee, foot = np.asarray(hip), np.asarray(knee), np.asarray(foot)
            d0 = beetle.seg_dist(c, hip, knee)
            d1 = beetle.seg_dist(c, knee, foot)
            sign = 1.0 if side == "r" else -1.0
            m = ~red & (z * sign > 0.17) & (x < 0.08) & (np.minimum(d0, d1) < reach)
            lab[m & (d0 <= d1)] = "thigh_" + side
            lab[m & (d1 < d0)] = "shin_" + side
            taken |= m
            piv["thigh_" + side] = hip
            piv["shin_" + side] = knee
    if "claws" in cfg:
        y_top, z_min, x_min, x_max = cfg["claws"]
        m = ~red & ~eye_texels(tcol) & (y < y_top) & (np.abs(z) > z_min) & (x > x_min) & (x < x_max) & ~taken
        found = [r for r in runs(m, nb) if len(r) >= MIN_PART_TRIS]
        found.sort(key=lambda r: -len(r))
        for run in found[:2]:
            near = run[np.argsort(c[run, 0])[: max(3, len(run) // 8)]]
            p = c[near].mean(0)
            pn = "claw_r" if p[2] > 0.0 else "claw_l"
            lab[run] = pn
            piv[pn] = p
            taken[run] = True
    y_top, z_min, x_min, x_max, cx, ax, az = cfg["cut"]
    outside = ((x - cx) / ax) ** 2 + (z / az) ** 2 > 1.0
    m = ~red & (y < y_top) & (np.abs(z) > z_min) & (x > x_min) & (x < x_max) & outside & ~taken
    found = [[r, root_of(c, r, cx, ax, az)] for r in runs(m, nb) if len(r) >= MIN_PART_TRIS]
    prefix, per_side = cfg["names"]
    name_limbs(lab, piv, c, found, prefix, per_side)
    lab = hs.islands(lab, pinv_J)
    return lab, piv


def surfaces_of(cfg, part, c, tcol):
    """Per triangle: 2 glow (the eye; the flea's cracks), 1 role (the crimson shell), 0 base."""
    k = np.zeros(len(part), int)
    k[hs.role_texels(tcol) & ~eye_texels(tcol)] = 1
    e_at, e_r = cfg["eye"]
    k[eye_texels(tcol) & (np.linalg.norm(c - np.asarray(e_at), axis=1) < e_r)] = 2
    if cfg.get("cracks"):
        k[crack_texels(tcol) & (part == "body")] = 2
    k[(part != "body") & (k == 2)] = 0
    return k


def debug(rid):
    from PIL import ImageDraw

    cfg = MODELS[rid]
    Wr, UVw, J, pinv, colour, _, _ = hs.load(rid)
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, piv = parts_of(cfg, cen, tcol, pinv[J])
    surf = surfaces_of(cfg, part, cen, tcol)
    size = 600
    sheet = Image.new("RGB", (size * 4, size), "white")
    views = ((0, 2, 1, 1.0), (0, 1, 2, 1.0), (2, 1, 0, 1.0), (0, 2, 1, -1.0))  # top, side, front, bottom
    for k, (a0, a1, depth, sign) in enumerate(views):
        im = Image.new("RGB", (size, size), "white")
        d = ImageDraw.Draw(im)
        order = np.argsort(sign * cen[:, depth])
        for t in order:
            v = Wr[J[t]]
            yy = v[:, a1] if a1 != 1 else 0.45 - v[:, 1]
            pts = [(size / 2 + v[q, a0] * size * 0.8, size / 2 + yy[q] * size * 0.8) for q in range(3)]
            fill = PART_COLOURS.get(part[t], (0, 0, 0))
            if surf[t] == 2:
                fill = (255, 0, 255)
            elif surf[t] == 1 and part[t] == "body":
                fill = (170, 60, 70)
            d.polygon(pts, fill=fill, outline=(0, 0, 0))
        for pn, p in piv.items():
            yy = p[a1] if a1 != 1 else 0.45 - p[1]
            q = (size / 2 + p[a0] * size * 0.8, size / 2 + yy * size * 0.8)
            d.ellipse([q[0] - 4, q[1] - 4, q[0] + 4, q[1] + 4], fill=(255, 255, 0), outline=(0, 0, 0))
        sheet.paste(im, (k * size, 0))
    os.makedirs("build/prep", exist_ok=True)
    sheet.save("build/prep/%s_parts.png" % rid)
    print(json.dumps({p: int((part == p).sum()) for p in sorted(set(part))}), "glow", int((surf == 2).sum()))


def prepare(rid):
    cfg = MODELS[rid]
    dst = "assets/models/enemies/%s.glb" % rid
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = hs.load(rid)
    s = cfg["height"] / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cfg, cen, tcol, pinv[J])
    surf = surfaces_of(cfg, part, cen, tcol)
    W = Wr * s  # metres
    groups = sorted({(p, k) for p, k in zip(part, surf)})
    total = len(J)
    scale = 1.0
    for _attempt in range(3):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (surf == g[1])
            share = max(int(round(BUDGET_TRIS * scale * m.sum() / total)), 8)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=True)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= BUDGET_TRIS * 1.03:
            break
        scale *= BUDGET_TRIS / tris_after * 0.97
    order = [pn for pn in sorted(pivots) if any(g[0] == pn and len(simplified[g]) for g in groups)]
    per_part = {pn: np.concatenate([simplified[g] for g in groups if g[0] == pn]) for pn in order}
    per_surf = {pn: np.concatenate([np.full(len(simplified[g]), g[1]) for g in groups if g[0] == pn]) for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = beetle.cut_caps(per_part, pinv, W, set(), set())
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
            for csurf, tris in caps.get(pn, []):
                if csurf != k:
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
        report[pn] = [len(T), int((K == 2).sum()), int((K == 1).sum()), [round(float(v), 4) for v in pivot]]
    # The colour map: the crimson plates' texels greyscale (the game multiplies them by the role colour), halved.
    img = colour.copy()
    role_px = hs.role_texels(img) & ~eye_texels(img)
    if cfg.get("cracks"):
        role_px &= ~crack_texels(img)
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
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    mi_prep.write_glb(dst, rid, nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    tris = int(sum(len(v) for v in per_part.values()))
    print(json.dumps({
        "id": rid, "raw": "unprocessed_images/models_v0120_b/%s.glb" % rid, "raw_tris": raw_tris,
        "tris": tris, "caps": sum(cap_report.values()), "with_caps": tris + sum(cap_report.values()),
        "simplifier": mi_prep.BACKEND, "tex": TEX_PX, "size": [round(float(v), 3) for v in ext], "path": dst,
        "bytes": os.path.getsize(dst), "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
        "parts": report,
    }))


def main():
    ids = [a for a in sys.argv[1:] if not a.startswith("--")] or list(MODELS)
    for rid in ids:
        if "--debug" in sys.argv:
            debug(rid)
        else:
            prepare(rid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
