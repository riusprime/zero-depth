"""src10.blend -> rig.blend: the Colossus's skeleton and skin.

The delivered mesh is eleven closed shells: the cloaked body, the two fists, the halo, five crystal spikes and the two
pale plates that hang before it. Nothing is skinned by automatic weights: every shell is skinned by rule.
- A spike or a plate is rigid on its own bone.
- The halo is cut in two at its back (its faces are split along the cut, no triangle is added) and each half is rigid.
- A fist is cut into its stone blocks by connectivity: what hangs below the knuckle line is three fingers and a thumb
  (each finger a knuckle bone and a claw bone), what stands above the wrist is the wrist block and the forearm stone;
  the rest is the palm, on the fist's own bone. A block is rigid; only the red neck between two blocks bends.
- The body: the dark torso inside the cloak follows body / spine / chest / neck by height, the hood is the head, the
  mantle hangs on eight chains of two links, and the long back sheet with its ring carries the back chain on down.
Work space: metres x10 of the delivered file, turned to face -Y (export.py turns and scales it back).
"""
import bpy, sys, os, bmesh, math
import numpy as np
from mathutils import Vector, kdtree
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, colmask
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
mesh = [o for o in bpy.data.objects if o.type == 'MESH'][0]
for o in list(bpy.data.objects):
    if o is not mesh: bpy.data.objects.remove(o)
mesh.modifiers.clear(); mesh.vertex_groups.clear()
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def V(*a): return Vector(a)

# ---------------------------------------------------------------- the halo is cut in two at its back
HALO_SEED = max((v.co.copy() for v in mesh.data.vertices), key=lambda c: c.z)      # the halo is the highest thing
def shell_of_bm(bm, seed):
    v0 = min(bm.verts, key=lambda v: (v.co - seed).length)
    key = {}
    for v in bm.verts: key.setdefault(tuple(round(x, 3) for x in v.co), []).append(v)
    seen = {v0}; todo = [v0]
    while todo:
        v = todo.pop()
        nb = [e.other_vert(v) for e in v.link_edges] + key[tuple(round(x, 3) for x in v.co)]
        for o in nb:
            if o not in seen: seen.add(o); todo.append(o)
    return seen
bm = bmesh.new(); bm.from_mesh(mesh.data)
hv = shell_of_bm(bm, HALO_SEED)
HALO_C = sum((v.co for v in hv), Vector()) / len(hv)
hf = {f for v in hv for f in v.link_faces}
side = {f: (f.calc_center_median().x > HALO_C.x) for f in hf}
cut = [e for e in bm.edges if len(e.link_faces) == 2 and e.link_faces[0] in side and side[e.link_faces[0]] != side[e.link_faces[1]]
       and e.calc_length() >= 0 and (e.verts[0].co.y + e.verts[1].co.y) / 2 > HALO_C.y]
bmesh.ops.split_edges(bm, edges=cut)
bm.to_mesh(mesh.data); bm.free()
me = mesh.data
PALE = colmask.pale_verts(mesh)

# ---------------------------------------------------------------- points (the file splits vertices along UV seams) and shells
node_of = {}; nodes = []
for v in me.vertices:
    k = tuple(round(x, 3) for x in v.co)
    if k not in node_of: node_of[k] = len(nodes); nodes.append([])
    nodes[node_of[k]].append(v.index)
vnode = [0] * len(me.vertices)
for n, lst in enumerate(nodes):
    for i in lst: vnode[i] = n
NCO = [me.vertices[lst[0]].co.copy() for lst in nodes]
NPALE = [sum(PALE[i] for i in lst) / len(lst) for lst in nodes]
nb = [set() for _ in nodes]
for e in me.edges:
    a, b = vnode[e.vertices[0]], vnode[e.vertices[1]]
    if a != b: nb[a].add(b); nb[b].add(a)
def comps(keep):
    """Connected pieces of a set of points."""
    keep = set(keep); out = []
    while keep:
        s = keep.pop(); c = [s]; todo = [s]
        while todo:
            n = todo.pop()
            for o in nb[n]:
                if o in keep: keep.discard(o); c.append(o); todo.append(o)
        out.append(c)
    return out
def nearest(pieces, seed):
    return min(pieces, key=lambda c: min((NCO[n] - seed).length for n in c))
SHELLS = comps(range(len(nodes)))
def centroid(ns): return sum((NCO[n] for n in ns), Vector()) / len(ns)
def band(ns, z0, z1):
    b = [n for n in ns if z0 <= NCO[n].z <= z1]
    return b or ns

# The halo's halves share the cut's points, so they are told apart by their faces.
halo_nodes = set(nearest(SHELLS, HALO_SEED))
vside = {}
for p in me.polygons:
    if vnode[p.vertices[0]] in halo_nodes:
        s = p.center.x > HALO_C.x
        for i in p.vertices: vside[i] = s

W = {}                      # vertex -> {bone: weight}; filled per shell
BONES = []                  # (name, head, tail, parent)
def bone(name, head, tail, parent): BONES.append((name, Vector(head), Vector(tail), parent))
def rigid(ns, name):
    for n in ns:
        for i in nodes[n]: W[i] = {name: 1.0}

# ---------------------------------------------------------------- the body's own bones
bone("root", (0, 0, 0), (0, 0.4, 0), None)
bone("body", (0, 0.05, 1.20), (0, 0.05, 1.45), "root")
bone("spine", (0, 0.05, 1.45), (0, 0.05, 1.70), "body")
bone("chest", (0, 0.05, 1.70), (0, 0.05, 2.38), "spine")
bone("neck", (0, 0.05, 2.38), (0, 0.05, 2.50), "chest")
bone("head", (0, 0.05, 2.50), (0, 0.0, 3.03), "neck")
bone("core", (0, -0.30, 1.95), (0, -0.62, 1.95), "chest")
JOINTS = [("body", None), ("spine", (1.45, 0.10)), ("chest", (1.70, 0.10)), ("neck", (2.38, 0.05)), ("head", (2.47, 0.04))]
def height_w(z):
    out = {}; up = 1.0
    for k, (name, _) in enumerate(JOINTS):
        nxt = JOINTS[k + 1][1] if k + 1 < len(JOINTS) else None
        s = smooth((z - (nxt[0] - nxt[1])) / (2 * nxt[1])) if nxt else 0.0
        if up * (1 - s) > 0.001: out[name] = up * (1 - s)
        up *= s
    return out

# ---------------------------------------------------------------- the halo
bone("halo", HALO_C, HALO_C + V(0, 0, 0.3), "head")
hl = [n for n in halo_nodes if NCO[n].x > HALO_C.x]; hr = [n for n in halo_nodes if NCO[n].x <= HALO_C.x]
back = max(halo_nodes, key=lambda n: NCO[n].y)
hinge = V(HALO_C.x, NCO[back].y - 0.03, NCO[back].z)
for sd, ns in (("L", hl), ("R", hr)):
    tip = min(ns, key=lambda n: NCO[n].y)
    bone(f"halo.{sd}", hinge, centroid(band(ns, NCO[tip].z - 9, 9)) * 0.4 + NCO[tip] * 0.6, "halo")
for n in halo_nodes:
    for i in nodes[n]: W[i] = {("halo.L" if vside.get(i, NCO[n].x > HALO_C.x) else "halo.R"): 1.0}

# ---------------------------------------------------------------- the spikes and the plates: each rigid on its bone
RIGID = {"spike_front": V(0.04, -0.3, 0.8), "spike_low.L": V(0.3, 0.1, 0.6), "spike_low.R": V(-0.2, 0.1, 0.6),
         "spike_side.L": V(0.65, 0.05, 1.0), "spike_side.R": V(-0.55, 0.05, 1.0),
         "tag.L": V(0.62, -0.55, 1.4), "tag.R": V(-0.47, -0.7, 1.45)}
used = set(halo_nodes)
for name, seed in RIGID.items():
    ns = nearest([s for s in SHELLS if len(s) < 400 and not (set(s) & used)], seed); used |= set(ns)
    top = max(NCO[n].z for n in ns); bot = min(NCO[n].z for n in ns)
    if name.startswith("spike"):
        # A crystal is held in the air and turned about its own length: its bone lies on the line from its tip through
        # its middle (the bone's Y is the long axis, pointing at the tip), so a turn about Y leaves the tip where it is.
        tip = NCO[min(ns, key=lambda n: NCO[n].z)]; mid = centroid(ns); ax = (mid - tip).normalized()
        bone(name, tip + ax * max((NCO[n] - tip).dot(ax) for n in ns), tip, "body")
    else:
        bone(name, centroid(band(ns, top - 0.08, top)), centroid(band(ns, bot, bot + 0.05)), "body")
    rigid(ns, name)

# ---------------------------------------------------------------- the fists
FIST = {"R": dict(seed=V(-1.4, -0.3, 1.4), zw=1.70, zn=2.03, zk=1.09, zt=1.39,
                  tips={"a": V(-1.33, -0.32, 0.7), "b": V(-1.2, -0.65, 0.68), "c": V(-0.97, -0.86, 0.74)}, thumb=V(-0.8, -0.76, 1.02)),
        "L": dict(seed=V(1.4, -0.3, 1.4), zw=1.75, zn=2.07, zk=1.14, zt=1.29,
                  tips={"a": V(1.43, -0.03, 0.76), "b": V(1.3, -0.43, 0.72), "c": V(1.15, -0.75, 0.78)}, thumb=V(1.0, -0.7, 0.88))}
report = {}
for sd, F in FIST.items():
    shell = nearest([s for s in SHELLS if not (set(s) & used) and len(s) < max(len(x) for x in SHELLS)], F["seed"]); used |= set(shell)
    left = set(shell); rep = {}
    # the forearm stack: what stands above the wrist line and holds the highest point
    up = comps([n for n in shell if NCO[n].z > F["zw"]])
    arm = max(up, key=lambda c: max(NCO[n].z for n in c)); left -= set(arm)
    # the fingers and the thumb: what hangs below the knuckle line
    low = comps([n for n in left if NCO[n].z < F["zk"]])
    fingers = {}
    for k, tip in F["tips"].items():
        fingers[k] = nearest(low, tip); low = [c for c in low if c is not fingers[k]]; left -= set(fingers[k])
    th = nearest(comps([n for n in left if NCO[n].z < F["zt"]]), F["thumb"]); left -= set(th)
    palm = list(left)
    pc = centroid(palm)
    bone(f"fist.{sd}", pc, pc + V(0, 0, -0.4), "root")
    rigid(palm, f"fist.{sd}")
    # wrist block and forearm stone, the red neck between them shared
    zn = F["zn"]; lo = min(NCO[n].z for n in arm); hi = max(arm, key=lambda n: NCO[n].z)
    j0 = centroid(band(arm, lo, lo + 0.07)); j1 = centroid(band(arm, zn - 0.04, zn + 0.04))
    bone(f"wrist.{sd}", j0, j1, f"fist.{sd}")
    bone(f"forearm.{sd}", j1, centroid(band(arm, NCO[hi].z - 0.1, 9)) + V(0, 0, 0.05), f"wrist.{sd}")
    for n in arm:
        a = smooth((NCO[n].z - (zn - 0.03)) / 0.06); b = smooth((NCO[n].z - lo) / 0.06)
        w = {f"forearm.{sd}": a, f"wrist.{sd}": (1 - a) * b, f"fist.{sd}": (1 - a) * (1 - b)}
        for i in nodes[n]: W[i] = {k: x for k, x in w.items() if x > 0.001}
    for k, ns in fingers.items():
        top = max(NCO[n].z for n in ns); tipn = min(ns, key=lambda n: NCO[n].z); zm = (top + NCO[tipn].z) / 2
        h = centroid(band(ns, top - 0.05, top)); m = centroid(band(ns, zm - 0.04, zm + 0.04))
        bone(f"finger_{k}.{sd}", h, m, f"fist.{sd}"); bone(f"claw_{k}.{sd}", m, NCO[tipn], f"finger_{k}.{sd}")
        for n in ns:
            a = smooth((NCO[n].z - (zm - 0.03)) / 0.06)
            for i in nodes[n]: W[i] = {k_: x for k_, x in {f"finger_{k}.{sd}": a, f"claw_{k}.{sd}": 1 - a}.items() if x > 0.001}
        rep[k] = len(ns)
    top = max(NCO[n].z for n in th); tipn = min(th, key=lambda n: NCO[n].z)
    bone(f"thumb.{sd}", centroid(band(th, top - 0.05, top)), NCO[tipn], f"fist.{sd}")
    rigid(th, f"thumb.{sd}")
    rep.update(palm=len(palm), arm=len(arm), thumb=len(th)); report[sd] = rep

# ---------------------------------------------------------------- the cloak: the mantle's chains and the back sheet
body_nodes = [n for s in SHELLS if not (set(s) & used) for n in s]
AX = V(0, 0.05, 0)
SECT = {"cloak_side{}.L": 0, "cloak_back{}.L": 45, "cloak_back{}": 90, "cloak_back{}.R": 135,
        "cloak_side{}.R": 180, "cloak_front{}.R": 225, "cloak_front{}": 270, "cloak_front{}.L": 315}
STRIP_Z = (2.30, 1.98, 1.60)
DEF_R = {0: (.62, 1.0, 1.0), 45: (.6, .8, .85), 90: (.5, .6, .65), 135: (.6, .8, .85), 180: (.62, 1.0, 1.0),
         225: (.55, .7, .75), 270: (.45, .5, .55), 315: (.55, .7, .75)}
# The body shell is the cloak and, inside it, the dark stone torso, fused here and there. A point is cloth when it is
# painted pale or lies on the pale cloth (its dark inner side), or when it belongs to the long back sheet (all of it,
# its dark ring too: told by where it hangs). The rest is stone, on the torso's bones by height; the hood is the head's.
THICK = 0.08
def sheet_y(z): return 0.62 + (1.60 - z) * 0.21          # the back sheet's line, seen from the side
def in_sheet(co):
    if co.z >= 1.72: return False
    return co.y > (sheet_y(co.z) - 0.27 if co.z > 1.25 else 0.30)
kdp = kdtree.KDTree(len(body_nodes))
for n in body_nodes:
    if NPALE[n] > 0.5 and NCO[n].z <= 2.44: kdp.insert(NCO[n], n)
kdp.balance()
core_set = set()
for n in body_nodes:
    co = NCO[n]
    front = co.y < -0.2 and 1.55 < co.z < 2.4 and (abs(co.x) < 0.30 or (abs(co.x) < 0.42 and NPALE[n] <= 0.5))        # the chest's stone face and its core
    if co.z > 2.44 or front or (not in_sheet(co) and ((co.z < 1.45 and co.y < 0.1) or (NPALE[n] <= 0.5 and kdp.find(co)[2] >= THICK))): core_set.add(n)
cloth = [n for n in body_nodes if n not in core_set]
CHAINS = {}
for fmt, ang in SECT.items():
    pts = []
    for k, z in enumerate(STRIP_Z):
        rs = []
        for n in cloth:
            co = NCO[n]
            if abs(co.z - z) < 0.10:
                a = math.degrees(math.atan2(co.y - AX.y, co.x - AX.x)) % 360
                if min(abs(a - ang), 360 - abs(a - ang)) < 22.5: rs.append(math.hypot(co.x - AX.x, co.y - AX.y))
        r = float(np.median(rs)) if len(rs) >= 6 else DEF_R[ang][k]
        pts.append(V(AX.x + r * math.cos(math.radians(ang)), AX.y + r * math.sin(math.radians(ang)), z))
    CHAINS[fmt] = pts
    for i in range(2):
        bone(fmt.format(i + 1), pts[i], pts[i + 1], "chest" if i == 0 else fmt.format(i))
TAIL = [CHAINS["cloak_back{}"][2], V(0.05, 0.72, 1.15), V(0.05, 0.83, 0.70), V(0.05, 0.90, 0.38), V(0.05, 0.96, 0.0)]
for i in range(4):
    bone(f"tail{i+1}", TAIL[i], TAIL[i + 1], "cloak_back2" if i == 0 else f"tail{i}")
def strip_w(co):
    ds = []
    for fmt, pts in CHAINS.items():
        i = 0 if co.z >= pts[1].z else 1
        t = max(-0.3, min(1.3, (pts[i].z - co.z) / (pts[i].z - pts[i + 1].z)))
        p = pts[i].lerp(pts[i + 1], t)
        ds.append((math.hypot(co.x - p.x, co.y - p.y), fmt))
    ds.sort(); out = {}
    k3 = 1.0 / (ds[2][0] ** 2 + 0.01) ** 1.5
    ws = [1.0 / (d * d + 0.01) ** 1.5 - k3 for d, _ in ds[:2]]; s = sum(ws) or 1.0
    a = smooth((co.z - (STRIP_Z[1] - 0.12)) / 0.24)
    for (d, fmt), w in zip(ds[:2], ws):
        for n, x in ((fmt.format(1), a), (fmt.format(2), 1 - a)):
            if x > 0.001: out[n] = out.get(n, 0.0) + x * w / s
    return out
def tail_w(z):
    out = {}; up = 1.0
    for i in range(4):
        zj = TAIL[i + 1].z; s = smooth((z - (zj - 0.10)) / 0.20) if i < 3 else 1.0
        if up * s > 0.001: out[f"tail{i+1}"] = up * s
        up *= 1 - s
    return out
def mix(a, b, t):
    out = {}
    for n, x in a.items(): out[n] = out.get(n, 0.0) + x * (1 - t)
    for n, x in b.items(): out[n] = out.get(n, 0.0) + x * t
    return {n: x for n, x in out.items() if x > 0.002}
CORE_C = V(0, -0.45, 1.95)
cnt = {"core": 0, "cloth": 0, "sheet": 0, "gem": 0}
NW = {}; fixed = set()
for n in body_nodes:
    co = NCO[n]
    if n in core_set:
        w = height_w(co.z); cnt["core"] += 1
        if (co - CORE_C).length < 0.28 and co.y < -0.25 and (abs(co.x) < 0.30 or NPALE[n] <= 0.5): w = {"core": 1.0}; cnt["gem"] += 1; fixed.add(n)
    else:
        w = mix(height_w(co.z), strip_w(co), smooth((2.40 - co.z) / 0.22)); cnt["cloth"] += 1
        if in_sheet(co):
            t = smooth((1.70 - co.z) / 0.16) * (smooth((co.y - (sheet_y(co.z) - 0.27)) / 0.2) if co.z > 1.25 else 1.0)   # eased in from the side hems
            if t > 0: w = mix(w, tail_w(co.z), t); cnt["sheet"] += 1
    NW[n] = w
# The cloth is fused to the stone in places: the weights are spread a few edges across every such seam, so the cloth
# gives beside it instead of one edge taking the whole swing.
for it in range(4):
    new = {}
    for n in body_nodes:
        if n in fixed or not nb[n]: new[n] = NW[n]; continue
        acc = {}
        for k_, x in NW[n].items(): acc[k_] = acc.get(k_, 0.0) + 0.5 * x
        for j in nb[n]:
            for k_, x in NW[j].items(): acc[k_] = acc.get(k_, 0.0) + 0.5 * x / len(nb[n])
        new[n] = {k_: x for k_, x in acc.items() if x > 0.004}
    NW = new
for n in body_nodes:
    for i in nodes[n]: W[i] = NW[n]
report["body"] = cnt

# ---------------------------------------------------------------- build
arm = bpy.data.armatures.new("Rig"); rig = bpy.data.objects.new("Rig", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in BONES:
    eb = arm.edit_bones.new(name); eb.head = h; eb.tail = t if (t - h).length > 0.03 else h + V(0, 0, -0.05)
    if par: eb.parent = arm.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
for name, *_ in BONES:
    if name != "root": mesh.vertex_groups.new(name=name)
missing = 0
for v in me.vertices:
    w = W.get(v.index)
    if not w: missing += 1; w = {"body": 1.0}
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]; s = sum(x for _, x in top) or 1.0
    for n, x in top: mesh.vertex_groups[n].add([v.index], x / s, 'REPLACE')
mesh.name = "final_boss_phase3"; mesh.parent = rig
md = mesh.modifiers.new("Armature", 'ARMATURE'); md.object = rig
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "rig.blend"))
zdlib.emit({"bones": len(arm.bones), "verts": len(me.vertices), "tris": sum(len(p.vertices) - 2 for p in me.polygons),
            "missing": missing, "cut_edges": len(cut), "report": report,
            "chains": {k: [[round(x, 2) for x in p] for p in v] for k, v in CHAINS.items()},
            "bone_heads": {n: [round(x, 2) for x in h] + [round(x, 2) for x in t] for n, h, t, _ in BONES if "fist" in n or "wrist" in n or "forearm" in n or "finger" in n or "thumb" in n or "claw" in n or "halo" in n or "spike" in n or "tag" in n}})
