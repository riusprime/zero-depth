"""src.blend -> rig.blend: the Tidecaller's skeleton and skin.

The delivered file is one fused surface cut into five parts by boxes (Body, ArmL, Shell, Staff, Bell): the cuts do not
follow the things themselves (the lower staff and the claw tips are in Body, scraps of the mantle are in Shell). So the
parts are joined, a welded copy is skinned as a whole (Blender's automatic weights, then the rules below that make
the hard things rigid and give hanging things to their chains), and the weights are copied back by position.
"""
import bpy, sys, os, bmesh, math, colorsys
import numpy as np
from mathutils import Vector, kdtree
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

PARTS = ["Body", "ArmL", "Shell", "Staff", "Bell"]
parts = {}
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name in PARTS:
        mw = o.matrix_world.copy(); o.parent = None
        o.data.transform(mw); o.matrix_world.identity()
        o.modifiers.clear(); o.vertex_groups.clear()
        parts[o.name] = o
for o in list(bpy.data.objects):
    if o not in parts.values(): bpy.data.objects.remove(o)
part_kd = {}
for n, o in parts.items():
    t = kdtree.KDTree(len(o.data.vertices))
    for v in o.data.vertices: t.insert(v.co, v.index)
    t.balance(); part_kd[n] = t
bpy.ops.object.select_all(action='DESELECT')
for o in parts.values(): o.select_set(True)
mesh = parts["Body"]; bpy.context.view_layer.objects.active = mesh
bpy.ops.object.join()
mesh.name = "Tidecaller"; mesh.data.name = "Tidecaller"
me = mesh.data

# ---------------------------------------------------------------- the bones
# name: (head, tail, parent, deform).  The model faces -Y; +X is its left (the reaching arm), -X its right (the staff).
CX, CY = -0.07, 0.05
B = [
 ("root",        (0, 0, 0),             (0, 0.3, 0),            None),
 ("hips",        (CX, CY, 1.15),        (CX, CY, 1.42),         "root"),
 ("spine",       (CX, CY, 1.42),        (CX, CY, 1.72),         "hips"),
 ("chest",       (CX, CY, 1.72),        (CX, 0.0, 2.05),        "spine"),
 ("neck",        (CX, -0.08, 2.05),     (CX, -0.18, 2.15),      "chest"),
 ("head",        (CX, -0.18, 2.15),     (CX, -0.24, 2.55),      "neck"),
 ("shell",       (0.0, 0.33, 2.0),      (0.0, 0.40, 3.1),       "chest"),
 ("shoulder.L",  (0.15, 0.0, 2.12),     (0.52, -0.06, 2.12),    "chest"),
 ("upper_arm.L", (0.52, -0.06, 2.12),   (0.68, -0.40, 1.76),    "shoulder.L"),
 ("forearm.L",   (0.68, -0.40, 1.76),   (0.84, -0.80, 1.37),    "upper_arm.L"),
 ("hand.L",      (0.84, -0.80, 1.37),   (0.88, -0.99, 1.27),    "forearm.L"),
 ("claws.L",     (0.88, -0.99, 1.27),   (0.92, -1.12, 0.90),    "hand.L"),
 ("shoulder.R",  (-0.29, 0.0, 2.12),    (-0.58, 0.08, 2.16),    "chest"),
 ("upper_arm.R", (-0.58, 0.08, 2.16),   (-0.70, 0.38, 1.88),    "shoulder.R"),
 ("forearm.R",   (-0.70, 0.38, 1.88),   (-0.87, 0.02, 1.86),    "upper_arm.R"),
 ("hand.R",      (-0.87, 0.02, 1.86),   (-0.93, -0.14, 1.86),   "forearm.R"),
 ("staff",       (-0.93, -0.10, 1.87),  (-1.01, -0.10, 2.95),   "hand.R"),
 ("bell",        (-1.10, -0.42, 2.95),  (-1.13, -0.45, 2.30),   "staff"),
 ("clapper",     (-1.13, -0.45, 2.60),  (-1.13, -0.45, 2.15),   "bell"),
 ("tassel1",     (-1.10, -0.22, 2.92),  (-1.24, -0.18, 2.40),   "staff"),
 ("tassel2",     (-1.24, -0.18, 2.40),  (-1.28, -0.16, 1.90),   "tassel1"),
 ("tassel3",     (-1.28, -0.16, 1.90),  (-1.25, -0.14, 1.50),   "tassel2"),
 ("thigh.L",     (0.16, -0.05, 1.10),   (0.18, -0.13, 0.62),    "hips"),
 ("shin.L",      (0.18, -0.13, 0.62),   (0.20, -0.08, 0.16),    "thigh.L"),
 ("foot.L",      (0.20, -0.08, 0.16),   (0.22, -0.42, 0.04),    "shin.L"),
 ("thigh.R",     (-0.32, -0.05, 1.10),  (-0.36, -0.13, 0.62),   "hips"),
 ("shin.R",      (-0.36, -0.13, 0.62),  (-0.38, -0.08, 0.16),   "thigh.R"),
 ("foot.R",      (-0.38, -0.08, 0.16),  (-0.42, -0.42, 0.04),   "shin.R"),
 ("sleeve1.L",   (0.72, -0.28, 1.72),   (0.76, -0.20, 1.36),    "upper_arm.L"),
 ("sleeve2.L",   (0.76, -0.20, 1.36),   (0.78, -0.16, 1.00),    "sleeve1.L"),
 ("sleeve1.R",   (-0.76, 0.22, 1.80),   (-0.77, 0.24, 1.45),    "forearm.R"),
 ("sleeve2.R",   (-0.77, 0.24, 1.45),   (-0.78, 0.26, 1.10),    "sleeve1.R"),
 ("pendant1",    (0.02, -0.42, 1.48),   (0.06, -0.48, 1.12),    "hips"),
 ("pendant2",    (0.06, -0.48, 1.12),   (0.26, -0.52, 0.74),    "pendant1"),
]
# The robe: six chains from the waist to the hem.
SKIRT = {"f.L": -52, "f.R": -128, "s.L": 5, "s.R": 175, "b.L": 62, "b.R": 118}
for nm, ang in SKIRT.items():
    a = math.radians(ang); d = Vector((math.cos(a), math.sin(a), 0))
    yk = 0.85 if d.y > 0.3 else (0.75 if d.y < -0.3 else 1.0)       # the hem is wider to the sides than front to back
    p = [Vector((CX, CY, 1.18)) + d * 0.38, Vector((CX, CY, 0.62)) + d * 0.72 * yk, Vector((CX, CY, 0.04)) + d * 1.15 * yk]
    B.append((f"skirt1_{nm}", tuple(p[0]), tuple(p[1]), "hips"))
    B.append((f"skirt2_{nm}", tuple(p[1]), tuple(p[2]), f"skirt1_{nm}"))
SEG = {n: (Vector(h), Vector(t)) for n, h, t, _ in B}

arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in B:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.use_deform = name != "root"
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- what each point is: its colour and its part
img = bpy.data.images["base"]; IW, IH = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(IH, IW, 4)
uv = me.uv_layers.active.data
acc = np.zeros((len(me.vertices), 3)); cnt = np.zeros(len(me.vertices))
for l in me.loops:
    u, v = uv[l.index].uv
    acc[l.vertex_index] += px[int(v % 1.0 * (IH - 1)), int(u % 1.0 * (IW - 1)), :3]; cnt[l.vertex_index] += 1
acc /= np.maximum(cnt, 1)[:, None]

tmp = mesh.copy(); tmp.data = mesh.data.copy(); bpy.context.scene.collection.objects.link(tmp)
bm = bmesh.new(); bm.from_mesh(tmp.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(tmp.data); bm.free()
td = tmp.data; NV = len(td.vertices)
okd = kdtree.KDTree(len(me.vertices))
for v in me.vertices: okd.insert(v.co, v.index)
okd.balance()
col = np.zeros((NV, 3))
for v in td.vertices:
    near = okd.find_range(v.co, 0.001)
    col[v.index] = np.mean([acc[i] for _, i, _ in near], axis=0) if near else acc[okd.find(v.co)[1]]
hsv = np.array([colorsys.rgb_to_hsv(*c) for c in col])
def in_part(co, n): return part_kd[n].find(co)[2] < 0.0008
nbr = [set() for _ in range(NV)]
for e in td.edges:
    a, b = e.vertices; nbr[a].add(b); nbr[b].add(a)

# ---------------------------------------------------------------- automatic weights on the welded copy
bpy.ops.object.select_all(action='DESELECT')
tmp.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unweighted = sum(1 for v in td.vertices if not v.groups)
names = [g.name for g in tmp.vertex_groups]
W = [{names[g.group]: g.weight for g in v.groups if g.weight > 0.01} for v in td.vertices]
P = [v.co.copy() for v in td.vertices]

def off_bone(co, n, past=0.0):
    h, tl = SEG[n]; ax = tl - h; ln = ax.length; ax /= ln
    s = max(-past, min(ln + past, (co - h).dot(ax)))
    return (co - (h + ax * s)).length

exec(open(os.path.join(os.path.dirname(__file__), "tidecaller_rules.py")).read())

# ---------------------------------------------------------------- copy the weights back and finish
kd = kdtree.KDTree(NV)
for v in td.vertices: kd.insert(v.co, v.index)
kd.balance()
for n, _, _, _ in B:
    if n != "root": mesh.vertex_groups.new(name=n)
for v in me.vertices:
    w = W[kd.find(v.co)[1]]
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(x for _, x in top) or 1.0
    if not top: top = [("chest", 1.0)]; s = 1.0
    for n, x in top: mesh.vertex_groups[n].add([v.index], x / s, 'REPLACE')
bpy.data.objects.remove(tmp)

# ---------------------------------------------------------------- tear the hard things free of the cloth they touch
# The file is one fused surface: where the pole stands in the robe there are faces with corners on both. Each such
# face keeps to the cloth: its corners on the pole become new points (no new triangles) that take the cloth's weights.
def tear(hard, keep):
    """hard: the rigid bone. keep: bones whose points may stay joined to it."""
    gi = {g.name: g.index for g in mesh.vertex_groups}; H = gi[hard]; K = {gi[k] for k in keep} | {H}
    bm = bmesh.new(); bm.from_mesh(me); dl = bm.verts.layers.deform.verify()
    def is_hard(v): return v[dl].get(H, 0) > 0.98
    def kept(v):
        d = v[dl]; top = max(d.keys(), key=lambda k: d[k]); return top in K
    made = {}; n = 0
    for f in list(bm.faces):
        hv = [v for v in f.verts if is_hard(v)]; sv = [v for v in f.verts if not kept(v)]
        if not hv or not sv: continue
        acc = {}
        for v in sv:
            for k, x in v[dl].items():
                if k != H: acc[k] = acc.get(k, 0) + x
        s = sum(acc.values())
        if s <= 0: continue
        for v in hv:
            nv = bmesh.utils.face_vert_separate(f, v)
            if nv is None or nv is v: continue          # this corner was the vertex's only face: it is free already
            nv[dl].clear()
            for k, x in acc.items(): nv[dl][k] = x / s
            made.setdefault(v, []).append(nv); n += 1
    # The new points made from one old point join again (they sit in the same place), with their weights averaged.
    tm = {}
    for v, lst in made.items():
        if len(lst) < 2: continue
        acc = {}
        for nv in lst:
            for k, x in nv[dl].items(): acc[k] = acc.get(k, 0) + x / len(lst)
        lst[0][dl].clear()
        for k, x in acc.items(): lst[0][dl][k] = x
        for nv in lst[1:]: tm[nv] = lst[0]
    if tm: bmesh.ops.weld_verts(bm, targetmap=tm)
    bm.to_mesh(me); bm.free()
    return n
TORN = {"staff": tear("staff", ["hand.R", "forearm.R", "bell", "tassel1", "tassel2", "tassel3"]),
        "bell": tear("bell", ["clapper"])}      # the ribbons that hang past the bell stay with the hook
mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig
cntd = {}
for v in me.vertices:
    g = max(v.groups, key=lambda g: g.weight); n = mesh.vertex_groups[g.group].name; cntd[n] = cntd.get(n, 0) + 1
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"unweighted_welded": unweighted, "welded": NV, "verts": len(me.vertices),
            "tris": sum(len(p.vertices) - 2 for p in me.polygons), "bones": len(arm.bones), "report": REPORT, "torn": TORN})
