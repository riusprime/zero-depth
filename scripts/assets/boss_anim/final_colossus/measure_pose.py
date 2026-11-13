"""anim.blend: the numbers of one frame of one action (work space: x10 the delivered units, facing -Y).  -- <action> <frame>"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
rig = bpy.data.objects["Rig"]; rig.animation_data.action = bpy.data.actions[a[0]]
sc = bpy.context.scene; sc.frame_set(int(a[1])); bpy.context.view_layer.update()
m = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig][0]
out = {}
for n in ("body", "spine", "chest", "neck", "head", "halo", "halo.L", "halo.R", "fist.L", "fist.R", "forearm.L", "forearm.R"):
    pb = rig.pose.bones[n]; b = rig.data.bones[n]
    R = pb.matrix.to_3x3() @ b.matrix_local.to_3x3().inverted()            # the bone's turn from rest, armature space
    up = R @ Vector((0, 0, 1)); fwd = R @ Vector((0, -1, 0))
    out[n] = {"head": [round(x, 2) for x in pb.head], "rest_head": [round(x, 2) for x in b.head_local],
              "pitch_forward_deg": round(math.degrees(math.atan2(-up.y, up.z)), 1), "roll_deg": round(math.degrees(math.atan2(up.x, up.z)), 1),
              "yaw_deg": round(math.degrees(math.atan2(fwd.x, -fwd.y)), 1)}
dg = bpy.context.evaluated_depsgraph_get(); ev = m.evaluated_get(dg)
gi = {g.index: g.name for g in m.vertex_groups}
box = {}
for v, v0 in zip(ev.data.vertices, m.data.vertices):
    if not v0.groups: continue
    n = gi[max(v0.groups, key=lambda g: g.weight).group]
    grp = "fist_R" if n.endswith(".R") and n.split(".")[0] in ("fist", "wrist", "forearm", "thumb") or (n.endswith(".R") and n[:4] in ("fing", "claw")) else \
          "fist_L" if n.endswith(".L") and (n.split(".")[0] in ("fist", "wrist", "forearm", "thumb") or n[:4] in ("fing", "claw")) else \
          "hood" if n == "head" else "halo" if n.startswith("halo") else "rest"
    b = box.setdefault(grp, [[9, 9, 9], [-9, -9, -9]])
    for i in range(3): b[0][i] = min(b[0][i], v.co[i]); b[1][i] = max(b[1][i], v.co[i])
    b = box.setdefault("all", [[9, 9, 9], [-9, -9, -9]])
    for i in range(3): b[0][i] = min(b[0][i], v.co[i]); b[1][i] = max(b[1][i], v.co[i])
out["boxes_min_max"] = {k: [[round(x, 2) for x in v[0]], [round(x, 2) for x in v[1]]] for k, v in box.items()}
zdlib.emit(out)
