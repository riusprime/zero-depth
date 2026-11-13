"""src.blend: connected pieces of the mesh (after welding by position), their boxes and their dominant bones;
then the weights of slices of interest."""
import bpy, sys, os, bmesh
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Vector
m = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'Icosphere'][0]
me = m.data
gn = {g.index: g.name for g in m.vertex_groups}
# weld by position
key = {}
rep = []
for v in me.vertices:
    k = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
    rep.append(key.setdefault(k, v.index))
par = list(range(len(me.vertices)))
def find(a):
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a
for e in me.edges:
    a, b = find(rep[e.vertices[0]]), find(rep[e.vertices[1]])
    if a != b: par[a] = b
groups = {}
for v in me.vertices:
    groups.setdefault(find(rep[v.index]), []).append(v.index)
out = []
for r, vs in sorted(groups.items(), key=lambda kv: -len(kv[1]))[:25]:
    cs = [me.vertices[i].co for i in vs]
    cnt = {}
    for i in vs:
        gs = me.vertices[i].groups
        if gs:
            g = max(gs, key=lambda g: g.weight); cnt[gn[g.group]] = cnt.get(gn[g.group], 0) + 1
    out.append({"n": len(vs), "min": [round(min(c[i] for c in cs), 2) for i in range(3)],
                "max": [round(max(c[i] for c in cs), 2) for i in range(3)],
                "dom": dict(sorted(cnt.items(), key=lambda kv: -kv[1])[:6])})
# how many influences, and how rigid
ninf = {}
for v in me.vertices:
    k = len([g for g in v.groups if g.weight > 0.01]); ninf[k] = ninf.get(k, 0) + 1
def region(lo, hi):
    cnt = {}; n = 0
    for v in me.vertices:
        if all(lo[i] <= v.co[i] <= hi[i] for i in range(3)):
            n += 1
            for g in v.groups:
                cnt[gn[g.group]] = cnt.get(gn[g.group], 0) + g.weight
    return {"n": n, "w": {k: round(x / max(n, 1), 2) for k, x in sorted(cnt.items(), key=lambda kv: -kv[1])[:7]}}
zdlib.emit({"pieces": len(groups), "top": out, "influences": ninf,
            "spear_top": region((-1, -1, 0.72), (1, -0.2, 1.1)), "spear_bottom": region((-1, -1, 0), (1, -0.2, 0.15)),
            "spear_mid_hi": region((0, -0.33, 0.5), (0.12, -0.2, 0.72)),
            "shield": region((-0.2, 0.27, 0), (0.3, 1, 0.6)),
            "plume": region((-1, -1, 0.78), (1, 0.15, 1.1)),
            "cape_low": region((-1, -0.15, 0.1), (-0.1, 0.2, 0.35)),
            "tabard_low": region((0.1, -0.1, 0.1), (1, 0.1, 0.3))})
