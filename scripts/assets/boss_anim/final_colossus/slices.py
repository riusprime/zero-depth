"""Cut-away views: from above with everything over a height removed, and from the front with everything before a depth removed.
-- <top|front|side> <cuts,comma> [ortho] [tag]   (ZD_SEED keeps one shell)"""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Euler, Vector
a = sys.argv[sys.argv.index('--') + 1:]
mode = a[0]; cuts = [float(x) for x in a[1].split(',')]; S = float(a[2]) if len(a) > 2 else 3.0; tag = a[3] if len(a) > 3 else ""
if os.environ.get("ZD_SEED"):
    import bmesh
    seed = Vector([float(x) for x in os.environ["ZD_SEED"].split(",")])
    m = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    bm = bmesh.new(); bm.from_mesh(m.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0015)
    v0 = min(bm.verts, key=lambda v: (v.co - seed).length); seen = {v0}; todo = [v0]
    while todo:
        v = todo.pop()
        for e in v.link_edges:
            o = e.other_vert(v)
            if o not in seen: seen.add(o); todo.append(o)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in seen], context='VERTS')
    bm.to_mesh(m.data); bm.free()
W = H = 700
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
cam = zdlib.get_cam(); CZ = 1.6
def grid(path, hc, vc, hflip=False):
    im = bpy.data.images.load(path); px = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-16, 17):
        v = k * 0.25; col = (1, 1, 0.2, 1) if k == 0 else ((1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1)); al = 0.6 if k % 4 == 0 else 0.3
        x = int(W / 2 + (v - hc) * ppm * (-1 if hflip else 1))
        if 0 <= x < W: px[:, x] = px[:, x] * (1 - al) + np.array(col) * al
        y = int(H / 2 + (v - vc) * ppm)
        if 0 <= y < H: px[y, :] = px[y, :] * (1 - al) + np.array(col) * al
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = px.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
ps = []
for c in cuts:
    p = os.path.join(out, f"_sl_{c}.png")
    if mode == "top":
        zdlib.aim(cam, (0, 0, 1), target=(0, 0, CZ), ortho=S); cam.rotation_euler = Euler((0, 0, 0))
        cam.location = Vector((0, 0, 10)); cam.data.clip_start = 10 - c; cam.data.clip_end = 100
        bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); grid(p, 0, 0)
    elif mode == "front":
        zdlib.aim(cam, (0, -1, 0), target=(0, 0, CZ), ortho=S)
        cam.location = Vector((0, -10, CZ)); cam.data.clip_start = 10 + c; cam.data.clip_end = 100
        bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); grid(p, 0, CZ)
    else:
        zdlib.aim(cam, (-1, 0, 0), target=(0, 0, CZ), ortho=S)
        cam.location = Vector((-10, 0, CZ)); cam.data.clip_start = 10 + c; cam.data.clip_end = 100
        bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); grid(p, 0, CZ, hflip=True)
    ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"slices_{mode}{tag}.png"), min(len(ps), 3))
for p in ps: os.remove(p)
