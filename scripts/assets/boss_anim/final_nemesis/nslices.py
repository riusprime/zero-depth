"""src.blend: ASCII cross-sections in the work frame.  -- z|x|y v1 v2 ..."""
import bpy, sys, os, bmesh, math
from mathutils import Matrix
K = 1.5 / 0.19
T = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.transform(bm, matrix=T, verts=bm.verts)
args = sys.argv[sys.argv.index('--') + 1:]
ax = "xyz".index(args[0]); vals = [float(a) for a in args[1:]]
W = 113
if ax == 2: ia, ib, a0, a1, b0, b1, H = 0, 1, -0.7, 0.7, -0.5, 0.5, 41      # x across, y down (front at top)
elif ax == 0: ia, ib, a0, a1, b0, b1, H = 1, 2, -0.7, 0.7, 1.55, -0.02, 63   # y across (front left), z up
else: ia, ib, a0, a1, b0, b1, H = 0, 2, -0.7, 0.7, 1.55, -0.02, 63           # x across, z up
for val in vals:
    g = [[' '] * W for _ in range(H)]
    for e in bm.edges:
        a, b = e.verts[0].co, e.verts[1].co
        if (a[ax] - val) * (b[ax] - val) < 0:
            t = (val - a[ax]) / (b[ax] - a[ax]); p = a.lerp(b, t)
            c = int(round((p[ia] - a0) / (a1 - a0) * (W - 1))); r = int(round((p[ib] - b0) / (b1 - b0) * (H - 1)))
            if 0 <= c < W and 0 <= r < H: g[r][c] = '#'
    print(f"SL {args[0]}={val}  across {'xyz'[ia]} {a0}..{a1} (0.0125/char), down {'xyz'[ib]} {b0}..{b1}")
    print("SL " + "".join('|' if (i - 56) % 8 == 0 else '.' for i in range(W)))
    for r in range(H): print("SL " + "".join(g[r]) + f" {b0 + (b1 - b0) * r / (H - 1):+.3f}")
