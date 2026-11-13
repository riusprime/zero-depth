"""anim.blend: does the preview turn leave each crystal's tip where the clip put it?  -- <action> <frame>
Also prints each crystal bone's rest head, tail and Y axis (work space), and its hover range over the idle."""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, spin
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]; act = bpy.data.actions[a[0]]; rig.animation_data.action = act
m = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig][0]
sc = bpy.context.scene; f = int(a[1])
gi = {g.name: g.index for g in m.vertex_groups}
def pts():
    sc.frame_set(f); dg = bpy.context.evaluated_depsgraph_get(); ev = m.evaluated_get(dg)
    return [v.co.copy() for v in ev.data.vertices]
own = {n: [v.index for v in m.data.vertices if any(g.group == gi[n] and g.weight > 0.99 for g in v.groups)] for n in spin.SPIN}
tip = {n: min(own[n], key=lambda i: m.data.vertices[i].co.z) for n in spin.SPIN}
before = pts()
hov = {}
for n in spin.SPIN:
    zs = []; xs = []
    for fr in range(0, int(act.frame_range[1]) + 1, 2):
        sc.frame_set(fr); pb = rig.pose.bones[n]; zs.append(pb.head.z); xs.append((pb.head.x, pb.head.y))
    hov[n] = {"head_z_range_cm": round((max(zs) - min(zs)) * 100, 1), "head_x_range_cm": round((max(x for x, _ in xs) - min(x for x, _ in xs)) * 100, 1),
              "head_y_range_cm": round((max(y for _, y in xs) - min(y for _, y in xs)) * 100, 1)}
spin.apply(act)
after = pts()
out = {}
for n in spin.SPIN:
    b = rig.data.bones[n]
    out[n] = {"rest_head": [round(x, 3) for x in b.head_local], "rest_tail_tip": [round(x, 3) for x in b.tail_local],
              "y_axis": [round(x, 3) for x in (b.tail_local - b.head_local).normalized()], "length": round(b.length, 3),
              "tip_moved_by_turn_mm": round((after[tip[n]] - before[tip[n]]).length * 1000, 2),
              "widest_point_moved_by_turn_cm": round(max((after[i] - before[i]).length for i in own[n]) * 100, 1),
              "turn_deg_at_frame": round(spin.SPIN[n][0] * 360 * (f / 300 + spin.SPIN[n][1]) % 360, 1), "hover_in_clip": hov[n]}
zdlib.emit(out)
