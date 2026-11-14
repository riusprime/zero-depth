import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name, frame = args[0], int(args[1])
tg = tuple(float(x) for x in args[2].split(",")); orth = float(args[3])
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[name]
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
zdlib.setup_render((600, 760))
ps = []
for nm, v in [("front", (0, -1, 0.1)), ("q", (-0.8, -1, 0.3)), ("side", (-1, 0, 0.1)), ("back", (-0.5, 1, 0.3))]:
    p = os.path.join(out, f"_zm_{name}_{frame}_{args[4]}_{nm}.png"); zdlib.render(p, v, frame=frame, target=tg, ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"zm_{name}_{frame}_{args[4]}.png"), 4)
for p in ps: os.remove(p)
