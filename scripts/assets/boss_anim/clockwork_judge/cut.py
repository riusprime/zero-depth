"""Look at a slab of the model: keep only vertices inside a box, then render views with a grid.
-- <name> <xmin,xmax,ymin,ymax,zmin,zmax> <tx,ty,tz> <ortho> [only=Obj,Obj] [views=front,left,...]"""
import bpy, sys, os, bmesh
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; box = [float(x) for x in args[1].split(',')]
tgt = tuple(float(x) for x in args[2].split(',')); S = float(args[3])
views = ["front", "left", "back", "right", "top", "q"]
for a in args[4:]:
    if a.startswith("only="):
        keep = a[5:].split(',')
        for o in bpy.data.objects:
            if o.type == 'MESH' and o.name not in keep: o.hide_render = True
    if a.startswith("views="): views = a[6:].split(',')
for o in bpy.data.objects:
    if o.type != 'MESH' or o.hide_render: continue
    mw = o.matrix_world
    bm = bmesh.new(); bm.from_mesh(o.data)
    dead = []
    for v in bm.verts:
        p = mw @ v.co
        if not (box[0] <= p.x <= box[1] and box[2] <= p.y <= box[3] and box[4] <= p.z <= box[5]): dead.append(v)
    bmesh.ops.delete(bm, geom=dead, context='VERTS'); bm.to_mesh(o.data); bm.free()
W = H = 760
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
STEP = 0.25 if S > 1.6 else 0.1
def grid(path, hc, vc, hflip):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-40, 80):
        v = k * STEP; big = (k % 4 == 0) if STEP == 0.25 else (k % 5 == 0)
        col = (1, 0.2, 0.2, 1) if big else (0.2, 0.9, 1, 1)
        px = int(round(W / 2 + (v - hc) * ppm * (-1 if hflip else 1)))
        if 0 <= px < W: a[:, px] = a[:, px] * 0.5 + np.array(col) * 0.5
        py = int(round(H / 2 + (v - vc) * ppm))
        if 0 <= py < H: a[py, :] = a[py, :] * 0.5 + np.array(col) * 0.5
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
V = {"front": ((0, -1, 0), tgt[0], tgt[2], False), "left": ((1, 0, 0), tgt[1], tgt[2], False), "back": ((0, 1, 0), tgt[0], tgt[2], True),
     "right": ((-1, 0, 0), tgt[1], tgt[2], True), "top": ((0, -0.001, 1), tgt[0], -tgt[1], False), "q": ((-0.75, -1, 0.45), None, None, False),
     "q2": ((0.75, -1, 0.45), None, None, False), "qb": ((0.75, 1, 0.45), None, None, False)}
ps = []
for nm in views:
    v, hc, vc, flip = V[nm]
    p = os.path.join(out, f"_ct_{nm}.png"); zdlib.render(p, v, target=tgt, ortho=S)
    if hc is not None and nm != "top": grid(p, hc, vc, flip)
    ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"cut_{name}.png"), min(3, len(ps)))
for p in ps: os.remove(p)
print(f"GRID step {STEP} m; red lines every {STEP * (4 if STEP == 0.25 else 5)} m; centre {tgt}")
