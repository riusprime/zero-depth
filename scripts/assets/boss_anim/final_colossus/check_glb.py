import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
def info(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'Icosphere']
    return {"bytes": os.path.getsize(path), "meshes": {o.name: [len(o.data.vertices), sum(len(p.vertices) - 2 for p in o.data.polygons), len(o.vertex_groups)] for o in ms},
            "images": {i.name: list(i.size) for i in bpy.data.images}, "materials": [m.name for m in bpy.data.materials]}
zdlib.emit({"new": info(os.path.join(here, "boss_twin_warden_amber_anim.glb")),
            "old": info(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "boss_twin_warden_amber.glb"))})
