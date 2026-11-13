"""src10.blend: one shell cut into bands along an axis; the pieces of each band.  -- <seed x y z> <axis 0-2> <step> [minverts]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
seed = Vector((float(a[0]), float(a[1]), float(a[2]))); ax = int(a[3]); step = float(a[4]); mnv = int(a[5]) if len(a) > 5 else 6
m = [o for o in bpy.data.objects if o.type == 'MESH'][0]; me = m.data
def comps(keep):
    parent = {i: i for i in keep}
    def find(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for e in me.edges:
        i, j = e.vertices
        if i in parent and j in parent:
            ra, rb = find(i), find(j)
            if ra != rb: parent[ra] = rb
    key = {}
    for i in keep:
        k = tuple(round(x, 3) for x in me.vertices[i].co)
        if k in key:
            ra, rb = find(key[k]), find(i)
            if ra != rb: parent[ra] = rb
        else: key[k] = i
    out = {}
    for i in keep: out.setdefault(find(i), []).append(i)
    return list(out.values())
allc = comps(set(range(len(me.vertices))))
best = min(allc, key=lambda c: min((me.vertices[i].co - seed).length for i in c))
lo = min(me.vertices[i].co[ax] for i in best); hi = max(me.vertices[i].co[ax] for i in best)
rows = []
z = lo
while z < hi:
    keep = {i for i in best if z <= me.vertices[i].co[ax] < z + step}
    for c in comps(keep):
        if len(c) < mnv: continue
        mn = [round(min(me.vertices[i].co[k] for i in c), 2) for k in range(3)]; mx = [round(max(me.vertices[i].co[k] for i in c), 2) for k in range(3)]
        rows.append(f"{z:.2f} n={len(c)} {mn} {mx}")
    z += step
print("JSON>>shell verts", len(best), "range", round(lo, 2), round(hi, 2))
for r in rows: print("JSON>>", r)
