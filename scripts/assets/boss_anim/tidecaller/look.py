"""Six views of the file as it is. -- [name] [only=Obj,Obj] [tz] [ortho]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
name = args[0] if args else "look"
only = args[1].split(',') if len(args) > 1 and args[1] != "all" else None
tz = float(args[2]) if len(args) > 2 else 1.6
orth = float(args[3]) if len(args) > 3 else 3.9
tx = float(args[4]) if len(args) > 4 else 0.0
if only:
    for o in bpy.data.objects:
        if o.type == 'MESH': o.hide_render = o.name not in only
zdlib.setup_render((640, 640))
out = os.path.join(os.path.dirname(__file__), "..", "out")
ps = []
for nm, v in [("front", (0, -1, 0)), ("left", (1, 0, 0)), ("back", (0, 1, 0)), ("right", (-1, 0, 0)), ("top", (0, -0.001, 1)), ("q", (-0.8, -1, 0.45))]:
    p = os.path.abspath(os.path.join(out, f"_{name}_{nm}.png")); zdlib.render(p, v, target=(tx, 0, tz), ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.abspath(os.path.join(out, f"{name}_sheet.png")), 3)
for p in ps: os.remove(p)
