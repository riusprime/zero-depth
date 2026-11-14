"""Any blend with the armature: pose a few bones (rotations in armature axes, degrees), render views.
-- <out name> <views> <tz> <ortho> Bone:x,y,z [Bone:x,y,z ...]"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
args = sys.argv[sys.argv.index('--') + 1:]
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
rig = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
P = Poser(rig)
pose = {}
for a in args[4:]:
    n, v = a.split(':'); x, y, z = [float(t) for t in v.split(',')]
    pose[n] = {"rot": qe(x=x, y=y, z=z)}
poser.new_action(rig, "_test"); P.key(pose, 0)
bpy.context.scene.frame_set(0)
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
V = {"f": (1, 0, 0.05), "q": (1, -0.8, 0.35), "r": (0, -1, 0.05), "l": (0, 1, 0.05), "b": (-1, 0, 0.05),
     "t": (0.01, 0, 1), "q2": (1, 0.8, 0.35), "qb": (-1, -0.8, 0.35), "qb2": (-1, 0.8, 0.35)}
zdlib.setup_render((560, 640))
ps = []
for n in args[1].split(','):
    p = os.path.join(out, f"_tp_{n}.png"); zdlib.render(p, V[n], target=(0, 0, float(args[2])), ortho=float(args[3])); ps.append(p)
zdlib.sheet(ps, os.path.join(out, args[0] + ".png"), len(ps))
for p in ps: os.remove(p)
# edges that pull apart in this pose
m = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = m.data; gn = {g.index: g.name for g in m.vertex_groups}
ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
worst = {}
for e in me.edges:
    a, b = e.vertices
    r = (me.vertices[a].co - me.vertices[b].co).length
    d = (ev.vertices[a].co - ev.vertices[b].co).length
    if d - r > 0.04:
        ks = []
        for i in (a, b):
            g = max(me.vertices[i].groups, key=lambda g: g.weight); c = me.vertices[i].co
            ks.append(f"{gn[g.group]}({c.x:.2f},{c.y:.2f},{c.z:.2f})")
        worst[" - ".join(ks)] = round(d - r, 2)
zdlib.emit({"n": len(worst), "top": sorted(worst.items(), key=lambda kv: -kv[1])[:30]})
