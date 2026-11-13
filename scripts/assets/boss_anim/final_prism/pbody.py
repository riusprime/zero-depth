"""src.blend: only the biggest piece (or only a z band of it), from chosen directions.  -- tag zlo zhi views(;-sep x,y,z) [ortho] [cz]"""
import bpy, sys, os, math, bmesh
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix
a = sys.argv[sys.argv.index('--') + 1:]
tag = a[0]; zlo = float(a[1]); zhi = float(a[2])
views = [tuple(float(x) for x in v.split(',')) for v in a[3].split(';')]
orth = float(a[4]) if len(a) > 4 else 3.4; cz = float(a[5]) if len(a) > 5 else 1.5
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
o.data.transform(Matrix.Rotation(math.radians(-90), 4, 'Z') @ Matrix.Scale(10, 4))
bm = bmesh.new(); bm.from_mesh(o.data)
# pieces through edges and coincident points
par = list(range(len(bm.verts)))
def find(x):
    while par[x] != x: par[x] = par[par[x]]; x = par[x]
    return x
key = {}
for v in bm.verts:
    k = tuple(round(c, 4) for c in v.co)
    if k in key: par[find(v.index)] = find(key[k])
    else: key[k] = v.index
for e in bm.edges:
    x, y = find(e.verts[0].index), find(e.verts[1].index)
    if x != y: par[x] = y
size = {}
for v in bm.verts: size[find(v.index)] = size.get(find(v.index), 0) + 1
main = max(size, key=size.get)
keep_main = tag[0] != 'L'
dead = [v for v in bm.verts if ((find(v.index) != main) == keep_main) or not (zlo <= v.co.z <= zhi)]
bmesh.ops.delete(bm, geom=dead, context='VERTS')
bm.to_mesh(o.data); bm.free()
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
zdlib.setup_render((700, 700))
ps = []
for i, v in enumerate(views):
    p = os.path.join(out, f"_b_{i}.png"); zdlib.render(p, v, target=(-0.43, -0.1, cz), ortho=orth, dist=12); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"body_{tag}.png"), len(ps))
for p in ps: os.remove(p)
