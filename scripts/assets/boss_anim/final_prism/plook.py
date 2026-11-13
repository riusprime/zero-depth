"""src.blend: size, loose pieces (welded), six views."""
import bpy, sys, os, bmesh
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Vector
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
me = o.data
pts = [o.matrix_world @ v.co for v in me.vertices]
mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00005)
bm.verts.ensure_lookup_table()
seen = set(); comps = []
for v in bm.verts:
    if v.index in seen: continue
    st = [v]; seen.add(v.index); c = []
    while st:
        u = st.pop(); c.append(u.index)
        for e in u.link_edges:
            w = e.other_vert(u)
            if w.index not in seen: seen.add(w.index); st.append(w)
    comps.append(c)
comps.sort(key=len, reverse=True)
res = []
for c in comps[:60]:
    ws = [bm.verts[i].co for i in c]
    lo = [round(min(p[i] for p in ws), 3) for i in range(3)]; hi = [round(max(p[i] for p in ws), 3) for i in range(3)]
    res.append([len(c), lo, hi])
zdlib.emit({"verts": len(me.vertices), "tris": sum(len(p.vertices) - 2 for p in me.polygons), "min": [round(x, 4) for x in mn], "max": [round(x, 4) for x in mx],
            "welded": len(bm.verts), "ncomps": len(comps), "comps": res,
            "mats": [s.material.name for s in o.material_slots], "images": [(i.name, list(i.size), i.filepath) for i in bpy.data.images]})
c = (mn + mx) / 2; size = max(mx - mn) * 1.15
zdlib.setup_render((640, 640))
ps = []
for nm, v in [("front", (0, -1, 0)), ("left", (1, 0, 0)), ("back", (0, 1, 0)), ("right", (-1, 0, 0)), ("top", (0, 0, 1)), ("below", (0.01, -0.02, -1))]:
    p = os.path.join(out, f"_look_{nm}.png"); zdlib.render(p, v, target=tuple(c), ortho=size, dist=5); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "look_sheet.png"), 3)
for p in ps: os.remove(p)
