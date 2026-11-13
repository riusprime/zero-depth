"""src.blend -> rig.blend: the Clockwork Judge's skeleton and skin.

The delivered model is a fused shell cut into six parts by position. It is a machine, so almost every vertex is rigid
on one bone; the regions are picked by position and by flooding the welded mesh inside a box (a piece that hangs free
below a height is found by where it is still connected). Only three places blend: the coat between the pelvis and the
chest, the hanging tails, and the legs' rods, which telescope (the model has a hip and an ankle and no knee)."""
import bpy, sys, os, bmesh, math
from mathutils import Vector, kdtree
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

PARTS = ("Body", "ArmL", "ArmR", "Gears", "HandHour", "HandMinute")
parts = {}
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name in PARTS:
        mw = o.matrix_world.copy(); o.parent = None
        o.data.transform(mw); o.matrix_world.identity()
        o.modifiers.clear(); o.vertex_groups.clear()
        parts[o.name] = o
for o in list(bpy.data.objects):
    if o not in parts.values(): bpy.data.objects.remove(o)

# ---------------------------------------------------------------- the bones
# The model faces -Y; its left side is +X. Measured on gridded renders and on the vertices' bounds by height.
HIP = Vector((0.40, -0.03, 1.05)); ANKLE = Vector((0.515, 0.09, 0.38)); KNEE = (HIP + ANKLE) / 2
SHOULDER = Vector((0.80, 0.03, 2.60)); ELBOW = Vector((0.92, 0.10, 1.90)); WRIST = Vector((0.98, 0.0, 1.43))
GAVEL_TIP = Vector((1.035, -0.045, 0.37))
GEAR_C = Vector((0.0, -0.36, 1.41)); GEAR_R = 0.168
CLOCK = Vector((0.0, -0.50, 2.322))
WAIST = (1.60, 1.88)          # the coat bends between these heights
def mx(v, s): return Vector((v.x * s, v.y, v.z))
B = [  # name, head, tail, parent, deform
 ("root",   (0, 0, 0),        (0, 0.3, 0),      None,    False),
 ("body",   (0, 0, 1.25),     (0, 0, 1.60),     "root",  True),
 ("chest",  (0, 0, 1.75),     (0, 0, 2.50),     "body",  True),
 ("head",   (0, -0.06, 3.03), (0, -0.06, 3.50), "chest", True),
 ("pendulum", (0, -0.39, 2.04), (0, -0.39, 1.03), "chest", True),
 ("hand_hour", CLOCK, CLOCK + Vector((-0.20, 0, 0.23)), "chest", True),
 ("hand_minute", CLOCK, CLOCK + Vector((0.21, 0, 0.25)), "chest", True),
 ("gear",   GEAR_C,           GEAR_C + Vector((0, 0.2, 0)), "body", True),
 ("apron",  (0, -0.36, 1.22), (0, -0.36, 0.63), "body",  True),
]
for sfx, s in ((".L", 1), (".R", -1)):
    B += [
     ("pauldron" + sfx, (0.46 * s, 0, 2.90), (0.90 * s, 0, 2.80), "chest", True),
     ("fin" + sfx, (0.59 * s, 0.38, 2.25), (0.59 * s, 0.40, 1.08), "chest", True),
     ("upper_arm" + sfx, mx(SHOULDER, s), mx(ELBOW, s), "chest", True),
     ("forearm" + sfx, mx(ELBOW, s), mx(WRIST, s), "upper_arm" + sfx, True),
     ("gavel" + sfx, mx(WRIST, s), mx(GAVEL_TIP, s), "forearm" + sfx, True),
     ("thigh" + sfx, mx(HIP, s), mx(KNEE, s), "body", True),
     ("shin" + sfx, mx(KNEE, s), mx(ANKLE, s), "thigh" + sfx, True),
     ("foot" + sfx, mx(ANKLE, s), (0.53 * s, -0.30, 0.06), "shin" + sfx, True),
     ("tail1" + sfx, (0.27 * s, 0.38, 1.25), (0.27 * s, 0.40, 0.75), "body", True),
     ("tail2" + sfx, (0.27 * s, 0.40, 0.75), (0.27 * s, 0.40, 0.25), "tail1" + sfx, True),
    ]
arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par, deform in B:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.use_deform = deform
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- picking regions
def welded(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.verts.ensure_lookup_table()
    return bm
def flood(bm, inside, seed):
    """The welded vertices connected, without leaving `inside`, to a vertex of `seed`."""
    got = set(); st = [v for v in bm.verts if inside(v.co) and seed(v.co)]
    for v in st: got.add(v.index)
    while st:
        u = st.pop()
        for e in u.link_edges:
            w = e.other_vert(u)
            if w.index not in got and inside(w.co): got.add(w.index); st.append(w)
    return got
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def waist(z):
    t = smooth((z - WAIST[0]) / (WAIST[1] - WAIST[0]))
    return {"body": 1.0} if t <= 0 else ({"chest": 1.0} if t >= 1 else {"body": 1 - t, "chest": t})

body = parts["Body"]; bm = welded(body)
W = {}           # welded vertex index -> {bone: weight}
count = {}
CUTS = []        # the pieces that move as machine parts: each is cut free of what it touches, so nothing is dragged
DROP = set()
def give(ids, fn):
    for i in ids:
        if i not in W:
            w = fn(bm.verts[i].co) if callable(fn) else {fn: 1.0}
            W[i] = w
            for n in w: count[n] = count.get(n, 0) + 1
for sfx, s in ((".L", 1), (".R", -1)):
    side = lambda p, s=s: p.x * s > 0
    # A leg and its foot: what is still joined to the sole below the hip's ball. The rods between the two balls
    # shorten and lengthen: their ends follow the thigh and the shin, which slides along the leg.
    leg = flood(bm, lambda p: side(p) and p.z < 0.90, lambda p: p.z < 0.03)
    hip = mx(HIP, s) + Vector((0.01 * s, -0.01, -0.02))
    ball = {v.index for v in bm.verts if side(v.co) and (v.co - hip).length < 0.155 and v.co.z < 1.17}
    def leg_w(p, sfx=sfx):
        if p.z < 0.295: return {"foot" + sfx: 1.0}
        t = (0.86 - p.z) / (0.86 - 0.50)
        if t <= 0: return {"thigh" + sfx: 1.0}
        if t >= 1: return {"shin" + sfx: 1.0}
        return {"thigh" + sfx: 1 - t, "shin" + sfx: t}
    give(leg | ball, leg_w)
    foot = {i for i in leg if bm.verts[i].co.z < 0.295}
    CUTS.append(foot); CUTS.append((leg | ball) - foot)
    # A coat tail at the back: free below the pelvis, bending in two places.
    tail = flood(bm, lambda p: side(p) and p.z < 1.30 and p.y > 0.2 and abs(p.x) < 0.5, lambda p: p.z < 0.5 and p.z > 0.24)
    def tail_w(p, sfx=sfx):
        a = smooth((1.30 - p.z) / 0.16); b = smooth((0.84 - p.z) / 0.18)
        w = {"body": 1 - a, "tail1" + sfx: a * (1 - b), "tail2" + sfx: a * b}
        return {n: x for n, x in w.items() if x > 0.001}
    give(tail, tail_w)
    # The upper arm: the rod from the shoulder's ball and the inner half of the elbow's block (the cut left the outer
    # half on the arm's part). The scraps of the gavel's ring the cut left on the body go to the gavel.
    up = flood(bm, lambda p: p.x * s > 0.70 and -0.12 < p.y < 0.30 and 1.3 < p.z < 2.52, lambda p: 1.8 < p.z < 2.0)
    sh = mx(SHOULDER, s)
    up |= {v.index for v in bm.verts if (v.co - sh).length < 0.105}
    # The slivers of the forearm's rods the cut left hanging under the elbow are removed: they would stick out of
    # a bent elbow as spikes.
    low = {i for i in up if bm.verts[i].co.z < 1.69}; DROP |= low; up -= low; CUTS.append(set(up))
    give(up, "upper_arm" + sfx)
    ring = {v.index for v in bm.verts if v.co.x * s > 0.78 and 1.15 < v.co.z < 1.46 and -0.25 < v.co.y < 0.2}
    give(ring, "gavel" + sfx)
    # The long fin that hangs behind the shoulder, then the shoulder's armour itself.
    fin = flood(bm, lambda p: 0.5 < p.x * s < 0.72 and p.y > 0.15 and 1.0 < p.z < 2.30, lambda p: p.z < 1.5)
    def fin_w(p, sfx=sfx):
        a = smooth((2.30 - p.z) / 0.12)
        return {"fin" + sfx: 1.0} if a >= 1 else {"pauldron" + sfx: 1 - a, "fin" + sfx: a}
    give(fin, fin_w)
    CUTS.append({i for i in fin if bm.verts[i].co.z < 2.17})
    give({v.index for v in bm.verts if v.co.x * s > 0.47 and v.co.z > 2.2}, "pauldron" + sfx)
head = flood(bm, lambda p: abs(p.x) < 0.21 and -0.28 < p.y < 0.15 and p.z > 2.99, lambda p: p.z > 3.3)
give(head, "head"); CUTS.append(head)
apron = flood(bm, lambda p: abs(p.x) < 0.34 and p.y < -0.24 and p.z < 1.24, lambda p: p.z < 0.7)
def apron_w(p):
    a = smooth((1.24 - p.z) / 0.10)
    return {"apron": 1.0} if a >= 1 else {"body": 1 - a, "apron": a}
give(apron, apron_w)
give([v.index for v in bm.verts], lambda p: waist(p.z))

def put(o, weights_of):
    names = [b[0] for b in B if b[4]]
    for n in names:
        if n not in o.vertex_groups: o.vertex_groups.new(name=n)
    for v in o.data.vertices:
        for n, x in weights_of(v).items(): o.vertex_groups[n].add([v.index], x, 'REPLACE')
kd = kdtree.KDTree(len(bm.verts))
for v in bm.verts: kd.insert(v.co, v.index)
kd.balance()
def body_w(co): return W[kd.find(co)[1]]
def skin(o, wid, w_of, cuts, drop=()):
    """Weigh a part. wid(co) is a vertex's welded index and w_of(index) its weights. Every set in `cuts` becomes a
    piece of its own: the faces wholly inside it get their own copy of the vertices on its edge. A face that straddles
    an edge stays whole on the other side (its corners inside the piece take the weights of a corner outside it), so
    no face is ever stretched between a moving piece and what it sits on."""
    b = bmesh.new(); b.from_mesh(o.data)
    if drop: bmesh.ops.delete(b, geom=[v for v in b.verts if wid(v.co) in drop], context='VERTS')
    def piece(ids):
        for k, S in enumerate(cuts):
            if all(i in S for i in ids): return k
        return -1
    groups = {}
    for f in b.faces: groups.setdefault(piece([wid(v.co) for v in f.verts]), []).append(f)
    for k, faces in groups.items():
        if k >= 0: bmesh.ops.split(b, geom=faces)
    b.to_mesh(o.data); b.free()
    me = o.data; inside = set().union(*cuts) if cuts else set(); vw = {}
    for poly in me.polygons:
        ids = [wid(me.vertices[i].co) for i in poly.vertices]
        if piece(ids) >= 0:
            for i, w in zip(poly.vertices, ids): vw[i] = w_of(w)
            continue
        free = [w for w in ids if w not in inside]
        anchor = free[0] if free else max(zip(poly.vertices, ids), key=lambda t: me.vertices[t[0]].co.z)[1]
        for i, w in zip(poly.vertices, ids): vw[i] = w_of(anchor if w in inside else w)
    put(o, lambda v: vw.get(v.index) or w_of(wid(v.co)))
skin(body, lambda co: kd.find(co)[1], lambda i: W[i], CUTS, DROP)

# ---------------------------------------------------------------- the arms' parts
# The outer half of the elbow's block and the two rods are the forearm; the collar, the ring and the gavel are the
# gavel. The few loose scraps of coat the cut took with the arm follow the body's nearest point.
scraps = 0
for pname, sfx, s in (("ArmL", ".L", 1), ("ArmR", ".R", -1)):
    o = parts[pname]; ab = welded(o)
    main = flood(ab, lambda p: True, lambda p: 0.7 < p.z < 0.9 and p.x * s > 1.0)
    akd = kdtree.KDTree(len(ab.verts))
    for v in ab.verts: akd.insert(v.co, v.index)
    akd.balance()
    AW = {}
    for v in ab.verts:
        if v.index not in main: scraps += 1; AW[v.index] = body_w(v.co)
        else: AW[v.index] = {"forearm" + sfx: 1.0} if v.co.z > 1.46 else {"gavel" + sfx: 1.0}
    gav = {v.index for v in ab.verts if v.index in main and v.co.z <= 1.46}
    skin(o, lambda co: akd.find(co)[1], lambda i: AW[i], [gav]); ab.free()

# ---------------------------------------------------------------- the gear column
# The slab cut from the front of the coat: the rod with the two arrow heads is the pendulum, the round disc behind it
# a gear that turns on its own axis; both are cut free of the slab so they can move without dragging it. The rest
# (rails, the worn shapes behind) bends with the coat.
g = parts["Gears"]; gb = bmesh.new(); gb.from_mesh(g.data); gb.verts.ensure_lookup_table()
gw = welded(g)
pend_w = flood(gw, lambda p: abs(p.x) < 0.10 and p.y < -0.355, lambda p: True)
gkd = kdtree.KDTree(len(gw.verts))
for v in gw.verts: gkd.insert(v.co, v.index)
gkd.balance()
def is_pend(co): return gkd.find(co)[1] in pend_w
def is_gear(co):
    r = math.hypot(co.x - GEAR_C.x, co.z - GEAR_C.z)
    return r < GEAR_R and -0.365 < co.y < -0.20 and not is_pend(co)
def cut_free(test):
    """Give the faces whose corners all pass `test` their own copy of the vertices on the seam."""
    faces = [f for f in gb.faces if all(test(v.co) for v in f.verts)]
    ret = bmesh.ops.split(gb, geom=faces)
    return [x for x in ret["geom"] if isinstance(x, bmesh.types.BMFace)]
pend_f = cut_free(is_pend)
gear_f = cut_free(is_gear)
gb.verts.index_update()
pend_v = {v.index for f in pend_f for v in f.verts}; gear_v = {v.index for f in gear_f for v in f.verts}
gb.to_mesh(g.data); gb.free(); gw.free()
def gears_w(v):
    if v.index in pend_v: return {"pendulum": 1.0}
    if v.index in gear_v: return {"gear": 1.0}
    return waist(v.co.z)
put(g, gears_w)
put(parts["HandHour"], lambda v: {"hand_hour": 1.0})
put(parts["HandMinute"], lambda v: {"hand_minute": 1.0})
bm.free()

# ---------------------------------------------------------------- one mesh
bpy.ops.object.select_all(action='DESELECT')
for o in parts.values(): o.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = "ClockworkJudge"; body.data.name = "ClockworkJudge"
body.parent = rig
md = body.modifiers.new("Armature", 'ARMATURE'); md.object = rig
loose = sum(1 for v in body.data.vertices if not v.groups)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"welded_body_by_bone": count, "arm_scraps": scraps, "pendulum_verts": len(pend_v), "gear_verts": len(gear_v),
            "unweighted": loose, "verts": len(body.data.vertices), "tris": sum(len(p.vertices) - 2 for p in body.data.polygons),
            "bones": len(arm.bones)})
