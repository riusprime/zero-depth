"""The preview renders play the file's own tracks and nothing else: no orbit, no added spin (the slow turn of each
crystal about its own axis is baked into every clip). A loop is only unrolled `loops` times into a throwaway action,
so the video shows the seam."""
import bpy

def build(rig, act, loops=1):
    sc = bpy.context.scene
    n = int(act.frame_range[1]); total = n * loops
    rig.animation_data.action = act
    for tr in rig.animation_data.nla_tracks: tr.mute = True
    if loops == 1: return act, total
    samples = []
    for f in range(n + 1):
        sc.frame_set(f)
        samples.append({pb.name: (pb.rotation_quaternion.copy(), pb.location.copy()) for pb in rig.pose.bones})
    old = bpy.data.actions.get("__preview")
    if old: bpy.data.actions.remove(old)
    pv = bpy.data.actions.new("__preview"); rig.animation_data.action = pv
    for F in range(total + 1):
        src = samples[F % n]
        for pb in rig.pose.bones:
            q, l = src[pb.name]
            pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = q; pb.location = l
            pb.keyframe_insert("rotation_quaternion", frame=F); pb.keyframe_insert("location", frame=F)
    return pv, total
