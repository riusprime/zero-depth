"""rig.blend -> anim.blend: the 'walk' and 'cast' actions, each also stashed on an NLA track."""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
rig = bpy.data.objects["Rig"]; P = Poser(rig)
sc = bpy.context.scene; sc.render.fps = 30
TAU = math.tau
def c(ph): return math.cos(TAU * ph)
def s(ph): return math.sin(TAU * ph)
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def curve(t, keys):
    """Eased interpolation through (frame, value) keys."""
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def arc(d0, d1, t):
    """Swing direction d0 towards d1 by fraction t (t may pass 1)."""
    d0 = Vector(d0).normalized(); d1 = Vector(d1).normalized()
    qd = d0.rotation_difference(d1); ax, ang = qd.to_axis_angle()
    return Quaternion(ax, ang * t) @ d0
# The clips are written for a figure with the sword in its right hand. A figure that holds it in the left (the violet
# Warden) is animated as its own mirror image: its rest pose is read mirrored, and each pose is mirrored back.
MIRROR = rig.data.bones["sword"].parent.name.endswith(".L")
def _side(n):
    if MIRROR and n[-2:] in (".L", ".R"): return n[:-1] + ("R" if n[-1] == "L" else "L")
    return n
def _mv(v):
    v = Vector(v)
    return Vector((-v.x, v.y, v.z)) if MIRROR else v
def _mq(qq): return Quaternion((qq.w, qq.x, -qq.y, -qq.z)) if MIRROR else qq
def rest_dir(n): return _mv(P.rest[_side(n)].to_3x3().col[1].normalized())
def rest_head(n): return _mv(P.rest[_side(n)].translation.copy())
def real(pose):
    if not MIRROR: return pose
    out = {}
    for n, ops in pose.items():
        o = {}
        for k, v in ops.items():
            if k in ("rot", "abs"): o[k] = _mq(v)
            elif k in ("loc", "aim"): o[k] = _mv(v)
            else: o[k] = (_mv(v[0]), _mv(v[1]))        # aimvec, ik
        out[_side(n)] = o
    return out
# Where this figure's sword shoulder sits against the one the hand paths were drawn on.
OFF = rest_head("upper_arm.R") - Vector((-0.36, 0.07, 1.63))

ANKLE = {s_: rest_head(f"foot.{s_}") for s_ in "LR"}
BALL = {s_: rest_head(f"toe.{s_}") for s_ in "LR"}
NARROW = {"R": 0.07, "L": -0.07}      # the walk brings the wide rest stance in a little
POLE = {"R": Vector((-0.25, -1, 0.1)), "L": Vector((0.25, -1, 0.1))}

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True

# ---------------------------------------------------------------- walk
N = 40                 # frames per cycle (two steps)
STANCE = 0.62          # share of the cycle a foot is on the ground
STEP = 0.28            # the ball of the foot travels +-STEP: the cycle covers 2*STEP/STANCE = 0.90 m

def foot(p):
    """Phase 0 = heel strike. Returns (forward offset, lift, pitch in degrees: + is heel up, toe pitch)."""
    p %= 1.0
    if p < STANCE:
        u = p / STANCE
        y = lerp(-STEP, STEP, u)
        pitch = -16 * (1 - smooth(u / 0.16)) + 40 * smooth((u - 0.58) / 0.42) ** 1.5
        return y, 0.0, pitch, min(pitch, 0.0)
    v = (p - STANCE) / (1 - STANCE)
    y = lerp(STEP, -STEP, smooth(v) * 0.75 + v * 0.25)
    lift = 0.13 * math.sin(math.pi * v) ** 0.9 + 0.03 * math.sin(math.pi * min(1, v * 1.6))
    pitch = lerp(40, -16, smooth(v * 1.15))
    return y, lift, pitch, pitch * smooth(v * 2.5)

def leg(pose, side, p):
    y, lift, pitch, toe = foot(p)
    qf = qe(x=pitch)
    heel_lift = max(0.0, -math.sin(math.radians(pitch))) * 0.2      # toe-up pivots on the heel
    ball = BALL[side] + Vector((NARROW[side], y, lift + heel_lift))
    ankle = ball + qf @ (ANKLE[side] - BALL[side])
    pose[f"thigh.{side}"] = {"ik": (ankle, POLE[side])}
    pose[f"foot.{side}"] = {"abs": qf}
    pose[f"toe.{side}"] = {"abs": qe(x=toe)}
    return y

def walk_pose(ph):
    pose = {}
    leg(pose, "R", ph); leg(pose, "L", ph + 0.5)
    pose["hips"] = {"loc": (-0.045 * s(ph - 0.06), 0.0, -0.06 - 0.028 * c(2 * (ph - 0.05))),
                    "rot": qe(x=3.5 + 1.0 * c(2 * (ph - 0.08)), y=3.0 * s(ph - 0.06), z=7 * c(ph))}
    pose["spine"] = {"rot": qe(x=2.5, y=-2.0 * s(ph - 0.10), z=-5 * c(ph - 0.03))}
    pose["chest"] = {"rot": qe(x=1.5 + 1.5 * c(2 * (ph - 0.12)), y=-2.0 * s(ph - 0.13), z=-6.5 * c(ph - 0.06))}
    pose["neck"] = {"rot": qe(x=-2, z=2.0 * c(ph - 0.08))}
    pose["head"] = {"rot": qe(x=-3 + 1.5 * c(2 * (ph - 0.18)), y=1.0 * s(ph - 0.15), z=2.5 * c(ph - 0.10))}
    # The sword arm swings against its own leg, each joint a little later than the one above it.
    pose["shoulder.R"] = {"rot": qe(z=2.5 * c(ph - 0.02), y=-1.5 * c(2 * (ph - 0.1)))}
    pose["upper_arm.R"] = {"rot": qe(x=11 * c(ph - 0.04), y=-2 + 2 * s(ph))}
    pose["pauldron.R"] = {"rot": qe(x=3.5 * c(ph - 0.07), y=1.2 * c(2 * (ph - 0.14)))}
    pose["pauldron.L"] = {"rot": qe(x=-1.5 * c(ph - 0.07), y=-1.2 * c(2 * (ph - 0.14)))}
    pose["forearm.R"] = {"rot": qe(x=-11 + 8 * c(ph - 0.11))}
    pose["hand.R"] = {"rot": qe(x=6 * c(ph - 0.19), z=3 * s(ph - 0.19))}
    # The shield arm carries weight: it stays close and only rides the steps.
    pose["shoulder.L"] = {"rot": qe(z=-1.5 * c(ph - 0.02), y=1.2 * c(2 * (ph - 0.1)))}
    pose["upper_arm.L"] = {"rot": qe(x=-4 * c(ph - 0.04))}
    pose["forearm.L"] = {"rot": qe(x=-3 + 2.5 * c(2 * (ph - 0.16)), z=1.5 * s(ph - 0.1))}
    # Cloth: trails behind, bounces on each step, sways late, and the leg that is back pushes its side out.
    back = {"R": max(0.0, foot(ph - 0.06)[0]) / STEP, "L": max(0.0, foot(ph + 0.5 - 0.06)[0]) / STEP}
    back["M"] = 0.5 * (back["R"] + back["L"])
    for side in "LMR":
        for k in (1, 2, 3):
            d = 0.07 * k
            pose[f"cape{k}.{side}"] = {"rot": qe(
                x=(2.5 if k == 1 else 1.5) + (1.0 + 0.9 * k) * c(2 * (ph - 0.14 - d)) + (0, 5, 9)[k - 1] * back[side],
                y=(1.2 + 0.9 * k) * s(ph - 0.16 - d),
                z=(0.8 * k) * c(ph - 0.2 - d))}
    pose["tabard1"] = {"rot": qe(x=-5 + 4 * c(2 * (ph - 0.10)), y=3.5 * s(ph - 0.12))}
    pose["tabard2"] = {"rot": qe(x=-3 + 5 * c(2 * (ph - 0.19)), y=4.0 * s(ph - 0.22))}
    return pose

act = poser.new_action(rig, "walk"); P.prevq.clear()
for f in range(N + 1):
    P.key(real(walk_pose(f / N)), f)
act.frame_range = (0, N); act.use_frame_range = True; act.use_cyclic = True
stash(act)

# ---------------------------------------------------------------- cast
END = 80
SW0 = rest_dir("sword"); U0 = rest_dir("upper_arm.R"); F0 = rest_dir("forearm.R"); S0 = rest_dir("shoulder.R")
def qpow(qq, t):
    ax, ang = qq.to_axis_angle(); return Quaternion(ax, ang * t)
# The grip is rigid: the palm's normal is square to the forearm and the blade. Levelled, the blade points ahead and a
# little up with the palm turned in; the wrist gives 20 degrees, so the forearm lies almost level behind the hand.
# The arm only comes up to chest height, so the shoulder plate hardly has to move.
POINT = Vector((0.0, -0.97, 0.24)).normalized()
PALM0 = F0.cross(SW0).normalized()
if PALM0.x < 0: PALM0.negate()
_A = Matrix((SW0, PALM0, SW0.cross(PALM0))).transposed()
_B = Matrix((POINT, X, POINT.cross(X))).transposed()
Q_HAND = (_B @ _A.transposed()).to_quaternion()
Q_FORE = q(X, -20) @ Q_HAND
UP_ARM = Vector((-0.20, -0.88, -0.38))   # forward and a little down: the hand ends in front of the chest

def cast_pose(t):
    def a(dt=0):      # the dip before the lift
        return curve(t - dt, [(0, 0), (9, 1), (17, 0)])
    def r(dt=0):      # the lift, past its mark and back
        return curve(t - dt, [(8, 0), (21, 1.07), (28, 0.98), (34, 1), (54, 1), (76, 0)])
    def ring(dt=0):   # the wobble as the lift stops
        tt = t - dt
        return math.exp(-(tt - 20) / 13.0) * math.sin(TAU * (tt - 20) / 24.0) if tt > 20 else 0.0
    hold = curve(t, [(24, 0), (32, 1), (52, 1), (58, 0)])
    settle = curve(t, [(54, 0), (66, 1), (80, 0)])
    pose = {}
    pose["hips"] = {"loc": (0.02 * r() - 0.02 * a(), 0.03 * a() - 0.05 * r(),
                            -0.06 * a() - 0.035 * r() - 0.015 * settle + 0.006 * ring()),
                    "rot": qe(x=4 * a() + 3 * r(), z=-6 * a() + 7 * r(1), y=-1.0 * r())}
    pose["spine"] = {"rot": qe(x=3 * a() + 3 * r(1), z=-7 * a() + 6 * r(2), y=-1.5 * r(1))}
    pose["chest"] = {"rot": qe(x=3 * a() + 4 * r(2) + 0.8 * hold * s(t / 38.0) + 1.5 * ring(), z=-10 * a() + 9 * r(3), y=-2.0 * r(2))}
    pose["neck"] = {"rot": qe(x=2 * a() - 2 * r(4), z=4 * a() - 6 * r(4))}
    pose["head"] = {"rot": qe(x=3 * a() - 3 * r(5) + 2 * ring(3), z=5 * a() - 8 * r(5), y=-2 * r(5))}
    # The sword arm: shoulder, elbow, wrist start one after the other, so the blade arrives last.
    pose["shoulder.R"] = {"aim": arc(arc(S0, (-0.9, 0.15, -0.25), a()), (-0.96, -0.20, -0.08), r())}
    pose["upper_arm.R"] = {"abs": qpow(Q_FORE, r(1)), "rot": qe(x=14 * a(1), y=-4 * a(1)), "aim": None}
    up = arc(U0, UP_ARM, r(1)); pose["upper_arm.R"]["aim"] = qe(x=14 * a(1), y=-4 * a(1)) @ up
    pose["pauldron.R"] = {"rot": qe(y=3 * r(1) + 2 * ring(1), x=-4 * r(2) + 4 * a())}
    pose["pauldron.L"] = {"rot": qe(y=-2 * r(3) - 2 * ring(3))}
    pose["forearm.R"] = {"abs": qpow(Q_FORE, r(3)), "rot": qe(x=-16 * a(2) + 3 * ring(1))}
    sway = qe(x=1.6 * hold * s(t / 23.0) + 5 * ring(2), y=1.4 * hold * c(t / 31.0))
    pose["hand.R"] = {"abs": sway @ qpow(Q_HAND, r(5)), "rot": qe(x=10 * a(3))}
    # The shield arm braces: in tight during the dip, then forward and a little up as the body opens.
    pose["shoulder.L"] = {"rot": qe(y=2 * a() + 2.5 * r(2), z=-2 * r(2))}
    pose["upper_arm.L"] = {"rot": qe(x=4 * a() - 7 * r(3), y=-3 * r(3))}
    pose["forearm.L"] = {"rot": qe(x=-6 * a(1) - 5 * r(4) + 1.5 * ring(4), z=4 * r(4))}
    for side in "LR":                                     # the feet stay planted: the knees take the dip
        pose[f"thigh.{side}"] = {"ik": (ANKLE[side], POLE[side])}
        pose[f"foot.{side}"] = {"abs": Quaternion()}
        pose[f"toe.{side}"] = {"abs": Quaternion()}
    for side in "LMR":
        tw = {"L": -1, "M": 0, "R": 1}[side]
        for k in (1, 2, 3):
            pose[f"cape{k}.{side}"] = {"rot": qe(
                x=-3 * a(2 * k) * k + 4 * r(2 + 2 * k) * (k == 1) + (2.0 + 2.5 * k) * ring(2 + 3 * k) + 0.5 * k * hold * s((t - 4 * k) / 34.0),
                y=(1.0 + 1.2 * k) * ring(5 + 3 * k) * (1 if side != "L" else -0.6) + tw * 0.6 * k * r(4 + 2 * k),
                z=-2 * a(2 * k) + 1.5 * k * ring(4 + 3 * k))}
    pose["tabard1"] = {"rot": qe(x=6 * a(2) - 3 * r(3) + 4 * ring(3), y=2 * ring(5))}
    pose["tabard2"] = {"rot": qe(x=7 * a(4) + 6 * ring(6), y=3 * ring(8))}
    return pose

act = poser.new_action(rig, "cast"); P.prevq.clear()
for f in range(END + 1):
    P.key(real(cast_pose(float(f))), f)
act.frame_range = (0, END); act.use_frame_range = True
stash(act)

# ---------------------------------------------------------------- idle
IDLE_N = 90            # a three-second loop: every term below repeats once or twice in it

def idle_pose(ph):
    breath = s(2 * ph)                  # two breaths a loop
    late = s(2 * (ph - 0.06))
    shift = s(ph)                       # one slow shift of weight
    pose = {}
    pose["hips"] = {"loc": (0.012 * shift, 0.004 * c(ph), -0.010 - 0.006 * breath),
                    "rot": qe(x=0.6 * breath, y=0.8 * shift, z=1.0 * s(ph - 0.1))}
    pose["spine"] = {"rot": qe(x=-0.8 * breath, y=-0.6 * shift, z=-0.6 * s(ph - 0.14))}
    pose["chest"] = {"rot": qe(x=-1.6 * late, y=-0.5 * s(ph - 0.05), z=-0.8 * s(ph - 0.18))}
    pose["neck"] = {"rot": qe(x=0.8 * late)}
    pose["head"] = {"rot": qe(x=0.9 * s(2 * (ph - 0.12)), z=2.2 * s(ph - 0.3), y=0.5 * shift)}
    pose["shoulder.R"] = {"rot": qe(y=1.2 * late)}
    pose["shoulder.L"] = {"rot": qe(y=-1.2 * late)}
    pose["pauldron.R"] = {"rot": qe(y=0.8 * s(2 * (ph - 0.10)))}
    pose["pauldron.L"] = {"rot": qe(y=-0.8 * s(2 * (ph - 0.10)))}
    pose["upper_arm.R"] = {"rot": qe(x=1.2 * s(ph - 0.2), y=-0.8 * late)}
    pose["forearm.R"] = {"rot": qe(x=-2.0 + 1.6 * s(2 * (ph - 0.16)))}
    pose["hand.R"] = {"rot": qe(x=2.2 * s(ph - 0.33), z=1.2 * s(2 * (ph - 0.25)))}
    pose["upper_arm.L"] = {"rot": qe(x=-0.8 * s(ph - 0.2), y=0.7 * late)}
    pose["forearm.L"] = {"rot": qe(x=-1.0 + 1.0 * s(2 * (ph - 0.18)), z=0.8 * s(ph - 0.25))}
    for side in "LR":                                     # planted feet: the knees take the breathing and the shift
        pose[f"thigh.{side}"] = {"ik": (ANKLE[side], POLE[side])}
        pose[f"foot.{side}"] = {"abs": Quaternion()}
        pose[f"toe.{side}"] = {"abs": Quaternion()}
    for side in "LMR":
        off = {"L": 0.0, "M": 0.04, "R": 0.08}[side]
        for k in (1, 2, 3):
            d = 0.06 * k + off
            pose[f"cape{k}.{side}"] = {"rot": qe(x=0.5 * k * s(2 * (ph - 0.12 - d)), y=0.7 * k * s(ph - 0.15 - d),
                                                 z=0.3 * k * c(ph - 0.2 - d))}
    pose["tabard1"] = {"rot": qe(x=0.8 * s(2 * (ph - 0.1)), y=1.0 * s(ph - 0.15))}
    pose["tabard2"] = {"rot": qe(x=1.2 * s(2 * (ph - 0.2)), y=1.5 * s(ph - 0.27))}
    return pose

act = poser.new_action(rig, "idle"); P.prevq.clear()
for f in range(IDLE_N + 1):
    P.key(real(idle_pose(f / IDLE_N)), f)
act.frame_range = (0, IDLE_N); act.use_frame_range = True; act.use_cyclic = True
stash(act)

# ---------------------------------------------------------------- swipe
SWIPE_END = 48
WRIST0 = rest_head("hand.R")
REST_BASIS = Matrix((SW0, PALM0, SW0.cross(PALM0))).transposed()

def grip(blade, forearm):
    """The hand's rotation from rest for a blade direction and roughly where the forearm comes from.
    The grip keeps the forearm 40 degrees off the blade, on the side away from blade x palm."""
    b = Vector(blade).normalized(); f = Vector(forearm).normalized()
    cc = 0.76 * b - f; cc = (cc - b * cc.dot(b)).normalized()
    n = cc.cross(b)
    return (Matrix((b, n, cc)).transposed() @ REST_BASIS.transposed()).to_quaternion()

def bez(p0, p1, p2, u):
    return (1 - u) * (1 - u) * Vector(p0) + 2 * u * (1 - u) * Vector(p1) + u * u * Vector(p2)
def qbez(q0, q1, q2, u):
    return q0.slerp(q1, u).slerp(q1.slerp(q2, u), u)
def ramp(t, f0, f1): return max(0.0, min(1.0, (t - f0) / (f1 - f0)))

# The chamber: the hand in front of the shield-side shoulder, the blade up and back over it.
W_UP = Vector((0.04, -0.40, 1.64)) + OFF; Q_UP = grip((0.38, 0.42, 0.82), (0.72, -0.50, 0.48))
# Halfway down the cut: the hand out in front of the chest, the blade pointing ahead.
Q_MID = grip((-0.05, -0.93, 0.36), (-0.25, -0.90, -0.36))
# The end of the cut: low on the sword side, the blade down, ahead and outwards.
W_LOW = Vector((-0.60, -0.36, 1.00)) + OFF; Q_LOW = grip((-0.42, -0.62, -0.66), (-0.30, -0.42, -0.86))
# Carried past: the hand swings on out beside the hip.
W_PAST = Vector((-0.74, -0.06, 0.93)) + OFF; Q_PAST = grip((-0.52, -0.30, -0.80), (-0.36, -0.05, -0.93))
Q_ID = Quaternion()

def swipe_pose(t):
    up = smooth(ramp(t, 2, 10))                              # the quick lift across the body
    coil = curve(t, [(8, 0), (12, 1), (14, 0)])              # a last wind tighter before it goes
    cut = ramp(t, 12, 17); cut = cut ** 1.7 * (1.0 + 0.35 * (1 - cut))    # starts slow, lands fast
    cut = min(1.0, cut)
    past = smooth(ramp(t, 17, 22))
    back = smooth(ramp(t, 25, 46))
    def twist(dt=0):                                         # degrees to its left: the body winds, then unwinds past
        tt = t - dt
        return 20 * smooth(ramp(tt, 2, 10)) + 5 * curve(tt, [(8, 0), (12, 1), (14, 0)]) \
            - 42 * smooth(ramp(tt, 12, 17)) - 5 * smooth(ramp(tt, 17, 21)) + 27 * smooth(ramp(tt, 25, 46))
    def lean(dt=0):                                          # degrees forward
        tt = t - dt
        return -5 * smooth(ramp(tt, 2, 10)) + 16 * smooth(ramp(tt, 12, 17)) - 11 * smooth(ramp(tt, 25, 44))
    if t <= 12:
        W = bez(WRIST0, Vector((-0.58, -0.56, 1.22)) + OFF, W_UP, up) + Vector((0.03, 0.04, 0.03)) * coil
        Q = Q_ID.slerp(Q_UP, up)
        pole = Vector((-0.35, -0.45, -0.82))
    elif t <= 17:
        W = bez(W_UP, Vector((-0.30, -0.86, 1.52)) + OFF, W_LOW, cut); Q = qbez(Q_UP, Q_MID, Q_LOW, cut)
        pole = Vector((-0.35, -0.45, -0.82)).lerp(Vector((-0.6, 0.5, -0.4)), cut)
    elif t <= 25:
        W = W_LOW.lerp(W_PAST, past); Q = Q_LOW.slerp(Q_PAST, past); pole = Vector((-0.6, 0.5, -0.4))
    else:
        W = bez(W_PAST, Vector((-0.76, -0.04, 0.90)) + OFF, WRIST0, back); Q = Q_PAST.slerp(Q_ID, back)
        pole = Vector((-0.6, 0.5, -0.4))
    drop = 0.03 * up + 0.05 * smooth(ramp(t, 12, 17)) - 0.08 * smooth(ramp(t, 25, 44))
    side = 0.04 * up - 0.09 * smooth(ramp(t, 12, 18)) + 0.05 * back      # weight to the shield side, then into the cut
    pose = {}
    pose["hips"] = {"loc": (side, 0.01 * up - 0.05 * smooth(ramp(t, 12, 17)) + 0.04 * back, -0.012 - drop),
                    "rot": qe(x=0.30 * lean(), z=0.28 * twist(), y=-1.5 * up + 3 * smooth(ramp(t, 12, 17)) - 1.5 * back)}
    pose["spine"] = {"rot": qe(x=0.30 * lean(1), z=0.32 * twist(1))}
    pose["chest"] = {"rot": qe(x=0.40 * lean(2), z=0.40 * twist(2), y=3 * up - 7 * smooth(ramp(t, 13, 18)) + 4 * back)}
    look = -0.55 * (0.28 * twist() + 0.32 * twist(1) + 0.40 * twist(2))   # the head stays on the target
    pose["neck"] = {"rot": qe(x=-0.2 * lean(2), z=0.4 * look)}
    pose["head"] = {"rot": qe(x=-0.35 * lean(3) + 4 * smooth(ramp(t, 13, 18)) - 4 * back, z=0.6 * look)}
    reach = up - smooth(ramp(t, 12, 16))
    pose["shoulder.R"] = {"aim": arc(arc(S0, (-0.82, -0.56, 0.08), reach), (-0.97, 0.12, -0.20), smooth(ramp(t, 14, 19)) - back)}
    pose["pauldron.R"] = {"rot": qe(y=4 * reach, x=-5 * reach + 4 * (smooth(ramp(t, 14, 19)) - back))}
    pose["upper_arm.R"] = {"abs": qpow(Q, 0.5), "ik": (W, pole)}
    pose["forearm.R"] = {"abs": Q}
    pose["hand.R"] = {"abs": Q}
    # The shield arm drops and opens to let the blade over, then snaps back across the body as the cut lands.
    cover = smooth(ramp(t, 13, 18)) - back
    pose["shoulder.L"] = {"rot": qe(y=-2 * up + 2 * cover, z=3 * up - 5 * cover)}
    pose["pauldron.L"] = {"rot": qe(y=-1.5 * up)}
    pose["upper_arm.L"] = {"rot": qe(x=5 * up - 9 * cover, y=4 * up - 3 * cover)}
    pose["forearm.L"] = {"rot": qe(x=4 * up - 8 * cover, z=-5 * up + 7 * cover)}
    for sd in "LR":
        pose[f"thigh.{sd}"] = {"ik": (ANKLE[sd], POLE[sd])}
        pose[f"foot.{sd}"] = {"abs": Quaternion()}
        pose[f"toe.{sd}"] = {"abs": Quaternion()}
    # Cloth lags the body's turn and its lean: each link later than the one above.
    for sd in "LMR":
        for k in (1, 2, 3):
            d = 2 + 2.5 * k
            pose[f"cape{k}.{sd}"] = {"rot": qe(
                x=0.22 * k * (lean() - lean(d)) + 0.25 * lean(d) * (k == 1),
                y=0.07 * k * (twist(d) - twist()) * (0.6 if sd == "M" else 1.0),
                z=0.10 * (twist(d) - twist()))}
    pose["tabard1"] = {"rot": qe(x=0.4 * (lean() - lean(3)) - 0.3 * lean(), y=0.25 * (twist(3) - twist()))}
    pose["tabard2"] = {"rot": qe(x=0.6 * (lean() - lean(6)), y=0.35 * (twist(6) - twist()))}
    return pose

act = poser.new_action(rig, "swipe"); P.prevq.clear()
for f in range(SWIPE_END + 1):
    P.key(real(swipe_pose(float(f))), f)
act.frame_range = (0, SWIPE_END); act.use_frame_range = True
stash(act)

sc.frame_start = 0; sc.frame_end = END
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
zdlib.emit({"actions": {a_.name: list(a_.frame_range) for a_ in bpy.data.actions}})
