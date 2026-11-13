"""src.blend -> rig.blend. The delivered skeleton stays: its 41 bones, their names, their rest pose and the weights of
the body. Added: a bone each for the spear, the shield and the two shoulder plates (rigid pieces), three chains for the
cloak, a chain for the cloth at the front and one for the helm's crest. The pieces are picked by rule (parts.py)."""
import bpy, sys, os
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, parts, cutparts
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
rig = zdlib.the_rig(); arm = rig.data
mesh = [o for o in bpy.data.objects if o.type == 'MESH'][0]; me = mesh.data
delivered = [b.name for b in arm.bones]

def on_axis(z): return parts.SP_A + parts.SP_D * ((z - parts.SP_A.z) / parts.SP_D.z)
CAPE_Y = {"L": 0.13, "M": 0.0, "R": -0.13}
CAPE_Z = [0.56, 0.40, 0.24, 0.07]
TAB_Z = [0.38, 0.22, 0.07]
PLUME = [(-0.01, 0.0, 0.735), (-0.035, 0.0, 0.84), (-0.06, 0.0, 0.94)]
# name: (head, tail, parent)
NEW = [
    ("Spear", on_axis(0.44), on_axis(0.74), "R_Hand"),
    ("Shield", (0.015, 0.215, 0.30), (0.015, 0.215, 0.50), "L_Hand"),          # it turns on the fist that holds it
    ("L_Pauldron", tuple(arm.bones["L_Upperarm"].head_local), (0.0, 0.24, 0.66), "L_Upperarm"),
    ("R_Pauldron", tuple(arm.bones["R_Upperarm"].head_local), (-0.03, -0.24, 0.66), "R_Upperarm"),
    ("Tabard01", (0.09, 0.0, TAB_Z[0]), (0.10, 0.0, TAB_Z[1]), "Pelvis"),
    ("Tabard02", (0.10, 0.0, TAB_Z[1]), (0.10, 0.0, TAB_Z[2]), "Tabard01"),
    ("Plume01", PLUME[0], PLUME[1], "Head"),
    ("Plume02", PLUME[1], PLUME[2], "Plume01"),
]
for side, y in CAPE_Y.items():
    for k in range(3):
        x0 = -0.15 - 0.012 * k; x1 = -0.15 - 0.012 * (k + 1)
        NEW.append((f"Cape{k+1:02d}_{side}", (x0, y * (1 + 0.15 * k), CAPE_Z[k]), (x1, y * (1 + 0.15 * (k + 1)), CAPE_Z[k + 1]),
                    "Spine02" if k == 0 else f"Cape{k:02d}_{side}"))

bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in NEW:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.parent = arm.edit_bones[par]; eb.use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')
for name, *_ in NEW: mesh.vertex_groups.new(name=name)
gi = {g.name: g.index for g in mesh.vertex_groups}

def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def chain(z, zs, names, top):
    """Weights down a hanging chain: `top` above zs[0], then each link takes over across its joint."""
    w = {}
    f = smooth((zs[0] + 0.02 - z) / 0.08)          # from the body onto the first link
    for n, x in top.items(): w[n] = x * (1 - f)
    rem = f
    for k in range(1, len(names)):
        g = smooth((zs[k] + 0.04 - z) / 0.08)      # from link k-1 onto link k
        w[names[k - 1]] = w.get(names[k - 1], 0) + rem * (1 - g); rem *= g
    w[names[-1]] = w.get(names[-1], 0) + rem
    return w

def cape_w(co):
    x, y, z = co
    cols = {}
    for side, cy in CAPE_Y.items():
        cols[side] = max(0.0, 1 - abs(y - cy) / 0.13)
    if y > 0.13: cols = {"L": 1.0}
    if y < -0.13: cols = {"R": 1.0}
    w = {}
    for side, cw in cols.items():
        if cw <= 0: continue
        for n, x_ in chain(z, CAPE_Z, [f"Cape{k:02d}_{side}" for k in (1, 2, 3)], {"Spine02": 1.0}).items():
            w[n] = w.get(n, 0) + x_ * cw
    return w

cls, red = parts.classify(mesh)
old = [{mesh.vertex_groups[g.group].name: g.weight for g in v.groups} for v in me.vertices]
count = {}
PIECE = {"spear": "Spear", "shield": "Shield", "pauldron_L": "L_Pauldron", "pauldron_R": "R_Pauldron"}
pieces = {b: set() for b in PIECE.values()}
for v in me.vertices:
    c = cls[v.index]; x, y, z = v.co; w = None
    if c in PIECE: pieces[PIECE[c]].add(v.index); count[c] = count.get(c, 0) + 1; continue
    if c == "plume":
        f = smooth((z - 0.735) / 0.04); g = smooth((z - 0.81) / 0.06)
        w = {"Head": 1 - f, "Plume01": f * (1 - g), "Plume02": f * g}
    elif c == 'tabard':
        w = chain(z, TAB_Z, ["Tabard01", "Tabard02"], old[v.index])
    elif c == 'cape':
        w = cape_w(v.co)
    if w is None: continue
    count[c] = count.get(c, 0) + 1
    for g in mesh.vertex_groups: g.remove([v.index])
    top = sorted(((n, x) for n, x in w.items() if x > 0.004), key=lambda kv: -kv[1])[:4]
    s = sum(x for _, x in top)
    for n, x in top: mesh.vertex_groups[n].add([v.index], x / s, 'REPLACE')

# The rigid pieces leave the shell: each becomes its own closed piece on its own bone. Behind a shoulder plate the
# body's side of the cut is the cloak, so it takes the cloak's weights (the arm must not drag the cloak).
def pkey(co): return (round(co[0], 4), round(co[1], 4), round(co[2], 4))
by_cloak = set()                 # points that share an edge with the cloak
for e in me.edges:
    a, b = e.vertices
    if cls[a] == 'cape': by_cloak.add(pkey(me.vertices[b].co))
    if cls[b] == 'cape': by_cloak.add(pkey(me.vertices[a].co))
def body_rim(bone, co, w):
    if bone.endswith("Pauldron") and pkey(co) in by_cloak:
        return {n: x for n, x in cape_w(co).items() if x > 0.004}
    return None
cut_report = cutparts.cut(mesh, pieces, body_rim, parts.dark_uv(me))

# Where the shell fuses the cloth to a leg or an arm, the joining faces would pull into long slivers when the limb lifts: they
# go. They sit in the crease between the two.
import bmesh
gn = {g.index: g.name for g in mesh.vertex_groups}
dom = [gn[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in me.vertices]
def cloth(i): return dom[i].startswith(("Cape", "Tabard")) or (i < len(cls) and cls[i] in ("cape", "tabard"))
def leg(n): return any(k in n for k in ("Thigh", "Calf", "Foot", "Toe", "Upperarm", "Forearm", "Hand"))
bm = bmesh.new(); bm.from_mesh(me)
kill = [f for f in bm.faces if any(cloth(v.index) for v in f.verts) and any(leg(dom[v.index]) for v in f.verts)]
# The same for the scraps the shell left hanging off the shaft away from the fist (they were weighted to the foot
# beside the butt, or to the arm behind the shaft).
kill += [f for f in bm.faces if any(dom[v.index] != "Spear" for v in f.verts)
         and any(v.co.z > 0.028 and not (0.38 < v.co.z < 0.52) and parts.rule(v.co, False, 0.0) == "spear" for v in f.verts)]
# And where the hanging cloth is fused to the hips behind it, below the line it hangs from.
def torso(n): return n in ("Waist", "Pelvis", "Hip", "Spine01")
kill += [f for f in bm.faces if any(torso(dom[v.index]) for v in f.verts) and (
    (any(dom[v.index].startswith("Tabard") for v in f.verts) and f.calc_center_median().z < 0.33) or
    (any(dom[v.index].startswith("Cape") for v in f.verts) and f.calc_center_median().z < 0.42))]
kill = list(set(kill))
cut_faces = len(kill)
bmesh.ops.delete(bm, geom=kill, context='FACES')
bm.to_mesh(me); bm.free(); me.update()

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"cut": cut_report, "cloth_leg_faces_removed": cut_faces, "delivered_bones": len(delivered), "bones": len(arm.bones),
            "added": [n for n, *_ in NEW],
            "reweighted": count, "verts": len(me.vertices), "tris": sum(len(p.vertices) - 2 for p in me.polygons)})
