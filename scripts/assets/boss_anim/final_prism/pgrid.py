"""src.blend: the model in the work frame (x10, facing -Y) with a 0.25 m grid.  -- [cx cz span] [hide_loose]"""
import bpy, sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix, Euler
a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
CX = float(a[0]) if len(a) > 0 else 0.0; CZ = float(a[1]) if len(a) > 1 else 1.55; S = float(a[2]) if len(a) > 2 else 4.4
tag = a[3] if len(a) > 3 else ""
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
if "Rig" not in bpy.data.objects:
    o.data.transform(Matrix.Rotation(math.radians(-90), 4, 'Z') @ Matrix.Scale(10, 4))
W = H = 900
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hc, vc, hflip=False, vflip=False):
    im = bpy.data.images.load(path); A = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-12, 17):
        v = k * 0.25
        col = (1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1)
        al = 0.6 if k % 4 == 0 else 0.25
        if k == 0: col = (1, 1, 0.2, 1)
        px = int(W / 2 + (v - hc) * ppm * (-1 if hflip else 1))
        if 0 <= px < W: A[:, px] = A[:, px] * (1 - al) + np.array(col) * al
        py = int(H / 2 + (v - vc) * ppm * (-1 if vflip else 1))
        if 0 <= py < H: A[py, :] = A[py, :] * (1 - al) + np.array(col) * al
    im2 = bpy.data.images.new("g", W, H, alpha=True); im2.pixels = A.ravel().tolist(); im2.filepath_raw = path; im2.file_format = 'PNG'; im2.save(); bpy.data.images.remove(im2)
ps = []
def shot(nm, v, hc, vc, hflip=False, vflip=False, target=None, rot=None):
    p = os.path.join(out, f"_g_{nm}.png")
    cam = zdlib.get_cam(); zdlib.aim(cam, v, target=target or (CX, 0, CZ), ortho=S, dist=12)
    if rot: cam.rotation_euler = Euler(rot)
    bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True)
    grid(p, hc, vc, hflip, vflip); ps.append(p)
shot("front", (0, -1, 0), CX, CZ)                       # image right = +X (her left)
shot("sideR", (-1, 0, 0), 0, CZ, hflip=True)            # from her right: image right = -Y (front)
shot("back", (0, 1, 0), CX, CZ, hflip=True)             # image right = -X
shot("sideL", (1, 0, 0), 0, CZ)                         # from her left: image right = +Y (back)
zdlib.sheet(ps[:2], os.path.join(out, f"g_a{tag}.png"), 2)
zdlib.sheet(ps[2:], os.path.join(out, f"g_b{tag}.png"), 2)
ps2 = []
ps = ps2
shot("top", (0, 0, 1), CX, 0, target=(CX, 0, CZ), rot=(0, 0, 0))                 # image right = +X, up = +Y (back)
shot("below", (0, 0, -1), CX, 0, vflip=True, target=(CX, 0, CZ), rot=(math.pi, 0, 0))   # image right = +X, up = -Y (front)
zdlib.sheet(ps2, os.path.join(out, f"g_c{tag}.png"), 2)
