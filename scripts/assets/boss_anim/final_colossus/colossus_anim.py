"""rig.blend -> anim.blend: the Colossus's actions, each also stashed on an NLA track.

The torso, the hood, the halo and the two fists are written as functions of time. A fist is a free body: its place is
a path through keyed points, its turn a set of keyed directions (where the fingers point, where the palm faces), and
it reads the body's moves a beat late. Everything that hangs or trails is not written by hand: the wrist block and the
forearm stone behind each fist, the mantle's chains, the back sheet, the plates and the crystal spikes are each a small
weight on a spring that its parent drags along, stepped through the clip and then keyed.
Work space: the model faces -Y, its right is -X, the floor is z = 0.
"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ONLY = [a for a in (sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])]
rig = bpy.data.objects["Rig"]
SPIKES = ["spike_front", "spike_low.L", "spike_low.R", "spike_side.L", "spike_side.R"]
Poser.LOC = ("root", "body", "fist.L", "fist.R", "halo", "halo.L", "halo.R", "tag.L", "tag.R", *SPIKES)
P = Poser(rig)
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
def spline(t, keys):
    """A smooth path through (frame, point[, stop]) keys: it passes each key without stopping unless the key says stop."""
    if t <= keys[0][0]: return Vector(keys[0][1])
    if t >= keys[-1][0]: return Vector(keys[-1][1])
    def tan(i):
        if i == 0 or i == len(keys) - 1 or (len(keys[i]) > 2 and keys[i][2]): return Vector((0, 0, 0))
        return (Vector(keys[i + 1][1]) - Vector(keys[i - 1][1])) / (keys[i + 1][0] - keys[i - 1][0])
    for i in range(len(keys) - 1):
        f0, f1 = keys[i][0], keys[i + 1][0]
        if t <= f1:
            h = f1 - f0; u = (t - f0) / h; p0, p1 = Vector(keys[i][1]), Vector(keys[i + 1][1]); m0, m1 = tan(i) * h, tan(i + 1) * h
            u2, u3 = u * u, u * u * u
            return p0 * (2 * u3 - 3 * u2 + 1) + m0 * (u3 - 2 * u2 + u) + p1 * (-2 * u3 + 3 * u2) + m1 * (u3 - u2)
def qcurve(t, keys):
    """Eased turn through (frame, quaternion) keys."""
    if t <= keys[0][0]: return keys[0][1].copy()
    for (f0, q0), (f1, q1) in zip(keys, keys[1:]):
        if t <= f1: return q0.slerp(q1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1].copy()
def arc(d0, d1, t):
    d0 = Vector(d0).normalized(); d1 = Vector(d1).normalized()
    ax, ang = d0.rotation_difference(d1).to_axis_angle()
    return Quaternion(ax, ang * t) @ d0
def V(*a): return Vector(a)
def rest_dir(n): return P.rest[n].to_3x3().col[1].normalized()
def rest_head(n): return P.rest[n].translation.copy()
def jolt(t, f0, period=5.0, decay=4.0):
    """A blow's shudder: starts at f0, rings and dies."""
    return 0.0 if t < f0 else math.exp(-(t - f0) / decay) * math.sin(TAU * (t - f0) / period)

SX = {"R": 1.0, "L": -1.0}                         # a move is written for the right fist; the left is its mirror
def M(sd, v): return Vector((v[0] * SX[sd], v[1], v[2]))
FC = {sd: rest_head(f"fist.{sd}") for sd in "LR"}   # the palm's centre at rest
F0 = V(0, 0, -1)                                    # at rest the fingers hang down
N0 = {sd: M(sd, V(1, -0.35, 0)).normalized() for sd in "LR"}   # and the palm faces the body, a little forward
CURL_AX = {sd: F0.cross(N0[sd]).normalized() for sd in "LR"}   # a finger closes about this, towards the palm
def orient(sd, f, n=None):
    """The fist's turn from rest, from where its fingers point and where its palm faces (given for the right fist)."""
    f = M(sd, f).normalized(); n = M(sd, n) if n is not None else N0[sd].copy()
    n = (n - f * n.dot(f)).normalized()
    B0 = Matrix((F0, N0[sd], F0.cross(N0[sd]))).transposed(); B1 = Matrix((f, n, f.cross(n))).transposed()
    return (B1 @ B0.transposed()).to_quaternion()
QREST = Quaternion()
FALLEN = (V(-0.25, -0.95, -0.06), V(-0.12, -0.05, 1.0))       # a fist lying on the floor: on its back, palm up, fingers forward
FLOOR_Z = 0.46                                               # the palm's centre when it lies there
SLAM_Z = 0.62                                                # and when the closed fist stands on its knuckles

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True

# ---------------------------------------------------------------- what hangs or trails: springs
AXIS = V(0, 0.05, 0)
class Dyn:
    def __init__(self, name, w=6.0, z=0.3, grav=0.5, wind=0.0, maxang=60.0, anchor=None, out=None, margin=0.1, floor=0.03, kind="cloth"):
        self.name = name; self.w = w; self.z = z; self.grav = grav; self.wind = wind; self.kind = kind
        self.maxang = math.radians(maxang); self.floor = floor
        self.par = P.par[name]; self.rest_dir = rest_dir(name); self.len = P.len[name]
        h = rest_head(name); self.ang = math.atan2(h.y - AXIS.y, h.x - AXIS.x)
        self.radial = Vector((math.cos(self.ang), math.sin(self.ang), 0))
        self.level = 0; self.p = None; self.v = Vector(); self.h = None
        self.anchor = anchor
        if anchor:
            self.out = Vector(out) if out else self.radial.copy()
            self.wall = h + self.rest_dir * self.len - self.out * margin
DYN = {}
def _add(name, **k): DYN[name] = Dyn(name, **k)
for sd in "LR":
    _add(f"wrist.{sd}", w=12, z=0.5, grav=0.0, maxang=28, floor=0.2, kind="arm")
    _add(f"forearm.{sd}", w=9.5, z=0.42, grav=0.0, maxang=34, floor=0.2, kind="arm")
    _add(f"tag.{sd}", w=7.0, z=0.22, grav=0.85, wind=0.05, maxang=40, anchor="body", out=(0, -1, 0), margin=0.10, kind="tag")
for b in P.bones:
    n = b.name
    if n.startswith("cloak_"):
        k = int(n.split(".")[0][-1])
        _add(n, w=(8.0, 6.5)[k - 1], z=(0.4, 0.32)[k - 1], grav=0.55, wind=(0.035, 0.07)[k - 1], maxang=(18, 30)[k - 1],
             anchor="chest", margin=(0.08, 0.14)[k - 1])
    if n.startswith("tail"):
        k = int(n[-1])
        _add(n, w=(6.5, 5.8, 5.2, 4.6)[k - 1], z=0.3, grav=0.55, wind=(0.06, 0.09, 0.12, 0.15)[k - 1], maxang=(28, 36, 44, 50)[k - 1],
             anchor="body", out=(0, 1, 0), margin=(0.10, 0.2, 0.3, 0.4)[k - 1])
# A crystal is held in the air, not hung: no wind moves it. The spring only makes it answer the body a beat late.
for n in SPIKES: _add(n, w=10, z=0.45, grav=0.6, wind=0.0, maxang=14, kind="spike")
for d in DYN.values():
    p = d.par
    while p:
        if p in DYN: d.level += 1
        p = P.par[p]
LEVELS = max(d.level for d in DYN.values()) + 1
SUB = 6; DT = 1.0 / 30 / SUB

class Air:
    """What moves the hanging things besides the body: a slow travelling sway, a steady drag; a clip may let the
    forearms go limp, fan the spikes out or whip the cloth."""
    damp = 1.0            # a clip may thicken the air (a steady glide: the cloth streams instead of flapping)
    def __init__(self, period=120.0, life=1.0, drag=(0, 0, 0)):
        self.period = period; self.life = life; self.drag = Vector(drag)
    def gust(self, t): return 1.0
    def limp(self, d, t): return 0.0
    def flare(self, d, t): return 0.0
    def wind(self, d, t):
        if d.wind == 0.0: return Vector()
        a = d.ang / TAU; k = d.level
        tan = Vector((-math.sin(d.ang), math.cos(d.ang), 0)); rad = d.radial
        T = self.period
        w = tan * s(t / T - a - 0.14 * k) + rad * (0.6 * s(2 * t / T - 2 * a - 0.2 * k)) + tan * (0.35 * s(3 * t / T + a - 0.25 * k))
        return w * (d.wind * self.life * self.gust(t)) + self.drag * (0.5 + 0.5 * k) * (d.wind / 0.1)

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
            if d.kind == "spike":
                fl = air.flare(d, t)
                if fl: tdir = (tdir + (world["body"] @ P.rest["body"].inverted()).to_3x3() @ d.radial * fl).normalized()
                ln = pose.get("_lean", {}).get(d.name)          # where the clip tips it (already in the body's frame)
                if ln is not None and ln.length > 1e-5: tdir = (tdir + ln).normalized()
            if d.kind == "arm":
                l = air.limp(d, t)
                if l > 0: tdir = (tdir * (1 - l) + Vector((0, 0, -1)) * l + cdir * 0.05).normalized()
            if d.anchor:            # where it would hang is moved out of the body; the spring then keeps it out
                A = world[d.anchor] @ P.rest[d.anchor].inverted(); n = A.to_3x3() @ d.out; dep = (h + tdir * d.len - A @ d.wall).dot(n)
                if dep < 0: tdir = (tdir * d.len - n * dep).normalized()
            if h.z + tdir.z * d.len < d.floor and h.z > d.floor:      # nor through the floor
                tdir.z = (d.floor - h.z) / d.len; hz = math.sqrt(max(1e-6, 1 - tdir.z ** 2)); xy = Vector((tdir.x, tdir.y, 0))
                xy = xy.normalized() * hz if xy.length > 1e-4 else d.radial * hz
                tdir = Vector((xy.x, xy.y, tdir.z))
            if d.p is None:
                d.p = h + tdir * d.len; d.v = Vector(); d.h = h
            h0 = d.h
            for i in range(SUB):
                hh = h0.lerp(h, (i + 1) / SUB)
                acc = (hh + tdir * d.len - d.p) * (d.w * d.w) - d.v * (2 * d.z * air.damp * d.w)
                d.v += acc * DT
                pn = d.p + d.v * DT
                r = (pn - hh).normalized()
                ang = tdir.angle(r)
                if ang > d.maxang: r = arc(tdir, r, d.maxang / ang)
                pn = hh + r * d.len
                if pn.z < d.floor and hh.z > d.floor:
                    pn.z = d.floor; pn = hh + (pn - hh).normalized() * d.len
                d.v = (pn - d.p) / DT
                d.p = pn
            d.h = h
            pose.setdefault(d.name, {})["aim"] = (d.p - h).normalized()
    return pose

# ---------------------------------------------------------------- the stance everything returns to
IDLE = 120
def base(t, k=1.0):
    """The hover that never stops. Returns the state a clip then changes: Euler degrees per torso bone, the body's
    offset, each fist (place, turn, finger curls, thumb), the halo (offset, Euler, its two halves)."""
    ph = t / IDLE
    E = {"body": [1.0 * s(ph - 0.05) * k, 0.8 * s(ph + 0.2) * k, 2.5 * s(ph) * k],
         "spine": [0.8 * s(ph - 0.10) * k, 0.5 * s(ph + 0.1) * k, 1.2 * s(ph - 0.08) * k],
         "chest": [1.5 * s(2 * ph - 0.2) * k, 0.6 * s(ph) * k, 1.5 * s(ph - 0.16) * k],
         "neck": [0.8 * s(ph - 0.25) * k, 0.0, 2.0 * s(ph - 0.25) * k],
         "head": [(2.0 * s(2 * ph - 0.35) + 1.5 * s(ph - 0.1)) * k, 1.2 * s(ph - 0.3) * k, 4.0 * s(ph - 0.33) * k]}
    loc = Vector((0.03 * s(ph + 0.25), 0.02 * s(ph + 0.05), 0.07 * s(2 * ph) + 0.02 * s(ph))) * k
    F = {}
    for sd, a in (("R", 0.12), ("L", 0.31)):        # each fist hovers on its own, a beat behind the body and out of step with the other
        d = Vector((0.045 * SX[sd] * s(ph - a), 0.05 * s(ph - a - 0.2), 0.08 * s(2 * ph - 0.18 - a) + 0.03 * s(ph - a))) * k
        q_ = qe(x=4 * s(ph - a - 0.1) * k, y=5 * SX[sd] * s(2 * ph - a) * k, z=6 * SX[sd] * s(ph - a - 0.3) * k)
        curl = [0.16 + (0.14 * s(ph - a - 0.07 * i) + 0.10 * max(0.0, s(2 * ph - a - 0.05 * i))) * k for i in range(3)]
        F[sd] = {"pos": FC[sd] + d, "q": q_, "curl": curl, "thumb": 0.2 + 0.15 * s(ph - a - 0.2) * k}
    halo = {"loc": Vector((0, 0, 0.035 * s(2 * ph - 0.3) * k)), "e": [5 * s(ph - 0.1) * k, 5 * c(ph - 0.1) * k, 10 * s(ph - 0.4) * k],
            "L": (Vector(), [0, 2 * s(2 * ph) * k, 0]), "R": (Vector(), [0, -2 * s(2 * ph - 0.3) * k, 0])}
    return {"E": E, "loc": loc, "F": F, "halo": halo, "misc": {}, "spk": hover(ph, k)}

# The crystals under it are held in the air by it, each on its own: a clip moves them through `spk`.
RAD = {n: DYN[n].radial.copy() for n in SPIKES}                                            # outwards from the body's axis
R0 = {n: math.hypot(rest_head(n).x - AXIS.x, rest_head(n).y - AXIS.y) for n in SPIKES}       # how far out it floats
TILT = {n: Vector((rest_dir(n).x, rest_dir(n).y, 0)) for n in SPIKES}                       # how far its length is off plumb
TANG = {n: Vector((-RAD[n].y, RAD[n].x, 0)) for n in SPIKES}
HOVER = [(1, 2, 1), (2, 1, 2), (1, 1, 2), (2, 2, 1), (1, 2, 2)]         # each one's own periods (whole divisions of the loop)
def hover(ph, k=1.0, amp=1.0):
    """Each crystal bobs and drifts a few centimetres on its own period and phase. Returns {name: [offset, lean]},
    both in the body's frame: the offset moves the crystal, the lean tips its length."""
    out = {}
    for i, n in enumerate(SPIKES):
        kx, ky, kz = HOVER[i]
        out[n] = [Vector((0.020 * s(kx * ph + 0.13 * i), 0.020 * s(ky * ph + 0.31 * i + 0.2), 0.035 * s(kz * ph + 0.23 * i + 0.1))) * (k * amp), Vector()]
    return out
def spk(S, out=0.0, inn=0.0, up=0.0, lean=None, loc=None, each=None):
    """Move all the crystals together: `out` tips their points outwards (negative: inwards), `inn` draws them in
    towards the axis by that share of their distance (negative: spreads them), `up` lifts them, `lean`/`loc` are
    shared vectors, `each(i, name)` returns one crystal's own (offset, lean)."""
    for i, n in enumerate(SPIKES):
        e = S["spk"][n]
        e[0] += RAD[n] * (-inn * R0[n]) + Vector((0, 0, up)); e[1] += RAD[n] * out
        if loc is not None: e[0] += loc
        if lean is not None: e[1] += lean
        if each:
            l, ln = each(i, n); e[0] += l; e[1] += ln

def add(S, bone, x=0.0, y=0.0, z=0.0):
    e = S["E"][bone]; e[0] += x; e[1] += y; e[2] += z

def build(S):
    """A state -> a pose for the Poser."""
    pose = {n: {"rot": qe(*e)} for n, e in S["E"].items()}
    pose["body"]["loc"] = Vector(S["loc"])
    H = S["halo"]
    pose["halo"] = {"loc": Vector(H["loc"]), "rot": qe(*H["e"])}
    for sd in "LR":
        f = S["F"][sd]; C = f["q"]
        pose[f"fist.{sd}"] = {"loc": f["pos"] - FC[sd], "abs": C}
        ax = CURL_AX[sd]
        for i, k in enumerate("abc"):
            cu = f["curl"][i]
            q1 = q(ax, 78 * cu); C1 = C @ q1
            pose[f"finger_{k}.{sd}"] = {"rot": C @ q1 @ C.inverted()}
            pose[f"claw_{k}.{sd}"] = {"rot": C1 @ q(ax, 58 * max(cu, -0.3)) @ C1.inverted()}
        pose[f"thumb.{sd}"] = {"rot": C @ q(ax, -38 * f["thumb"]) @ C.inverted()}
    world, _ = P.solve(pose)
    Hq = (world["halo"] @ P.rest["halo"].inverted()).to_quaternion()
    for sd in "LR":
        l, e = H[sd]
        pose[f"halo.{sd}"] = {"loc": Hq @ Vector(l), "rot": Hq @ qe(*e) @ Hq.inverted()}
    for n, ops in S["misc"].items(): pose.setdefault(n, {}).update(ops)
    Bq = (world["body"] @ P.rest["body"].inverted()).to_quaternion()
    pose["_lean"] = {}
    for n, (l, ln) in S["spk"].items():
        ops = pose.setdefault(n, {}); ops["loc"] = Vector(ops.get("loc", (0, 0, 0))) + Bq @ l
        pose["_lean"][n] = Bq @ ln
    return pose

def fist(S, sd, t, pos=None, ori=None, curl=None, thumb=None, zmin=None):
    """Move one fist: `pos` keys are places for the right fist (None = its rest), `ori` keys are turns from rest,
    `curl` a value or three. What the idle gave it stays underneath."""
    f = S["F"][sd]
    if pos:
        keys = [(k[0], FC[sd] if k[1] is None else M(sd, k[1]), *k[2:]) for k in pos]
        f["pos"] = f["pos"] + spline(t, keys) - FC[sd]
        if zmin is not None and f["pos"].z < zmin: f["pos"].z = zmin
    if ori: f["q"] = qcurve(t, ori) @ f["q"]
    if curl is not None:
        f["curl"] = [curl] * 3 if not isinstance(curl, (list, tuple)) else list(curl)
    if thumb is not None: f["thumb"] = thumb

SEAM = {}
def bake(name, fn, end, air, loop=False):
    """Key one action: fn(t) is the state; the hanging bones are stepped through it."""
    if ONLY and name not in ONLY: return
    for d in DYN.values(): d.p = None
    if loop:
        for cyc in range(14):                      # run the loop until what hangs repeats, then keep the last pass
            poses = [step_dyn(build(fn(float(f))), float(f), air) for f in range(end)]
        again = step_dyn(build(fn(float(end))), float(end), air)
        SEAM[name] = sorted((round(math.degrees(Vector(again[n]["aim"]).angle(Vector(poses[0][n]["aim"]))), 2), n) for n in DYN)[-3:]
        poses.append(poses[0])
    else:
        for f in range(-60, 0): step_dyn(build(fn(0.0)), 0.0, air)       # let it hang still in the first pose
        poses = [step_dyn(build(fn(float(f))), float(f), air) for f in range(end + 1)]
    act = poser.new_action(rig, name); P.prevq.clear()
    for f, pose in enumerate(poses): P.key(pose, f)
    act.frame_range = (0, end); act.use_frame_range = True; act.use_cyclic = loop
    stash(act)

# ---------------------------------------------------------------- idle
bake("idle", lambda t: base(t), IDLE, Air(period=120, life=1.0), loop=True)

# ---------------------------------------------------------------- walk: it has no legs, so this is a glide
GLIDE = 90
class GlideAir(Air):
    damp = 2.2
    """The air of a steady glide: everything streams back, and a ripple runs down each chain from its top to its tail.
    Each chain starts its ripple at its own moment, so the hem never beats in step."""
    def wind(self, d, t):
        if d.wind == 0.0: return Vector()
        k = d.level; off = 0.37 * round(d.ang / (TAU / 8))
        w = Z * (1.2 * s(3 * t / GLIDE - 0.22 * k - off)) + X * (0.6 * s(2 * t / GLIDE - 0.18 * k - 1.7 * off))
        return w * d.wind + self.drag * (0.5 + 0.5 * k) * (max(d.wind, 0.03) / 0.1)
def walk_state(t):
    ph = t / GLIDE
    S = {"E": {"body": [13 + 1.0 * s(ph - 0.05), 0.0, 1.0 * s(ph + 0.3)],
               "spine": [5 + 0.8 * s(ph - 0.12), 0.0, 0.5 * s(ph + 0.22)],
               "chest": [4 + 0.8 * s(ph - 0.18), 0.0, 0.0],
               "neck": [-3.0, 0.0, 0.0],
               "head": [-7 + 1.5 * s(ph - 0.3), 0.0, -0.8 * s(ph + 0.15)]},          # the hood stays up: it looks where it goes
         "loc": Vector((0.02 * s(ph + 0.25), -0.14, 0.045 * s(ph) - 0.05)), "F": {}, "misc": {}, "spk": hover(ph, amp=0.7),
         "halo": {"loc": Vector((0, 0.05, 0.02 * s(ph - 0.3))), "e": [-9 + 2 * s(ph - 0.2), 3 * c(ph - 0.2), 4 * s(ph - 0.4)],
                  "L": (Vector(), [0, 0, 0]), "R": (Vector(), [0, 0, 0])}}
    for sd, a in (("R", 0.0), ("L", 0.14)):
        # The fists trail behind and low, the fingers streaming back; once a loop they fall back and are drawn up again.
        surge = s(ph - a)
        d = Vector((0.06 * SX[sd], 0.46 + 0.15 * surge, -0.16 + 0.05 * s(ph - a - 0.22)))
        q_ = orient(sd, V(0.0, 0.42 + 0.08 * s(ph - a - 0.1), -0.9), V(1, -0.2, 0.1)) @ qe(y=3 * SX[sd] * s(ph - a - 0.3))
        curl = [0.34 + 0.08 * s(ph - a - 0.08 * i) for i in range(3)]
        S["F"][sd] = {"pos": FC[sd] + d, "q": q_, "curl": curl, "thumb": 0.3}
    # the crystals trail a little behind their places, their points swept back, each easing on its own
    spk(S, each=lambda i, n: (Vector((0, 0.06 + 0.03 * s(ph - 0.15 - 0.11 * i), 0)), Vector((0, 0.30 + 0.07 * s(ph - 0.1 - 0.13 * i), 0))))
    return S
bake("walk", walk_state, GLIDE, GlideAir(drag=(0, 0.26, 0.03)), loop=True)

# ---------------------------------------------------------------- the hooks: one fist wound far back and whipped across the front
def hook_state(sd):
    o = "L" if sd == "R" else "R"; sg = SX[sd]; END = 52
    POS = [(0, None), (8, (-1.55, 0.25, 1.78)), (16, (-1.78, 0.78, 2.06)), (19, (-1.82, 0.84, 2.08)), (22, (-1.80, -0.95, 1.82)),
           (24, (-0.35, -1.90, 1.60)), (27, (0.60, -1.50, 1.50)), (31, (0.78, -1.28, 1.46), True), (41, (-0.75, -1.40, 1.42)), (END, None)]
    ORI = [(0, QREST), (15, orient(sd, V(0.1, -0.8, 0.5), V(1, 0.2, 0))), (19, orient(sd, V(0.05, -0.85, 0.5), V(1, 0.25, 0))),
           (22, orient(sd, V(0.5, -0.85, 0.1), V(0.85, 0.5, 0.2))), (24, orient(sd, V(0.95, -0.3, -0.05), V(0.3, 0.95, 0))),
           (28, orient(sd, V(0.9, 0.38, -0.2), V(-0.35, 0.9, 0))), (33, orient(sd, V(0.85, 0.3, -0.3), V(-0.3, 0.92, 0))),
           (43, orient(sd, V(0.3, -0.3, -0.9), V(0.9, 0.3, 0))), (END, QREST)]
    def fn(t):
        def w(dt=0): return curve(t - dt, [(0, 0), (14, 1), (19, 1.06), (24, 0)])            # the wind back
        def r(dt=0): return curve(t - dt, [(19, 0), (24, 1), (27, 1.14), (33, 1.0), (END, 0)])   # the swing, carried past, back
        busy = curve(t, [(0, 0), (8, 1), (36, 1), (END, 0)])
        S = base(t - END, 1 - 0.7 * busy)
        yaw = lambda dt: (-24 * w(dt) + 32 * r(dt)) * sg
        add(S, "body", z=0.36 * yaw(0), x=-4 * w() + 8 * r(), y=(-3 * w() + 4 * r()) * sg)
        add(S, "spine", z=0.30 * yaw(1), x=-3 * w(1) + 6 * r(1), y=(-2 * w(1) + 3 * r(1)) * sg)
        add(S, "chest", z=0.34 * yaw(2), x=-4 * w(2) + 7 * r(2), y=(-3 * w(2) + 4 * r(2)) * sg)
        add(S, "neck", z=-0.22 * yaw(3))
        add(S, "head", z=-0.30 * yaw(4), x=3 * w(3) + 2 * r(4))
        S["loc"] += Vector((0.10 * sg * (r() - w()), 0.12 * w() - 0.34 * r(), 0.07 * w() - 0.13 * r() + 0.02 * jolt(t, 24)))
        cl = [curve(t, [(1 + i, 0.2), (9 + 2 * i, 1.0), (31, 1.0), (45 + i, 0.2)]) for i in range(3)]
        fist(S, sd, t, POS, ORI, curl=cl, thumb=curve(t, [(2, 0.2), (12, 1.0), (31, 1.0), (46, 0.2)]))
        # the other fist draws in to guard, then swings out behind as a counterweight
        g = curve(t, [(0, 0), (14, 1), (20, 1), (26, -0.6), (34, -0.4), (END, 0)])
        fist(S, o, t)
        S["F"][o]["pos"] += M(o, V(0.22, -0.30, 0.22)) * max(g, 0) + M(o, V(-0.25, 0.45, 0.05)) * max(-g, 0)
        S["F"][o]["q"] = qe(z=-14 * SX[o] * max(g, 0) + 22 * SX[o] * max(-g, 0)) @ S["F"][o]["q"]
        S["F"][o]["curl"] = [lerp(x, 0.8, abs(g)) for x in S["F"][o]["curl"]]
        S["halo"]["e"][2] += -0.5 * yaw(6); S["halo"]["e"][0] += 8 * r(5) - 5 * w(4); S["halo"]["loc"].z += 0.03 * jolt(t, 25)
        # the crystals swing out against the twist and jolt as the fist lands
        sw = r(3) - w(3)
        spk(S, out=0.22 * w(2) + 0.34 * min(1.0, r(2)) + 0.25 * jolt(t, 24), loc=Vector((0.10 * sg * sw, 0.05 * sw, -0.05 * jolt(t, 24))),
            lean=Vector((-0.30 * sg * sw, 0.12 * sw, 0)))
        return S
    return fn, END
for sd in "RL":
    fn, END = hook_state(sd)
    bake(f"hook_{sd.lower()}", fn, END, Air(life=0.8))

# ---------------------------------------------------------------- slam: both fists hauled overhead and hammered into the floor before it
def slam_state(t):
    END = 56
    def w(dt=0): return curve(t - dt, [(0, 0), (16, 1), (20, 1.08), (24, 0)])
    def r(dt=0): return curve(t - dt, [(20, 0), (24, 1.1), (27, 0.96), (30, 1.0), (37, 1.0), (END, 0)])
    busy = curve(t, [(0, 0), (8, 1), (40, 1), (END, 0)])
    S = base(t - END, 1 - 0.75 * busy)
    add(S, "body", x=-5 * w() + 8 * r()); add(S, "spine", x=-5 * w(1) + 8 * r(1)); add(S, "chest", x=-6 * w(2) + 13 * r(1))
    add(S, "neck", x=-4 * w(3) - 3 * r(3)); add(S, "head", x=-8 * w(4) - 4 * r(4) + 5 * jolt(t, 25, 6))
    S["loc"] += Vector((0, 0.14 * w() - 0.34 * r(), 0.26 * w() - 0.46 * r() + 0.03 * jolt(t, 24)))
    for sd, dl in (("R", 0.0), ("L", 1.0)):
        tt = t - dl if t < 22 else t - dl * max(0.0, (24 - t) / 2)          # the left starts a frame late; they land together
        POS = [(0, None), (9, (-1.55, 0.12, 2.10)), (17, (-1.12, -0.32, 3.24)), (20, (-1.08, -0.26, 3.32)), (24, (-0.95, -1.55, SLAM_Z), True),
               (26.5, (-0.95, -1.56, SLAM_Z + 0.10), True), (29, (-0.95, -1.56, SLAM_Z), True), (37, (-0.95, -1.56, SLAM_Z), True), (47, (-1.22, -0.90, 1.32)), (END, None)]
        ORI = [(0, QREST), (17, orient(sd, V(0, 0.55, -0.8), V(1, 0, 0))), (20, orient(sd, V(0, 0.62, -0.75), V(1, 0, 0))),
               (24, orient(sd, V(0, -0.12, -1), V(1, -0.15, 0))), (37, orient(sd, V(0, -0.1, -1), V(1, -0.15, 0))), (END, QREST)]
        cl = [curve(tt, [(2 + i, 0.2), (10 + 2 * i, 1.0), (38, 1.0), (50 + i, 0.2)]) for i in range(3)]
        fist(S, sd, tt, POS, ORI, curl=cl, thumb=curve(tt, [(3, 0.2), (13, 1.0), (38, 1.0), (50, 0.2)]), zmin=SLAM_Z - 0.02)
    S["halo"]["loc"].z += 0.06 * w(3) - 0.05 * r(2) + 0.08 * jolt(t, 25, 6); S["halo"]["e"][0] += -10 * w(4) + 14 * r(3)
    # the crystals draw in as the fists go up, and are thrown outwards by the blow
    spk(S, inn=0.15 * w(2), up=0.06 * w(2) - 0.05 * jolt(t, 24), out=-0.15 * w(2) + 0.55 * curve(t, [(23, 0), (26, 1.2), (30, 0.8), (37, 0.7), (50, 0)]))
    return S
bake("slam", slam_state, 56, Air(life=0.8))

# ---------------------------------------------------------------- leap: a coil, the jump with both fists swung overhead, the landing smash
def leap_state(t):
    END = 60
    def cr(dt=0): return curve(t - dt, [(0, 0), (12, 1), (15.5, 1.05), (19, 0)])            # the coil
    def up(dt=0): return curve(t - dt, [(15, 0), (19, 1.1), (24, 1.0), (28, 1.0), (30, 0)])   # stretched in the air
    def r(dt=0): return curve(t - dt, [(28, 0), (30, 1.12), (33, 0.95), (36, 1.0), (41, 1.0), (END, 0)])
    busy = curve(t, [(0, 0), (6, 1), (44, 1), (END, 0)])
    S = base(t - END, 1 - 0.75 * busy)
    add(S, "body", x=7 * cr() - 4 * up() + 8 * r()); add(S, "spine", x=6 * cr(1) - 5 * up(1) + 8 * r(1))
    add(S, "chest", x=8 * cr(1) - 6 * up(2) + 12 * r(1)); add(S, "neck", x=-6 * cr(2) - 3 * r(3))
    add(S, "head", x=-10 * cr(3) - 4 * up(3) - 4 * r(4) + 5 * jolt(t, 31, 6))
    S["loc"] += Vector((0, 0.10 * cr() - 0.06 * up() - 0.34 * r(), -0.50 * cr() + 0.30 * up() - 0.48 * r() + 0.035 * jolt(t, 30)))
    for sd, dl in (("R", 0.0), ("L", 1.0)):
        tt = t - dl if t < 27 else t - dl * max(0.0, (30 - t) / 3)
        POS = [(0, None), (8, (-1.52, 0.36, 1.12)), (15, (-1.48, 0.52, 0.95)), (19, (-1.50, -0.05, 2.25)), (25, (-1.12, -0.42, 3.32)), (28, (-1.08, -0.40, 3.38)),
               (30, (-0.95, -1.52, SLAM_Z), True), (32.5, (-0.95, -1.53, SLAM_Z + 0.10), True), (35, (-0.95, -1.53, SLAM_Z), True), (41, (-0.95, -1.53, SLAM_Z), True),
               (51, (-1.25, -0.85, 1.30)), (END, None)]
        ORI = [(0, QREST), (14, orient(sd, V(0.0, -0.35, -0.94), V(1, -0.3, 0))), (25, orient(sd, V(0, 0.55, -0.8), V(1, 0, 0))),
               (28, orient(sd, V(0, 0.62, -0.75), V(1, 0, 0))), (30, orient(sd, V(0, -0.12, -1), V(1, -0.15, 0))),
               (41, orient(sd, V(0, -0.1, -1), V(1, -0.15, 0))), (END, QREST)]
        cl = [curve(tt, [(1 + i, 0.2), (8 + 2 * i, 1.0), (42, 1.0), (53 + i, 0.2)]) for i in range(3)]
        fist(S, sd, tt, POS, ORI, curl=cl, thumb=curve(tt, [(2, 0.2), (11, 1.0), (42, 1.0), (53, 0.2)]), zmin=SLAM_Z - 0.02)
    S["halo"]["loc"].z += -0.05 * cr(2) + 0.10 * up(3) - 0.06 * r(2) + 0.09 * jolt(t, 31, 6); S["halo"]["e"][0] += 8 * cr(3) - 10 * up(4) + 14 * r(3)
    # the crystals tuck in tight under it for the jump, and splay wide as it lands
    spk(S, inn=0.5 * cr(1) + 0.3 * up(1), up=0.14 * cr(1) + 0.08 * up(1) - 0.06 * jolt(t, 30),
        out=-0.45 * cr(1) - 0.25 * up(1) + 1.0 * curve(t, [(29, 0), (32, 1.25), (36, 0.9), (41, 0.85), (56, 0)]))
    return S
class LeapAir(Air):
    def wind(self, d, t):       # the air of the jump pulls the cloth down as it rises and up as it falls
        v = curve(t, [(15, 0), (18, -0.5), (24, 0), (29, 0.45), (31, 0)])
        return Air.wind(self, d, t) + Z * (0.5 * v * (max(d.wind, 0.03) / 0.1))
bake("leap", leap_state, 60, LeapAir(life=0.8))

# ---------------------------------------------------------------- hurl (the boulder throw): the right fist scoops the floor, hauls it over the shoulder and throws
def hurl_state(t):
    END = 60
    def dip(dt=0): return curve(t - dt, [(0, 0), (8, 1), (11, 1), (17, 0)])
    def w(dt=0): return curve(t - dt, [(9, 0), (18, 1), (20.5, 1.06), (23, 0)])
    def r(dt=0): return curve(t - dt, [(20, 0), (23, 1), (27, 1.14), (33, 1.0), (END, 0)])
    busy = curve(t, [(0, 0), (6, 1), (38, 1), (END, 0)])
    S = base(t - END, 1 - 0.7 * busy)
    yaw = lambda dt: -9 * dip(dt) - 24 * w(dt) + 30 * r(dt)
    add(S, "body", z=0.36 * yaw(0), x=6 * dip() - 5 * w() + 8 * r(), y=-4 * dip() - 2 * w() + 3 * r())
    add(S, "spine", z=0.30 * yaw(1), x=5 * dip(1) - 4 * w(1) + 6 * r(1), y=-3 * dip(1) + 2 * r(1))
    add(S, "chest", z=0.34 * yaw(2), x=5 * dip(1) - 5 * w(2) + 8 * r(2), y=-4 * dip(2) - 3 * w(2) + 4 * r(2))
    add(S, "neck", z=-0.22 * yaw(3), x=-4 * dip(2))
    add(S, "head", z=-0.30 * yaw(4), x=-6 * dip(3) + 3 * w(3) + 2 * r(4))
    S["loc"] += Vector((-0.10 * dip() - 0.06 * w() + 0.12 * r(), -0.06 * dip() + 0.16 * w() - 0.36 * r(), -0.26 * dip() + 0.10 * w() - 0.12 * r()))
    POS = [(0, None), (7, (-1.38, -0.78, 0.86)), (10, (-1.32, -0.72, 0.80)), (17, (-1.60, 0.55, 2.60)), (20, (-1.55, 0.78, 2.88)), (21.7, (-1.62, -0.45, 2.98)),
           (23, (-0.98, -1.75, 2.46)), (27, (-0.50, -1.90, 1.46)), (32, (-0.52, -1.72, 1.30), True), (46, (-1.12, -0.92, 1.36)), (END, None)]
    ORI = [(0, QREST), (8, orient("R", V(0.1, -0.4, -0.9), V(0.7, -0.7, 0.1))), (11, orient("R", V(0.1, -0.2, -0.97), V(0.8, -0.6, 0))),
           (19, orient("R", V(0, 0.5, 0.85), V(0, -0.85, 0.5))), (20.5, orient("R", V(0, 0.58, 0.8), V(0, -0.8, 0.58))),
           (23, orient("R", V(0, -0.9, 0.42), V(0, -0.42, -0.9))), (28, orient("R", V(0.1, -0.6, -0.8), V(0.5, 0.55, -0.5))),
           (46, orient("R", V(0.1, -0.2, -0.97), V(0.95, 0.1, 0))), (END, QREST)]
    grip = curve(t, [(0, 0.2), (6, -0.25), (9, -0.25), (12, 0.55), (21, 0.55), (23, -0.3), (28, -0.15), (44, 0.2)])
    fist(S, "R", t, POS, ORI, curl=[grip, grip * 0.9, grip * 0.8], thumb=max(0.0, grip) * 1.4, zmin=0.78)
    # the left fist points the way, then swings back as the right comes over
    g = curve(t, [(0, 0), (12, 0.4), (19, 1), (26, -0.8), (34, -0.5), (END, 0)])
    fist(S, "L", t)
    S["F"]["L"]["pos"] += V(-0.30, -0.75, 0.42) * max(g, 0) + V(0.22, 0.50, -0.05) * max(-g, 0)
    S["F"]["L"]["q"] = orient("L", arc(F0, V(0.1, -0.75, -0.3), max(g, 0)), None) @ qe(z=-20 * max(-g, 0)) @ S["F"]["L"]["q"]
    S["F"]["L"]["curl"] = [lerp(x, 0.75, abs(g)) for x in S["F"]["L"]["curl"]]
    S["halo"]["e"][2] += -0.5 * yaw(6); S["halo"]["e"][0] += 8 * r(5) - 6 * w(4)
    # the crystals gather with the haul and flare forward as the fist lets go
    fl = curve(t, [(21, 0), (24.5, 1.2), (28, 0.8), (34, 0.6), (48, 0)])
    spk(S, out=-0.2 * w(2) + 0.75 * fl, inn=0.12 * w(2), up=0.05 * w(2), lean=Vector((0, 0.2 * w(2) - 0.25 * fl, 0)))
    return S
bake("hurl", hurl_state, 60, Air(life=0.8))

# ---------------------------------------------------------------- ground_punch (the spike chase): one fist raised high and driven into the floor, held there
def punch_state(t):
    END = 66
    def w(dt=0): return curve(t - dt, [(0, 0), (19, 1), (23.5, 1.07), (27, 0)])
    def r(dt=0): return curve(t - dt, [(23, 0), (27, 1.1), (30, 0.96), (33, 1.0), (45, 1.0), (END, 0)])
    busy = curve(t, [(0, 0), (8, 1), (48, 1), (END, 0)])
    S = base(t - END, 1 - 0.75 * busy)
    add(S, "body", x=-4 * w() + 8 * r(), z=-6 * w() + 4 * r(), y=3 * w() - 4 * r())
    add(S, "spine", x=-4 * w(1) + 7 * r(1), z=-5 * w(1) + 3 * r(1), y=2 * w(1) - 3 * r(1))
    add(S, "chest", x=-5 * w(2) + 10 * r(1), z=-6 * w(2) + 4 * r(2), y=3 * w(2) - 5 * r(2))
    add(S, "neck", x=-3 * r(3), z=3 * w(3)); add(S, "head", x=-6 * w(4) - 5 * r(4) + 5 * jolt(t, 28, 6), z=5 * w(4) - 6 * r(4))
    S["loc"] += Vector((0.06 * w() - 0.16 * r(), 0.12 * w() - 0.30 * r(), 0.22 * w() - 0.46 * r() + 0.035 * jolt(t, 27)))
    PZ = SLAM_Z - 0.10                                                     # driven a little into the floor
    POS = [(0, None), (10, (-1.55, 0.05, 2.20)), (20, (-1.28, -0.42, 3.30)), (23.5, (-1.22, -0.36, 3.40)), (27, (-1.02, -1.46, PZ), True),
           (29.5, (-1.02, -1.47, PZ + 0.07), True), (32, (-1.02, -1.47, PZ), True), (45, (-1.02, -1.47, PZ), True), (55, (-1.25, -0.90, 1.25)), (END, None)]
    ORI = [(0, QREST), (20, orient("R", V(0, 0.5, -0.86), V(1, 0, 0))), (23.5, orient("R", V(0, 0.6, -0.8), V(1, 0, 0))),
           (27, orient("R", V(0.1, -0.15, -1), V(1, -0.2, 0))), (36, orient("R", V(0.16, -0.15, -1), V(1, -0.05, 0))),
           (45, orient("R", V(0.1, -0.15, -1), V(1, -0.2, 0))), (END, QREST)]
    cl = [curve(t, [(2 + i, 0.2), (11 + 2 * i, 1.0), (46, 1.0), (58 + i, 0.2)]) for i in range(3)]
    fist(S, "R", t, POS, ORI, curl=cl, thumb=curve(t, [(3, 0.2), (14, 1.0), (46, 1.0), (58, 0.2)]), zmin=PZ - 0.02)
    # the left fist is flung out wide to brace, its claws spread
    g = curve(t, [(0, 0), (18, 0.5), (27, 1.1), (32, 1.0), (45, 1.0), (END, 0)])
    fist(S, "L", t)
    S["F"]["L"]["pos"] += V(0.42, 0.22, 0.36) * min(g, 0.5) * 2 + V(0.0, -0.10, -0.50) * max(0.0, g - 0.5) * 2
    S["F"]["L"]["q"] = qe(y=-16 * g, z=10 * g) @ S["F"]["L"]["q"]
    S["F"]["L"]["curl"] = [lerp(x, -0.2, min(1.0, g)) for x in S["F"]["L"]["curl"]]
    S["halo"]["loc"].z += 0.05 * w(3) - 0.05 * r(2) + 0.08 * jolt(t, 28, 6); S["halo"]["e"][0] += -8 * w(4) + 12 * r(3)
    # the crystals turn their points straight down and drive at the floor with the fist, and stay down while it holds
    dr = curve(t, [(24, 0), (27.5, 1.15), (31, 0.95), (45, 1.0), (60, 0)])
    spk(S, inn=0.12 * w(2) + 0.2 * dr, up=0.10 * w(2), out=-0.2 * w(2) - 0.12 * dr, loc=Vector((-0.10 * dr, -0.10 * dr, -0.22 * dr - 0.04 * jolt(t, 27))),
        each=lambda i, n: (Vector(), TILT[n] * (-1.2 * dr)))
    return S
bake("ground_punch", punch_state, 66, Air(life=0.8))

# ---------------------------------------------------------------- burst (the spike burst): both fists thrown wide and high, slammed down either side; the crystals fan out
def burst_state(t):
    END = 72
    def w(dt=0): return curve(t - dt, [(0, 0), (19, 1), (23.5, 1.07), (27, 0)])
    def r(dt=0): return curve(t - dt, [(23, 0), (27, 1.12), (30, 0.95), (33, 1.0), (46, 1.0), (END, 0)])
    busy = curve(t, [(0, 0), (8, 1), (50, 1), (END, 0)])
    S = base(t - END, 1 - 0.8 * busy)
    add(S, "body", x=-5 * w() + 6 * r()); add(S, "spine", x=-5 * w(1) + 6 * r(1)); add(S, "chest", x=-7 * w(2) + 8 * r(1))
    add(S, "neck", x=-5 * w(3) + 3 * r(3)); add(S, "head", x=-10 * w(4) + 6 * r(4) + 5 * jolt(t, 28, 6))
    S["loc"] += Vector((0, 0.10 * w() - 0.12 * r(), 0.30 * w() - 0.50 * r() + 0.04 * jolt(t, 27)))
    for sd, dl in (("R", 0.0), ("L", 1.0)):
        tt = t - dl if t < 24 else t - dl * max(0.0, (27 - t) / 3)
        POS = [(0, None), (10, (-1.78, 0.10, 2.00)), (20, (-2.16, 0.16, 2.96)), (23.5, (-2.22, 0.22, 3.04)), (27, (-1.75, -0.55, SLAM_Z), True),
               (29.5, (-1.75, -0.55, SLAM_Z + 0.09), True), (32, (-1.75, -0.55, SLAM_Z), True), (46, (-1.75, -0.55, SLAM_Z), True), (59, (-1.50, -0.40, 1.36)), (END, None)]
        ORI = [(0, QREST), (20, orient(sd, V(-0.8, 0.0, 0.6), V(0.1, -1, 0.1))), (23.5, orient(sd, V(-0.75, 0.1, 0.65), V(0.1, -1, 0.1))),
               (27, orient(sd, V(0, 0, -1), V(1, -0.2, 0))), (46, orient(sd, V(0, 0, -1), V(1, -0.2, 0))), (END, QREST)]
        cl = [curve(tt, [(2 + i, 0.2), (8, -0.25), (16 + i, -0.25), (23 + 0.5 * i, 1.0), (47, 1.0), (62 + i, 0.2)]) for i in range(3)]
        fist(S, sd, tt, POS, ORI, curl=cl, thumb=curve(tt, [(3, 0.2), (10, 0.0), (18, 0.0), (24, 1.0), (47, 1.0), (62, 0.2)]), zmin=SLAM_Z - 0.02)
    S["halo"]["loc"].z += 0.08 * w(3) - 0.08 * r(2) + 0.12 * jolt(t, 28, 6); S["halo"]["e"][0] += -12 * w(4) + 10 * r(3)
    op = curve(t, [(26, 0), (30, 1), (46, 0.8), (62, 0)])                 # the broken halo springs open with the blow
    S["halo"]["L"] = (Vector(), [0, -6 * op, 9 * op]); S["halo"]["R"] = (Vector(), [0, 6 * op, -9 * op])
    # this is the crystals' move: they gather tight under the body, then fan out wide, points outwards, and hold
    g = w(2); fan = curve(t, [(25, 0), (28.5, 1.2), (32, 0.95), (46, 0.9), (64, 0)])
    spk(S, inn=0.6 * g - 0.55 * fan, up=0.14 * g - 0.04 * fan + 0.03 * jolt(t, 27), out=-0.55 * g + 1.5 * fan)
    return S
class BurstAir(Air):
    def gust(self, t): return 1 + 4 * curve(t, [(25, 0), (29, 1), (44, 0)])
bake("burst", burst_state, 72, BurstAir(life=0.8))

# ---------------------------------------------------------------- rise: it is the first body; it gathers itself off the floor
RISE = 30
LOW = {"body": 10, "spine": 16, "chest": 28, "neck": 8, "head": 14}        # hunched over
def rise_state(t):
    def u(dt=0): return curve(t - dt, [(0, 0), (3, 0.03), (14, 1.10), (19, 0.97), (24, 1.0)])   # the torso lifts and unfolds, top last
    S = base(t - RISE, curve(t, [(12, 0), (RISE, 1)]))
    for i, (b, a) in enumerate(LOW.items()): add(S, b, x=a * (1 - u(i)))
    S["loc"] += Vector((0, 0.10 * (1 - u()), -0.80 * (1 - u())))
    for sd, dl in (("R", 0.0), ("L", 2.0)):
        tt = t - dl
        POS = [(0, (-1.30, -0.36, FLOOR_Z), True), (4, (-1.28, -0.36, FLOOR_Z), True), (11, (-1.14, -0.34, 1.00)), (18, (-1.44, -0.30, 1.72)),
               (22.5, (-1.37, -0.27, 1.46)), (27, None)]
        ORI = [(0, orient(sd, *FALLEN)), (4, orient(sd, *FALLEN)), (10, orient(sd, V(0.28, -0.3, -0.91), V(1, 0.1, 0.45))),
               (18, orient(sd, V(-0.14, 0.06, -1), V(1, -0.3, -0.1))), (26, QREST)]
        S["F"][sd]["pos"] = FC[sd] + (S["F"][sd]["pos"] - FC[sd]) * curve(tt, [(18, 0), (28, 1)])
        S["F"][sd]["q"] = QREST.slerp(S["F"][sd]["q"], curve(tt, [(18, 0), (28, 1)]))
        fist(S, sd, tt, POS, ORI, curl=[curve(tt, [(0, 0.45), (8 + i, 0.9), (17 + i, 0.0), (24 + i, S["F"][sd]["curl"][i])]) for i in range(3)],
             thumb=curve(tt, [(0, 0.4), (10, 0.8), (20, 0.1), (26, 0.2)]), zmin=FLOOR_Z - 0.02)
    h = curve(t, [(10, 0), (22, 1.08), (26, 0.97), (29, 1.0)])               # the halo comes up last and settles
    S["halo"]["loc"] += Vector((0, 0, -0.22 * (1 - h))); wob = math.sin(TAU * t / 9.0) * 4 * h * (1 - min(1.0, h))
    S["halo"]["e"] = [S["halo"]["e"][0] + 16 * (1 - h) + wob, S["halo"]["e"][1] + 24 * (1 - h), S["halo"]["e"][2]]
    # the crystals lie splayed on the floor; each comes up after the torso and finds its place, the last of everything
    def one(i, n):
        us = curve(t - 5 - i, [(0, 0), (3, 0.03), (12, 1.08), (16, 0.98), (19, 1.0)])
        return Vector((0, 0, min(0.03, 0.80 * (us - u())))), RAD[n] * (0.9 * (1 - min(1.0, us)))
    spk(S, each=one)
    return S
class RiseAir(Air):
    def limp(self, d, t): return curve(t - (2 if d.name.endswith(".L") else 0), [(4, 1), (15, 0)])
bake("rise", rise_state, RISE, RiseAir(life=0.8))

# ---------------------------------------------------------------- break: it comes apart (played through the shatter)
BREAK = 45
FOLD = {"body": 5, "spine": 12, "chest": 28, "neck": 8, "head": 14}          # 45 degrees at the chest, the hood bowed further
SINK = 0.48                                                                  # 15% of its 3.23 m
def break_state(t):
    k = 1 - curve(t, [(0, 0), (10, 1)])
    S = base(t, k)
    a = curve(t, [(0, 0), (4, 1), (11, 0)])                                    # the blow throws it back
    def f(dt=0): return curve(t - dt, [(8, 0), (27, 1.07), (32, 0.98), (35, 1.0)])   # then it folds, from the waist up
    tr = curve(t, [(0, 0), (4, 1), (30, 1), (40, 0)])                            # it shakes while it still holds together
    for i, (b, ang) in enumerate(FOLD.items()): add(S, b, x=ang * f(1.2 * i) - (3, 4, 5, 3, 6)[i] * a)
    add(S, "chest", z=2.5 * tr * s(t / 2.6), y=2.0 * tr * s(t / 3.1)); add(S, "head", z=4 * tr * s(t / 2.9 + 0.2), y=3 * tr * s(t / 3.4))
    S["loc"] += Vector((0.012 * tr * s(t / 2.3), 0.08 * a + 0.06 * f(), 0.06 * a - SINK * curve(t, [(6, 0), (14, 0.2), (30, 1.08), (35, 0.96), (39, 1.0)])))
    for sd, dl in (("R", 0.0), ("L", 4.0)):
        tt = t - dl
        POS = [(0, None), (4, (-1.56, -0.24, 1.74)), (10, (-1.50, -0.30, 1.56)), (16, (-1.46, -0.38, 1.28)), (20, (-1.42, -0.42, 1.12)),
               (26, (-1.30, -0.50, FLOOR_Z), True), (28.5, (-1.30, -0.52, FLOOR_Z + 0.11), True), (31, (-1.30, -0.53, FLOOR_Z), True)]
        ORI = [(0, QREST), (4, orient(sd, V(-0.2, -0.1, -1), V(1, -0.2, 0.15))), (16, orient(sd, V(-0.1, -0.3, -0.95), V(1, -0.2, 0.3))),
               (26, orient(sd, *FALLEN)), (28.5, orient(sd, V(-0.25, -0.93, -0.2), V(0.1, -0.1, 1.0))), (31, orient(sd, *FALLEN))]
        S["F"][sd]["pos"] = FC[sd] + (S["F"][sd]["pos"] - FC[sd]) * (1 - curve(tt, [(0, 0), (20, 1)]))
        S["F"][sd]["q"] = S["F"][sd]["q"].slerp(QREST, curve(tt, [(0, 0), (20, 1)]))
        cl = [curve(tt, [(0, S["F"][sd]["curl"][i]), (4, -0.3), (9 + i, 0.55), (18 + i, 0.2), (27, 0.3), (32 + i, 0.45)]) for i in range(3)]
        fist(S, sd, tt, POS, ORI, curl=cl, thumb=curve(tt, [(0, 0.2), (4, -0.2), (12, 0.6), (30, 0.4)]), zmin=FLOOR_Z - 0.01)
        sh = curve(tt, [(3, 0), (7, 1), (19, 1), (25, 0)])                        # the fist's grip on the air stutters before it goes
        S["F"][sd]["pos"] += Vector((0.022 * s(tt / 2.1), 0.018 * s(tt / 2.7 + 0.3), 0.03 * s(tt / 1.9 + 0.1))) * sh
    # the halo tips, cracks into its two halves, and they slump apart
    tip = curve(t, [(4, 0), (13, 0.5), (22, 1.1), (28, 1.0)]); sp = curve(t, [(13, 0), (17, 1.25), (21, 0.9), (25, 1.0)]); sag = curve(t, [(17, 0), (34, 1)])
    S["halo"]["e"] = [S["halo"]["e"][0] * k + 14 * tip, S["halo"]["e"][1] * k + 30 * tip + 3 * tr * s(t / 2.2), S["halo"]["e"][2] * k]
    S["halo"]["loc"] = Vector((0, 0, 0.05 * a - 0.16 * sag))
    S["halo"]["L"] = (Vector((0.10 * sp, 0.0, -0.03 * sp - 0.03 * sag)), [0, -16 * sp, 10 * sp])
    S["halo"]["R"] = (Vector((-0.13 * sp, 0.02 * sp, -0.05 * sp - 0.10 * sag)), [10 * sag, 22 * sp + 14 * sag, -14 * sp])
    # the crystals under it work loose, one after another
    for i, n in enumerate(SPIKES):
        sl = curve(t, [(9 + 4 * i, 0), (13 + 4 * i, 1.15), (16 + 4 * i, 1.0)])
        S["misc"][n] = {"loc": Vector((0, 0, -0.10 * sl))}
    for i, n in enumerate(("tag.R", "tag.L")):
        sl = curve(t, [(7 + 6 * i, 0), (12 + 6 * i, 1.2), (16 + 6 * i, 1.0)])
        S["misc"][n] = {"loc": Vector((0, -0.02 * sl, -0.12 * sl))}
    return S
class BreakAir(Air):
    def limp(self, d, t): return curve(t - (4 if d.name.endswith(".L") else 0), [(8, 0), (22, 1)])
    def gust(self, t): return 1 + 5 * curve(t, [(0, 0), (4, 1), (24, 0.6), (38, 0)])
    def flare(self, d, t): return 0.35 * curve(t, [(8, 0), (24, 1)])
bake("break", break_state, BREAK, BreakAir(life=0.8))

# ---------------------------------------------------------------- flinch: a hit jolts it back; the fists and the halo take it a beat later
def flinch_state(t):
    END = 16
    def j(dt=0): return curve(t - dt, [(0, 0), (3, 1), (8, -0.25), (12, 0.06), (END, 0)])
    S = base(t - END)
    add(S, "body", x=-3 * j()); add(S, "spine", x=-4 * j(1)); add(S, "chest", x=-6 * j(1), z=4 * j(2)); add(S, "neck", x=3 * j(2)); add(S, "head", x=7 * j(3), z=-5 * j(3))
    S["loc"] += Vector((0.02 * j(), 0.14 * j(), 0.04 * j()))
    for sd in "LR":
        f = S["F"][sd]
        f["pos"] += M(sd, V(-0.16, 0.20, 0.10)) * j(2 if sd == "R" else 3)
        f["q"] = qe(x=-9 * j(3), z=-8 * SX[sd] * j(3)) @ f["q"]
        f["curl"] = [x - 0.35 * max(0.0, j(2 + i)) for i, x in enumerate(f["curl"])]
    S["halo"]["loc"].z += 0.07 * j(4); S["halo"]["e"][0] += -12 * j(4); S["halo"]["e"][1] += 6 * j(5)
    spk(S, out=0.3 * j(2), up=0.04 * j(3))                 # the crystals start outwards with the jolt
    return S
bake("flinch", flinch_state, 16, Air(life=0.8))

# ---------------------------------------------------------------- stagger: it reels, sags with its fists hanging near the floor, sways, and gathers itself
def stagger_state(t):
    END = 60
    hit = curve(t, [(0, 0), (4, 1), (11, 0)])
    sag = curve(t, [(3, 0), (16, 1.08), (22, 1.0), (46, 1.0), (END, 0)])
    S = base(t - END, 1 - 0.8 * sag)
    sw = s(t / 34.0) * sag; sw2 = s(t / 34.0 - 0.12) * sag
    add(S, "body", x=-4 * hit + 5 * sag, y=3 * sw, z=3 * sw); add(S, "spine", x=-5 * hit + 6 * sag, y=3 * sw)
    add(S, "chest", x=-7 * hit + 9 * sag, y=3 * sw2, z=-4 * sw2); add(S, "neck", x=6 * sag, y=3 * sw2)
    add(S, "head", x=6 * hit + 10 * curve(t, [(6, 0), (20, 1.1), (26, 1.0), (44, 1.0), (56, 0)]), y=7 * sw2, z=-6 * sw2)
    S["loc"] += Vector((0.05 * sw, 0.16 * hit + 0.04 * sag, 0.05 * hit - 0.30 * sag + 0.02 * sag * s(t / 17.0)))
    for sd, dl in (("R", 0.0), ("L", 3.0)):
        f = S["F"][sd]; g = curve(t - dl, [(3, 0), (17, 1.1), (23, 1.0), (45, 1.0), (58, 0)])
        f["pos"] += M(sd, V(-0.10, 0.22, 0.12)) * curve(t - dl, [(0, 0), (4, 1), (12, 0)]) + M(sd, V(0.10, -0.12, -0.72)) * g + Vector((0.05 * s(t / 34.0 - 0.2), 0, 0)) * g
        f["q"] = f["q"].slerp(orient(sd, V(0.12, -0.25, -0.96), V(1, -0.2, 0.25)), min(1.0, g))
        f["curl"] = [lerp(x, 0.08, min(1.0, g)) for x in f["curl"]]; f["thumb"] = lerp(f["thumb"], 0.0, min(1.0, g))
    S["halo"]["loc"].z += 0.06 * hit - 0.10 * sag; S["halo"]["e"][0] += -10 * hit + 10 * sag; S["halo"]["e"][1] += 16 * sag + 8 * sw2
    # the crystals lose their hold: each sags in its turn and hangs, some tipping over
    def one(i, n):
        g = curve(t - 2 * i, [(4, 0), (16, 1.1), (22, 1.0), (44 - 2 * i, 1.0), (56 - 2 * i, 0)])
        return Vector((0.03 * sw * g, 0, -(0.10 + 0.03 * i) * g)), TANG[n] * ((0.45, -0.25, 0.6, -0.4, 0.3)[i] * g) + RAD[n] * (0.15 * g)
    spk(S, each=one)
    return S
class StaggerAir(Air):
    def limp(self, d, t): return 0.45 * curve(t, [(4, 0), (18, 1), (44, 1), (56, 0)])
bake("stagger", stagger_state, 60, StaggerAir(life=0.8))

# ---------------------------------------------------------------- roar: it draws in, then rears back with both fists flung wide, claws spread, shaking
def roar_state(t):
    END = 50
    inn = curve(t, [(0, 0), (7, 1), (11, 0)])
    r = lambda dt=0: curve(t - dt, [(7, 0), (13, 1.12), (17, 0.97), (20, 1.0), (38, 1.0), (END, 0)])
    sh = curve(t, [(12, 0), (15, 1), (36, 1), (41, 0)])
    S = base(t - END, 1 - 0.8 * max(inn, min(1.0, r())))
    add(S, "body", x=5 * inn - 5 * r()); add(S, "spine", x=5 * inn - 6 * r(1)); add(S, "chest", x=6 * inn - 9 * r(2), z=1.5 * sh * s(t / 2.4))
    add(S, "neck", x=-4 * r(3)); add(S, "head", x=6 * inn - 12 * r(4), z=3 * sh * s(t / 2.7 + 0.2), y=2 * sh * s(t / 3.1))
    S["loc"] += Vector((0.012 * sh * s(t / 2.2), -0.05 * inn + 0.14 * r(), -0.14 * inn + 0.24 * r() + 0.012 * sh * s(t / 1.9)))
    for sd, dl in (("R", 0.0), ("L", 1.0)):
        f = S["F"][sd]; g = r(2 + dl); gi = curve(t - dl, [(0, 0), (7, 1), (12, 0)])
        f["pos"] += M(sd, V(0.22, -0.25, -0.05)) * gi + M(sd, V(-0.62, 0.30, 0.55)) * g + Vector((0.015 * s(t / 2.0 + dl), 0, 0.02 * s(t / 2.3 + dl))) * sh
        f["q"] = f["q"].slerp(orient(sd, V(-0.55, -0.25, -0.8), V(0.55, -0.8, -0.2)), min(1.0, g))
        f["curl"] = [lerp(x, 0.9, gi) - 0.45 * min(1.0, g) * (1 if gi < 0.01 else 1 - gi) for x in f["curl"]]
        f["thumb"] = lerp(f["thumb"], -0.2, min(1.0, g))
    S["halo"]["loc"].z += -0.04 * inn + 0.10 * r(3); S["halo"]["e"][0] += -14 * r(4); S["halo"]["e"][1] += 4 * sh * s(t / 2.5)
    op = curve(t, [(11, 0), (15, 1), (36, 0.9), (46, 0)])
    S["halo"]["L"] = (Vector(), [0, -5 * op, 7 * op]); S["halo"]["R"] = (Vector(), [0, 5 * op, -7 * op])
    # the crystals spread and tremble with it
    spk(S, inn=0.12 * inn - 0.3 * min(1.0, r(3)), up=0.05 * r(3), out=-0.2 * inn,
        each=lambda i, n: (Vector((0.012 * s(t / 2.1 + 0.3 * i), 0.012 * s(t / 2.5 + 0.2 * i), 0.016 * s(t / 1.9 + 0.37 * i))) * sh, Vector()))
    return S
class RoarAir(Air):
    def flare(self, d, t): return 0.6 * curve(t, [(11, 0), (15, 1.2), (20, 1.0), (36, 1.0), (46, 0)])
    def gust(self, t): return 1 + 5 * curve(t, [(11, 0), (15, 1), (36, 0.8), (44, 0)])
bake("roar", roar_state, 50, RoarAir(life=0.8))

rig.animation_data.action = None
for pb in rig.pose.bones: pb.matrix_basis.identity()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
zdlib.emit({"actions": {a.name: [round(x) for x in a.frame_range] for a in bpy.data.actions}, "loop_seam_degrees": SEAM})
