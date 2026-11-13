"""The crystals' slow turn, as the game's avatar will add it: PREVIEW ONLY (it is never saved and never exported).

Each crystal turns about its own bone's Y (its long axis, through its tip) at one full turn in 10 s, steadily, on top
of whatever the clip keyed: local rotation = keyed rotation x turn about Y. A 10 s turn cannot loop inside a 3 or 4 s
clip, so it is not in the file's tracks; here it is laid over the action in memory so the renders show what the game
will. A looping clip is unrolled first (its keys repeated), so the turn runs on through the repeat as it will in play.
"""
import bpy, math
from mathutils import Quaternion

PERIOD_S = 10.0
# bone: (direction, where in its turn it starts, as a share of a turn)
SPIN = {"spike_front": (1, 0.0), "spike_low.L": (-1, 0.2), "spike_low.R": (1, 0.4), "spike_side.L": (1, 0.6), "spike_side.R": (-1, 0.8)}

def fcurves(act):
    if getattr(act, "layers", None):
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags: yield from cb.fcurves
    else: yield from act.fcurves

def unroll(act, loops):
    """Repeat a loop's keys `loops` times in place (frames 0..N become 0..loops*N)."""
    n = int(act.frame_range[1] - act.frame_range[0])
    for fc in fcurves(act):
        vals = {int(round(kp.co.x)): kp.co.y for kp in fc.keyframe_points}
        for k in range(1, loops):
            for j in range(1, n + 1):
                fc.keyframe_points.insert(k * n + j, vals.get(j, vals[max(vals)]), options={'FAST'})
        fc.update()
    act.frame_range = (0, loops * n)
    return loops * n

def apply(act, fps=30.0):
    """Lay the turn over the action's keyed rotations of the crystals."""
    by = {}
    for fc in fcurves(act):
        for n in SPIN:
            if fc.data_path == f'pose.bones["{n}"].rotation_quaternion': by.setdefault(n, {})[fc.array_index] = fc
    done = 0
    for n, fcs in by.items():
        sign, ph = SPIN[n]
        pts = [fcs[i].keyframe_points for i in range(4)]
        for k in range(len(pts[0])):
            f = pts[0][k].co.x
            ang = sign * math.tau * (f / (PERIOD_S * fps) + ph)
            q = Quaternion([pts[i][k].co.y for i in range(4)]) @ Quaternion((0, 1, 0), ang)
            for i in range(4):
                pts[i][k].co.y = q[i]; pts[i][k].handle_left.y = q[i]; pts[i][k].handle_right.y = q[i]; pts[i][k].interpolation = 'LINEAR'
        for i in range(4): fcs[i].update()
        done += 1
    return done
