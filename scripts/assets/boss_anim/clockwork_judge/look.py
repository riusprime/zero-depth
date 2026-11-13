"""Views of whatever is in the file.  -- <name> <tx,ty,tz> <ortho> [grid] [hide=Obj,Obj]
Views: front (camera at -Y), its left side (camera at +X), back, its right side (camera at -X), top, three-quarter."""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; tgt = tuple(float(x) for x in args[1].split(',')); S = float(args[2])
grid_on = "grid" in args
for a in args:
    if a.startswith("hide="):
        for n in a[5:].split(','):
            o = bpy.data.objects.get(n)
            if o: o.hide_render = True
    if a.startswith("only="):
        keep = a[5:].split(',')
        for o in bpy.data.objects:
            if o.type == 'MESH' and o.name not in keep: o.hide_render = True
W = H = 760
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hc, vc, hflip):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-12, 32):
        v = k * 0.25; col = (1, 0.2, 0.2, 1) if k % 4 == 0 else (0.2, 0.9, 1, 1)
        px = int(W / 2 + (v - hc) * ppm * (-1 if hflip else 1))
        if 0 <= px < W: a[:, px] = a[:, px] * 0.5 + np.array(col) * 0.5
        py = int(H / 2 + (v - vc) * ppm)
        if 0 <= py < H: a[py, :] = a[py, :] * 0.5 + np.array(col) * 0.5
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
ps = []
# (name, camera direction, horizontal world axis centre, flipped)
for nm, v, hc, flip in [("front", (0, -1, 0), tgt[0], False), ("left", (1, 0, 0), tgt[1], False), ("back", (0, 1, 0), tgt[0], True),
                        ("right", (-1, 0, 0), tgt[1], True), ("top", (0, -0.001, 1), tgt[0], False), ("q", (-0.75, -1, 0.45), 0, False)]:
    p = os.path.join(out, f"_lk_{nm}.png"); zdlib.render(p, v, target=tgt, ortho=S)
    if grid_on and nm not in ("top", "q"): grid(p, hc, tgt[2], flip)
    ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"look_{name}.png"), 3)
for p in ps: os.remove(p)
