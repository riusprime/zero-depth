"""anim.blend: contact sheets and a video of one action, with the crystals' slow turn laid over it as the game will
(spin.py: preview only, nothing is saved).  -- <action> <frames,comma> [video]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, spin
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]
rig = bpy.data.objects["Rig"]; act = bpy.data.actions[name]
loops = 2 if (name in ("idle", "walk") and len(args) > 2) else 1
if loops > 1: spin.unroll(act, loops)          # the loop played twice, the turn running on through the repeat
spin.apply(act)
rig.animation_data.action = act
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
sc = zdlib.setup_render((480, 480)); zdlib.floor()
views = {"side": (-1, 0, 0), "q": (-0.75, -1, 0.45)}
tgt = (0, -0.3, 1.75)         # the Colossus is 3.2 m tall, 3.5 m across its fists, and throws them overhead and forward
orth = 5.9
for vn, v in views.items():
    ps = []
    for f in frames:
        p = os.path.join(out, f"_{name}_{vn}_{f:03d}.png")
        zdlib.render(p, v, frame=f, target=tgt, ortho=orth); ps.append(p)
    zdlib.sheet(ps, os.path.join(out, f"{name}_{vn}.png"), min(4, len(frames)))
    for p in ps: os.remove(p)
if len(args) > 2:
    sc = zdlib.setup_render((800, 800))
    zdlib.aim(zdlib.get_cam(), (-0.75, -1, 0.45), target=tgt, ortho=orth)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    try: sc.render.image_settings.media_type = 'VIDEO'
    except Exception: pass
    sc.render.image_settings.file_format = 'FFMPEG'
    sc.render.ffmpeg.format = 'MPEG4'; sc.render.ffmpeg.codec = 'H264'; sc.render.ffmpeg.constant_rate_factor = 'HIGH'
    sc.frame_start, sc.frame_end = f0, (f1 - 1 if loops > 1 else f1)
    sc.render.filepath = os.path.join(out, f"{name}.mp4")
    bpy.ops.render.render(animation=True)
