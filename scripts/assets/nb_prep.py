"""v0.9.0 Step NB1: prepares the owner's four new boss models (unprocessed_images/models_v090_bosses/, five files: the
Twin Wardens are two) for the game. The raw files stay untouched.

The raw files are Tripo exports: one textured mesh each (about 19k triangles), normalised to a 1 m cube with the
feet at y = 0, facing +Z, one material with three maps (base colour, metallic-roughness, normal). Two carry a
Mixamo skeleton (`mixamorig:*`, 52 and 49 joints, no clips): the amber Warden and the Clockwork Judge.

Unlike mi2_prep.py (which re-bakes a small enemy onto a new atlas, losing the normal map), a boss keeps its own
UVs and all three maps: its triangle count (15-20k, the art list's) is already a boss's, so nothing is simplified.
Per model (SPECS):
1. turned into the game's file frame: front kept on +Z (BossModels turns it to +X), centred on x/z, bottom at y = 0,
   scaled evenly to the art list's height (m);
2. the three maps reduced to MAP_PX (the Tidecaller's are 7 MB as delivered): base colour and metallic-roughness as
   JPEG, the normal map as JPEG too (as the shipped Hive Lens's), all embedded;
3. a static model (the Tidecaller, the violet Warden, the Lantern Shade) is cut into the parts the art list names
   (PARTS: triangles by region of the figure, measured on renders of the raw files), each part one glTF node with its
   origin at its pivot, so the avatar can swing it in code (BossModels rigs each part as one bone);
4. a rigged model keeps its skeleton, skin and vertices as delivered, under a new root node that does the centring and
   the scale; its joints' rest transforms, missing from the files (every joint at the origin), are rebuilt from their
   inverse bind matrices (repair_joints), so the rest pose matches the mesh and the avatar can drive its bones in code.

It prints one JSON line per model (raw triangles and size, the parts and their triangles and pivots, the size in
metres, the file written, its size and sha256: pasted into assets/models/manifest.json and the evidence by hand).

Run from the repo root:  python -I scripts/assets/nb_prep.py [ids...]   (numpy and Pillow; mi_prep's reader).
`--labels <id> <out.npy>` writes the per-triangle part labels of a static model (for checking renders).
"""

import hashlib
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

SRC = "unprocessed_images/models_v090_bosses"
OUT = "assets/models/bosses"
MAP_PX = 1024
JPEG_QUALITY = 90

## id: height (m, the art list's), and either "parts" (a PARTS rule) or "rigged".
SPECS = {
    "boss_tidecaller": {"height": 3.2, "parts": "tidecaller"},
    "boss_twin_warden_amber": {"height": 2.2, "rigged": True},
    "boss_twin_warden_violet": {"height": 2.2, "parts": "warden_violet"},
    # The Judge's file carries a Mixamo skin (49 joints) but its inverse bind matrices are not matrices (the bytes at
    # their buffer view decode to values up to 1e32; Godot imports it with the mesh collapsed out of sight) and its
    # joints have no transforms: no rest pose can be recovered, so the skin is left out and it is cut into the art
    # list's parts like the static ones (its vertices are the bind pose, the shape the renders show).
    "boss_clockwork_judge": {"height": 3.6, "parts": "clockwork_judge"},
    "boss_lantern_shade": {"height": 3.4, "parts": "lantern_shade"},
}


# --- reading -------------------------------------------------------------------------------------------------------


def read(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20 : 20 + n])
    bl = struct.unpack("<I", data[20 + n : 24 + n])[0]
    blob = data[28 + n : 28 + n + bl]
    return j, blob


def accessor(j, blob, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
    k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    if stride and stride != np.dtype(dt).itemsize * k:
        raise ValueError("interleaved accessor %d" % i)
    arr = np.frombuffer(blob, dt, a["count"] * k, o)
    return arr.reshape(-1, k) if k > 1 else arr


def image_bytes(j, blob, k):
    bv = j["bufferViews"][j["images"][k]["bufferView"]]
    o = bv.get("byteOffset", 0)
    return blob[o : o + bv["byteLength"]]


def reduced_maps(j, blob):
    """The material's three maps, reduced to MAP_PX: {"base" | "rm" | "normal": jpeg bytes}, plus the raw sizes."""
    mat = j["materials"][0]
    which = {
        "base": mat["pbrMetallicRoughness"]["baseColorTexture"]["index"],
        "rm": mat["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"],
        "normal": mat["normalTexture"]["index"],
    }
    out, raw = {}, {}
    for name, t in which.items():
        src = Image.open(io.BytesIO(image_bytes(j, blob, j["textures"][t]["source"]))).convert("RGB")
        raw[name] = list(src.size)
        if max(src.size) > MAP_PX:
            src = src.resize((MAP_PX, MAP_PX), Image.LANCZOS)
        buf = io.BytesIO()
        src.save(buf, "JPEG", quality=JPEG_QUALITY)
        out[name] = buf.getvalue()
    return out, raw


def frame(P, height):
    """Centre on x/z, bottom at y = 0, scale evenly to `height`: (scale, offset) with game = P * scale + offset."""
    lo, hi = P.min(0), P.max(0)
    s = height / max(hi[1] - lo[1], 1e-9)
    off = -np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]) * s
    return s, off


# --- parts ---------------------------------------------------------------------------------------------------------


def tidecaller_parts(c, H):
    """The Tidecaller (front +Z; its staff in its right hand at -X, its reaching arm at +X): the bell at the staff's
    top, the staff (with the hand on it), the reaching arm from the shoulder, the back shell; the robe, the mask and
    the shoulders stay `Body`. Shares of the height, read from renders of the raw file."""
    x, y, z = c[:, 0] / H, c[:, 1] / H, c[:, 2] / H
    lab = np.array(["Body"] * len(c), dtype=object)
    piv = {"Body": np.array([0.0, 0.0, 0.0])}

    def take(mask, name, pivot):
        mask = mask & (lab == "Body")
        if mask.any():
            lab[mask] = name
            piv[name] = np.array(pivot, float) * H

    take((x < -0.27) & (y > 0.6) & (y < 0.845), "Bell", [-0.345, 0.84, 0.1])
    # The staff: the pole (its axis leans from (-0.325, z -0.01) low to (-0.34, z 0.1) at the top) and the hook over
    # the bell, with the hand holding it; pivoted at the hand.
    zaxis = -0.02 + 0.13 * y
    pole = (np.abs(x + 0.33) < 0.035) & (np.abs(z - zaxis) < 0.045) & (y > 0.1)
    take(pole | ((x < -0.29) & (y >= 0.845)), "Staff", [-0.33, 0.5, 0.03])
    take((x > 0.24) & (y > 0.18) & (y < 0.66), "ArmL", [0.22, 0.6, 0.02])
    take(((y > 0.62) & (z < -0.03) & (np.abs(x) < 0.3)) | ((y > 0.83) & (np.abs(x) < 0.25) & (z < 0.04)), "Shell",
         [0.0, 0.7, -0.12])
    return lab, piv


def warden_violet_parts(c, H):
    """The violet Warden (front +Z; its tower shield on its right arm at -X, its sword at +X): the shield (with the
    shackle), the sword, the helm; the armour and the cape stay `Body`."""
    x, y, z = c[:, 0] / H, c[:, 1] / H, c[:, 2] / H
    lab = np.array(["Body"] * len(c), dtype=object)
    piv = {"Body": np.array([0.0, 0.0, 0.0])}

    def take(mask, name, pivot):
        mask = mask & (lab == "Body")
        if mask.any():
            lab[mask] = name
            piv[name] = np.array(pivot, float) * H

    take((y > 0.8) & (np.abs(x) < 0.1), "Helm", [0.0, 0.8, 0.0])
    # The shield: the slab outside x = -0.25 in front of the cape (z > -0.1) and its hanging chain, below the
    # shoulder plate; pivoted at the forearm.
    take((x < -0.25) & (y > 0.1) & (y < 0.64) & (z > -0.1), "Shield", [-0.28, 0.5, 0.04])
    take((x > 0.2) & (y > 0.05) & (y < 0.36) & (z > 0.02), "Sword", [0.25, 0.36, 0.08])
    return lab, piv


def lantern_shade_parts(c, H):
    """The Lantern Shade (front +Z). The delivered file has no lantern cage for a head (a dark hood instead) and only
    the held lantern: its arms and the held lantern on its chain are cut; the cloak and hood stay `Body`."""
    x, y, z = c[:, 0] / H, c[:, 1] / H, c[:, 2] / H
    lab = np.array(["Body"] * len(c), dtype=object)
    piv = {"Body": np.array([0.0, 0.0, 0.0])}

    def take(mask, name, pivot):
        mask = mask & (lab == "Body")
        if mask.any():
            lab[mask] = name
            piv[name] = np.array(pivot, float) * H

    take((x < -0.3) & (y < 0.45), "HandLantern", [-0.36, 0.45, 0.02])
    take((x < -0.25) & (y > 0.3) & (y < 0.72), "ArmR", [-0.25, 0.66, 0.0])
    take((x > 0.25) & (y > 0.3) & (y < 0.72), "ArmL", [0.25, 0.66, 0.0])
    return lab, piv


def clockwork_judge_parts(c, H):
    """The Clockwork Judge (front +Z; its left at +X). Its file's skin can't be used (see SPECS), so it is cut like the
    static ones: the two pendulum arms with their gavels from the shoulder, the gear cage at the waist, the clock's two
    hands (the triangles standing proud of the face, split by side; the longer is the minute hand); the rest `Body`."""
    x, y, z = c[:, 0] / H, c[:, 1] / H, c[:, 2] / H
    lab = np.array(["Body"] * len(c), dtype=object)
    piv = {"Body": np.array([0.0, 0.0, 0.0])}

    def take(mask, name, pivot):
        mask = mask & (lab == "Body")
        if mask.any():
            lab[mask] = name
            piv[name] = np.array(pivot, float) * H

    arm = ((np.abs(x) > 0.255) & (y > 0.09) & (y < 0.68)) | ((np.abs(x) > 0.17) & (y > 0.11) & (y < 0.34))
    take(arm & (x > 0), "ArmL", [0.27, 0.68, 0.0])
    take(arm & (x < 0), "ArmR", [-0.27, 0.68, 0.0])
    take((np.abs(x) < 0.075) & (y > 0.3) & (y < 0.56) & (z > 0.0), "Gears", [0.0, 0.43, 0.06])
    centre = np.array([0.0, 0.645])
    d = np.hypot(x - centre[0], y - centre[1])
    face = (d < 0.09) & (lab == "Body")
    if face.any():
        front = np.percentile(z[face], 60)
        proud = face & (z > front + 0.006) & (d > 0.008)
        reach = {}
        for side, name in ((x < 0, "a"), (x >= 0, "b")):
            m = proud & side
            reach[name] = (m, d[m].max() if m.any() else 0.0)
        longer = "a" if reach["a"][1] >= reach["b"][1] else "b"
        for key, (m, _r) in reach.items():
            hand = "HandMinute" if key == longer else "HandHour"
            take(m, hand, [0.0, 0.645, front])
    return lab, piv


PARTS = {
    "clockwork_judge": clockwork_judge_parts,
    "tidecaller": tidecaller_parts,
    "warden_violet": warden_violet_parts,
    "lantern_shade": lantern_shade_parts,
}


# --- writing -------------------------------------------------------------------------------------------------------


def pad4(b, fill=b"\0"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write(path, gltf, blob):
    js = pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    blob = pad4(blob)
    gltf_len = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, gltf_len))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0") + blob)


def material_of(j):
    mat = j["materials"][0]
    out = {
        "name": "body",
        "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0},
            "metallicRoughnessTexture": {"index": 1},
        },
        "normalTexture": {"index": 2},
    }
    for k in ("metallicFactor", "roughnessFactor", "baseColorFactor"):
        if k in mat.get("pbrMetallicRoughness", {}):
            out["pbrMetallicRoughness"][k] = mat["pbrMetallicRoughness"][k]
    if "scale" in mat.get("normalTexture", {}):
        out["normalTexture"]["scale"] = mat["normalTexture"]["scale"]
    return out


def prepare_static(rid, spec, j, blob, maps):
    prim = j["meshes"][0]["primitives"][0]
    at = prim["attributes"]
    P = accessor(j, blob, at["POSITION"]).astype(np.float64)
    N = accessor(j, blob, at["NORMAL"]).astype(np.float64)
    UV = accessor(j, blob, at["TEXCOORD_0"]).astype(np.float64)
    I = accessor(j, blob, prim["indices"]).astype(np.int64).reshape(-1, 3)
    s, off = frame(P, spec["height"])
    G = P * s + off
    lab, piv = PARTS[spec["parts"]](G[I].mean(1), spec["height"])
    out = bytearray()
    views, accs, meshes, nodes = [], [], [], []

    def add(arr, target, comp, typ, minmax=False):
        data = np.ascontiguousarray(arr).tobytes()
        views.append({"buffer": 0, "byteOffset": len(out), "byteLength": len(data)})
        if target:
            views[-1]["target"] = target
        out.extend(pad4(data))
        a = {"bufferView": len(views) - 1, "componentType": comp, "count": len(arr), "type": typ}
        if minmax:
            a["min"] = arr.min(0).tolist()
            a["max"] = arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    parts = {}
    for name in sorted(piv, key=lambda n: (n != "Body", n)):
        T = I[lab == name]
        if len(T) == 0:
            continue
        used, inv = np.unique(T.ravel(), return_inverse=True)
        V = (G[used] - piv[name]).astype(np.float32)
        meshes.append({"name": name, "primitives": [{
            "attributes": {
                "POSITION": add(V, 34962, 5126, "VEC3", True),
                "NORMAL": add(N[used].astype(np.float32), 34962, 5126, "VEC3"),
                "TEXCOORD_0": add(UV[used].astype(np.float32), 34962, 5126, "VEC2"),
            },
            "indices": add(inv.astype(np.uint32), 34963, 5125, "SCALAR"),
            "material": 0,
            "mode": 4,
        }]})
        nodes.append({"name": name, "mesh": len(meshes) - 1, "translation": [float(v) for v in piv[name]]})
        parts[name] = [int(len(T)), [round(float(v), 3) for v in piv[name]]]
    images = []
    for k, name in enumerate(("base", "rm", "normal")):
        views.append({"buffer": 0, "byteOffset": len(out), "byteLength": len(maps[name])})
        out.extend(pad4(maps[name]))
        images.append({"name": name, "bufferView": len(views) - 1, "mimeType": "image/jpeg"})
    gltf = {
        "asset": {"version": "2.0", "generator": "zero-depth scripts/assets/nb_prep.py (from the owner's Tripo file)"},
        "scene": 0,
        "scenes": [{"nodes": [len(nodes)]}],
        "nodes": nodes + [{"name": rid, "children": list(range(len(nodes)))}],
        "meshes": meshes,
        "materials": [material_of(j)],
        "textures": [{"source": k, "sampler": 0} for k in range(3)],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": images,
        "accessors": accs,
        "bufferViews": views,
        "buffers": [{"byteLength": len(pad4(bytes(out)))}],
    }
    dst = os.path.join(OUT, rid + ".glb")
    write(dst, gltf, bytes(out))
    return dst, len(I), parts, (G.max(0) - G.min(0)), lab


def repair_joints(j, blob):
    """The owner's two rigged files carry their joints' inverse bind matrices but no joint transforms (every joint
    node sits at the origin, unturned), so the rest pose the file describes folds the mesh up. Each joint's rest is
    rebuilt from its bind: its global transform is the inverse of its inverse bind matrix (the mesh is in the
    skeleton's space), its local one that relative to its parent joint's. Returns how many joints were set."""
    sk = j["skins"][0]
    ibm = accessor(j, blob, sk["inverseBindMatrices"]).reshape(-1, 4, 4).astype(np.float64)
    parent = {c: p for p, n in enumerate(j["nodes"]) for c in n.get("children", [])}
    glob = {}
    # Parents first (the joint list is in hierarchy order); a degenerate bind (an unweighted end joint whose matrix
    # can't be inverted) takes its parent's transform.
    for k, node in enumerate(sk["joints"]):
        m = ibm[k].T
        if abs(np.linalg.det(m[:3, :3])) > 1e-6:
            glob[node] = np.linalg.inv(m)
        else:
            glob[node] = glob.get(parent.get(node), np.eye(4))
    for node, g in glob.items():
        p = parent.get(node)
        local = np.linalg.inv(glob[p]) @ g if p in glob else g
        n = j["nodes"][node]
        for k in ("translation", "rotation", "scale", "matrix"):
            n.pop(k, None)
        # The binds are stored to 3 decimals: the turn is made exactly orthonormal again (SVD), the scale dropped.
        u, _sv, vt = np.linalg.svd(local[:3, :3])
        r = u @ vt
        if np.linalg.det(r) < 0.0 or not np.isfinite(r).all():
            r = np.eye(3)
        n["translation"] = [float(v) for v in local[:3, 3]]
        n["rotation"] = quat_of(r)
    return len(glob)


def quat_of(r):
    """A rotation matrix's quaternion [x, y, z, w] (glTF order)."""
    t = np.trace(r)
    if t > 0.0:
        s = np.sqrt(t + 1.0) * 2.0
        q = [(r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s, 0.25 * s]
    elif r[0, 0] > r[1, 1] and r[0, 0] > r[2, 2]:
        s = np.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2.0
        q = [0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s, (r[2, 1] - r[1, 2]) / s]
    elif r[1, 1] > r[2, 2]:
        s = np.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2.0
        q = [(r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s, (r[0, 2] - r[2, 0]) / s]
    else:
        s = np.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2.0
        q = [(r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s, (r[1, 0] - r[0, 1]) / s]
    q = np.array(q)
    return [float(v) for v in q / np.linalg.norm(q)]


def prepare_rigged(rid, spec, j, blob, maps):
    """Keeps the skeleton, the skin and every vertex as delivered (the joints' rest rebuilt: repair_joints); a new root
    node centres and scales it, and the
    three maps are swapped for the reduced ones (the buffer rebuilt view by view)."""
    repaired = repair_joints(j, blob)  # before the buffer is rebuilt (it reads the bind matrices)
    prim = j["meshes"][0]["primitives"][0]
    P = accessor(j, blob, prim["attributes"]["POSITION"]).astype(np.float64)
    tris = sum(j["accessors"][p["indices"]]["count"] // 3 for m in j["meshes"] for p in m["primitives"])
    s, off = frame(P, spec["height"])
    image_view = {}
    for k, name in enumerate(("base", "rm", "normal")):
        t = {"base": j["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"],
             "rm": j["materials"][0]["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"],
             "normal": j["materials"][0]["normalTexture"]["index"]}[name]
        src = j["textures"][t]["source"]
        image_view[j["images"][src]["bufferView"]] = maps[name]
        j["images"][src] = {"name": name, "bufferView": j["images"][src]["bufferView"],
                            "mimeType": "image/jpeg"}
    out = bytearray()
    for vi, bv in enumerate(j["bufferViews"]):
        o = bv.get("byteOffset", 0)
        data = image_view.get(vi, blob[o : o + bv["byteLength"]])
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(data)
        out.extend(pad4(data))
    j["buffers"] = [{"byteLength": len(out)}]
    j["materials"][0] = {**material_of(j), "pbrMetallicRoughness": j["materials"][0]["pbrMetallicRoughness"],
                         "normalTexture": j["materials"][0]["normalTexture"]}
    j["materials"][0]["name"] = "body"
    j["materials"][0].pop("extensions", None)
    for k in ("extensionsUsed", "extensionsRequired"):
        j.pop(k, None)
    roots = j["scenes"][j.get("scene", 0)]["nodes"]
    j["nodes"].append({"name": rid, "children": list(roots), "scale": [s, s, s],
                       "translation": [float(v) for v in off]})
    j["scenes"] = [{"nodes": [len(j["nodes"]) - 1]}]
    j["scene"] = 0
    j["asset"] = {"version": "2.0", "generator": "zero-depth scripts/assets/nb_prep.py (from the owner's Tripo file)"}
    dst = os.path.join(OUT, rid + ".glb")
    write(dst, j, bytes(out))
    joints = len(j["skins"][0]["joints"]) if j.get("skins") else 0
    return dst, tris, joints, (P.max(0) - P.min(0)) * s, repaired


def prepare(rid):
    spec = SPECS[rid]
    src = os.path.join(SRC, rid + ".glb")
    j, blob = read(src)
    maps, raw_px = reduced_maps(j, blob)
    os.makedirs(OUT, exist_ok=True)
    row = {"id": rid, "raw_bytes": os.path.getsize(src), "raw_maps_px": raw_px}
    if spec.get("rigged"):
        dst, tris, joints, size, repaired = prepare_rigged(rid, spec, j, blob, maps)
        row.update({"tris": tris, "joints": joints, "joints_rest_rebuilt": repaired})
    else:
        dst, tris, parts, size, _lab = prepare_static(rid, spec, j, blob, maps)
        row.update({"tris": tris, "parts": parts})
    row.update({
        "maps_px": MAP_PX, "size": [round(float(v), 3) for v in size], "path": dst.replace(os.sep, "/"),
        "bytes": os.path.getsize(dst), "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
    })
    return row


def labels(rid, out):
    spec = SPECS[rid]
    j, blob = read(os.path.join(SRC, rid + ".glb"))
    prim = j["meshes"][0]["primitives"][0]
    P = accessor(j, blob, prim["attributes"]["POSITION"]).astype(np.float64)
    I = accessor(j, blob, prim["indices"]).astype(np.int64).reshape(-1, 3)
    s, off = frame(P, spec["height"])
    lab, piv = PARTS[spec["parts"]]((P * s + off)[I].mean(1), spec["height"])
    names = sorted(piv, key=lambda n: (n != "Body", n))
    np.save(out, np.array([names.index(v) for v in lab]))
    print(json.dumps({n: int((lab == n).sum()) for n in names}))


def main():
    if sys.argv[1:2] == ["--labels"]:
        labels(sys.argv[2], sys.argv[3])
        return 0
    for rid in sys.argv[1:] or list(SPECS):
        print(json.dumps(prepare(rid)), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
