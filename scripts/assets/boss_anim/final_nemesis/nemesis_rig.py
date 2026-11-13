"""src.blend -> rig.blend: the Nemesis's skeleton and skin.

The delivered mesh is one fused shell 0.19 units tall facing +X. It is worked on 1.5 m tall facing -Y (WORK below) and
put back by export.py. The figure has no arms: a hood, three shoulder capes and a skirt cape (a hollow shell), two long
front panels hanging from the shoulders, hip tabs, two legs. The front panels are skinned as the arms (sleeves).
Weights are set by rule from where a vertex is, not by the automatic pass: the shell has no inside for it to read.
"""
import bpy, sys, os, bmesh, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
K = 1.5 / 0.19
WORK = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)

mesh = [x for x in bpy.data.objects if x.type == 'MESH'][0]
for o in list(bpy.data.objects):
    if o != mesh: bpy.data.objects.remove(o)
mesh.data.transform(mesh.matrix_world); mesh.matrix_world.identity()
mesh.data.transform(WORK)
tris0 = sum(len(p.vertices) - 2 for p in mesh.data.polygons)

# ---- the legs: two columns under the shell
LX = 0.19            # a leg's axis, metres either side of the middle
LY = -0.01
HIP_Z, KNEE_Z, ANKLE_Z = 0.50, 0.275, 0.085
def leg_dist(co): return math.hypot(abs(co.x) - LX, co.y - LY)
def is_leg(co):
    if co.z < 0.16: return abs(abs(co.x) - LX) < 0.12 and -0.2 < co.y < 0.16       # the boot
    return co.z < 0.50 and leg_dist(co) < 0.118 and co.y > -0.150

# A knee needs a ring of vertices above and below it; the delivered columns have none between the boot and the knee.
bm = bmesh.new(); bm.from_mesh(mesh.data)
added = 0
for zc in (0.20,):
    geom = [e for e in bm.edges if is_leg(e.verts[0].co) and is_leg(e.verts[1].co) and (e.verts[0].co.z - zc) * (e.verts[1].co.z - zc) < 0]
    geom += list({f for e in geom for f in e.link_faces})
    r = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, zc), plane_no=(0, 0, 1), dist=0.0005)
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
bm.to_mesh(mesh.data); bm.free()
tris1 = sum(len(p.vertices) - 2 for p in mesh.data.polygons)

# ---- bones: name, head, tail, parent, deform.  The figure faces -Y; its right is -X.
B = [
 ("root",   (0, 0, 0),          (0, 0.25, 0),       None, False),
 ("hips",   (0, 0.0, 0.50),     (0, 0.0, 0.62),     "root", True),
 ("spine",  (0, 0.0, 0.62),     (0, 0.0, 0.76),     "hips", True),
 ("chest",  (0, 0.0, 0.76),     (0, 0.0, 0.93),     "spine", True),
 ("neck",   (0, 0.0, 0.93),     (0, -0.01, 1.01),   "chest", True),
 ("head",   (0, -0.01, 1.01),   (0, -0.01, 1.42),   "neck", True),
]
for sd, sx in (("R", -1), ("L", 1)):
    B += [
     (f"shoulder.{sd}",  (sx * 0.07, -0.08, 0.93),  (sx * 0.19, -0.19, 0.92),  "chest", True),
     (f"upper_arm.{sd}", (sx * 0.19, -0.19, 0.92),  (sx * 0.20, -0.255, 0.73), f"shoulder.{sd}", True),
     (f"forearm.{sd}",   (sx * 0.20, -0.255, 0.73), (sx * 0.20, -0.275, 0.585), f"upper_arm.{sd}", True),
     (f"hand.{sd}",      (sx * 0.20, -0.275, 0.585), (sx * 0.20, -0.280, 0.505), f"forearm.{sd}", True),
     (f"thigh.{sd}",     (sx * LX, LY, HIP_Z),      (sx * LX, LY - 0.012, KNEE_Z), "hips", True),
     (f"shin.{sd}",      (sx * LX, LY - 0.012, KNEE_Z), (sx * LX, LY + 0.02, ANKLE_Z), f"thigh.{sd}", True),
     (f"foot.{sd}",      (sx * LX, LY + 0.02, ANKLE_Z), (sx * LX, -0.085, 0.03), f"shin.{sd}", True),
     (f"toe.{sd}",       (sx * LX, -0.085, 0.03),   (sx * LX, -0.15, 0.03),   f"foot.{sd}", True),
     (f"tab.{sd}",       (sx * 0.17, -0.19, 0.50),  (sx * 0.17, -0.22, 0.27), "hips", True),
    ]
# The cloak: a chain down each side (left, right, back), one bone a layer: the three shoulder capes, then the skirt.
LAYER_Z = [1.00, 0.87, 0.71, 0.51, 0.30]          # the top of cape 1, then each hem
RAD = {"L": [0.20, 0.31, 0.40, 0.49, 0.60], "R": [0.20, 0.31, 0.40, 0.49, 0.60], "B": [0.18, 0.30, 0.33, 0.36, 0.43],
       "FL": [0.20, 0.30, 0.32, 0.36, 0.44], "FR": [0.20, 0.30, 0.32, 0.36, 0.44]}
DIR = {"L": Vector((1, 0, 0)), "R": Vector((-1, 0, 0)), "B": Vector((0, 1, 0)),
       "FL": Vector((0.5, -0.866, 0)), "FR": Vector((-0.5, -0.866, 0))}
for sd in ("L", "R", "B", "FL", "FR"):
    for k in range(4):
        h = DIR[sd] * RAD[sd][k] + Vector((0, 0, LAYER_Z[k])); t = DIR[sd] * RAD[sd][k + 1] + Vector((0, 0, LAYER_Z[k + 1]))
        B.append((f"cloak{k + 1}.{sd}", tuple(h), tuple(t), "chest" if k == 0 else f"cloak{k}.{sd}", True))

arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par, deform in B:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.use_deform = deform
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

# ---- the skin, by rule
def sm(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)
def mix(w, share, other):
    """Give `share` of everything in w to the table `other`."""
    out = {n: x * (1 - share) for n, x in w.items()}
    for n, x in other.items(): out[n] = out.get(n, 0) + x * share
    return out
def torso(z):
    a = sm(0.57, 0.66, z); b = sm(0.72, 0.80, z); c = sm(0.93, 1.01, z)
    return {"hips": 1 - a, "spine": a * (1 - b), "chest": b * (1 - c), "head": c}
def cloak(co):
    phi = math.degrees(math.atan2(co.y, abs(co.x)))       # -90 = ahead, 0 = out to the side, 90 = behind
    wf = 1 - sm(-45, -15, phi); wb = sm(28, 62, phi); ws = 1 - wf - wb
    left = sm(-0.04, 0.04, co.x) if phi > 0 else (1.0 if co.x > 0 else 0.0)
    z = co.z; e = 0.012
    k1 = sm(0.87 - e, 0.87 + e, z); k2 = sm(0.71 - e, 0.71 + e, z); k3 = sm(0.51 - e, 0.51 + e, z)
    lay = [k1, (1 - k1) * k2, (1 - k2) * k3, 1 - k3]
    w = {}
    for sd, x in (("FL", wf * left), ("FR", wf * (1 - left)), ("L", ws * left), ("R", ws * (1 - left)), ("B", wb)):
        for k in range(4):
            if x * lay[k] > 0: w[f"cloak{k + 1}.{sd}"] = x * lay[k]
    return w
def leg(co, sd):
    z = co.z
    if z < 0.16 and co.y < -0.02 and z < 0.11:            # the boot's front
        t = sm(-0.105, -0.065, co.y)
        w = {f"toe.{sd}": 1 - t, f"foot.{sd}": t}
    else:
        a = sm(ANKLE_Z + 0.02, ANKLE_Z + 0.075, z)        # foot -> shin
        b = sm(KNEE_Z - 0.06, KNEE_Z + 0.06, z)           # shin -> thigh
        c = sm(0.43, 0.52, z)                             # thigh -> hips
        w = {f"foot.{sd}": 1 - a, f"shin.{sd}": a * (1 - b), f"thigh.{sd}": b * (1 - c), "hips": c}
    return w
def sleeve(co, sd):
    """There are no arms: each cape runs round to the open front. The capes' front quarter on a side is that side's
    sleeve: it follows the arm most where the arm hangs under it and less and less towards the side and the middle."""
    z = co.z; phi = math.degrees(math.atan2(co.y, abs(co.x)))          # -90 = ahead, 0 = out to the side
    amt = (1 - sm(10, 68, abs(phi + 55))) * sm(0.045, 0.13, abs(co.x)) * (1 - sm(0.88, 0.99, z)) * sm(0.36, 0.50, z)
    a = sm(0.585, 0.63, z); b = sm(0.69, 0.80, z); c = sm(0.84, 0.96, z)
    # the hand bone carries the weapon and turns freely with it, so no cloth hangs on it
    return 0.8 * amt, {f"forearm.{sd}": 1 - b, f"upper_arm.{sd}": b * (1 - c), f"shoulder.{sd}": c}
kind = {}
W = {}; KD = {}
for v in mesh.data.vertices:
    co = v.co; sd = "L" if co.x > 0 else "R"; ax = abs(co.x); r = math.hypot(co.x, co.y)
    if co.z >= 1.02:
        w = {"head": 1.0}; kd = "head"
    elif is_leg(co):
        w = leg(co, sd); kd = "leg"
    elif co.y < -0.13 and r < 0.42 and (co.z < 0.50 and ax < 0.345 or co.z < 0.53 and ax < 0.30 and co.y > -0.20):
        s_ = sm(-0.03, 0.03, co.x)
        w = mix({"tab.L": s_, "tab.R": 1 - s_}, max(sm(0.33, 0.52, co.z), sm(-0.20, -0.13, co.y)), {"hips": 1.0}); kd = "tab"
    elif co.z < 0.50 and r < 0.34 or r < 0.20 and co.z < 0.56:
        w = {"hips": 1.0}; kd = "hips"
    elif co.y < -0.15 and ax <= 0.065 and co.z < 1.02:
        w = torso(co.z); kd = "front"
    else:
        w = cloak(co); kd = "cloak"
        inner = 1 - sm(0.13, 0.22, r)                    # what is near the axis belongs to the body
        if inner > 0: w = mix(w, inner, torso(co.z))
        hood = sm(0.96, 1.02, co.z)                      # the hood's brim rides the head
        amt, aw = sleeve(co, sd)
        if amt > 0: w = mix(w, amt, aw); kd = "sleeve" if amt > 0.4 else kd
        if hood > 0: w = mix(w, hood, {"head": 1.0})
    kind[kd] = kind.get(kd, 0) + 1
    W[v.index] = w; KD[v.index] = kd
# The shell is closed underneath (the skirt's hem joins an inner floor) and the capes run into each other: a rule's
# edge would tear there. So the weights are evened out along the mesh's edges, between vertices at the same place
# (the file splits them along texture seams) as one. The hood and the legs stay as the rules set them.
def key(co): return (round(co.x, 4), round(co.y, 4), round(co.z, 4))
at = {}
for v in mesh.data.vertices: at.setdefault(key(v.co), []).append(v.index)
kw = {k: W[ids[0]] for k, ids in at.items()}
fixed = {k for k, ids in at.items() if KD[ids[0]] in ("head", "leg")}
nb = {k: set() for k in at}
for e in mesh.data.edges:
    a = key(mesh.data.vertices[e.vertices[0]].co); b = key(mesh.data.vertices[e.vertices[1]].co)
    if a != b: nb[a].add(b); nb[b].add(a)
for it in range(5):
    new = {}
    for k, w in kw.items():
        if k in fixed or not nb[k]: new[k] = w; continue
        acc = {}
        for o in nb[k]:
            for n, x in kw[o].items(): acc[n] = acc.get(n, 0) + x / len(nb[k])
        new[k] = {n: 0.45 * w.get(n, 0) + 0.55 * acc.get(n, 0) for n in set(w) | set(acc)}
    kw = new
for k, ids in at.items():
    top = sorted(((n, x) for n, x in kw[k].items() if x > 0.01), key=lambda kv: -kv[1])[:4]
    s_ = sum(x for _, x in top)
    for n, x in top:
        g = mesh.vertex_groups.get(n) or mesh.vertex_groups.new(name=n)
        g.add(ids, x / s_, 'REPLACE')
for b in arm.bones:
    if b.use_deform and mesh.vertex_groups.get(b.name) is None: mesh.vertex_groups.new(name=b.name)
mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"kinds": kind, "verts": len(mesh.data.vertices), "tris_delivered": tris0, "tris": tris1, "bones": len(arm.bones)})
