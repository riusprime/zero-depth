"""Cuts the owner's two packed prop files (unprocessed_images/models_v0120_b/props_pack_{a,b}.glb) and his timed door
(timed_door.glb) into the eleven device props of docs/art/requests/v0.12.0_models.md Part 2 and writes them as
assets/models/devices/<id>.glb.

Each raw file is a Tripo export: one mesh (about 4.7k triangles), one 2048 px colour map, Y up, about 1 unit wide.
The packs lay their pieces out like a picture seen from the front (+Z): a back row standing about 0.3 units higher
and a front row on y = 0, each piece one welded part. Like scripts/assets/rooms_v0120_prep.py (whose reading,
cutting, texture and writing this reuses), for each pack this script:
1. splits the mesh into its welded parts, puts each in its row by the height of its base and joins the parts of a
   row whose x spans overlap, then names the groups left to right from PACKS (a count that does not match stops it);
2. per piece keeps its own triangles with the owner's normals and UVs, turns it by its yaw (AUTO_YAW: the turn in
   (-45, 45] degrees that gives the least footprint, so a box stands square and the pylon's socket still faces +Z;
   plus TURN, a quarter turn that puts a long side on +X), centres it on x/z with its base on y = 0 and scales it
   evenly to its request row (SIZE: by height, or by its widest side for the flat and rolling hazards in FIT_WIDTH);
3. gives each piece its own copy of the pack's colour map at the kit's 1024 px, brightened toward the kit's mean and
   never darkened (rooms_v0120_prep.piece_texture), material matte (metallic 0, roughness 0.9);
4. marks the parts the game moves in TEXCOORD_1 (u = (part + 0.5) / 16, read back by ShopModels.parts): the ice
   plate's shards (its top faces split at the cracks, every other face joined to the nearest shard), the explosive
   barrel's lid and fuse (the UV islands at its top), the door's two jambs, its lintel and sill, and its slab;
5. the pylon: an emission map (white where its front faces carry the owner's copper channels, the rest black) the
   game lights violet as each pylon locks in.
The timed door: the slab with its seal (the triangles inside the frame's opening) is cut from the frame, the frame
split into its two jambs and the middle (lintel and sill, the game stretches it to the doorway) and the cuts capped
(the jambs' and the lintel's and sill's inner faces, the slab's four edges) with a texel of the slab's stone. It is
turned so its front (+Z) faces the side the hero comes from (-X in the door's frame) and its width runs on +Z, scaled
evenly so the slab is 3.0 m tall.
The raw files stay untouched. It prints one JSON line: per piece its triangles, size (m, x/z/y), the file's size and
sha256 (paste the sha256 into assets/models/manifest.json by hand), and the points the views place lights at.

Run from the repo root:  python3 scripts/assets/props_v0120_prep.py [ids...]   (needs numpy and Pillow)
With ids it writes only those pieces.
"""

import hashlib
import io
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rooms_v0120_prep as rooms  # noqa: E402

SRC = "unprocessed_images/models_v0120_b"
OUT = "assets/models/devices"
## A part whose base is above this (raw units) is in the back row.
ROW_SPLIT = 0.25

PACKS = {
    "props_pack_a.glb": (
        ["hazard_cable", "container_crate", "container_urn"],
        ["container_barrel", "explosive_barrel", "approach_pylon"],
    ),
    "props_pack_b.glb": (["hazard_rock", "hazard_vent", "hazard_ice"], ["hazard_star"]),
}
## The request rows (v0.12.0_models.md Part 2): width (x), depth (z), height (y), metres. The flat hazards' rows give
## only a footprint; their height is the model's own.
SIZE = {
    "container_crate": (0.8, 0.8, 0.8),
    "container_urn": (0.6, 0.6, 0.9),
    "container_barrel": (0.6, 0.6, 0.9),
    "explosive_barrel": (0.7, 0.7, 1.0),
    "approach_pylon": (0.9, 0.9, 2.4),
    "hazard_cable": (2.0, 1.5, 0.0),
    "hazard_rock": (1.2, 1.2, 1.0),
    "hazard_vent": (1.3, 1.3, 0.0),
    "hazard_ice": (1.3, 1.3, 0.0),
    "hazard_star": (1.0, 1.0, 0.8),
}
## Scaled so the widest side is the row's width (flat pieces, and the rock the game drops: its footprint is the hit).
FIT_WIDTH = {"hazard_cable", "hazard_rock", "hazard_vent", "hazard_ice"}
## Turned to their least footprint (boxes and the pylon); the rest are round or rough.
AUTO_YAW = {"container_crate", "approach_pylon", "hazard_cable"}
## A quarter turn on top: the cable slab's long side lies on z in the pack.
TURN = {"hazard_cable": 90.0}
## Raw points the views light (the pylon's socket on its front face, the cable's frayed ends), written out in the
## game's frame in the report.
HINTS = {"approach_pylon": (0.401, 0.265, -0.061), "hazard_cable": (-0.31, 0.37, 0.16)}
## The ice's top faces (normal y above this) split at the cracks; a shard has at least SHARD_MIN of them.
ICE_TOP = 0.7
SHARD_MIN = 10
## The explosive barrel's lid: its UV islands starting above this share of its height.
LID_FROM = 0.75
## The pylon's channels: texels this much redder than green and blue on its front faces (normal z above PYLON_FRONT).
PYLON_FRONT = 0.5
EMISSION_PX = 512
PART_SLOTS = 16.0

## The door: the opening in the frame (raw x, y), the slab's thickness (raw z, both faces), the slab's height (m).
DOOR_FILE = "timed_door.glb"
DOOR_X = 0.302
DOOR_Y = (0.088, 0.765)
DOOR_Z = 0.085
DOOR_SLAB_H = 3.0
## Raw -> game: the front (+Z) onto -X, the width (+X) onto +Z.
DOOR_YAW = -90.0
DOOR_LEFT, DOOR_RIGHT, DOOR_MIDDLE, DOOR_SLAB = 0, 1, 2, 3


def turn(P, deg):
    a = math.radians(deg)
    return P @ np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]]).T


def least_footprint(P):
    best = (1e9, 0.0)
    for k in range(-89, 91):
        a = k * 0.5
        Q = turn(P, a)
        ext = Q.max(0) - Q.min(0)
        best = min(best, (ext[0] * ext[2], a))
    return best[1]


def raw_islands(I):
    """Per triangle, its UV island (triangles joined through shared vertex indices, before any welding)."""
    par = np.arange(I.max() + 1)

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x

    for a, b, c in I:
        for u, v in ((a, b), (b, c)):
            ru, rv = find(u), find(v)
            if ru != rv:
                par[ru] = rv
    return np.unique(np.array([find(v) for v in I[:, 0]]), return_inverse=True)[1].ravel()


def face_normals(P, I):
    n = np.cross(P[I[:, 1]] - P[I[:, 0]], P[I[:, 2]] - P[I[:, 0]])
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]


def ice_shards(P, I):
    """Per triangle its shard: the top faces' welded groups of SHARD_MIN or more, the rest to the nearest."""
    top = np.nonzero(face_normals(P, I)[:, 1] > ICE_TOP)[0]
    grp = rooms.loose_parts(P, I[top])
    big = [g for g in range(grp.max() + 1) if (grp == g).sum() >= SHARD_MIN]
    c = P[I].mean(1)[:, [0, 2]]
    seeds = np.concatenate([top[grp == g] for g in big])
    seed_of = np.concatenate([np.full((grp == g).sum(), k) for k, g in enumerate(big)])
    d = ((c[:, None, :] - c[seeds][None, :, :]) ** 2).sum(2)
    return seed_of[d.argmin(1)]


def barrel_lid(P, I):
    """Per triangle 1 for the lid and fuse (the UV islands starting high on the barrel), else 0."""
    isl = raw_islands(I)
    lo, hi = P[:, 1].min(), P[:, 1].max()
    out = np.zeros(len(I), np.int64)
    for k in range(isl.max() + 1):
        t = isl == k
        if P[I[t].ravel(), 1].min() >= lo + LID_FROM * (hi - lo):
            out[t] = 1
    return out


def pylon_emission(Q, I, UV, img):
    """The emission map: white on the copper channels of the pylon's front faces (Q in the game's frame)."""
    front = face_normals(Q, I)[:, 2] > PYLON_FRONT
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    for tri in I[front]:
        draw.polygon([(UV[v, 0] * img.size[0], UV[v, 1] * img.size[1]) for v in tri], fill=255)
    px = np.asarray(img).astype(np.float64) / 255.0
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    lit = (np.asarray(mask) > 0) & (r > g * 1.25) & (r > b * 1.5) & (r > 0.25)
    out = Image.fromarray((lit * 255).astype(np.uint8)).resize((EMISSION_PX, EMISSION_PX), Image.BILINEAR)
    buf = io.BytesIO()
    out.convert("RGB").save(buf, "PNG", optimize=True)
    return buf.getvalue(), int(lit.sum())


def part_uv(parts):
    return np.stack([(parts + 0.5) / PART_SLOTS, np.zeros(len(parts))], 1)


def write(rid, pos, nrm, uv, idx, jpeg, parts=None, emission=None):
    """rooms.write_glb plus the parts (TEXCOORD_1) and an emission map; returns the report's row."""
    dst = os.path.join(OUT, rid + ".glb")
    rooms.write_glb(dst, rid, pos, nrm, uv, idx, jpeg)
    if parts is not None or emission is not None:
        _extend(dst, parts, emission)
    ext = pos.max(0) - pos.min(0)
    return {
        "tris": int(len(idx)),
        "size_m": [round(float(ext[0]), 3), round(float(ext[2]), 3), round(float(ext[1]), 3)],
        "bytes": os.path.getsize(dst),
        "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
        "path": dst.replace(os.sep, "/"),
    }


def _extend(path, vparts, emission):
    """Adds TEXCOORD_1 (per vertex) and an emission texture to a glb rooms.write_glb wrote."""
    import struct

    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20 : 20 + n])
    blob = bytearray(data[28 + n :])
    prim = j["meshes"][0]["primitives"][0]
    if vparts is not None:
        arr = np.ascontiguousarray(vparts.astype(np.float32)).tobytes()
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(arr), "target": 34962})
        blob += arr + b"\0" * ((4 - len(arr) % 4) % 4)
        j["accessors"].append(
            {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(vparts), "type": "VEC2"}
        )
        prim["attributes"]["TEXCOORD_1"] = len(j["accessors"]) - 1
    if emission is not None:
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(emission)})
        blob += emission + b"\0" * ((4 - len(emission) % 4) % 4)
        j["images"].append({"name": "glow", "bufferView": len(j["bufferViews"]) - 1, "mimeType": "image/png"})
        j["textures"].append({"source": len(j["images"]) - 1, "sampler": 0})
        mat = j["materials"][0]
        mat["emissiveTexture"] = {"index": len(j["textures"]) - 1}
        mat["emissiveFactor"] = [1.0, 1.0, 1.0]
    j["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0") + bytes(blob))


def prop(rid, P, N, UV, idx, img):
    yaw = (least_footprint(P) if rid in AUTO_YAW else 0.0) + TURN.get(rid, 0.0)
    Q = turn(P, yaw)
    lo, hi = Q.min(0), Q.max(0)
    w, _, h = SIZE[rid]
    ext = hi - lo
    s = w / max(ext[0], ext[2]) if rid in FIT_WIDTH else h / ext[1]
    base = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    pos = (Q - base) * s
    nrm = turn(N, yaw)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1), 1e-12)[:, None]
    jpeg, gain = rooms.piece_texture(img, UV, idx)
    parts, emission, extra = None, None, {}
    if rid == "hazard_ice":
        tparts = ice_shards(pos, idx)
        extra["parts"] = int(tparts.max() + 1)
    elif rid == "explosive_barrel":
        tparts = barrel_lid(pos, idx)
        extra["lid_tris"] = int(tparts.sum())
    if rid in ("hazard_ice", "explosive_barrel"):
        # A vertex shared across two parts is split so each triangle keeps its own part.
        pos, nrm, uv2, idx2, parts = _split_by_part(pos, nrm, UV, idx, tparts)
        UV, idx = uv2, idx2
    if rid == "approach_pylon":
        emission, texels = pylon_emission(pos, idx, UV, img)
        extra["channel_texels"] = texels
    if rid in HINTS:
        p = (turn(np.array([HINTS[rid]]), yaw)[0] - base) * s
        extra["hint_m"] = [round(float(v), 3) for v in p]
    row = write(rid, pos, nrm, UV, idx, jpeg, None if parts is None else part_uv(parts), emission)
    row.update({"yaw": round(yaw, 1), "gain": round(gain, 3)}, **extra)
    return row


def _split_by_part(pos, nrm, uv, idx, tparts):
    key = {}
    P2, N2, U2, parts, I2 = [], [], [], [], []
    for t, tri in enumerate(idx):
        row = []
        for v in tri:
            k = (int(v), int(tparts[t]))
            if k not in key:
                key[k] = len(P2)
                P2.append(pos[v])
                N2.append(nrm[v])
                U2.append(uv[v])
                parts.append(tparts[t])
            row.append(key[k])
        I2.append(row)
    return np.array(P2), np.array(N2), np.array(U2), np.array(I2, np.int64), np.array(parts, np.float64)


# --- the timed door --------------------------------------------------------------------------------------------------


def door(P, N, UV, I, img):
    c = P[I].mean(1)
    inside = (np.abs(c[:, 0]) < DOOR_X) & (c[:, 1] > DOOR_Y[0]) & (c[:, 1] < DOOR_Y[1])
    tpart = np.where(c[:, 0] < -DOOR_X, DOOR_LEFT, np.where(c[:, 0] > DOOR_X, DOOR_RIGHT, DOOR_MIDDLE))
    tpart[inside] = DOOR_SLAB
    # The texel the caps take: the slab's face, from the triangle nearest the opening's middle.
    near = np.argmin(np.where(inside, np.abs(c[:, 0]) + np.abs(c[:, 1] - sum(DOOR_Y) / 2), 9.0))
    cap_uv = UV[I[near]].mean(0)
    x, (y0, y1), z = DOOR_X, DOOR_Y, DOOR_Z
    caps = [
        # (four corners counter-clockwise seen from the side the face faces, its normal, part)
        ([(-x, y0, z), (-x, y0, -z), (-x, y1, -z), (-x, y1, z)], (1, 0, 0), DOOR_LEFT),
        ([(x, y0, -z), (x, y0, z), (x, y1, z), (x, y1, -z)], (-1, 0, 0), DOOR_RIGHT),
        ([(-x, y1, z), (-x, y1, -z), (x, y1, -z), (x, y1, z)], (0, -1, 0), DOOR_MIDDLE),
        ([(-x, y0, -z), (-x, y0, z), (x, y0, z), (x, y0, -z)], (0, 1, 0), DOOR_MIDDLE),
        ([(-x, y0, -z), (-x, y1, -z), (-x, y1, z), (-x, y0, z)], (-1, 0, 0), DOOR_SLAB),
        ([(x, y0, z), (x, y1, z), (x, y1, -z), (x, y0, -z)], (1, 0, 0), DOOR_SLAB),
        ([(-x, y1, -z), (x, y1, -z), (x, y1, z), (-x, y1, z)], (0, 1, 0), DOOR_SLAB),
        ([(-x, y0, z), (x, y0, z), (x, y0, -z), (-x, y0, -z)], (0, -1, 0), DOOR_SLAB),
    ]
    P2, N2, U2, I2, tp2 = [P], [N], [UV], [I], [tpart]
    nv = len(P)
    for corners, normal, part in caps:
        quad = np.array(corners, np.float64)
        # Wind each cap so its geometric normal agrees with `normal` (glTF's counter-clockwise front).
        tri = np.array([[0, 1, 2], [0, 2, 3]])
        if np.dot(np.cross(quad[1] - quad[0], quad[2] - quad[0]), normal) < 0:
            tri = tri[:, ::-1]
        P2.append(quad)
        N2.append(np.tile(normal, (4, 1)).astype(np.float64))
        U2.append(np.tile(cap_uv, (4, 1)))
        I2.append(tri + nv)
        tp2.append(np.full(2, part))
        nv += 4
    P, N, UV, I, tpart = (np.concatenate(a) for a in (P2, N2, U2, I2, tp2))
    s = DOOR_SLAB_H / (y1 - y0)
    Q = turn(P, DOOR_YAW) * s
    M = turn(N, DOOR_YAW)
    jpeg, gain = rooms.piece_texture(img, UV, I)
    pos, nrm, uv, idx, parts = _split_by_part(Q, M, UV, I, tpart)
    row = write("timed_door", pos, nrm, uv, idx, jpeg, part_uv(parts))
    row.update(
        {
            "gain": round(gain, 3),
            "opening_m": round(2 * x * s, 3),
            "slab_y_m": [round(y0 * s, 3), round(y1 * s, 3)],
            "slab_tris": int((tpart == DOOR_SLAB).sum()),
        }
    )
    return row


def main():
    only = set(sys.argv[1:])
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for fname, names in PACKS.items():
        P, N, UV, I, img = rooms.read_glb(os.path.join(SRC, fname))
        saved = rooms.ROW_SPLIT
        rooms.ROW_SPLIT = ROW_SPLIT
        pieces = rooms.cut(P, I, names)
        rooms.ROW_SPLIT = saved
        for rid, tris in pieces.items():
            if only and rid not in only:
                continue
            used, inv = np.unique(I[tris].ravel(), return_inverse=True)
            report[rid] = prop(rid, P[used], N[used], UV[used], inv.reshape(-1, 3), img)
            report[rid]["from"] = fname
    if not only or "timed_door" in only:
        P, N, UV, I, img = rooms.read_glb(os.path.join(SRC, DOOR_FILE))
        report["timed_door"] = door(P, N, UV, I, img)
        report["timed_door"]["from"] = DOOR_FILE
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
