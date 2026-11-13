import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
path = os.path.join(here, os.path.basename(here) + "_anim.glb")
rig = zdlib.the_rig(); rig.animation_data.action = None
for b in rig.data.bones: b.name = b.name.replace(".", "_")   # Godot keeps bone names as written; dots read as paths
for pb in rig.pose.bones: pb.matrix_basis.identity()
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
    export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True, export_yup=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
me = [o for o in bpy.data.objects if o.type == 'MESH'][0]
zdlib.emit({"bytes": os.path.getsize(path), "bones": len(arm.data.bones), "verts": len(me.data.vertices),
            "actions": {a.name: [round(x) for x in a.frame_range] for a in bpy.data.actions}})
