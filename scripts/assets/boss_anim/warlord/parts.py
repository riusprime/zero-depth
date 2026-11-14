"""Which piece of the fused shell a vertex belongs to, by rule (positions at rest, model units: the figure is 1.0 tall
to its spear's tip, faces +X, its left is +Y).  classify(mesh) -> (part name per vertex ('' = body), redness per vertex).
The file splits vertices along texture seams, so everything is decided per position: vertices that share a point
always get the same part."""
import bpy
import numpy as np
from mathutils import Vector

# The spear's axis, measured on grid renders.
SP_A = Vector((0.072, -0.2375, 0.05)); SP_B = Vector((0.196, -0.303, 1.0))
SP_D = (SP_B - SP_A).normalized()
# The shield's chord seen from above: from its back edge to its front edge; n points out of its face.
SH_A = Vector((-0.08, 0.34)); SH_N = Vector((0.519, 0.855))


def spear_r(co):
    v = Vector(co) - SP_A
    return (v - SP_D * v.dot(SP_D)).length


def shield_s(co):
    return (Vector((co[0], co[1])) - SH_A).dot(SH_N)


def weld(me):
    """(group index per vertex, number of groups)."""
    key = {}; rep = []
    for v in me.vertices:
        k = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        rep.append(key.setdefault(k, len(key)))
    return rep, len(key)


def redness(me, rep, n):
    """Per position: how red the texture is there (cloth, crystal) rather than dark metal."""
    img = None
    for mat in me.materials:
        if mat and mat.node_tree:
            for nd in mat.node_tree.nodes:
                if nd.type == 'TEX_IMAGE' and nd.image: img = nd.image
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(px); px = px.reshape(h, w, 4)
    uv = me.uv_layers.active.data
    red = [0.0] * n; cnt = [0] * n
    for l in me.loops:
        u, v = uv[l.index].uv
        x = min(w - 1, max(0, int((u % 1.0) * w))); y = min(h - 1, max(0, int((v % 1.0) * h)))
        r, g, b = px[y, x, :3]
        red[rep[l.vertex_index]] += float(r - max(g, b)); cnt[rep[l.vertex_index]] += 1
    return [red[i] / max(cnt[i], 1) for i in range(n)]


def rule(co, isred, legw):
    x, y, z = co
    r = spear_r(co); s = shield_s(co)
    # The shield bows: towards its front and back edges its inner side lies further in than at the middle, where the
    # arm is. A leg never belongs to it (the delivered weights say what is a leg).
    u = (Vector((x, y)) - SH_A).dot(Vector((SH_N.y, -SH_N.x)))
    thr = -0.014 - 0.045 * min(1.0, max(0.0, (abs(u - 0.1445) - 0.045) / 0.05))
    if (z >= 0.655 and r < 0.085 and x > 0.115 and y < -0.17) or (0.028 < z < 0.17 and r < 0.03) \
            or (r < 0.024 and z > 0.028 and not (0.395 < z < 0.50)) or (r < 0.017 and z > 0.028):
        return 'spear'
    if z > 0.735 and abs(y) < 0.16 and x < 0.1: return 'plume'
    if 0.04 < z < 0.615 and y > 0.15 and s > thr and legw < 0.4 and not (z > 0.47 and s < 0.012 and isred): return 'shield'
    if 0.47 < z < 0.72 and y < -0.105 and x < 0.11 and isred: return 'pauldron_R'
    if 0.47 < z < 0.72 and y > 0.105 and x < 0.11 and isred: return 'pauldron_L'
    if x < (-0.06 if z > 0.13 else -0.10) and 0.04 < z < 0.62 and abs(y) < 0.26 and isred: return 'cape'
    if x > 0.04 and 0.05 < z < 0.41 and abs(y) < 0.11 and isred: return 'tabard'
    return ''


def classify(mesh):
    me = mesh.data
    rep, n = weld(me)
    red = redness(me, rep, n)
    pos = [None] * n
    for v in me.vertices: pos[rep[v.index]] = v.co
    gn = {g.index: g.name for g in mesh.vertex_groups}
    legw = [0.0] * n
    for v in me.vertices:
        legw[rep[v.index]] = sum(g.weight for g in v.groups if any(k in gn[g.group] for k in ("Thigh", "Calf", "Foot", "Toe", "Pelvis")))
    cls = [rule(pos[i], red[i] > 0.04, legw[i]) for i in range(n)]
    nb = [set() for _ in range(n)]
    for e in me.edges:
        a, b = rep[e.vertices[0]], rep[e.vertices[1]]
        if a != b: nb[a].add(b); nb[b].add(a)
    for _ in range(3):                      # a speck takes the part of most of its neighbours
        new = list(cls)
        for i in range(n):
            if not nb[i]: continue
            cnt = {}
            for j in nb[i]: cnt[cls[j]] = cnt.get(cls[j], 0) + 1
            c, k = max(cnt.items(), key=lambda kv: kv[1])
            if c != cls[i] and k * 3 >= len(nb[i]) * 2 and cls[i] != 'spear' and c != 'spear': new[i] = c
        cls = new
    # A shoulder plate's dark trim and rivets are not red: a point inside the plate's box that the plate half
    # surrounds belongs to it.
    for _ in range(3):
        new = list(cls)
        for i in range(n):
            x, y, z = pos[i]
            if cls[i] in ('', 'cape') and 0.47 < z < 0.72 and abs(y) > 0.105 and x < 0.11 and nb[i]:
                want = 'pauldron_R' if y < 0 else 'pauldron_L'
                if sum(1 for j in nb[i] if cls[j] == want) * 2 >= len(nb[i]): new[i] = want
        cls = new
    # A piece is big: a few stray points the rules picked far from it (a red glint on a boot) go back to the body.
    seen = [False] * n
    for i in range(n):
        if seen[i] or not cls[i]: continue
        comp = [i]; seen[i] = True; k = 0
        while k < len(comp):
            for j in nb[comp[k]]:
                if not seen[j] and cls[j] == cls[i]: seen[j] = True; comp.append(j)
            k += 1
        if len(comp) < (120 if cls[i] in ('cape', 'tabard') else 25):
            for j in comp: cls[j] = ''
    return [cls[rep[v.index]] for v in me.vertices], [red[rep[v.index]] for v in me.vertices]


def dark_uv(me):
    """The UV of the darkest texel the mesh uses (the under-armour's black), for faces that close a hole."""
    img = None
    for mat in me.materials:
        if mat and mat.node_tree:
            for nd in mat.node_tree.nodes:
                if nd.type == 'TEX_IMAGE' and nd.image: img = nd.image
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(px); px = px.reshape(h, w, 4)
    uvs = me.uv_layers.active.data
    best, best_l = None, 9.0
    for i in range(0, len(uvs), 5):
        u, v = uvs[i].uv
        x = min(w - 1, max(0, int((u % 1.0) * w))); y = min(h - 1, max(0, int((v % 1.0) * h)))
        lum = float(px[y, x, 0] + px[y, x, 1] + px[y, x, 2])
        if lum < best_l: best, best_l = uvs[i].uv.copy(), lum
    return best
