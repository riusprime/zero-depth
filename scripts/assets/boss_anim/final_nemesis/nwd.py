"""rig.blend: colour every vertex by its bones (blended), six views -> out/wd.png"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
m = [o for o in bpy.data.objects if o.type == 'MESH'][0]; me = m.data
PAL = {"head": (1, 1, 1), "neck": (.6, .6, .6), "chest": (1, .6, 0), "spine": (.8, .8, 0), "hips": (.5, .3, 0),
       "shoulder": (1, 0, 1), "upper_arm": (1, 0, 0), "forearm": (0, 1, 0), "hand": (0, .4, 1),
       "thigh": (0, 1, 1), "shin": (1, .3, .6), "foot": (.3, 1, .3), "toe": (1, 1, 0), "tab": (.6, 0, 1),
       "cloak1": (.2, .2, .9), "cloak2": (.1, .7, .7), "cloak3": (.9, .3, .1), "cloak4": (.3, .8, .2)}
gi = {g.index: g.name for g in m.vertex_groups}
att = me.color_attributes.new("dbg", 'FLOAT_COLOR', 'POINT')
for v in me.vertices:
    c = [0, 0, 0]
    for g in v.groups:
        n = gi[g.group]; base = n.split(".")[0]; col = PAL.get(base, (.3, .3, .3))
        k = 1.0
        if n.endswith(".R"): k = 0.6
        if n.endswith(".B"): k = 0.35
        for i in range(3): c[i] += col[i] * g.weight * k
    att.data[v.index].color = (*c, 1)
me.color_attributes.active_color = att
sc = zdlib.setup_render((640, 640)); sc.display.shading.color_type = 'VERTEX'; sc.display.shading.light = 'FLAT'
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out")); ps = []
for nm, v, tz, o in [("f", (0, -1, 0), .75, 1.6), ("fl", (0.3, -1, -0.5), .5, 1.4), ("s", (-1, 0, 0), .75, 1.6),
                     ("b", (0, 1, 0), .75, 1.6), ("u", (0, -0.15, -1), .4, 1.4), ("q", (-0.8, -1, 0.4), .75, 1.6)]:
    p = os.path.join(out, f"_wd_{nm}.png"); zdlib.render(p, v, target=(0, 0, tz), ortho=o); ps.append(p)
zdlib.sheet(ps, os.path.join(out, "wd.png"), 3)
for p in ps: os.remove(p)
