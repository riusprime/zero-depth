import bpy, sys, os, bmesh, math
from mathutils import Matrix
K = 1.5 / 0.19
T = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.transform(bm, matrix=T, verts=bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
vs = [v.co.copy() for v in bm.verts]
print("P band   n   xmin  xmax  ymin(front) ymax(back) | front verts (y<-0.2): xs")
for k in range(30):
    z0 = k * 0.05; b = [v for v in vs if z0 <= v.z < z0 + 0.05]
    if not b: continue
    fr = sorted(round(v.x, 2) for v in b if v.y < -0.2)
    print(f"P {z0:.2f} {len(b):4d} {min(v.x for v in b):+.2f} {max(v.x for v in b):+.2f} {min(v.y for v in b):+.2f} {max(v.y for v in b):+.2f} | {fr}")
print("P legs: verts with |x|-0.19 within 0.13 and |y|<0.2 and z<0.5")
for k in range(10):
    z0 = k * 0.05
    b = [v for v in vs if z0 <= v.z < z0 + 0.05 and abs(abs(v.x) - 0.19) < 0.13 and -0.22 < v.y < 0.2]
    if b: print(f"P leg {z0:.2f} n={len(b)} x {min(abs(v.x) for v in b):.2f}..{max(abs(v.x) for v in b):.2f} y {min(v.y for v in b):+.2f}..{max(v.y for v in b):+.2f}")
