"""src.blend (or rig.blend): render the parts the rules pick, each in a colour.  -- <name> <cx,cy,cz> <ortho> <views>"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, parts
args = sys.argv[sys.argv.index('--') + 1:]
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
m = [o for o in bpy.data.objects if o.type == 'MESH'][0]; me = m.data
cls, red = parts.classify(m)
COL = {'': (0.35, 0.35, 0.35), 'spear': (1, 1, 0), 'shield': (0, 0.4, 1), 'pauldron_R': (1, 0.5, 0), 'pauldron_L': (1, 0, 1),
       'cape': (0, 0.9, 0.2), 'tabard': (0, 0.9, 0.9), 'plume': (1, 1, 1)}
att = me.color_attributes.new("dbg", 'FLOAT_COLOR', 'POINT')
for v in me.vertices:
    c = COL[cls[v.index]]
    k = 1.0 if cls[v.index] else (1.6 if red[v.index] > 0.04 else 1.0)
    att.data[v.index].color = (c[0] * k, c[1] * (1 if k == 1 else 0.5), c[2] * (1 if k == 1 else 0.5), 1)
me.color_attributes.active_color = att
sc = zdlib.setup_render((640, 720)); sc.display.shading.color_type = 'VERTEX'
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
V = {"f": (1, 0, 0.05), "q": (1, -0.8, 0.35), "r": (0, -1, 0.05), "l": (0, 1, 0.05), "b": (-1, 0, 0.05),
     "t": (0.01, 0, 1), "q2": (1, 0.8, 0.35), "qb": (-1, -0.8, 0.35), "qb2": (-1, 0.8, 0.35), "u": (0.3, 0, -1), "in": (0.2, -1, 0.3)}
tgt = tuple(float(x) for x in args[1].split(',')); ps = []
for n in args[3].split(','):
    p = os.path.join(out, f"_pl_{n}.png"); zdlib.render(p, V[n], target=tgt, ortho=float(args[2])); ps.append(p)
zdlib.sheet(ps, os.path.join(out, args[0] + ".png"), len(ps))
for p in ps: os.remove(p)
cnt = {}
for c in cls: cnt[c] = cnt.get(c, 0) + 1
zdlib.emit(cnt)
