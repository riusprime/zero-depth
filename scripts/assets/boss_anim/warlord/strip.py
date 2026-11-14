"""anim.blend: one view of several frames of an action, side by side.
-- <action> <frames,comma> <view: side|q|front|back|left|top> [tz] [ortho] [tx]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]; vn = args[2]
tz = float(args[3]) if len(args) > 3 else 0.45; orth = float(args[4]) if len(args) > 4 else 1.2
tx = float(args[5]) if len(args) > 5 else 0.05
V = {"side": (0, -1, 0.03), "q": (1, -0.85, 0.5), "front": (1, 0, 0.08), "back": (-1, 0.5, 0.3), "left": (0.2, 1, 0.1),
     "top": (0.01, 0, 1), "iso": (1, -1, 1.2)}
rig = zdlib.the_rig(); rig.animation_data.action = bpy.data.actions[name]
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
zdlib.setup_render((440, 520))
ps = []
for f in frames:
    p = os.path.join(out, f"_st_{f:03d}.png"); zdlib.render(p, V[vn], frame=f, target=(tx, 0, tz), ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"st_{name}_{vn}.png"), len(ps))
for p in ps: os.remove(p)
