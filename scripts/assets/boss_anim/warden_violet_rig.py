"""amber_src.blend -> rig.blend: strip the old rig, build a new skeleton, skin the mesh."""
import bpy, sys, os, bmesh
from mathutils import Vector, kdtree
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, plates
HERE = zdlib.WORK

# The violet file is cut into parts: the body is skinned, each loose part goes whole to one bone, then all are joined.
PART_BONE = {"Helm": "head", "Shield": "shield", "Sword": "sword"}
parts = {}
for o in list(bpy.data.objects):
    if o.type == 'MESH' and (o.name == "Body" or o.name in PART_BONE):
        mw = o.matrix_world.copy(); o.parent = None
        o.data.transform(mw); o.matrix_world.identity()
        o.modifiers.clear(); o.vertex_groups.clear()
        parts[o.name] = o
for o in list(bpy.data.objects):
    if o not in parts.values(): bpy.data.objects.remove(o)
mesh = parts["Body"]
mesh.name = "WardenViolet"; mesh.data.name = "WardenViolet"

# name: (head, tail, parent, connected, deform).  The model faces -Y; its right side is -X.
B = [
 ("root",        (0, 0, 0),              (0, 0.3, 0),            None, False),
 ("hips",        (-0.03, -0.06, 1.08),   (-0.03, -0.06, 1.27),   "root", True),
 ("spine",       (-0.03, -0.06, 1.27),   (-0.03, -0.06, 1.45),   "hips", True),
 ("chest",       (-0.03, -0.06, 1.45),   (-0.03, -0.06, 1.72),   "spine", True),
 ("neck",        (-0.03, -0.06, 1.72),   (-0.03, -0.09, 1.80),   "chest", True),
 ("head",        (-0.03, -0.09, 1.80),   (-0.03, -0.09, 2.06),   "neck", True),
 ("shoulder.L",  (0.05, -0.04, 1.66),    (0.36, -0.04, 1.60),    "chest", True),
 ("pauldron.L",  (0.14, -0.04, 1.74),    (0.48, -0.04, 1.60),    "shoulder.L", False),
 ("upper_arm.L", (0.36, -0.04, 1.60),    (0.56, -0.08, 1.28),    "shoulder.L", True),
 ("forearm.L",   (0.56, -0.08, 1.28),    (0.49, -0.20, 0.92),    "upper_arm.L", True),
 ("hand.L",      (0.49, -0.20, 0.92),    (0.49, -0.24, 0.80),    "forearm.L", True),
 ("sword",       (0.50, -0.26, 0.80),    (0.62, -0.56, 0.12),    "hand.L", True),
 ("shoulder.R",  (-0.11, -0.04, 1.66),   (-0.42, -0.04, 1.60),   "chest", True),
 ("pauldron.R",  (-0.20, -0.04, 1.74),   (-0.54, -0.04, 1.60),   "shoulder.R", False),
 ("upper_arm.R", (-0.42, -0.04, 1.60),   (-0.52, -0.04, 1.28),   "shoulder.R", True),
 ("forearm.R",   (-0.52, -0.04, 1.28),   (-0.54, -0.10, 0.98),   "upper_arm.R", True),
 ("hand.R",      (-0.54, -0.10, 0.98),   (-0.54, -0.12, 0.86),   "forearm.R", True),
 ("shield",      (-0.70, -0.10, 1.47),   (-0.70, -0.10, 0.17),   "forearm.R", True),
 ("thigh.L",     (0.13, -0.05, 1.08),    (0.25, -0.10, 0.68),    "hips", True),
 ("shin.L",      (0.25, -0.10, 0.68),    (0.37, 0.03, 0.17),     "thigh.L", True),
 ("foot.L",      (0.37, 0.03, 0.17),     (0.41, -0.16, 0.06),    "shin.L", True),
 ("toe.L",       (0.41, -0.16, 0.06),    (0.43, -0.32, 0.05),    "foot.L", True),
 ("thigh.R",     (-0.19, -0.05, 1.08),   (-0.33, -0.10, 0.68),   "hips", True),
 ("shin.R",      (-0.33, -0.10, 0.68),   (-0.47, 0.03, 0.17),    "thigh.R", True),
 ("foot.R",      (-0.47, 0.03, 0.17),    (-0.51, -0.16, 0.06),   "shin.R", True),
 ("toe.R",       (-0.51, -0.16, 0.06),   (-0.54, -0.32, 0.05),   "foot.R", True),
 ("tabard1",     (-0.02, -0.27, 1.08),   (-0.02, -0.31, 0.74),   "hips", True),
 ("tabard2",     (-0.02, -0.31, 0.74),   (-0.02, -0.33, 0.40),   "tabard1", True),
]
CAPE = {"M": [(-0.03, 0.17, 1.58), (-0.03, 0.30, 1.08), (-0.03, 0.40, 0.56), (-0.03, 0.48, 0.04)],
        "L": [(0.36, 0.14, 1.55), (0.50, 0.24, 1.06), (0.64, 0.32, 0.56), (0.76, 0.38, 0.04)],
        "R": [(-0.42, 0.14, 1.55), (-0.56, 0.24, 1.06), (-0.70, 0.32, 0.56), (-0.82, 0.38, 0.04)]}
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
# The loose parts' bones carry only their parts: the body takes nothing from them.
for bone in PART_BONE.values(): arm.bones[bone].use_deform = False
bpy.ops.object.select_all(action='DESELECT')
tmp.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
for bone in PART_BONE.values(): arm.bones[bone].use_deform = True
unweighted = sum(1 for v in tmp.data.vertices if not v.groups)

kd = kdtree.KDTree(len(tmp.data.vertices))
for v in tmp.data.vertices: kd.insert(v.co, v.index)
kd.balance()
names = [g.name for g in tmp.vertex_groups]
for n in names: mesh.vertex_groups.new(name=n)
for n in LATE:
    arm.bones[n].use_deform = True
    if n not in names: mesh.vertex_groups.new(name=n)
for n in [b.name for b in arm.bones if b.use_deform]:
    if n not in mesh.vertex_groups: mesh.vertex_groups.new(name=n)
def plate(v, w):
    """The shoulder plates are armour: each moves as one piece on its own bone."""
    for side, out in (("R", -(v.co.x + 0.05)), ("L", v.co.x + 0.05)):      # out: metres from the body's middle
        arm_w = w.get(f"shoulder.{side}", 0) + w.get(f"upper_arm.{side}", 0)
        tall = v.co.z > 1.47 or (v.co.z > 1.36 and out > 0.45)
        if out > 0.17 and tall and arm_w > (0.3 if out > 0.25 else 0.5):
            return {f"pauldron.{side}": 1.0}
    return w
RIGID = {"shield": 0.4, "sword": 0.4, "head": 0.5}
# What the cut left of a loose part on the body (a strap, a sliver of its rim) still belongs to that part.
part_kd = {}
for pname, bone in PART_BONE.items():
    tree = kdtree.KDTree(len(parts[pname].data.vertices))
    for pv in parts[pname].data.vertices: tree.insert(pv.co, pv.index)
    tree.balance(); part_kd[bone] = tree
SEG = {n: (Vector(h), Vector(tl)) for n, h, tl, _, _ in B}
def off_bone(co, n):
    """Metres from a point to a bone's line (a little past its tip)."""
    h, tl = SEG[n]; ax = tl - h; ln = ax.length; ax /= ln
    s = max(0.0, min(ln + 0.06, (co - h).dot(ax)))
    return (co - (h + ax * s)).length
picked = {"R": set(), "L": set()}
allowed = {"R": set(), "L": set()}     # where a plate may reach at all: off the cloak, beside the body, shoulder high
for v in mesh.data.vertices:
    _, idx, _ = kd.find(v.co)
    w = {names[g.group]: g.weight for g in tmp.data.vertices[idx].groups if g.weight > 0.01}
    for n, th in RIGID.items():
        if w.get(n, 0) >= th: w = {n: 1.0}
    # The cloak hangs right behind the arms: cloth back there that the automatic pass gave to an arm goes to the
    # cloak's own bones, by height and side.
    # So does cloth that hangs beside a forearm or below a hand, further out than the arm's own armour.
    if v.co.z < 1.35:
        k = 1 if v.co.z > 1.06 else (2 if v.co.z > 0.56 else 3)
        sd = "R" if v.co.x < -0.25 else ("L" if v.co.x > 0.2 else "M")
        for n in list(w):
            limb = n.split(".")[0]
            behind = v.co.y > 0.02 and limb in ("upper_arm", "forearm", "hand")
            loose = limb in ("forearm", "hand") and off_bone(v.co, n) > 0.14
            if behind or loose:
                w[f"cape{k}.{sd}"] = w.get(f"cape{k}.{sd}", 0.0) + w.pop(n)
    for bone, tree in part_kd.items():
        if bone != "sword" and tree.find(v.co)[2] < 0.03: w = {bone: 1.0}
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
# The sword's part was cut out with scraps of the cloak that hung beside it: only the pieces on the blade's own line
# are the sword. A scrap takes the weights of the body's nearest point, so it hangs with the cloak again.
body_kd = kdtree.KDTree(len(mesh.data.vertices))
for bv in mesh.data.vertices: body_kd.insert(bv.co, bv.index)
body_kd.balance()
gname = {g.index: g.name for g in mesh.vertex_groups}
scraps = 0
for pname, bone in PART_BONE.items():
    o = parts[pname]
    for n in gname.values(): o.vertex_groups.new(name=n)
    if bone != "sword":
        o.vertex_groups[bone].add(list(range(len(o.data.vertices))), 1.0, 'REPLACE'); continue
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(o.data); bm.free()
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    seen = set()
    for v0 in bm.verts:
        if v0.index in seen: continue
        comp = [v0]; seen.add(v0.index); i = 0
        while i < len(comp):
            for e in comp[i].link_edges:
                u = e.other_vert(comp[i])
                if u.index not in seen: seen.add(u.index); comp.append(u)
            i += 1
        centre = sum((u.co for u in comp), Vector()) / len(comp)
        if off_bone(centre, "sword") < 0.12:
            o.vertex_groups[bone].add([u.index for u in comp], 1.0, 'REPLACE')
        else:
            scraps += len(comp)
            for u in comp:
                src = mesh.data.vertices[body_kd.find(u.co)[1]]
                for g in src.groups: o.vertex_groups[gname[g.group]].add([u.index], g.weight, 'REPLACE')
    bm.free()
print("SCRAPS", scraps)
bpy.ops.object.select_all(action='DESELECT')
for o in parts.values(): o.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.join()
mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig

cnt = {}
for v in mesh.data.vertices:
    if v.groups:
        g = max(v.groups, key=lambda g: g.weight); n = mesh.vertex_groups[g.group].name; cnt[n] = cnt.get(n, 0) + 1
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"unweighted_welded": unweighted, "plates": plate_report, "verts": len(mesh.data.vertices), "tris": sum(len(p.vertices) - 2 for p in mesh.data.polygons)})
