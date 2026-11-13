"""anim.blend: heights of the hood, the body and the lowest point at given frames.  -- <action> <frames,comma>"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
a = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[a[0]]
m = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "ZDFloor"][0]; me = m.data
gi = {g.name: g.index for g in m.vertex_groups}
def dom(v): return max(v.groups, key=lambda g: g.weight).group
head = [v.index for v in me.vertices if dom(v) == gi["head"]]
fig = [v.index for v in me.vertices if not m.vertex_groups[dom(v)].name.startswith("shard")]
out = {}
for f in [int(x) for x in a[1].split(",")]:
    bpy.context.scene.frame_set(f)
    ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    hz = [ev.vertices[i].co for i in head]; fz = [ev.vertices[i].co for i in fig]
    cx = sum(p.x for p in hz) / len(hz); cy = sum(p.y for p in hz) / len(hz)
    out[f] = {"hood_top": round(max(p.z for p in hz), 2), "hood_centre_xy": [round(cx, 2), round(cy, 2)], "figure_top": round(max(p.z for p in fig and fz), 2),
              "lowest": round(min(p.z for p in fz), 2), "x": [round(min(p.x for p in fz), 2), round(max(p.x for p in fz), 2)], "y": [round(min(p.y for p in fz), 2), round(max(p.y for p in fz), 2)]}
zdlib.emit({"clip": a[0], "floor": -0.363, "frames": out})
