"""Cut rigid pieces (the spear, the shield, the shoulder plates) out of the fused shell into their own closed pieces.

After plates.py (the Twin Wardens'): the piece's faces are split off and weighted wholly to its bone, and both open
rims (the piece's and the hole left in the body) are closed with a fan of faces, so nothing joins the two and neither
shows a hole. The body's side keeps the weights it had.
"""
import bpy, bmesh
from mathutils import Vector


def _key(v):
    return (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))


def cut(mesh, pieces, body_rim=None, dark=None):
    """pieces: {bone name: set of vertex indices}. Returns counts per piece."""
    me = mesh.data
    gidx = {g.name: g.index for g in mesh.vertex_groups}
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    dl = bm.verts.layers.deform.verify(); uvl = bm.loops.layers.uv.active
    picked = {bone: {bm.verts[i] for i in idx} for bone, idx in pieces.items()}
    report = {}
    for bone, C in picked.items():
        F = [f for f in bm.faces if all(v in C for v in f.verts)]
        Fset = set(F)
        border = [e for e in bm.edges if any(f in Fset for f in e.link_faces) and any(f not in Fset for f in e.link_faces)]
        if border: bmesh.ops.split_edges(bm, edges=border)
        plate_verts = {v for f in F for v in f.verts}
        for v in [v for v in plate_verts if any(f not in Fset for f in v.link_faces)]:
            bmesh.utils.vert_separate(v, v.link_edges)       # a corner the edge split left joined
        plate_verts = {v for f in F for v in f.verts}
        for v in plate_verts:
            v[dl].clear(); v[dl][gidx[bone]] = 1.0
        # The rim: the piece's edges that lie on a body edge.
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
        if body_rim:
            rk = {p for k in rim for p in k}
            for v in bm.verts:                               # every copy of a rim point on the body's side
                if v in plate_verts or _key(v) not in rk: continue
                nw = body_rim(bone, v.co, v[dl])
                if nw:
                    v[dl].clear()
                    for n_, x_ in nw.items(): v[dl][gidx[n_]] = x_
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
            acc = {}
            for k in ks:
                for v in be[k]:
                    for g, wt in v[dl].items(): acc[g] = acc.get(g, 0.0) + wt
            top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]; tot = sum(x for _, x in top) or 1.0
            cb = bm.verts.new(c); cp = bm.verts.new(c)
            for g, wt in top: cb[dl][g] = wt / tot
            cp[dl][gidx[bone]] = 1.0
            for k in ks:
                for (a, b), mid in ((be[k], cb), (pe[k], cp)):
                    try: nf = bm.faces.new((b, a, mid))      # against the neighbour's winding: it faces the same way out
                    except ValueError: continue
                    nf.smooth = False
                    src = {}
                    for v in (a, b):                          # the patch carries the colour of the rim it grows from
                        for l in v.link_loops:
                            if l.face is not nf: src[v] = l[uvl].uv.copy(); break
                    for l in nf.loops:
                        # the body's side of the cut is the dark under-armour; the piece's side carries its rim's colour
                        l[uvl].uv = dark if (dark is not None and mid is cb) else src.get(l.vert, src.get(a, src.get(b)))
                    caps += 1
        report[bone] = {"faces": len(F), "rim_edges": len(rim), "loops": len(loops), "cap_faces": caps}
    bm.to_mesh(me); bm.free(); me.update()
    return report
