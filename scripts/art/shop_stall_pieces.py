# The raw stall (v0.8.0 SR) seen from its front (+x), each connected piece in its own colour (the main body grey):
# the evidence that its vendor is part of the main body. Writes only the output png.
# Usage: python3 -I scripts/art/shop_stall_pieces.py unprocessed_images/shop/shop_stall_desert_raw.glb <out.png>
import json, struct, sys
import numpy as np
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
b = open(src, 'rb').read()
n = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + n]); binlen = struct.unpack('<I', b[20 + n:24 + n])[0]; bin_ = b[28 + n:28 + n + binlen]
def acc(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]
    k = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    arr = np.frombuffer(bin_, dt, a['count'] * k, o)
    return arr.reshape(-1, k) if k > 1 else arr
prim = j['meshes'][0]['primitives'][0]
P = acc(prim['attributes']['POSITION']).astype(float); I = acc(prim['indices']).reshape(-1, 3).astype(np.int64)
key = np.round(P, 5); _, inv = np.unique(key, axis=0, return_inverse=True); inv = inv.ravel()
par = np.arange(inv.max() + 1)
def f(x):
    r = x
    while par[r] != r: r = par[r]
    while par[x] != r: par[x], x = r, par[x]
    return r
for t in inv[I]:
    for u, v in ((t[0], t[1]), (t[1], t[2])):
        ru, rv = f(u), f(v)
        if ru != rv: par[ru] = rv
root = np.array([f(x) for x in inv])
ids, counts = np.unique(root[I[:, 0]], return_counts=True)
order = ids[np.argsort(-counts)]
palette = [(170, 170, 170), (230, 90, 70), (90, 200, 120), (90, 140, 240), (240, 220, 80), (200, 90, 220)]
tc = np.array([palette[list(order).index(r) % len(palette)] for r in root[I[:, 0]]])
W, S = 900, 800
tri = P[I]
right = np.array([0, 0, -1.]); up = np.array([0, 1, 0.]); fwd = np.array([-1, 0, 0.])
x = tri @ right; y = tri @ up; d = (tri @ fwd).mean(1)
nrm = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]); nrm /= (np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-12)
shade = 0.45 + 0.55 * np.abs(nrm @ (-fwd))
im = Image.new('RGB', (W, 600), (30, 30, 34)); dr = ImageDraw.Draw(im)
for t in np.argsort(-d):
    dr.polygon([(W / 2 + x[t, k] * S, 300 - y[t, k] * S) for k in range(3)], fill=tuple(int(c * shade[t]) for c in tc[t]))
im.save(out)
print('pieces by triangles:', sorted(counts.tolist(), reverse=True))
