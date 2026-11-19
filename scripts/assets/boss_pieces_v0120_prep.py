"""Prepares the owner's four boss attack pieces (unprocessed_images/models_v0120/{javelin,war_banner,hour_clock,
siege_cart}.glb; OWNER_TODO §3.5) and writes them as assets/models/fx/<id>.glb, cut into the parts the game moves.

Each raw file is a Tripo export: one welded mesh (about 4.5-4.9k triangles, so its parts cannot be told apart by
connection), one 2048 px colour map, Y up, about 1 unit on its long side, base on y = 0. Per piece this script:
- javelin: the raw spear lies on a slant (its length runs about (0.60, 0.78, -0.16)); its main axis (the mesh's first
  principal direction) is turned onto +X, the crystal head toward +X, the butt at x = 0, the raw front (+Z) kept as
  near +Z as the turn allows, scaled to LENGTH. One part: `javelin`.
- war_banner: scaled to its height (BANNER_H). The cloth is the triangles in the cloth's height band (CLOTH_Y) that
  lie off the pole (farther than POLE_R from its axis); it gets a second UV set (TEXCOORD_1: x across 0..1, y down
  from its top 0..1) for the game's wave and burn. The rest is split at SNAP_Y (a triangle's centre above it is in the
  top, the part a charge snaps off with the cloth: the upper pole, the crossbar and the spearhead; the rest is the
  stump). Parts: `pole`, `top`, `cloth`; the cloth hangs on the +Z side.
- hour_clock: scaled to its width (CLOCK_W), its origin at the hands' hub (HUB) so the minute hand turns about Z
  there. The minute hand is the triangles in front of the dial (z > HAND_Z) within HAND_HALF_W of its axis (HAND_DEG
  from +X) from HAND_FROM to HAND_TO out from the hub. Parts: `clock` (case, dial, hour hand, hub) and
  `minute_hand`; the face looks along +Z.
- siege_cart: turned half a turn about Y (the raw tow bar is on -X; the game's front is +X), centred on x/z, base on
  y = 0, scaled to its length (CART_L). Each wheel is the triangles whose corners all lie within WHEEL_R of its hub (WHEELS, raw) on its
  side's outer face (|z| > WHEEL_Z), written about its hub (its node translated there) so the game can turn it about
  its local Z. Parts: `body`, `wheel_0`..`wheel_3`.
The colour map is resized to TEXTURE_PX (the kit's budget) and brightened toward MODEL_MEAN as the room pieces are
(rooms_v0120_prep.piece_texture: never darkened, at most BRIGHT_MAX), shared by every part of a piece. Normals and UVs
are the owner's. The raw files stay untouched. It prints one JSON line: per piece its triangles (and per part), size
(m, x/z/y), extra facts the game reads (the javelin's head share, the wheels' radius), the file's size and sha256
(paste the sha256 into assets/models/manifest.json by hand).

Run from the repo root:  python3 scripts/assets/boss_pieces_v0120_prep.py [ids...]   (needs numpy and Pillow)
"""

import hashlib
import json
import math
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rooms_v0120_prep import pad4, piece_texture, read_glb  # noqa: E402

SRC = "unprocessed_images/models_v0120"
OUT = "assets/models/fx"
IDS = ["javelin", "war_banner", "hour_clock", "siege_cart"]

## The request rows (OWNER_TODO §3.5), metres.
LENGTH = 2.0
BANNER_H = 3.2
CLOCK_W = 0.7
CART_L = 2.0
## The javelin's head: where along it (a share of its length from the butt) the red crystal starts, read from the map.
HEAD_RED = 0.15
## The banner (raw units): the cloth's height band, the pole's radius round its axis, the snap line.
CLOTH_Y = (0.25, 0.695)
POLE_R = 0.026
SNAP_Y = 0.2
## The clock (raw units): the hands' hub, the minute hand's axis (degrees from +X), its reach and half width, and the
## plane in front of the dial it stands over.
HUB = (0.0015, 0.3487)
HAND_DEG = 22.0
HAND_FROM = 0.045
HAND_TO = 0.26
HAND_HALF_W = 0.035
HAND_Z = 0.042
## The cart (raw units): the wheels' hubs (x, y, side), their radius, and the side faces' depth they stand outside of.
WHEELS = [(-0.055, 0.137, 1), (0.332, 0.138, 1), (-0.058, 0.133, -1), (0.327, 0.138, -1)]
WHEEL_R = 0.14
WHEEL_Z = 0.195


def unit(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)


def compact(P, N, UV, I, tris):
    """The triangles `tris` as their own vertex arrays, re-indexed."""
    used, inv = np.unique(I[tris].ravel(), return_inverse=True)
    return P[used], N[used], UV[used], inv.reshape(-1, 3)


# --- the pieces --------------------------------------------------------------------------------------------------------


def javelin(P, N, UV, I, img):
    m = P.mean(0)
    _, _, vt = np.linalg.svd(P - m, full_matrices=False)
    ax = vt[0]
    if ((P - m) @ ax).max() < -((P - m) @ ax).min():  # the head (the wider end) toward +X
        ax = -ax
    t = (P - m) @ ax
    hi = P[t > t.max() - 0.15] - m
    lo = P[t < t.min() + 0.15] - m
    perp = lambda q: np.linalg.norm(q - np.outer(q @ ax, ax), axis=1).max()  # noqa: E731
    if perp(lo) > perp(hi):
        ax = -ax
    z = np.array([0.0, 0.0, 1.0]) - ax[2] * ax
    z = unit(z)
    y = np.cross(z, ax)
    R = np.stack([ax, y, z])  # rows: the game's x, y, z in raw terms
    Q = (P - m) @ R.T
    lo, hi = Q.min(0), Q.max(0)
    Q = Q - np.array([lo[0], (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2])
    s = LENGTH / (hi[0] - lo[0])
    # How far along the red crystal starts: the first share of the length whose triangles are mostly red.
    px = np.asarray(img).astype(np.float64) / 255.0
    h, w = px.shape[:2]
    uvc = UV[I].mean(1)
    col = px[np.clip((uvc[:, 1] * h).astype(int), 0, h - 1), np.clip((uvc[:, 0] * w).astype(int), 0, w - 1)]
    red = col[:, 0] > col[:, 1] + HEAD_RED
    along = Q[I].mean(1)[:, 0] / (hi[0] - lo[0])
    head = 1.0
    for k in range(100, 0, -1):
        sel = (along >= (k - 1) / 100) & (along < k / 100)
        if sel.any() and red[sel].mean() < 0.5:
            head = k / 100
            break
    parts = {"javelin": (Q * s, unit(N @ R.T), UV, I, None, None)}
    return parts, {"head_from": round(head, 3)}


def war_banner(P, N, UV, I, img):
    s = BANNER_H / (P[:, 1].max() - P[:, 1].min())
    C = P[I].mean(1)
    band = (C[:, 1] > 0.12) & (C[:, 1] < 0.24)
    axis = C[band][:, [0, 2]].mean(0)
    r = np.hypot(C[:, 0] - axis[0], C[:, 2] - axis[1])
    cloth = (C[:, 1] > CLOTH_Y[0]) & (C[:, 1] < CLOTH_Y[1]) & (r > POLE_R)
    top = ~cloth & (C[:, 1] > SNAP_Y)
    pole = ~cloth & ~top
    off = np.array([axis[0], P[:, 1].min(), axis[1]])
    parts = {}
    for name, sel in (("pole", pole), ("top", top), ("cloth", cloth)):
        p, n, uv, idx = compact(P, N, UV, I, np.nonzero(sel)[0])
        uv2 = None
        if name == "cloth":
            lo, hi = p.min(0), p.max(0)
            uv2 = np.stack([(p[:, 0] - lo[0]) / (hi[0] - lo[0]), (hi[1] - p[:, 1]) / (hi[1] - lo[1])], 1)
        parts[name] = ((p - off) * s, n, uv, idx, uv2, None)
    ci = np.unique(I[cloth].ravel())
    ce = (P[ci].max(0) - P[ci].min(0)) * s
    return parts, {"cloth_m": [round(float(ce[0]), 3), round(float(ce[1]), 3)], "snap_m": round(SNAP_Y * s, 3)}


def hour_clock(P, N, UV, I, img):
    s = CLOCK_W / (P[:, 0].max() - P[:, 0].min())
    C = P[I].mean(1)
    a = math.radians(HAND_DEG)
    rel = C[:, :2] - np.array(HUB)
    along = rel @ np.array([math.cos(a), math.sin(a)])
    perp = np.abs(rel @ np.array([-math.sin(a), math.cos(a)]))
    hand = (along > HAND_FROM) & (along < HAND_TO) & (perp < HAND_HALF_W) & (C[:, 2] > HAND_Z)
    off = np.array([HUB[0], HUB[1], 0.0])
    parts = {}
    for name, sel in (("clock", ~hand), ("minute_hand", hand)):
        p, n, uv, idx = compact(P, N, UV, I, np.nonzero(sel)[0])
        parts[name] = ((p - off) * s, n, uv, idx, None, None)
    return parts, {}


def siege_cart(P, N, UV, I, img):
    Q = P * np.array([-1.0, 1.0, -1.0])  # half a turn about Y
    M = N * np.array([-1.0, 1.0, -1.0])
    lo, hi = Q.min(0), Q.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    s = CART_L / (hi[0] - lo[0])
    C = P[I].mean(1)
    taken = np.zeros(len(I), bool)
    parts = {}
    radii = []
    for k, (wx, wy, side) in enumerate(WHEELS):
        far = np.hypot(P[I][:, :, 0] - wx, P[I][:, :, 1] - wy).max(1)
        sel = (far < WHEEL_R) & (C[:, 2] * side > WHEEL_Z) & ~taken
        taken |= sel
        p, n, uv, idx = compact(Q, M, UV, I, np.nonzero(sel)[0])
        p = (p - centre) * s
        # The hub in the game's frame (the half turn flips x), at the middle of the wheel's own thickness.
        hub = np.array([(-wx - centre[0]) * s, (wy - centre[1]) * s, (p[:, 2].min() + p[:, 2].max()) / 2])
        radii.append(float(np.hypot(p[:, 0] - hub[0], p[:, 1] - hub[1]).max()))
        parts["wheel_%d" % k] = (p - hub, n, uv, idx, None, hub)
    p, n, uv, idx = compact(Q, M, UV, I, np.nonzero(~taken)[0])
    parts = {"body": ((p - centre) * s, n, uv, idx, None, None), **parts}
    return parts, {"wheel_r_m": round(float(np.mean(radii)), 3)}


PIECES = {"javelin": javelin, "war_banner": war_banner, "hour_clock": hour_clock, "siege_cart": siege_cart}


# --- glb out -------------------------------------------------------------------------------------------------------


def write_glb(path, rid, parts, jpeg):
    """One node and mesh per part (in `parts` order), all on one matte material of the piece's map."""
    blob = b""
    views, accs = [], []

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

    nodes, meshes = [], []
    for name, (pos, nrm, uv, idx, uv2, at) in parts.items():
        attrs = {
            "POSITION": add(pos.astype(np.float32), 34962, 5126, "VEC3", True),
            "NORMAL": add(unit(nrm).astype(np.float32), 34962, 5126, "VEC3"),
            "TEXCOORD_0": add(uv.astype(np.float32), 34962, 5126, "VEC2"),
        }
        if uv2 is not None:
            attrs["TEXCOORD_1"] = add(uv2.astype(np.float32), 34962, 5126, "VEC2")
        prim = {"attributes": attrs, "indices": add(idx.astype(np.uint32).ravel(), 34963, 5125, "SCALAR")}
        prim.update({"material": 0, "mode": 4})
        meshes.append({"name": name, "primitives": [prim]})
        node = {"name": name, "mesh": len(meshes) - 1}
        if at is not None:
            node["translation"] = [float(v) for v in at]
        nodes.append(node)
    views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(jpeg)})
    blob = pad4(blob + jpeg)
    gltf = {
        "asset": {"version": "2.0", "generator": "zero-depth scripts/assets/boss_pieces_v0120_prep.py (the owner's Tripo file)"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [
            {
                "name": rid,
                "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0},
            }
        ],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
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


# --- main ------------------------------------------------------------------------------------------------------------


def main():
    only = set(sys.argv[1:])
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for rid in IDS:
        if only and rid not in only:
            continue
        P, N, UV, I, img = read_glb(os.path.join(SRC, rid + ".glb"))
        parts, extra = PIECES[rid](P, N, UV, I, img)
        jpeg, gain = piece_texture(img, UV, I)
        dst = os.path.join(OUT, rid + ".glb")
        write_glb(dst, rid, parts, jpeg)
        allp = np.concatenate([p[0] + (p[5] if p[5] is not None else 0) for p in parts.values()])
        ext = allp.max(0) - allp.min(0)
        report[rid] = {
            "tris": int(sum(len(p[3]) for p in parts.values())),
            "parts": {k: int(len(p[3])) for k, p in parts.items()},
            "size_m": [round(float(ext[0]), 3), round(float(ext[2]), 3), round(float(ext[1]), 3)],
            **extra,
            "gain": round(gain, 3),
            "bytes": os.path.getsize(dst),
            "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
            "path": dst.replace(os.sep, "/"),
        }
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
