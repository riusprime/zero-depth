"""anim.blend: edges that pull apart in a clip, by the bones that own them.  -- <action> [limit ratio]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
a = sys.argv[sys.argv.index('--') + 1:]
name = a[0]; lim = float(a[1]) if len(a) > 1 else 1.6
rig = bpy.data.objects["Rig"]; act = bpy.data.actions[name]; rig.animation_data.action = act
m = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = m.data
gn = [g.name for g in m.vertex_groups]
def dom(v):
    return gn[max(v.groups, key=lambda g: g.weight).group] if v.groups else "-"
rest = [(me.vertices[e.vertices[0]].co - me.vertices[e.vertices[1]].co).length for e in me.edges]
worst = {}
sc = bpy.context.scene
for f in range(int(act.frame_range[0]), int(act.frame_range[1]) + 1, 2):
    sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get(); ev = m.evaluated_get(dg); em = ev.data
    for e, r0 in zip(me.edges, rest):
        if r0 < 0.02: continue
        i, j = e.vertices
        r = (em.vertices[i].co - em.vertices[j].co).length / r0
        if r > lim:
            k = tuple(sorted((dom(me.vertices[i]), dom(me.vertices[j]))))
            w = worst.get(k)
            if w is None or r > w[0]: worst[k] = (round(r, 2), f, [round(x, 2) for x in me.vertices[i].co], w[3] + 1 if w else 1)
            else: worst[k] = (w[0], w[1], w[2], w[3] + 1)
zdlib.emit({"clip": name, "pairs": {f"{k[0]}|{k[1]}": v for k, v in sorted(worst.items(), key=lambda kv: -kv[1][0])[:25]}})
