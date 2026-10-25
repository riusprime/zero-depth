"""v0.8.0 Step MI: prepares the owner's v0.8.0 models (unprocessed_images/models_v080/) for the game.

The raw files are Tripo exports: one textured mesh each (14-59k triangles, a 2048 px colour map plus a roughness and a
normal map), about 100 units across, no rig. The raw files stay untouched. For each model this script:
1. turns it into the game's frame (Y up; a kit piece's long side on +X; an enemy's front on +X, the facing frame of
   the avatars), centres it on x/z with its bottom at y = 0 and scales it evenly to its request row's height (metres);
2. welds the mesh by position and simplifies it (meshoptimizer, positions only) to its role's triangle budget (BUDGET);
   an enemy is first cut into parts (its moving pieces, by connected pieces and height/side bands; PARTS) and into
   surfaces by what its texture shows there (grey frame, role-coloured plates, glowing accents), each part and surface
   simplified apart with its borders locked, so no crack opens between them;
3. gives the simplified mesh a new UV atlas (xatlas) and bakes the owner's colour map onto it (every texel takes the
   colour of the nearest point of the raw mesh's surface, facing the same way), at TEX_PX (512 for small
   decoration), then pads the charts so mipmaps do not bleed. Normals are smooth within SMOOTH_DEG and split above
   (the kit's faceted look). The roughness and normal maps are dropped (they belonged to the raw surface);
4. writes a .glb with one shared colour map (JPEG): assets/models/kit/<id>.glb (room pieces, props, void pieces),
   assets/models/enemies/<id>.glb (one node per part, named, its origin at the part's pivot, three materials `base`,
   `role` and `glow`; on the role plates the colour map is greyscale so the game tints them in the kind's role
   colour), assets/models/devices/loop_device.glb.
It also prepares ground_star.webp as assets/textures/kit/ground_star.png (1024, seamless by an offset cross-fade) and
draws the crack masks Starfall's starglow pools are cut with (assets/textures/kit/ground_star_cracks.png).

It prints, per model: raw triangles and file size, triangles after, the file written and its size and sha256 (paste
those into assets/models/manifest.json and the evidence by hand).

Run from the repo root:  python3 -I scripts/assets/mi_prep.py [ids...]
Needs: numpy, Pillow, meshoptimizer==0.2.30a0, xatlas==0.0.11, scipy (pip install; offline tool, not shipped).

v0.9.0 MI2 (owner, 2026-10-22: "Use Godot's simplifier"): when meshoptimizer can't be imported (it has no Windows
wheel), simplify() goes through Godot instead, which embeds meshoptimizer for its LODs: scripts/assets/gd_simplify.gd,
run headless as a subprocess (the executable from the GODOT environment variable, else `godot` on the PATH). That route
aims at the exact target too but always locks the mesh's open borders (lock_border=False is not honoured; see
gd_simplify.gd). meshoptimizer stays the default where it is installed (the cloud/Linux pipeline is unchanged).
"""

import ctypes
import hashlib
import io
import json
import math
import os
import struct
import sys

import subprocess
import tempfile

import numpy as np
import xatlas
from PIL import Image
from scipy.spatial import cKDTree

try:
    from meshoptimizer._loader import lib as _mo
except ImportError:  # v0.9.0 MI2: no meshoptimizer (Windows): Godot's simplifier (gd_simplify.gd)
    _mo = None

SRC = "unprocessed_images/models_v080"
OUT = {"kit": "assets/models/kit", "enemies": "assets/models/enemies", "devices": "assets/models/devices"}
TEX_OUT = "assets/textures/kit"
JPEG_QUALITY = 88
SMOOTH_DEG = 40.0
PAD_PX = 6
## A room piece's colour map is brightened toward this mean, by at most BRIGHT_MAX (starting values).
BRIGHT_MEAN = 0.5
BRIGHT_MAX = 2.2

## Per role: the triangle budget and the colour map's size.
BUDGET = {
    "decor": (1000, 512),
    "void": (1000, 512),
    "cover": (3000, 1024),
    "set": (6000, 1024),
    "island": (3000, 1024),
    "enemy": (5000, 1024),
    "drone": (3000, 512),
    "device": (8000, 1024),
}

## id: (role, output folder, height (m) from its request row, yaw (degrees about Y, raw -> game; None: the long side
## onto +X), the id it is installed as).
SPECS = {
    # Ruins
    "building_corner": ("set", "kit", 3.0, None),
    "ladder_frame": ("cover", "kit", 2.0, None),
    "column_broken": ("cover", "kit", 1.6, None),
    "pipe_bundle": ("cover", "kit", 0.9, None),
    "barricade": ("cover", "kit", 1.0, None),
    "tire_stack": ("cover", "kit", 0.9, None),
    # Night Rocks
    "boulder_small": ("decor", "kit", 0.35, None),
    "rock_spire": ("cover", "kit", 2.2, None),
    "stone_arch": ("set", "kit", 2.4, None),
    "mushroom_cluster": ("decor", "kit", 0.5, None),
    "bone_pile": ("decor", "kit", 0.3, None),
    "floating_island_moss": ("island", "kit", 2.0, None),
    # Red Canyon
    "mesa_chunk": ("set", "kit", 1.4, None),
    "dry_shrub": ("decor", "kit", 0.4, None),
    "cactus": ("cover", "kit", 1.6, None),
    "wagon_wreck": ("set", "kit", 1.4, None),
    "cattle_skull_post": ("cover", "kit", 1.4, None),
    # Frozen Shore (the raw `ice_floe` file holds a frozen boat wreck: installed as boat_wreck, see INSTALL_AS)
    "snow_drift": ("decor", "kit", 0.28, None),
    "ice_shard": ("decor", "kit", 0.4, None),
    "ice_rock": ("cover", "kit", 1.2, None),
    "ice_floe": ("set", "kit", 1.2, None),
    "fish_rack": ("cover", "kit", 1.6, None),
    # Starfall
    "star_crystal": ("decor", "kit", 0.4, None),
    "meteorite": ("decor", "kit", 0.26, None),
    "star_monolith": ("cover", "kit", 1.6, None),
    "floating_island_starfall": ("island", "kit", 2.0, None),
    "void_spike": ("void", "kit", 2.5, None),
    "ruined_observatory": ("set", "kit", 2.6, None),
    # Enemies: the raw front read from renders (scripts/shots/mi_models.gd): +Z for the Mender, the Splitter and the
    # Lens Drone, -X for the Shield Bearer.
    "mender": ("enemy", "enemies", 1.3, 90.0),
    "shield_bearer": ("enemy", "enemies", 1.2, 180.0),
    "splitter": ("enemy", "enemies", 1.0, 90.0),
    "lens_drone": ("drone", "enemies", 0.6, 90.0),
    # The Loop device (round; its turn does not matter).
    "loop_device": ("device", "devices", 0.9, 0.0),
    # The Ascension portal (owner O81): its steps' front +Z as delivered, turned onto +X (the portal's facing); 3.4 m
    # to its pillars' tops puts its dais about 4.2 m across, the code-made dais's size.
    "ascension_portal": ("device", "devices", 3.4, 90.0),
}
## Devices cut into parts (the rest are one piece), and the height share over which a piece floats.
PARTED = {"ascension_portal"}
PORTAL_FLOAT = 0.3
## A raw file installed under another id (what it shows, not what it was named).
INSTALL_AS = {"ice_floe": "boat_wreck"}

## The Splitter's shoulders and the Mender's arms, as shares of their half-width (from the part renders).
SPLITTER_SHOULDER = 0.42
MENDER_ARM_Z = 0.45

## Texel classes on an enemy's colour map: glow (bright and coloured: eyes, seams, crystals), role (coloured
## plates), base (the charcoal and bone). Per model: (role saturation floor, glow value floor, glow saturation floor).
CLASS_THRESHOLDS = {
    "mender": (0.22, 0.80, 0.10),
    "shield_bearer": (0.30, 0.72, 0.45),
    "splitter": (0.30, 0.80, 0.40),
    "lens_drone": (0.30, 0.75, 0.50),
}


# --- glb in --------------------------------------------------------------------------------------------------------


def read_glb(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20 : 20 + n])
    bl = struct.unpack("<I", data[20 + n : 24 + n])[0]
    blob = data[28 + n : 28 + n + bl]

    def acc(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
        k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        arr = np.frombuffer(blob, dt, a["count"] * k, o)
        return arr.reshape(-1, k) if k > 1 else arr

    prim = j["meshes"][0]["primitives"][0]
    at = prim["attributes"]
    mat = j["materials"][prim.get("material", 0)]
    tex = j["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    im = j["images"][tex["source"]]
    bv = j["bufferViews"][im["bufferView"]]
    img = Image.open(io.BytesIO(blob[bv.get("byteOffset", 0) : bv.get("byteOffset", 0) + bv["byteLength"]]))
    factor = mat["pbrMetallicRoughness"].get("baseColorFactor", [1, 1, 1, 1])
    colour = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0 * np.array(factor[:3], np.float32)
    return (
        acc(at["POSITION"]).astype(np.float64),
        acc(at["TEXCOORD_0"]).astype(np.float64),
        acc(prim["indices"]).astype(np.int64).reshape(-1, 3),
        colour,
    )


# --- geometry -------------------------------------------------------------------------------------------------------


def to_game_frame(P, height, yaw_deg):
    lo, hi = P.min(0), P.max(0)
    if yaw_deg is None:
        yaw_deg = 90.0 if (hi[2] - lo[2]) > (hi[0] - lo[0]) * 1.02 else 0.0
    a = math.radians(yaw_deg)
    # A turn of +a about +Y: x' = x cos a + z sin a, z' = -x sin a + z cos a (glTF's right-handed frame).
    R = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    Q = P @ R.T
    lo, hi = Q.min(0), Q.max(0)
    Q = Q - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    Q = Q * (height / max(hi[1] - lo[1], 1e-9))
    return Q, yaw_deg


def weld(P, I, eps):
    key = np.round(P / eps).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    W = P[first]
    J = inv[I]
    keep = (J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])
    return W, J, keep


def components(nverts, J):
    par = np.arange(nverts)

    def find(x):
        root = x
        while par[root] != root:
            root = par[root]
        while par[x] != root:
            par[x], x = root, par[x]
        return root

    for a, b, c in J:
        for u, v in ((a, b), (b, c)):
            ru, rv = find(u), find(v)
            if ru != rv:
                par[ru] = rv
    roots = np.array([find(x) for x in range(nverts)])
    _, comp = np.unique(roots, return_inverse=True)
    return comp.ravel()


F32P = ctypes.POINTER(ctypes.c_float)
U32P = ctypes.POINTER(ctypes.c_uint)
if _mo is not None:
    _mo.meshopt_simplify.argtypes = [U32P, U32P, ctypes.c_size_t, F32P, ctypes.c_size_t, ctypes.c_size_t,
                                     ctypes.c_size_t, ctypes.c_float, ctypes.c_uint, F32P]
    _mo.meshopt_simplify.restype = ctypes.c_size_t
LOCK_BORDER = 1
## The backend simplify() uses (printed by the callers into their summaries).
BACKEND = "meshoptimizer" if _mo is not None else "godot"
GD_SIMPLIFY = "scripts/assets/gd_simplify.gd"


def simplify_godot(W, J, target_tris):
    """Godot's simplifier (gd_simplify.gd, headless): only the triangles' own vertices go in; borders always locked."""
    used, inv = np.unique(J.ravel(), return_inverse=True)
    pos = np.ascontiguousarray(W[used].astype(np.float32))
    idx = np.ascontiguousarray(inv.astype(np.uint32))
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, "in.bin"), os.path.join(tmp, "out.bin")
        with open(src, "wb") as f:
            f.write(struct.pack("<II", len(pos), idx.size) + pos.tobytes() + idx.tobytes())
        godot = os.environ.get("GODOT", "godot")
        r = subprocess.run([godot, "--headless", "--path", ".", "-s", GD_SIMPLIFY, "--", src, dst, str(target_tris)],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(dst):
            raise RuntimeError("gd_simplify failed (%d): %s" % (r.returncode, (r.stdout + r.stderr)[-2000:]))
        data = open(dst, "rb").read()
    m = struct.unpack("<I", data[:4])[0]
    out = np.frombuffer(data[4 : 4 + 4 * m], np.uint32).astype(np.int64)
    return used[out].reshape(-1, 3)


def simplify(W, J, target_tris, lock_border):
    if len(J) <= target_tris:
        return J
    if _mo is None:
        return simplify_godot(W, J, target_tris)
    idx = np.ascontiguousarray(J.ravel().astype(np.uint32))
    pos = np.ascontiguousarray(W.astype(np.float32))
    dst = np.zeros(idx.size, np.uint32)
    err = ctypes.c_float(0.0)
    n = _mo.meshopt_simplify(
        dst.ctypes.data_as(U32P), idx.ctypes.data_as(U32P), idx.size, pos.ctypes.data_as(F32P), len(pos), 12,
        target_tris * 3, 1.0, LOCK_BORDER if lock_border else 0, ctypes.byref(err),
    )
    return dst[:n].astype(np.int64).reshape(-1, 3)


def face_normals(V, T):
    n = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    area = np.linalg.norm(n, axis=1)
    return n / np.maximum(area, 1e-12)[:, None], area


def corner_normals(V, T):
    """Per corner: the area-weighted mean of the faces round its vertex within SMOOTH_DEG of its own face."""
    fn, area = face_normals(V, T)
    cos_lim = math.cos(math.radians(SMOOTH_DEG))
    faces_of = [[] for _ in range(len(V))]
    for f, tri in enumerate(T):
        for v in tri:
            faces_of[v].append(f)
    out = np.zeros((len(T), 3, 3))
    for f, tri in enumerate(T):
        for c, v in enumerate(tri):
            fs = np.array(faces_of[v])
            d = fn[fs] @ fn[f]
            sel = fs[d >= cos_lim]
            s = (fn[sel] * area[sel, None]).sum(0)
            ln = np.linalg.norm(s)
            out[f, c] = s / ln if ln > 1e-12 else fn[f]
    return out


# --- bake -----------------------------------------------------------------------------------------------------------


def closest_on_tris(p, a, b, c):
    """Closest points on triangles (a, b, c) to points p (all (n, 3)), with their barycentrics (Ericson 5.1.5)."""
    ab, ac, ap = b - a, c - a, p - a
    d1, d2 = (ab * ap).sum(1), (ac * ap).sum(1)
    bp = p - b
    d3, d4 = (ab * bp).sum(1), (ac * bp).sum(1)
    cp = p - c
    d5, d6 = (ab * cp).sum(1), (ac * cp).sum(1)
    va = d3 * d6 - d5 * d4
    vb = d5 * d2 - d1 * d6
    vc = d1 * d4 - d3 * d2
    denom = np.maximum(va + vb + vc, 1e-30)
    v = vb / denom
    w = vc / denom
    bary = np.stack([1 - v - w, v, w], 1)
    # Regions outside the face (vertex and edge regions).
    m = (d1 <= 0) & (d2 <= 0)
    bary[m] = [1, 0, 0]
    m = (d3 >= 0) & (d4 <= d3)
    bary[m] = [0, 1, 0]
    m = (d6 >= 0) & (d5 <= d6)
    bary[m] = [0, 0, 1]
    m = (vc <= 0) & (d1 >= 0) & (d3 <= 0)
    t = d1 / np.maximum(d1 - d3, 1e-30)
    bary[m] = np.stack([1 - t[m], t[m], np.zeros(m.sum())], 1)
    m = (vb <= 0) & (d2 >= 0) & (d6 <= 0)
    t = d2 / np.maximum(d2 - d6, 1e-30)
    bary[m] = np.stack([1 - t[m], np.zeros(m.sum()), t[m]], 1)
    m = (va <= 0) & ((d4 - d3) >= 0) & ((d5 - d6) >= 0)
    t = (d4 - d3) / np.maximum((d4 - d3) + (d5 - d6), 1e-30)
    bary[m] = np.stack([np.zeros(m.sum()), 1 - t[m], t[m]], 1)
    q = a * bary[:, :1] + b * bary[:, 1:2] + c * bary[:, 2:3]
    return q, bary


class Source:
    """The raw mesh in the game frame, for nearest-surface lookups."""

    def __init__(self, P, UV, I, colour):
        self.P, self.UV, self.I, self.colour = P, UV, I, colour
        self.fn, _ = face_normals(P, I)
        self.tree = cKDTree(P[I].mean(1))

    def nearest(self, pts, normals, k=12):
        _, cand = self.tree.query(pts, k=k)
        best_d = np.full(len(pts), np.inf)
        best_t = np.zeros(len(pts), np.int64)
        best_b = np.zeros((len(pts), 3))
        for j in range(k):
            t = cand[:, j]
            tri = self.I[t]
            q, bary = closest_on_tris(pts, self.P[tri[:, 0]], self.P[tri[:, 1]], self.P[tri[:, 2]])
            d = np.linalg.norm(q - pts, axis=1)
            # A face turned away (the far side of a thin part) only wins when nothing facing the same way is near.
            d = d + (np.einsum("ij,ij->i", self.fn[t], normals) < 0.0) * 0.05
            better = d < best_d
            best_d[better], best_t[better], best_b[better] = d[better], t[better], bary[better]
        return best_t, best_b

    def colour_at(self, t, bary):
        uv = (self.UV[self.I[t]] * bary[:, :, None]).sum(1)
        h, w = self.colour.shape[:2]
        x = np.clip(uv[:, 0] % 1.0 * w - 0.5, 0, w - 1.001)
        y = np.clip(uv[:, 1] % 1.0 * h - 0.5, 0, h - 1.001)
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = (x - x0)[:, None], (y - y0)[:, None]
        c = self.colour
        return (
            c[y0, x0] * (1 - fx) * (1 - fy) + c[y0, x0 + 1] * fx * (1 - fy)
            + c[y0 + 1, x0] * (1 - fx) * fy + c[y0 + 1, x0 + 1] * fx * fy
        )


def dilate(img, filled, passes):
    img = img.copy()
    filled = filled.copy()
    for _ in range(passes):
        acc = np.zeros_like(img)
        cnt = np.zeros(filled.shape)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)):
            sh = np.roll(np.roll(filled, dy, 0), dx, 1)
            acc += np.roll(np.roll(img * filled[..., None], dy, 0), dx, 1)
            cnt += sh
        grow = (~filled) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow, None]
        filled = filled | grow
    img[~filled] = img[filled].mean(0) if filled.any() else 0.5
    return img


# --- enemy parts ----------------------------------------------------------------------------------------------------


def classify_texels(rgb, thr):
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    role_s, glow_v, glow_s = thr
    glow = (mx >= glow_v) & (sat >= glow_s)
    role = (sat >= role_s) & ~glow
    return np.where(glow, 2, np.where(role, 1, 0))


def parts_of(name, W, J, comp, H):
    """Per welded triangle: its part name, and each part's pivot (game frame, metres)."""
    c = W[J].mean(1)
    n = len(J)
    lab = np.array(["body"] * n, dtype=object)
    piv = {"body": np.array([0.0, 0.0, 0.0])}
    tri_comp = comp[J[:, 0]]
    if name == "shield_bearer":
        # The tower shield: the connected pieces in front of the chest; the legs below the hips, left and right.
        sizes = np.bincount(tri_comp)
        cx = np.array([c[tri_comp == k, 0].mean() for k in range(len(sizes))])
        shield = cx > 0.14 * H
        lab[shield[tri_comp]] = "shield"
        ss = shield[tri_comp]
        piv["shield"] = np.array([c[ss, 0].mean(), 0.45 * H, 0.0])
        legs = (~ss) & (c[:, 1] < 0.3 * H)
        for side, nm in ((-1, "leg_l"), (1, "leg_r")):
            m = legs & (np.sign(c[:, 2]) == side)
            lab[m] = nm
            piv[nm] = np.array([c[m, 0].mean(), 0.3 * H, c[m, 2].mean()])
    elif name == "splitter":
        width = W[:, 2].max()
        shoulder = SPLITTER_SHOULDER * width
        arms = (np.abs(c[:, 2]) > shoulder) & (c[:, 1] > 0.18 * H)
        legs = (~arms) & (c[:, 1] < 0.22 * H)
        for side, sfx in ((-1, "l"), (1, "r")):
            m = arms & (np.sign(c[:, 2]) == side)
            lab[m] = "arm_" + sfx
            piv["arm_" + sfx] = np.array([0.0, 0.62 * H, side * shoulder])
            m = legs & (np.sign(c[:, 2]) == side)
            lab[m] = "leg_" + sfx
            piv["leg_" + sfx] = np.array([c[m, 0].mean() if m.any() else 0.0, 0.22 * H, side * 0.3 * width])
            m = (~arms) & (~legs) & (np.sign(c[:, 2] + 1e-9) == side)
            lab[m] = "half_" + sfx
            piv["half_" + sfx] = np.array([0.0, 0.3 * H, 0.0])
        del piv["body"]
    elif name == "mender":
        # The cross crystal floating over the hood (a height band: it touches the hood) and the arms holding the
        # crystals out at the sides (a side band at chest height).
        cross = c[:, 1] > 0.86 * H
        lab[cross] = "cross"
        piv["cross"] = c[cross].mean(0)
        side = W[:, 2].max()
        held = (~cross) & (np.abs(c[:, 2]) > MENDER_ARM_Z * side) & (c[:, 1] > 0.3 * H) & (c[:, 1] < 0.82 * H)
        lab[held] = "crystal"
        piv["crystal"] = np.array([0.0, 0.62 * H, 0.0])
    elif name == "ascension_portal":
        # The crystals floating over the dais (pieces of their own that start above PORTAL_FLOAT of the height) each
        # turn and bob in code: one part per crystal (`shard_00` ...), its pivot at its centre.
        k_n = tri_comp.max() + 1
        lo = np.full(k_n, np.inf)
        np.minimum.at(lo, tri_comp, W[J].min(1)[:, 1])
        k_out = 0
        for k in np.argsort(-np.bincount(tri_comp, minlength=k_n)):
            if lo[k] > PORTAL_FLOAT * H:
                m = tri_comp == k
                nm = "shard_%02d" % k_out
                lab[m] = nm
                piv[nm] = c[m].mean(0)
                k_out += 1
    elif name == "lens_drone":
        # Its little hanging feet (below the pod's belly band) turn as one piece: the ring.
        m = c[:, 1] < 0.16 * H
        lab[m] = "ring"
        piv["ring"] = np.array([0.0, 0.1 * H, 0.0])
    return lab, piv


# --- glb out --------------------------------------------------------------------------------------------------------


def pad4(b, fill=b"\0"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write_glb(path, name, nodes, jpeg, materials):
    """nodes: [(node name, translation, [(material index, positions, normals, uvs, indices)])]."""
    blob = b""
    views, accs, meshes, gnodes = [], [], [], []

    def add(arr, target, comp, typ, minmax=False):
        nonlocal blob
        data = np.ascontiguousarray(arr).tobytes()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob = pad4(blob + data)
        a = {"bufferView": len(views) - 1, "componentType": comp, "count": len(arr), "type": typ}
        if minmax:
            a["min"] = arr.min(0).tolist()
            a["max"] = arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    for nname, tr, prims in nodes:
        gp = []
        for mat, pos, nrm, uv, idx in prims:
            gp.append({
                "attributes": {
                    "POSITION": add(pos.astype(np.float32), 34962, 5126, "VEC3", True),
                    "NORMAL": add(nrm.astype(np.float32), 34962, 5126, "VEC3"),
                    "TEXCOORD_0": add(uv.astype(np.float32), 34962, 5126, "VEC2"),
                },
                "indices": add(idx.astype(np.uint32).ravel(), 34963, 5125, "SCALAR"),
                "material": mat,
                "mode": 4,
            })
        meshes.append({"name": nname, "primitives": gp})
        gnodes.append({"name": nname, "mesh": len(meshes) - 1, "translation": [float(x) for x in tr]})
    views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(jpeg)})
    blob = pad4(blob + jpeg)
    gltf = {
        "asset": {"version": "2.0", "generator": "zero-depth scripts/assets/mi_prep.py (from the owner's Tripo file)"},
        "scene": 0,
        "scenes": [{"nodes": [len(gnodes)]}],
        "nodes": gnodes + [{"name": name, "children": list(range(len(gnodes)))}],
        "meshes": meshes,
        "materials": materials,
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"name": "albedo", "bufferView": len(views) - 1, "mimeType": "image/jpeg"}],
        "accessors": accs,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    js = pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0") + blob)


def material(name, emissive=None):
    m = {"name": name, "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0,
                                                "roughnessFactor": 1.0}}
    if emissive is not None:
        m["emissiveFactor"] = emissive
    return m


# --- one model ------------------------------------------------------------------------------------------------------


def prepare(rid):
    role, folder, height, yaw = SPECS[rid]
    budget, tex_px = BUDGET[role]
    src_path = os.path.join(SRC, rid + ".glb")
    P0, UV, I, colour = read_glb(src_path)
    P, yaw = to_game_frame(P0, height, yaw)
    source = Source(P, UV, I, colour)
    ext = P.max(0) - P.min(0)
    W, J, keep = weld(P, I, ext.max() * 2e-5)
    J = J[keep]
    enemy = folder == "enemies"
    # Labels per welded triangle: (part, texel class).
    if enemy:
        comp = components(len(W), J)
        part, pivots = parts_of(rid, W, J, comp, height)
        # Each welded triangle's class from the raw colour at its centre.
        cen = W[J].mean(1)
        fn, _ = face_normals(W, J)
        t, b = source.nearest(cen, fn, k=6)
        cls = classify_texels(source.colour_at(t, b), CLASS_THRESHOLDS[rid])
    elif rid in PARTED:
        # A device with moving pieces (the Ascension portal's floating crystals): parts, one material.
        comp = components(len(W), J)
        part, pivots = parts_of(rid, W, J, comp, height)
        cls = np.zeros(len(J), int)
    else:
        part = np.array(["body"] * len(J), dtype=object)
        pivots = {"body": np.zeros(3)}
        cls = np.zeros(len(J), int)
    # Simplified apart: each part, and in it the glowing accents (small; they must survive), borders locked. The
    # grey and role-coloured triangles are told apart after (their borders interleave too finely to lock).
    glow = np.where(cls == 2, 2, 0)
    groups = sorted({(p, k) for p, k in zip(part, glow)}, key=lambda g: (g[0], g[1]))
    total = len(J)
    scale = 1.0
    for _attempt in range(6):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (glow == g[1])
            share = max(int(round(budget * scale * m.sum() / total)), 24 if g[1] == 2 else 12)
            simplified[g] = simplify(W, J[m], share, lock_border=len(groups) > 1)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= budget * 1.02:
            break
        scale *= budget / tris_after * 0.97  # locked borders kept more than asked: ask the rest for less
    if enemy:
        # The grey / role split of each simplified triangle, from the raw colour nearest its centre.
        for g in groups:
            if g[1] == 2 or len(simplified[g]) == 0:
                continue
            T = simplified[g]
            fn, _ = face_normals(W, T)
            t, b = source.nearest(W[T].mean(1), fn, k=6)
            simplified[g] = (T, classify_texels(source.colour_at(t, b), CLASS_THRESHOLDS[rid]).clip(0, 1))
    for g in groups:
        if not isinstance(simplified[g], tuple):
            simplified[g] = (simplified[g], np.full(len(simplified[g]), g[1]))
    # One atlas over every part (one shared colour map).
    atlas = xatlas.Atlas()
    order = sorted(pivots)
    per_part = {}
    for pn in order:
        T = np.concatenate([simplified[g][0] for g in groups if g[0] == pn] or [np.zeros((0, 3), np.int64)])
        K = np.concatenate([simplified[g][1] for g in groups if g[0] == pn] or [np.zeros(0, int)])
        if len(T) == 0:
            continue
        used, inv = np.unique(T.ravel(), return_inverse=True)
        V = W[used]
        Tl = inv.reshape(-1, 3)
        per_part[pn] = (V, Tl, K)
        fnv = np.zeros_like(V)
        fn, area = face_normals(V, Tl)
        for c3 in range(3):
            np.add.at(fnv, Tl[:, c3], fn * area[:, None])
        fnv /= np.maximum(np.linalg.norm(fnv, axis=1), 1e-12)[:, None]
        atlas.add_mesh(V.astype(np.float32), Tl.astype(np.uint32), fnv.astype(np.float32))
    copt = xatlas.ChartOptions()
    copt.max_iterations = 2
    popt = xatlas.PackOptions()
    popt.resolution = tex_px
    popt.padding = PAD_PX // 2
    popt.bilinear = True
    popt.rotate_charts = True
    atlas.generate(copt, popt)
    while atlas.atlas_count > 1:  # every chart on one page: shrink the texel density until it fits
        popt.texels_per_unit = atlas.texels_per_unit * 0.9
        atlas.generate(copt, popt)
    img = np.zeros((tex_px, tex_px, 3))
    filled = np.zeros((tex_px, tex_px), bool)
    nodes = []
    names = [pn for pn in order if pn in per_part]
    for mi, pn in enumerate(names):
        V, Tl, K = per_part[pn]
        vmap, idx, uvs = atlas[mi]
        idx = idx.astype(np.int64)
        pos = V[vmap]
        corner_n = corner_normals(V, Tl)
        # Map xatlas's corners back to the input faces (xatlas keeps the face order).
        uv_px = uvs * np.array([atlas.width, atlas.height])
        uv_px = uv_px * (tex_px / max(atlas.width, atlas.height, 1))
        fnp, _ = face_normals(pos, idx)
        p3, n3, wh = rasterise_faces(uv_px, idx, pos, fnp, tex_px)
        if len(p3):
            t, b = source.nearest(p3, n3)
            img[wh[:, 1], wh[:, 0]] = source.colour_at(t, b)
            filled[wh[:, 1], wh[:, 0]] = True
        # Flat corners: each face its own three vertices (the split normals).
        cp = pos[idx].reshape(-1, 3)
        cn = corner_n.reshape(-1, 3)
        cu = (uvs[idx] * np.array([atlas.width, atlas.height]) / max(atlas.width, atlas.height, 1)).reshape(-1, 2)
        prims = []
        for k in (0, 1, 2):
            sel = np.where(K == k)[0]
            if len(sel) == 0:
                continue
            ci = (sel[:, None] * 3 + np.arange(3)[None]).ravel()
            pv = cp[ci] - pivots[pn]
            prims.append((k if enemy else 0, pv, cn[ci], cu[ci], np.arange(len(ci)).reshape(-1, 3)))
        nodes.append((pn, pivots[pn], prims))
    img = dilate(img, filled, PAD_PX * 2)
    if not enemy and filled.any():
        # As kit_prep's MODEL_MEAN (the generator's maps average about 0.25 and read black under the night moods),
        # gentler: the charts' mean brought up toward BRIGHT_MEAN, by at most BRIGHT_MAX (snow and ice stay as they are).
        gain = min(max(BRIGHT_MEAN / max(img[filled].mean(), 1e-3), 1.0), BRIGHT_MAX)
        img = np.clip(img * gain, 0.0, 1.0)
    if enemy:
        # The role plates' texels in greyscale (the game multiplies them by the kind's role colour).
        cls_px = classify_texels(img, CLASS_THRESHOLDS[rid])
        lum = img @ np.array([0.299, 0.587, 0.114])
        role_px = cls_px == 1
        if role_px.any():
            g = np.clip(lum / max(lum[role_px].mean(), 1e-3) * 0.82, 0, 1)
            img[role_px] = g[role_px, None]
    buf = io.BytesIO()
    Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8)).save(buf, "JPEG", quality=JPEG_QUALITY)
    mats = [material("base"), material("role"), material("glow", [1.0, 1.0, 1.0])] if enemy else [material("albedo")]
    out_id = INSTALL_AS.get(rid, rid)
    os.makedirs(OUT[folder], exist_ok=True)
    dst = os.path.join(OUT[folder], out_id + ".glb")
    write_glb(dst, out_id, nodes, buf.getvalue(), mats)
    return {
        "raw": rid, "id": out_id, "raw_tris": len(I), "raw_bytes": os.path.getsize(src_path), "tris": tris_after,
        "budget": budget, "tex": tex_px, "yaw": yaw, "path": dst, "bytes": os.path.getsize(dst),
        "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
        "parts": {pn: [len(per_part[pn][1]), [round(float(x), 3) for x in pivots[pn]]] for pn in names},
        "size": [round(float(x), 3) for x in ext],
    }


def rasterise_faces(uv_px, idx, pos, fnp, size):
    pts, nrms, where = [], [], []
    for f, t in enumerate(idx):
        a, b, c = uv_px[t[0]], uv_px[t[1]], uv_px[t[2]]
        x0 = max(int(math.floor(min(a[0], b[0], c[0]) - 1)), 0)
        x1 = min(int(math.ceil(max(a[0], b[0], c[0]) + 1)), size - 1)
        y0 = max(int(math.floor(min(a[1], b[1], c[1]) - 1)), 0)
        y1 = min(int(math.ceil(max(a[1], b[1], c[1]) + 1)), size - 1)
        if x1 < x0 or y1 < y0:
            continue
        m = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
        det = m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]
        if abs(det) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        g = np.stack([gx.ravel(), gy.ravel()], 1)
        st = np.linalg.solve(m, (g - a).T).T
        bary = np.stack([1 - st[:, 0] - st[:, 1], st[:, 0], st[:, 1]], 1)
        e = 0.75 / max(math.sqrt(abs(det)), 1e-6)
        inside = (bary >= -e).all(1)
        if not inside.any():
            continue
        bary = np.clip(bary[inside], 0, 1)
        bary /= bary.sum(1, keepdims=True)
        pts.append(pos[t[0]] * bary[:, :1] + pos[t[1]] * bary[:, 1:2] + pos[t[2]] * bary[:, 2:3])
        nrms.append(np.repeat(fnp[f][None], len(bary), 0))
        where.append(g[inside].astype(int))
    if not pts:
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 2), int)
    return np.concatenate(pts), np.concatenate(nrms), np.concatenate(where)


# --- ground_star and the crack masks ----------------------------------------------------------------------------

GROUND_PX = 1024
CRACK_CELL = 512  # four crack shapes, 2 x 2 in one 1024 px mask
CRACK_SEED = 80018


def seamless_blend(img):
    """Offset by half, keep the original in the middle and the offset copy at the edges (a wide feather; kit_prep)."""
    h, w = img.shape[:2]
    rolled = np.roll(np.roll(img, h // 2, axis=0), w // 2, axis=1)
    y = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h / 2)
    x = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w / 2)
    m = np.outer(np.clip((y - 0.15) / 0.5, 0, 1), np.clip((x - 0.15) / 0.5, 0, 1))[..., None]
    m = m * m * (3 - 2 * m)
    return img * m + rolled * (1 - m)


def crack_cell(rng):
    """One crack shape: jagged branching polylines from a few points near the middle out to all four edges (so the
    pool's extent still reads), their width tapering from trunk to tip. R: the crack itself (soft-edged), G: a wider
    soft halo round it (the starlight's glow), 0..255."""
    from PIL import ImageDraw, ImageFilter

    size = CRACK_CELL
    core = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(core)
    centre = np.array([size / 2, size / 2]) + rng.uniform(-60, 60, 2)

    def walk(p, base, width, depth):
        # Jagged: each segment turns off a slowly drifting heading (a zigzag, not a meander); a branch is shorter
        # and thinner than its parent.
        steps = {0: 999, 1: 9, 2: 5}.get(depth, 3)
        while 0 <= p[0] < size and 0 <= p[1] < size and width > 0.9 and steps > 0:
            steps -= 1
            base += rng.normal(0, 0.08)
            ang = base + rng.normal(0, 0.5)
            q = p + rng.uniform(18, 34) * np.array([math.cos(ang), math.sin(ang)])
            d.line([tuple(p), tuple(q)], fill=255, width=max(int(round(width)), 1))
            d.ellipse([q[0] - width / 2, q[1] - width / 2, q[0] + width / 2, q[1] + width / 2], fill=255)
            p = q
            width *= rng.uniform(0.955, 0.985)
            if depth < 2 and rng.random() < 0.12:
                walk(p.copy(), base + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), width * 0.5, depth + 1)

    # Four trunks toward the four edges (and a fifth anywhere), so every pool's crack reaches its rim on all sides.
    for k in range(4):
        walk(centre.copy(), k * math.pi / 2 + rng.uniform(-0.5, 0.5), rng.uniform(30, 42), 0)
    walk(centre.copy(), rng.uniform(0, 2 * math.pi), rng.uniform(18, 24), 1)
    soft = core.filter(ImageFilter.GaussianBlur(2.5))
    halo = core.filter(ImageFilter.GaussianBlur(22))
    return np.asarray(soft), np.minimum(np.asarray(halo).astype(float) * 1.8, 255)


def prepare_ground_star():
    os.makedirs(TEX_OUT, exist_ok=True)
    src = Image.open(os.path.join(SRC, "ground_star.webp")).convert("RGB")
    w, h = src.size
    s = min(w, h)
    sq = src.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
    a = np.asarray(sq).astype(float)
    tex = Image.fromarray(seamless_blend(a).round().clip(0, 255).astype(np.uint8)).resize(
        (GROUND_PX, GROUND_PX), Image.LANCZOS
    )
    out = []
    p = os.path.join(TEX_OUT, "ground_star.png")
    tex.save(p)
    out.append(p)
    rng = np.random.default_rng(CRACK_SEED)
    mask = np.zeros((GROUND_PX, GROUND_PX, 3), np.uint8)
    for k in range(4):
        core, halo = crack_cell(rng)
        y, x = (k // 2) * CRACK_CELL, (k % 2) * CRACK_CELL
        mask[y : y + CRACK_CELL, x : x + CRACK_CELL, 0] = core
        mask[y : y + CRACK_CELL, x : x + CRACK_CELL, 1] = halo.astype(np.uint8)
    p = os.path.join(TEX_OUT, "ground_star_cracks.png")
    Image.fromarray(mask).save(p)
    out.append(p)
    for p in out:
        print(json.dumps({"id": os.path.basename(p)[:-4], "path": p, "bytes": os.path.getsize(p),
                          "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()}))


def main():
    ids = sys.argv[1:] or sorted(SPECS) + ["ground_star"]
    rows = []
    for rid in ids:
        if rid == "ground_star":
            prepare_ground_star()
            continue
        r = prepare(rid)
        rows.append(r)
        print(json.dumps(r))
    return 0


if __name__ == "__main__":
    sys.exit(main())
