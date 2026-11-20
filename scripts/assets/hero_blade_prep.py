"""Prepares the owner's Blade (unprocessed_images/models_v0120_b/hero_blade.glb; docs/art/requests/PENDING_ASSETS.md
§9) for the game: assets/models/fx/hero_blade.glb, the rune-summoned blade SummonedBlade draws on each Blade swing.

The raw file is a Tripo export: one mesh of 14,529 triangles, 1 unit long on X (the pommel at x = -0.5, the tip at
x = +0.5), its flat facing Z (the blade's width on Y, about 0.09..0.16 along the blade), three 2048 px maps: a colour
map, a roughness/metal map and a normal map. Its colour and roughness maps are lossless JPEGs (SOF3), which Pillow
cannot read, so Blender (BLENDER, or its default install path) first writes the colour map again as a baseline JPEG into build/prep/.
This script:
1. simplifies the mesh to BUDGET_TRIS with mi_prep's simplifier (Godot's when the Python meshoptimizer package is
   missing; borders locked), keeping the owner's UVs and his smooth normals (no recomputed hard edges);
2. sorts each triangle into the `steel` part or the `edge` part (the one the game makes glow pale blue-white): on the
   blade (past GUARD_X), a triangle whose centre lies farther than EDGE_FRAC of the blade's half width from the blade's
   centre line at its place, and every triangle past TIP_X (the point);
3. turns it into the game's frame: the blade along +X (the pommel at x = 0, the tip at LENGTH_M), its flat facing +Y
   (so a swing in the ground plane shows the iso camera the blade's face), centred on its blade's centre line, scaled
   evenly to LENGTH_M;
4. keeps only the colour map, resized to TEX_PX (the roughness and metal map are dropped: models are matte, lit like the
   walls; the normal map is dropped: the blade's facets are in its geometry);
5. writes assets/models/fx/hero_blade.glb: two nodes, `steel` and `edge`, on one matte material of the colour map.
It prints one JSON line: the raw and kept triangles (per part), the simplifier, the size in metres, the map size, the
file's size and sha256 (pasted into assets/models/manifest.json by hand). `--debug` also writes a top view of the
parts into build/prep/hero_blade_parts.png. The raw file stays untouched.

Run from the repo root:  python scripts/assets/hero_blade_prep.py [--debug]
(GODOT=<godot executable> when meshoptimizer is missing; BLENDER=<blender executable> when not at BLENDER_DEFAULT.)
Needs numpy and Pillow (and mi_prep's imports: scipy; xatlas is stubbed when missing).
"""

import hashlib
import io
import json
import struct
import os
import subprocess
import sys
import types

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import xatlas  # noqa: F401  (mi_prep imports it at the top; this script keeps the owner's UVs)
except ImportError:
    sys.modules["xatlas"] = types.ModuleType("xatlas")
import mi_prep  # noqa: E402  (the simplifier)
from boss_pieces_v0120_prep import write_glb  # noqa: E402  (one node per part, one matte material)

SRC = "unprocessed_images/models_v0120_b/hero_blade.glb"
OUT = "assets/models/fx/hero_blade.glb"
PREP = "build/prep"
BLENDER_DEFAULT = "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"

## The request: about 1.1 m, a hero weapon on screen (3-5k triangles), a 1024 px map.
LENGTH_M = 1.1
BUDGET_TRIS = 4000
TEX_PX = 1024
JPEG_QUALITY = 88
## The blade starts past the cross guard at this raw x; the point is past TIP_X.
GUARD_X = -0.16
TIP_X = 0.46
## A blade triangle is edge when its centre is this far out of the blade's half width (0 the centre line, 1 the edge).
EDGE_FRAC = 0.62
## The width of the slices the blade's centre line and half width are read in (raw units).
SLICE = 0.02


def colour_map():
    """The colour map, written again by Blender (which reads the lossless JPEG Pillow cannot) as one Pillow reads."""
    os.makedirs(PREP, exist_ok=True)
    out = os.path.abspath(os.path.join(PREP, "hero_blade_basecolor.jpg"))
    code = (
        "import bpy\n"
        "bpy.ops.wm.read_factory_settings(use_empty=True)\n"
        "bpy.ops.import_scene.gltf(filepath=%r)\n"
        "im=[i for i in bpy.data.images if 'basecolor' in i.name][0]\n"
        "im.filepath_raw=%r\n"
        "im.file_format='JPEG'\n"
        "im.save()\n" % (os.path.abspath(SRC), out)
    )
    blender = os.environ.get("BLENDER", BLENDER_DEFAULT)
    r = subprocess.run([blender, "-b", "--python-expr", code], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        raise RuntimeError("blender failed (%d): %s" % (r.returncode, (r.stdout + r.stderr)[-2000:]))
    return Image.open(out).convert("RGB")


def read_mesh(path):
    """Positions, the owner's normals, UVs and indices (rooms_v0120_prep.read_glb also opens the colour map, which
    Pillow cannot read here)."""
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
    return (
        acc(at["POSITION"]).astype(np.float64),
        acc(at["NORMAL"]).astype(np.float64),
        acc(at["TEXCOORD_0"]).astype(np.float64),
        acc(prim["indices"]).astype(np.int64).reshape(-1, 3),
    )


def blade_lines(P):
    """Per raw x slice on the blade: (centre y, half width), from the vertices in it."""
    lo = GUARD_X
    n = int(np.ceil((P[:, 0].max() - lo) / SLICE)) + 1
    out = []
    for k in range(n):
        s = P[(P[:, 0] >= lo + k * SLICE) & (P[:, 0] < lo + (k + 1) * SLICE)]
        if len(s) == 0:
            out.append(out[-1] if out else (0.0, 1.0))
            continue
        out.append(((s[:, 1].min() + s[:, 1].max()) * 0.5, max((s[:, 1].max() - s[:, 1].min()) * 0.5, 1e-4)))
    return np.array(out)


def edge_mask(P, T):
    c = P[T].mean(1)
    lines = blade_lines(P)
    k = np.clip(((c[:, 0] - GUARD_X) / SLICE).astype(int), 0, len(lines) - 1)
    off = np.abs(c[:, 1] - lines[k, 0]) / lines[k, 1]
    on_blade = c[:, 0] > GUARD_X
    return on_blade & ((off > EDGE_FRAC) | (c[:, 0] > TIP_X))


def to_game(P, N, centre_y):
    """Raw (x length, y width, z flat normal) -> game (+X the blade, +Y the flat's normal, Z the width)."""
    s = LENGTH_M / (P[:, 0].max() - P[:, 0].min())
    G = np.stack([P[:, 0] - P[:, 0].min(), P[:, 2], -(P[:, 1] - centre_y)], 1) * s
    M = np.stack([N[:, 0], N[:, 2], -N[:, 1]], 1)
    return G, M / np.maximum(np.linalg.norm(M, axis=1), 1e-12)[:, None]


def compact(P, N, UV, T):
    used, inv = np.unique(T.ravel(), return_inverse=True)
    return P[used], N[used], UV[used], inv.reshape(-1, 3)


def debug_png(P, T, edge):
    img = Image.new("RGB", (1400, 260), (40, 40, 46))
    d = ImageDraw.Draw(img)
    for tri, e in zip(T, edge):
        pts = [(40 + P[v, 0] * 1200, 130 + P[v, 2] * 1200) for v in tri]
        d.polygon(pts, fill=(170, 230, 255) if e else (110, 110, 120))
    img.save(os.path.join(PREP, "hero_blade_parts.png"))


def main():
    P, N, UV, T = read_mesh(SRC)
    raw_tris = len(T)
    T2 = mi_prep.simplify(P, T, BUDGET_TRIS, True)
    edge = edge_mask(P, T2)
    lines = blade_lines(P)
    centre_y = float(np.median(lines[:, 0]))
    G, M = to_game(P, N, centre_y)
    img = colour_map()
    buf = io.BytesIO()
    img.resize((TEX_PX, TEX_PX), Image.LANCZOS).save(buf, "JPEG", quality=JPEG_QUALITY)
    parts = {}
    for name, sel in (("steel", ~edge), ("edge", edge)):
        p, n, uv, t = compact(G, M, UV, T2[sel])
        parts[name] = (p, n, uv, t, None, None)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    write_glb(OUT, "hero_blade", parts, buf.getvalue())
    if "--debug" in sys.argv:
        debug_png(G, T2, edge)
    data = open(OUT, "rb").read()
    print(json.dumps({
        "id": "hero_blade",
        "raw_tris": raw_tris,
        "tris": len(T2),
        "steel_tris": int((~edge).sum()),
        "edge_tris": int(edge.sum()),
        "simplifier": mi_prep.BACKEND,
        "size_m": [round(float(v), 3) for v in (G[np.unique(T2)].max(0) - G[np.unique(T2)].min(0))],
        "map_px": TEX_PX,
        "file": OUT,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }))


if __name__ == "__main__":
    main()
