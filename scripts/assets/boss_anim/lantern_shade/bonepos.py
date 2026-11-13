"""anim.blend: where bones are at a frame.  -- <action> <frame> <name prefix,comma>"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
a = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[a[0]]
bpy.context.scene.frame_set(int(a[1])); pre = a[2].split(',')
out = {}
for pb in rig.pose.bones:
    if any(pb.name.startswith(p) for p in pre):
        out[pb.name] = [[round(x, 2) for x in pb.head], [round(x, 2) for x in pb.tail]]
zdlib.emit(out)
