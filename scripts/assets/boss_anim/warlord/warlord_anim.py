"""rig.blend -> anim.blend: the Warlord's actions, each also stashed on an NLA track.

Every clip is a function from time (frames) to a *state*: where the hips are, how far the torso leans and twists, where
each foot stands, where each wrist is and where the spear points. build() turns a state into a pose: it spreads the
lean and the twist up the spine (each joint reads the state a frame later than the one below), plants the feet with a
two-bone reach, places each arm by a reach to its wrist with the hand turned by a grip frame (the spear's direction +
the forearm it comes from), and lets the cloak, the cloth at the front and the crest trail the body.

Model units: the figure is 1.0 tall to its spear's tip (2.7 m in the game). It faces +X, its left is +Y.
Angles are degrees: lean + is forward, twist + is to its left, side + tilts to its right.
"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
rig = zdlib.the_rig()
# A shoulder plate rides the upper arm but takes only part of its swing, so a lifted arm doesn't carry it into the helm.
Poser.LAG = {"L_Pauldron": 0.55, "R_Pauldron": 0.55}
P = Poser(rig)
sc = bpy.context.scene; sc.render.fps = 30
TAU = math.tau
def c(ph): return math.cos(TAU * ph)
def s(ph): return math.sin(TAU * ph)
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def ramp(t, f0, f1): return max(0.0, min(1.0, (t - f0) / (f1 - f0)))
def sramp(t, f0, f1): return smooth(ramp(t, f0, f1))
def curve(t, keys):
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def hit(t, f0, f1, over=0.10, settle=6.0):
    """0 -> 1 between f0 and f1, slow then fast; then a little past 1 and back."""
    if t <= f1: return ramp(t, f0, f1) ** 2.2
    x = min(1.0, (t - f1) / settle)
    return 1.0 + over * math.sin(math.pi * x) * (1 - x)
def perp(v, n): return v - n * v.dot(n)
def qpart(qq, f): return Quaternion().slerp(qq, max(0.0, min(1.0, f)))
def rest_dir(n): return P.rest[n].to_3x3().col[1].normalized()
def rest_head(n): return P.rest[n].translation.copy()

D0 = rest_dir("Spear"); F0 = rest_dir("R_Forearm")
C0 = perp(F0, D0).normalized(); N0 = C0.cross(D0)
REST_BASIS = Matrix((D0, N0, C0)).transposed()
WR0 = rest_head("R_Hand"); WL0 = rest_head("L_Hand")
ANK = {"L": rest_head("L_Foot"), "R": rest_head("R_Foot")}
BALL = {"L": rest_head("L_ToeBase"), "R": rest_head("R_ToeBase")}
KNEE = {"L": Vector((1, 0.5, 0)), "R": Vector((1, -0.9, 0))}
LEN = P.len

# ---------------------------------------------------------------- states
BASE = dict(
    hip=[0.0, 0.0, -0.012], lean=0.0, twist=0.0, side=0.0,
    head=[0.0, 0.0, 0.0],                      # extra roll, pitch (+ down), yaw (+ left)
    fl=[0.0] * 6, fr=[0.0] * 6,                # ball of the foot dx, dy, dz; heel-up pitch; toe pitch; yaw
    kl=list(KNEE["L"]), kr=list(KNEE["R"]),
    rw=[0.045, -0.245, 0.412], rd=list(D0), rpiv=0.0, rfol=0.0, rdfol=1.0, rpole=[-0.6, -0.5, -0.6],
    lw=[0.09, 0.20, 0.40], lfol=1.0, lpole=[-0.5, 0.7, -0.4], sh=[0.0, 0.0, -25.0], shfol=1.0,
    shr=0.0, shl=0.0, fold=0.0, tab=0.0, wind=0.0,
)
def K(**kw):
    d = {k: (list(v) if isinstance(v, list) else v) for k, v in BASE.items()}
    for k, v in kw.items(): d[k] = list(v) if isinstance(v, (list, tuple, Vector)) else float(v)
    return d
def mix(*parts):
    """BASE plus each (key pose, weight)'s difference from it."""
    out = {}
    for k, b in BASE.items():
        if isinstance(b, list):
            out[k] = [b[i] + sum(w * (p[k][i] - b[i]) for p, w in parts) for i in range(len(b))]
        else:
            out[k] = b + sum(w * (p[k] - b) for p, w in parts)
    out["extra"] = {}
    return out
def add(st, key, v):
    if isinstance(st[key], list):
        for i in range(len(v)): st[key][i] += v[i]
    else: st[key] += v

# ---------------------------------------------------------------- state -> pose
SPINE = (("Hip", 0.20, 0), ("Waist", 0.15, 1), ("Spine01", 0.35, 2), ("Spine02", 0.30, 3))
STAT = {}

def grip(Dv, f):
    """The hand's rotation from rest for the direction its thumb side points along the shaft and the forearm it
    comes from; the wrist only gives 70..140 degrees between the two, the rest is the shaft turning in the fist."""
    Dv = Dv.normalized(); f = f.normalized()
    phi = math.degrees(Dv.angle(f)); th = max(70.0, min(140.0, phi))
    a = perp(f, Dv).normalized().cross(Dv)
    Dh = Quaternion(a, math.radians(th - phi)) @ Dv
    c2 = perp(f, Dh).normalized(); n2 = c2.cross(Dh)
    Q = (Matrix((Dh, n2, c2)).transposed() @ REST_BASIS.transposed()).to_quaternion()
    return Q, a, phi - th, phi

def elbow(sh, W, pole, l1, l2):
    d = W - sh; dist = min(d.length, (l1 + l2) * 0.999); nn = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist); hh = math.sqrt(max(l1 * l1 - a * a, 0))
    pp = perp(pole, nn).normalized()
    return sh + nn * a + pp * hh, d.length / (l1 + l2)

def build(Sf, t, name=""):
    def g(key, d=0): return Sf(t - d)[key]
    st = Sf(t); pose = {}
    for bone, share, d in SPINE:
        pose[bone] = {"rot": qe(x=share * g("side", d), y=share * g("lean", d), z=share * g("twist", d))}
    pose["Hip"]["loc"] = Vector(g("hip"))
    lean = sum(sh_ * g("lean", d) for _, sh_, d in SPINE); twist = sum(sh_ * g("twist", d) for _, sh_, d in SPINE)
    hd = g("head", 4)
    pose["NeckTwist01"] = {"rot": qe(y=0.4 * (hd[1] - 0.5 * lean), z=0.4 * (hd[2] - 0.6 * twist))}
    pose["Head"] = {"rot": qe(x=hd[0], y=0.6 * (hd[1] - 0.5 * lean), z=0.6 * (hd[2] - 0.6 * twist))}
    for side, fk, kk in (("L", "fl", "kl"), ("R", "fr", "kr")):
        f = g(fk)
        qf = qe(z=f[5]) @ qe(y=f[3])
        ball = BALL[side] + Vector(f[:3]); ankle = ball + qf @ (ANK[side] - BALL[side])
        pose[f"{side}_Thigh"] = {"ik": (ankle, Vector(g(kk)))}
        pose[f"{side}_Foot"] = {"abs": qf}
        pose[f"{side}_ToeBase"] = {"abs": qe(z=f[5]) @ qe(y=f[4])}
    pose["R_Clavicle"] = {"rot": qe(x=-g("shr", 1))}
    pose["L_Clavicle"] = {"rot": qe(x=g("shl", 1))}
    world, _ = P.solve(pose)
    M = world["Spine02"] @ P.rest["Spine02"].inverted(); Mq = M.to_quaternion()
    # The spear arm.
    fol = g("rfol", 1); Qf = qpart(Mq, fol)
    Wl = Vector(g("rw", 1)); W = Wl.lerp(M @ Wl, fol)
    Dv = qpart(Mq, fol * g("rdfol", 2)) @ Vector(g("rd", 2)).normalized(); pole = Qf @ Vector(g("rpole", 1))
    el, reach = elbow(world["R_Upperarm"].translation, W, pole, LEN["R_Upperarm"], LEN["R_Forearm"])
    Q, axis, slack, phi = grip(Dv, W - el)
    pose["R_Upperarm"] = {"ik": (W, pole)}
    pose["R_Forearm"] = {"abs": Q}
    pose["R_Hand"] = {"abs": Q}
    pose["Spear"] = {"rot": Quaternion(axis, math.radians(g("rpiv", 1) + slack))}
    z = STAT.setdefault(name, {"reachR": 0, "reachL": 0, "slack": 0})
    z["reachR"] = max(z["reachR"], round(reach, 3)); z["slack"] = max(z["slack"], round(abs(slack)))
    # The shield arm: the shield turns on the fist, so it stays upright whatever the forearm does.
    fol = g("lfol", 1.5); Qf = qpart(Mq, fol)
    Wl = Vector(g("lw", 1.5)); W = Wl.lerp(M @ Wl, fol)
    pole = Qf @ Vector(g("lpole", 1.5))
    _, reach = elbow(world["L_Upperarm"].translation, W, pole, LEN["L_Upperarm"], LEN["L_Forearm"])
    z["reachL"] = max(z["reachL"], round(reach, 3))
    pose["L_Upperarm"] = {"ik": (W, pole)}
    sh = g("sh", 2.5)
    pose["Shield"] = {"abs": qpart(Mq, g("shfol", 2.5)) @ (qe(z=sh[2]) @ qe(x=sh[0], y=sh[1]))}
    # Cloth: it hangs (so it gives back part of the torso's lean), lags the lean and the twist, and trails the way
    # the body travels.
    def vx(d): return (g("hip", d)[0] - g("hip", d + 2)[0]) / 2 + g("wind", d)
    L0, T0 = g("lean"), g("twist"); fold = g("fold", 2)
    for col in "LMR":
        tw = {"L": 1, "M": 0, "R": -1}[col]
        for k in (1, 2, 3):
            d = 1 + 2 * k
            pitch = 0.30 * (L0 - g("lean", d)) + min(22.0, max(-8.0, 170 * vx(d))) * (0.5 + 0.25 * k) + (-4, 22, 36)[k - 1] * fold
            if k == 1: pitch += -0.5 * max(g("lean", 3), 0.0)
            pose[f"Cape{k:02d}_{col}"] = {"rot": qe(x=tw * 0.05 * k * (g("twist", d) - T0),
                                                   y=pitch, z=0.22 * (g("twist", d) - T0))}
    tp = min(5.0, max(-25.0, 150 * vx(2))) + g("tab", 1)
    pose["Tabard01"] = {"rot": qe(y=-0.2 * g("lean", 1) + tp, x=0.1 * (g("twist", 3) - T0))}
    pose["Tabard02"] = {"rot": qe(y=0.7 * (min(5.0, max(-25.0, 150 * vx(4))) + g("tab", 3)) + 0.2 * (L0 - g("lean", 4)))}
    pose["Plume01"] = {"rot": qe(y=0.20 * (L0 - g("lean", 4)) + 110 * vx(3), z=0.12 * (g("twist", 5) - T0))}
    pose["Plume02"] = {"rot": qe(y=0.30 * (L0 - g("lean", 6)) + 150 * vx(5), z=0.18 * (g("twist", 7) - T0))}
    for bone, qq in st["extra"].items():
        ops = pose.setdefault(bone, {})
        ops["rot"] = qq @ ops["rot"] if "rot" in ops else qq
    return pose

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True

def bake(name, Sf, n, loop=False):
    cache = {}
    def Sc(t):
        if loop: t = t % n
        k = round(t * 4)
        if k not in cache: cache[k] = Sf(k / 4.0)
        return cache[k]
    act = poser.new_action(rig, name); P.prevq.clear()
    for f in range(n + 1):
        P.key(build(Sc, float(f), name), f)
    act.frame_range = (0, n); act.use_frame_range = True; act.use_cyclic = loop
    stash(act)

# ---------------------------------------------------------------- idle
# The spear stands on the floor beside it; the body breathes and shifts its weight around the planted hand.
IDLE_N = 96
BUTT = WR0 + D0 * ((0.0 - WR0.z) / D0.z) + (Vector(BASE["rw"]) - WR0)      # where the shaft's line meets the floor

def idle_S(t):
    ph = t / IDLE_N
    breath = s(2 * ph); late = s(2 * (ph - 0.06)); shift = s(ph)
    st = mix()
    st["hip"] = [0.004 * c(ph), -0.009 * shift, -0.012 - 0.004 * breath]
    st["side"] = -1.2 * s(ph - 0.04); st["lean"] = 1.0 * late; st["twist"] = 1.8 * s(ph - 0.12)
    st["head"] = [0.0, 1.2 * s(2 * (ph - 0.15)), 9.0 * s(ph - 0.30) + 3.0 * s(2 * (ph - 0.1))]
    st["shr"] = 1.2 * late; st["shl"] = 1.2 * late
    # the spear leans a little on its butt, and the hand shifts its hold once a loop
    tilt = qe(x=1.4 * s(ph - 0.15), y=1.0 * s(2 * (ph - 0.22)))
    slide = 0.014 * math.sin(math.pi * ramp(ph, 0.52, 0.80)) ** 2
    W = BUTT + tilt @ (Vector(BASE["rw"]) - BUTT + D0 * slide)
    st["rw"] = list(W); st["rd"] = list(tilt @ D0)
    st["lw"] = [0.09 + 0.004 * s(ph - 0.2), 0.20, 0.40 + 0.004 * s(2 * (ph - 0.12))]
    st["sh"] = [0.8 * s(ph - 0.25), 0.8 * s(2 * (ph - 0.2)), -25 + 2.0 * s(ph - 0.22)]
    ex = st["extra"]
    for col, off in (("L", 0.0), ("M", 0.04), ("R", 0.08)):
        for k in (1, 2, 3):
            d = 0.06 * k + off
            ex[f"Cape{k:02d}_{col}"] = qe(y=0.6 * k * s(2 * (ph - 0.12 - d)), x=0.5 * k * s(ph - 0.15 - d))
    ex["Tabard01"] = qe(y=0.8 * s(2 * (ph - 0.1)), x=1.0 * s(ph - 0.15))
    ex["Tabard02"] = qe(y=1.2 * s(2 * (ph - 0.2)), x=1.5 * s(ph - 0.27))
    ex["Plume01"] = qe(y=0.8 * s(2 * (ph - 0.2)), x=0.8 * s(ph - 0.35))
    ex["Plume02"] = qe(y=1.2 * s(2 * (ph - 0.27)), x=1.2 * s(ph - 0.42))
    ex["R_Pauldron"] = qe(x=-0.8 * s(2 * (ph - 0.10))); ex["L_Pauldron"] = qe(x=0.8 * s(2 * (ph - 0.10)))
    return st

# ---------------------------------------------------------------- walk
WALK_N = 30
STANCE = 0.62          # share of the cycle a foot is on the ground
STEP = 0.10            # the ball of the foot travels +-STEP: the cycle covers 2*STEP/STANCE = 0.32 units (0.87 m)
SOLE = 0.08            # ball to heel
CENTRE = {"L": 0.02 - BALL["L"].x, "R": 0.02 - BALL["R"].x}     # the rest stance is staggered; the walk is not
NARROW = {"L": -0.02, "R": 0.02}

def foot(p):
    """Phase 0 = heel strike. Returns forward offset, lift, the foot's pitch (+ is heel up) and the toe's."""
    p %= 1.0
    if p < STANCE:
        u = p / STANCE
        x = lerp(STEP, -STEP, u)
        pitch = -15 * (1 - smooth(u / 0.16)) + 38 * smooth((u - 0.58) / 0.42) ** 1.5
        return x, 0.0, pitch, min(pitch, 0.0)
    v = (p - STANCE) / (1 - STANCE)
    x = lerp(-STEP, STEP, smooth(v) * 0.75 + v * 0.25)
    lift = 0.040 * math.sin(math.pi * v) ** 0.9 + 0.012 * math.sin(math.pi * min(1, v * 1.6))
    pitch = lerp(38, -15, smooth(v * 1.15))
    return x, lift, pitch, pitch * smooth(v * 2.5)

def walk_S(t):
    ph = t / WALK_N
    st = mix()
    for side, key, p in (("R", "fr", ph), ("L", "fl", ph + 0.5)):
        x, lift, pitch, toe = foot(p)
        heel = max(0.0, -math.sin(math.radians(pitch))) * SOLE      # toe-up pivots on the heel
        st[key] = [CENTRE[side] + x, NARROW[side], lift + heel, pitch, toe, 0.0]
    st["hip"] = [0.0, -0.013 * s(ph - 0.05), -0.024 - 0.008 * c(2 * (ph - 0.04))]
    st["side"] = 2.2 * s(ph - 0.06); st["lean"] = 4.0 + 1.2 * c(2 * (ph - 0.10))
    st["head"] = [0.0, 1.2 * c(2 * (ph - 0.18)), 0.0]
    ex = st["extra"]
    ex["Hip"] = qe(z=6.0 * c(ph))                               # the hips turn with the leading leg ...
    ex["Spine01"] = qe(z=-5.0 * c(ph - 0.04)); ex["Spine02"] = qe(z=-5.5 * c(ph - 0.07))    # ... the chest against it
    ex["Head"] = qe(z=4.0 * c(ph - 0.09))
    # the spear is carried upright off the floor, its arm swinging a little against its own leg
    st["rfol"] = 1.0
    st["rw"] = [0.055 - 0.016 * c(ph - 0.05), -0.25, 0.462 + 0.006 * c(2 * (ph - 0.13))]
    st["rd"] = list(qe(y=-1.0 - 3.0 * c(ph - 0.14), x=1.2 * s(ph - 0.1)) @ D0)
    st["shr"] = 1.5 * c(2 * (ph - 0.1))
    # the shield arm carries weight: it stays close and rides the steps
    st["lw"] = [0.09 + 0.010 * c(ph - 0.05), 0.205, 0.405 + 0.006 * c(2 * (ph - 0.15))]
    st["sh"] = [1.5 * s(ph - 0.1), 1.0 * c(2 * (ph - 0.17)), -25 + 2.5 * c(ph - 0.1)]
    st["wind"] = 0.012
    back = {"R": max(0.0, -foot(ph - 0.06)[0]) / STEP, "L": max(0.0, -foot(ph + 0.5 - 0.06)[0]) / STEP}
    back["M"] = 0.5 * (back["R"] + back["L"])
    for col in "LMR":
        for k in (1, 2, 3):
            d = 0.07 * k
            ex[f"Cape{k:02d}_{col}"] = qe(y=(0.8 + 0.8 * k) * c(2 * (ph - 0.14 - d)) + (0, 3, 6)[k - 1] * back[col],
                                          x=(1.0 + 0.8 * k) * s(ph - 0.16 - d))
    ex["Tabard01"] = qe(y=-3 + 3.5 * c(2 * (ph - 0.10)), x=3.0 * s(ph - 0.12))
    ex["Tabard02"] = qe(y=-2 + 4.5 * c(2 * (ph - 0.19)), x=3.5 * s(ph - 0.22))
    ex["Plume01"] = qe(y=1.5 * c(2 * (ph - 0.2)), x=1.2 * s(ph - 0.2)); ex["Plume02"] = qe(y=2.5 * c(2 * (ph - 0.28)), x=2.0 * s(ph - 0.3))
    ex["R_Pauldron"] = qe(x=-1.2 * c(2 * (ph - 0.14))); ex["L_Pauldron"] = qe(x=1.2 * c(2 * (ph - 0.14)))
    return st

# ---------------------------------------------------------------- thrust
# The spear comes off the floor and back to the hip, level; the body winds away, then drives it forward and holds.
THRUST_N = 48
T_WIND = K(hip=[-0.04, 0.0, -0.035], lean=-5, twist=-26, rw=[-0.05, -0.285, 0.45], rd=[0.94, -0.05, 0.34], rfol=1, rdfol=0,
           rpole=[-0.7, -0.5, -0.3], lw=[0.13, 0.17, 0.42], sh=[0, 0, -40], shr=4)
T_HIT = K(hip=[0.065, 0.005, -0.045], lean=13, twist=24, rw=[0.165, -0.165, 0.50], rd=[0.975, 0.03, 0.22], rfol=1, rdfol=0,
          rpole=[-0.4, -0.5, -0.8], lw=[0.10, 0.20, 0.41], sh=[0, 5, -30], fr=[0, 0, 0, 28, 0, 0])

def thrust_S(t):
    wind = curve(t, [(0, 0), (9, 1), (16, 1.08), (20, 0)])
    go = hit(t, 16, 20) * (1 - sramp(t, 28, 46))
    st = mix((T_WIND, wind), (T_HIT, go))
    add(st, "hip", [0, 0, -0.012 * curve(t, [(0, 0), (4, 1), (9, 0)])])          # the dip before it moves
    if 20 < t < 28: add(st, "rw", [0.003 * math.sin(t * 2.4), 0, 0.002 * math.sin(t * 3.1)])
    return st

# ---------------------------------------------------------------- lunge
# It sinks back onto the rear leg with the spear couched at the hip, then steps and thrusts at full stretch, and holds
# the stretch while the dash carries it.
LUNGE_N = 70
L_COUCH = K(hip=[-0.06, 0.0, -0.055], lean=7, twist=-32, rw=[-0.05, -0.29, 0.45], rd=[0.985, 0.0, 0.17], rfol=1, rdfol=0,
            rpole=[-0.7, -0.5, -0.3], lw=[0.15, 0.13, 0.44], sh=[0, 0, -50], shr=5, head=[0, -4, 0])
L_EXT = K(hip=[0.13, 0.0, -0.07], lean=24, twist=30, rw=[0.185, -0.16, 0.52], rd=[0.999, 0.02, 0.04], rfol=1, rdfol=0,
          rpole=[-0.3, -0.5, -0.8], lw=[0.08, 0.21, 0.42], sh=[0, 6, -20], fl=[0.15, 0, 0, 0, 0, 0],
          fr=[0, 0, 0, 50, 0, 0], head=[0, -6, 0])

def lunge_S(t):
    couch = curve(t, [(0, 0), (11, 1), (24, 1.10), (28, 0)])
    go = hit(t, 24, 28, over=0.06) * (1 - sramp(t, 46, 68))
    st = mix((L_COUCH, couch), (L_EXT, go))
    add(st, "hip", [0, 0, -0.010 * curve(t, [(0, 0), (4, 1), (10, 0)])])
    step = math.sin(math.pi * ramp(t, 23.5, 27.5)) + 0.8 * math.sin(math.pi * ramp(t, 50, 62))
    add(st, "fl", [0, 0, 0.03 * step, -10 * step, -10 * step, 0])               # the front foot steps out, and back
    st["wind"] = 0.07 * sramp(t, 26, 29) * (1 - sramp(t, 44, 50))                # the dash: cloth streams
    if 11 < t < 24: add(st, "rw", [0.002 * math.sin(t * 2.7), 0, 0.002 * math.sin(t * 3.3)])
    if 28 < t < 46: add(st, "rw", [0.002 * math.sin(t * 2.9), 0, 0.003 * math.sin(t * 3.7)])
    return st

# ---------------------------------------------------------------- throw
# The spear tips forward as the hand turns under it into a throwing hold and rises behind the head; the body winds
# away, then whips through: hips, chest, shoulder, elbow, and the hand last.
THROW_N = 56
W_COCK = K(hip=[-0.045, -0.008, -0.025], lean=-8, twist=-38, rw=[-0.10, -0.26, 0.71], rd=[-0.96, 0.05, -0.26],
           rpiv=-180, rfol=1, rdfol=0, rpole=[-0.5, -0.8, -0.35], lw=[0.16, 0.14, 0.47], sh=[0, -5, -45], shr=10, fl=[0, 0, 0, 0, 0, 0])
W_REL = K(hip=[0.07, 0.0, -0.04], lean=16, twist=30, rw=[0.165, -0.19, 0.74], rd=[-0.99, 0.0, -0.06], rpiv=-180,
          rfol=1, rdfol=0, rpole=[-0.2, -0.8, -0.6], lw=[0.06, 0.22, 0.40], sh=[0, 0, -15], shr=14, fr=[0, 0, 0, 30, 0, 0])
W_FOL = K(hip=[0.085, 0.01, -0.055], lean=25, twist=42, rw=[0.165, -0.07, 0.52], rd=[-0.86, -0.10, 0.50], rpiv=-180,
          rfol=1, rdfol=0, rpole=[-0.3, -0.8, -0.5], lw=[0.03, 0.23, 0.40], sh=[0, 0, -10], shr=2, fr=[0, 0, 0, 40, 0, 0])

def throw_S(t):
    up = curve(t, [(0, 0), (11, 1), (20, 1.07)])
    whip = ramp(t, 19, 23) ** 1.8
    fol = sramp(t, 24, 30)
    back = sramp(t, 33, 54)
    st = mix((W_COCK, up * (1 - whip)), (W_REL, whip * (1 - fol)), (W_FOL, fol * (1 - back)))
    add(st, "hip", [0, 0, -0.010 * curve(t, [(0, 0), (4, 1), (10, 0)])])
    return st

# ---------------------------------------------------------------- bash
# The shield is drawn back as the body twists away, then rammed forward with a step of the front foot.
BASH_N = 46
B_WIND = K(hip=[-0.035, 0.01, -0.04], lean=-3, twist=27, lw=[-0.02, 0.25, 0.43], sh=[0, 0, -5], lpole=[-0.6, 0.6, -0.4],
           rfol=1, rw=[0.06, -0.245, 0.45], rd=list(D0), shl=5)
B_HIT = K(hip=[0.125, 0.0, -0.045], lean=14, twist=-30, lw=[0.215, 0.07, 0.50], sh=[0, 8, -58], lpole=[-0.2, 0.8, -0.6],
          rfol=1, rw=[-0.03, -0.27, 0.45], rd=[-0.28, -0.10, 0.955], rpole=[-0.8, -0.4, -0.3], fl=[0.13, 0, 0, 0, 0, 0],
          fr=[0, 0, 0, 36, 0, 0], shl=8)

def bash_S(t):
    wind = curve(t, [(0, 0), (9, 1), (14, 1.08), (18, 0)])
    go = hit(t, 14, 18, over=0.12) * (1 - sramp(t, 25, 44))
    st = mix((B_WIND, wind), (B_HIT, go))
    add(st, "hip", [0, 0, -0.010 * curve(t, [(0, 0), (3, 1), (8, 0)])])
    step = math.sin(math.pi * ramp(t, 13.5, 17.5)) + 0.8 * math.sin(math.pi * ramp(t, 28, 38))
    add(st, "fl", [0, 0, 0.025 * step, -8 * step, -8 * step, 0])
    return st

# ---------------------------------------------------------------- kneel
# The spear is hoisted upright, high, the body rising onto its toes; then it drops onto its rear knee and drives the
# butt into the floor, and holds there, shield grounded, while the lines run.
KNEEL_N = 92
N_HOIST = K(hip=[-0.012, 0.0, 0.004], lean=-6, twist=-6, rw=[0.10, -0.21, 0.665], rd=[0.03, 0.0, 1.0], rfol=1, rdfol=0,
            rpole=[-0.3, -0.7, -0.6], shr=9, head=[0, -9, 0], fl=[0, 0, 0, 16, 0, 0], fr=[0, 0, 0, 20, 0, 0],
            lw=[0.11, 0.19, 0.42], sh=[0, -3, -32])
N_DOWN = K(hip=[0.035, 0.0, -0.165], lean=15, twist=-5, rw=[0.15, -0.235, 0.432], rd=[0.0, 0.0, 1.0], rfol=0,
           rpole=[-0.5, -0.6, -0.6], fr=[-0.12, 0, 0, 65, 0, 0], kr=[0.3, -0.3, -1.0], kl=[1, 0.35, 0.2],
           lw=[0.13, 0.215, 0.30], lfol=0, sh=[0, 0, -32], shfol=0, lpole=[-0.6, 0.7, 0.0], fold=1, tab=-38, head=[0, 10, 0])

def kneel_S(t):
    hoist = curve(t, [(4, 0), (20, 1.05), (27, 1.0), (38, 1.04), (44, 0)])
    down = hit(t, 38, 44, over=0.07, settle=7) * (1 - sramp(t, 62, 88))
    st = mix((N_HOIST, hoist), (N_DOWN, down))
    add(st, "hip", [0, 0, -0.014 * curve(t, [(0, 0), (4, 1), (10, 0)])])
    if 20 < t < 38: add(st, "rw", [0.002 * math.sin(t * 2.6), 0.002 * math.sin(t * 3.4), 0])
    look = sramp(t, 48, 56) * (1 - sramp(t, 62, 72))                              # the head comes up to watch the lines
    add(st, "head", [0, -16 * look, 0])
    return st

bake("idle", idle_S, IDLE_N, loop=True)
bake("walk", walk_S, WALK_N, loop=True)
bake("thrust", thrust_S, THRUST_N)
bake("lunge", lunge_S, LUNGE_N)
bake("throw", throw_S, THROW_N)
bake("bash", bash_S, BASH_N)
bake("kneel", kneel_S, KNEEL_N)

sc.frame_start = 0; sc.frame_end = KNEEL_N
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
zdlib.emit({"actions": {a_.name: list(a_.frame_range) for a_ in bpy.data.actions if not a_.name.startswith("_")}, "stat": STAT})
