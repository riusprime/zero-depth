import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name, frame = args[0], int(args[1])
tz = float(args[2]) if len(args) > 2 else 1.6; orth = float(args[3]) if len(args) > 3 else 4.4
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[name]
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
zdlib.setup_render((560, 640))
ps = []
for nm, v in [("front", (0, -1, 0.1)), ("q", (-0.8, -1, 0.3)), ("side", (-1, 0, 0.1)), ("left", (1, -0.25, 0.15)), ("back", (-0.5, 1, 0.3))]:
    p = os.path.join(out, f"_cu_{nm}.png"); zdlib.render(p, v, frame=frame, target=(float(args[4]) if len(args) > 4 else 0, float(args[5]) if len(args) > 5 else -0.1, tz), ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"cu_{name}_{frame}.png"), 5)
for p in ps: os.remove(p)
