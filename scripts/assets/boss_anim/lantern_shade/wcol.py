"""rig.blend: every bone's weights as its own colour.  -- [cx,cy,cz] [size]"""
import bpy, sys, os, colorsys
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
tgt = tuple(float(x) for x in a[0].split(',')) if a else (0, 0, 1.75); size = float(a[1]) if len(a) > 1 else 3.8
m = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = m.data
names = [g.name for g in m.vertex_groups]
order = sorted(names)
cols = {}
for i, n in enumerate(order):
    h = (i * 0.381966) % 1.0
    cols[n] = colorsys.hsv_to_rgb(h, 0.55 + 0.45 * ((i * 7) % 3) / 2, 1.0 - 0.3 * ((i * 5) % 3) / 2)
att = me.color_attributes.new("dbg", 'FLOAT_COLOR', 'POINT')
for v in me.vertices:
    c = [0.0, 0.0, 0.0]
    for g in v.groups:
        k = cols[names[g.group]]
        for i in range(3): c[i] += k[i] * g.weight
    att.data[v.index].color = (*c, 1)
me.color_attributes.active_color = att
sc = zdlib.setup_render((700, 700)); sc.display.shading.color_type = 'VERTEX'; sc.display.shading.light = 'FLAT'
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out")); ps = []
for nm, v in [("f", (0, -1, 0.0)), ("r", (-1, 0, 0.0)), ("b", (0, 1, 0.0)), ("l", (1, 0, 0))]:
    p = os.path.join(out, f"_wc_{nm}.png"); zdlib.render(p, v, target=tgt, ortho=size); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "wcol.png"), 4)
for p in ps: os.remove(p)
print("LEGEND", {n: [round(x, 2) for x in cols[n]] for n in order})
