import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
def info(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.polygons) > 100]
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in ms:
        ev = o.evaluated_get(dg); pts += [ev.matrix_world @ v.co for v in ev.data.vertices]
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    return {"bytes": os.path.getsize(path),
            "meshes": {o.name: [len(o.data.vertices), sum(len(p.vertices) - 2 for p in o.data.polygons), len(o.vertex_groups)] for o in ms},
            "tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in ms),
            "bbmin": [round(min(p[i] for p in pts), 3) for i in range(3)], "bbmax": [round(max(p[i] for p in pts), 3) for i in range(3)],
            "armatures": len(arm), "bones": sorted(b.name for b in arm[0].data.bones) if arm else [],
            "images": {i.name: list(i.size) for i in bpy.data.images}, "materials": [m.name for m in bpy.data.materials],
            "actions": {a.name: round((a.frame_range[1] - a.frame_range[0]) / bpy.context.scene.render.fps, 3) for a in bpy.data.actions}}
zdlib.emit({"new": info(os.path.join(here, "tidecaller_anim.glb"))})
zdlib.emit({"old": info(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "boss_tidecaller.glb"))})
