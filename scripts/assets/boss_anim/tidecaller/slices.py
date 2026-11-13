"""ASCII cross-sections of every mesh at the given heights. -- z z z ...  (letters: which part the edge is in)"""
import bpy, sys, os, bmesh
W, H = 130, 52
x0, x1, y0, y1 = -1.625, 1.625, -1.3, 1.3
zs = [float(a) for a in sys.argv[sys.argv.index('--') + 1:]]
obs = [o for o in bpy.data.objects if o.type == 'MESH']
for z in zs:
    g = [[' '] * W for _ in range(H)]
    for o in obs:
        ch = o.name[0] if o.name != "Body" else '#'
        if o.name == "Shell": ch = 'h'
        mw = o.matrix_world; vs = [mw @ v.co for v in o.data.vertices]
        for e in o.data.edges:
            a, b = vs[e.vertices[0]], vs[e.vertices[1]]
            if (a.z - z) * (b.z - z) < 0:
                t = (z - a.z) / (b.z - a.z); p = a.lerp(b, t)
                c = int((p.x - x0) / (x1 - x0) * (W - 1)); r = int((p.y - y0) / (y1 - y0) * (H - 1))
                if 0 <= c < W and 0 <= r < H: g[r][c] = ch
    print(f"SL z={z}  (x {x0}..{x1}, 0.025/char, '|' every 0.25 m, x=0 at col 65; y {y0} (front) at top, 0.05/row)")
    print("SL " + "".join('|' if (i - 65) % 10 == 0 else '.' for i in range(W)))
    for r in range(H): print("SL " + "".join(g[r]) + f" {y0 + (y1 - y0) * r / (H - 1):+.2f}")
