"""Any blend: N views of the model as it stands.  -- <out name> <tx,ty,tz> <ortho> [views: f,q,r,l,b,t,q2,qb]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
args = sys.argv[sys.argv.index('--') + 1:]
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
tgt = tuple(float(x) for x in args[1].split(',')); orth = float(args[2])
V = {"f": (1, 0, 0.05), "q": (1, -0.8, 0.35), "r": (0, -1, 0.05), "l": (0, 1, 0.05), "b": (-1, 0, 0.05),
     "t": (0.01, 0, 1), "q2": (1, 0.8, 0.35), "qb": (-1, -0.8, 0.35), "qb2": (-1, 0.8, 0.35), "u": (0.01, 0, -1)}
names = (args[3] if len(args) > 3 else "f,r,b,l").split(',')
zdlib.setup_render((560, 640))
ps = []
for n in names:
    p = os.path.join(out, f"_lk_{n}.png"); zdlib.render(p, V[n], target=tgt, ortho=orth); ps.append(p)
zdlib.sheet(ps, os.path.join(out, args[0] + ".png"), len(ps))
for p in ps: os.remove(p)
