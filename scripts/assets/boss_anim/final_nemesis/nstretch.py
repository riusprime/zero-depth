"""anim.blend: the most stretched edges of one frame.  -- <action> <frame>"""
import bpy, sys
args = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[args[0]]
m = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig][0]; me = m.data
gn = {g.index: g.name for g in m.vertex_groups}
bpy.context.scene.frame_set(int(args[1]))
ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
rows = []
for e in me.edges:
    a, b = e.vertices
    r = (me.vertices[a].co - me.vertices[b].co).length; d = (ev.vertices[a].co - ev.vertices[b].co).length
    rows.append((d - r, a, b))
rows.sort(reverse=True)
def desc(i):
    v = me.vertices[i]
    return f"({v.co.x:+.2f},{v.co.y:+.2f},{v.co.z:.2f}) " + " ".join(f"{gn[g.group]}:{g.weight:.2f}" for g in sorted(v.groups, key=lambda g: -g.weight))
for s, a, b in rows[:14]: print(f"STR {s:.2f} | {desc(a)} | {desc(b)}")
