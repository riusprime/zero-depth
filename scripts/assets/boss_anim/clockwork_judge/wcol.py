"""Every vertex coloured by its bones (a colour per bone, mixed by weight).  -- <name> <tx,ty,tz> <ortho>"""
import bpy, sys, os, colorsys
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
name = args[0]; tgt = tuple(float(x) for x in args[1].split(',')); S = float(args[2])
m = [o for o in bpy.data.objects if o.type == "MESH" and o.parent and o.parent.name == "Rig"][0]; me = m.data
names = [g.name for g in m.vertex_groups]
col = {}
for i, n in enumerate(sorted(names)):
    col[n] = colorsys.hsv_to_rgb((i * 0.381966) % 1.0, 0.55 + 0.45 * ((i * 7) % 3) / 2, 1.0 - 0.3 * ((i * 5) % 3) / 2)
att = me.color_attributes.new("dbg", 'FLOAT_COLOR', 'POINT')
for v in me.vertices:
    c = [0.0, 0.0, 0.0]
    for g in v.groups:
        k = col[names[g.group]]
        for i in range(3): c[i] += k[i] * g.weight
    att.data[v.index].color = (*c, 1)
me.color_attributes.active_color = att
sc = zdlib.setup_render((700, 760)); sc.display.shading.color_type = 'VERTEX'
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
ps = []
for nm, v in [("f", (0, -1, 0.1)), ("q", (-0.8, -1, 0.3)), ("s", (1, 0, 0.1)), ("b", (0.5, 1, 0.3))]:
    p = os.path.join(out, f"_wc_{nm}.png"); zdlib.render(p, v, target=tgt, ortho=S); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"wcol_{name}.png"), 4)
for p in ps: os.remove(p)
print("COL " + ", ".join(f"{n}=({c[0]:.1f},{c[1]:.1f},{c[2]:.1f})" for n, c in col.items()))
