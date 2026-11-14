import bpy, sys, os, bmesh, math
from mathutils import Matrix
K = 1.5 / 0.19
T = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.transform(bm, matrix=T, verts=bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
print("Q front column: x>0.05, y<0.05, per z band: list of (x,y) sorted by y")
for k in range(9, 21):
    z0 = k * 0.05
    b = sorted(((round(v.co.y, 2), round(v.co.x, 2)) for v in bm.verts if z0 <= v.co.z < z0 + 0.05 and v.co.x > 0.0 and v.co.y < 0.08), key=lambda t: t)
    print(f"Q {z0:.2f} " + " ".join(f"({y:+.2f},{x:.2f})" for y, x in b))
