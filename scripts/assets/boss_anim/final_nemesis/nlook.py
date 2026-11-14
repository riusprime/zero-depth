"""src.blend: scaled look sheet with a 0.25 m grid (front, side from its right, back, below, top, quarter)."""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Euler, Matrix
K = 1.5 / 0.19
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
o.data.transform(Matrix.Scale(K, 4))
W = H = 900; S = 2.0; TZ = 0.75
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hflip=False, vc=TZ, step=0.125):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-16, 17):
        v = k * step
        col = (1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1)
        px = int(W / 2 + v * ppm * (-1 if hflip else 1))
        if 0 <= px < W: a[:, px] = a[:, px] * 0.6 + np.array(col) * 0.4
        py = int(H / 2 + (v - vc) * ppm)
        if 0 <= py < H: a[py, :] = a[py, :] * 0.6 + np.array(col) * 0.4
    o2 = bpy.data.images.new("g", W, H, alpha=True); o2.pixels = a.ravel().tolist(); o2.filepath_raw = path; o2.file_format = 'PNG'; o2.save(); bpy.data.images.remove(o2)
ps = []
for nm, v, fl in [("front", (0, -1, 0), False), ("side", (-1, 0, 0), True), ("back", (0, 1, 0), True), ("sideL", (1, 0, 0), False)]:
    p = os.path.join(out, f"g_{nm}.png"); zdlib.render(p, v, target=(0, 0, TZ), ortho=S); grid(p, hflip=fl); ps.append(p)
cam = zdlib.get_cam()
p = os.path.join(out, "g_below.png")
zdlib.aim(cam, (0, 0, -1), target=(0, 0, TZ), ortho=S)
cam.rotation_euler = Euler((3.14159265, 0, 0))
bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); grid(p, vc=0); ps.append(p)
p = os.path.join(out, "g_q.png"); zdlib.render(p, (-0.8, -1, 0.4), target=(0, 0, TZ), ortho=S); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "g_sheet.png"), 3)
