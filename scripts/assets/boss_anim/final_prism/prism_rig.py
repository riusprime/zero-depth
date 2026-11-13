"""src.blend -> rig.blend: the Prism's skeleton and skin.

The delivered file is one mesh of 21 loose pieces: the torn figure (hood, crystal torso, cloak, a cluster of crystal
columns under the chest) and 20 crystals. Nothing is cut or welded: every vertex stays, only weights are added.
- The crystals are rigid, each on one bone: nine free shards (the game orbits them), six spikes hanging under her,
  the halo's ring, its broken disc, the two crown wedges, a shoulder stud (on the chest).
- The figure is skinned by rule, per point (so the copies of a point along a UV seam agree): the torso by height
  (body, chest, neck, head), the chest crystal on `core`, the column cluster on `spike_front`, and everything outside
  the torso (the cloak's mantle, wings and back) on seven chains of three bones hung from the shoulders.
The work frame is the delivered one times ten, turned to face -Y (export.py turns it back).
"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, plib
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

mesh = plib.work_mesh(); me = mesh.data
mesh.modifiers.clear(); mesh.vertex_groups.clear()
ids, size = plib.pieces(me)
main = max(size, key=size.get)
co = [v.co.copy() for v in me.vertices]

AX = Vector((-0.43, -0.18, 0.0))          # her axis: the torso's centre line
def P(r, deg, z): return (AX.x + r * math.cos(math.radians(deg)), AX.y + r * math.sin(math.radians(deg)), z)

# ---------------------------------------------------------------- the loose crystals, by their centres
SHARDS = [  # the free shards, in bone order: round her from her left (+X), anticlockwise seen from above; ties by height
    (1.84, -0.323, 0.607), (0.822, -0.127, 2.025), (1.086, 0.039, 2.446), (-1.81, 0.039, 2.446), (-1.673, -0.127, 2.055),
    (-1.585, -0.284, 1.223), (-1.791, -0.333, 0.675), (0.333, -0.753, 1.223), (1.076, -0.793, 1.008)]
SPIKES = {"spike_c": (-0.391, -0.254, 0.372), "spike_back.L": (-0.127, 0.196, 0.949), "spike_back.R": (-0.744, 0.196, 0.93),
          "spike_side.R": (-1.155, -0.254, 0.499), "spike_front.L": (0.068, -0.616, 0.89), "spike_front.R": (-0.998, -0.607, 1.037)}
CROWN = {"halo_ring": (-0.431, -0.01, 2.945), "halo_disc": (-0.431, 0.646, 2.701), "crown.L": (0.303, 0.078, 2.798),
         "crown.R": (-1.164, 0.078, 2.798)}
STUD = (-0.969, -0.45, 2.192)
box = {}
for i, pid in enumerate(ids):
    b = box.setdefault(pid, [co[i].copy(), co[i].copy()])
    for k in range(3): b[0][k] = min(b[0][k], co[i][k]); b[1][k] = max(b[1][k], co[i][k])
piece_bone = {}; piece_box = {}
def match(c, name):
    best = min((pid for pid in box if pid != main), key=lambda pid: ((box[pid][0] + box[pid][1]) / 2 - Vector(c)).length)
    assert ((box[best][0] + box[best][1]) / 2 - Vector(c)).length < 0.05 and best not in piece_bone, name
    piece_bone[best] = name; piece_box[name] = box[best]
for k, c in enumerate(SHARDS): match(c, f"shard_{k:02d}")
for n, c in SPIKES.items(): match(c, n)
for n, c in CROWN.items(): match(c, n)
match(STUD, "chest")
assert len(piece_bone) == len(size) - 1, (len(piece_bone), len(size))
def centre(n): return (piece_box[n][0] + piece_box[n][1]) / 2

# ---------------------------------------------------------------- the bones
CORE = Vector((-0.39, -0.47, 1.86))
B = [  # name, head, tail, parent
 ("root",        (0, 0, 0),             (0, 0.4, 0),           None),
 ("body",        (AX.x, AX.y, 1.20),    (AX.x, AX.y, 1.75),    "root"),
 ("chest",       (AX.x, AX.y, 1.75),    (AX.x, -0.22, 2.22),   "body"),
 ("neck",        (AX.x, -0.22, 2.22),   (AX.x, -0.28, 2.36),   "chest"),
 ("head",        (AX.x, -0.28, 2.36),   (AX.x, -0.42, 2.85),   "neck"),
 ("core",        tuple(CORE),           (CORE.x, CORE.y - 0.3, CORE.z), "chest"),
 ("halo",        (AX.x, 0.10, 2.55),    (AX.x, 0.10, 2.95),    "chest"),
 ("shards_lift", (AX.x, AX.y, 1.50),    (AX.x, AX.y, 1.90),    "root"),
 ("shards",      (AX.x, AX.y, 1.50),    (AX.x, AX.y, 1.90),    "shards_lift"),
]
# A free crystal turns about its own long axis in the game, so its bone's Y is that axis: the line through the piece's
# middle along which it is longest (from its points), pointing at its red tip (or, with no red on it, its far end).
bone_piece = {v: k for k, v in piece_bone.items()}
COL = plib.vert_colours(mesh); RED = (COL[:, 0] > 0.25) & (COL[:, 0] > COL[:, 1] * 2.2)
AXIS = {}
def long_axis(n):
    idx = [i for i, pid in enumerate(ids) if pid == bone_piece[n]]; pts = np.array([co[i][:] for i in idx]); red = RED[idx]
    m = pts.mean(axis=0); w, v = np.linalg.eigh(np.cov((pts - m).T)); a = v[:, int(np.argmax(w))]
    pr = (pts - m) @ a
    if (red.sum() >= 5 and pr[red].mean() < 0) or (red.sum() < 5 and -pr.min() > pr.max()): a = -a; pr = -pr
    AXIS[n] = (Vector(m), Vector(a), float(pr.min()), float(pr.max()))
    return AXIS[n]
for n in CROWN:
    if n.startswith("crown"):
        m, a, lo, hi = long_axis(n); c = centre(n); B.append((n, tuple(c), tuple(c + a * 0.3), "halo"))
    else:
        c = centre(n); B.append((n, tuple(c), (c.x, c.y, c.z + 0.3), "halo"))
for k in range(len(SHARDS)):
    n = f"shard_{k:02d}"; m, a, lo, hi = long_axis(n); c = centre(n); B.append((n, tuple(c), tuple(c + a * 0.25), "shards"))
for n in SPIKES:           # a spike hangs from its upper end, its bone down its long axis
    m, a, lo, hi = long_axis(n)
    if a.z > 0: a = -a; lo, hi = -hi, -lo
    B.append((n, tuple(m + a * lo), tuple(m + a * hi), "body"))
B.append(("spike_front", (-0.46, -0.50, 1.45), (-0.46, -0.50, 0.62), "body"))
# The cloak: seven chains from the shoulder line, three links each. (direction about her axis, (radius, height) per joint)
CH = {"wing{}.L": (0, [(0.50, 2.10), (0.85, 1.82), (1.08, 1.45), (1.34, 1.02)]),
      "back{}.L": (45, [(0.45, 2.10), (0.60, 1.60), (0.90, 1.10), (0.93, 0.60)]),
      "back{}": (90, [(0.45, 2.10), (0.62, 1.55), (0.85, 0.95), (0.98, 0.15)]),
      "back{}.R": (135, [(0.45, 2.10), (0.65, 1.55), (0.98, 0.95), (1.00, 0.30)]),
      "wing{}.R": (180, [(0.50, 2.10), (0.88, 1.88), (1.22, 1.65), (1.52, 1.40)]),
      "front{}.R": (225, [(0.45, 2.10), (0.80, 1.88), (1.15, 1.65), (1.45, 1.40)]),
      "front{}.L": (315, [(0.45, 2.10), (0.72, 1.85), (1.00, 1.55), (1.35, 1.20)])}
CHAINS = {}
for fmt, (ang, rz) in CH.items():
    pts = [Vector(P(r, ang, z)) for r, z in rz]; CHAINS[fmt] = pts
    for i in range(3):
        B.append((fmt.format(i + 1), tuple(pts[i]), tuple(pts[i + 1]), "chest" if i == 0 else fmt.format(i)))

arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in B:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t; eb.use_deform = name not in ("root", "halo", "shards", "shards_lift")
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- the figure's weights, by rule
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def mix(a, b, t):
    out = {}
    for n, x in a.items(): out[n] = out.get(n, 0.0) + x * (1 - t)
    for n, x in b.items(): out[n] = out.get(n, 0.0) + x * t
    return {n: x for n, x in out.items() if x > 0.002}
def torso(p):
    z = p.z
    a = smooth((z - 1.60) / 0.30); b = smooth((z - 2.22) / 0.10); c = smooth((z - 2.30) / 0.10)
    return {"body": 1 - a, "chest": a * (1 - b), "neck": b * (1 - c), "head": c}
def on_chain(p, pts):
    """Nearest point of a chain's line: (distance, position along it in links 0..3)."""
    best = (1e9, 0.0)
    for i in range(3):
        a, b = pts[i], pts[i + 1]; ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        d = (p - (a + ab * t)).length
        if d < best[0]: best = (d, i + t)
    return best
def links(fmt, s, bw=0.22):
    a = smooth((s - (1 - bw)) / (2 * bw)); b = smooth((s - (2 - bw)) / (2 * bw))
    return {fmt.format(1): 1 - a, fmt.format(2): a * (1 - b), fmt.format(3): a * b}
def cloak(p):
    ds = sorted((on_chain(p, pts) + (fmt,) for fmt, pts in CHAINS.items()))
    k3 = 1.0 / (ds[2][0] ** 2 + 0.01) ** 1.5         # a chain's share falls to nothing as it becomes the third nearest
    ws = [1.0 / (d * d + 0.01) ** 1.5 - k3 for d, _, _ in ds[:2]]; s = sum(ws) or 1.0
    out = {}
    for (d, par, fmt), w in zip(ds[:2], ws):
        for n, x in links(fmt, par).items():
            if x > 0.001: out[n] = out.get(n, 0.0) + x * w / s
    return out
def figure(p):
    w = torso(p)
    r = math.hypot(p.x - AX.x, p.y - AX.y)
    rt = 0.55 - 0.12 * smooth((p.z - 1.95) / 0.25)                 # the torso's radius: narrower at the shoulders
    f = smooth((r - rt) / 0.30) * smooth((2.27 - p.z) / 0.14)      # outside it and below the hood: the cloak
    if f > 0.002: w = mix(w, cloak(p), f)
    # the crystal columns under the chest
    g = smooth((1.46 - p.z) / 0.20) * smooth((-0.20 - p.y) / 0.15) * smooth((0.80 - r) / 0.08)
    if g > 0.002: w = mix(w, {"spike_front": 1.0}, g)
    # the chest crystal and its frame
    c = (1 - smooth(((p - CORE).length - 0.16) / 0.14)) * smooth((-0.30 - p.y) / 0.08)
    if c > 0.002: w = mix(w, {"core": 1.0}, c)
    return w

for n, _, _, _ in B: mesh.vertex_groups.new(name=n)
node = {}; cnt = {}
for v in me.vertices:
    if ids[v.index] == main:
        k = tuple(round(x, 3) for x in v.co)
        if k not in node: node[k] = figure(v.co)
# The rules meet along sharp lines (cloak against torso, one chain against the next): the weights are then evened out
# along the surface, so where two bones part the faces between them bend over several edges instead of one tearing.
vkey = {v.index: tuple(round(x, 3) for x in v.co) for v in me.vertices if ids[v.index] == main}
nb = {k: set() for k in node}
for e in me.edges:
    a, b = e.vertices
    if a in vkey and b in vkey and vkey[a] != vkey[b]: nb[vkey[a]].add(vkey[b]); nb[vkey[b]].add(vkey[a])
SMOOTH = int(os.environ.get("ZD_SMOOTH", "8"))
for it in range(SMOOTH):
    new = {}
    for k, w in node.items():
        if not nb[k]: new[k] = w; continue
        out = {n: 0.5 * x for n, x in w.items()}; share = 0.5 / len(nb[k])
        for j in nb[k]:
            for n, x in node[j].items(): out[n] = out.get(n, 0.0) + x * share
        new[k] = {n: x for n, x in out.items() if x > 0.002}
    node = new
for v in me.vertices:
    pid = ids[v.index]
    if pid != main: w = {piece_bone[pid]: 1.0}
    else: w = node[vkey[v.index]]
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]; s = sum(x for _, x in top)
    for n, x in top: mesh.vertex_groups[n].add([v.index], x / s, 'REPLACE')
    cnt[top[0][0]] = cnt.get(top[0][0], 0) + 1
mesh.name = "final_boss_phase2"; me.name = "final_boss_phase2"
mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"bones": len(arm.bones), "verts": len(me.vertices), "tris": sum(len(p.vertices) - 2 for p in me.polygons),
            "dominant": cnt, "shards": {f"shard_{k:02d}": [round(x, 3) for x in centre(f"shard_{k:02d}")] for k in range(len(SHARDS))},
            "long_axes": {n: [round(x, 2) for x in a[1]] for n, a in AXIS.items()}})
