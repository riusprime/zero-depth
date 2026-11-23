"""Cuts the owner's three packed room-piece files (unprocessed_images/models_v0120/room_assetspack{1,2,3}.glb) into the
sixteen kit pieces of OWNER_TODO §3.6 and writes them as assets/models/kit/<id>.glb.

Each raw file is a Tripo export: one mesh (about 4.7k triangles), one 2048 px colour map, Y up, about 1 unit wide. Its
pieces are laid out like a picture seen from the front (+Z): a back row standing about 0.3 units higher and a front row
on y = 0, each piece a few loose parts. For each file this script:
1. welds the mesh by position (only to find which triangles touch) and splits it into loose parts;
2. puts each part in its row by the height of its base (ROW_SPLIT) and joins the parts of a row whose x spans overlap
   (a piece's chips and pebbles lie inside its own span), then names the groups left to right from PACKS; a count
   that does not match stops the script;
3. per piece keeps its own triangles with the owner's normals and UVs, turns it by its yaw (YAW: the packs set some
   pieces at a slant; the turn puts its long side on +X, as the kit's pieces are, its front toward +Z), centres it on
   x/z with its base on y = 0 and scales it evenly (uniform scale, proportions kept) so its height is the request
   row's (SIZE); FIT_WIDTH pieces are scaled to the row's width instead, and SCALE_AS pieces take another piece's
   scale (the broken statue is the whole statue broken). The rows' footprints are wishes the models do not all
   keep (a pebble, a bracket or a jib reaches past them), so the printed sizes are the pieces' own;
4. gives each piece its own copy of the pack's colour map at TEXTURE_PX (the kit's budget): the texels its UVs cover
   are kept (grown by MASK_GROW px so mipmaps do not bleed), the rest filled with their mean (a smaller JPEG), and
   the whole brightened toward MODEL_MEAN by at most BRIGHT_MAX and never darkened (the uploads average about 0.35,
   which reads black under the night moods; the biome hue is added in the game), saved as JPEG.
The raw files stay untouched. It prints one JSON line: per piece its triangles, size (m, x/z/y), the file's size
and sha256 (paste the sha256 into assets/models/manifest.json by hand).

Run from the repo root:  python3 scripts/assets/rooms_v0120_prep.py [ids...]   (needs numpy and Pillow)
With ids it writes only those pieces.
"""

import hashlib
import io
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "unprocessed_images/models_v0120"
OUT = "assets/models/kit"
TEXTURE_PX = 1024
JPEG_QUALITY = 88
MODEL_MEAN = 0.55
BRIGHT_MAX = 2.0
MASK_GROW = 6
## A part whose base is above this (raw units) is in the back row.
ROW_SPLIT = 0.25
## Weld distance (raw units) for finding loose parts.
WELD = 1e-5

## Per file: the back row's pieces and then the front row's, each left to right as seen from the front.
PACKS = {
    "room_assetspack1.glb": (["camp_tent", "log_seat", "cook_pot"], ["statue_whole", "statue_broken", "column_round"]),
    "room_assetspack2.glb": (["column_drum", "quarry_crane", "mine_cart"], ["stone_block", "tool_rack"]),
    "room_assetspack3.glb": (["metal_post", "dumpster", "cable_spool"], ["sign_frame", "ice_floe"]),
}
## The request rows (OWNER_TODO §3.6): width (x), depth (z), height (y), metres, in the game frame after YAW.
## column_drum's row reads 0.8 wide and 1.6 deep: its long side goes on +X, so it is 1.6 x 0.8 here.
SIZE = {
    "camp_tent": (2.4, 2.0, 1.8),
    "log_seat": (1.4, 0.4, 0.4),
    "cook_pot": (0.7, 0.7, 0.9),
    "statue_whole": (1.2, 1.2, 3.2),
    "statue_broken": (1.4, 1.2, 1.8),
    "column_round": (0.8, 0.8, 3.6),
    "column_drum": (1.6, 0.8, 0.8),
    "quarry_crane": (2.0, 1.6, 4.0),
    "mine_cart": (1.4, 0.9, 1.0),
    "stone_block": (1.2, 1.2, 0.8),
    "tool_rack": (1.4, 0.4, 1.6),
    "metal_post": (0.2, 0.2, 1.8),
    "dumpster": (1.8, 1.0, 1.2),
    "cable_spool": (0.9, 0.9, 0.7),
    "sign_frame": (1.2, 0.2, 1.6),
    "ice_floe": (2.0, 1.6, 0.12),
}
## Degrees about +Y (raw -> game), read from each piece's least-area footprint rectangle (and a quarter turn where
## that leaves its long side on z); the rest stand square to the front already, or are round.
YAW = {
    "log_seat": -17.5,
    "statue_broken": 69.5,
    "column_drum": -20.0,
    "quarry_crane": 65.0,
    "stone_block": -12.5,
    "metal_post": 23.5,
    "dumpster": -57.0,
    "cable_spool": -59.0,
    "sign_frame": -45.5,
}
## Scaled to the row's width, not its height: the floe is a flat slab whose thickness is the model's own.
FIT_WIDTH = {"ice_floe"}
## Scaled as another piece is (that piece's raw height to its row's height).
SCALE_AS = {"statue_broken": "statue_whole"}


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
    bv = j["bufferViews"][j["images"][tex["source"]]["bufferView"]]
    img = Image.open(io.BytesIO(blob[bv.get("byteOffset", 0) : bv.get("byteOffset", 0) + bv["byteLength"]]))
    return (
        acc(at["POSITION"]).astype(np.float64),
        acc(at["NORMAL"]).astype(np.float64),
        acc(at["TEXCOORD_0"]).astype(np.float64),
        acc(prim["indices"]).astype(np.int64).reshape(-1, 3),
        img.convert("RGB"),
    )


# --- cutting ---------------------------------------------------------------------------------------------------------


def loose_parts(P, I):
    """Per triangle, the id of its loose part (triangles joined through shared welded vertices)."""
    key = np.round(P / WELD).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    J = inv.ravel()[I]
    par = np.arange(J.max() + 1)

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x

    for a, b, c in J:
        for u, v in ((a, b), (b, c)):
            ru, rv = find(u), find(v)
            if ru != rv:
                par[ru] = rv
    roots = np.array([find(v) for v in J[:, 0]])
    return np.unique(roots, return_inverse=True)[1].ravel()


def cut(P, I, names):
    """{piece id: triangle indices}: rows by base height, then groups of overlapping x spans, named left to right."""
    part = loose_parts(P, I)
    spans = []
    for c in range(part.max() + 1):
        tris = np.nonzero(part == c)[0]
        pts = P[I[tris].ravel()]
        spans.append((pts[:, 1].min() > ROW_SPLIT, pts[:, 0].min(), pts[:, 0].max(), tris))
    out = {}
    for row, row_names in ((True, names[0]), (False, names[1])):
        mine = sorted((s for s in spans if s[0] == row), key=lambda s: s[1])
        groups = []
        for _, lo, hi, tris in mine:
            if groups and lo <= groups[-1][1]:
                groups[-1][1] = max(groups[-1][1], hi)
                groups[-1][2].append(tris)
            else:
                groups.append([lo, hi, [tris]])
        if len(groups) != len(row_names):
            raise SystemExit("%s row: %d groups, expected %d" % (row_names, len(groups), len(row_names)))
        for rid, g in zip(row_names, groups):
            out[rid] = np.concatenate(g[2])
    return out


def turn(P, rid):
    a = math.radians(YAW.get(rid, 0.0))
    # A turn of +a about +Y: x' = x cos a + z sin a, z' = -x sin a + z cos a (glTF's right-handed frame).
    return P @ np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]]).T


def scale_of(rid, ext):
    """The uniform scale (m per raw unit) for a piece whose turned raw extent is `ext`."""
    w, _, h = SIZE[rid]
    return w / ext[0] if rid in FIT_WIDTH else h / ext[1]


def to_game(P, N, rid, s):
    Q = turn(P, rid)
    lo, hi = Q.min(0), Q.max(0)
    Q = Q - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    M = turn(N, rid)
    return Q * s, M / np.maximum(np.linalg.norm(M, axis=1), 1e-12)[:, None]


# --- texture ---------------------------------------------------------------------------------------------------------


def piece_texture(img, UV, T):
    """The pack's map at TEXTURE_PX: this piece's texels kept, the rest their mean, brightened (never darkened)."""
    src = img.resize((TEXTURE_PX, TEXTURE_PX), Image.LANCZOS) if img.size[0] != TEXTURE_PX else img
    mask = Image.new("L", (TEXTURE_PX, TEXTURE_PX), 0)
    draw = ImageDraw.Draw(mask)
    for tri in T:
        draw.polygon([(UV[v, 0] * TEXTURE_PX, UV[v, 1] * TEXTURE_PX) for v in tri], fill=255)
    mask = mask.filter(ImageFilter.MaxFilter(2 * MASK_GROW + 1))
    m = np.asarray(mask) > 0
    px = np.asarray(src).astype(np.float64) / 255.0
    mean = px[m].mean(0)
    gain = min(max(MODEL_MEAN / max(mean.mean(), 1e-3), 1.0), BRIGHT_MAX)
    px[~m] = mean
    px = np.clip(px * gain, 0.0, 1.0)
    buf = io.BytesIO()
    Image.fromarray((px * 255).round().astype(np.uint8)).save(buf, "JPEG", quality=JPEG_QUALITY)
    return buf.getvalue(), gain


# --- glb out ---------------------------------------------------------------------------------------------------------


def pad4(b, fill=b"\0"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write_glb(path, rid, pos, nrm, uv, idx, jpeg):
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

    prim = {
        "attributes": {
            "POSITION": add(pos.astype(np.float32), 34962, 5126, "VEC3", True),
            "NORMAL": add(nrm.astype(np.float32), 34962, 5126, "VEC3"),
            "TEXCOORD_0": add(uv.astype(np.float32), 34962, 5126, "VEC2"),
        },
        "indices": add(idx.astype(np.uint32).ravel(), 34963, 5125, "SCALAR"),
        "material": 0,
        "mode": 4,
    }
    views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(jpeg)})
    blob = pad4(blob + jpeg)
    gltf = {
        "asset": {"version": "2.0", "generator": "zero-depth scripts/assets/rooms_v0120_prep.py (the owner's Tripo file)"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": rid, "mesh": 0}],
        "meshes": [{"name": rid, "primitives": [prim]}],
        "materials": [
            {
                "name": rid,
                "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.9},
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
    pieces = {}
    for fname, names in PACKS.items():
        P, N, UV, I, img = read_glb(os.path.join(SRC, fname))
        for rid, tris in cut(P, I, names).items():
            used, inv = np.unique(I[tris].ravel(), return_inverse=True)
            ext = turn(P[used], rid).max(0) - turn(P[used], rid).min(0)
            pieces[rid] = (fname, P[used], N[used], UV[used], inv.reshape(-1, 3), img, ext)
    for rid, (fname, P, N, UV, idx, img, ext) in pieces.items():
        if only and rid not in only:
            continue
        s = scale_of(SCALE_AS.get(rid, rid), pieces[SCALE_AS.get(rid, rid)][6])
        pos, nrm = to_game(P, N, rid, s)
        jpeg, gain = piece_texture(img, UV, idx)
        dst = os.path.join(OUT, rid + ".glb")
        write_glb(dst, rid, pos, nrm, UV, idx, jpeg)
        ext = pos.max(0) - pos.min(0)
        report[rid] = {
            "from": fname,
            "tris": int(len(idx)),
            "size_m": [round(float(ext[0]), 3), round(float(ext[2]), 3), round(float(ext[1]), 3)],
            "gain": round(gain, 3),
            "bytes": os.path.getsize(dst),
            "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
            "path": dst.replace(os.sep, "/"),
        }
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
