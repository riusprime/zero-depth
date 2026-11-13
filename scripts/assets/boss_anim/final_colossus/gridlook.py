"""src10.blend (or any): orthographic views with a 0.25 m grid (red lines every metre).  -- [cx cz ortho tag]"""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Euler
a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
CX = float(a[0]) if len(a) > 0 else 0.0; CZ = float(a[1]) if len(a) > 1 else 1.6; S = float(a[2]) if len(a) > 2 else 4.4
tag = a[3] if len(a) > 3 else ""; CY = float(a[4]) if len(a) > 4 else 0.0
if os.environ.get("ZD_SEED"):          # keep only the shell nearest this point
    import bmesh
    from mathutils import Vector
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
if os.environ.get("ZD_KEEP"):          # keep only the cloth (pale) or the stone (dark) faces
    import bmesh, colmask
    m = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    pale = colmask.pale_faces(m)
    want = os.environ["ZD_KEEP"] == "cloth"
    bm = bmesh.new(); bm.from_mesh(m.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if bool(pale[f.index]) != want], context='FACES')
    bm.to_mesh(m.data); bm.free()
W, H = 900, 900
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hcenter, vcenter, hflip=False, vflip=False):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-16, 17):
        v = k * 0.25
        col = (1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1)
        al = 0.6 if k % 4 == 0 else 0.3
        if k == 0: col = (1, 1, 0.2, 1)
        px = int(W / 2 + (v - hcenter) * ppm * (-1 if hflip else 1))
        if 0 <= px < W: a[:, px] = a[:, px] * (1 - al) + np.array(col) * al
        py = int(H / 2 + (v - vcenter) * ppm * (-1 if vflip else 1))
        if 0 <= py < H: a[py, :] = a[py, :] * (1 - al) + np.array(col) * al
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
ps = []
# front: camera at -Y, image right = +X (its left)
p = os.path.join(out, "g_front.png"); zdlib.render(p, (0, -1, 0), target=(CX, CY, CZ), ortho=S); grid(p, CX, CZ); ps.append(p)
# its right side: camera at -X, image right = -Y (front to the right)
p = os.path.join(out, "g_side.png"); zdlib.render(p, (-1, 0, 0), target=(CX, CY, CZ), ortho=S); grid(p, CY, CZ, hflip=True); ps.append(p)
# back: camera at +Y, image right = -X
p = os.path.join(out, "g_back.png"); zdlib.render(p, (0, 1, 0), target=(CX, CY, CZ), ortho=S); grid(p, CX, CZ, hflip=True); ps.append(p)
cam = zdlib.get_cam()
# from above: image right = +X, image up = +Y (the back)
p = os.path.join(out, "g_top.png"); zdlib.aim(cam, (0, 0, 1), target=(CX, CY, CZ), ortho=S); cam.rotation_euler = Euler((0, 0, 0))
bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); grid(p, CX, CY); ps.append(p)
# from below: image right = +X, image up = -Y (the front)
p = os.path.join(out, "g_below.png"); zdlib.aim(cam, (0, 0, -1), target=(CX, CY, CZ), ortho=S); cam.rotation_euler = Euler((3.14159265, 0, 0))
bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); grid(p, CX, CY, vflip=True); ps.append(p)
# its left side: camera at +X, image right = +Y (front to the left)
p = os.path.join(out, "g_left.png"); zdlib.render(p, (1, 0, 0), target=(CX, CY, CZ), ortho=S); grid(p, CY, CZ); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"g_sheet{tag}.png"), 3)
for p in ps: os.remove(p)
