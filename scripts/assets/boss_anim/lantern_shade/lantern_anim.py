"""rig.blend -> anim.blend: the Lantern Shade's actions, each also stashed on an NLA track.

The body, the arms and the hands are written as functions of time (periodic terms for the loops, eased ramps read with
a delay per joint for the attacks). Everything that hangs (the lantern on its chain, the talisman strings and tags,
the mantle's hem, the robe's strips) is not written by hand: each of those bones is a small weight on a spring or a
pendulum that the body drags along, stepped through the clip and then keyed. That is what makes them arrive late,
swing past and settle.
"""
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
def ramp(t, f0, f1): return smooth((t - f0) / (f1 - f0))
def curve(t, keys):
    """Eased interpolation through (frame, value) keys."""
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def arc(d0, d1, t):
    """Swing direction d0 towards d1 by fraction t (t may pass 1)."""
    d0 = Vector(d0).normalized(); d1 = Vector(d1).normalized()
    ax, ang = d0.rotation_difference(d1).to_axis_angle()
    return Quaternion(ax, ang * t) @ d0
def bez(a, m, b, u):
    """A curved path from a to b that bows towards m."""
    a, m, b = Vector(a), Vector(m), Vector(b)
    return a * (1 - u) ** 2 + m * (2 * u * (1 - u)) + b * u * u
def V(*a): return Vector(a)
def rest_dir(n): return P.rest[n].to_3x3().col[1].normalized()
def rest_head(n): return P.rest[n].translation.copy()

WR = {"L": rest_head("hand.L"), "R": rest_head("hand.R")}
HAND_DIR = {sd: rest_dir(f"hand.{sd}") for sd in "LR"}
def _perp(v, axis): v = Vector(v); axis = Vector(axis).normalized(); return (v - axis * v.dot(axis)).normalized()
PALM = {"L": _perp((-1, 0, 0), HAND_DIR["L"])}          # the left palm faces the body at rest
POLE0 = {"L": V(0.6, 0.6, -0.2), "R": V(-0.6, 0.6, -0.1)}   # the elbows point out and back

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True

# ---------------------------------------------------------------- what hangs: springs and a pendulum
class Dyn:
    def __init__(self, name, kind, w=6.0, z=0.3, grav=0.5, wind=0.0, maxang=60.0, anchor=None, out=None, margin=0.1):
        self.name = name; self.kind = kind; self.w = w; self.z = z; self.grav = grav; self.wind = wind
        self.maxang = math.radians(maxang)
        self.par = P.par[name]; self.rest_dir = rest_dir(name)
        self.len = 0.55 if kind == "pend" else P.len[name]      # the pendulum's weight sits at the lantern's middle
        h = rest_head(name); self.ang = math.atan2(h.y, h.x)
        self.level = 0; self.p = None; self.v = Vector(); self.h = None
        # It may not swing into the body: its tip stays outside a plane the anchor bone carries, just inside where it rests.
        self.anchor = anchor
        if anchor:
            self.out = Vector(out) if out else Vector((math.cos(self.ang), math.sin(self.ang), 0))
            self.wall = h + self.rest_dir * self.len - self.out * margin
DYN = {}
def _add(name, *a, **k): DYN[name] = Dyn(name, *a, **k)
_add("chain1", "pend", maxang=115)
_add("chain2", "spring", w=16, z=0.5, grav=0.0, maxang=30)
_add("lantern", "spring", w=11, z=0.3, grav=0.0, maxang=35)
for sd in "LR":
    sx = 1 if sd == "L" else -1
    _add(f"mantle.{sd}", "spring", w=7.5, z=0.3, grav=0.6, wind=0.05, maxang=50, anchor="chest", out=(sx, 0, 0), margin=0.10)
    _add(f"tag.{sd}", "spring", w=7.0, z=0.18, grav=0.85, wind=0.05, maxang=50, anchor="chest", out=(sx, 0, 0), margin=0.06)
    for k in (1, 2, 3):
        _add(f"tal{k}.{sd}", "spring", w=(11.0, 9.0, 8.0)[k - 1], z=0.3, grav=0.85, wind=(0.02, 0.05, 0.08)[k - 1], maxang=30,
             anchor=("chest", "spine", "hips")[k - 1], out=(0, -1, 0), margin=0.04)
for b in P.bones:
    if b.name.startswith("strip_"):
        k = int(b.name.split(".")[0][-1])
        _add(b.name, "spring", w=(6.5, 5.5, 4.6)[k - 1], z=(0.42, 0.34, 0.28)[k - 1], grav=0.5,
             wind=(0.05, 0.10, 0.16)[k - 1], maxang=(60, 70, 80)[k - 1], anchor="hips", margin=(0.08, 0.14, 0.20)[k - 1])
for d in DYN.values():
    p = d.par
    while p:
        if p in DYN: d.level += 1
        p = P.par[p]
LEVELS = max(d.level for d in DYN.values()) + 1
SUB = 6; DT = 1.0 / 30 / SUB

class Air:
    """What moves the hanging things besides the body: a slow travelling sway, a steady drag, a push on the lantern."""
    def __init__(self, period=120.0, life=1.0, drag=(0, 0, 0), push=0.3, push_period=40.0, swing_max=70.0, swing_damp=0.9):
        self.period = period; self.life = life; self.drag = Vector(drag); self.push = push; self.push_period = push_period
        self.swing_max = math.radians(swing_max); self.swing_damp = swing_damp
    def wind(self, d, t):
        if d.wind == 0.0: return Vector()
        a = d.ang / TAU; k = d.level
        tan = Vector((-math.sin(d.ang), math.cos(d.ang), 0)); rad = Vector((math.cos(d.ang), math.sin(d.ang), 0))
        T = self.period
        w = tan * s(t / T - a - 0.14 * k) + rad * (0.6 * s(2 * t / T - 2 * a - 0.2 * k)) + tan * (0.35 * s(3 * t / T + a - 0.25 * k))
        return w * (d.wind * self.life) + self.drag * (0.5 + 0.5 * k) * (d.wind / 0.1)
    def lantern(self, t):
        return Vector((s(t / self.push_period), 0.6 * c(t / self.push_period), 0)) * self.push

def carried(world, n):
    p = P.par[n]
    return world[p] @ P.rest[p].inverted() @ P.rest[n]
def step_dyn(pose, t, air):
    """Advance every hanging bone one frame under the given pose, and write its direction into the pose."""
    for level in range(LEVELS):
        world, _ = P.solve(pose)
        for d in DYN.values():
            if d.level != level: continue
            M0 = carried(world, d.name); h = M0.translation.copy(); cdir = M0.to_3x3().col[1].normalized()
            tdir = (cdir.lerp(d.rest_dir, d.grav) + air.wind(d, t)).normalized()
            if d.anchor:            # where it would hang is moved out of the body; the spring then keeps it out
                A = world[d.anchor] @ P.rest[d.anchor].inverted(); n = A.to_3x3() @ d.out; dep = (h + tdir * d.len - A @ d.wall).dot(n)
                if dep < 0: tdir = (tdir * d.len - n * dep).normalized()
            if d.p is None:
                d.p = h + (tdir if d.kind != "pend" else Vector((0, 0, -1))) * d.len; d.v = Vector(); d.h = h
            h0 = d.h
            for i in range(SUB):
                hh = h0.lerp(h, (i + 1) / SUB)
                if d.kind == "pend":
                    acc = Vector((0, 0, -9.8)) + air.lantern(t) - d.v * air.swing_damp
                else:
                    acc = (hh + tdir * d.len - d.p) * (d.w * d.w) - d.v * (2 * d.z * d.w)
                d.v += acc * DT
                pn = d.p + d.v * DT
                r = (pn - hh).normalized()
                ref = tdir if d.kind != "pend" else Vector((0, 0, -1))
                ang = ref.angle(r); lim = air.swing_max if d.kind == "pend" else d.maxang
                if ang > lim: r = arc(ref, r, lim / ang)
                pn = hh + r * d.len
                if d.kind == "pend":        # the lantern stays out of the robe: an upright oval round the hips, a lantern's width wider
                    A = world["hips"] @ P.rest["hips"].inverted(); ql = A.inverted() @ pn
                    e = (ql.x / 0.95) ** 2 + ((ql.y + 0.05) / 0.74) ** 2
                    if e < 1.0 and ql.z < 2.5:
                        k = 1.0 / math.sqrt(max(e, 1e-4)); ql.x *= k; ql.y = (ql.y + 0.05) * k - 0.05
                        pn = hh + (A @ ql - hh).normalized() * d.len
                d.v = (pn - d.p) / DT
                d.p = pn
            d.h = h
            pose[d.name] = {"aim": (d.p - h).normalized()}
    return pose

# ---------------------------------------------------------------- the body under the cloth
def idle_terms(t, k=1.0):
    """The hover that never stops: a bob, a slow turn, breath. Euler degrees per bone (x, y, z), and the hips' offset."""
    ph = t / 120.0
    E = {"hips": [1.2 * s(ph - 0.05) * k, 0.8 * s(ph + 0.2) * k, 2.2 * s(ph) * k],
         "spine": [0.9 * s(ph - 0.12) * k, 0.5 * s(ph + 0.1) * k, 1.2 * s(ph - 0.08) * k],
         "chest": [1.3 * s(2 * ph - 0.2) * k, 0.5 * s(ph) * k, 1.2 * s(ph - 0.16) * k],
         "neck": [0.6 * s(ph - 0.25) * k, 0.0, 1.5 * s(ph - 0.25) * k],
         "head": [1.6 * s(2 * ph - 0.35) * k, 0.9 * s(ph - 0.3) * k, 3.2 * s(ph - 0.33) * k],
         "shoulder.L": [0, -1.0 * s(2 * ph - 0.25) * k, 0], "shoulder.R": [0, 1.0 * s(2 * ph - 0.25) * k, 0]}
    loc = Vector((0.02 * s(ph + 0.25), 0.015 * s(ph + 0.05), 0.05 * s(2 * ph) + 0.015 * s(ph))) * k
    wl = Vector((0.025 * s(ph - 0.2), 0.04 * s(ph - 0.3), -0.035 * s(2 * (ph - 0.09)))) * k
    wr = Vector((-0.015 * s(ph - 0.15), 0.03 * s(ph - 0.38), -0.02 * s(2 * (ph - 0.07)))) * k
    curl = (6 + 5 * s(ph - 0.4) * k, 5 + 4 * s(ph - 0.47) * k, 3.0)
    return E, loc, wl, wr, curl

def add(E, bone, x=0.0, y=0.0, z=0.0):
    e = E.setdefault(bone, [0.0, 0.0, 0.0]); e[0] += x; e[1] += y; e[2] += z

def build(E, loc, wrist_l, wrist_r, pole_l=None, pole_r=None, hand_l=None, hand_r=None, curl=(6, 5, 3)):
    """Euler tables + wrist targets (given beside the resting chest, carried by it) -> a pose for the Poser.
    hand_l: (weight, direction, palm normal) blends the left hand from what the forearm carries to a set direction.
    hand_r: a rotation of the lantern hand from its rest (it hangs from the wrist under the lantern's weight)."""
    pose = {n: {"rot": qe(*e)} for n, e in E.items()}
    pose["hips"]["loc"] = Vector(loc)
    world, _ = P.solve(pose)
    D = world["chest"] @ P.rest["chest"].inverted(); Dq = D.to_quaternion()
    pose["upper_arm.L"] = {"ik": (D @ Vector(wrist_l), Dq @ Vector(pole_l or POLE0["L"]))}
    pose["upper_arm.R"] = {"ik": (D @ Vector(wrist_r), Dq @ Vector(pole_r or POLE0["R"]))}
    pose["hand.R"] = {"abs": Dq @ (hand_r or Quaternion())}
    world, _ = P.solve(pose)
    if hand_l and hand_l[0] > 0.001:
        g, hd, palm = hand_l
        M0 = carried(world, "hand.L").to_3x3()
        cd = M0.col[1].normalized(); cp = (M0 @ P.rest["hand.L"].to_3x3().inverted()) @ PALM["L"]
        d = arc(cd, Dq @ Vector(hd), g)
        pn = _perp(arc(cp, Dq @ Vector(palm), g), d)
        pose["hand.L"] = {"aim": d, "aimvec": (PALM["L"], pn)}
        world, _ = P.solve(pose)
    C = (world["hand.L"] @ P.rest["hand.L"].inverted()).to_quaternion()
    q1 = q(Y, curl[0]); C1 = C @ q1
    pose["fingers1.L"] = {"rot": C @ q1 @ C.inverted()}
    pose["fingers2.L"] = {"rot": C1 @ q(Y, curl[1]) @ C1.inverted()}
    pose["thumb.L"] = {"rot": C @ q(Y, -curl[2]) @ C.inverted()}
    return pose

SEAM = {}
def bake(name, fn, end, air, loop=False):
    """Key one action: fn(t) is the body's pose; the hanging bones are stepped through it."""
    for d in DYN.values(): d.p = None
    poses = []
    if loop:
        for cyc in range(10):                      # run the loop until what hangs repeats, then keep the last pass
            poses = [step_dyn(fn(float(f)), float(f), air) for f in range(end)]
        again = step_dyn(fn(float(end)), float(end), air)       # one frame past the end: how far from frame 0 it lands
        SEAM[name] = sorted((round(math.degrees(Vector(again[n]["aim"]).angle(Vector(poses[0][n]["aim"]))), 2), n) for n in DYN)[-3:]
        poses.append(poses[0])
    else:
        for f in range(-75, 0): step_dyn(fn(0.0), float(f), air)       # let it hang still in the first pose
        poses = [step_dyn(fn(float(f)), float(f), air) for f in range(end + 1)]
    act = poser.new_action(rig, name); P.prevq.clear()
    for f, pose in enumerate(poses): P.key(pose, f)
    act.frame_range = (0, end); act.use_frame_range = True; act.use_cyclic = loop
    stash(act)

# ---------------------------------------------------------------- idle
def idle_pose(t):
    E, loc, wl, wr, curl = idle_terms(t)
    return build(E, loc, WR["L"] + wl, WR["R"] + wr, curl=curl)
bake("idle", idle_pose, 120, Air(period=120, life=1.0, push=0.32, push_period=40), loop=True)

# ---------------------------------------------------------------- walk: it has no legs, so this is a glide, not steps
GLIDE = 90
class GlideAir(Air):
    """The air of a steady glide: everything streams back, and a ripple runs down each chain from its top to its tail.
    Each chain starts its ripple at its own moment, so the hem never beats in step."""
    def wind(self, d, t):
        if d.wind == 0.0: return Vector()
        k = d.level; off = 0.37 * round(d.ang / (TAU / 8))
        w = Z * (1.5 * s(3 * t / GLIDE - 0.22 * k - off)) + X * (0.6 * s(2 * t / GLIDE - 0.18 * k - 1.7 * off))
        return w * d.wind + self.drag * (0.5 + 0.5 * k) * (d.wind / 0.1)
    def lantern(self, t):          # the lantern trails behind its hand, easing a little with the heave
        return Vector((0.25 * s(t / GLIDE), 3.2 + 0.5 * s(t / GLIDE - 0.2), 0))
def walk_pose(t):
    ph = t / GLIDE
    heave = s(ph)                  # one slow rise and fall over the loop; each part reads it a little later
    E = {"hips": [11 + 1.0 * s(ph - 0.05), 0.0, 1.0 * s(ph + 0.3)],
         "spine": [5 + 0.8 * s(ph - 0.12), 0.0, 0.5 * s(ph + 0.22)],
         "chest": [4 + 0.8 * s(ph - 0.18), 0.0, 0.0],
         "neck": [-1.0, 0.0, 0.0],
         "head": [-2 + 1.0 * s(ph - 0.3), 0.0, -0.8 * s(ph + 0.15)],        # the hood leads
         "shoulder.L": [0, 0, 5.0], "shoulder.R": [0, 0, -4.0]}
    loc = Vector((0.02 * s(ph + 0.25), -0.08, 0.045 * heave))
    # Both arms are carried still and a little back; they only give with the heave.
    wl = WR["L"] + Vector((0.0, 0.26, 0.08 - 0.012 * s(ph - 0.15)))
    wr = WR["R"] + Vector((0.0, 0.12, 0.06 - 0.010 * s(ph - 0.12)))
    curl = (14 + 2 * s(ph - 0.4), 12 + 2 * s(ph - 0.5), 5)
    return build(E, loc, wl, wr, hand_r=qe(x=6), curl=curl)
bake("walk", walk_pose, GLIDE, GlideAir(drag=(0, 0.22, 0.04), swing_max=60, swing_damp=1.1), loop=True)

# ---------------------------------------------------------------- raise_lantern (Lights Out): the lantern lifted high beside the hood
def raise_pose(t):
    def a(dt=0): return curve(t - dt, [(0, 0), (8, 1), (16, 0)])                          # the sink before the lift
    def r(dt=0): return curve(t - dt, [(7, 0), (19, 0.72), (28, 1.04), (34, 0.985), (40, 1), (88, 1), (114, 0)])   # up, past, settle, hold, fold
    hold = curve(t, [(26, 0), (38, 1), (86, 1), (96, 0)])
    sink = curve(t, [(92, 0), (108, 1), (120, 0)])                                       # it settles a little low coming down
    E, loc, wl, wr, curl = idle_terms(t, 1 - 0.5 * hold)
    add(E, "hips", x=5 * a() - 3 * r(), z=4 * a() - 5 * r(1))
    add(E, "spine", x=4 * a(1) - 3 * r(2), z=3 * a(1) - 4 * r(2))
    add(E, "chest", x=4 * a(2) - 4 * r(3) + 1.0 * hold * s(t / 50.0), z=4 * a(2) - 6 * r(3), y=3 * r(3))
    add(E, "neck", x=3 * a(3) - 6 * r(5), z=-6 * r(5))
    add(E, "head", x=5 * a(4) - 10 * r(6), z=-9 * r(6), y=4 * r(6))
    add(E, "shoulder.R", y=-3 * a() + 12 * r(1))
    add(E, "shoulder.L", y=2 * a() - 8 * r(3))
    loc = loc + Vector((0.0, 0.03 * a() + 0.02 * r(), -0.09 * a() + 0.30 * r() + 0.02 * hold * s(t / 44.0) - 0.05 * sink))
    up = bez(WR["R"], (-1.40, -0.45, 2.40), (-0.96, -0.30, 3.36), r(2))        # the arm up in an L, the lantern beside the hood
    wr = up + Vector((0.05, 0.06, -0.10)) * a(1) + wr + Vector((0.015 * s(t / 37.0), 0.01 * c(t / 29.0), 0)) * hold
    pole_r = POLE0["R"].lerp(V(-1.0, 0.15, -0.7), r(2))
    hand_r = qe(x=-58 * r(4) + 8 * a(2))
    # The free arm opens wide and low, the palm turned up, the fingers spread.
    out = bez(WR["L"], (1.30, -0.30, 1.95), (1.42, -0.22, 2.42), r(4))
    wl = out + Vector((-0.06, 0.04, 0.05)) * a(2) + wl
    pole_l = POLE0["L"].lerp(V(0.2, 0.7, -0.8), r(4))
    hand_l = (r(6), V(0.95, -0.25, 0.15), V(-0.1, -0.5, 0.85))
    curl = (lerp(curl[0], -8, r(8)) + 14 * a(3), lerp(curl[1], -4, r(9)) + 12 * a(3), lerp(curl[2], -8, r(8)))
    return build(E, loc, wl, wr, pole_l, pole_r, hand_l, hand_r, curl)
bake("raise_lantern", raise_pose, 120, Air(period=120, life=1.0, push=0.25, push_period=40, swing_max=40, swing_damp=1.6))

# ---------------------------------------------------------------- bloom (Wisp Bloom): the lantern thrust out before it, the free arm opening
def bloom_pose(t):
    def a(dt=0): return curve(t - dt, [(0, 0), (9, 1), (16, 0)])                          # drawn in and back
    def r(dt=0): return curve(t - dt, [(10, 0), (21, 1.08), (26, 0.97), (31, 1), (36, 1), (58, 0)])
    hold = curve(t, [(20, 0), (28, 1), (36, 1), (44, 0)])
    E, loc, wl, wr, curl = idle_terms(t, 1 - 0.5 * hold)
    add(E, "hips", x=-5 * a() + 7 * r(), z=-4 * a() + 5 * r(1))
    add(E, "spine", x=-4 * a(1) + 5 * r(1), z=-4 * a(1) + 5 * r(2))
    add(E, "chest", x=-4 * a(2) + 6 * r(2), z=-6 * a(2) + 8 * r(3), y=-2 * r(3))
    add(E, "neck", x=2 * a(2) - 3 * r(4), z=3 * a(3) - 4 * r(4))
    add(E, "head", x=4 * a(3) - 6 * r(5), z=4 * a(3) - 6 * r(5))
    add(E, "shoulder.R", y=4 * a() + 4 * r(1), z=-6 * a() + 12 * r(1))
    add(E, "shoulder.L", y=-5 * r(3), z=4 * r(3))
    loc = loc + Vector((0.0, 0.07 * a() - 0.12 * r(), -0.07 * a() + 0.12 * r(1)))
    fwd = bez(WR["R"], (-0.95, -0.75, 2.05), (-0.40, -0.78, 2.40), r(1))
    wr = fwd + Vector((0.18, 0.22, 0.16)) * a(1) + wr
    pole_r = POLE0["R"].lerp(V(-1.0, 0.1, -0.6), r(1))
    hand_r = qe(x=-42 * r(3) + 10 * a(1))
    out = bez(WR["L"], (1.30, -0.25, 1.80), (1.28, -0.42, 2.18), r(3))
    wl = out + Vector((-0.10, 0.02, 0.08)) * a(2) + wl
    pole_l = POLE0["L"].lerp(V(0.4, 0.6, -0.7), r(3))
    hand_l = (r(5), V(0.8, -0.55, 0.1), V(-0.2, -0.3, 0.9))
    curl = (lerp(curl[0], -6, r(7)) + 16 * a(3), lerp(curl[1], -3, r(8)) + 14 * a(3), lerp(curl[2], -6, r(7)))
    return build(E, loc, wl, wr, pole_l, pole_r, hand_l, hand_r, curl)
bake("bloom", bloom_pose, 60, Air(period=120, life=1.0, push=0.2, push_period=40, swing_max=55, swing_damp=1.2))

# ---------------------------------------------------------------- snuff: the free hand reaches for the flame and pinches it out
def snuff_pose(t):
    def a(dt=0): return curve(t - dt, [(0, 0), (11, 1), (20, 0.6), (40, 0)])               # the claw drawn up, the lantern hidden
    def r(dt=0): return curve(t - dt, [(11, 0), (40, 1), (44, 1.04), (48, 0.86), (57, 0.84), (82, 0)])   # the slow reach, the snatch back
    def snap(dt=0): return curve(t - dt, [(44, 0), (47.5, 1.1), (51, 0.96), (57, 1), (70, 0)])           # the fingers close
    spread = curve(t, [(8, 0), (36, 1), (43.5, 1.25), (46, 0), (84, 0)])                  # the fingers open as it reaches
    jolt = curve(t, [(45, 0), (48, 1), (53, -0.25), (58, 0)])
    busy = curve(t, [(4, 0), (14, 1), (58, 1), (72, 0)])
    hide = curve(t, [(0, 0), (16, 1), (56, 1), (80, 0)])                                   # the lantern held back out of the way
    E, loc, wl, wr, curl = idle_terms(t, 1 - 0.55 * busy)
    add(E, "hips", x=-3 * a() + 4 * r() - 4 * jolt, z=-7 * r(1) + 2 * jolt)
    add(E, "spine", x=-3 * a(1) + 4 * r(2) - 3 * jolt, z=-7 * r(2))
    add(E, "chest", x=-3 * a(2) + 4 * r(3) - 3 * jolt, z=-9 * r(3), y=-3 * r(3))
    add(E, "neck", x=3 * r(4), z=5 * r(4))
    add(E, "head", x=3 * a(3) + 2 * r(5) + 4 * jolt, z=8 * r(5), y=-3 * r(5))
    add(E, "shoulder.L", y=-6 * a() + 2 * r(1), z=14 * r(1) - 4 * a())
    add(E, "shoulder.R", z=-8 * hide, y=3 * hide)
    loc = loc + Vector((0.0, 0.05 * a() - 0.14 * r() + 0.05 * jolt, 0.04 * a() - 0.05 * r() + 0.03 * jolt))
    up = WR["L"] + Vector((-0.20, -0.30, 0.45))                                           # the claw lifted beside the hood
    reach = bez(up, (0.98, -0.70, 2.50), (0.74, -0.86, 2.28), r(2))            # outside the talisman string on its chest
    tremble = Vector((0, 0.0, 0.012)) * s(t / 3.0) * curve(t, [(47, 0), (48, 1), (56, 0)])
    wl = WR["L"] + (up - WR["L"]) * max(a(1), min(1.0, r(2) * 3)) + (reach - up) + tremble + wl
    pole_l = POLE0["L"].lerp(V(1.0, 0.2, -0.4), max(a(1), r(2)))
    g = max(a(2), min(1.0, r(3) * 2.5))
    hd = arc(V(0.3, -0.5, 0.8), V(-0.1, -1.0, -0.15), r(4))
    pm = arc(V(-0.6, -0.8, -0.2), V(-0.15, 0.1, -1.0), r(4))
    hand_l = (g, hd, pm)
    curl = (lerp(curl[0], 4, g) - 16 * spread + 62 * snap(), lerp(curl[1], 10, g) - 6 * spread + 58 * snap(1), lerp(curl[2], 0, g) - 12 * spread + 40 * snap())
    back = bez(WR["R"], (-1.22, 0.02, 2.02), (-1.02, 0.30, 2.08), hide)
    wr = back + wr + Vector((0, 0.03, 0.03)) * jolt
    hand_r = qe(x=8 * hide)
    return build(E, loc, wl, wr, pole_l, None, hand_l, hand_r, curl)
bake("snuff", snuff_pose, 84, Air(period=120, life=1.0, push=0.2, push_period=40))

# ---------------------------------------------------------------- sweep (Lantern Sweep): the lantern hauled back, then swung round low in a wide arc
def sweep_pose(t):
    def w(dt=0): return curve(t - dt, [(0, 0), (11, 1), (15, 1.03), (27, 0)])              # the haul back and up
    def r(dt=0): return curve(t - dt, [(14, 0), (21, 1), (27, 1.12), (35, 1.04), (41, 1.0), (64, 0)])    # the swing, carried past, back
    busy = curve(t, [(2, 0), (10, 1), (40, 1), (56, 0)])
    E, loc, wl, wr, curl = idle_terms(t, 1 - 0.6 * busy)
    yaw = lambda dt: -30 * w(dt) + 34 * r(dt)
    add(E, "hips", z=0.36 * yaw(0), x=-4 * w() + 9 * r(), y=-3 * w() + 4 * r())
    add(E, "spine", z=0.30 * yaw(1), x=-3 * w(1) + 6 * r(1), y=-3 * w(1) + 3 * r(1))
    add(E, "chest", z=0.34 * yaw(2), x=-3 * w(2) + 5 * r(2), y=-2 * w(2) + 3 * r(2))
    add(E, "neck", z=-0.25 * yaw(3))
    add(E, "head", z=-0.35 * yaw(4), x=4 * w(3) + 3 * r(4))
    add(E, "shoulder.R", z=-14 * w() + 20 * r(1), y=10 * w() - 2 * r(1))
    add(E, "shoulder.L", z=-8 * w(1) + 6 * r(2), y=-4 * r(2))
    loc = loc + Vector((-0.05 * w() + 0.08 * r(), 0.06 * w() - 0.12 * r(), 0.06 * w() - 0.12 * r() + 0.06 * curve(t, [(23, 0), (33, 1), (60, 0)])))
    BACK, FRONT = V(-1.18, 0.42, 2.48), V(-0.12, -0.72, 2.22)
    if t - 1 <= 14: wr_ = bez(WR["R"], (-1.30, 0.10, 2.05), BACK, w(1))
    elif t - 1 <= 21: wr_ = bez(BACK, (-1.00, -0.55, 1.90), FRONT, r(1))
    elif t - 1 <= 41: wr_ = FRONT + Vector((0.20, 0.14, 0.22)) * (r(1) - 1.0) / 0.12         # carried on past the strike
    else: wr_ = bez(WR["R"], (-1.05, -0.60, 2.00), FRONT, r(1))
    wr = wr_ + wr
    pole_r = POLE0["R"].lerp(V(-1.0, 0.2, 0.3), w(1)).lerp(V(-0.6, -0.1, -1.0), min(1.0, r(1)))
    hand_r = qe(x=10 * w(2) - 34 * min(1.0, r(2)), z=30 * min(1.0, r(2)))
    OUT, FLUNG = V(1.10, -0.50, 2.05), V(1.20, 0.42, 2.20)
    if t - 3 <= 14: wl_ = bez(WR["L"], (1.20, -0.35, 1.90), OUT, w(2))
    elif t - 3 <= 41: wl_ = bez(OUT, (1.35, 0.10, 2.00), FLUNG, min(1.0, r(3)))           # the free arm thrown back against the swing
    else: wl_ = bez(WR["L"], (1.35, 0.15, 1.95), FLUNG, r(3))
    wl = wl_ + wl
    pole_l = POLE0["L"].lerp(V(0.8, 0.5, -0.4), max(w(2), min(1.0, r(3))))
    hand_l = (max(w(3), min(1.0, r(4))) * 0.8, arc(V(0.5, -0.6, -0.5), V(0.6, 0.5, -0.5), min(1.0, r(4))), V(-0.6, 0.2, -0.75))
    curl = (curl[0] + 14 * w(3) - 18 * min(1.0, r(5)), curl[1] + 12 * w(3) - 10 * min(1.0, r(5)), curl[2])
    return build(E, loc, wl, wr, pole_l, pole_r, hand_l, hand_r, curl)
bake("sweep", sweep_pose, 66, Air(period=120, life=1.0, push=0.1, push_period=40, swing_max=95, swing_damp=0.7))

rig.animation_data.action = None
for pb in rig.pose.bones: pb.matrix_basis.identity()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
zdlib.emit({"actions": {a.name: [round(x) for x in a.frame_range] for a in bpy.data.actions}, "loop_seam_degrees": SEAM})
