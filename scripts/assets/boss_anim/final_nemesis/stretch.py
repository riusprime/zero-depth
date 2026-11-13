import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; frames = [int(x) for x in args[1].split(',')]
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[name]
m = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig][0]
me = m.data; gn = {g.index: g.name for g in m.vertex_groups}
rest = [v.co.copy() for v in me.vertices]
edges = [(e.vertices[0], e.vertices[1]) for e in me.edges]
worst = {}
for f in frames:
    bpy.context.scene.frame_set(f)
    ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    for a, b in edges:
        r = (rest[a] - rest[b]).length
        if r < 1e-5: continue
        d = (ev.vertices[a].co - ev.vertices[b].co).length
        if d - r > 0.12:
            for i in (a, b):
                g = max(me.vertices[i].groups, key=lambda g: g.weight)
                key = (gn[g.group], round(rest[i].x, 1), round(rest[i].y, 1), round(rest[i].z, 1))
                worst[key] = max(worst.get(key, 0), round(d - r, 2))
top = sorted(worst.items(), key=lambda kv: -kv[1])[:40]
zdlib.emit({"n": len(worst), "top": [[*k, v] for k, v in top]})
