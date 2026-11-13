"""src.blend: connected pieces of the welded mesh in the work frame (1.5 m tall, facing -Y)."""
import bpy, sys, os, bmesh, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix
K = 1.5 / 0.19
T = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.transform(bm, matrix=T, verts=bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
seen = set(); comps = []
for v in bm.verts:
    if v.index in seen: continue
    st = [v]; seen.add(v.index); cs = []
    while st:
        a = st.pop(); cs.append(a)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b.index not in seen: seen.add(b.index); st.append(b)
    comps.append(cs)
res = []
for cs in sorted(comps, key=lambda c: -len(c)):
    mn = [round(min(v.co[i] for v in cs), 3) for i in range(3)]; mx = [round(max(v.co[i] for v in cs), 3) for i in range(3)]
    res.append([len(cs), mn, mx])
print("N", len(comps), "welded verts", len(bm.verts), "faces", len(bm.faces))
for r in res[:40]: print("C", r)
