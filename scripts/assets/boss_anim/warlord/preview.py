"""anim.blend: contact sheets and a video of one action.  -- <action> <frames,comma> [video]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]
rig = zdlib.the_rig(); act = bpy.data.actions[name]
rig.animation_data.action = act
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
sc = zdlib.setup_render((400, 560))
views = {"side": (0, -1, 0.02), "q": (1, -0.85, 0.5)}
tgt = (0.08, 0, 0.47)
orth = 1.75 if name in ("lunge", "throw", "kneel", "bash", "thrust") else 1.45
for vn, v in views.items():
    ps = []
    for f in frames:
        p = os.path.join(out, f"_{name}_{vn}_{f:03d}.png")
        zdlib.render(p, v, frame=f, target=tgt, ortho=orth); ps.append(p)
    zdlib.sheet(ps, os.path.join(out, f"{name}_{vn}.png"), len(frames))
    for p in ps: os.remove(p)
if len(args) > 2:
    sc = zdlib.setup_render((720, 800))
    zdlib.aim(zdlib.get_cam(), (1, -0.85, 0.5), target=tgt, ortho=orth)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    loops = 3 if name == "walk" else (2 if name == "idle" else 1)
    try: sc.render.image_settings.media_type = 'VIDEO'
    except Exception: pass
    sc.render.image_settings.file_format = 'FFMPEG'
    sc.render.ffmpeg.format = 'MPEG4'; sc.render.ffmpeg.codec = 'H264'; sc.render.ffmpeg.constant_rate_factor = 'HIGH'
    if loops > 1:   # repeat the cycle through an NLA strip
        rig.animation_data.action = None
        tr = rig.animation_data.nla_tracks.new(); st = tr.strips.new("loop", f0, act); st.repeat = loops
        f1 = f0 + (f1 - f0) * loops - 1
    sc.frame_start, sc.frame_end = f0, f1
    sc.render.filepath = os.path.join(out, f"{name}.mp4")
    bpy.ops.render.render(animation=True)
