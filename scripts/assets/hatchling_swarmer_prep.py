"""Prepares the owner's Hatchling and Swarmer (unprocessed_images/models_v0120_b/<id>.glb) for the game:
assets/models/enemies/<id>.glb, cut into the parts HatchlingAvatar and SwarmerModel animate.

Each raw file is a Tripo export: one closed textured mesh (about 4.9k triangles, a 2048 px colour map), about one
unit across, no rig, Y up, its front on +Z:
- the Hatchling: a charcoal body under a spiky red-orange carapace, a glowing red eye under the carapace's front
  rim, six two-part legs (a long front pair reaching forward, a side pair, a hind pair pointing back);
- the Swarmer: a charcoal body under a crimson wing case split down its middle, a dark head with a red eye in front,
  two curved bone mandibles, six two-part legs.
They are horde kinds (a pack of 8 Swarmers, a stream of Hatchlings), drawn many at once, so each is simplified to
BUDGET_TRIS. The raw files stay untouched. This script (the Frost Spitter's path: frost_spitter_prep.py, with the Kiln
Beetle's simplifier pass, reusing o17_prep_kiln_beetle's colour sampling and cut caps and mi_prep's reader, normals,
simplifier and glb writer):
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres it on x/z with its feet on y = 0 and
   scales it evenly to its HEIGHT_M (the Hatchling 0.4 m tall, 0.58 m across; the Swarmer 0.25 m tall, 0.5 m long);
2. cuts it into the parts that move (by place and colour): each leg's upper half (hip to knee) and lower half (knee
   to foot), the triangles near its bone line (LEGS, read off the raw mesh); the Hatchling's carapace (the saturated
   red above SHELL_Y); the Swarmer's two wing-case halves (the crimson above SHELL_Y, split at z = 0) and its two
   mandibles (the bone ahead of MAND_X); the rest is the body (the rig's root). Every part node's origin is its pivot;
3. simplifies each part's surfaces to its share of BUDGET_TRIS (borders locked, so the cuts stay matched);
4. caps the cuts (the hull is hollow: a part turning would show through): a charcoal fan over each part's cut edges
   facing the part across the cut (none on the shells: their undersides are never seen);
5. sorts each triangle into a surface by the colour map under it: `glow` (the eye), `role` (the saturated shell
   plates and the pale wear among them, by role_map's rules: the texels under the role triangles greyscale in the map,
   so the game tints them in the kind's role colour) and `base`;
6. keeps the owner's UV layout and colour map, halved to TEX_PX, and writes assets/models/enemies/<id>.glb (one node
   per part, three materials base / role / glow).
It prints one JSON line per model: the raw triangles, the triangles after (per part: total, glow, role, the pivot),
the caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).
`--debug` instead draws each triangle in its part's colour from the top, the side and the front into build/prep/.

Run from the repo root:  python scripts/assets/hatchling_swarmer_prep.py [hatchling|swarmer] [--debug]
(GODOT=<godot executable> when the Python meshoptimizer package is missing: mi_prep's simplifier then runs Godot's.)
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
import mi2_prep  # noqa: E402  (its mi_prep: the reader, normals, simplifier and glb writer)
import o17_prep_kiln_beetle as beetle  # noqa: E402  (the colour sampling and the cut caps)
import frost_spitter_prep as fs  # noqa: E402  (the triangles' edge neighbours)
import role_map  # noqa: E402

mi_prep = mi2_prep.mi_prep

TEX_PX = 1024
## The triangles each model is simplified to (the cut caps come on top), and a glowing group's floor.
BUDGET_TRIS = 2450
## The reach (raw units) round a leg's upper and lower bone line that is still that leg.
REACH = (0.07, 0.07)
## The plates' saturation floor (the shells' red over it; the charcoal, the greys and the bone under).
ROLE_SAT = 0.5

## Per model (raw units, the game frame: +X front, +Z its right):
## - "legs": per leg its hip (where it leaves the body under the shell), its knee (where it turns down: the lower
##   half's pivot) and its foot's tip. fr / fl the front pair, mr / ml the middle, br / bl the hind;
## - "shell_y": above it the saturated red is the shell, and everything "shell_band" higher (the Hatchling's dark
##   ridges between its red spikes; the Swarmer's seam); "shell_pivot": the shell's pivot (the Swarmer's: each half's
##   hinge at the front of the seam);
## - "eye": the eye's middle and reach (its bright red is the glow);
## - the Swarmer's mandibles: ahead of "mand_x", off the middle by "mand_z", the bone; each one's pivot (its root).
MODELS = {
    "hatchling": {
        "height": 0.4,
        "legs": {
            "fr": ((0.24, 0.19, 0.2), (0.31, 0.29, 0.245), (0.482, 0.02, 0.29)),
            "fl": ((0.24, 0.17, -0.2), (0.3, 0.26, -0.22), (0.468, 0.03, -0.312)),
            "mr": ((-0.1, 0.19, 0.29), (-0.155, 0.275, 0.335), (-0.173, 0.008, 0.475)),
            "ml": ((-0.18, 0.19, -0.255), (-0.195, 0.285, -0.315), (-0.127, 0.035, -0.478)),
            "br": ((-0.28, 0.2, 0.15), (-0.34, 0.28, 0.14), (-0.488, 0.015, 0.04)),
            "bl": ((-0.28, 0.17, -0.15), (-0.323, 0.27, -0.18), (-0.47, 0.028, -0.08)),
        },
        "leg_top": 0.33,
        "shell_y": 0.3,
        "shell_pivot": (0.0, 0.36, 0.0),
        "eye": ((0.37, 0.21, 0.0), 0.09),
    },
    "swarmer": {
        "height": 0.25,
        "legs": {
            "fr": ((0.1, 0.16, 0.24), (0.16, 0.19, 0.32), (0.205, 0.02, 0.428)),
            "fl": ((0.11, 0.17, -0.24), (0.16, 0.19, -0.32), (0.22, 0.016, -0.426)),
            "mr": ((-0.07, 0.15, 0.25), (-0.095, 0.19, 0.345), (-0.1, 0.02, 0.48)),
            "ml": ((-0.07, 0.16, -0.25), (-0.098, 0.19, -0.345), (-0.093, 0.014, -0.485)),
            "br": ((-0.24, 0.15, 0.22), (-0.29, 0.19, 0.3), (-0.355, 0.022, 0.465)),
            "bl": ((-0.24, 0.15, -0.22), (-0.3, 0.19, -0.3), (-0.357, 0.006, -0.477)),
        },
        "leg_top": 0.21,
        "shell_y": 0.19,
        "shell_band": 0.06,
        "shell_x": 0.22,
        "shell_pivot": (0.2, 0.38, 0.0),
        "eye": ((0.3, 0.2, 0.0), 0.06),
        "mand_x": 0.25,
        "mand_z": 0.075,
        "mand_pivot": {"r": (0.29, 0.15, 0.15), "l": (0.255, 0.15, -0.2)},
    },
}

PART_COLOURS = {
    "body": (90, 90, 90), "shell": (220, 60, 30), "shell_l": (220, 60, 30), "shell_r": (240, 140, 40),
    "mand_l": (230, 220, 120), "mand_r": (250, 250, 180),
}
for _k, _leg in enumerate(["fr", "fl", "mr", "ml", "br", "bl"]):
    PART_COLOURS["leg_%s_u" % _leg] = (40 + 30 * _k, 120, 220 - 25 * _k)
    PART_COLOURS["leg_%s_l" % _leg] = (40 + 30 * _k, 200, 120 - 15 * _k)


def sat_of(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    return (mx - mn) / np.maximum(mx, 1e-6)


def role_texels(rgb):
    """The shell's red plates: saturated, red over blue, not dark."""
    return (sat_of(rgb) >= ROLE_SAT) & (rgb.max(-1) >= 0.25) & (rgb[..., 0] >= rgb[..., 2])


def eye_texels(rgb):
    """The eye's bright red: red near full, green and blue low."""
    return (rgb[..., 0] >= 0.75) & (rgb[..., 1] <= 0.35) & (rgb[..., 2] <= 0.35)


def bone_texels(rgb):
    """The mandibles' and feet's bone: light and pale."""
    return (rgb.max(-1) >= 0.35) & (sat_of(rgb) < 0.45)


def parts_of(cfg, c, tcol, pinv_J):
    """Per triangle centre (raw units): its part; and each part's pivot (raw units)."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    best = np.full(n, np.inf)
    taken = np.zeros(n, bool)
    for leg, (hip, knee, foot) in cfg["legs"].items():
        hip, knee, foot = np.asarray(hip), np.asarray(knee), np.asarray(foot)
        d0 = beetle.seg_dist(c, hip, knee)
        d1 = beetle.seg_dist(c, knee, foot)
        out = (knee - hip) * np.array([1.0, 0.0, 1.0])
        beyond = (c - hip) @ (out / np.linalg.norm(out)) > -0.01
        near_u = (d0 < REACH[0]) & (d0 <= d1)
        near_l = (d1 < REACH[1]) & (d1 < d0)
        dn = np.minimum(d0, d1)
        m = (near_u | near_l) & beyond & (y < cfg["leg_top"]) & (dn < best)
        lab[m & near_u] = "leg_%s_u" % leg
        lab[m & near_l] = "leg_%s_l" % leg
        best = np.where(m, dn, best)
        taken |= m
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    if "mand_x" in cfg:
        for side, sign in (("r", 1.0), ("l", -1.0)):
            base = (x > cfg["mand_x"] + 0.02) & (y < 0.19)
            m = (x > cfg["mand_x"]) & (z * sign > cfg["mand_z"]) & (y < 0.2) & ~taken & (bone_texels(tcol) | base)
            lab[m] = "mand_" + side
            taken |= m
            piv["mand_" + side] = np.asarray(cfg["mand_pivot"][side])
    red = role_texels(tcol) & ~eye_texels(tcol)
    high = y > cfg["shell_y"] + cfg.get("shell_band", 0.0)
    shell = (red | high) & (y > cfg["shell_y"]) & ~taken & (x < cfg.get("shell_x", 9.0))
    if "mand_x" in cfg:
        lab[shell & (z >= 0.0)] = "shell_r"
        lab[shell & (z < 0.0)] = "shell_l"
        piv["shell_r"] = np.asarray(cfg["shell_pivot"])
        piv["shell_l"] = np.asarray(cfg["shell_pivot"])
    else:
        lab[shell] = "shell"
        piv["shell"] = np.asarray(cfg["shell_pivot"])
    lab = islands(lab, pinv_J)
    return lab, piv


def islands(lab, pinv_J, passes=4):
    """A part's triangle with no edge neighbour in its own part (a speck cut off by the colour or the reach) takes
    the part most of its neighbours are, so nothing floats or tears when the parts move."""
    nb = beetle.neighbours(pinv_J)
    for _ in range(passes):
        new = lab.copy()
        for t in range(len(lab)):
            ns = [lab[k] for k in nb[t]]
            if ns and lab[t] not in ns:
                vals, counts = np.unique(np.array(ns, dtype=object), return_counts=True)
                new[t] = vals[np.argmax(counts)]
        lab = new
    return lab


def load(rid):
    """The raw mesh in the game frame (raw units), welded: (welded positions, their UVs, triangles, the position-weld
    index, the colour map, the raw positions' bounds, the raw triangle count)."""
    P0, UV, I0, colour = mi_prep.read_glb("unprocessed_images/models_v0120_b/%s.glb" % rid)
    P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)  # a quarter turn about +Y: the raw +Z front to +X
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
    return Wr, UVw, J, pinv.ravel(), colour, (lo, hi), len(I0)


def plate_texels(rgb):
    return role_texels(rgb) & ~eye_texels(rgb)


def plate_or_shade(rgb):
    """The plates' colour from their shaded undersides' dark red (below role_texels' brightness floor) up to their
    lit red (the eye's colour too: the eye is found by its place, not its colour)."""
    return (sat_of(rgb) >= ROLE_SAT) & (rgb.max(-1) >= 0.08) & (rgb[..., 0] >= rgb[..., 2])


def surfaces_of(cfg, part, c, tcol, colour, UVw, J, nb):
    """Per triangle: 2 glow (the eye), 1 role (the shell plates, by role_map's rules: the pale triangles that join them
    are light and warm, off the legs and mandibles: the plates' painted wear, not the bone), 0 base."""
    k = (role_map.texel_share(colour, UVw, J, plate_or_shade) >= role_map.ROLE_SHARE).astype(int)
    lum = tcol @ role_map.LUMA
    limbs = np.array([p.startswith("leg") or p.startswith("mand") for p in part])
    k = role_map.grow(k, nb, (lum >= 0.3) & (tcol[:, 0] >= tcol[:, 2] + 0.03) & ~limbs)
    e_at, e_r = cfg["eye"]
    eye = eye_texels(tcol) & (np.linalg.norm(c - np.asarray(e_at), axis=1) < e_r)
    k[eye & ~limbs] = 2
    return k


def debug(rid):
    from PIL import ImageDraw

    cfg = MODELS[rid]
    Wr, UVw, J, pinv, colour, _, _ = load(rid)
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, _ = parts_of(cfg, cen, tcol, pinv[J])
    surf = surfaces_of(cfg, part, cen, tcol, colour, UVw, J, fs.neighbours(pinv[J]))
    size = 700
    sheet = Image.new("RGB", (size * 4, size), "white")
    views = ((0, 2, 1, 1.0), (0, 1, 2, 1.0), (2, 1, 0, 1.0), (0, 2, 1, -1.0))  # top, side, front, bottom
    for k, (a0, a1, depth, sign) in enumerate(views):
        im = Image.new("RGB", (size, size), "white")
        d = ImageDraw.Draw(im)
        order = np.argsort(sign * cen[:, depth])
        for t in order:
            v = Wr[J[t]]
            yy = v[:, a1] if a1 != 1 else 0.5 - v[:, 1]
            pts = [(size / 2 + v[q, a0] * size * 0.9, size / 2 + yy[q] * size * 0.9) for q in range(3)]
            fill = PART_COLOURS.get(part[t], (0, 0, 0))
            if surf[t] == 2:
                fill = (255, 0, 255)
            d.polygon(pts, fill=fill, outline=(0, 0, 0))
        sheet.paste(im, (k * size, 0))
    os.makedirs("build/prep", exist_ok=True)
    sheet.save("build/prep/%s_parts.png" % rid)
    print(json.dumps({p: int((part == p).sum()) for p in sorted(set(part))}), int((surf == 2).sum()))


def prepare(rid):
    cfg = MODELS[rid]
    dst = "assets/models/enemies/%s.glb" % rid
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = load(rid)
    s = cfg["height"] / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = beetle.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cfg, cen, tcol, pinv[J])
    surf = surfaces_of(cfg, part, cen, tcol, colour, UVw, J, fs.neighbours(pinv[J]))
    W = Wr * s  # metres
    groups = sorted({(p, k) for p, k in zip(part, surf)})
    total = len(J)
    scale = 1.0
    for _attempt in range(3):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (surf == g[1])
            share = max(int(round(BUDGET_TRIS * scale * m.sum() / total)), 12)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=True)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= BUDGET_TRIS * 1.03:
            break
        scale *= BUDGET_TRIS / tris_after * 0.97
    order = [pn for pn in sorted(pivots) if any(g[0] == pn and len(simplified[g]) for g in groups)]
    per_part = {pn: np.concatenate([simplified[g] for g in groups if g[0] == pn]) for pn in order}
    per_surf = {pn: np.concatenate([np.full(len(simplified[g]), g[1]) for g in groups if g[0] == pn]) for pn in order}
    # A simplified base triangle can stretch its UVs over the plates' colour (its collapsed corners moved): it joins the
    # role plates when role_map's share holds for it, so no base triangle shows the greyscale map untinted.
    for pn in order:
        if pn.startswith("leg") or pn.startswith("mand"):
            continue
        base = per_surf[pn] == 0
        share = role_map.texel_share(colour, UVw, per_part[pn][base], plate_or_shade)
        per_surf[pn][np.where(base)[0][share >= role_map.ROLE_SHARE]] = 1
    # Normals over the whole position-welded mesh, every part at once (no crease where two parts meet, nor at the UV
    # seams); corners flat per face after.
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    shells = {pn for pn in order if pn.startswith("shell")}
    caps = beetle.cut_caps(per_part, pinv, W, set(), shells)
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
    # The colour map: the role plates' texels greyscale (the game multiplies them by the role colour), halved.
    T_role = np.concatenate([per_part[pn][per_surf[pn] == 1] for pn in order])
    T_other = np.concatenate([per_part[pn][per_surf[pn] != 1] for pn in order])
    img = role_map.tinted_map(colour, UVw, T_role, T_other, plate_texels)
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    mi_prep.write_glb(dst, rid, nodes, buf.getvalue(), mats)
    ext = (hi - lo) * s
    print(json.dumps({
        "id": rid, "raw": "unprocessed_images/models_v0120_b/%s.glb" % rid, "raw_tris": raw_tris,
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "simplifier": mi_prep.BACKEND,
        "tex": TEX_PX, "size": [round(float(v), 3) for v in ext], "path": dst, "bytes": os.path.getsize(dst),
        "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(), "parts": report,
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
