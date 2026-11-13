"""anim.blend: per action, the lowest and highest point of the deformed mesh, how many vertices are under the ground,
which bones own them, and the longest edge stretch.  -- <action[:f0,f1,..]> ..."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]
m = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig][0]
me = m.data; gn = {g.index: g.name for g in m.vertex_groups}
rest = [v.co.copy() for v in me.vertices]
edges = [(e.vertices[0], e.vertices[1]) for e in me.edges]
res = {}
for a in args:
    name, _, fr = a.partition(":")
    act = bpy.data.actions[name]; rig.animation_data.action = act
    frames = [int(x) for x in fr.split(",")] if fr else range(int(act.frame_range[0]), int(act.frame_range[1]) + 1)
    rows = []
    for f in frames:
        bpy.context.scene.frame_set(f)
        ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        zs = [v.co.z for v in ev.vertices]
        under = {}
        for i, z in enumerate(zs):
            if z < -0.02:
                g = max(me.vertices[i].groups, key=lambda g: g.weight); n = gn[g.group]; under[n] = under.get(n, 0) + 1
        st = 0.0
        for x, y in edges:
            r = (rest[x] - rest[y]).length
            st = max(st, (ev.vertices[x].co - ev.vertices[y].co).length - r)
        rows.append([f, round(min(zs), 3), round(max(zs), 3), round(st, 3), under])
    worst = min(rows, key=lambda r: r[1]); tall = max(rows, key=lambda r: r[2]); low = min(rows, key=lambda r: r[2]); stw = max(rows, key=lambda r: r[3])
    res[name] = {"lowest": worst, "top_max": tall[:3], "top_min": low[:3], "stretch_max": stw[:4], "first": rows[0], "last": rows[-1]}
for k, v in res.items(): print("CHK", k, v)
