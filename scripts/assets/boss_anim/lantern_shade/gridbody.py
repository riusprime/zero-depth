import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
for n in sys.argv[sys.argv.index('--') + 1:]:
    o = bpy.data.objects.get(n)
    if o: o.hide_render = True
W, H = 800, 800; S = 4.0; ZC = 1.75
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hflip=False):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-8, 13):
        v = k * 0.25; col = (1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1)
        px = int(W / 2 + v * ppm * (-1 if hflip else 1))
        if 0 <= px < W: a[:, px] = a[:, px] * 0.45 + np.array(col) * 0.55
        py = int(H / 2 + (v - ZC) * ppm)
        if 0 <= py < H: a[py, :] = a[py, :] * 0.45 + np.array(col) * 0.55
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
ps = []
for nm, v, flip in [("front", (0, -1, 0), False), ("sideR", (-1, 0, 0), True), ("back", (0, 1, 0), True)]:
    p = os.path.join(out, f"gb_{nm}.png"); zdlib.render(p, v, target=(0, 0, ZC), ortho=S); grid(p, flip); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "gb_sheet.png"), 3)
