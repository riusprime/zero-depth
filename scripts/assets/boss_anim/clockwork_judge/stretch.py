"""anim.blend: the edges that pull apart. For every action, the edges that grow past 1.5x (and by more than 4 cm) at
any sampled frame, counted by the pair of bones their two ends follow."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
rig = bpy.data.objects["Rig"]
m = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig][0]; me = m.data
names = [g.name for g in m.vertex_groups]
dom = [names[max(v.groups, key=lambda g: g.weight).group] for v in me.vertices]
rest = [v.co.copy() for v in me.vertices]
edges = [(e.vertices[0], e.vertices[1]) for e in me.edges]
rl = [(rest[a] - rest[b]).length for a, b in edges]
sc = bpy.context.scene; out = {}
for act in bpy.data.actions:
    rig.animation_data.action = act
    worst = {}
    for f in range(int(act.frame_range[0]), int(act.frame_range[1]) + 1, 3):
        sc.frame_set(f)
        ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()); em = ev.to_mesh()
        co = [v.co.copy() for v in em.vertices]; ev.to_mesh_clear()
        for i, (a, b) in enumerate(edges):
            l = (co[a] - co[b]).length
            if l > rl[i] * 1.5 and l - rl[i] > 0.04:
                k = "|".join(sorted((dom[a], dom[b])))
                w = worst.setdefault(k, [0, 0.0, f]); w[0] += 1
                if l - rl[i] > w[1]: w[1] = round(l - rl[i], 3); w[2] = f
    out[act.name] = worst
zdlib.emit(out)
