"""Prepares the owner's five horde critters (unprocessed_images/models_v0120_b/<id>.glb) for the game:
assets/models/enemies/<id>.glb, cut into the parts CritterModel and FlyerModel animate.

Each raw file is a Tripo export: one closed textured mesh (about 4.7k triangles, a 2048 px colour map), about one
unit across, no rig, Y up, its front on +Z:
- the Dust Mite: a low crimson dome on a charcoal underside, a face plate with a crimson gem eye, eight short legs
  (four a side) splayed out round it;
- the Ember Flea: a tall crimson hump leaning back with glowing ember cracks, a face plate low at the front, two big
  back legs folded high (thigh up and back to the knee, the shin down to the foot) and four short front legs;
- the Ice Crab: a wide flat crimson shell with pale ice facets at its rim on a charcoal slab, two claws held forward,
  eight short flat legs (four a side) held out sideways;
- the Cave Bat: a ridged crimson shell on a charcoal body with a shield face plate and a gem eye, two broad grey
  stone wings spread flat (bone claws at their fingers' tips), two tiny feet under;
- the Star Mote: an upright five-pointed crimson star facing forward, a charcoal shield face plate with a gem eye a
  little off its middle, a charcoal core behind and a curved grey tail with a bone tip trailing back and to its left.
They come by the dozen in a surge, so each is simplified to about BUDGET_TRIS (the cut caps on top). The raw files stay
untouched. This script (hatchling_swarmer_prep.py's path: its reader, colour tests and islands; the Kiln Beetle's
colour sampling and cut caps; mi_prep's simplifier, normals and glb writer; role_map's role plates):
1. turns it to the game's frame (+X the front), centres it on x/z with its feet on y = 0 and scales it evenly to its
   HEIGHT_M (no taller than CritterBodies.HEIGHTS and about as wide as its collision circle);
2. cuts it into the parts that move. The walkers: each leg (and the crab's claws, the flea's front legs) is a
   connected run of non-crimson triangles outside the body's footprint (CUT), named by its side and its place front to
   back, its pivot where it leaves the body; the flea's back legs are the triangles near their bone lines (BACK_LEGS),
   the thigh (hip to knee) and the shin (knee to foot). The bat: each wing is the non-crimson run past the body's side,
   cut again at its elbow into the inner wing (wing_r / wing_l, its pivot the shoulder) and the outer wing (wtip_r /
   wtip_l, its pivot the elbow). The mote: the crimson star cut into its five points (pt_1 the top, on round toward
   its right; each a wedge about the star's middle, the pivot it spins about), the tail cut into three segments along
   its length (tail_1 at the core, its pivot the root; tail_2, tail_3 each pivoting where the one before ends). The
   rest is the body (the rig's root). Every part node's origin is its pivot;
3. simplifies each part's surfaces to its share of BUDGET_TRIS (borders locked, so the cuts stay matched);
4. caps the cuts (the hull is hollow): a charcoal fan over each part's cut edges;
5. sorts each triangle into a surface by role_map's rules: `glow` (the eye, found by its place; the flea's ember
   cracks), `role` (the crimson plates: a triangle whose texels are the plate colour for role_map.ROLE_SHARE of them,
   the pale wear touching them off the limbs joined, and a simplified base triangle whose stretched UVs now cover the
   plates joined too) and `base`; the map greys exactly the texels under the role triangles (the game tints them), so
   no base triangle draws a greyed texel white;
6. keeps the owner's UV layout and colour map, halved to TEX_PX, and writes assets/models/enemies/<id>.glb.
It prints one JSON line per model: the raw triangles, the triangles after (per part: total, glow, role, the pivot), the
caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).
`--debug` instead draws each triangle in its part's colour from the top, the side and the front into build/prep/.

Run from the repo root:  python scripts/assets/critter_prep.py [dust_mite|ember_flea|ice_crab|cave_bat|star_mote]
[--debug]  (GODOT=<godot executable> when the Python meshoptimizer package is missing: mi_prep's simplifier then runs
Godot's.)
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
import role_map  # noqa: E402

beetle = hs.beetle
mi_prep = hs.mi_prep

TEX_PX = 1024
## The triangles each model is simplified to (the cut caps come on top).
BUDGET_TRIS = 1300
## A run of leg triangles smaller than this is a speck of the body (it stays on it).
MIN_PART_TRIS = 10
## The parts the plates' pale wear does not grow onto (role_map.grow) and whose simplified base triangles stay base:
## the limbs are grey stone and bone, never a plate.
LIMBS = ("leg", "fleg", "thigh", "shin", "claw", "wing", "wtip", "tail")

## Per model (raw units, the game frame: +X front, +Z its right):
## - "height": the height in metres it is scaled to;
## - "cut": the leg runs: (y below, |z| over, x over, x under, the footprint ellipse's centre x, its half axes x and z):
##   a non-crimson triangle under that height, past that |z| and between those x, outside the ellipse, is a limb's;
## - "claws": the crab's claws, the same test ahead of the body (they are claw_r / claw_l);
## - "back_legs": the flea's two big legs, per side the hip, the knee and the foot (the thigh and the shin);
## - "wings": the bat's (|z| past which a non-crimson triangle is a wing's, |z| past which it is the outer wing's);
## - "star": the mote's star (its middle's y and z, the reach round that middle that is the core behind it, x past
##   which a non-crimson triangle is the face plate, its first point's angle from straight up in degrees);
## - "eye": the eye's middle and reach (its bright red is the glow); "cracks": the flea's ember cracks glow too;
## - "budget": its own triangle budget (the mote's: its five wedges and three tail segments cut through the star's middle
##   bring about 770 cap triangles, so its surfaces take fewer to land near the others' total).
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
    "cave_bat": {
        "height": 0.2,
        "wings": (0.14, 0.3),
        "eye": ((0.2, 0.13, 0.0), 0.05),
    },
    "star_mote": {
        "height": 0.25,
        "star": (0.43, 0.04, 0.17, 0.12, 0.0),
        "budget": 900,
        "eye": ((0.3, 0.43, 0.11), 0.09),
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
    PART_COLOURS["wing_" + _side] = (60, 140 + 80 * _s, 230)
    PART_COLOURS["wtip_" + _side] = (230, 160 + 60 * _s, 40)
for _k in range(5):
    PART_COLOURS["pt_%d" % (_k + 1)] = (240 - 40 * _k, 60 + 40 * _k, 60 + 30 * _k)
for _k in range(3):
    PART_COLOURS["tail_%d" % (_k + 1)] = (60 + 80 * _k, 220, 220 - 60 * _k)


def crack_texels(rgb):
    """The flea's ember cracks: bright orange (red full, green some, blue low)."""
    return (rgb[..., 0] >= 0.8) & (rgb[..., 1] >= 0.22) & (rgb[..., 1] <= 0.7) & (rgb[..., 2] <= 0.35)


def eye_texels(rgb):
    """The gem eye: bright, saturated red or pink-red."""
    return (rgb[..., 0] >= 0.75) & (rgb[..., 1] <= 0.35) & (rgb[..., 2] <= 0.55)


def plate_test(cfg):
    """The plates' colour (role_map.texel_share's test): the crimson from its shaded underside's dark red to its lit
    red (hs.plate_or_shade), the flea's ember cracks left out (they glow)."""
    if cfg.get("cracks"):
        return lambda rgb: hs.plate_or_shade(rgb) & ~crack_texels(rgb)
    return hs.plate_or_shade


def mean_test(cfg):
    """The lit plate texels the greyscale map's level is set by (role_map.tinted_map)."""
    if cfg.get("cracks"):
        return lambda rgb: hs.plate_texels(rgb) & ~crack_texels(rgb)
    return hs.plate_texels


def is_limb(pn):
    return pn.startswith(LIMBS)


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


def parts_of(cfg, c, tcol, pinv_J, plates):
    """Per triangle centre (raw units): its part; and each part's pivot (raw units). `plates`: the crimson plates by
    role_map's share (the flyers' cut); the walkers' legs are cut by the colour at each triangle's middle."""
    if "wings" in cfg:
        return bat_parts(cfg, c, pinv_J, plates)
    if "star" in cfg:
        return mote_parts(cfg, c, pinv_J, plates)
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


def band_middle(c, run, at, half=0.02):
    """The middle of the triangles of `run` whose |z| is within `half` of `at` (a wing's root or elbow)."""
    az = np.abs(c[run, 2])
    near = run[np.abs(az - at) < half]
    if len(near) < 3:
        near = run[np.argsort(np.abs(az - at))[:6]]
    return c[near].mean(0)


def bat_parts(cfg, c, pinv_J, plates):
    """The bat: each wing the biggest non-crimson run past body_z on its side, its outer part past tip_z."""
    body_z, tip_z = cfg["wings"]
    lab = np.array(["body"] * len(c), dtype=object)
    piv = {"body": np.zeros(3)}
    nb = beetle.neighbours(pinv_J)
    for side, sign in (("r", 1.0), ("l", -1.0)):
        found = runs(~plates & (c[:, 2] * sign > body_z), nb)
        if not found:
            continue
        run = max(found, key=len)
        lab[run[np.abs(c[run, 2]) <= tip_z]] = "wing_" + side
        lab[run[np.abs(c[run, 2]) > tip_z]] = "wtip_" + side
        piv["wing_" + side] = band_middle(c, run, body_z)
        piv["wtip_" + side] = band_middle(c, run, tip_z)
    lab = hs.islands(lab, pinv_J)
    return lab, piv


def mote_parts(cfg, c, pinv_J, plates):
    """The mote: the crimson star's five wedges about its middle; the face plate (ahead of face_x) and the core
    (within core_r of the middle) the body; the rest of the non-crimson triangles the tail, in three segments by their
    distance from its root."""
    yc, zc, core_r, face_x, first_deg = cfg["star"]
    lab = np.array(["body"] * len(c), dtype=object)
    piv = {"body": np.zeros(3)}
    ang = np.degrees(np.arctan2(c[:, 2] - zc, c[:, 1] - yc)) - first_deg  # 0 straight up, growing toward +z
    wedge = np.floor(np.mod(ang + 36.0, 360.0) / 72.0).astype(int)
    x_mid = float(np.median(c[plates, 0]))
    for k in range(5):
        lab[plates & (wedge == k)] = "pt_%d" % (k + 1)
        piv["pt_%d" % (k + 1)] = np.array([x_mid, yc, zc])
    d_axis = np.hypot(c[:, 1] - yc, c[:, 2] - zc)
    tail = ~plates & (c[:, 0] < face_x) & (d_axis >= core_r)
    found = runs(tail, beetle.neighbours(pinv_J))
    if found:
        run = max(found, key=len)
        lab[run] = "tail_1"
        # The root: the run's triangles nearest the core; each triangle's distance from it (along the curved tail).
        root = c[run[np.argsort(d_axis[run])[: max(3, len(run) // 10)]]].mean(0)
        dist = np.linalg.norm(c[run] - root, axis=1)
        top = dist.max()
        lab[run[dist > top / 3.0]] = "tail_2"
        lab[run[dist > 2.0 * top / 3.0]] = "tail_3"
        piv["tail_1"] = root
        for k, f in ((2, 1.0 / 3.0), (3, 2.0 / 3.0)):
            band = run[np.abs(dist - f * top) < top * 0.05]
            piv["tail_%d" % k] = c[band].mean(0) if len(band) >= 3 else root + (c[run[np.argmax(dist)]] - root) * f
    lab = hs.islands(lab, pinv_J)
    return lab, piv


def surfaces_of(cfg, part, c, tcol, colour, UVw, J, nb):
    """Per triangle: 2 glow (the eye, by its place; the flea's cracks), 1 role (role_map's rules: the plates by the
    share of their texels, the pale wear touching them off the limbs joined), 0 base."""
    k = (role_map.texel_share(colour, UVw, J, plate_test(cfg)) >= role_map.ROLE_SHARE).astype(int)
    lum = tcol @ role_map.LUMA
    limbs = np.array([is_limb(p) for p in part])
    k = role_map.grow(k, nb, (lum >= 0.3) & (tcol[:, 0] >= tcol[:, 2] + 0.03) & ~limbs)
    e_at, e_r = cfg["eye"]
    k[eye_texels(tcol) & (np.linalg.norm(c - np.asarray(e_at), axis=1) < e_r) & (part == "body")] = 2
    if cfg.get("cracks"):
        k[crack_texels(tcol) & (part == "body")] = 2
    return k


def classify(rid):
    """The raw model read and sorted: (cfg, Wr, UVw, J, pinv, colour, bounds, raw tris, centres, colours, part,
    pivots, surface)."""
    cfg = MODELS[rid]
    Wr, UVw, J, pinv, colour, bounds, raw_tris = hs.load(rid)
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    plates = role_map.texel_share(colour, UVw, J, plate_test(cfg)) >= role_map.ROLE_SHARE
    e_at, e_r = cfg["eye"]
    plates &= ~(eye_texels(tcol) & (np.linalg.norm(cen - np.asarray(e_at), axis=1) < e_r))  # The gem stays on the body
    part, pivots = parts_of(cfg, cen, tcol, pinv[J], plates)
    surf = surfaces_of(cfg, part, cen, tcol, colour, UVw, J, beetle.neighbours(pinv[J]))
    return cfg, Wr, UVw, J, pinv, colour, bounds, raw_tris, cen, tcol, part, pivots, surf


def debug(rid):
    from PIL import ImageDraw

    _cfg, Wr, _UVw, J, _p, _c, _b, _r, cen, _t, part, piv, surf = classify(rid)
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
    counts = {p: int((part == p).sum()) for p in sorted(set(part))}
    print(json.dumps(counts), "glow", int((surf == 2).sum()), "role", int((surf == 1).sum()))


def prepare(rid):
    dst = "assets/models/enemies/%s.glb" % rid
    cfg, Wr, UVw, J, pinv, colour, (lo, hi), raw_tris, _cen, tcol, part, pivots, surf = classify(rid)
    s = cfg["height"] / (hi[1] - lo[1])
    W = Wr * s  # metres
    groups = sorted({(p, k) for p, k in zip(part, surf)})
    total = len(J)
    budget = cfg.get("budget", BUDGET_TRIS)
    scale = 1.0
    for _attempt in range(3):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (surf == g[1])
            share = max(int(round(budget * scale * m.sum() / total)), 8)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=True)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= budget * 1.03:
            break
        scale *= budget / tris_after * 0.97
    order = [pn for pn in sorted(pivots) if any(g[0] == pn and len(simplified[g]) for g in groups)]
    per_part = {pn: np.concatenate([simplified[g] for g in groups if g[0] == pn]) for pn in order}
    per_surf = {pn: np.concatenate([np.full(len(simplified[g]), g[1]) for g in groups if g[0] == pn]) for pn in order}
    # A simplified base triangle can stretch its UVs over the plates' colour (its collapsed corners moved): off the
    # limbs it joins the role plates when role_map's share holds for it, so no base triangle shows the greyscale map.
    for pn in order:
        if is_limb(pn):
            continue
        base = per_surf[pn] == 0
        share = role_map.texel_share(colour, UVw, per_part[pn][base], plate_test(cfg))
        per_surf[pn][np.where(base)[0][share >= role_map.ROLE_SHARE]] = 1
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = beetle.cut_caps(per_part, pinv, W, set(), set())
    body_m = part == "body"
    lum = tcol @ role_map.LUMA
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
    # The colour map: the texels under the role triangles greyscale (the game multiplies them by the role colour),
    # every other texel as painted (role_map.tinted_map), halved.
    T_role = np.concatenate([per_part[pn][per_surf[pn] == 1] for pn in order])
    T_other = np.concatenate([per_part[pn][per_surf[pn] != 1] for pn in order])
    img = role_map.tinted_map(colour, UVw, T_role, T_other, mean_test(cfg))
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
