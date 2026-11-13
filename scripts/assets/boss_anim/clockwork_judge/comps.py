"""Welded connected pieces of every mesh object: size and bounds.  -- [min verts]"""
import bpy, sys, os, bmesh
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
MINV = int(args[0]) if args else 12
res = {}
for o in bpy.data.objects:
    if o.type != 'MESH': continue
    bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.transform(bm, matrix=o.matrix_world, verts=bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.verts.ensure_lookup_table()
    seen = set(); rows = []
    for v in bm.verts:
        if v.index in seen: continue
        st = [v]; seen.add(v.index); c = []
        while st:
            u = st.pop(); c.append(u.co)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen: seen.add(w.index); st.append(w)
        rows.append((len(c), [round(min(p[i] for p in c), 2) for i in range(3)], [round(max(p[i] for p in c), 2) for i in range(3)]))
    rows.sort(key=lambda r: -r[0])
    print(f"CP {o.name}: {len(rows)} pieces, {len(bm.verts)} welded verts")
    for n, lo, hi in rows:
        if n >= MINV: print(f"CP   {n:5d}  min {lo}  max {hi}")
    bm.free()
