"""v0.11.0 Step O17b: prepares the owner's Rock Lurker (unprocessed_images/models_v0110/rock_lurker.glb, a Tripo export:
one textured mesh, 9,766 triangles, no rig, front raw +Z) for the game, the way mi2_prep.py prepared the elites (its
bake, simplify and glb writer come from mi_prep.py through it). The raw file stays untouched.

1. Turned to the game's frame (front onto +X: yaw 90), centred on x/z with its bottom at y = 0, scaled to HEIGHT m (the
   art list's 0.9 m boulder; EnemyModels scales it again to its SPECS height).
2. Cut into the parts RockLurkerAvatar moves (label_parts, PIVOTS: by position in the model's own height units): the rock shell with
   the belly under it (`body`), the face plate with its brow and visor (`head`), each front arm in two (`arm_*`: the
   upper boulder from the shoulder, `hand_*`: the forearm and claws from the elbow), each short hind leg (`leg_*`);
   each part one glTF node with its origin at its pivot.
3. Each triangle's surface from the colour under it: `glow` (the visor: bright, saturated), `role` (the brow plate:
   saturated red, greyscale in the texture so the game tints it), `base` (the rest).
4. The cracks: thin lines painted in the colour map, too thin to survive as triangles. Every crack texel on the shell
   is found in the raw map, put back on the surface (its 3D point and normal), and the points are joined into short
   flat ribbons a few millimetres proud of the rock (the body's `glow` surface: the avatar's crack material, which
   pulses with the rumble). The painted lines stay in the colour map under them.
5. Welded, simplified per part and surface to BUDGET (borders locked: Godot's simplifier on a PC without
   meshoptimizer), each part's open cuts closed by a fan (cap_holes: no hole shows when a joint turns), given a new UV
   atlas (always Godot's own xatlas through gd_unwrap.gd: the Python package has no wheel for this PC's Python, and one
   route gives the same file everywhere) and the raw colour baked onto it (mi_prep's bake), written to
   assets/models/enemies/rock_lurker.glb.

It prints one JSON line: raw triangles and size, triangles after (per part: [triangles, glow triangles, pivot]), the
ribbons, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).

Run from the repo root:  python scripts/assets/o17_prep_rock_lurker.py   (GODOT=<godot executable>; not -I where
numpy and the rest live in the user site-packages)
Needs numpy, Pillow, scipy and Godot 4.7 (gd_unwrap.gd; gd_simplify.gd without the meshoptimizer package).
"""

import hashlib
import io
import json
import os
import struct
import subprocess
import sys
import tempfile
import types

import numpy as np
from PIL import Image
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import xatlas  # noqa: F401  (mi_prep imports it; the atlas here is Godot's either way)
except ImportError:  # no wheel for this Python: a stand-in so mi_prep imports
    sys.modules["xatlas"] = types.ModuleType("xatlas")
import mi2_prep  # noqa: E402  (mi_prep's bake, simplify and glb writer, through mi2_prep)

mi_prep = mi2_prep.mi_prep

SRC = "unprocessed_images/models_v0110/rock_lurker.glb"
DST = "assets/models/enemies/rock_lurker.glb"
RID = "rock_lurker"
YAW = 90.0
HEIGHT = 0.9
BUDGET = 5400
TEX_PX = 1024
GD_UNWRAP = "scripts/assets/gd_unwrap.gd"

## Texel classes in the head (mi_prep.classify_texels): (role saturation floor, glow value floor, glow saturation
## floor). The brow is a saturated red plate; the visor gem is the brighter orange-red under it.
HEAD_THRESHOLDS = (0.42, 0.80, 0.55)
## A crack texel on the shell: red well over green and blue, not dark.
CRACK_RED = 0.38
CRACK_RATIO = 1.9
## The crack ribbons (metres at HEIGHT): the clustering cell, the half width, the length clamp, the lift off the rock.
RIBBON_CELL = 0.026
RIBBON_HALF_W = 0.0075
RIBBON_LEN = (0.02, 0.05)
RIBBON_LIFT = 0.004
RIBBON_MIN_POINTS = 6
## The visor gem: the head's glowing triangles below the brow and near the middle (model height units).
GEM_TOP = 0.465
GEM_HALF_Z = 0.08

## The pivots (in model height units, the game frame: +X front, +Z the right side).
PIVOTS = {
    "body": (0.0, 0.25, 0.0),
    "head": (0.30, 0.38, 0.0),
    "arm_r": (0.15, 0.32, 0.36),
    "arm_l": (0.15, 0.32, -0.36),
    "hand_r": (0.29, 0.21, 0.40),
    "hand_l": (0.29, 0.21, -0.40),
    "leg_r": (-0.35, 0.24, 0.36),
    "leg_l": (-0.35, 0.24, -0.36),
}


def label_parts(c, sat):
    """Per triangle centre (model height units) and the saturation under it: its part."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    az = np.abs(z)
    lab = np.array(["body"] * len(c), dtype=object)

    def take(mask, name):
        mask = mask & (lab == "body")
        lab[mask] = name

    # The head: the dark face plate under the shell's front edge, the brow and the visor (the shell's grey above the
    # plate's top stays on the shell).
    box = (x > 0.28) & (az < 0.22) & (y > 0.15) & (y < 0.62)
    take(box & ((y < 0.47) | (sat > 0.3)), "head")
    for side, s in (("r", 1.0), ("l", -1.0)):
        front = (x > 0.1) & (z * s > 0.2) & (y < 0.4)
        fore = (x - 0.29) - 0.5 * (y - 0.21) > 0.0
        take(front & fore, "hand_" + side)
        take(front, "arm_" + side)
        take((x < -0.12) & (z * s > 0.2) & (y < 0.24), "leg_" + side)
    return lab


def cap_holes(W, tris):
    """The open boundary loops of `tris` (indices into W) closed by fans to each loop's centre: (fan triangles, the
    centres, appended after W's vertices), or () when it is closed."""
    e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    key = {}
    for a, b in e:
        key[(a, b)] = key.get((a, b), 0) + 1
    nxt = {}
    for a, b in e:
        if (b, a) not in key:
            nxt.setdefault(a, []).append(b)
    fans, centres = [], []
    while nxt:
        start = next(iter(nxt))
        loop = [start]
        cur = start
        while True:
            outs = nxt.get(cur)
            if not outs:
                break
            b = outs.pop()
            if not outs:
                del nxt[cur]
            if b == start:
                break
            loop.append(b)
            cur = b
            if len(loop) > 10000:
                break
        if len(loop) < 3:
            continue
        ci = len(W) + len(centres)
        centres.append(W[loop].mean(0))
        for k in range(len(loop)):
            a, b = loop[k], loop[(k + 1) % len(loop)]
            fans.append([b, a, ci])
    if not fans:
        return ()
    return np.array(fans, np.int64), np.array(centres)


# --- the UV atlas ----------------------------------------------------------------------------------------------------


def unwrap(surfaces, texel):
    """surfaces: [(V, T, N)] -> [(V', T', UV')] one atlas over all (Godot's xatlas through gd_unwrap.gd)."""
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, "in.bin"), os.path.join(tmp, "out.bin")
        with open(src, "wb") as f:
            f.write(struct.pack("<I", len(surfaces)))
            for V, T, N in surfaces:
                f.write(struct.pack("<II", len(V), T.size))
                f.write(np.ascontiguousarray(V.astype(np.float32)).tobytes())
                f.write(np.ascontiguousarray(N.astype(np.float32)).tobytes())
                f.write(np.ascontiguousarray(T.astype(np.uint32)).tobytes())
        godot = os.environ.get("GODOT", "godot")
        r = subprocess.run([godot, "--headless", "--path", ".", "-s", GD_UNWRAP, "--", src, dst, repr(texel)],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(dst):
            raise RuntimeError("gd_unwrap failed (%d): %s" % (r.returncode, (r.stdout + r.stderr)[-2000:]))
        data = open(dst, "rb").read()
    out = []
    o = 4
    for _ in range(struct.unpack("<I", data[:4])[0]):
        nv, ni = struct.unpack("<II", data[o : o + 8])
        o += 8
        V = np.frombuffer(data[o : o + 12 * nv], np.float32).reshape(-1, 3).astype(np.float64)
        o += 12 * nv
        UVo = np.frombuffer(data[o : o + 8 * nv], np.float32).reshape(-1, 2).astype(np.float64)
        o += 8 * nv
        T = np.frombuffer(data[o : o + 4 * ni], np.uint32).astype(np.int64).reshape(-1, 3)
        o += 4 * ni
        out.append((V, T, UVo))
    return out


# --- the crack ribbons -----------------------------------------------------------------------------------------------


def crack_points(P, UV, I, colour, shell):
    """The crack texels on the shell's raw triangles: their 3D points and normals (metres, game frame)."""
    size = 1024
    small = np.asarray(Image.fromarray((colour * 255).astype(np.uint8)).resize((size, size), Image.BILINEAR))
    small = small.astype(np.float64) / 255.0
    r, g, b = small[..., 0], small[..., 1], small[..., 2]
    mask = (r > CRACK_RED) & (r > CRACK_RATIO * g) & (r > CRACK_RATIO * b)
    sel = np.where(shell)[0]
    fn, _ = mi_prep.face_normals(P, I)
    uv_px = UV * size
    pts, nrm, wh = mi_prep.rasterise_faces(uv_px, I[sel], P, fn[sel], size)
    hit = mask[np.clip(wh[:, 1], 0, size - 1), np.clip(wh[:, 0], 0, size - 1)]
    return pts[hit], nrm[hit], int(mask.sum())


def ribbons(pts, nrm):
    """Short flat quads along the crack points: (positions (n*4, 3), normals (n*4, 3), triangles (n*2, 3))."""
    if len(pts) == 0:
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3), np.int64)
    tree = cKDTree(pts)
    cell = np.floor(pts / RIBBON_CELL).astype(np.int64)
    _, inv = np.unique(cell, axis=0, return_inverse=True)
    inv = inv.ravel()
    V, N, T = [], [], []
    for k in range(inv.max() + 1):
        m = inv == k
        if m.sum() < RIBBON_MIN_POINTS:
            continue
        c = pts[m].mean(0)
        near = tree.query_ball_point(c, RIBBON_CELL * 1.2)
        q = pts[near]
        n = nrm[near].sum(0)
        n /= max(np.linalg.norm(n), 1e-9)
        # (the nearest surface point's normal is the face's: steady enough over a cell)
        cov = np.cov((q - q.mean(0)).T) if len(q) > 2 else np.eye(3)
        w, e = np.linalg.eigh(cov)
        d = e[:, -1]
        d = d - n * (d @ n)
        if np.linalg.norm(d) < 1e-6:
            continue
        d /= np.linalg.norm(d)
        along = (q - c) @ d
        hl = 0.5 * np.clip(along.max() - along.min() + 0.012, *RIBBON_LEN)
        s = np.cross(n, d)
        p0 = c + n * RIBBON_LIFT
        base = len(V) * 4
        V.append([p0 - d * hl - s * RIBBON_HALF_W, p0 + d * hl - s * RIBBON_HALF_W,
                  p0 + d * hl + s * RIBBON_HALF_W, p0 - d * hl + s * RIBBON_HALF_W])
        N.append([n] * 4)
        T.append([[base, base + 1, base + 2], [base, base + 2, base + 3]])
    if not V:
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3), np.int64)
    return (np.array(V).reshape(-1, 3), np.array(N).reshape(-1, 3), np.array(T, np.int64).reshape(-1, 3))


# --- the model -------------------------------------------------------------------------------------------------------


def prepare():
    P0, UV, I, colour = mi_prep.read_glb(SRC)
    P = mi2_prep.to_game_frame(P0, {"yaw": YAW, "height": HEIGHT})
    H = HEIGHT
    source = mi_prep.Source(P, UV, I, colour)
    ext = P.max(0) - P.min(0)
    # Labels on the raw triangles (the cracks), then on the welded ones (the mesh).
    fn0, _ = mi_prep.face_normals(P, I)
    t0, b0 = source.nearest(P[I].mean(1), fn0, k=6)
    rgb0 = source.colour_at(t0, b0)
    sat0 = (rgb0.max(1) - rgb0.min(1)) / np.maximum(rgb0.max(1), 1e-6)
    lab0 = label_parts(P[I].mean(1) / H, sat0)
    cpts, cnrm, crack_texels = crack_points(P, UV, I, colour, lab0 == "body")
    RV, RN, RT = ribbons(cpts, cnrm)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    J = J[keep]
    cen = W[J].mean(1)
    fn, _ = mi_prep.face_normals(W, J)
    t, b = source.nearest(cen, fn, k=6)
    rgb = source.colour_at(t, b)
    sat = (rgb.max(1) - rgb.min(1)) / np.maximum(rgb.max(1), 1e-6)
    part = label_parts(cen / H, sat)
    cls = np.zeros(len(J), int)
    head = part == "head"
    cls[head] = mi_prep.classify_texels(rgb[head], HEAD_THRESHOLDS)
    # Only the gem under the brow glows: the brow's bright facets stay its role plate.
    c_h = cen / H
    gem = (c_h[:, 1] < GEM_TOP) & (np.abs(c_h[:, 2]) < GEM_HALF_Z)
    cls[head & (cls == 2) & ~gem] = 1
    pivots = {k: np.asarray(v, float) * H for k, v in PIVOTS.items()}
    groups = sorted({(p, k) for p, k in zip(part, cls)}, key=lambda g: (g[0], g[1]))
    total = len(J)
    scale = 1.0
    for _attempt in range(6):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (cls == g[1])
            share = max(int(round(BUDGET * scale * m.sum() / total)), 24 if g[1] > 0 else 12)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=True)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= BUDGET * 1.02:
            break
        scale *= BUDGET / tris_after * 0.97
    # Each part's open cuts (where it was joined to its neighbour) closed by a fan to the cut's centre, on its base
    # surface, so a turned joint shows no hole.
    caps = 0
    for pn in sorted(set(part)):
        tris = np.concatenate([simplified[g] for g in groups if g[0] == pn])
        cap = cap_holes(W, tris)
        if len(cap):
            W = np.concatenate([W, cap[1]])
            fan = cap[0]
            simplified[(pn, 0)] = np.concatenate([simplified.get((pn, 0), np.zeros((0, 3), np.int64)), fan])
            caps += len(fan)
            if (pn, 0) not in groups:
                groups = sorted(groups + [(pn, 0)], key=lambda g: (g[0], g[1]))
    # One atlas over every (part, surface) group; the ribbons get none (an untextured glow).
    surf_in = []
    for g in groups:
        T = simplified[g]
        u, iv = np.unique(T.ravel(), return_inverse=True)
        V = W[u]
        Tl = iv.reshape(-1, 3)
        nv = np.zeros_like(V)
        f_n, area = mi_prep.face_normals(V, Tl)
        for c3 in range(3):
            np.add.at(nv, Tl[:, c3], f_n * area[:, None])
        nv /= np.maximum(np.linalg.norm(nv, axis=1), 1e-12)[:, None]
        surf_in.append((V, Tl, nv))
    area_total = sum(mi_prep.face_normals(V, T)[1].sum() * 0.5 for V, T, _ in surf_in)
    texel = float(np.sqrt(area_total / (0.5 * TEX_PX * TEX_PX)))
    surf_out = unwrap(surf_in, texel)
    img = np.zeros((TEX_PX, TEX_PX, 3))
    filled = np.zeros((TEX_PX, TEX_PX), bool)
    role_px = np.zeros((TEX_PX, TEX_PX), bool)
    per_part = {}
    for g, (V0, T0, _n0), (V, T, UVo) in zip(groups, surf_in, surf_out):
        # Godot's output splits vertices at the seams: each back to its input vertex (the same point) for normals.
        vmap = cKDTree(V0).query(V)[1]
        corner_n = mi_prep.corner_normals(V0, vmap[T])
        uv_px = UVo * TEX_PX
        f_n, _ = mi_prep.face_normals(V, T)
        p3, n3, wh = mi_prep.rasterise_faces(uv_px, T, V, f_n, TEX_PX)
        if len(p3):
            tt, bb = source.nearest(p3, n3)
            img[wh[:, 1], wh[:, 0]] = source.colour_at(tt, bb)
            filled[wh[:, 1], wh[:, 0]] = True
            if g[1] == 1:
                role_px[wh[:, 1], wh[:, 0]] = True
        cp = V[T].reshape(-1, 3)
        cn = corner_n.reshape(-1, 3)
        cu = UVo[T].reshape(-1, 2)
        per_part.setdefault(g[0], []).append((g[1], cp - pivots[g[0]], cn, cu, np.arange(len(cp)).reshape(-1, 3)))
    img = mi_prep.dilate(img, filled, mi_prep.PAD_PX * 2)
    if role_px.any():  # the brow's texels in greyscale (the game multiplies them by the role colour)
        lum = img @ np.array([0.299, 0.587, 0.114])
        gr = np.clip(lum / max(lum[role_px].mean(), 1e-3) * 0.82, 0, 1)
        img[role_px] = gr[role_px, None]
    if len(RT):
        per_part["body"].append((2, RV - pivots["body"], RN, np.zeros((len(RV), 2)), RT))
    nodes = []
    names = sorted(per_part)
    for pn in names:
        prims = []
        for k in (0, 1, 2):
            for kk, pos, nrm, uv, idx in per_part[pn]:
                if kk == k:
                    prims.append((k, pos, nrm, uv, idx))
        nodes.append((pn, pivots[pn], prims))
    buf = io.BytesIO()
    Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8)).save(buf, "JPEG",
                                                                             quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, RID, nodes, buf.getvalue(), mats)
    tris = {pn: [int(sum(len(p[4]) for p in per_part[pn])), int(sum(len(p[4]) for p in per_part[pn] if p[0] == 2)),
                 [round(float(v), 3) for v in pivots[pn]]] for pn in names}
    return {
        "id": RID, "raw": SRC, "raw_tris": len(I), "raw_bytes": os.path.getsize(SRC), "tris": tris_after + caps + len(RT), "cap_tris": caps,
        "mesh_tris": tris_after, "ribbon_tris": len(RT), "crack_texels": crack_texels, "crack_points": len(cpts),
        "budget": BUDGET, "tex": TEX_PX, "atlas": "godot", "backend": mi_prep.BACKEND,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(), "parts": tris,
    }


def main():
    print(json.dumps(prepare()), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
