"""Grid renders (lines every 0.25 m, red on whole metres, yellow at 0). -- name tx,ty,tz ortho [hide=Obj,Obj]
Views: front (image right = +X), sideR (camera at -X, image right = -Y: the front), back (image right = -X), top (image right = +X, up = +Y)."""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; T = tuple(float(x) for x in args[1].split(',')); S = float(args[2])
views = args[3].split(',') if len(args) > 3 else ["front", "sideR", "back", "top"]
if len(args) > 4:
    for n in args[4].split(','):
        o = bpy.data.objects.get(n)
        if o: o.hide_render = True
W = H = 900
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hc, vc, hflip):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-16, 17):
        v = k * 0.25
        col = (1, 1, 0, 1) if k == 0 else ((1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1))
        px = int(W / 2 + (v - hc) * ppm * (-1 if hflip else 1))
        if 0 <= px < W: a[:, px] = a[:, px] * 0.5 + np.array(col) * 0.5
        py = int(H / 2 + (v - vc) * ppm)
        if 0 <= py < H: a[py, :] = a[py, :] * 0.5 + np.array(col) * 0.5
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
DEF = {"front": ((0, -1, 0), 0, 2, False), "sideR": ((-1, 0, 0), 1, 2, True), "sideL": ((1, 0, 0), 1, 2, False),
       "back": ((0, 1, 0), 0, 2, True), "top": ((0, -0.0001, 1), 0, 1, False)}
ps = []
for nm in views:
    v, hi, vi, flip = DEF[nm]
    p = os.path.join(out, f"_g_{nm}.png"); zdlib.render(p, v, target=T, ortho=S); grid(p, T[hi], T[vi], flip); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"g_{name}.png"), min(2, len(ps)))
for p in ps: os.remove(p)
