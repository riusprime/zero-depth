"""Prepares the owner's Bomb Drone (unprocessed_images/models_v0120_b/bomb_drone.glb) for the game:
assets/models/enemies/bomb_drone.glb, cut into the parts BombDroneAvatar animates.

The raw file is a Tripo export: one textured mesh (4,622 triangles, a 2048 px colour map, its own smooth normals), one
piece, 0.59 units tall and 1.0 wide, no rig, Y up, its front (the charcoal shield face plate with its small yellow gem
visor, low on the nose) on +Z: a rounded body under a ridged shell in bomber yellow, a charcoal steel belly, four grey
segmented arms with bone joints reaching out to the sides in an X (two high and back, two low and forward), each ending
in a round grey rotor housing with a flat two-bladed rotor on top, and a cradle of bone-jointed claws hanging under the
belly. It carries no bomb: the avatar hangs its own in the cradle. The raw file stays untouched. This script, reusing
mi_prep's reader and glb writer and the Frost Spitter prep's colour sampling and cut caps:
1. turns it to the game's frame (+X the front: a quarter turn about +Y), centres it on x/z with the claws' lowest point on
   y = 0, at its own size (1.0 m across the rotors: the old code drone's span, so the scale is 1);
2. cuts it into the parts that move, by place: the hull (shell, belly, face plate; the rig's root), the four arms with
   their housings (outside ARM_Z of the middle, high or low; their pivots at the root on the body), the four rotors
   (each one's blades and hub cap, found in the thin band of the blade plane round the hub; pivot on the hub's axis in
   the blade plane) and the claw cradle (under CRADLE_Y; pivot at the middle of the belly's underside). Every part
   node's origin is its pivot;
3. caps the cuts (a fan over each part's cut edges facing the part across the cut, within CAP_R of its middle; none
   between a rotor and its housing), in the charcoal of the belly;
4. sorts each triangle into a surface by the colour map under it: `glow` (the visor's gem), `role` (the yellow paint of
   the shell, by role_map's rules: the texels under the role triangles greyscale in the map so the game tints them in
   the kind's role colour) and `base` (the charcoal steel, the greys, the bone joints);
5. keeps every triangle (under the 5k budget: no simplification), the owner's UVs, the owner's own normals (turned with
   the mesh: the model shades as delivered) and colour map, halved to TEX_PX;
6. writes assets/models/enemies/bomb_drone.glb (one node per part, three materials base / role / glow).
It prints one JSON line: the raw triangles and size, the triangles after (per part: total, glow, role, the pivot), the
caps, the size in metres, the file written, its size and sha256 (pasted into assets/models/manifest.json by hand).

Run from the repo root:  python scripts/assets/bomb_drone_prep.py
Needs numpy, Pillow, scipy (mi_prep's imports; xatlas is stubbed when missing: this script never calls it).
"""

import hashlib
import io
import json
import os
import struct
import sys
import types

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import xatlas  # noqa: F401  (mi_prep imports it at the top; this script keeps the owner's UVs instead)
except ImportError:
    sys.modules["xatlas"] = types.ModuleType("xatlas")
import frost_spitter_prep as fsp  # noqa: E402  (the colour sampling, the cut caps)
import role_map  # noqa: E402

mi_prep = fsp.mi_prep

SRC = "unprocessed_images/models_v0120_b/bomb_drone.glb"
DST = "assets/models/enemies/bomb_drone.glb"
ID = "bomb_drone"
TEX_PX = 1024

# Places in raw units (metres: the scale is 1), the game frame (+X front, +Z the drone's right, the claws' low point on
# y = 0, centred on x/z).
## The hull's pivot (the rig turns about it): the body's middle.
HULL = (0.0, 0.35, 0.0)
## Off the middle by more than ARM_Z (and not the shell's yellow) it is an arm; above ARM_SPLIT_Y an upper one.
ARM_Z = 0.2
ARM_SPLIT_Y = 0.33
## Each rotor's hub cap (the bone cap on top of the housing, about where the axis is): [arm, cap]. "r" / "l": the
## drone's right (+Z) and left; "u" / "d": the upper and lower pair.
HUBS = (
    ("ur", (-0.099, 0.561, 0.342)),
    ("ul", (-0.192, 0.543, -0.329)),
    ("dr", (0.042, 0.159, 0.328)),
    ("dl", (0.051, 0.168, -0.349)),
)
## The blade plane is found between BLADE_R (outside the housing) and the blade's reach, round the cap; a triangle within
## BLADE_BAND of it (or within BLADE_EDGE out past BLADE_R), or the cap's within HUB_R of the axis, is the rotor's.
BLADE_R = 0.08
BLADE_REACH = 0.17
BLADE_BAND = 0.012
BLADE_EDGE = 0.02
HUB_R = 0.035
## The housing (its middle is the rotor's axis): within HOUSING_R of the cap, under the blades.
HOUSING_R = 0.1
## A cut cap's triangles reach at most CAP_R from the fan's middle.
CAP_R = 0.06
## Under CRADLE_Y (within ARM_Z of the middle) it is the claw cradle; its pivot at the belly's underside.
CRADLE_Y = 0.165
CRADLE = (0.0, 0.17, 0.0)
## The visor's gem: within VISOR_R of VISOR_C, bright yellow.
VISOR_C = (0.236, 0.252, 0.0)
VISOR_R = 0.05


def lum_of(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def role_texels(rgb):
    """The yellow paint: saturated, red and green over blue, not dark."""
    return (fsp.sat_of(rgb) >= 0.45) & (rgb[..., 0] >= 0.35) & (rgb[..., 1] >= rgb[..., 2] + 0.1)


def visor_texels(rgb):
    """The gem's bright yellow."""
    return (lum_of(rgb) >= 0.55) & (fsp.sat_of(rgb) >= 0.4) & (rgb[..., 0] >= 0.75)


def read_normals(path):
    """The raw file's own vertex normals (the POSITION order mi_prep.read_glb returns)."""
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20 : 20 + n])
    blob = data[28 + n : 28 + n + struct.unpack("<I", data[20 + n : 24 + n])[0]]
    a = j["accessors"][j["meshes"][0]["primitives"][0]["attributes"]["NORMAL"]]
    bv = j["bufferViews"][a["bufferView"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(blob, np.float32, a["count"] * 3, o).reshape(-1, 3).astype(np.float64)


def load():
    """The raw mesh in the game frame, welded by position, UV and normal (so the owner's normals stay as delivered):
    (welded positions, their UVs, their normals, triangles, the position-weld index, the colour map, the bounds, the raw
    triangle count)."""
    P0, UV, I0, colour = mi_prep.read_glb(SRC)
    N0 = read_normals(SRC)
    P0 = np.stack([P0[:, 2], P0[:, 1], -P0[:, 0]], 1)  # a quarter turn about +Y: the raw +Z front to +X
    N0 = np.stack([N0[:, 2], N0[:, 1], -N0[:, 0]], 1)
    lo, hi = P0.min(0), P0.max(0)
    raw = P0 - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    eps = (hi - lo).max() * 2e-5
    key = np.concatenate([np.round(raw / eps), np.round(UV * 1e6), np.round(N0 * 1e4)], 1).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    J = inv[I0]
    J = J[(J[:, 0] != J[:, 1]) & (J[:, 1] != J[:, 2]) & (J[:, 0] != J[:, 2])]
    W = raw[first]
    _, pinv = np.unique(np.round(W / eps).astype(np.int64), axis=0, return_inverse=True)
    Nw = N0[first]
    Nw = Nw / np.maximum(np.linalg.norm(Nw, axis=1, keepdims=True), 1e-12)
    return W, UV[first], Nw, J, pinv.ravel(), colour, (lo, hi), len(I0)


def parts_of(W, J, tcol):
    """Per triangle: its part; and each part's pivot."""
    c = W[J].mean(1)
    n = len(c)
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab = np.array(["hull"] * n, dtype=object)
    piv = {"hull": np.asarray(HULL)}
    yellow = role_texels(tcol)
    out = (np.abs(z) > ARM_Z) & ~yellow
    for name, cap in HUBS:
        side = 1.0 if name[1] == "r" else -1.0
        upper = name[0] == "u"
        arm = out & (z * side > 0) & ((y > ARM_SPLIT_Y) == upper)
        lab[arm] = "arm_" + name
        cap = np.asarray(cap)
        # The blade plane: the median height of the arm's triangles out past the housing round the cap.
        r0 = np.hypot(x - cap[0], z - cap[2])
        tips = arm & (r0 > BLADE_R) & (r0 < BLADE_REACH) & (np.abs(y - cap[1]) < 0.04)
        yb = float(np.median(y[tips]))
        # The axis: the middle of the round housing under the blades (the blades are not quite opposite).
        house = arm & (r0 < HOUSING_R) & (y < yb - 0.025) & (y > yb - 0.1)
        Ph = W[J[house]].reshape(-1, 3)
        ax = np.array([(Ph[:, 0].min() + Ph[:, 0].max()) / 2, yb, (Ph[:, 2].min() + Ph[:, 2].max()) / 2])
        r = np.hypot(x - ax[0], z - ax[2])
        dy = y - yb
        rotor = arm & (
            ((np.abs(dy) < BLADE_BAND) & (r < BLADE_REACH))
            | ((np.abs(dy) < BLADE_EDGE) & (r > BLADE_R) & (r < BLADE_REACH))
            | ((r < HUB_R) & (dy > -BLADE_BAND) & (dy < 0.03))
        )
        lab[rotor] = "rotor_" + name
        piv["rotor_" + name] = ax
        root = arm & ~rotor & (np.abs(z) < ARM_Z + 0.03)
        piv["arm_" + name] = np.array([x[root].mean(), y[root].mean(), side * ARM_Z])
    cradle = (y < CRADLE_Y) & (np.abs(z) < ARM_Z) & (lab == "hull")
    lab[cradle] = "cradle"
    piv["cradle"] = np.asarray(CRADLE)
    return lab, piv


def main():
    W, UVw, Nw, J, pinv, colour, (lo, hi), raw_tris = load()
    cen = W[J].mean(1)
    tcol = fsp.tri_colour(colour, UVw, J)
    part, pivots = parts_of(W, J, tcol)
    glow = np.zeros(len(J), int)
    near_visor = np.linalg.norm(cen - np.asarray(VISOR_C), axis=1) < VISOR_R
    glow[(part == "hull") & near_visor & visor_texels(tcol)] = 2
    order = [pn for pn in sorted(pivots) if (part == pn).any()]
    per_part = {pn: J[part == pn] for pn in order}
    # No caps between a rotor and its housing: the blade band's cut edges are scattered over the thin blades, so a fan
    # over them draws dark wedges, and the housing's top is closed under the blades anyway.
    joined = {pn: T for pn, T in per_part.items() if not pn.startswith("rotor_")}
    for pn in per_part:
        if pn.startswith("rotor_"):
            joined["arm_" + pn[6:]] = np.concatenate([joined["arm_" + pn[6:]], per_part[pn]])
    caps = fsp.cut_caps(joined, pinv, W, set(), set())
    # A fan's triangles reaching past CAP_R from its middle are dropped: where the arms' cut runs along the shell's paint
    # edge its cut edges scatter, and a fan over them draws dark wedges across the shell.
    caps = {
        pn: [(surf, t[np.linalg.norm(t - t[:, 2:3], axis=2).max(1) < CAP_R]) for surf, t in lst]
        for pn, lst in caps.items()
    }
    lum = lum_of(tcol)
    belly = (part == "hull") & (cen[:, 1] < 0.25)
    dark_uv = UVw[J[belly][np.argmin(np.where(lum[belly] > 0.03, lum[belly], 9.0))]].mean(0)
    nodes, report, cap_report = [], {}, {}
    role_tris, other_tris = [], []
    for pn in order:
        T = per_part[pn]
        K = glow[part == pn].copy()
        rest = K != 2
        K[rest] = (role_map.texel_share(colour, UVw, T[rest], role_texels) >= role_map.ROLE_SHARE).astype(int)
        role_tris.append(T[K == 1])
        other_tris.append(T[K != 1])
        pivot = pivots[pn]
        prims = []
        for k in (0, 1, 2):
            sel = np.where(K == k)[0]
            pos_l, nrm_l, uv_l = [], [], []
            if len(sel):
                Ts = T[sel]
                pos_l.append(W[Ts].reshape(-1, 3) - pivot)
                nrm_l.append(Nw[Ts].reshape(-1, 3))
                uv_l.append(UVw[Ts].reshape(-1, 2))
            for surf, tris in caps.get(pn, []):
                if surf != k or not len(tris):
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
    img = role_map.tinted_map(colour, UVw, np.concatenate(role_tris), np.concatenate(other_tris), role_texels)
    pil = Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8))
    if pil.size[0] > TEX_PX:
        pil = pil.resize((TEX_PX, TEX_PX), Image.LANCZOS)
    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    mats = [mi_prep.material("base"), mi_prep.material("role"), mi_prep.material("glow", [1.0, 1.0, 1.0])]
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    mi_prep.write_glb(DST, ID, nodes, buf.getvalue(), mats)
    ext = hi - lo
    print(json.dumps({
        "id": ID, "raw": SRC, "raw_tris": raw_tris, "raw_bytes": os.path.getsize(SRC),
        "tris": int(sum(len(v) for v in per_part.values())), "caps": cap_report, "tex": TEX_PX,
        "size": [round(float(v), 3) for v in ext], "path": DST, "bytes": os.path.getsize(DST),
        "sha256": hashlib.sha256(open(DST, "rb").read()).hexdigest(),
        "parts": report,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
