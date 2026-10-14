# The owner's desert merchant stall (v0.8.0 SR; a Tripo file: one mesh, one textured material, no skeleton or clips,
# 10,558 triangles, about 1.0 x 0.64 x 1.0 units) made ready for the game: its connected pieces are found (as
# split_final_boss.py does), the loose crate pile standing apart in front of one end of the counter is left out (it
# would stand in the counter's approach; the stall's other pieces are kept), and the rest is moved so its footprint is
# centred on x and z with its bottom at y = 0. Its front (the counters, the vendor's face) is +X as delivered; it is
# not scaled (ShopModels scales it in game). The vendor is part of the stall's main piece (fused, no cut possible), so
# it stays in the mesh. Writes only the output file.
# Usage: python3 -I scripts/art/shop_stall.py unprocessed_images/shop/shop_stall_desert_raw.glb assets/models/shop/shop_tent.glb
import json, struct, sys
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
b = open(src, "rb").read()
n = struct.unpack("<I", b[12:16])[0]
j = json.loads(b[20:20 + n])
binlen = struct.unpack("<I", b[20 + n:24 + n])[0]
bin_ = b[28 + n:28 + n + binlen]


def acc(i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
    k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    arr = np.frombuffer(bin_, dt, a["count"] * k, o)
    return arr.reshape(-1, k) if k > 1 else arr


assert len(j["meshes"]) == 1 and len(j["meshes"][0]["primitives"]) == 1, "one mesh, one primitive"
for nd in j["nodes"]:
    assert not any(k in nd for k in ("rotation", "scale", "translation", "matrix")), "no node transform"
prim = j["meshes"][0]["primitives"][0]
at = prim["attributes"]
P = acc(at["POSITION"]).astype(np.float64)
I = acc(prim["indices"]).reshape(-1, 3).astype(np.int64)
extra = {k: acc(v) for k, v in at.items() if k != "POSITION"}
# Connected pieces (vertices welded by position).
key = np.round(P, 5)
_, inv = np.unique(key, axis=0, return_inverse=True)
inv = inv.ravel()
par = np.arange(inv.max() + 1)


def f(x):
    r = x
    while par[r] != r:
        r = par[r]
    while par[x] != r:
        par[x], x = r, par[x]
    return r


for t in inv[I]:
    for u, v in ((t[0], t[1]), (t[1], t[2])):
        ru, rv = f(u), f(v)
        if ru != rv:
            par[ru] = rv
root = np.array([f(x) for x in inv])
keep = np.ones(len(P), bool)
for r in np.unique(root):
    m = root == r
    lo, hi = P[m].min(0), P[m].max(0)
    tris = int(np.sum(m[I[:, 0]]))
    loose = lo[0] > 0.25 and lo[2] < -0.45 and tris > 300  # the crate pile in front of the counter's -z end
    print("piece: %5d tris  min %s  max %s%s" % (tris, np.round(lo, 3).tolist(), np.round(hi, 3).tolist(), "  <- left out" if loose else ""))
    if loose:
        keep[m] = False
tri = I[keep[I[:, 0]]]
used = np.unique(tri)
remap = -np.ones(len(P), np.int64)
remap[used] = np.arange(len(used))
pos = P[used].copy()
lo, hi = pos.min(0), pos.max(0)
pos[:, 0] -= (lo[0] + hi[0]) / 2
pos[:, 2] -= (lo[2] + hi[2]) / 2
pos[:, 1] -= lo[1]
print("kept: %d tris, size (x front-to-back, y height, z across) %s" % (len(tri), np.round(pos.max(0) - pos.min(0), 4).tolist()))
attrs = {"POSITION": pos.astype(np.float32)}
attrs.update({k: v[used].astype(v.dtype) for k, v in extra.items()})
idx = remap[tri].astype(np.uint32).ravel()
img = j["images"][0]
ibv = j["bufferViews"][img["bufferView"]]
imgbytes = bin_[ibv.get("byteOffset", 0):ibv.get("byteOffset", 0) + ibv["byteLength"]]


def pad(x, c=b"\0"):
    return x + c * ((4 - len(x) % 4) % 4)


blob = b""
views = []
accs = []
amap = {}
for k, v in attrs.items():
    data = np.ascontiguousarray(v).tobytes()
    views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": 34962})
    blob = pad(blob + data)
    a = {"bufferView": len(views) - 1, "componentType": 5126, "count": len(v), "type": {2: "VEC2", 3: "VEC3", 4: "VEC4"}[v.shape[1]]}
    if k == "POSITION":
        a["min"] = v.min(0).tolist()
        a["max"] = v.max(0).tolist()
    accs.append(a)
    amap[k] = len(accs) - 1
data = idx.tobytes()
views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": 34963})
blob = pad(blob + data)
accs.append({"bufferView": len(views) - 1, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(imgbytes)})
blob = pad(blob + imgbytes)
gj = {
    "asset": {"version": "2.0", "generator": "zero-depth scripts/art/shop_stall.py (from the owner's Tripo file)"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "shop_tent", "mesh": 0}],
    "meshes": [{"name": "shop_tent", "primitives": [{"attributes": amap, "indices": len(accs) - 1, "material": 0}]}],
    "materials": j["materials"],
    "textures": j["textures"],
    "images": [{"name": img.get("name"), "mimeType": img["mimeType"], "bufferView": len(views) - 1}],
    "accessors": accs,
    "bufferViews": views,
    "buffers": [{"byteLength": len(blob)}],
}
if j.get("samplers"):
    gj["samplers"] = j["samplers"]
else:
    for t in gj["textures"]:
        t.pop("sampler", None)
js = pad(json.dumps(gj).encode(), b" ")
glb = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(blob)) + struct.pack("<I", len(js)) + b"JSON" + js
glb += struct.pack("<I", len(blob)) + b"BIN\0" + blob
open(dst, "wb").write(glb)
print("wrote", dst, len(glb), "bytes")
