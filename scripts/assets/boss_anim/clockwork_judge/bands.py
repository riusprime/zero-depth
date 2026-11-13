"""Bounds and centre of an object's vertices in a box, in z bands.  -- <Obj> <xmin,xmax,ymin,ymax,zmin,zmax> <band>"""
import bpy, sys
args = sys.argv[sys.argv.index('--') + 1:]
o = bpy.data.objects[args[0]]; b = [float(x) for x in args[1].split(',')]; step = float(args[2])
ps = [o.matrix_world @ v.co for v in o.data.vertices]
ps = [p for p in ps if b[0] <= p.x <= b[1] and b[2] <= p.y <= b[3] and b[4] <= p.z <= b[5]]
z = b[4]
while z < b[5] - 1e-6:
    q = [p for p in ps if z <= p.z < z + step]
    if q:
        print(f"BD z {z:.2f}-{z + step:.2f} n={len(q):4d} x[{min(p.x for p in q):+.2f},{max(p.x for p in q):+.2f}] y[{min(p.y for p in q):+.2f},{max(p.y for p in q):+.2f}] "
              f"mid ({(min(p.x for p in q) + max(p.x for p in q)) / 2:+.3f},{(min(p.y for p in q) + max(p.y for p in q)) / 2:+.3f})")
    z += step
