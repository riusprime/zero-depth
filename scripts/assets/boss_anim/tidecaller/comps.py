"""src.blend: join all parts, weld, list connected components (size, bounds, which parts they came from)."""
import bpy, sys, os, bmesh
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
bm = bmesh.new()
lay = bm.verts.layers.int.new("part")
names = []
for o in bpy.data.objects:
    if o.type != 'MESH': continue
    names.append(o.name); k = len(names) - 1
    n0 = len(bm.verts)
    me = o.data.copy(); me.transform(o.matrix_world)
    bm.from_mesh(me); bm.verts.ensure_lookup_table()
    for i in range(n0, len(bm.verts)): bm.verts[i][lay] = k
nv = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.verts.ensure_lookup_table()
seen = set(); comps = []
for v in bm.verts:
    if v.index in seen: continue
    st = [v]; seen.add(v.index); c = []
    while st:
        u = st.pop(); c.append(u)
        for e in u.link_edges:
            w = e.other_vert(u)
            if w.index not in seen: seen.add(w.index); st.append(w)
    comps.append(c)
comps.sort(key=len, reverse=True)
res = []
for c in comps[:60]:
    ps = {}
    for u in c: ps[names[u[lay]]] = ps.get(names[u[lay]], 0) + 1
    res.append({"n": len(c), "min": [round(min(u.co[i] for u in c), 2) for i in range(3)],
                "max": [round(max(u.co[i] for u in c), 2) for i in range(3)], "parts": ps})
zdlib.emit({"verts": nv, "welded": len(bm.verts), "ncomps": len(comps), "sizes": [len(c) for c in comps[:80]]})
for r in res: print("JSON>>", r)
