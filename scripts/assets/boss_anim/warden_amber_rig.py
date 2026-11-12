"""amber_src.blend -> rig.blend: strip the old rig, build a new skeleton, skin the mesh."""
import bpy, sys, os, bmesh
from mathutils import Vector, kdtree
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, plates
HERE = zdlib.WORK

mesh = [x for x in bpy.data.objects if x.type == 'MESH' and x.name.startswith('tripo')][0]
mw = mesh.matrix_world.copy()
mesh.parent = None
mesh.matrix_world = mw
for o in list(bpy.data.objects):
    if o != mesh: bpy.data.objects.remove(o)
mesh.modifiers.clear(); mesh.vertex_groups.clear()
mesh.data.transform(mw); mesh.matrix_world.identity()
mesh.name = "WardenAmber"; mesh.data.name = "WardenAmber"

# name: (head, tail, parent, connected, deform).  The model faces -Y; its right side is -X.
B = [
 ("root",        (0, 0, 0),             (0, 0.3, 0),           None, False),
 ("hips",        (-0.04, 0.03, 1.08),   (-0.04, 0.03, 1.27),   "root", True),
 ("spine",       (-0.04, 0.03, 1.27),   (-0.04, 0.03, 1.45),   "hips", True),
 ("chest",       (-0.04, 0.03, 1.45),   (-0.04, 0.03, 1.72),   "spine", True),
 ("neck",        (-0.04, 0.03, 1.72),   (-0.04, 0.02, 1.82),   "chest", True),
 ("head",        (-0.04, 0.02, 1.82),   (-0.04, 0.02, 2.08),   "neck", True),
 ("shoulder.R",  (-0.12, 0.06, 1.66),   (-0.36, 0.07, 1.63),   "chest", True),
 ("pauldron.R",  (-0.20, 0.07, 1.74),   (-0.52, 0.07, 1.60),   "shoulder.R", False),
 ("upper_arm.R", (-0.36, 0.07, 1.63),   (-0.56, 0.07, 1.28),   "shoulder.R", True),
 ("forearm.R",   (-0.56, 0.07, 1.28),   (-0.70, 0.00, 0.95),   "upper_arm.R", True),
 ("hand.R",      (-0.70, 0.00, 0.95),   (-0.71, -0.04, 0.82),  "forearm.R", True),
 ("sword",       (-0.70, -0.08, 0.80),  (-0.62, -0.66, 0.16),  "hand.R", True),
 ("shoulder.L",  (0.04, 0.06, 1.66),    (0.26, 0.07, 1.63),    "chest", True),
 ("pauldron.L",  (0.10, 0.07, 1.74),    (0.42, 0.07, 1.60),    "shoulder.L", False),
 ("upper_arm.L", (0.26, 0.07, 1.63),    (0.42, 0.06, 1.28),    "shoulder.L", True),
 ("forearm.L",   (0.42, 0.06, 1.28),    (0.60, -0.05, 0.90),   "upper_arm.L", True),
 ("hand.L",      (0.60, -0.05, 0.90),   (0.63, -0.08, 0.78),   "forearm.L", True),
 ("shield",      (0.56, -0.20, 1.70),   (0.56, -0.20, 0.15),   "forearm.L", True),
 ("thigh.R",     (-0.20, 0.03, 1.08),   (-0.33, -0.03, 0.68),  "hips", True),
 ("shin.R",      (-0.33, -0.03, 0.68),  (-0.45, 0.12, 0.17),   "thigh.R", True),
 ("foot.R",      (-0.45, 0.12, 0.17),   (-0.50, -0.06, 0.06),  "shin.R", True),
 ("toe.R",       (-0.50, -0.06, 0.06),  (-0.53, -0.20, 0.05),  "foot.R", True),
 ("thigh.L",     (0.12, 0.03, 1.08),    (0.21, -0.03, 0.68),   "hips", True),
 ("shin.L",      (0.21, -0.03, 0.68),   (0.33, 0.12, 0.17),    "thigh.L", True),
 ("foot.L",      (0.33, 0.12, 0.17),    (0.39, -0.06, 0.06),   "shin.L", True),
 ("toe.L",       (0.39, -0.06, 0.06),   (0.42, -0.20, 0.05),   "foot.L", True),
 ("tabard1",     (-0.07, -0.20, 1.08),  (-0.07, -0.25, 0.74),  "hips", True),
 ("tabard2",     (-0.07, -0.25, 0.74),  (-0.07, -0.27, 0.36),  "tabard1", True),
]
CAPE = {"M": [(-0.10, 0.27, 1.58), (-0.10, 0.40, 1.08), (-0.12, 0.52, 0.56), (-0.14, 0.62, 0.04)],
        "L": [(0.22, 0.24, 1.55), (0.30, 0.34, 1.06), (0.38, 0.42, 0.56), (0.44, 0.48, 0.04)],
        "R": [(-0.42, 0.24, 1.55), (-0.56, 0.32, 1.06), (-0.68, 0.40, 0.56), (-0.78, 0.46, 0.04)]}
for side, pts in CAPE.items():
    for i in range(3):
        B.append((f"cape{i+1}.{side}", pts[i], pts[i+1], "chest" if i == 0 else f"cape{i}.{side}", True))

arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par, deform in B:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.use_deform = deform
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
LATE = ("pauldron.R", "pauldron.L")      # weighted by rule below, not by the automatic pass

# Skin a welded copy (the file splits vertices along UV seams), then copy weights back by position.
tmp = mesh.copy(); tmp.data = mesh.data.copy(); bpy.context.scene.collection.objects.link(tmp)
bm = bmesh.new(); bm.from_mesh(tmp.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(tmp.data); bm.free()
bpy.ops.object.select_all(action='DESELECT')
tmp.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unweighted = sum(1 for v in tmp.data.vertices if not v.groups)

kd = kdtree.KDTree(len(tmp.data.vertices))
for v in tmp.data.vertices: kd.insert(v.co, v.index)
kd.balance()
names = [g.name for g in tmp.vertex_groups]
for n in names: mesh.vertex_groups.new(name=n)
for n in LATE:
    arm.bones[n].use_deform = True
    if n not in names: mesh.vertex_groups.new(name=n)
def plate(v, w):
    """The shoulder plates are armour: each moves as one piece on its own bone."""
    for side, out in (("R", -(v.co.x + 0.05)), ("L", v.co.x + 0.05)):      # out: metres from the body's middle
        arm_w = w.get(f"shoulder.{side}", 0) + w.get(f"upper_arm.{side}", 0)
        tall = v.co.z > 1.47 or (v.co.z > 1.36 and out > 0.45)
        if out > 0.17 and tall and arm_w > (0.3 if out > 0.25 else 0.5):
            return {f"pauldron.{side}": 1.0}
    return w
RIGID = {"shield": 0.4, "sword": 0.4, "head": 0.5}
picked = {"R": set(), "L": set()}
allowed = {"R": set(), "L": set()}     # where a plate may reach at all: off the cloak, beside the body, shoulder high
for v in mesh.data.vertices:
    _, idx, _ = kd.find(v.co)
    w = {names[g.group]: g.weight for g in tmp.data.vertices[idx].groups if g.weight > 0.01}
    for n, th in RIGID.items():
        if w.get(n, 0) >= th: w = {n: 1.0}
    cloak = sum(x for n, x in w.items() if n.startswith("cape"))
    for side, out in (("R", -(v.co.x + 0.05)), ("L", v.co.x + 0.05)):
        if out > 0.17 and v.co.z > 1.36 and cloak < 0.5: allowed[side].add(v.index)
    pw = plate(v, w)
    if pw is not w: picked[list(pw)[0][-1]].add(v.index)
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(x for _, x in top) or 1.0
    for n, x in top: mesh.vertex_groups[n].add([v.index], x / s, 'REPLACE')
bpy.data.objects.remove(tmp)
plate_report = plates.cut(mesh, picked, allowed)
mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig

cnt = {}
for v in mesh.data.vertices:
    if v.groups:
        g = max(v.groups, key=lambda g: g.weight); n = mesh.vertex_groups[g.group].name; cnt[n] = cnt.get(n, 0) + 1
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"unweighted_welded": unweighted, "plates": plate_report, "verts": len(mesh.data.vertices), "tris": sum(len(p.vertices) - 2 for p in mesh.data.polygons)})
