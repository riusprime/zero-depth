"""src.blend -> rig.blend: the Lantern Shade's skeleton and skin.

The file is cut into Body (the cloak), ArmL, ArmR and HandLantern. The upper cloak is skinned by Blender's automatic
weights on a welded copy; everything else is skinned by rule: the robe below the waist on eight chains of strip bones,
the talisman strings and tags (found by their colour in the texture) on their own chains, the arms and hands by the
nearest arm bone, the lantern and its chain by height. The parts are joined into one mesh at the end.
"""
import bpy, sys, os, bmesh, math
import numpy as np
from mathutils import Vector, kdtree
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

NAMES = ("Body", "ArmL", "ArmR", "HandLantern")
parts = {}
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name in NAMES:
        mw = o.matrix_world.copy(); o.parent = None
        o.data.transform(mw); o.matrix_world.identity()
        o.modifiers.clear(); o.vertex_groups.clear()
        parts[o.name] = o
for o in list(bpy.data.objects):
    if o not in parts.values(): bpy.data.objects.remove(o)
mesh = parts["Body"]

def tan_mask(o):
    """True for the vertices painted bone/parchment colour (strings, tags, rings), read from the base texture."""
    mat = o.material_slots[0].material; img = None
    for n in mat.node_tree.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            l = n.inputs["Base Color"].links
            if l and l[0].from_node.type == 'TEX_IMAGE': img = l[0].from_node.image
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
    me = o.data; uv = me.uv_layers.active.data
    col = np.zeros((len(me.vertices), 3)); cnt = np.zeros(len(me.vertices))
    for l in me.loops:
        u, v = uv[l.index].uv
        col[l.vertex_index] += px[min(H - 1, max(0, int(v % 1.0 * H))), min(W - 1, max(0, int(u % 1.0 * W))), :3]
        cnt[l.vertex_index] += 1
    col /= np.maximum(cnt, 1)[:, None]
    return (col[:, 0] > col[:, 2] * 1.25) & (col[:, 0] > 0.12)
TAN = {n: tan_mask(o) for n, o in parts.items() if n != "HandLantern"}

# ---------------------------------------------------------------- the bones
# name: (head, tail, parent, in the automatic pass).  The model faces -Y; its right side is -X.
B = [
 ("root",        (0, 0, 0),              (0, 0.4, 0),            None, False),
 ("hips",        (0, -0.08, 1.55),       (0, -0.08, 1.95),       "root", True),
 ("spine",       (0, -0.08, 1.95),       (0, -0.08, 2.32),       "hips", True),
 ("chest",       (0, -0.08, 2.32),       (0, -0.08, 2.70),       "spine", True),
 ("neck",        (0, -0.08, 2.70),       (0, -0.10, 2.86),       "chest", True),
 ("head",        (0, -0.10, 2.86),       (0, -0.20, 3.38),       "neck", True),
 ("shoulder.L",  (0.14, -0.04, 2.70),    (0.55, 0.0, 2.72),      "chest", True),
 ("upper_arm.L", (0.55, 0.0, 2.72),      (0.90, 0.06, 2.20),     "shoulder.L", True),
 ("forearm.L",   (0.90, 0.06, 2.20),     (1.06, -0.08, 1.83),    "upper_arm.L", True),
 ("hand.L",      (1.06, -0.08, 1.83),    (1.13, -0.08, 1.58),    "forearm.L", False),
 ("fingers1.L",  (1.14, -0.08, 1.58),    (1.29, -0.08, 1.38),    "hand.L", False),
 ("fingers2.L",  (1.29, -0.08, 1.38),    (1.29, -0.08, 1.17),    "fingers1.L", False),
 ("thumb.L",     (1.03, -0.08, 1.62),    (0.93, -0.08, 1.36),    "hand.L", False),
 ("shoulder.R",  (-0.14, -0.04, 2.70),   (-0.55, -0.03, 2.72),   "chest", True),
 ("upper_arm.R", (-0.55, -0.03, 2.72),   (-0.90, -0.10, 2.28),   "shoulder.R", True),
 ("forearm.R",   (-0.90, -0.10, 2.28),   (-1.10, -0.27, 1.98),   "upper_arm.R", True),
 ("hand.R",      (-1.10, -0.27, 1.98),   (-1.17, -0.33, 1.80),   "forearm.R", False),
 ("fingers1.R",  (-1.20, -0.36, 1.80),   (-1.28, -0.38, 1.67),   "hand.R", False),
 ("fingers2.R",  (-1.28, -0.38, 1.67),   (-1.20, -0.38, 1.58),   "fingers1.R", False),
 ("thumb.R",     (-1.05, -0.33, 1.84),   (-1.02, -0.36, 1.63),   "hand.R", False),
 ("chain1",      (-1.12, -0.37, 1.57),   (-1.12, -0.37, 1.47),   "hand.R", False),
 ("chain2",      (-1.12, -0.37, 1.47),   (-1.12, -0.37, 1.37),   "chain1", False),
 ("lantern",     (-1.12, -0.37, 1.37),   (-1.12, -0.37, 0.62),   "chain2", False),
 ("mantle.L",    (0.86, 0.02, 2.32),     (0.92, 0.02, 1.90),     "upper_arm.L", False),
 ("mantle.R",    (-0.86, -0.02, 2.32),   (-0.92, -0.02, 1.90),   "upper_arm.R", False),
 ("tag.L",       (0.71, -0.04, 2.34),    (0.71, -0.04, 1.95),    "upper_arm.L", False),
 ("tag.R",       (-0.69, -0.08, 2.44),   (-0.69, -0.08, 1.95),   "upper_arm.R", False),
]
# The talisman strings hang from the rings on the chest.
TAL = {"L": [(0.52, -0.40, 2.68), (0.52, -0.40, 2.32), (0.52, -0.40, 1.97), (0.52, -0.40, 1.62)],
       "R": [(-0.37, -0.36, 2.68), (-0.37, -0.36, 2.33), (-0.37, -0.36, 1.98), (-0.37, -0.36, 1.62)]}
for side, pts in TAL.items():
    for i in range(3):
        B.append((f"tal{i+1}.{side}", pts[i], pts[i+1], "chest" if i == 0 else f"tal{i}.{side}", False))
# The robe below the waist: eight chains round the hem, three links each. (angle about +Z from +X, radius at each joint)
STRIP_Z = (1.60, 1.10, 0.65, 0.20)
STRIPS = {"strip_side{}.L": (0, (.55, .62, .85, .78)), "strip_back{}.L": (45, (.48, .57, .62, .55)),
          "strip_back{}": (90, (.23, .35, .46, .50)), "strip_back{}.R": (135, (.40, .48, .55, .53)),
          "strip_side{}.R": (180, (.42, .56, .85, .90)), "strip_front{}.R": (225, (.40, .43, .56, .60)),
          "strip_front{}": (270, (.40, .42, .45, .48)), "strip_front{}.L": (315, (.47, .52, .58, .72))}
CHAINS = {}
for fmt, (ang, rad) in STRIPS.items():
    pts = [(r * math.cos(math.radians(ang)), r * math.sin(math.radians(ang)), z) for r, z in zip(rad, STRIP_Z)]
    CHAINS[fmt] = pts
    for i in range(3):
        B.append((fmt.format(i + 1), pts[i], pts[i + 1], "hips" if i == 0 else fmt.format(i), False))

arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par, auto in B:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.use_deform = auto
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
SEG = {n: (Vector(h), Vector(tl)) for n, h, tl, _, _ in B}
def off_bone(co, n, yscale=1.0):
    """Metres from a point to a bone's segment."""
    h, tl = SEG[n]; ax = tl - h; ln = ax.length; ax /= ln
    s = max(0.0, min(ln, (co - h).dot(ax)))
    d = co - (h + ax * s); d.y *= yscale
    return d.length
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- the upper cloak: automatic weights on a welded copy
tmp = mesh.copy(); tmp.data = mesh.data.copy(); bpy.context.scene.collection.objects.link(tmp)
bm = bmesh.new(); bm.from_mesh(tmp.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005); bm.to_mesh(tmp.data); bm.free()
bpy.ops.object.select_all(action='DESELECT')
tmp.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unweighted = sum(1 for v in tmp.data.vertices if not v.groups)
for b in arm.bones: b.use_deform = b.name != "root"
kd = kdtree.KDTree(len(tmp.data.vertices))
for v in tmp.data.vertices: kd.insert(v.co, v.index)
kd.balance()
names = [g.name for g in tmp.vertex_groups]

def chain_weights(pts, fmt, z, bw):
    """A point at height z on a three-link chain: the link it is on, blended across each joint."""
    z1, z2 = pts[1][2], pts[2][2]
    a = smooth((z - (z1 - bw)) / (2 * bw)); b = smooth((z - (z2 - bw)) / (2 * bw))
    return {fmt.format(1): a, fmt.format(2): (1 - a) * b, fmt.format(3): (1 - a) * (1 - b)}
def strip_weights(co):
    """The robe: the two nearest chains at this height share the point."""
    ds = []
    for fmt, pts in CHAINS.items():
        z = co.z
        for i in range(3):
            if z >= pts[i + 1][2] or i == 2:
                t = (pts[i][2] - z) / (pts[i][2] - pts[i + 1][2]); t = max(-0.3, min(1.3, t)); break
        x = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t; y = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t
        ds.append((math.hypot(co.x - x, co.y - y), fmt))
    ds.sort(); out = {}
    k3 = 1.0 / (ds[2][0] ** 2 + 0.01) ** 1.5         # a chain's share falls to nothing as it becomes the third nearest: no jump
    ws = [1.0 / (d * d + 0.01) ** 1.5 - k3 for d, _ in ds[:2]]; s = sum(ws) or 1.0
    for (d, fmt), w in zip(ds[:2], ws):
        for n, x in chain_weights(CHAINS[fmt], fmt, co.z, 0.14).items():
            if x > 0.001: out[n] = out.get(n, 0.0) + x * w / s
    return out
def mix(a, b, t):
    out = {}
    for n, x in a.items(): out[n] = out.get(n, 0.0) + x * (1 - t)
    for n, x in b.items(): out[n] = out.get(n, 0.0) + x * t
    return {n: x for n, x in out.items() if x > 0.002}

LBOX = ((-1.45, -0.89), (-0.65, -0.10), (0.55, 1.62))      # the lantern's box: pieces of it were cut into other parts
def in_lantern(co): return all(lo <= c <= hi for c, (lo, hi) in zip(co, LBOX))
def body_weights(v, tan):
    co = v.co
    if in_lantern(co): return {"lantern": 1.0}
    _, idx, _ = kd.find(co)
    w = {names[g.group]: g.weight for g in tmp.data.vertices[idx].groups if g.weight > 0.01}
    for side, sx in (("L", 1), ("R", -1)):
        f, u = f"forearm.{side}", f"upper_arm.{side}"
        # Only the stub of the arm that the cut left on the cloak follows the forearm; cloth beside it stays on the upper arm.
        if w.get(f, 0) > 0 and off_bone(co, f) > 0.10:
            w[u] = w.get(u, 0.0) + w.pop(f)
        # The mantle's ragged hem under the elbow swings on its own bone.
        aw = w.get(u, 0.0)
        m = smooth((2.36 - co.z) / 0.3) * smooth((co.x * sx - 0.58) / 0.15) * min(1.0, aw / 0.35)
        if m > 0.01 and not tan: w = mix(w, {f"mantle.{side}": 1.0}, m * 0.85)
    # The robe: from the waist down it belongs to the strip chains.
    w = mix(w, strip_weights(co), smooth((1.95 - co.z) / 0.5))
    if tan and co.y < -0.2 and 1.58 < co.z < 2.64:
        for side, pts in TAL.items():
            if abs(co.x - pts[0][0]) < 0.2:
                w = mix(w, chain_weights(pts, "tal{}." + side, co.z, 0.05), smooth((2.62 - co.z) / 0.28))
    if tan and 1.9 < co.z < 2.47 and 0.52 < abs(co.x) < 0.79 and -0.25 < co.y < 0.1:
        side = "L" if co.x > 0 else "R"; top = SEG[f"tag.{side}"][0].z
        w = mix(w, {f"tag.{side}": 1.0}, smooth((top - co.z) / 0.08))
    return w
def put(o, i, w):
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(x for _, x in top) or 1.0
    for n, x in top: o.vertex_groups[n].add([i], x / s, 'REPLACE')
ALL = [b.name for b in arm.bones if b.name != "root"]
for o in parts.values():
    for n in ALL: o.vertex_groups.new(name=n)
# The file splits vertices along UV seams: the copies of one point must get one answer, so the rules run per point.
node_of = {}; nodes = []
for v in mesh.data.vertices:
    k = tuple(round(x, 3) for x in v.co)
    if k not in node_of: node_of[k] = len(nodes); nodes.append([])
    nodes[node_of[k]].append(v.index)
vnode = {i: n for n, lst in enumerate(nodes) for i in lst}
nw = []
for lst in nodes:
    tan = sum(1 for i in lst if TAN["Body"][i]) * 2 >= len(lst)
    nw.append(body_weights(mesh.data.vertices[lst[0]], tan))
# The strings, tags and hems are fused to the cloth here and there: their weights are spread a few edges into it, so
# the cloth beside a swinging string gives instead of tearing.
nb = [set() for _ in nodes]
for e in mesh.data.edges:
    a, b = vnode[e.vertices[0]], vnode[e.vertices[1]]
    if a != b: nb[a].add(b); nb[b].add(a)
SOFT = [n for n in ALL if n.split(".")[0].rstrip("123") in ("tal", "tag", "mantle")]
for it in range(3):
    new = []
    for i, w in enumerate(nw):
        if not nb[i] or "lantern" in w: new.append(w); continue
        sp = {}
        for n in SOFT:
            x = 0.5 * w.get(n, 0.0) + 0.5 * sum(nw[j].get(n, 0.0) for j in nb[i]) / len(nb[i])
            if x > 0.003: sp[n] = x
        s = sum(sp.values()); rest = {n: x for n, x in w.items() if n not in SOFT}; rs = sum(rest.values())
        if rs > 1e-6:
            out = {n: x * (1 - s) / rs for n, x in rest.items()}; out.update(sp)
        else: out = sp or w
        new.append(out)
    nw = new
final = {}
for v in mesh.data.vertices:
    w = nw[vnode[v.index]]; final[v.index] = w; put(mesh, v.index, w)
bpy.data.objects.remove(tmp)
body_kd = kdtree.KDTree(len(mesh.data.vertices))
for v in mesh.data.vertices: body_kd.insert(v.co, v.index)
body_kd.balance()

# ---------------------------------------------------------------- the arms: the limb by its nearest bones, the scraps of cloak back to the cloak
def components(o):
    """Vertex index -> component id (joined through edges and through coincident positions), and the sizes."""
    me = o.data; parent = list(range(len(me.vertices)))
    def find(a):
        while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
        return a
    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b: parent[a] = b
    key = {}
    for v in me.vertices:
        k = tuple(round(x, 3) for x in v.co)
        if k in key:
            a, b = find(key[k]), find(v.index)
            if a != b: parent[a] = b
        else: key[k] = v.index
    ids = [find(i) for i in range(len(me.vertices))]; size = {}
    for i in ids: size[i] = size.get(i, 0) + 1
    return ids, size
report = {}
for pname, side in (("ArmL", "L"), ("ArmR", "R")):
    o = parts[pname]; ids, size = components(o); main = max(size, key=size.get); tan = TAN[pname]
    limb = [f"upper_arm.{side}", f"forearm.{side}", f"hand.{side}", f"fingers1.{side}", f"fingers2.{side}", f"thumb.{side}"]
    cnt = {"limb": 0, "lantern": 0, "scrap": 0}; thumb = []
    for v in o.data.vertices:
        if ids[v.index] != main:
            if in_lantern(v.co): w = {"lantern": 1.0}; cnt["lantern"] += 1
            else: w = final[body_kd.find(v.co)[1]]; cnt["scrap"] += 1
        else:
            cnt["limb"] += 1
            ys = 0.35 if side == "L" else 1.0             # the left hand's fingers fan out along Y
            d = {n: off_bone(v.co, n, ys if n.split(".")[0] in ("fingers1", "fingers2", "thumb") else 1.0) for n in limb}
            if side == "R" and tan[v.index] and v.co.z < 1.9: w = {"hand.R": 1.0}      # the ring it holds
            else:
                near = sorted(d.items(), key=lambda kv: kv[1])[:2]
                w = {n: 1.0 / (x + 0.004) ** 6 for n, x in near}
        put(o, v.index, w)
    report[pname] = cnt
# ---------------------------------------------------------------- the lantern on its chain
o = parts["HandLantern"]
for v in o.data.vertices:
    z = v.co.z
    a = smooth((z - 1.44) / 0.06); b = smooth((z - 1.34) / 0.06)
    put(o, v.index, {"chain1": a, "chain2": (1 - a) * b, "lantern": (1 - a) * (1 - b)})

bpy.ops.object.select_all(action='DESELECT')
for o in parts.values(): o.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.join()
mesh.name = "LanternShade"; mesh.data.name = "LanternShade"
mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig
cnt = {}
for v in mesh.data.vertices:
    if v.groups:
        g = max(v.groups, key=lambda g: g.weight); n = mesh.vertex_groups[g.group].name; cnt[n] = cnt.get(n, 0) + 1
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"unweighted_welded": unweighted, "parts": report, "bones": len(arm.bones), "verts": len(mesh.data.vertices),
            "tris": sum(len(p.vertices) - 2 for p in mesh.data.polygons), "dominant": cnt})
