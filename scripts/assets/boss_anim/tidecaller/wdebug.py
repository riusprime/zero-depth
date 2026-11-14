import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
cols = {args[0]: (1, 0, 0), args[1]: (0, 1, 0), args[2]: (0, 0.3, 1)}
m = [o for o in bpy.data.objects if o.type == "MESH" and o.parent and o.parent.name == "Rig"][0]; me = m.data
gi = {g.index: g.name for g in m.vertex_groups}
att = me.color_attributes.new("dbg", 'FLOAT_COLOR', 'POINT')
for v in me.vertices:
    c = [0.25, 0.25, 0.25]
    for g in v.groups:
        n = gi[g.group]
        if n in cols:
            for i in range(3): c[i] += cols[n][i] * g.weight * 0.75
    att.data[v.index].color = (*c, 1)
me.color_attributes.active_color = att
sc = zdlib.setup_render((560, 560)); sc.display.shading.color_type = 'VERTEX'
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
tgt = tuple(float(x) for x in args[3].split(',')); ps = []
for nm, v in [("f", (0, -1, 0.2)), ("s", (-1, -0.2, 0.2)), ("b", (-0.3, 1, 0.3)), ("t", (-0.2, -0.3, 1))]:
    p = os.path.join(out, f"_wd_{nm}.png"); zdlib.render(p, v, target=tgt, ortho=1.5); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "wd.png"), 4)
for p in ps: os.remove(p)
