import bpy, sys, math
from mathutils import Vector
args = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[args[0]]
for f in [int(x) for x in args[1].split(',')]:
    bpy.context.scene.frame_set(f)
    out = []
    for b in args[2].split(','):
        y = rig.pose.bones[b].matrix.to_3x3().col[1].normalized()
        h = rig.pose.bones[b].matrix.translation
        out.append(f"{b}: dir=({y.x:.2f},{y.y:.2f},{y.z:.2f}) head=({h.x:.2f},{h.y:.2f},{h.z:.2f}) from_down={math.degrees(y.angle(Vector((0,0,-1)))):.0f}")
    print("JSON>>", f, " | ".join(out))
