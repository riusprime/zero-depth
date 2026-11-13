"""Cut each shoulder plate out of the fused shell into its own closed piece, and close the body behind it.

The file is one skin, so a plate that turns on its own bone drags the arm's faces with it. Here the plate's faces are
split off, weighted wholly to the plate's bone, and both open rims (the plate's underside and the hole left in the
body) are closed with a fan of dark faces, so nothing joins the two and neither shows a hole.
"""
import bpy, bmesh
from mathutils import Vector


def _key(v):
    return (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))


def _dark_uv(me):
    """The UV of the darkest texel any corner of the mesh uses (the under-armour's black)."""
    img = None
    for mat in me.materials:
        if mat and mat.node_tree:
            for n in mat.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
                    img = n.image
    uvs = me.uv_layers.active.data
    if img is None or img.size[0] == 0:
        return uvs[0].uv.copy()
    w, h = img.size; px = img.pixels[:]
    best, best_l = None, 9.0
    for i in range(0, len(uvs), 7):
        u, v = uvs[i].uv
        x = min(w - 1, max(0, int(u % 1.0 * w))); y = min(h - 1, max(0, int(v % 1.0 * h)))
        k = (y * w + x) * 4
        lum = px[k] + px[k + 1] + px[k + 2]
        if lum < best_l: best, best_l = uvs[i].uv.copy(), lum
    return best


def cut(mesh, cand, allowed):
    """cand: {"R": set of vertex indices, "L": ...} the rule picked. Returns counts for the build's report."""
    me = mesh.data
    dark = _dark_uv(me)
    gidx = {g.name: g.index for g in mesh.vertex_groups}
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    dl = bm.verts.layers.deform.verify(); uvl = bm.loops.layers.uv.active
    report = {}
    # A plate is whole texture islands: an island joins the plate when most of its vertices were picked.
    island = {}; islands = []
    for v0 in bm.verts:
        if v0 in island: continue
        comp = [v0]; island[v0] = len(islands); i = 0
        while i < len(comp):
            for e in comp[i].link_edges:
                o = e.other_vert(comp[i])
                if o not in island: island[o] = len(islands); comp.append(o)
            i += 1
        islands.append(comp)
    for side, picked in cand.items():
        C = set()
        for comp in islands:
            n = sum(1 for v in comp if v.index in picked)
            if n * 2 > len(comp): C.update(v for v in comp if v.index in allowed[side])
        F = [f for f in bm.faces if all(v in C for v in f.verts)]
        Fset = set(F)
        border = [e for e in bm.edges if any(f in Fset for f in e.link_faces) and any(f not in Fset for f in e.link_faces)]
        if border: bmesh.ops.split_edges(bm, edges=border)
        plate_verts = {v for f in F for v in f.verts}
        shared = [v for v in plate_verts if any(f not in Fset for f in v.link_faces)]
        for v in shared:                       # a corner the edge split left joined
            bmesh.utils.vert_separate(v, v.link_edges)
        plate_verts = {v for f in F for v in f.verts}
        for v in plate_verts:
            v[dl].clear(); v[dl][gidx[f"pauldron.{side}"]] = 1.0
        # The body around the hole belongs to the torso: up here the collar, chest and back follow the shoulder
        # bone, and only below the plate does the skin go with the upper arm.
        ua, sh = gidx[f"upper_arm.{side}"], gidx[f"shoulder.{side}"]
        sign = -1.0 if side == "R" else 1.0
        for v in bm.verts:
            if v in plate_verts or ua not in v[dl]: continue
            if sign * (v.co.x + 0.05) < 0.1: continue
            keep = min(1.0, max(0.0, (1.42 - v.co.z) / 0.12))
            moved = v[dl][ua] * (1.0 - keep)
            if moved > 0.0:
                v[dl][ua] = v[dl][ua] * keep
                v[dl][sh] = v[dl].get(sh, 0.0) + moved
        # The rim: plate edges that lie on a body edge.
        pe, be = {}, {}
        for f in F:
            for l in f.loops:
                a, b = l.vert, l.link_loop_next.vert
                pe[frozenset((_key(a), _key(b)))] = (a, b)
        for f in bm.faces:
            if f in Fset: continue
            for l in f.loops:
                a, b = l.vert, l.link_loop_next.vert
                k = frozenset((_key(a), _key(b)))
                if k in pe and len(k) == 2: be[k] = (a, b)
        rim = [k for k in pe if k in be]
        # Group the rim into loops by shared points, and close each loop on both sides.
        parent = {}
        def find(x):
            while parent.setdefault(x, x) != x:
                parent[x] = parent[parent[x]]; x = parent[x]
            return x
        for k in rim:
            a, b = tuple(k); parent[find(a)] = find(b)
        loops = {}
        for k in rim: loops.setdefault(find(tuple(k)[0]), []).append(k)
        caps = 0
        for ks in loops.values():
            if len(ks) < 3: continue
            pts = {p for k in ks for p in k}
            c = sum((Vector(p) for p in pts), Vector()) / len(pts)
            # body side: the middle point moves with the average of the rim's weights
            acc = {}
            for k in ks:
                for v in be[k]:
                    for g, wt in v[dl].items(): acc[g] = acc.get(g, 0.0) + wt
            top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]; tot = sum(x for _, x in top) or 1.0
            cb = bm.verts.new(c); cp = bm.verts.new(c)
            for g, wt in top: cb[dl][g] = wt / tot
            cp[dl][gidx[f"pauldron.{side}"]] = 1.0
            for k in ks:
                for (a, b), mid in ((be[k], cb), (pe[k], cp)):
                    try: nf = bm.faces.new((b, a, mid))      # against the neighbour's winding: it faces the same way out
                    except ValueError: continue
                    nf.smooth = False
                    # Both patches carry the colour of the rim they grow from, so a gap shows stone and not a black hole.
                    src = {}
                    for v in (a, b):
                        for l in v.link_loops:
                            if l.face is not nf: src[v] = l[uvl].uv.copy(); break
                    for l in nf.loops:
                        l[uvl].uv = src.get(l.vert, src.get(a, dark))
                    caps += 1
        report[side] = {"plate_faces": len(F), "rim_edges": len(rim), "loops": len(loops), "cap_faces": caps}
    bm.to_mesh(me); bm.free(); me.update()
    return report
