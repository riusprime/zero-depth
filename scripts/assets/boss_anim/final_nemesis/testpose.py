import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
rig = bpy.data.objects["Rig"]; P = Poser(rig)
sw = (P.rest["sword"].to_3x3().col[1]).normalized()
poser.new_action(rig, "test")
pose = {
 "hips": {"loc": (0.03, 0, -0.03), "rot": qe(z=6)},
 "spine": {"rot": qe(x=-4, z=-4)}, "chest": {"rot": qe(x=-8, z=-6)}, "head": {"rot": qe(x=-18)},
 "shoulder.R": {"aim": Vector((-0.8, 0, 0.6))},
 "upper_arm.R": {"aim": Vector((-0.30, -0.12, 0.95))}, "forearm.R": {"aim": Vector((0.10, -0.05, 1.0))},
 "hand.R": {"aimvec": (sw, Z)},
 "thigh.R": {"ik": (Vector((-0.42, -0.28, 0.30)), Vector((0, -1, 0.1)))},
 "foot.R": {"abs": qe(x=-25)},
 "thigh.L": {"ik": (Vector((0.30, 0.38, 0.22)), Vector((0, -1, 0.1)))},
 "foot.L": {"abs": qe(x=30)}, "toe.L": {"abs": qe(x=0)},
}
P.key(pose, 1)
bpy.context.scene.frame_set(1)
zdlib.setup_render((520, 640))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
ps = []
for nm, v in [("f", (0, -1, 0)), ("r", (-1, 0, 0)), ("b", (0, 1, 0)), ("q", (-0.7, -1, 0.4))]:
    p = os.path.join(out, f"tp_{nm}.png"); zdlib.render(p, v, target=(0, 0, 1.4), ortho=3.3); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "tp_sheet.png"), 4)
