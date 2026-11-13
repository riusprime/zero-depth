"""anim.blend: contact sheets and a video of one action, as the file plays it (loops shown twice).
-- <action> <frames,comma> [video]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, pvlayer
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]
rig = bpy.data.objects["Rig"]; act = bpy.data.actions[name]
loops = {"idle": 2, "walk": 2}.get(name, 1)      # a loop is shown twice, so its seam can be seen
pv, total = pvlayer.build(rig, act, loops)
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
sc = zdlib.setup_render((400, 520)); zdlib.floor()
views = {"side": (-1, 0, 0), "q": (-0.75, -1, 0.45)}
tgt = (-0.2, -0.1, 1.45)         # the Prism: 3.1 m tall, 4 m wide with her shards
orth = 5.6
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
    try: sc.render.image_settings.media_type = 'VIDEO'
    except Exception: pass
    sc.render.image_settings.file_format = 'FFMPEG'
    sc.render.ffmpeg.format = 'MPEG4'; sc.render.ffmpeg.codec = 'H264'; sc.render.ffmpeg.constant_rate_factor = 'HIGH'
    sc.frame_start, sc.frame_end = 0, total - (1 if loops > 1 else 0)
    sc.render.filepath = os.path.join(out, f"{name}.mp4")
    bpy.ops.render.render(animation=True)
