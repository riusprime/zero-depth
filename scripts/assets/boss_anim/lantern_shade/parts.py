"""Grid renders of chosen objects.  -- <prefix> <cx,cy,cz> <size m> <views,comma> <show names,comma or ALL> [grid step]"""
import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
a = sys.argv[sys.argv.index('--') + 1:]
prefix = a[0]; C = tuple(float(x) for x in a[1].split(',')); S = float(a[2]); views = a[3].split(','); show = a[4].split(',')
step = float(a[5]) if len(a) > 5 else 0.25
for o in bpy.data.objects:
    if o.type == 'MESH': o.hide_render = not (show == ["ALL"] or o.name in show)
W = H = 900
zdlib.setup_render((W, H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
VD = {"front": ((0, -1, 0), 0, 2, 1), "back": ((0, 1, 0), 0, 2, -1), "right": ((-1, 0, 0), 1, 2, -1), "left": ((1, 0, 0), 1, 2, 1),
      "top": ((0, 0, 1), 0, 1, 1)}
def grid(path, hi, vi, sgn):
    im = bpy.data.images.load(path); arr = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4); bpy.data.images.remove(im)
    ppm = W / S
    n = int(S / step) + 2
    for axis, ci in ((0, hi), (1, vi)):
        k0 = int((C[ci] - S / 2) / step) - 1
        for k in range(k0, k0 + n + 2):
            v = k * step
            whole = abs(v - round(v)) < 1e-6
            col = np.array((1, 0.2, 0.2, 1) if whole else (0.2, 0.9, 1, 1)); al = 0.55 if whole else 0.3
            if axis == 0:
                px = int(W / 2 + (v - C[ci]) * ppm * sgn)
                if 0 <= px < W: arr[:, px] = arr[:, px] * (1 - al) + col * al
            else:
                py = int(H / 2 + (v - C[ci]) * ppm)
                if 0 <= py < H: arr[py, :] = arr[py, :] * (1 - al) + col * al
    o = bpy.data.images.new("g", W, H, alpha=True); o.pixels = arr.ravel().tolist(); o.filepath_raw = path; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
ps = []
for nm in views:
    v, hi, vi, sgn = VD[nm]
    p = os.path.join(out, f"_{prefix}_{nm}.png")
    if nm == "top":
        cam = zdlib.get_cam(); from mathutils import Vector, Euler
        cam.location = Vector(C) + Vector((0, 0, 8)); cam.rotation_euler = Euler((0, 0, 0)); cam.data.type = 'ORTHO'; cam.data.ortho_scale = S; cam.data.clip_end = 100
        bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True)
    else:
        zdlib.render(p, v, target=C, ortho=S)
    grid(p, hi, vi, sgn); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"{prefix}.png"), len(ps))
for p in ps: os.remove(p)
