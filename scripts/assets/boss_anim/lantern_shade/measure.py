import bpy, bmesh, json
from mathutils import Vector
out = {}
for o in bpy.data.objects:
    if o.type != 'MESH': continue
    mw = o.matrix_world
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(mw)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.verts.ensure_lookup_table()
    seen = set(); comps = []
    for v0 in bm.verts:
        if v0.index in seen: continue
        comp = [v0]; seen.add(v0.index); i = 0
        while i < len(comp):
            for e in comp[i].link_edges:
                u = e.other_vert(comp[i])
                if u.index not in seen: seen.add(u.index); comp.append(u)
            i += 1
        cs = [u.co for u in comp]
        comps.append({"n": len(comp), "min": [round(min(c[i] for c in cs), 2) for i in range(3)],
                      "max": [round(max(c[i] for c in cs), 2) for i in range(3)]})
    comps.sort(key=lambda d: -d["n"])
    d = {"verts": len(o.data.vertices), "welded": len(bm.verts), "tris": sum(len(p.vertices) - 2 for p in o.data.polygons),
         "parent": o.parent.name if o.parent else None, "mats": [s.material.name if s.material else None for s in o.material_slots],
         "ncomps": len(comps), "comps": comps[:40]}
    # slices along z: centroid and extents
    sl = []
    if o.name in ("ArmL", "ArmR", "HandLantern"):
        zs = sorted(v.co.z for v in bm.verts); z0, z1 = zs[0], zs[-1]
        k = 14
        for i in range(k):
            a = z0 + (z1 - z0) * i / k; b = z0 + (z1 - z0) * (i + 1) / k
            vs = [v.co for v in bm.verts if a <= v.co.z <= b]
            if vs:
                c = sum(vs, Vector()) / len(vs)
                sl.append([round(a, 2), round(b, 2), len(vs), [round(x, 2) for x in c],
                           [round(min(v.x for v in vs), 2), round(max(v.x for v in vs), 2), round(min(v.y for v in vs), 2), round(max(v.y for v in vs), 2)]])
    d["slices"] = sl
    out[o.name] = d
    bm.free()
print("JSON>>" + json.dumps(out))
