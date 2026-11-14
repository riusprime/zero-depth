"""anim.blend: four views of frames of an action.  -- <action> <frame[,frame..]> [target z] [ortho]
One frame: front, three-quarter, its right side, back -> out/cu_<action>_<frame>.png.  Several: a row per frame."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]
tz = float(args[2]) if len(args) > 2 else 0.72; orth = float(args[3]) if len(args) > 3 else 1.9
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[name]
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
sc = zdlib.setup_render((480, 500))
if os.environ.get('ZD_TEX') != '1':
    sc.display.shading.color_type = 'SINGLE'; sc.display.shading.single_color = (0.62, 0.6, 0.66); sc.display.shading.show_object_outline = True
zdlib.ground()
ps = []
for frame in frames:
    for nm, v in [("front", (0, -1, 0.1)), ("q", (-0.8, -1, 0.3)), ("side", (-1, 0, 0.1)), ("back", (0.5, 1, 0.3))]:
        p = os.path.join(out, f"_cu_{frame}_{nm}.png"); zdlib.render(p, v, frame=frame, target=(0, -0.05, tz), ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"cu_{name}_{'_'.join(str(f) for f in frames)}.png"), 4)
for p in ps: os.remove(p)
