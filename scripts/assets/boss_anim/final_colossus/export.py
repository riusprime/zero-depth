"""anim.blend -> final_colossus_anim.glb, at the delivered size and facing.

The work space is the delivered model turned to face -Y and scaled x10. Here the mesh and the skeleton are turned and
scaled back (their data, not their objects: no node carries a transform) and every keyed location is scaled with them.
Then the file is read back and compared with the delivered one.
"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix, Vector
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
path = os.path.join(here, os.path.basename(here) + "_anim.glb")
DELIVERED = os.path.abspath(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "final_boss_colossus.glb"))
rig = bpy.data.objects["Rig"]; rig.animation_data.action = None
mesh = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig][0]
for o in list(bpy.data.objects):
    if o not in (rig, mesh): bpy.data.objects.remove(o)
for b in rig.data.bones: b.name = b.name.replace(".", "_")   # Godot keeps bone names as written; dots read as paths
for pb in rig.pose.bones: pb.matrix_basis.identity()
S = 0.1
T = Matrix.Scale(S, 4) @ Matrix.Rotation(math.radians(90), 4, 'Z')
mesh.data.transform(T); rig.data.transform(T)
def fcurves(act):
    if getattr(act, "layers", None):
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags: yield from cb.fcurves
    else: yield from act.fcurves
nloc = 0
for act in bpy.data.actions:
    for fc in fcurves(act):
        if fc.data_path.endswith(".location"):
            nloc += 1
            for kp in fc.keyframe_points:
                kp.co.y *= S; kp.handle_left.y *= S; kp.handle_right.y *= S
            fc.update()
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
    export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True, export_yup=True)

def info(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'Icosphere']
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    for a in arms:                                   # the rest pose, not whichever action the importer left on
        if a.animation_data: a.animation_data.action = None
        for tr in (a.animation_data.nla_tracks if a.animation_data else []): tr.mute = True
        for pb in a.pose.bones: pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    m = ms[0]; dg = bpy.context.evaluated_depsgraph_get(); ev = m.evaluated_get(dg)
    pts = [m.matrix_world @ v.co for v in ev.data.vertices]
    mn = [round(min(p[i] for p in pts), 4) for i in range(3)]; mx = [round(max(p[i] for p in pts), 4) for i in range(3)]
    return {"bytes": os.path.getsize(p), "meshes": {o.name: [len(o.data.vertices), sum(len(q.vertices) - 2 for q in o.data.polygons)] for o in ms},
            "bbox": [mn, mx], "bones": len(arms[0].data.bones) if arms else 0,
            "node_scale_rot": [[round(x, 4) for x in o.scale] + [round(x, 4) for x in o.rotation_euler] for o in ms + arms],
            "materials": [s.material.name for s in m.material_slots], "images": {i.name: list(i.size) for i in bpy.data.images if i.size[0]},
            "actions": {a.name: [round(x) for x in a.frame_range] for a in bpy.data.actions},
            "has": [n for n in ("halo", "fist_L", "fist_R", "chest", "body", "head") if arms and n in arms[0].data.bones]}
new = info(path); old = info(DELIVERED)
zdlib.emit({"path": path, "location_curves_scaled": nloc, "new": new, "delivered": old})
