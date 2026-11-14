"""rig.blend: put the rig in a test pose and render four views.
-- name "bone:x,y,z;bone:x,y,z" [tx,ty,tz] [ortho]     (degrees about the figure's X, Y, Z axes, on top of the parent)"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]
T = tuple(float(x) for x in args[2].split(',')) if len(args) > 2 else (0, 0, 1.6)
orth = float(args[3]) if len(args) > 3 else 3.9
rig = bpy.data.objects["Rig"]; P = poser.Poser(rig)
pose = {}
for item in args[1].split(';'):
    if not item: continue
    b, v = item.split(':'); x, y, z = [float(a) for a in v.split(',')]
    pose[b] = {"rot": qe(x=x, y=y, z=z)}
world, basis = P.solve(pose)
for n, Mb in basis.items():
    pb = rig.pose.bones[n]; pb.rotation_mode = 'QUATERNION'
    loc, rot, _ = Mb.decompose(); pb.rotation_quaternion = rot
bpy.context.view_layer.update()
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
zdlib.setup_render((640, 760)); ps = []
VW = {"front": (0, -1, 0.1), "q": (-0.8, -1, 0.3), "side": (-1, 0, 0.1), "back": (0.5, 1, 0.3), "left": (1, -0.2, 0.1), "ql": (0.8, -1, 0.3)}
vs = args[4].split(',') if len(args) > 4 else ["front", "q", "left"]
for nm in vs:
    p = os.path.join(out, f"_pt_{nm}.png"); zdlib.render(p, VW[nm], target=T, ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"pt_{name}.png"), len(vs))
for p in ps: os.remove(p)
