"""The exported file against the delivered one: meshes, triangles, bounds, skeleton, images, animations."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
def info(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'Icosphere']
    pts = [o.matrix_world @ v.co for o in ms for v in o.data.vertices]
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    return {"bytes": os.path.getsize(path),
            "meshes": {o.name: [len(o.data.vertices), sum(len(p.vertices) - 2 for p in o.data.polygons), len(o.vertex_groups)] for o in ms},
            "tris": sum(len(p.vertices) - 2 for o in ms for p in o.data.polygons),
            "min": [round(min(p[i] for p in pts), 3) for i in range(3)], "max": [round(max(p[i] for p in pts), 3) for i in range(3)],
            "skeletons": len(arms), "bones": sorted(b.name for a in arms for b in a.data.bones),
            "images": {i.name: list(i.size) for i in bpy.data.images}, "materials": [m.name for m in bpy.data.materials],
            "actions": sorted(a.name for a in bpy.data.actions)}
zdlib.emit({"new": info(os.path.join(here, "clockwork_judge_anim.glb")),
            "old": info(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "boss_clockwork_judge.glb"))})
