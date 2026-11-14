"""Top views with a grid, each cut at a height (everything above it is clipped). Image right = +X (front),
image up = +Y (its left). Lines every 0.05, red every 0.25.  -- z1 z2 ..."""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Euler
args = sys.argv[sys.argv.index('--') + 1:]
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
S = 0.9; W = H = 900
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
cam = zdlib.get_cam(); ps = []
for z in args:
    cam.location = (0, 0, float(z)); cam.rotation_euler = Euler((0, 0, 0))
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = S; cam.data.clip_start = 0.0005; cam.data.clip_end = 10
    p = os.path.join(out, f"_top_{z}.png"); bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-10, 11):
        v = k * 0.05; col = (1, 0.2, 0.2, 1) if k % 5 == 0 else (0.2, 0.9, 1, 1); al = 0.7 if k % 5 == 0 else 0.3
        px = int(W / 2 + v * ppm); py = int(H / 2 + v * ppm)
        if 0 <= px < W: a[:, px] = a[:, px] * (1 - al) + np.array(col) * al
        if 0 <= py < H: a[py, :] = a[py, :] * (1 - al) + np.array(col) * al
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = p; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
    ps.append(p)
zdlib.sheet(ps, os.path.join(out, "g_top.png"), len(ps))
for p in ps: os.remove(p)
