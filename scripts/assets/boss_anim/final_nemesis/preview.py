"""anim.blend: contact sheets (side from its right, and three-quarter front) and a video of one action.
-- <action> <frames,comma> [video]      The walk's video plays at the game's speed (5.2 m/s)."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]
rig = bpy.data.objects["Rig"]; act = bpy.data.actions[name]
rig.animation_data.action = act
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
sc = zdlib.setup_render((380, 420))
sc.display.shading.color_type = 'SINGLE'; sc.display.shading.single_color = (0.62, 0.6, 0.66)
zdlib.ground()
views = {"side": (-1, 0, 0.05), "q": (-0.75, -1, 0.45)}
tgt = (0, -0.05, 0.72); orth = 2.1
for vn, v in views.items():
    ps = []
    for f in frames:
        p = os.path.join(out, f"_{name}_{vn}_{f:03d}.png")
        zdlib.render(p, v, frame=f, target=tgt, ortho=orth); ps.append(p)
    zdlib.sheet(ps, os.path.join(out, f"{name}_{vn}.png"), len(frames))
    for p in ps: os.remove(p)
if len(args) > 2:
    sc = zdlib.setup_render((720, 800))
    zdlib.aim(zdlib.get_cam(), (-0.75, -1, 0.45), target=tgt, ortho=orth)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    try: sc.render.image_settings.media_type = 'VIDEO'
    except Exception: pass
    sc.render.image_settings.file_format = 'FFMPEG'
    sc.render.ffmpeg.format = 'MPEG4'; sc.render.ffmpeg.codec = 'H264'; sc.render.ffmpeg.constant_rate_factor = 'HIGH'
    loops = {"walk": 10, "idle": 2}.get(name, 1)
    scale = float(args[3]) if len(args) > 3 else 1.0
    fname = name if len(args) <= 4 else args[4]
    if loops > 1 or scale != 1.0:
        rig.animation_data.action = None
        tr = rig.animation_data.nla_tracks.new(); st = tr.strips.new("loop", f0, act); st.repeat = loops; st.scale = scale
        f1 = int(f0 + (f1 - f0) * loops * scale) - 1
    else:
        f1 += 12            # hold the last pose a moment
    sc.frame_start, sc.frame_end = f0, f1
    sc.render.filepath = os.path.join(out, f"{fname}.mp4")
    bpy.ops.render.render(animation=True)
