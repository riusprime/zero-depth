import bpy, bmesh, json, math
import numpy as np
from mathutils import Vector
out = {"images": {i.name: list(i.size) for i in bpy.data.images}}
o = bpy.data.objects["Body"]
mat = o.material_slots[0].material
img = None
for n in mat.node_tree.nodes:
    if n.type == 'BSDF_PRINCIPLED':
        l = n.inputs["Base Color"].links
        if l and l[0].from_node.type == 'TEX_IMAGE': img = l[0].from_node.image
out["base"] = img.name if img else None
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
me = o.data; mw = o.matrix_world
uv = me.uv_layers.active.data
col = np.zeros((len(me.vertices), 3)); cnt = np.zeros(len(me.vertices))
for l in me.loops:
    u, v = uv[l.index].uv
    c = px[min(H - 1, max(0, int(v % 1.0 * H))), min(W - 1, max(0, int(u % 1.0 * W))), :3]
    col[l.vertex_index] += c; cnt[l.vertex_index] += 1
col /= np.maximum(cnt, 1)[:, None]
# tan: red clearly above blue
tan = (col[:, 0] > col[:, 2] * 1.25) & (col[:, 0] > 0.12)
out["tan_count"] = int(tan.sum())
out["col_samples"] = [[round(float(x), 2) for x in col[i]] for i in range(0, len(col), 1500)]
# clusters of tan verts through edges
adj = {}
for e in me.edges:
    a, b = e.vertices
    if tan[a] and tan[b]: adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
# weld by position so UV seams don't split clusters
key = {}
for v in me.vertices:
    if tan[v.index]:
        k = tuple(round(x, 3) for x in (mw @ v.co)); key.setdefault(k, []).append(v.index)
for k, lst in key.items():
    for a in lst[1:]: adj.setdefault(lst[0], []).append(a); adj.setdefault(a, []).append(lst[0])
seen = set(); cl = []
for v in me.vertices:
    i = v.index
    if not tan[i] or i in seen: continue
    comp = [i]; seen.add(i); k = 0
    while k < len(comp):
        for u in adj.get(comp[k], []):
            if u not in seen: seen.add(u); comp.append(u)
        k += 1
    cs = [mw @ me.vertices[u].co for u in comp]
    if len(comp) >= 6:
        cl.append({"n": len(comp), "min": [round(min(c[i] for c in cs), 2) for i in range(3)], "max": [round(max(c[i] for c in cs), 2) for i in range(3)]})
cl.sort(key=lambda d: -d["max"][2])
out["tan_clusters"] = cl
# cross-sections: per z band, per sector, max radius and mean radius about (0, 0)
sec = {}
for v in me.vertices:
    c = mw @ v.co
    zb = int(c.z / 0.25); a = int(((math.degrees(math.atan2(c.y, c.x)) + 360 + 22.5) % 360) / 45)
    sec.setdefault(zb, {}).setdefault(a, []).append(math.hypot(c.x, c.y))
out["sections"] = {f"{zb * 0.25:.2f}": {a: [len(r), round(sum(r) / len(r), 2), round(max(r), 2)] for a, r in sorted(d.items())} for zb, d in sorted(sec.items())}
ys = {}
for v in me.vertices:
    c = mw @ v.co; zb = int(c.z / 0.25); ys.setdefault(zb, []).append(c)
out["bands"] = {f"{zb * 0.25:.2f}": [round(min(c.x for c in cs), 2), round(max(c.x for c in cs), 2), round(min(c.y for c in cs), 2), round(max(c.y for c in cs), 2)] for zb, cs in sorted(ys.items())}
print("JSON>>" + json.dumps(out))
