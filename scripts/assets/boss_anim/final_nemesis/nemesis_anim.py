"""rig.blend -> anim.blend: the Nemesis's actions, each also stashed on an NLA track.

A body pose is a table of numbers (S below: where the hips are, each spine joint's lean, where each foot and hand is);
build(S) turns it into bone operations for the Poser. A clip blends a few such tables with eased ramps that each part
of the body reads a little later than the part that drives it. The cloak (three chains of four bones) and nothing else
is simulated: each bone is a weight on a spring, stepped through the clip and baked.
The figure is worked on 1.5 m tall, facing -Y, its right at -X; metres here are metres in the game.
"""
import bpy, sys, os, math, copy
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
def sm(a, b, x): return smooth((x - a) / (b - a))
def lerp(a, b, t): return a + (b - a) * t
def V(*a): return Vector(a)
def curve(t, keys):
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def sig(t, a=2.6):
    """0..1 slow at both ends and fast through the middle (0.5 at 0.5)."""
    t = max(0.0, min(1.0, t)); return t ** a / (t ** a + (1 - t) ** a)
def arc(d0, d1, t):
    d0 = Vector(d0).normalized(); d1 = Vector(d1).normalized()
    ax, ang = d0.rotation_difference(d1).to_axis_angle()
    return Quaternion(ax, ang * t) @ d0
def rest_dir(n): return P.rest[n].to_3x3().col[1].normalized()
def rest_head(n): return P.rest[n].translation.copy()
def carried(world, n):
    p = P.par[n]; return world[p] @ P.rest[p].inverted() @ P.rest[n]
def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True; act.use_fake_user = True

ANKLE0 = {sd: rest_head(f"foot.{sd}") for sd in "LR"}
BALL0 = {sd: rest_head(f"toe.{sd}") for sd in "LR"}
SHO0 = {sd: rest_head(f"upper_arm.{sd}") for sd in "LR"}
SX = {"L": 1.0, "R": -1.0}

# ---------------------------------------------------------------- a body pose as a table
def grip(b, u):
    """A hand's rotation from rest for a weapon pointing along b with its top towards u (at rest: ahead, and up)."""
    b = Vector(b).normalized(); u = Vector(u); u = (u - b * u.dot(b)).normalized()
    A = Matrix((V(0, -1, 0), V(0, 0, 1), V(0, -1, 0).cross(V(0, 0, 1)))).transposed()
    Bm = Matrix((b, u, b.cross(u))).transposed()
    return (Bm @ A.transposed()).to_quaternion()

def stance():
    """The ready stance: left foot ahead, the weapon side drawn back, the hood on the target, the weapon hand carried."""
    return {
        "hl": V(-0.01, 0.0, -0.05),
        "hips": V(4, 0, -12), "spine": V(3, 0, -4), "chest": V(3, 0, -4), "neck": V(-2, 0, 8), "head": V(2, 0, 12),
        "shL": V(0, 0, 0), "shR": V(0, 0, 0),
        "fL": V(-0.03, -0.07, 0), "fL_yaw": 6.0, "fL_pitch": 0.0, "fL_toe": 0.0,
        "fR": V(0.03, 0.07, 0), "fR_yaw": -28.0, "fR_pitch": 0.0, "fR_toe": 0.0,
        # hands: an offset from the shoulder, in the chest's frame (a = 0) or in the upright world frame (a = 1)
        "wR": V(-0.07, -0.20, -0.21), "aR": 0.0, "bR": V(0.2, -0.8, 0.55), "uR": V(0, 0.4, 0.9), "pR": V(-0.7, 0.5, -0.5),
        "wL": V(0.06, -0.13, -0.29), "aL": 0.0, "bL": V(0, -1, 0.1), "uL": V(0, 0, 1), "pL": V(0.7, 0.5, -0.5),
        # a hand set down at a point in the world instead (k = 1)
        "xR": V(0, 0, 0), "kR": 0.0, "xL": V(0, 0, 0), "kL": 0.0,
        "drag": V(0, 0, 0),
    }
GROUP = {"hl": "hips", "hips": "hips", "spine": "torso", "chest": "torso", "neck": "head", "head": "head", "drag": "hips"}
def group(k):
    if k in GROUP: return GROUP[k]
    if k[0] == "f": return "leg" + k[1]
    return "arm" + k[-1] if k[-1] in "LR" else "arm" + k[1]
def mix(A, B, t, **gt):
    """Blend table A towards B by t; a named group (hips, torso, head, armL, armR, legL, legR) may have its own t."""
    out = {}
    for k, a in A.items():
        g = group(k)
        if g.startswith("arm"): g = "arm" + ("L" if k.endswith("L") else "R")
        out[k] = a + (B[k] - a) * gt.get(g, t)
    return out
def through(A, M, B, u):
    """A curve from A to B that passes through M halfway."""
    out = {}
    for k in A:
        ctl = 2 * M[k] - 0.5 * (A[k] + B[k])
        out[k] = (1 - u) * (1 - u) * A[k] + 2 * u * (1 - u) * ctl + u * u * B[k]
    return out
def tweak(S, **kw):
    S = dict(S)
    for k, v in kw.items(): S[k] = v
    return S

FWD = V(0, -1, 0)
FLOOR = 0.035
def build(S):
    pose = {}
    Rp = Quaternion()
    for n in ("hips", "spine", "chest", "neck", "head"):
        p, r, y = S[n]; L = qe(x=p, y=r, z=y)
        pose[n] = {"rot": Rp @ L @ Rp.inverted()}; Rp = Rp @ L
    pose["hips"]["loc"] = Vector(S["hl"])
    for sd in "LR":
        ball = BALL0[sd] + S[f"f{sd}"]; yaw = S[f"f{sd}_yaw"]; pitch = S[f"f{sd}_pitch"]
        qy = q(Z, yaw); qf = qy @ q(X, pitch)
        ankle = ball + qf @ (ANKLE0[sd] - BALL0[sd])
        pose[f"thigh.{sd}"] = {"ik": (ankle, qy @ V(SX[sd] * 0.12, -1, 0.12))}
        pose[f"foot.{sd}"] = {"abs": qf}
        pose[f"toe.{sd}"] = {"abs": qy @ q(X, S[f"f{sd}_toe"])}
    world, _ = P.solve(pose)
    D = world["chest"] @ P.rest["chest"].inverted(); Dq = D.to_quaternion()
    for sd in "LR":
        e = S[f"sh{sd}"]
        pose[f"shoulder.{sd}"] = {"rot": Dq @ qe(*e) @ Dq.inverted()}
    world, _ = P.solve(pose)
    for sd in "LR":
        a = max(0.0, min(1.0, S[f"a{sd}"])); w = S[f"w{sd}"]
        sh = world[f"upper_arm.{sd}"].translation
        Wc = sh + Dq @ w; Ww = sh + w
        W = Wc.lerp(Ww, a).lerp(S[f"x{sd}"], max(0.0, min(1.0, S[f"k{sd}"])))
        Q = Dq.slerp(Quaternion(), a) @ grip(S[f"b{sd}"], S[f"u{sd}"])
        pole = Dq.slerp(Quaternion(), a) @ S[f"p{sd}"]
        pose[f"upper_arm.{sd}"] = {"ik": (W, pole)}
        pose[f"hand.{sd}"] = {"abs": Q}
    world, _ = P.solve(pose)
    # A hip tab lies on its thigh: when the knee comes ahead of where the tab hangs, the tab is pushed out by it.
    Hq = (world["hips"] @ P.rest["hips"].inverted()).to_quaternion(); fwd = Hq @ FWD
    for sd in "LR":
        M0 = carried(world, f"tab.{sd}"); h = M0.translation; cdir = M0.to_3x3().col[1].normalized()
        knee = world[f"shin.{sd}"].translation
        d = (knee + fwd * 0.10 - h).normalized()
        amt = sm(0.0, 0.18, d.dot(fwd) - cdir.dot(fwd))
        a = arc(cdir, d, amt); L = P.len[f"tab.{sd}"]
        if h.z + a.z * L < 0.09:                           # a tab cannot hang through the ground: it lies forward on it
            dz = max(-1.0, min(0.3, (0.09 - h.z) / L)); flat = Vector((fwd.x, fwd.y, 0)).normalized()
            a = flat * math.sqrt(max(0.0, 1 - dz * dz)) + Vector((0, 0, dz))
        pose[f"tab.{sd}"] = {"aim": a}
    pose["_drag"] = Vector(S["drag"])
    return pose

def kneel(S, sd, knee_z=0.05):
    """Lower the hips of table S until that side's knee rests on the ground."""
    lo, hi = -0.40, 0.0
    for _ in range(18):
        mid = 0.5 * (lo + hi); T = dict(S); T["hl"] = V(S["hl"].x, S["hl"].y, mid)
        world, _ = P.solve(build(T))
        if world[f"shin.{sd}"].translation.z > knee_z: hi = mid
        else: lo = mid
    S = dict(S); S["hl"] = V(S["hl"].x, S["hl"].y, 0.5 * (lo + hi)); return S

# ---------------------------------------------------------------- the cloak: weights on springs
class Dyn:
    def __init__(self, name, w, z, grav, wind, maxang, anchor, out, margin):
        self.name = name; self.w = w; self.z = z; self.grav = grav; self.wind = wind; self.maxang = math.radians(maxang)
        self.par = P.par[name]; self.rest_dir = rest_dir(name); self.len = P.len[name]
        h = rest_head(name); self.ang = math.atan2(h.y, h.x)
        self.level = int(name[5]) - 1; self.p = None; self.v = Vector(); self.h = None
        self.anchor = anchor; self.out = Vector(out); self.wall = h + self.rest_dir * self.len - self.out * margin
DYN = {}
for sd, out in (("L", (1, 0, 0)), ("R", (-1, 0, 0)), ("B", (0, 1, 0)), ("FL", (0.5, -0.866, 0)), ("FR", (-0.5, -0.866, 0))):
    for k in range(4):
        DYN[f"cloak{k + 1}.{sd}"] = Dyn(f"cloak{k + 1}.{sd}", w=(16, 13, 11, 9.5)[k], z=(0.75, 0.65, 0.55, 0.5)[k],
            grav=(0.25, 0.4, 0.5, 0.6)[k], wind=(0.0, 0.015, 0.03, 0.05)[k], maxang=(12, 18, 24, 34)[k],
            anchor=("chest", "chest", "spine", "hips")[k], out=out, margin=(0.03, 0.05, 0.07, 0.10)[k])
LEVELS = 4; SUB = 6
INERTIA = 0.35
FLOORS = (0.05, 0.06, 0.08, 0.14)      # how high a layer's bone tip stays so the cloth round it clears the ground
FLOOR = 0.035

def wind(d, t, period, life):
    if d.wind == 0.0 or life == 0.0: return Vector()
    a = d.ang / TAU; k = d.level
    tan = Vector((-math.sin(d.ang), math.cos(d.ang), 0)); rad = Vector((math.cos(d.ang), math.sin(d.ang), 0))
    return (tan * s(t / period - a - 0.14 * k) + rad * (0.6 * s(2 * t / period - 2 * a - 0.2 * k))) * (d.wind * life)

def step_dyn(pose, t, ts=1.0, period=90.0, life=1.0, low=False):
    """Advance every cloak bone one frame (ts: seconds of game time a frame stands for, in thirtieths) under the pose."""
    drag = pose.pop("_drag", Vector()); DT = ts / 30.0 / SUB
    for level in range(LEVELS):
        world, _ = P.solve(pose)
        for d in DYN.values():
            if d.level != level: continue
            M0 = carried(world, d.name); h = M0.translation.copy(); cdir = M0.to_3x3().col[1].normalized()
            tdir = (cdir.lerp(d.rest_dir, d.grav) + wind(d, t, period, life) + drag * (0.4 + 0.3 * level)).normalized()
            A = world[d.anchor] @ P.rest[d.anchor].inverted(); n = A.to_3x3() @ d.out
            dep = (h + tdir * d.len - A @ d.wall).dot(n)
            if dep < 0: tdir = (tdir * d.len - n * dep).normalized()
            tip = h + tdir * d.len
            fl = FLOORS[level] if low else 0.02
            if tip.z < fl:                                 # it cannot hang through the ground: it spreads out on it
                flat = Vector((tdir.x, tdir.y, 0))
                if flat.length < 1e-4: flat = Vector((n.x, n.y, 0))
                dz = max(-1.0, min(0.35, (fl - h.z) / d.len))
                tdir = (flat.normalized() * math.sqrt(max(0.0, 1 - dz * dz)) + Vector((0, 0, dz))).normalized()
            if d.p is None: d.p = h + tdir * d.len; d.v = Vector(); d.h = h
            h0 = d.h
            for i in range(SUB):
                hh = h0.lerp(h, (i + 1) / SUB)
                d.p = d.p + (h - h0) * ((1 - INERTIA) / SUB)        # the cloth is carried along; it feels only part of the body's jolts
                acc = (hh + tdir * d.len - d.p) * (d.w * d.w) - d.v * (2 * d.z * d.w)
                d.v += acc * DT
                pn = d.p + d.v * DT
                r = (pn - hh).normalized()
                ang = tdir.angle(r)
                if ang > d.maxang: r = arc(tdir, r, d.maxang / ang)
                pn = hh + r * d.len
                if pn.z < fl and hh.z > fl:
                    pn.z = fl; r = (pn - hh).normalized(); pn = hh + r * d.len
                d.v = (pn - d.p) / DT; d.p = pn
            d.h = h
            pose[d.name] = {"aim": (d.p - h).normalized()}
    return pose

SEAM = {}
NODYN = os.environ.get("ZD_NODYN") == "1"
def bake(name, fn, end, loop=False, ts=1.0, life=0.0, period=90.0, low=False):
    """Key one action: fn(t) is the body's table; the cloak is stepped through it."""
    for d in DYN.values(): d.p = None
    def one(f):
        if NODYN:
            p = build(fn(float(f))); p.pop("_drag", None); return p
        return step_dyn(build(fn(float(f))), float(f), ts, period, life, low)
    if loop:
        for cyc in range(8): poses = [one(f) for f in range(end)]
        again = one(end)
        SEAM[name] = 0 if NODYN else max(round(math.degrees(Vector(again[n]["aim"]).angle(Vector(poses[0][n]["aim"]))), 2) for n in DYN)
        poses.append(poses[0])
    else:
        for f in range(-60, 0): one(0)
        poses = [one(f) for f in range(end + 1)]
    act = poser.new_action(rig, name); P.prevq.clear()
    for f, pose in enumerate(poses): P.key(pose, f)
    act.frame_range = (0, end); act.use_frame_range = True; act.use_cyclic = loop
    stash(act)

ST = stance()

# ---------------------------------------------------------------- idle: the ready stance, alive
IDLE_N = 90
def idle_S(t):
    ph = t / IDLE_N
    br = s(2 * ph); late = s(2 * (ph - 0.07)); sh = s(ph); shl = s(ph - 0.08)        # two breaths, one shift of weight
    S = dict(ST)
    S["hl"] = ST["hl"] + V(0.022 * sh, 0.006 * c(ph), -0.007 * br - 0.006 * abs(sh))
    S["hips"] = ST["hips"] + V(0.6 * br, 1.6 * sh, 1.5 * s(ph - 0.1))
    S["spine"] = ST["spine"] + V(-0.8 * br, -1.2 * shl, -0.8 * s(ph - 0.14))
    S["chest"] = ST["chest"] + V(-1.8 * late, -0.8 * shl, -1.0 * s(ph - 0.18))
    S["neck"] = ST["neck"] + V(0.9 * late, 0, 2.0 * s(ph - 0.22))
    S["head"] = ST["head"] + V(1.2 * s(2 * (ph - 0.14)) + 1.0 * s(ph - 0.3), 0.8 * sh, 5.0 * s(ph - 0.27))   # the hood tracks
    S["shR"] = V(0, 1.5 * late, 0); S["shL"] = V(0, -1.5 * late, 0)
    S["wR"] = ST["wR"] + V(0.004 * s(ph - 0.2), 0.008 * s(ph - 0.3), 0.012 * s(2 * (ph - 0.16)))
    S["bR"] = ST["bR"] + V(0.05 * s(ph - 0.35), 0, 0.07 * s(2 * (ph - 0.24)))
    S["wL"] = ST["wL"] + V(-0.004 * s(ph - 0.2), 0.010 * s(ph - 0.36), 0.008 * s(2 * (ph - 0.2)))
    # the heel of the foot the weight has left comes off the ground a little
    S["fR_pitch"] = 7 * sm(0.3, 1.0, sh); S["fL_pitch"] = 5 * sm(0.3, 1.0, -sh)
    return S
bake("idle", idle_S, IDLE_N, loop=True, life=1.0, period=IDLE_N)

# ---------------------------------------------------------------- walk: its move loop is a run
RUN_N = 20             # frames per loop as keyed; the game plays a loop per RUN_M metres
STANCE = 0.26          # share of the loop a foot is on the ground: the rest of each step is flight
STEP = 0.20            # the ball of the foot travels +-STEP under the body while it is down
RUN_M = 2 * STEP / STANCE
RUN_SPEED = 5.2        # nemesis.tres move_speed_mps
RUN_TS = (RUN_M / RUN_SPEED) * 30.0 / RUN_N      # game time one keyed frame stands for, in frames
def run_foot(p):
    """Phase 0 = the foot lands. (forward offset, lift, pitch: + is heel up, the toe's pitch)."""
    p %= 1.0
    if p < STANCE:
        u = p / STANCE
        pitch = -9 * (1 - sm(0, 0.3, u)) + 48 * sm(0.45, 1.0, u) ** 1.3
        return lerp(-STEP, STEP, u), 0.012 * (1 - sm(0, 0.2, u)), pitch, min(pitch, 0.0)
    v = (p - STANCE) / (1 - STANCE)
    y = lerp(STEP, -STEP, smooth(v) * 0.8 + v * 0.2) + 0.05 * math.sin(math.pi * min(1.0, v / 0.4))
    lift = 0.15 * math.sin(math.pi * v ** 0.75) + 0.012 * sm(0.8, 1.0, v)
    pitch = 48 + 30 * sm(0, 0.3, v) - 87 * sm(0.38, 1.0, v)
    return y, lift, pitch, pitch * 0.5
def run_S(t):
    ph = t / RUN_N
    S = dict(ST)
    for sd, p in (("R", ph), ("L", ph + 0.5)):
        y, lift, pitch, toe = run_foot(p)
        S[f"f{sd}"] = V(-SX[sd] * 0.045, y, lift); S[f"f{sd}_yaw"] = SX[sd] * 3.0
        S[f"f{sd}_pitch"] = pitch; S[f"f{sd}_toe"] = toe
    bob = c(2 * (ph - 0.14))                           # lowest just after each landing, highest in flight
    S["hl"] = V(-0.014 * c(ph - 0.13), -0.03, -0.062 - 0.022 * bob)
    S["hips"] = V(10 + 1.5 * bob, 3.0 * s(ph - 0.05), 9 * c(ph))
    S["spine"] = V(5, -2.0 * s(ph - 0.08), -8 * c(ph - 0.03))
    S["chest"] = V(5 + 2.0 * c(2 * (ph - 0.2)), -1.5 * s(ph - 0.1), -8 * c(ph - 0.06))
    S["neck"] = V(-5, 0, 3.5 * c(ph - 0.08))
    S["head"] = V(-8 + 2.0 * c(2 * (ph - 0.26)), 1.0 * s(ph - 0.15), 3.5 * c(ph - 0.1))
    S["shR"] = V(0, 0, 3 * c(ph - 0.04)); S["shL"] = V(0, 0, 3 * c(ph - 0.04))
    # The weapon hand is carried ready and only rides the steps; the free arm pumps against its leg.
    S["wR"] = V(-0.06, -0.19 + 0.045 * c(ph - 0.06), -0.20 + 0.018 * c(2 * (ph - 0.24)))
    S["bR"] = V(0.2, -0.85, 0.45 + 0.12 * c(2 * (ph - 0.3)))
    S["wL"] = V(0.07, -0.11 - 0.105 * c(ph - 0.05), -0.25 + 0.05 * c(ph - 0.05) + 0.015 * c(2 * (ph - 0.2)))
    S["drag"] = V(0, 0.14, 0.0)
    return S
bake("walk", run_S, RUN_N, loop=True, ts=RUN_TS)

# ---------------------------------------------------------------- slash: the blade's cut, right to left
SLASH_END = 40; SLASH_STRIKE = 21; SLASH_HOLD = 25
WIND = tweak(ST, hl=V(-0.04, 0.045, -0.085), hips=V(3, -2, -24), spine=V(2, 0, -11), chest=V(-2, 0, -13),
             neck=V(0, 0, 20), head=V(4, 0, 26),
             wR=V(-0.13, -0.04, -0.22), bR=V(-0.45, 0.8, 0.35), uR=V(0, -0.3, 0.9), pR=V(-0.7, 0.6, -0.2), shR=V(0, 4, -8),
             wL=V(-0.07, -0.25, -0.13), pL=V(0.8, 0.2, -0.5), fL_pitch=10.0)
CUT = tweak(ST, hl=V(0.01, -0.075, -0.095), hips=V(9, 2, 6), spine=V(5, 0, 9), chest=V(5, 0, 11),
            neck=V(-2, 0, -11), head=V(3, 0, -13),
            wR=V(0.09, -0.31, -0.02), aR=1.0, bR=V(0.12, -1, 0.02), uR=V(0, 0, 1), pR=V(-0.7, 0.2, -0.6), shR=V(0, 0, 10),
            wL=V(0.10, -0.02, -0.26), fR_pitch=34.0)
PAST = tweak(ST, hl=V(0.04, -0.09, -0.10), hips=V(10, 3, 22), spine=V(5, 0, 14), chest=V(4, 0, 16),
             neck=V(-2, 0, -22), head=V(4, 0, -27),
             wR=V(0.24, -0.03, -0.13), aR=1.0, bR=V(0.85, 0.4, -0.25), uR=V(0, 0, 1), pR=V(-0.5, -0.3, -0.7), shR=V(0, 0, 12),
             wL=V(0.12, 0.05, -0.25), fR_pitch=44.0)
def slash_S(t):
    if t <= 17:
        a = curve(t, [(0, 0), (4, -0.10), (15, 1.0), (17, 1.06)])           # a small give the other way, then the coil
        S = mix(ST, WIND, a, hips=curve(t, [(0, 0), (3, -0.08), (13, 1.0), (17, 1.04)]),
                armR=curve(t, [(0, 0), (5, -0.05), (16, 1.0), (17, 1.03)]), head=sm(1, 12, t), armL=sm(3, 15, t))
    elif t <= SLASH_HOLD:
        u = sig((t - 17) / 8.0)
        S = through(WIND, CUT, PAST, u)
        ub = sig((t - 16.4) / 8.0); B_ = through(WIND, CUT, PAST, min(1.0, ub))      # the hips lead the cut
        for k in ("hl", "hips"): S[k] = B_[k]
    else:
        o = curve(t, [(25, 0), (28, 1), (40, 0)])                             # carried a little past, then home
        OV = mix(PAST, tweak(PAST, wR=V(0.25, 0.03, -0.17), chest=V(4, 0, 19)), o)
        S = mix(OV, ST, sm(27, 40, t), hips=sm(26, 37, t), torso=sm(27, 39, t), armR=sm(28, 40, t), armL=sm(26, 40, t),
                head=sm(27, 38, t), legR=sm(28, 38, t))
    return S
bake("slash", slash_S, SLASH_END)

# ---------------------------------------------------------------- shoot: raise, aim, kick, settle
SHOOT_END = 45; SHOOT_STRIKE = 24; SHOOT_HOLD = 31
AIM = tweak(ST, hl=V(0.0, -0.02, -0.065), hips=V(3, 0, 12), spine=V(2, 0, 8), chest=V(1, 0, 10),
            neck=V(0, 0, -13), head=V(3, -3, -15),
            wR=V(0.045, -0.325, 0.03), aR=1.0, bR=V(0, -1, 0), uR=V(0, 0, 1), pR=V(-0.6, 0.2, -0.8), shR=V(0, 0, 8),
            wL=V(-0.03, -0.20, -0.17), pL=V(0.8, 0.3, -0.5), fR_pitch=12.0)
def shoot_S(t):
    dip = curve(t, [(0, 0), (4, 1), (9, 0)])
    up = curve(t, [(3, 0), (13, 1.08), (17, 0.98), (20, 1.0), (33, 1.0), (45, 0)])
    S = mix(ST, AIM, up, hips=curve(t, [(1, 0), (11, 1.0), (33, 1.0), (43, 0)]),
            torso=curve(t, [(2, 0), (12, 1.04), (16, 1.0), (33, 1.0), (44, 0)]),
            head=curve(t, [(1, 0), (9, 1.0), (34, 1.0), (43, 0)]),
            armR=curve(t, [(4, 0), (14, 1.0), (33, 1.0), (45, 0)]), armL=curve(t, [(3, 0), (13, 1.0), (34, 1.0), (45, 0)]))
    S["hl"] = S["hl"] + V(0, 0, -0.02 * dip); S["wR"] = S["wR"] + V(0, 0.02 * dip, -0.03 * dip + 0.03 * (up - 1) * (t < 20))
    hold = curve(t, [(16, 0), (20, 1), (33, 1), (37, 0)])
    S["wR"] = S["wR"] + V(0.003 * s(t / 19.0), 0, 0.004 * s(t / 13.0)) * hold
    # the kick: gone again by SHOOT_HOLD, so a volley can run strike..hold once a shot
    k = curve(t, [(24, 0), (25.6, 1.0), (28.5, -0.12), (31, 0)]); k2 = curve(t, [(24.6, 0), (26.6, 1.0), (30, -0.1), (32, 0)])
    S["wR"] = S["wR"] + V(0, 0.075 * k, 0.03 * k)
    S["bR"] = arc(S["bR"], V(0, -0.82, 0.57), k * (1 if t >= 24 else 0))
    S["shR"] = S["shR"] + V(0, 0, -7 * k)
    S["chest"] = S["chest"] + V(-5 * k2, 0, -4 * k2); S["spine"] = S["spine"] + V(-2.5 * k2, 0, -2 * k2)
    S["hl"] = S["hl"] + V(0, 0.018 * k2, -0.008 * k2)
    S["head"] = S["head"] + V(2.5 * curve(t, [(25, 0), (27.5, 1), (32, 0)]), 0, 0)
    return S
bake("shoot", shoot_S, SHOOT_END)

# ---------------------------------------------------------------- cast: the free hand lifts the card, then drives it out
CAST_END = 57; CAST_STRIKE = 30; CAST_HOLD = 36
GATHER = tweak(ST, hl=V(-0.02, 0.02, -0.085), hips=V(6, 0, -4), spine=V(4, 0, 4), chest=V(4, 0, 6), neck=V(0, 0, -2), head=V(6, 0, -4),
               wL=V(-0.10, -0.20, -0.19), pL=V(0.8, 0.3, -0.4), wR=V(-0.09, -0.10, -0.27))
LIFT = tweak(ST, hl=V(-0.01, 0.025, -0.02), hips=V(-2, 0, -2), spine=V(-3, 0, 6), chest=V(-6, 0, 8), neck=V(-4, 0, -4), head=V(-8, 0, -8),
             wL=V(0.20, -0.17, 0.17), aL=1.0, bL=V(0.2, -0.5, 0.85), uL=V(0, 0.8, 0.5), pL=V(0.7, 0.3, -0.6), shL=V(0, -8, 0),
             wR=V(-0.10, 0.02, -0.29), bR=V(-0.1, -0.5, -0.8), fR_pitch=10.0, fL_pitch=6.0)
THRUST = tweak(ST, hl=V(0.0, -0.075, -0.10), hips=V(9, 0, -22), spine=V(5, 0, -8), chest=V(5, 0, -10), neck=V(-3, 0, 16), head=V(2, 0, 22),
               wL=V(-0.05, -0.325, 0.0), aL=1.0, bL=V(0, -1, 0.05), uL=V(0, 0, 1), pL=V(0.6, 0.2, -0.7), shL=V(0, 0, -10),
               wR=V(-0.12, 0.08, -0.26), bR=V(-0.2, 0.3, -0.9), fR_pitch=36.0)
def cast_S(t):
    if t <= 27:
        g = curve(t, [(0, 0), (9, 1), (16, 0)])
        l = curve(t, [(8, 0), (21, 1.05), (25, 1.0), (27, 1.03)])
        S = mix(mix(ST, GATHER, g, armL=curve(t, [(0, 0), (10, 1), (15, 0.6)])), LIFT, l,
                hips=curve(t, [(8, 0), (19, 1.0)]), armL=curve(t, [(10, 0), (22, 1.04), (26, 1.0)]),
                armR=curve(t, [(9, 0), (22, 1.0)]), head=curve(t, [(9, 0), (20, 1.0)]))
        tr = sm(20, 24, t)                                                        # the card held up: it strains
        S["wL"] = S["wL"] + V(0.004 * s(t / 3.1), 0, 0.005 * s(t / 2.3)) * tr
    elif t <= CAST_HOLD:
        u = sig((t - 27) / 3.0, 2.2) if t <= 30 else 1.0
        S = mix(LIFT, THRUST, u, hips=sig((t - 26.5) / 3.0, 2.2), armL=sig((t - 27.3) / 2.7, 2.4))
        S = mix(S, tweak(S, wL=S["wL"] + V(0, 0.03, 0)), 1 - u)                   # the hand comes past the hood, not through it
        p = curve(t, [(30, 0), (31.5, 1), (34, 0.3), (36, 0.45)])                 # carried into the hold, pressed
        S["hl"] = S["hl"] + V(0, -0.012 * p, -0.008 * p); S["chest"] = S["chest"] + V(2 * p, 0, -3 * p)
        S["wL"] = S["wL"] + V(0, -0.012 * p, 0.004 * s(t / 2.5) * (t > 30))
    else:
        H = cast_S(36.0)
        S = mix(H, ST, sm(37, 57, t), hips=sm(36, 52, t), torso=sm(37, 54, t), head=sm(38, 54, t), armL=sm(38, 57, t),
                armR=sm(37, 55, t), legR=sm(38, 50, t))
        S["wL"] = S["wL"] + V(0, 0, -0.03 * math.sin(math.pi * sm(38, 57, t)))    # the arm drops as it comes home
    return S
bake("cast", cast_S, CAST_END)

# ---------------------------------------------------------------- dash: a low stretched lunge, held
DASH_END = 18; DASH_IN = 4; DASH_OUT = 13
LUNGE = tweak(ST, hl=V(0.0, -0.11, -0.125), hips=V(30, 0, -8), spine=V(10, 0, -3), chest=V(8, 0, -3),
              neck=V(-14, 0, 6), head=V(-18, 0, 8),
              fL=V(-0.05, -0.22, 0.05), fL_yaw=2.0, fL_pitch=-12.0, fL_toe=-6.0,
              fR=V(0.05, 0.36, 0.12), fR_yaw=-6.0, fR_pitch=72.0, fR_toe=40.0,
              wR=V(-0.07, 0.13, -0.27), bR=V(-0.1, 0.75, -0.6), uR=V(0, 0.6, 0.8), pR=V(-0.7, 0.6, 0.2),
              wL=V(0.07, 0.12, -0.27), pL=V(0.7, 0.6, 0.2), shR=V(0, 0, -8), shL=V(0, 0, 8),
              drag=V(0, 0.6, 0.06))
def dash_S(t):
    a = curve(t, [(0, 0), (1.2, -0.10), (DASH_IN, 1.05), (6, 1.0), (DASH_OUT, 1.0), (DASH_END, 0)])
    S = mix(ST, LUNGE, a, head=curve(t, [(0, 0), (3, 1.0), (DASH_OUT, 1.0), (17, 0)]),
            armR=curve(t, [(0.5, 0), (5, 1.0), (14, 1.0), (DASH_END, 0)]), armL=curve(t, [(0.5, 0), (5, 1.0), (14, 1.0), (DASH_END, 0)]),
            legR=curve(t, [(0, 0), (DASH_IN, 1.0), (DASH_OUT, 1.0), (17.5, 0)]), legL=curve(t, [(0, 0), (3.5, 1.0), (DASH_OUT, 1.0), (16.5, 0)]))
    hold = curve(t, [(4, 0), (6, 1), (12, 1), (14, 0)])
    S["hl"] = S["hl"] + V(0, 0, 0.006 * s(t / 5.0)) * hold
    S["chest"] = S["chest"] + V(1.5 * s(t / 4.0) * hold + 7 * curve(t, [(13, 0), (15, 1), (18, 0)]), 0, 0)    # the stop throws it forward
    S["drag"] = LUNGE["drag"] * curve(t, [(0, 0), (3, 1), (12.5, 1), (14.5, -0.25), (18, 0)])
    for sd in "LR":                                                             # the feet come back under it in an arc
        S[f"f{sd}"] = S[f"f{sd}"] + V(0, 0, 0.03 * math.sin(math.pi * sm(DASH_OUT, 17.5, t)))
    return S
bake("dash", dash_S, DASH_END)

# ---------------------------------------------------------------- form: up from a crouch on one knee (its rise)
FORM_END = 60; FORM_STOOD = 33
CROUCH = tweak(ST, hl=V(0.0, -0.05, -0.2), hips=V(24, 0, -4), spine=V(26, 0, -2), chest=V(22, 0, -2), neck=V(12, 0, 4), head=V(16, 0, 4),
               fR=V(0.03, 0.15, 0), fR_yaw=-6.0, fR_pitch=88.0, fR_toe=0.0,
               wR=V(0, 0, 0), xR=V(-0.30, -0.30, 0.22), kR=1.0, bR=V(0.3, -0.9, -0.2), pR=V(-0.8, 0.4, 0.3),
               wL=V(0, 0, 0), xL=V(0.34, -0.30, 0.22), kL=1.0, pL=V(0.8, 0.4, 0.3), shR=V(0, 0, 8), shL=V(0, 0, -8))
CROUCH = kneel(CROUCH, "R")
LOOK = tweak(CROUCH, neck=V(-10, 0, 6), head=V(-22, 0, 8), chest=V(16, 0, -2))        # the head is up; the eyes show
UP = tweak(ST, hl=ST["hl"] + V(0, 0, 0.035), hips=V(1, 0, -10), spine=V(-1, 0, -4), chest=V(-3, 0, -4), head=V(-2, 0, 12),
           wR=V(-0.05, -0.12, -0.30), wL=V(0.05, -0.10, -0.31))
def form_S(t):
    look = curve(t, [(5, 0), (17, 1.0)])
    S = mix(CROUCH, LOOK, look)
    br = sm(0, 3, t) * (1 - sm(14, 20, t))
    S["chest"] = S["chest"] + V(1.2 * s(t / 22.0) * br, 0, 0)
    if t > 13:
        r = curve(t, [(13, 0), (30, 1.0)])
        S = mix(S, UP, r, hips=curve(t, [(13, 0), (16, -0.04), (29, 1.0)]), torso=curve(t, [(15, 0), (31, 1.0)]),
                head=curve(t, [(17, 0), (32, 1.0)]), armR=curve(t, [(15, 0), (32, 1.0)]), armL=curve(t, [(16, 0), (33, 1.0)]),
                legR=curve(t, [(17, 0), (27, 1.0)]))
        S["fR"] = S["fR"] + V(0, 0, 0.035 * math.sin(math.pi * sm(18, 27, t)))        # the back foot is set down again
        S["fR_pitch"] = S["fR_pitch"] * (1 - sm(22, 27, t)) if t > 22 else S["fR_pitch"]
    if t > 30:
        # the shrug: the shoulders up and back and let go, a quick turn each way so the layers fall into place
        sh = curve(t, [(31, 0), (36, 1.0), (40, -0.25), (44, 0)])
        tw = curve(t, [(32, 0), (36, 1.0), (40, -0.7), (44, 0.2), (48, 0)])
        S["shR"] = S["shR"] + V(0, 12 * sh, -6 * sh); S["shL"] = S["shL"] + V(0, -12 * sh, 6 * sh)
        S["chest"] = S["chest"] + V(-4 * sh, 0, 7 * tw); S["spine"] = S["spine"] + V(0, 0, 4 * tw)
        S["hl"] = S["hl"] + V(0, 0, 0.012 * sh)
        d = curve(t, [(42, 0), (52, 1.06), (56, 0.98), (60, 1.0)])                    # and down into the stance
        S = mix(S, ST, d, armR=curve(t, [(41, 0), (53, 1.05), (58, 1.0)]), armL=curve(t, [(43, 0), (55, 1.0)]),
                head=curve(t, [(40, 0), (50, 1.0)]))
    return S
bake("form", form_S, FORM_END, low=True)

# ---------------------------------------------------------------- flinch: a hit rocks it back
FLINCH_END = 14
def flinch_S(t):
    k = curve(t, [(0, 0), (3, 1.0), (8, -0.12), (14, 0)])
    S = mix(ST, HIT, k, head=curve(t, [(0.5, 0), (4.5, 1.0), (10, -0.15), (14, 0)]), armR=curve(t, [(1, 0), (5, 1.0), (14, 0)]),
            armL=curve(t, [(1, 0), (5.5, 1.0), (14, 0)]))
    return S

# ---------------------------------------------------------------- death: reel, knees, fold, the hood last
DEATH_END = 48
REEL = tweak(ST, hl=V(0.01, 0.055, -0.035), hips=V(-6, 0, -6), spine=V(-7, 0, -2), chest=V(-9, 0, 4), neck=V(-8, 0, 4), head=V(-14, 4, 6),
             wR=V(-0.13, -0.14, -0.20), bR=V(0.1, -0.5, -0.8), wL=V(0.14, -0.14, -0.22), shR=V(0, 8, 0), shL=V(0, -8, 0), fL_pitch=-10.0)
SAG = tweak(ST, hl=V(0.0, -0.03, -0.14), hips=V(10, 3, -4), spine=V(8, 0, 0), chest=V(8, 0, 2), neck=V(10, 0, 2), head=V(14, -4, 2),
            wR=V(-0.05, -0.08, -0.32), bR=V(0, -0.3, -0.95), wL=V(0.05, -0.08, -0.32), fR_pitch=30.0, fL_pitch=22.0)
KNEES = tweak(ST, hl=V(0.0, -0.12, -0.2), hips=V(-4, 0, 0), spine=V(4, 0, 0), chest=V(6, 0, 0), neck=V(4, 0, 0), head=V(4, 3, 0),
              fR=V(0.03, 0.07, 0), fR_yaw=-8.0, fR_pitch=88.0, fL_yaw=4.0, fL_pitch=88.0,
              wR=V(-0.03, -0.06, -0.33), bR=V(0, -0.2, -1), wL=V(0.03, -0.06, -0.33))
KNEES = kneel(KNEES, "R")
FOLD = tweak(KNEES, hl=V(0.0, -0.10, -0.2), hips=V(34, 0, 0), spine=V(24, 0, 0), chest=V(16, 0, 0), neck=V(-22, 0, 0), head=V(-30, 0, 0),
             xR=V(-0.30, -0.46, 0.24), kR=1.0, xL=V(0.30, -0.46, 0.24), kL=1.0, pR=V(-0.8, 0.2, 0.4), pL=V(0.8, 0.2, 0.4))
FOLD = kneel(FOLD, "R")
DOWN = tweak(FOLD, neck=V(-8, 0, 0), head=V(-8, 0, -5), chest=V(18, 0, 0))
HIT = mix(ST, REEL, 0.55)
exec_flinch = bake("flinch", flinch_S, FLINCH_END)
def death_S(t):
    if t <= 16:
        S = mix(ST, REEL, curve(t, [(0, 0), (6, 1.0), (9, 0.9)]), head=curve(t, [(0, 0), (2, -0.2), (8, 1.0)]),
                armR=curve(t, [(1, 0), (9, 1.0)]), armL=curve(t, [(1, 0), (10, 1.0)]))
        S = mix(S, SAG, sm(8, 17, t), head=sm(10, 18, t), armR=sm(9, 18, t), armL=sm(9, 18, t))
    else:
        S0 = death_S(16.0); S0 = mix(S0, SAG, 1.0, head=sm(10, 18, t), armR=sm(9, 18, t), armL=sm(9, 18, t))
        k = curve(t, [(16, 0), (24, 1.0)]) ** 1.6                                     # the knees give: it falls faster
        S = mix(S0, KNEES, min(1.0, k), head=sm(18, 27, t), torso=sm(17, 26, t), armR=sm(18, 28, t), armL=sm(18, 29, t))
        b = curve(t, [(24, 0), (26, 1), (30, 0)])                                     # the knees hit: the body jolts
        S["spine"] = S["spine"] + V(5 * b, 0, 0); S["head"] = S["head"] + V(7 * curve(t, [(25, 0), (28, 1), (32, 0)]), 0, 0)
        if t > 27:
            f = curve(t, [(27, 0), (31, 0.08), (41, 1.0)])
            S = mix(S, FOLD, f, head=curve(t, [(29, 0), (40, 1.0)]), armR=curve(t, [(28, 0), (39, 1.0)]), armL=curve(t, [(29, 0), (41, 1.0)]))
            hd = curve(t, [(37, 0), (44, 1.08), (48, 1.0)])                           # the hood goes down last
            S = mix(S, DOWN, 0.0, head=hd, torso=curve(t, [(38, 0), (46, 1.0)]))
    return S
bake("death", death_S, DEATH_END, low=True)

TESTS = [ST, AIM, LIFT, THRUST, WIND, CUT, PAST, LUNGE, CROUCH, LOOK, KNEES, FOLD, DOWN, REEL, SAG, GATHER, UP]
_nd = NODYN; NODYN = True
bake("test", lambda t: TESTS[int(t)], len(TESTS) - 1)
NODYN = _nd
sc.frame_start = 0; sc.frame_end = 60
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
world, _ = P.solve(build(CROUCH))
zdlib.emit({"actions": {a_.name: list(a_.frame_range) for a_ in bpy.data.actions}, "seam_deg": SEAM,
            "run_m_per_loop": round(RUN_M, 3), "run_ts": round(RUN_TS, 3),
            "crouch_hips_z": round(world["hips"].translation.z, 3), "crouch_head_base_z": round(world["head"].translation.z, 3)})
