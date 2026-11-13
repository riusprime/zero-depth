"""anim.blend -> final_boss_nemesis_anim.glb at the delivered size and facing (0.19 units tall, facing +X), then read
it back and report what is in it against the delivered file."""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
path = os.path.join(here, "final_boss_nemesis_anim.glb")
delivered = os.path.abspath(os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "final_boss_nemesis.glb"))
K = 1.5 / 0.19
WORK = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(K, 4)
rig = bpy.data.objects["Rig"]; rig.animation_data.action = None
mesh = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig][0]
for o in list(bpy.data.objects):
    if o not in (rig, mesh): bpy.data.objects.remove(o)
for tr in list(rig.animation_data.nla_tracks):
    if tr.name == "test": rig.animation_data.nla_tracks.remove(tr)
if bpy.data.actions.get("test"): bpy.data.actions.remove(bpy.data.actions["test"])
for b in rig.data.bones: b.name = b.name.replace(".", "_")   # Godot keeps bone names as written; dots read as paths
for pb in rig.pose.bones: pb.matrix_basis.identity()
# back to the delivered frame: the skeleton and the mesh are scaled and turned, and every keyed offset with them
rig.matrix_world = WORK.inverted()
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
def curves(act):
    out = []
    if hasattr(act, "layers"):
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags: out += list(bag.fcurves)
    else: out = list(act.fcurves)
    return out
nloc = 0
for act in bpy.data.actions:
    for fc in curves(act):
        if fc.data_path.endswith(".location"):
            nloc += 1
            for kp in fc.keyframe_points:
                kp.co.y /= K; kp.handle_left.y /= K; kp.handle_right.y /= K
            fc.update()
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
    export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True, export_yup=True)
def info(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    out = {"bytes": os.path.getsize(p), "nodes": {o.name: [o.type, o.parent.name if o.parent else None, [round(x, 4) for x in o.matrix_world.to_euler()], [round(x, 4) for x in o.matrix_world.to_scale()]] for o in bpy.data.objects if not o.name.startswith("Icosphere")}}
    for o in bpy.data.objects:
        if o.type == 'MESH' and not o.name.startswith("Icosphere"):
            ws = [o.matrix_world @ v.co for v in o.data.vertices]
            out["mesh"] = {"name": o.name, "verts": len(ws), "tris": sum(len(q.vertices) - 2 for q in o.data.polygons), "groups": len(o.vertex_groups),
                           "min": [round(min(v[i] for v in ws), 4) for i in range(3)], "max": [round(max(v[i] for v in ws), 4) for i in range(3)],
                           "materials": [s.material.name for s in o.material_slots]}
        if o.type == 'ARMATURE':
            out["bones"] = len(o.data.bones)
            hb = o.data.bones.get("hand_R")
            if hb: out["hand_R_head"] = [round(x, 4) for x in (o.matrix_world @ hb.head_local)]; out["hand_R_tail"] = [round(x, 4) for x in (o.matrix_world @ hb.tail_local)]
    out["images"] = {i.name: list(i.size) for i in bpy.data.images}
    out["actions"] = {a.name: [round(x) for x in a.frame_range] for a in bpy.data.actions}
    return out
zdlib.emit({"location_curves_scaled": nloc, "new": info(path), "delivered": info(delivered)})
