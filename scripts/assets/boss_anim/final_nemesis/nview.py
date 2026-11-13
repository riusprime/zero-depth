"""src.blend (or rig/anim.blend with 'rig' as first arg): free views.  -- [rig] name dx,dy,dz,tx,ty,tz,ortho[,clipstart] ..."""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix
args = sys.argv[sys.argv.index('--') + 1:]
if args[0] == "rig": args = args[1:]
else:
    K = 1.5 / 0.19
    T = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)
    o = [x for x in bpy.data.objects if x.type == 'MESH'][0]; o.data.transform(T)
name = args[0]
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
zdlib.setup_render((700, 700))
ps = []
for i, a in enumerate(args[1:]):
    f = [float(x) for x in a.split(',')]
    p = os.path.join(out, f"_v{i}.png")
    cam = zdlib.get_cam(); zdlib.aim(cam, f[0:3], target=f[3:6], ortho=f[6], dist=8.0)
    cam.data.clip_start = f[7] if len(f) > 7 else 0.1
    bpy.context.scene.render.filepath = p; bpy.ops.render.render(write_still=True); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"{name}.png"), min(3, len(ps)))
for p in ps: os.remove(p)
