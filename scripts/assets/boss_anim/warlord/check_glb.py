"""Compare the exported file with the delivered one (each imported into an empty scene)."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
def info(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'Icosphere']
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    m = ms[0]; ws = [m.matrix_world @ v.co for v in m.data.vertices]
    a = arm[0]
    def bh(n):
        b = a.data.bones.get(n); return [round(x, 4) for x in (a.matrix_world @ b.head_local)] if b else None
    def bx(n):
        b = a.data.bones.get(n); return [round(x, 3) for x in (a.matrix_world.to_3x3() @ b.matrix_local.to_3x3().col[1])] if b else None
    return {"bytes": os.path.getsize(path), "objects": [(o.name, o.type, o.parent.name if o.parent else None, [round(x, 4) for x in o.matrix_world.to_euler()], [round(x, 4) for x in o.matrix_world.to_scale()]) for o in bpy.data.objects if o.name != 'Icosphere'],
            "mesh": [len(m.data.vertices), sum(len(p.vertices) - 2 for p in m.data.polygons), len(m.vertex_groups)],
            "bbmin": [round(min(v[i] for v in ws), 3) for i in range(3)], "bbmax": [round(max(v[i] for v in ws), 3) for i in range(3)],
            "images": {i.name: list(i.size) for i in bpy.data.images}, "materials": [x.name for x in bpy.data.materials],
            "bones": len(a.data.bones), "names": sorted(b.name for b in a.data.bones),
            "R_Hand": bh("R_Hand"), "Head": bh("Head"), "L_Foot": bh("L_Foot"), "R_Hand_axis": bx("R_Hand"), "Spine01_axis": bx("Spine01"),
            "actions": {x.name: [round(v) for v in x.frame_range] for x in bpy.data.actions}}
new = info(os.path.join(here, "warlord_anim.glb"))
old = info(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "warlord.glb"))
missing = [n for n in old["names"] if n not in new["names"]]
added = [n for n in new["names"] if n not in old["names"]]
del new["names"]; del old["names"]
zdlib.emit({"new": new, "old": old, "delivered_names_missing": missing, "added": added})
