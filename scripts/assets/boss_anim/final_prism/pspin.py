"""anim.blend: do the loops close (the skinned mesh on the last frame against the first), and how round is each spun
crystal about its own axis (a round one hardly shows its turn)? Also each clip's first and last crystal angles."""
import bpy, sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
rig = bpy.data.objects["Rig"]; m = [o for o in bpy.data.objects if o.type == "MESH"][0]; me = m.data
sc = bpy.context.scene
def shape(f):
    sc.frame_set(f)
    ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    a = np.zeros(len(ev.vertices) * 3); ev.vertices.foreach_get("co", a); return a.reshape(-1, 3)
seam = {}
for name in ("idle", "walk"):
    act = bpy.data.actions[name]; rig.animation_data.action = act
    a, b, mid = shape(0), shape(int(act.frame_range[1])), shape(int(act.frame_range[1]) // 4)
    seam[name] = {"last_vs_first_max_m": round(float(np.abs(a - b).max()), 5), "quarter_vs_first_max_m": round(float(np.linalg.norm(a - mid, axis=1).max()), 3)}
ends = {}
for act in bpy.data.actions:
    if act.name.startswith("__"): continue
    rig.animation_data.action = act; row = {}
    for f in (int(act.frame_range[0]), int(act.frame_range[1])):
        sc.frame_set(f); pb = rig.pose.bones["shard_02"]
        q = pb.rotation_quaternion; row[f] = [round(x, 3) for x in q]
    ends[act.name] = row
gi = {g.index: g.name for g in m.vertex_groups}
pts = {}
for v in me.vertices:
    n = gi[max(v.groups, key=lambda g: g.weight).group]
    if n.startswith("shard_") or n.startswith("crown") or (n.startswith("spike") and n != "spike_front"): pts.setdefault(n, []).append(v.co[:])
rnd = {}
for n, p in pts.items():
    b = rig.data.bones[n]; y = np.array(b.y_axis); p = np.array(p) - np.array(b.head_local)
    q = p - np.outer(p @ y, y); w = np.linalg.eigvalsh(np.cov(q.T))
    rnd[n] = round(float(math.sqrt(w[2] / max(w[1], 1e-9))), 2)        # widest over narrowest across the axis: 1 is round
zdlib.emit({"loop_seam": seam, "shard_02_quaternion_first_last": ends, "cross_section_wide_over_narrow": dict(sorted(rnd.items(), key=lambda kv: kv[1]))})
