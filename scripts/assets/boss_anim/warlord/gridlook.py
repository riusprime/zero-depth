"""Grid renders of the model at rest: from the front (+X), the spear side (-Y), the back and the top. Lines every
0.05, red every 0.25. -- [cx,cy,cz] [size]"""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
C = tuple(float(x) for x in args[0].split(',')) if args else (0, 0, 0.5)
S = float(args[1]) if len(args) > 1 else 1.1
W = H = 1000
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hc, vc, hflip=False, vflip=False):
    im = bpy.data.images.load(path); a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    for k in range(-40, 41):
        v = k * 0.05
        col = (1, 0.2, 0.2, 1) if k % 5 == 0 else (0.2, 0.9, 1, 1)
        al = 0.7 if k % 5 == 0 else 0.3
        px = int(W / 2 + (v - hc) * ppm * (-1 if hflip else 1))
        if 0 <= px < W: a[:, px] = a[:, px] * (1 - al) + np.array(col) * al
        py = int(H / 2 + (v - vc) * ppm * (-1 if vflip else 1))
        if 0 <= py < H: a[py, :] = a[py, :] * (1 - al) + np.array(col) * al
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = a.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
ps = []
# front: camera at +X, image right = +Y
p = os.path.join(out, "g_front.png"); zdlib.render(p, (1, 0, 0), target=C, ortho=S); grid(p, C[1], C[2]); ps.append(p)
# spear side: camera at -Y, image right = +X (front to the right)
p = os.path.join(out, "g_side.png"); zdlib.render(p, (0, -1, 0), target=C, ortho=S); grid(p, C[0], C[2]); ps.append(p)
# back: camera at -X, image right = -Y
p = os.path.join(out, "g_back.png"); zdlib.render(p, (-1, 0, 0), target=C, ortho=S); grid(p, C[1], C[2], hflip=True); ps.append(p)
# shield side: camera at +Y, image right = -X
p = os.path.join(out, "g_left.png"); zdlib.render(p, (0, 1, 0), target=C, ortho=S); grid(p, C[0], C[2], hflip=True); ps.append(p)
zdlib.sheet(ps[:2], os.path.join(out, "g_sheet1.png"), 2)
zdlib.sheet(ps[2:], os.path.join(out, "g_sheet2.png"), 2)
