"""The exported file played back: the hood's height and the figure's lowest point (delivered units) at a clip's end."""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(here, "final_boss_prism_anim.glb"))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; m = [o for o in bpy.data.objects if o.type == 'MESH'][0]
gi = {g.name: g.index for g in m.vertex_groups}
def dom(v): return max(v.groups, key=lambda g: g.weight).group
head = [v.index for v in m.data.vertices if dom(v) == gi["head"]]
out = {}
for name in ("break", "form", "kneel", "idle"):
    act = bpy.data.actions[name]; arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    for f in (int(act.frame_range[0]), int(act.frame_range[1])):
        bpy.context.scene.frame_set(f)
        ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        out[f"{name}@{f}"] = {"hood_top": round(max((m.matrix_world @ ev.vertices[i].co).z for i in head), 4)}
pb = arm.pose.bones
zdlib.emit({"frames": out, "shard_bones_have_curves": sorted({fc.data_path.split('"')[1] for a in bpy.data.actions for L in a.layers for s in L.strips for cb in s.channelbags for fc in cb.fcurves if "shard" in fc.data_path}),
            "core_head": [round(x, 4) for x in (arm.matrix_world @ arm.data.bones["core"].head_local)],
            "shards_head": [round(x, 4) for x in (arm.matrix_world @ arm.data.bones["shards"].head_local)],
            "shard_heads": {b.name: [round(x, 4) for x in (arm.matrix_world @ b.head_local)] for b in arm.data.bones if b.name.startswith("shard_")}})
