"""Connected pieces of one object's welded mesh restricted to a box.  -- <Obj> <xmin,xmax,ymin,ymax,zmin,zmax> [more boxes]"""
import bpy, sys, os, bmesh
args = sys.argv[sys.argv.index('--') + 1:]
o = bpy.data.objects[args[0]]
bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.transform(bm, matrix=o.matrix_world, verts=bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.verts.ensure_lookup_table()
for spec in args[1:]:
    b = [float(x) for x in spec.split(',')]
    ok = lambda p: b[0] <= p.x <= b[1] and b[2] <= p.y <= b[3] and b[4] <= p.z <= b[5]
    seen = set(); rows = []
    for v in bm.verts:
        if v.index in seen or not ok(v.co): continue
        st = [v]; seen.add(v.index); c = []
        while st:
            u = st.pop(); c.append(u.co)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen and ok(w.co): seen.add(w.index); st.append(w)
        rows.append((len(c), [round(min(p[i] for p in c), 2) for i in range(3)], [round(max(p[i] for p in c), 2) for i in range(3)]))
    rows.sort(key=lambda r: -r[0])
    print(f"BC box {spec}: {len(rows)} pieces")
    for n, lo, hi in rows:
        if n >= 6: print(f"BC   {n:5d}  min {lo}  max {hi}")
