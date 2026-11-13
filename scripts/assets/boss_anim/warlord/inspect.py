import bpy, json
from mathutils import Vector
out = {"objects": [], "actions": [a.name for a in bpy.data.actions]}
for o in bpy.data.objects:
    d = {"name": o.name, "type": o.type, "parent": o.parent.name if o.parent else None,
         "loc": [round(v,3) for v in o.location], "scale": [round(v,3) for v in o.scale]}
    if o.type == 'MESH':
        m = o.data
        ws = [o.matrix_world @ v.co for v in m.vertices]
        d.update(verts=len(m.vertices), tris=sum(len(p.vertices)-2 for p in m.polygons),
                 bbmin=[round(min(v[i] for v in ws),3) for i in range(3)], bbmax=[round(max(v[i] for v in ws),3) for i in range(3)],
                 vgroups=len(o.vertex_groups), mods=[md.type for md in o.modifiers], mats=[s.material.name if s.material else None for s in o.material_slots])
        cnt = {}
        for v in m.vertices:
            if v.groups:
                g = max(v.groups, key=lambda g: g.weight)
                n = o.vertex_groups[g.group].name
                cnt[n] = cnt.get(n,0)+1
        d["dominant"] = dict(sorted(cnt.items(), key=lambda kv:-kv[1])[:12])
    if o.type == 'ARMATURE':
        d["bones"] = {b.name: [round(v,3) for v in (o.matrix_world @ b.head_local)] for b in o.data.bones}
    out["objects"].append(d)
print("JSON>>" + json.dumps(out))
