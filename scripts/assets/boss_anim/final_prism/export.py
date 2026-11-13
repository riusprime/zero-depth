"""anim.blend -> final_boss_prism_anim.glb, at the delivered size and facing (the work frame is ten times it, turned).

The rig and the mesh are turned and scaled back and the change applied, the keyed offsets scaled with them. The
exporter samples every bone; the tracks of the bone the game drives (`shards`, the orbit) are then taken out of the
file, so no animation of it touches it (the `shard_NN` bones keep theirs: offsets inside the orbit). Then the file is read back and compared with the delivered one.
"""
import bpy, sys, os, json, struct
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, plib
from mathutils import Vector
here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
path = os.path.join(here, "final_boss_prism_anim.glb")
SRC = os.path.join(here, "..", "..", "..", "assets", "models", "bosses", "final_boss_prism.glb")
rig = bpy.data.objects["Rig"]; rig.animation_data.action = None
mesh = [o for o in bpy.data.objects if o.type == 'MESH'][0]
for b in rig.data.bones: b.name = b.name.replace(".", "_")   # Godot keeps bone names as written; dots read as paths
for pb in rig.pose.bones: pb.matrix_basis.identity()
inv = plib.TO_WORK.inverted(); k = inv.to_scale()[0]
rig.matrix_world = inv
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
def fcurves(act):
    if getattr(act, "layers", None):
        for L in act.layers:
            for st in L.strips:
                for cb in st.channelbags:
                    yield from cb.fcurves
    else: yield from act.fcurves
nloc = 0
for act in bpy.data.actions:
    for fc in fcurves(act):
        if fc.data_path.endswith(".location"):
            nloc += 1
            for kp in fc.keyframe_points:
                kp.co.y *= k; kp.handle_left.y *= k; kp.handle_right.y *= k
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
    export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True, export_yup=True)

# ---- take the game's bones out of every animation
with open(path, "rb") as f: data = f.read()
magic, ver, total = struct.unpack_from("<III", data, 0)
jl, jt = struct.unpack_from("<II", data, 12); js = json.loads(data[20:20 + jl].decode("utf8")); rest = data[20 + jl:]
game = {i for i, n in enumerate(js["nodes"]) if n.get("name") == "shards"}
dropped = 0; tracks = {}
for an in js.get("animations", []):
    keep = [c for c in an["channels"] if c["target"]["node"] not in game]
    dropped += len(an["channels"]) - len(keep); an["channels"] = keep
    tracks[an["name"]] = len(keep)
jb = json.dumps(js, separators=(",", ":")).encode("utf8"); jb += b" " * ((4 - len(jb) % 4) % 4)
with open(path, "wb") as f:
    f.write(struct.pack("<III", magic, ver, 12 + 8 + len(jb) + len(rest))); f.write(struct.pack("<II", len(jb), jt)); f.write(jb); f.write(rest)

# ---- read it back, beside the delivered file
def info(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    bpy.context.view_layer.update()
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith('Icosphere')]
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    pts = [o.matrix_world @ v.co for o in ms for v in o.data.vertices]
    d = {"bytes": os.path.getsize(p), "meshes": [o.name for o in ms], "verts": len(pts),
         "tris": sum(len(q.vertices) - 2 for o in ms for q in o.data.polygons),
         "min": [round(min(q[i] for q in pts), 4) for i in range(3)], "max": [round(max(q[i] for q in pts), 4) for i in range(3)],
         "materials": [s.material.name for o in ms for s in o.material_slots if s.material], "images": {i.name: list(i.size) for i in bpy.data.images},
         "bones": sum(len(a.data.bones) for a in arms), "max_influences": max(len(v.groups) for o in ms for v in o.data.vertices) if arms else 0,
         "node_rot": [[round(x, 3) for x in o.matrix_world.to_euler()] for o in ms + arms],
         "actions": {a.name: [round(x / 30, 2) for x in a.frame_range] for a in bpy.data.actions}}
    return d, sorted((round(q.x, 4), round(q.y, 4), round(q.z, 4)) for q in pts)
new, pn = info(path); old, po = info(SRC)
dev = max((Vector(a) - Vector(b)).length for a, b in zip(pn, po)) if len(pn) == len(po) else None
zdlib.emit({"new": new, "old": old, "location_curves_scaled": nloc, "game_tracks_removed": dropped, "tracks_left": tracks,
            "rest_pose_max_distance_from_delivered": dev})
