"""The exported file against the delivered one: meshes, triangles, size, facing, textures, skeleton, animations."""
import bpy, sys, os
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
def info(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    bpy.context.view_layer.update()
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith('Icosphere')]
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    pts = [o.matrix_world @ v.co for o in ms for v in o.data.vertices]
    lo = [round(min(p[i] for p in pts), 3) for i in range(3)]; hi = [round(max(p[i] for p in pts), 3) for i in range(3)]
    return {"bytes": os.path.getsize(path),
            "meshes": {o.name: {"verts": len(o.data.vertices), "tris": sum(len(p.vertices) - 2 for p in o.data.polygons),
                                "groups": len(o.vertex_groups), "max_influences": max((len(v.groups) for v in o.data.vertices), default=0),
                                "unweighted": sum(1 for v in o.data.vertices if not v.groups) if o.vertex_groups else None,
                                "materials": [s.material.name for s in o.material_slots if s.material]} for o in ms},
            "tris_total": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in ms),
            "bbox_min": lo, "bbox_max": hi,
            "armatures": {a.name: len(a.data.bones) for a in arms},
            "bones": sorted(b.name for a in arms for b in a.data.bones),
            "images": {i.name: list(i.size) for i in bpy.data.images},
            "actions": {a.name: [round(x / bpy.context.scene.render.fps, 2) for x in a.frame_range] for a in bpy.data.actions}}
new = info(os.path.join(here, "lantern_shade_anim.glb"))
old = info(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "boss_lantern_shade.glb"))
old.pop("bones")
zdlib.emit({"new": new, "old": old})
