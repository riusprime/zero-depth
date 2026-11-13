"""rig.blend: for each rigid piece, the islands of its vertices (welded by position): size, centre, box."""
import bpy, sys, os
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, parts
m = [o for o in bpy.data.objects if o.type == 'MESH'][0]; me = m.data
gn = {g.index: g.name for g in m.vertex_groups}
dom = [gn[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in me.vertices]
res = {}
for piece in ("Spear", "Shield", "L_Pauldron", "R_Pauldron"):
    key = {}; rep = {}
    for v in me.vertices:
        if dom[v.index] != piece: continue
        k = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)); rep[v.index] = key.setdefault(k, len(key))
    par = list(range(len(key)))
    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for e in me.edges:
        a, b = e.vertices
        if a in rep and b in rep:
            a, b = find(rep[a]), find(rep[b])
            if a != b: par[a] = b
    comp = {}
    for i, r in rep.items(): comp.setdefault(find(r), []).append(me.vertices[i].co)
    res[piece] = sorted(([len(vs), [round(x, 2) for x in sum(vs, Vector()) / len(vs)],
                          round(max(parts.spear_r(v) for v in vs), 3)] for vs in comp.values()), key=lambda x: -x[0])[:12]
zdlib.emit(res)
