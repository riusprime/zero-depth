"""Prepares the owner's Needle and Sniper (unprocessed_images/models_v0120_b/needle.glb, sniper.glb) for the game:
assets/models/enemies/needle.glb and sniper.glb, each cut into the parts NeedleAvatar / SniperAvatar animate.

Each raw file is a Tripo export: one closed textured mesh (the Needle 4,672 triangles, the Sniper 4,606; a 2048 px
colour map), about one unit across, no rig, Y up. The raw files stay untouched.
- The Needle faces +Z: a charcoal cube body under a ridged blue hood, a shield face plate with a cyan gem, a square
  barrel straight forward from under the face, octagonal pods on its flanks and four short two-part legs on bone claws
  splayed to the corners.
- The Sniper faces +X: a narrow blue ridged shell over a charcoal hub, a diamond face plate with a big round cyan lens,
  a long thin barrel forward from under the lens and three long thin legs in an uneven tripod on bone feet.
This script, reusing frost_spitter_prep's cutting helpers (and through it mi_prep's reader, normals and glb writer):
1. turns the mesh to the game's frame (+X the front), puts the origin under its legs' hub (CENTRE: the turret turns
   about where its legs meet, not about the bounds' middle, which the long barrel pulls forward), its feet on y = 0,
   and scales it evenly to HEIGHT_M (the request rows: the Needle about 1.1 m, the Sniper about 1.3 m);
2. cuts it into the parts that move, by place and colour: the barrel (it slides back on each shot), the shell (the
   blue hood: it lifts and tips), each leg's upper half (hip to knee) and lower half (the foot), the body (the rest:
   the rig's root). A leg's triangles are those near its bone line (LEGS, fitted to the raw mesh); every part node's
   origin is its pivot (the hip, the knee, the barrel's root, the shell's back rim);
3. caps the cuts (the hull is hollow): a fan over each part's cut edges facing the part across it (none on the shell:
   its underside is never seen from above);
4. sorts each triangle into a surface by the colour map under it: `glow` (the cyan gem or lens on the body; on the
   barrel its muzzle's end face, which charges up), `role` (the saturated blue plates: their texels greyscale in the
   map so the game tints them in the kind's role colour) and `base` (the charcoal, the greys, the bone feet);
5. keeps every triangle (both under the 5k budget) and the owner's own UV layout and colour map, halved to TEX_PX;
6. writes the glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles, the triangles after (per part: total, glow, role, the pivot), the caps,
the size in metres, the muzzle's tip (m, the game frame), the file written, its size and sha256 (pasted into
assets/models/manifest.json by hand).

Run from the repo root:  python scripts/assets/needle_sniper_prep.py needle   (or sniper)
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
import frost_spitter_prep as fs  # noqa: E402  (its cutting helpers; it stubs xatlas and imports mi_prep)

mi_prep = fs.mi_prep

## Per kind, in raw units after the turn (+X the front, +Z the right):
## - turn: "z" when the raw front is +Z (a quarter turn about +Y), "x" when it already faces +X;
## - centre: (x, z) of the new origin; the height the model is scaled to (m);
## - legs: hip, knee and foot tip per leg (the knee a little above the straight line, so the leg bends one way); reach: how far round the upper and the lower line is still that leg;
##   leg_top: above it nothing is a leg; leg_z: a leg starts that far off the middle (0: anywhere);
## - barrel: x past which, between the two heights and within the half width of its axis (z), is the barrel; its
##   pivot (its root, where it slides from) and the muzzle's end (x past which its end face glows);
## - shell: blue plates above y (and anything above top, behind top_x) are the shell; its pivot (the back rim);
## - cap_reach: how far (raw units) from its centre a leg's cap reaches (its cross-section);
## - leg_side (the Needle): the leg blocks reach up past the body's floor (leg_top) to that height past that |z|.
KINDS = {
    "needle": {
        "src": "unprocessed_images/models_v0120_b/needle.glb",
        "turn": "z",
        "centre": (-0.12, 0.0),
        "height": 1.1,
        "legs": {
            "fr": ((0.06, 0.22, 0.21), (0.14, 0.15, 0.29), (0.22, 0.01, 0.32)),
            "fl": ((0.04, 0.22, -0.20), (0.09, 0.15, -0.29), (0.145, 0.01, -0.35)),
            "br": ((-0.32, 0.22, 0.22), (-0.39, 0.15, 0.31), (-0.43, 0.01, 0.375)),
            "bl": ((-0.33, 0.22, -0.22), (-0.39, 0.15, -0.29), (-0.45, 0.01, -0.365)),
        },
        "reach": (9.0, 9.0),
        "leg_top": 0.205,
        "leg_z": 0.13,
        "leg_side": (0.27, 0.25),
        "cap_reach": 0.09,
        "barrel": {"x": 0.205, "y": (0.28, 0.48), "z": (0.0, 0.1), "pivot": (0.205, 0.38, 0.0), "muzzle": 0.492},
        "shell": {"y": 0.6, "top": 0.64, "top_x": 9.0, "pivot": (-0.36, 0.6, 0.0)},
    },
    "sniper": {
        "src": "unprocessed_images/models_v0120_b/sniper.glb",
        "turn": "x",
        "centre": (-0.17, -0.025),
        "height": 1.3,
        "legs": {
            "f": ((-0.165, 0.41, -0.09), (-0.085, 0.31, -0.14), (0.075, 0.005, -0.172)),
            "r": ((-0.175, 0.41, -0.075), (-0.26, 0.28, -0.15), (-0.345, 0.005, -0.265)),
            "l": ((-0.185, 0.42, 0.0), (-0.215, 0.26, 0.15), (-0.237, 0.005, 0.254)),
        },
        "reach": (0.055, 0.06),
        "cap_reach": 0.05,
        "leg_top": 0.395,
        "leg_z": 0.0,
        "barrel": {
            "x": 0.075, "y": (0.42, 0.54), "z": (-0.025, 0.06), "pivot": (0.075, 0.478, -0.025), "muzzle": 0.492,
        },
        "shell": {"y": 0.5, "top": 0.6, "top_x": -0.02, "pivot": (-0.3, 0.56, -0.025)},
    },
}
TEX_PX = 1024


def lens_texels(rgb):
    """The cyan gem / lens: bright blue with real green, little red (the shell's royal blue has little green)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (b >= 0.7) & (g >= 0.45) & (r <= 0.5)


def role_texels(rgb):
    mx = rgb.max(-1)
    blue = rgb[..., 2] >= rgb[..., 0] + 0.1
    return (fs.sat_of(rgb) >= 0.45) & (mx >= 0.22) & blue & ~lens_texels(rgb)


def parts_of(cfg, c, tcol, nb, corners):
    """Per triangle centre (raw units, game frame, centred; `corners` its three corners): its part; and each part's
    pivot (raw units)."""
    n = len(c)
    lab = np.array(["body"] * n, dtype=object)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    piv = {"body": np.zeros(3)}
    best = np.full(n, np.inf)
    taken = np.zeros(n, bool)
    r_u, r_l = cfg["reach"]
    for leg, (hip, knee, tip) in cfg["legs"].items():
        hip, knee, tip = np.asarray(hip), np.asarray(knee), np.asarray(tip)
        d0 = fs.seg_dist(c, hip, knee)
        d1 = fs.seg_dist(c, knee, tip)
        side = (z * np.sign(hip[2]) > cfg["leg_z"]) if cfg["leg_z"] > 0 else np.ones(n, bool)
        near_u = (d0 < r_u) & (d0 <= d1)
        near_l = (d1 < r_l) & (d1 < d0)
        dn = np.minimum(d0, d1)
        low = y < cfg["leg_top"]
        if "leg_side" in cfg:  # the leg blocks reach up past the body's floor at its corners
            low |= (y < cfg["leg_side"][0]) & (np.abs(z) > cfg["leg_side"][1])
        m = (near_u | near_l) & side & low & (dn < best)
        lab[m & near_u] = "leg_%s_u" % leg
        lab[m & near_l] = "leg_%s_l" % leg
        best = np.where(m, dn, best)
        taken |= m
        piv["leg_%s_u" % leg] = hip
        piv["leg_%s_l" % leg] = knee
    # Anything low left over (a splayed claw past the reach) goes to the nearest foot.
    stray = np.where((y < 0.08) & ~taken)[0]
    if len(stray):
        legs = list(cfg["legs"])
        d = np.stack([fs.seg_dist(c[stray], cfg["legs"][g][1], cfg["legs"][g][2]) for g in legs], 1)
        for t, k in zip(stray, d.argmin(1)):
            lab[t] = "leg_%s_l" % legs[k]
        taken[stray] = True
    b = cfg["barrel"]
    barrel = (x > b["x"]) & (y > b["y"][0]) & (y < b["y"][1]) & (np.abs(z - b["z"][0]) < b["z"][1]) & ~taken
    lab[barrel] = "barrel"
    piv["barrel"] = np.asarray(b["pivot"])
    s = cfg["shell"]
    shell = ((role_texels(tcol) & (y > s["y"])) | ((y > s["top"]) & (x < s["top_x"]))) & ~taken & ~barrel
    lab[shell] = "shell"
    piv["shell"] = np.asarray(s["pivot"])
    lab = fs.smooth(lab, nb, (y > s["y"] - 0.04) & ~taken & ~barrel, "shell", "body")
    # A long sliver whose centre is in a leg but whose corner reaches into the body (past cap_reach of the leg's bone
    # line) stays with the body: on the leg it would stick out of the hip as a spike once the leg turns.
    for leg, (hip, knee, tip) in cfg["legs"].items():
        on = (lab == "leg_%s_u" % leg) | (lab == "leg_%s_l" % leg)
        if not on.any():
            continue
        far = np.zeros(n)
        for k in range(3):
            p = corners[:, k]
            far = np.maximum(far, np.minimum(fs.seg_dist(p, hip, knee), fs.seg_dist(p, knee, tip)))
        lab[on & (far > cfg["cap_reach"] * 1.6)] = "body"
    return lab, piv


def leg_caps(per_part, pinv, W, reach):
    """fs.cut_caps for each pair of parts on its own (none on the shell). A leg's cut can be more than one loop (its
    cut edges in pieces round the hip): a fan to their common mean then spans the gap between them as long thin spikes
    that show once the leg turns; so on a pair with a leg in it the leg's cap keeps only its triangles within `reach`
    (m) of the fan's centre (the leg's own cross-section), and the body gets none there (its ragged hip cut would fan
    into spikes the same way; the leg's block covers it)."""
    caps = {}
    names = list(per_part)
    for i, a in enumerate(names):
        for b in names[i + 1 :]:
            two = fs.cut_caps({a: per_part[a], b: per_part[b]}, pinv, W, set(), {"shell"})
            legs = a.startswith("leg_") or b.startswith("leg_")
            for pn, got in two.items():
                if legs and pn == "body":  # (the hip's ragged cut would fan into spikes; the leg's own cap hides it)
                    continue
                for surf, tris in got:
                    if legs:
                        to_c = [np.linalg.norm(tris[:, k] - tris[:, 2], axis=1) for k in (0, 1)]
                        tris = tris[np.maximum(to_c[0], to_c[1]) <= reach]
                    if len(tris):
                        caps.setdefault(pn, []).append((surf, tris))
    return caps


def load(cfg):
    """fs.load's welding for this kind's file and turn, centred on cfg's centre."""
    P0, UV, I0, colour = mi_prep.read_glb(cfg["src"])
    if cfg["turn"] == "z":
        P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)
    lo, hi = P0.min(0), P0.max(0)
    raw = P0 - np.array([cfg["centre"][0], lo[1], cfg["centre"][1]])
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


def centred(cfg):
    """cfg's places (legs, barrel, shell) moved to the centred frame."""
    cx, cz = cfg["centre"]
    sh = np.array([cx, 0.0, cz])
    out = dict(cfg)
    out["legs"] = {k: tuple(np.asarray(p) - sh for p in v) for k, v in cfg["legs"].items()}
    b = dict(cfg["barrel"])
    b["x"] -= cx
    b["muzzle"] -= cx
    b["z"] = (b["z"][0] - cz, b["z"][1])
    b["pivot"] = np.asarray(b["pivot"]) - sh
    out["barrel"] = b
    s = dict(cfg["shell"])
    s["top_x"] -= cx
    s["pivot"] = np.asarray(s["pivot"]) - sh
    out["shell"] = s
    return out


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "needle"
    cfg = centred(KINDS[kind])
    dst = "assets/models/enemies/%s.glb" % kind
    Wr, UVw, J, pinv, colour, (lo, hi), raw_tris = load(KINDS[kind])
    s = cfg["height"] / (hi[1] - lo[1])
    cen = Wr[J].mean(1)
    tcol = fs.tri_colour(colour, UVw, J)
    part, pivots = parts_of(cfg, cen, tcol, fs.neighbours(pinv[J]), Wr[J])
    glow = np.zeros(len(J), int)
    glow[(part == "body") & lens_texels(tcol)] = 2
    glow[(part == "barrel") & (cen[:, 0] > cfg["barrel"]["muzzle"])] = 2
    W = Wr * s
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    T_all = np.concatenate([per_part[pn] for pn in order])
    used, loc = np.unique(pinv[T_all].ravel(), return_inverse=True)
    Vp = np.zeros((len(used), 3))
    Vp[loc] = W[T_all.ravel()]
    cn_all = mi_prep.corner_normals(Vp, loc.reshape(-1, 3))
    caps = leg_caps(per_part, pinv, W, cfg["cap_reach"] * s)
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
        K = glow[part == pn].copy()
        rest = K != 2
        K[rest] = role_texels(fs.tri_colour(colour, UVw, T[rest])).astype(int)
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
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    mi_prep.write_glb(dst, kind, nodes, buf.getvalue(), mats)
    bt = W[per_part["barrel"]].reshape(-1, 3)
    tip = [float(bt[:, 0].max()), float(bt[:, 1].mean()), float(bt[:, 2].mean())]
    feet = {g: [round(float(v) * s, 3) for v in cfg["legs"][g][2]] for g in cfg["legs"]}
    print(json.dumps({
        "id": kind, "raw": KINDS[kind]["src"], "raw_tris": raw_tris, "tris": int(sum(len(v) for v in per_part.values())),
        "caps": cap_report, "tex": TEX_PX, "size": [round(float(v), 3) for v in (hi - lo) * s],
        "muzzle": [round(v, 3) for v in tip], "feet": feet, "path": dst, "bytes": os.path.getsize(dst),
        "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(), "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
