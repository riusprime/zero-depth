"""rig.blend: colour every vertex by its bones (each bone its own colour, mixed by weight), six views, bones drawn as
dark lines. -- [name] [tx,ty,tz] [ortho] [bone,bone: only these coloured]"""
import bpy, sys, os, colorsys
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
name = args[0] if args else "wall"
T = tuple(float(x) for x in args[1].split(',')) if len(args) > 1 else (0, 0, 1.6)
orth = float(args[2]) if len(args) > 2 else 3.9
only = args[3].split(',') if len(args) > 3 else None
rig = bpy.data.objects["Rig"]
m = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = m.data
gi = {g.index: g.name for g in m.vertex_groups}
bn = [b.name for b in rig.data.bones]
def colour(n):
    i = bn.index(n)
    return colorsys.hsv_to_rgb((i * 0.381966) % 1.0, 0.55 + 0.45 * ((i * 7) % 3) / 2, 1.0 - 0.35 * ((i * 5) % 4) / 3)
att = me.color_attributes.new("dbg", 'FLOAT_COLOR', 'POINT')
for v in me.vertices:
    c = [0.0, 0.0, 0.0]; tot = 0
    for g in v.groups:
        n = gi[g.group]
        if only and n not in only: continue
        k = colour(n); tot += g.weight
        for i in range(3): c[i] += k[i] * g.weight
    if only: c = [0.2 + 0.8 * x for x in c]
    att.data[v.index].color = (*c, 1)
me.color_attributes.active_color = att
sc = zdlib.setup_render((640, 640)); sc.display.shading.color_type = 'VERTEX'; sc.display.shading.light = 'FLAT'
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out")); ps = []
for nm, v in [("front", (0, -1, 0)), ("left", (1, 0, 0)), ("back", (0, 1, 0)), ("right", (-1, 0, 0)), ("top", (0, -0.001, 1)), ("q", (-0.8, -1, 0.45))]:
    p = os.path.join(out, f"_w_{nm}.png"); zdlib.render(p, v, target=T, ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, f"{name}.png"), 3)
for p in ps: os.remove(p)
