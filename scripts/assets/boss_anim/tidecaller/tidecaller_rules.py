# Run inside tidecaller_rig.py (exec): W[i] = {bone: weight} for welded vertex i, P[i] its position, hsv[i] its colour,
# nbr[i] its neighbours, in_part(co, name), off_bone(co, bone, past).
REPORT = {}
def count(k): REPORT[k] = REPORT.get(k, 0) + 1

# The bell is one hard piece that swings on the hook; its clapper swings inside it.
rim = [P[i] for i in range(NV) if in_part(P[i], "Bell") and 2.28 < P[i].z < 2.40 and P[i].y < -0.2]
BX = (min(p.x for p in rim) + max(p.x for p in rim)) / 2; BY = (min(p.y for p in rim) + max(p.y for p in rim)) / 2
BR = (max(p.x for p in rim) - min(p.x for p in rim)) / 2
REPORT["bell_axis"] = [round(BX, 3), round(BY, 3), round(BR, 3)]
def bell_r(z):
    if z < 2.74: return BR + 0.03 - (BR - 0.15) * (z - 2.28) / 0.46
    return 0.18 - 0.08 * (z - 2.74) / 0.14
for i in range(NV):
    p = P[i]; r = math.hypot(p.x - BX, p.y - BY)
    if 2.10 < p.z < 2.31 and r < 0.10: W[i] = {"clapper": 1.0}; count("clapper")
    elif 2.26 < p.z < 2.88 and r < bell_r(p.z): W[i] = {"bell": 1.0}; count("bell")
    elif W[i].get("clapper", 0) > 0:                     # nothing else hangs from the clapper
        w = W[i]; w["bell"] = w.get("bell", 0) + w.pop("clapper")
# The staff is a hard pole (with its hook and rings); the shell is one hard piece, its corals and barnacles with it.
# Cloth is teal and the pole is not: the robe the pole stands in must not be taken for the pole, nor pulled by it.
def is_teal(i): return 0.38 < hsv[i][0] < 0.60 and hsv[i][1] > 0.3
def drop(w, bone):
    """Take a bone out of a vertex's weights; True if something is left."""
    w.pop(bone, None)
    return bool(w)
for i in range(NV):
    p = P[i]; w = W[i]
    if w.get("bell", 0) == 1.0 or w.get("clapper", 0) == 1.0: continue
    teal = is_teal(i)
    hook = p.z > 2.86 and p.x < -0.85 and w.get("staff", 0) + w.get("bell", 0) > 0.4
    pole = not teal and (off_bone(p, "staff", 1.75) < 0.075 or w.get("staff", 0) >= 0.5)
    if (hook or pole) and w.get("hand.R", 0) < 0.5:
        W[i] = {"staff": 1.0}; count("staff"); continue
    if teal and p.z < 1.0 and "staff" in w:
        if not drop(w, "staff"): W[i] = {"skirt2_s.R": 1.0}
        count("robe_off_staff")
    grey = hsv[i][1] < 0.28 and hsv[i][2] > 0.25
    if w.get("shell", 0) >= 0.5 or (in_part(p, "Shell") and grey and p.z > 2.05 and p.y > 0.0):
        W[i] = {"shell": 1.0}; count("shell"); continue
    if w.get("head", 0) >= 0.6: W[i] = {"head": 1.0}; count("head")

# The hem lies on the floor whatever the hips and the legs do: down there the cloth listens only to the robe's chains.
LEGS = ("shin.L", "shin.R", "foot.L", "foot.R")
SK2 = [n for n in SEG if n.startswith("skirt2")]
for i in range(NV):
    p = P[i]; w = W[i]
    if p.z > 0.8 or w.get("staff", 0) == 1.0: continue
    boot = min(off_bone(p, n, 0.08) for n in LEGS) < 0.20 and not is_teal(i)
    if boot: continue
    keep = {n: x for n, x in w.items() if n.startswith("skirt") or (p.z > 0.45 and n not in LEGS)}
    if not keep: keep = {min(SK2, key=lambda n: off_bone(p, n, 0.5)): 1.0}
    if keep != w: W[i] = keep; count("hem")
