"""rig.blend -> anim.blend: the Prism's actions, each also stashed on an NLA track.

The body (body, chest, neck, the hood, the chest crystal, the halo and its pieces) is written as functions of time:
periodic terms for the loops, eased ramps read a little later by each joint down the spine for the attacks. What hangs
(the cloak's seven chains, the seven spikes under her) is not written by hand: each of those bones is a small weight on
a spring that the body drags along, stepped through the clip and then keyed; a clip only says how far a rag should lift
or drape, and the spring arrives late, swings past and settles.
The free shards (`shards` and `shard_NN`) are never keyed: the game turns them. `shards_lift`, their parent, only
rises and sinks with her.
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
def curve(t, keys):
    """Eased interpolation through (frame, value) keys."""
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def curve_in(t, keys):
    """As curve, but each span starts slow and ends fast (a fall)."""
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: u = (t - f0) / (f1 - f0); return lerp(v0, v1, u * u)
    return keys[-1][1]
def arc(d0, d1, t):
    d0 = Vector(d0).normalized(); d1 = Vector(d1).normalized()
    ax, ang = d0.rotation_difference(d1).to_axis_angle()
    return Quaternion(ax, ang * t) @ d0
def V(*a): return Vector(a)
def rest_dir(n): return P.rest[n].to_3x3().col[1].normalized()
def rest_head(n): return P.rest[n].translation.copy()

AX = rest_head("body"); AX.z = 0.0
NAMES = [b.name for b in P.bones]
GAME = {"shards"}                                # the game yaws it (the orbit): never keyed
SHARD = sorted(n for n in NAMES if n.startswith("shard_"))
CHAIN = [n for n in NAMES if n[:4] in ("wing", "back") or n.startswith("front")]
SPIKE = [n for n in NAMES if n.startswith("spike")]
LOCB = {"body", "core", "halo", "halo_ring", "halo_disc", "crown.L", "crown.R", "shards_lift"} | set(SPIKE) | set(SHARD)
WINGS, FRONT, BACK = ("wing{}.L", "wing{}.R"), ("front{}.L", "front{}.R"), ("back{}.L", "back{}", "back{}.R")
ALLC = WINGS + FRONT + BACK
FLOOR = -0.363          # the game floats her 0.35 m over the floor (at its 3.0 m scale): the floor in this frame
# The slow turn of every free crystal about its own long axis (its bone's Y): one turn in 10 s, each next one the other
# way round. It is baked: a loop holds exactly one turn, and a one-shot clip either holds a whole number of turns or
# ends where it began, so every clip starts and ends on the idle's first frame's angles.
SPIN = {n: (1 if i % 2 == 0 else -1) for i, n in enumerate(sorted(
    n for n in NAMES if n.startswith("shard_") or n.startswith("crown") or (n.startswith("spike") and n != "spike_front")))}
SPIN_RATE = 360.0 / 300.0           # degrees a frame
TURNS = {}
def whirl(end, turns):
    """The steady turn, quickened through the middle of the clip (slow in, slow out) so it ends on a whole turn."""
    extra = 360.0 * turns - SPIN_RATE * end
    return lambda f: SPIN_RATE * f + extra * smooth(f / float(end))
SRAD, STAN, SR, SZ = {}, {}, {}, {}
for n in SHARD:
    h = rest_head(n) - AX; SZ[n] = h.z; h.z = 0; SR[n] = h.length; SRAD[n] = h.normalized(); STAN[n] = Vector((-SRAD[n].y, SRAD[n].x, 0))

def key(pose, frame, spin=0.0):
    world, basis = P.solve(pose)
    for n, Mb in basis.items():
        if n in GAME or n == "root": continue
        pb = rig.pose.bones[n]; pb.rotation_mode = 'QUATERNION'
        loc, rot, _ = Mb.decompose()
        if n in SPIN: rot = rot @ Quaternion(Y, SPIN[n] * math.radians(spin))        # the slow turn about its own long axis
        if n in P.prevq and P.prevq[n].dot(rot) < 0: rot.negate()
        P.prevq[n] = rot.copy()
        pb.rotation_quaternion = rot; pb.keyframe_insert("rotation_quaternion", frame=frame)
        if n in LOCB:
            pb.location = loc; pb.keyframe_insert("location", frame=frame)

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True

# ---------------------------------------------------------------- what hangs: springs
class Dyn:
    def __init__(self, name, w, z, grav, wind, maxang, anchor=None, margin=0.1):
        self.name = name; self.w = w; self.z = z; self.grav = grav; self.wind = wind
        self.maxang = math.radians(maxang)
        self.par = P.par[name]; self.rest_dir = rest_dir(name); self.len = P.len[name]
        h = rest_head(name) - AX; self.ang = math.atan2(h.y, h.x)
        self.rad = Vector((math.cos(self.ang), math.sin(self.ang), 0)); self.tan = Vector((-math.sin(self.ang), math.cos(self.ang), 0))
        self.level = 0; self.p = None; self.v = Vector(); self.h = None
        self.anchor = anchor
        if anchor: self.wall = rest_head(name) + self.rest_dir * self.len - self.rad * margin
DYN = {}
for n in CHAIN:
    k = int([ch for ch in n if ch.isdigit()][0])
    DYN[n] = Dyn(n, w=(7.0, 6.0, 5.0)[k - 1], z=(0.45, 0.36, 0.30)[k - 1], grav=0.55, wind=(0.04, 0.08, 0.13)[k - 1],
                 maxang=(55, 65, 75)[k - 1], anchor=("chest", "body", "body")[k - 1], margin=(0.10, 0.16, 0.22)[k - 1])
    if not n.startswith("back"):             # the wings and the front rags are short stiff boards of cloth: they give less than the long back
        DYN[n] = Dyn(n, w=(8.0, 8.5, 9.0)[k - 1], z=0.5, grav=0.5, wind=(0.03, 0.05, 0.07)[k - 1],
                     maxang=(40, 28, 22)[k - 1], anchor=("chest", "body", "body")[k - 1], margin=(0.10, 0.16, 0.22)[k - 1])
for n in SPIKE:
    DYN[n] = Dyn(n, w=5.5, z=0.22, grav=0.85, wind=0.015, maxang=30) if n != "spike_front" else Dyn(n, w=7.0, z=0.4, grav=0.2, wind=0.0, maxang=12)   # the cluster is fused to her: it only gives a little
for d in DYN.values():
    p = d.par
    while p:
        if p in DYN: d.level += 1
        p = P.par[p]
LEVELS = max(d.level for d in DYN.values()) + 1
SUB = 6; DT = 1.0 / 30 / SUB

class Air:
    """What moves the hanging things besides the body: a slow travelling sway and a steady drag."""
    def __init__(self, period=96.0, life=1.0, drag=(0, 0, 0), walls=True, keep=("-",)):
        self.period = period; self.life = life; self.drag = Vector(drag); self.walls = walls; self.keep = keep     # keep: chains that stay outside her whatever walls says
    def wind(self, d, t):
        a = d.ang / TAU; k = d.level; T = self.period
        w = d.tan * s(t / T - a - 0.14 * k) + d.rad * (0.6 * s(2 * t / T - 2 * a - 0.2 * k)) + d.tan * (0.35 * s(3 * t / T + a - 0.25 * k))
        return w * (d.wind * self.life) + self.drag * (0.5 + 0.5 * k) * (d.wind / 0.1)

def carried(world, n):
    p = P.par[n]
    return world[p] @ P.rest[p].inverted() @ P.rest[n]
def step_dyn(pose, t, air):
    """Advance every hanging bone one frame under the given pose, and write its direction into the pose.
    A hanging bone's own entry may say: lift (degrees out and up from where it would hang), down (0..1, towards
    hanging straight down beside her), loc (an offset of its head)."""
    for level in range(LEVELS):
        world, _ = P.solve(pose)
        for d in DYN.values():
            if d.level != level: continue
            ops = pose.get(d.name, {}); loc = Vector(ops.get("loc", (0, 0, 0)))
            M0 = carried(world, d.name); h = M0.translation + loc; cdir = M0.to_3x3().col[1].normalized()
            tdir = cdir.lerp(d.rest_dir, d.grav).normalized()
            if ops.get("lift"): tdir = Quaternion(d.tan, -math.radians(ops["lift"])) @ tdir
            if ops.get("down"): tdir = tdir.lerp((Vector((0, 0, -1)) + d.rad * 0.12).normalized(), ops["down"]).normalized()
            tdir = (tdir + air.wind(d, t)).normalized()
            wl = 1.0 if d.name.startswith(air.keep) else (air.walls(t) if callable(air.walls) else float(air.walls))
            if d.anchor and wl > 0:          # where it would hang is moved out of the body; the spring then keeps it out
                A = world[d.anchor] @ P.rest[d.anchor].inverted(); n = A.to_3x3() @ d.rad; dep = (h + tdir * d.len - A @ d.wall).dot(n)
                if dep < 0: tdir = (tdir * d.len - n * dep * wl).normalized()
            if d.p is None: d.p = h + tdir * d.len; d.v = Vector(); d.h = h
            h0 = d.h
            for i in range(SUB):
                hh = h0.lerp(h, (i + 1) / SUB)
                acc = (hh + tdir * d.len - d.p) * (d.w * d.w) - d.v * (2 * d.z * d.w)
                d.v += acc * DT
                pn = d.p + d.v * DT
                r = (pn - hh).normalized()
                ang = tdir.angle(r)
                if ang > d.maxang: r = arc(tdir, r, d.maxang / ang)
                pn = hh + r * d.len
                d.v = (pn - d.p) / DT
                d.p = pn
            d.h = h
            pose[d.name] = {"aim": (d.p - h).normalized(), "loc": loc}
    return pose

# ---------------------------------------------------------------- a frame's pose, built up from parts
IDLE = 150              # the body's own period (frames, 5 s): the bob and the hood on it, the breath and the core's beat twice in it
LONG = 300              # the idle and walk loops (10 s): each free crystal turns once about its own axis in it, and floats on 5 s or 10 s
RAG_GAIN = 0.65
class F:
    """One frame: Euler degrees per bone (x leans forward, y tilts to her left, z turns left), head offsets, rag orders.
    It starts from the hover that never stops (scaled by k): the bob, the breath, the hood's slow turn, the halo's drift."""
    def __init__(self, t, k=1.0):
        ph = t / IDLE; self.t = t
        self.E = {"body": [1.2 * s(ph - 0.05) * k, 0.8 * s(ph + 0.2) * k, 2.0 * s(ph) * k],
                  "chest": [1.6 * s(2 * ph - 0.2) * k, 0.5 * s(ph) * k, 1.4 * s(ph - 0.16) * k],
                  "neck": [0.8 * s(ph - 0.25) * k, 0.0, 2.0 * s(ph - 0.25) * k],
                  "head": [2.2 * s(2 * ph - 0.35) * k, 1.2 * s(ph - 0.3) * k, 5.0 * s(ph - 0.33) * k],
                  "halo": [1.5 * s(ph - 0.3) * k, 1.8 * s(ph - 0.4) * k, -2.0 * s(ph - 0.2) * k],
                  "halo_ring": [0.0, 7.0 * s(ph - 0.1) * k, 0.0],
                  "halo_disc": [2.0 * s(ph - 0.45) * k, 1.5 * s(2 * ph - 0.3) * k, 0.0],
                  "crown.L": [0.0, 4.0 * s(ph - 0.15) * k, 3.0 * s(ph - 0.5) * k],
                  "crown.R": [0.0, 4.0 * s(ph - 0.65) * k, 3.0 * s(ph) * k]}
        beat = max(0.0, s(2 * ph - 0.05)) ** 3              # the core's pulse: two beats a loop, with the breath
        self.L = {"body": V(0.02 * s(ph + 0.25), 0.015 * s(ph + 0.05), 0.06 * s(ph) + 0.015 * s(2 * ph)) * k,
                  "core": V(0, -0.03 * beat * k, 0),
                  "halo": V(0, 0, 0.04 * s(ph - 0.2)) * k,
                  "halo_disc": V(0, 0, 0.03 * s(ph - 0.55)) * k,
                  "crown.L": V(0, 0, 0.035 * s(ph - 0.35)) * k, "crown.R": V(0, 0, 0.035 * s(ph - 0.85)) * k,
                  "shards_lift": V(0, 0, 0.04 * s(ph - 0.15)) * k}
        self.R = {}; self.S = {}
        self.float_shards(t, k, LONG)
    def rot(self, bone, x=0.0, y=0.0, z=0.0):
        e = self.E.setdefault(bone, [0.0, 0.0, 0.0]); e[0] += x; e[1] += y; e[2] += z
    def loc(self, bone, x=0.0, y=0.0, z=0.0):
        self.L[bone] = self.L.get(bone, Vector()) + Vector((x, y, z))
    def rag(self, chains, l1=0.0, l2=0.0, l3=0.0, down=0.0):
        """The cloak's chains: lift each link (degrees out and up), or let it drape straight down."""
        for fmt in chains:
            for i, l in enumerate((l1, l2, l3)):
                r = self.R.setdefault(fmt.format(i + 1), {"lift": 0.0, "down": 0.0}); r["lift"] += l; r["down"] = max(r["down"], down)
    def spikes(self, lift=0.0, up=0.0, inward=0.0, names=None):
        """The hanging spikes: swung out, drawn up into her, drawn in to her axis."""
        for n in names or SPIKE:
            r = self.R.setdefault(n, {"lift": 0.0, "down": 0.0}); r["lift"] += lift
            d = DYN[n]; off = rest_head(n) - AX; off.z = 0
            r["loc"] = r.get("loc", Vector()) + Vector((0, 0, up)) - off * inward
    def ground(self, dz, sign=1, names=None):
        """She has sunk by dz: each loose spike that would reach the floor leans over just far enough to lie on it
        (sign 1: tips out from under her; -1: tips in under her), and is lifted if even that is not enough."""
        for n in names or SPIKE:
            if n == "spike_front": continue
            L = P.len[n]; cl = rest_head(n).z + dz - (FLOOR + 0.05)
            th = 0.0 if cl >= L else (math.degrees(math.acos(cl / L)) if cl > 0 else 90.0)
            r = self.R.setdefault(n, {"lift": 0.0, "down": 0.0}); r["lift"] += sign * th
            if cl < 0: r["loc"] = r.get("loc", Vector()) + Vector((0, 0, -cl))
    def float_shards(self, t, k, period):
        """The free shards held in the air: each bobs and breathes in and out from her axis on its own slow period and
        phase (whole numbers of cycles in `period`, so a loop of that length closes), and tips a degree or two."""
        ph = t / period
        for i, n in enumerate(SHARD):
            m = (1, 2, 1, 2, 2, 1, 1, 2, 1)[i % 9]
            self.shard(n, up=(0.05 + 0.015 * (i % 3)) * s(m * ph + 0.23 * i) * k, out=0.05 * s((3 - m) * ph + 0.31 * i + 0.1) * k,
                       tilt=2.5 * s(ph + 0.17 * i) * k)
    def shard(self, n, out=0.0, up=0.0, side=0.0, tilt=0.0, aim=None, w=0.0, fwd=0.0, aimv=None):
        """A free shard, in the frame the game's orbit carries: out from her axis, up, sideways along the orbit (m);
        tipped out (degrees); its point swung towards `aim` (given as (out, along, up)) by the share w."""
        r = self.S.setdefault(n, {"out": 0.0, "up": 0.0, "side": 0.0, "tilt": 0.0, "aim": None, "w": 0.0})
        r["out"] += out; r["up"] += up; r["side"] += side; r["tilt"] += tilt; r["fwd"] = r.get("fwd", 0.0) + fwd
        if aimv is not None and w > r["w"]: r["aim"] = ("v", aimv); r["w"] = w
        if aim is not None and w > r["w"]: r["aim"] = aim; r["w"] = w
    def lift(self, z):
        """She and her shards rise together."""
        self.loc("body", z=z); self.loc("shards_lift", z=z)
    def pose(self):
        # The cloak is one cloth: a chain between a wing and the back takes part of the wing's lift, so the cloth that
        # joins them is not pulled apart.
        def lf(n): return self.R.get(n, {}).get("lift", 0.0)
        for sd in ("L", "R"):
            for i in (1, 2, 3):
                wn, bn, fn_, mid = f"wing{i}.{sd}", f"back{i}.{sd}", f"front{i}.{sd}", f"back{i}"
                w0, b0, f0, m0 = lf(wn), lf(bn), lf(fn_), lf(mid)
                self.R.setdefault(bn, {"lift": 0.0, "down": 0.0})["lift"] = 0.35 * b0 + 0.65 * w0
                self.R.setdefault(fn_, {"lift": 0.0, "down": 0.0})["lift"] = f0 + 0.35 * (w0 - f0)
        for n in CHAIN:                      # how far the rags answer an order, all clips together
            if n in self.R: self.R[n]["lift"] *= RAG_GAIN
        pose = {n: {"rot": qe(*e)} for n, e in self.E.items()}
        for n, v in self.L.items(): pose.setdefault(n, {})["loc"] = v
        for n, r in self.R.items(): pose[n] = dict(r)
        for n, r in self.S.items():
            rad, tan = SRAD[n], STAN[n]
            d = Quaternion(tan, -math.radians(r["tilt"])) @ rest_dir(n)
            if r["aim"] is not None and r["w"] > 0.001:
                a = r["aim"]; tgt = Vector(a[1]) if a[0] == "v" else rad * a[0] + tan * a[1] + Z * a[2]; d = arc(d, tgt, min(1.0, r["w"]))
            pose[n] = {"loc": rad * r["out"] + tan * r["side"] + Z * r["up"] - Y * r.get("fwd", 0.0), "aim": d}
        return pose

SEAM = {}; MAXOFF = {}
def bake(name, fn, end, air, loop=False, spin=None):
    """Key one action: fn(t) is the body's pose; the hanging bones are stepped through it."""
    for d in DYN.values(): d.p = None
    if loop:
        for cyc in range(8):                       # run the loop until what hangs repeats, then keep the last pass
            poses = [step_dyn(fn(float(f)), float(f), air) for f in range(end)]
        again = step_dyn(fn(float(end)), float(end), air)
        SEAM[name] = sorted((round(math.degrees(Vector(again[n]["aim"]).angle(Vector(poses[0][n]["aim"]))), 2), n) for n in DYN)[-2:]
        poses.append(poses[0])
    else:
        for f in range(-75, 0): step_dyn(fn(0.0), float(f), air)        # let it hang still in the first pose
        poses = [step_dyn(fn(float(f)), float(f), air) for f in range(end + 1)]
    MAXOFF[name] = round(max(Vector(p[n].get("loc", (0, 0, 0))).length for p in poses for n in SHARD), 2)
    act = poser.new_action(rig, name); P.prevq.clear()
    spin = spin or (lambda f: SPIN_RATE * f)
    TURNS[name] = round((spin(end) - spin(0)) / 360.0, 3)
    for f, pose in enumerate(poses): key(pose, f, spin(f))
    act.frame_range = (0, end); act.use_frame_range = True; act.use_cyclic = loop
    stash(act)

# ---------------------------------------------------------------- idle: she floats, breathes, the hood turns, the core beats
def idle_pose(t): return F(t).pose()

# ---------------------------------------------------------------- walk: no legs, so a glide: she leans into it and everything streams back
GLIDE = 150
class GlideAir(Air):
    """A steady glide: everything streams back, and a ripple runs down each chain from its top to its tail, each chain
    starting its ripple at its own moment so the hem never beats in step."""
    def wind(self, d, t):
        k = d.level; off = 0.37 * round(d.ang / (TAU / 8))
        w = Z * (1.4 * s(3 * t / GLIDE - 0.22 * k - off)) + X * (0.6 * s(2 * t / GLIDE - 0.18 * k - 1.7 * off))
        return w * d.wind + self.drag * (0.5 + 0.5 * k) * (d.wind / 0.1)
def walk_pose(t):
    ph = t / GLIDE
    f = F(0, 0.0)
    f.rot("body", x=12 + 1.0 * s(ph - 0.05), z=1.0 * s(ph + 0.3))
    f.rot("chest", x=5 + 0.8 * s(ph - 0.14))
    f.rot("neck", x=-3.0)
    f.rot("head", x=-6 + 1.0 * s(ph - 0.3), z=-1.0 * s(ph + 0.15))          # the hood leads, looking where she goes
    f.rot("halo", x=-9 + 1.2 * s(ph - 0.35), y=1.5 * s(ph - 0.2))           # the halo trails, tipped back
    f.rot("halo_ring", y=6 * s(ph - 0.1)); f.rot("halo_disc", x=4 + 2.0 * s(ph - 0.45))
    f.rot("crown.L", y=4 * s(ph - 0.15), x=3); f.rot("crown.R", y=4 * s(ph - 0.65), x=3)
    f.loc("halo", y=0.10, z=0.02 * s(ph - 0.3))
    f.loc("body", x=0.015 * s(ph + 0.25), y=-0.10, z=0.04 * s(ph))
    f.loc("shards_lift", z=0.03 * s(ph - 0.15))
    f.loc("core", y=-0.02 * max(0.0, s(2 * ph)) ** 3)
    f.rag(BACK, 6, 4, 2); f.rag(WINGS, 4, 0, 0)
    f.float_shards(t, 0.6, LONG)
    f.rot("shards_lift", x=8 + 0.8 * s(ph - 0.2)); f.loc("shards_lift", y=0.18 + 0.02 * s(ph - 0.3))     # the ring leans with her and trails behind
    return f.pose()

# ---------------------------------------------------------------- open (the Cross): she rises and opens, holds while the rays turn, then sags
OPEN_STRIKE, OPEN_SPIN_END, OPEN_RECOVER, OPEN_END = 30, 180, 285, 294
def open_pose(t):
    def a(dt=0): return curve(t - dt, [(0, 0), (11, 1), (19, 0)])                                    # gathered in before it
    def o(dt=0): return curve(t - dt, [(13, 0), (30, 1.10), (38, 0.96), (46, 1.0), (178, 1.0), (200, 0.0)])   # thrown open, held aloft
    def g(dt=0): return curve(t - dt, [(180, 0), (204, 1.0), (214, 0.9), (262, 0.92), (285, 0)])      # the window: she sags
    busy = curve(t, [(0, 0), (12, 1), (270, 1), (290, 0)])
    hold = curve(t, [(40, 0), (56, 1), (172, 1), (184, 0)])
    f = F(t, 1 - 0.6 * busy)
    th = t / 44.0                                                                                    # the strain of holding it
    f.rot("body", x=6 * a() - 7 * o() + 13 * g(), y=3 * g(1), z=1.5 * hold * s(th / 2))
    f.rot("chest", x=8 * a(1) - 13 * o(1) + 9 * g(2) + 1.6 * hold * s(th) + 2.4 * g() * s(t / 26.0), y=2 * g(2))
    f.rot("neck", x=6 * a(2) - 6 * o(3) + 8 * g(3))
    f.rot("head", x=10 * a(3) - 11 * o(4) + 16 * g(5) + 1.5 * hold * s(th - 0.2), y=5 * g(5), z=3 * hold * s(th / 2 - 0.2))
    f.lift(-0.10 * a() + 0.45 * o() - 0.22 * g() + 0.03 * hold * s(th / 2) - 0.02 * g() * s(t / 26.0))
    f.loc("body", y=0.05 * a() - 0.04 * o() - 0.06 * g())
    f.loc("core", y=0.03 * a(1) - 0.07 * o(2) - 0.04 * g(2) - 0.02 * hold * max(0.0, s(t / 22.0)) ** 2)
    f.rot("halo", x=5 * a(2) - 10 * o(3) + 12 * g(4), y=4 * g(4)); f.loc("halo", z=-0.04 * a(1) + 0.16 * o(3) - 0.10 * g(4))
    f.rot("halo_ring", y=12 * hold * s(t / 60.0)); f.rot("halo_disc", x=-8 * o(4) + 6 * g(5))
    f.rot("crown.L", y=-16 * o(4) + 10 * g(5)); f.rot("crown.R", y=16 * o(4) - 10 * g(6))
    f.loc("crown.L", x=0.10 * o(4), z=0.08 * o(4) - 0.08 * g(5)); f.loc("crown.R", x=-0.10 * o(4), z=0.08 * o(4) - 0.10 * g(6))
    f.rag(WINGS, -8 * a(1) + 24 * o(2) + 4 * g(2), 9 * o(3) - 6 * g(3), 4 * o(4) - 4 * g(4))
    f.rag(FRONT, -8 * a(1) + 22 * o(2) + 10 * g(2), 9 * o(3), 4 * o(4))
    f.rag(BACK, -5 * a(1) + 12 * o(3) - 4 * g(3), 6 * o(4), 3 * o(5))
    f.spikes(lift=-4 * a(1) + 12 * o(3) - 3 * g(3), up=0.03 * a(1))
    for i, n in enumerate(SHARD):            # flung out and held wide and high; in the window (the bolts fire from them) they only sag a little
        dk = i % 4
        f.shard(n, out=-0.12 * a(dk) + 0.45 * o(dk + 1) + 0.15 * g(dk), up=0.30 * o(dk + 2) - 0.15 * g(dk + 1))
        f.shard(n, aim=(1, 0, 0.6), w=0.5 * min(1.0, o(dk + 2))); f.shard(n, aim=(0.3, 0, -1), w=0.35 * g(dk + 2))
    return f.pose()

# ---------------------------------------------------------------- cast (an orb spell): gathered in, then thrown open while the orbs pour out
CAST_STRIKE, CAST_RECOVER, CAST_END = 24, 54, 84
def cast_pose(t):
    def a(dt=0): return curve(t - dt, [(0, 0), (13, 1), (20, 0.92), (26, 0)])
    def r(dt=0): return curve(t - dt, [(19, 0), (25, 1.14), (30, 0.94), (35, 1.0), (54, 1.0), (80, 0)])
    hold = curve(t, [(24, 0), (30, 1), (52, 1), (60, 0)])
    busy = curve(t, [(0, 0), (8, 1), (60, 1), (82, 0)])
    f = F(t, 1 - 0.6 * busy)
    pour = s((t - 24) / 10.0) * hold                                                               # three pushes while they pour
    f.rot("body", x=7 * a() - 5 * r(), z=-3 * a() + 3 * r(1))
    f.rot("chest", x=10 * a(1) - 12 * r(1) + 2.0 * pour, z=-3 * a(1) + 3 * r(2))
    f.rot("neck", x=6 * a(2) - 5 * r(2))
    f.rot("head", x=10 * a(3) - 8 * r(3) + 2.0 * pour, z=3 * a(3) - 3 * r(4))
    f.lift(-0.12 * a() + 0.34 * r() + 0.015 * pour)
    f.loc("body", y=0.05 * a() - 0.05 * r())
    f.loc("core", y=0.03 * a(1) - 0.06 * r(1) - 0.03 * max(0.0, pour))
    f.rot("halo", x=6 * a(2) - 8 * r(3)); f.loc("halo", z=-0.05 * a(1) + 0.12 * r(3))
    f.rot("halo_ring", y=20 * r(3)); f.rot("halo_disc", x=-6 * r(4))
    f.rot("crown.L", y=-12 * r(4)); f.rot("crown.R", y=12 * r(4)); f.loc("crown.L", z=0.06 * r(4)); f.loc("crown.R", z=0.06 * r(4))
    f.rag(WINGS, -10 * a(1) + 38 * r(1), 12 * r(2), 6 * r(3)); f.rag(FRONT, -8 * a(1) + 26 * r(1), 10 * r(2), 5 * r(3))
    f.rag(BACK, -5 * a(1) + 14 * r(2), 6 * r(3), 3 * r(4))
    f.spikes(lift=-5 * a(1) + 10 * r(2), up=0.04 * a(1))
    for i, n in enumerate(SHARD):            # drawn in tight round the core, then thrown out on the burst and pushed out with each wave
        dk = i % 3
        f.shard(n, out=-min(0.7, max(0.0, 0.55 * (SR[n] - 0.85))) * a(dk) + 0.45 * r(dk) + 0.12 * max(0.0, pour),
                up=(1.86 - SZ[n]) * 0.35 * a(dk), aim=(1, 0, 0.2), w=0.6 * min(1.0, r(dk + 1)))
    return f.pose()

# ---------------------------------------------------------------- flick (a bolt): a quick turn away, then a snap of her right wing at the target
FLICK_STRIKE, FLICK_RECOVER, FLICK_END = 15, 16, 30
def flick_pose(t):
    def w(dt=0): return curve(t - dt, [(0, 0), (9, 1), (12, 1.04), (15, 0)])
    def r(dt=0): return curve(t - dt, [(11, 0), (15, 1.15), (19, 0.90), (22, 1.0), (30, 0)])
    busy = curve(t, [(0, 0), (6, 1), (20, 1), (30, 0)])
    f = F(t, 1 - 0.5 * busy)
    f.rot("body", z=-7 * w() + 8 * r(), x=-3 * w() + 5 * r(), y=2 * w() - 2 * r())
    f.rot("chest", z=-8 * w(1) + 9 * r(1), x=-4 * w(1) + 6 * r(1))
    f.rot("neck", z=4 * w(1) - 3 * r(2)); f.rot("head", z=6 * w(2) - 5 * r(2), x=3 * w(2) + 4 * r(3))
    f.lift(0.06 * w() - 0.03 * r())
    f.loc("body", y=0.04 * w() - 0.07 * r()); f.loc("core", y=-0.04 * r(1))
    f.rot("halo", z=3 * w(2) - 3 * r(3), x=-3 * w(2) + 4 * r(3))
    f.rag(("wing{}.R",), 16 * w(1) + 22 * r(1), -6 * w(2) + 14 * r(2), 8 * r(3))
    f.rag(("front{}.R",), 6 * w(1) + 24 * r(1), 10 * r(2), 6 * r(3))
    f.rag(("wing{}.L", "front{}.L"), -4 * w(1) + 6 * r(2))
    f.spikes(lift=4 * r(2))
    f.shard("shard_05", fwd=-0.18 * w() + 0.95 * r(), aimv=(0, -1, 0), w=min(1.0, w() + r()))       # the shard on her front right, thrown forward like a dart
    for n in SHARD:
        if n != "shard_05": f.shard(n, fwd=0.04 * r(2))
    return f.pose()

# ---------------------------------------------------------------- lances: she rises with both wings high, and jabs down once for each lance
LANCE_STRIKE, LANCE_RECOVER, LANCE_END = 24, 111, 120
JABS = [LANCE_STRIKE + (LANCE_RECOVER - LANCE_STRIKE) * (k + 1) / 7.0 for k in range(6)]
def lances_pose(t):
    def a(dt=0): return curve(t - dt, [(0, 0), (10, 1), (17, 0)])
    def r(dt=0): return curve(t - dt, [(11, 0), (24, 1.10), (30, 0.96), (36, 1.0), (106, 1.0), (119, 0)])
    def jab(k, dt=0):          # the wind before each lance, the snap on it, the give after
        j = JABS[k]; return curve(t - dt, [(j - 8, 0), (j - 3, -0.45), (j, 1.0), (j + 3, 0.55), (j + 8, 0)])
    busy = curve(t, [(0, 0), (8, 1), (108, 1), (120, 0)])
    f = F(t, 1 - 0.65 * busy)
    jl = lambda dt=0: sum(jab(k, dt) for k in (0, 2, 4)); jr = lambda dt=0: sum(jab(k, dt) for k in (1, 3, 5))
    ja = lambda dt=0: jl(dt) + jr(dt)
    f.rot("body", x=5 * a() - 6 * r() + 4 * ja(), z=3 * jl() - 3 * jr(), y=-2 * jl() + 2 * jr())
    f.rot("chest", x=8 * a(1) - 12 * r(1) + 9 * ja(1), z=5 * jl(1) - 5 * jr(1))
    f.rot("neck", x=5 * a(2) - 4 * r(2) + 4 * ja(1))
    f.rot("head", x=8 * a(3) - 6 * r(3) + 9 * ja(2), z=-4 * jl(2) + 4 * jr(2))
    f.lift(-0.12 * a() + 0.50 * r() - 0.05 * ja())
    f.loc("body", y=0.05 * a() - 0.03 * r() - 0.04 * ja()); f.loc("core", y=-0.05 * r(2) - 0.03 * ja(1))
    f.rot("halo", x=5 * a(2) - 8 * r(3) + 5 * ja(3)); f.loc("halo", z=-0.04 * a(1) + 0.14 * r(3))
    f.rot("halo_ring", y=25 * r(3) + 8 * jl(2) - 8 * jr(2)); f.rot("halo_disc", x=-6 * r(4) + 3 * ja(4))
    f.rot("crown.L", y=-14 * r(4) + 8 * jl(3)); f.rot("crown.R", y=14 * r(4) - 8 * jr(3))
    f.loc("crown.L", z=0.08 * r(4)); f.loc("crown.R", z=0.08 * r(4))
    f.rag(("wing{}.L",), -8 * a(1) + 36 * r(1) - 20 * jl(1), 10 * r(2) - 8 * jl(2), 6 * r(3) - 6 * jl(3))
    f.rag(("wing{}.R",), -8 * a(1) + 36 * r(1) - 20 * jr(1), 10 * r(2) - 8 * jr(2), 6 * r(3) - 6 * jr(3))
    f.rag(("front{}.L",), -6 * a(1) + 26 * r(1) - 14 * jl(1), 10 * r(2), 5 * r(3))
    f.rag(("front{}.R",), -6 * a(1) + 26 * r(1) - 14 * jr(1), 10 * r(2), 5 * r(3))
    f.rag(BACK, -4 * a(1) + 14 * r(2), 8 * r(3), 4 * r(4))
    f.spikes(lift=-4 * a(1) + 9 * r(2) + 4 * ja(2))
    f.rot("shards_lift", x=16 * r(2))                                                              # the ring tips towards the front
    for i, n in enumerate(SHARD):            # raised, points out and down like lance heads; each jabs along its point in its turn
        dk = i % 4; j = max(-0.45, jab(i % 6, 1))
        f.shard(n, up=0.22 * r(dk) - 0.14 * j, fwd=0.32 * j, aimv=(0, -1, -0.45), w=0.8 * min(1.0, r(dk + 1)))
    return f.pose()

# ---------------------------------------------------------------- kneel (the Shattered Kneel): she falls, lies low and tilted with the core bared, and hauls herself up
KNEEL_STRIKE, KNEEL_RECOVER, KNEEL_END = 18, 108, 126
def kneel_pose(t):
    up = curve(t, [(0, 0), (4, 1), (9, 0)])                                                         # the catch of breath before the fall
    def d(dt=0):                                                                                   # the fall, the bounce, lying there, the haul up
        u = t - dt
        if u <= 18: return curve_in(u, [(5, 0), (18, 1.0)])
        return curve(u, [(18, 1.0), (23, 0.88), (30, 0.95), (104, 0.95), (119, -0.07), (126, 0)])
    low = curve(t, [(18, 0), (30, 1), (100, 1), (110, 0)])
    busy = curve(t, [(0, 0), (6, 1), (112, 1), (126, 0)])
    f = F(t, 1 - 0.8 * busy)
    shake = low * (0.6 * s(t / 5.0) + 0.4 * s(t / 3.1))                                              # trembling while she is down
    pant = low * s(t / 24.0)
    f.rot("body", x=-4 * up + 24 * d(), y=11 * d(1), z=-5 * d(1))
    f.rot("chest", x=-5 * up + 10 * d(2) - 8 * low + 2.5 * pant, y=5 * d(2) + 0.5 * shake)
    f.rot("neck", x=-3 * up + 10 * d(3))
    f.rot("head", x=-5 * up + 20 * d(5) + 2.0 * pant, y=7 * d(5), z=6 * d(4) + 0.8 * shake)
    f.lift(0.10 * up - 0.80 * d() + 0.008 * shake)
    f.loc("body", y=-0.10 * d(), x=0.06 * d(1))
    f.loc("core", y=-0.06 * low - 0.02 * max(0.0, pant))
    f.rot("halo", x=14 * d(4), y=14 * d(5), z=4 * d(4)); f.loc("halo", z=-0.12 * d(4), x=0.08 * d(5))
    f.rot("halo_ring", y=18 * d(5)); f.rot("halo_disc", x=10 * d(6), y=-6 * d(6))
    f.rot("crown.L", y=22 * d(6)); f.rot("crown.R", y=-10 * d(7)); f.loc("crown.L", z=-0.16 * d(6)); f.loc("crown.R", z=-0.06 * d(7))
    f.rag(WINGS, 8 * up - 6 * d(1) + 16 * low, 14 * d(3), 16 * d(4)); f.rag(FRONT, 8 * up + 18 * low, 12 * d(3), 14 * d(4))
    f.rag(BACK, 6 * up - 4 * d(1), 6 * d(3), 12 * d(4))                                           # the hem pools out on the floor
    f.ground(-0.80 * d(), 1)                                                                       # the spikes splay flat under her
    f.loc("shards_lift", z=-(0.10 * up - 0.80 * d()))                                              # the shards are not carried down: they fall on their own
    for i, n in enumerate(SHARD):            # they lose their hold and drop, hang low round her trembling, and lift back as she hauls up
        dk = 1 + i % 5
        f.shard(n, up=(FLOOR + 0.45 + 0.12 * (i % 3) - SZ[n]) * d(dk) + 0.012 * shake * (1 if i % 2 else -1),
                out=-0.15 * d(dk) * (1 if SR[n] > 1.3 else 0), aim=(0.4, 0, -1), w=0.5 * max(0.0, d(dk)))
    return f.pose()

# ---------------------------------------------------------------- the hand-off poses, shared with the other two bodies
CENTRE = (-AX.x, -AX.y)            # her axis moved over the root
def hunch(f, k):
    """The pose a body is handed over in (k = 1): folded forward 45 degrees at the chest, the hood bowed, sunk 15 % of
    her height, centred over the root, the cloak closed round her, the spikes drawn up, the halo low over the hood."""
    f.rot("body", x=17 * k); f.rot("chest", x=28 * k); f.rot("neck", x=14 * k); f.rot("head", x=26 * k)
    f.loc("body", x=CENTRE[0] * k, y=(CENTRE[1] + 0.30) * k, z=-0.47 * k)
    f.loc("shards_lift", z=-0.47 * k)
    f.loc("core", y=0.03 * k)
    f.rot("halo", x=-20 * k); f.loc("halo", y=0.10 * k, z=-0.22 * k)
    f.rot("crown.L", y=18 * k); f.rot("crown.R", y=-18 * k); f.loc("crown.L", x=-0.22 * k, z=-0.08 * k); f.loc("crown.R", x=0.22 * k, z=-0.08 * k)
    f.rot("halo_disc", x=14 * k); f.loc("halo_disc", y=-0.25 * k, z=-0.10 * k)
    f.rag(WINGS, -14 * k, -6 * k, 0, down=0.7 * k); f.rag(FRONT, -12 * k, -6 * k, 0, down=0.7 * k); f.rag(BACK, -8 * k, 0, 0, down=0.6 * k)
    f.ground(-0.47 * k, -1)

# ---------------------------------------------------------------- form: she unfolds out of the hunch the Colossus ended in
FORM_END = 30
def form_pose(t):
    def u(dt=0): return curve(t - dt, [(0, 0), (14, 1.07), (20, 0.98), (26, 1.0)])                  # the chest lifts
    hood = curve(t, [(11, 0), (25, 1.06), (30, 1.0)])                                              # the hood comes up last
    opn = curve(t, [(5, 0), (18, 1.0)])                                                            # the cloak falls open
    flare = curve(t, [(6, 0), (15, 1), (27, 0)])
    lit = curve(t, [(12, 0), (18, 1), (28, 0)])                                                    # the core lights: it pushes out
    f = F(t - FORM_END, smooth(t / 24.0))                                                          # it ends on the idle's first frame
    k = 1 - u()
    f.rot("body", x=17 * k); f.rot("chest", x=28 * (1 - u(1)) - 4 * flare); f.rot("neck", x=14 * (1 - hood)); f.rot("head", x=26 * (1 - hood))
    rise = curve(t, [(0, 0), (16, 1.10), (23, 0.98), (29, 1.0)])
    f.loc("body", x=CENTRE[0] * (1 - smooth(t / 20.0)), y=(CENTRE[1] + 0.30) * (1 - smooth(t / 20.0)), z=-0.47 * (1 - rise))
    f.loc("core", y=0.03 * (1 - opn) - 0.07 * lit)
    hk = 1 - curve(t, [(8, 0), (24, 1.05), (30, 1.0)])
    f.rot("halo", x=-20 * hk); f.loc("halo", y=0.10 * hk, z=-0.22 * hk)
    f.rot("crown.L", y=18 * hk); f.rot("crown.R", y=-18 * hk); f.loc("crown.L", x=-0.22 * hk, z=-0.08 * hk); f.loc("crown.R", x=0.22 * hk, z=-0.08 * hk)
    f.rot("halo_disc", x=14 * hk); f.loc("halo_disc", y=-0.25 * hk, z=-0.10 * hk)
    c_ = 1 - opn
    f.rag(WINGS, -14 * c_ + 20 * flare, -6 * c_ + 8 * flare, 0, down=0.7 * c_); f.rag(FRONT, -12 * c_ + 16 * flare, -6 * c_ + 6 * flare, 0, down=0.7 * c_)
    f.rag(BACK, -8 * c_ + 10 * flare, 0, 0, down=0.6 * c_)
    sp = 1 - curve(t, [(10, 0), (24, 1.0)])                                                        # the spikes drop out from under her
    f.ground(-0.47 * (1 - rise), -1); f.spikes(lift=8 * flare)
    for i, n in enumerate(SHARD):            # scattered on the floor round her (what the Colossus left); each lifts into the ring, the last as she is done
        p = curve(t, [(4 + 1.5 * i, 0), (15 + 1.5 * i, 1.06), (18 + 1.5 * i, 1.0)]); q_ = 1 - p
        f.shard(n, out=(1.25 + 0.3 * (i % 3) - SR[n]) * q_, up=(FLOOR + 0.12 - SZ[n]) * q_ + 0.25 * math.sin(math.pi * min(1.0, p)),
                side=0.3 * (1 if i % 2 else -1) * q_, aim=(0, 1 if i % 2 else -1, 0), w=min(1.0, q_))
    return f.pose()

# ---------------------------------------------------------------- break: she comes apart to her core: the rags fold in, she curls forward and down
BREAK_END = 45
def break_pose(t):
    rec = curve(t, [(0, 0), (6, 1), (13, 0)])                                                      # the recoil before she goes
    def d(dt=0): return curve(t - dt, [(7, 0), (34, 1.04), (40, 1.0)])                             # the curl
    fall = curve_in(t, [(8, 0), (33, 1.0)]) + curve(t, [(33, 0), (36, 0.03), (41, 0)])             # the sink: slow, then all at once
    fold = curve(t, [(5, 0), (27, 1.0)])
    f = F(t, 1 - smooth(t / 10.0))
    f.rot("body", x=-4 * rec + 30 * d()); f.rot("chest", x=-7 * rec + 50 * d(1)); f.rot("neck", x=-4 * rec + 20 * d(3))
    f.rot("head", x=-8 * rec + 30 * d(5), y=4 * d(5))
    f.loc("body", x=CENTRE[0] * d(), y=(CENTRE[1] + 0.22) * d(), z=0.07 * rec - 0.74 * fall)
    f.loc("shards_lift", z=0.07 * rec)                                                             # the shards are not taken down with her
    f.loc("core", y=-0.04 * rec + 0.04 * d(2))
    f.rot("halo", x=-8 * rec - 48 * d(4)); f.loc("halo", y=0.30 * d(4), z=0.05 * rec - 0.50 * d(4))
    f.rot("halo_ring", x=-20 * d(6)); f.loc("halo_ring", z=-0.10 * d(6))
    f.rot("crown.L", y=40 * d(5)); f.rot("crown.R", y=-40 * d(6)); f.loc("crown.L", x=-0.45 * d(5), z=-0.20 * d(5)); f.loc("crown.R", x=0.45 * d(6), z=-0.20 * d(6))
    f.rot("halo_disc", x=30 * d(6)); f.loc("halo_disc", y=-0.40 * d(6), z=-0.20 * d(6))
    f.rag(WINGS, 12 * rec - 22 * fold, -10 * fold, -4 * fold, down=0.85 * fold); f.rag(FRONT, 10 * rec - 18 * fold, -8 * fold, 0, down=0.85 * fold)
    f.rag(BACK, 8 * rec - 6 * fold, -10 * fold, -22 * fold, down=0.3 * fold)                                         # the back of the cloak lies over her
    f.spikes(lift=6 * rec, inward=0.3 * fold); f.ground(-0.74 * fall, -1)                           # the spikes fold in under her
    for i, n in enumerate(SHARD):            # they fall in and down onto the heap with her, landing among the rags on the last frames
        land = 36 + 0.9 * i
        p = curve_in(t, [(10 + i, 0), (land, 1.0)]); hop = curve(t, [(land, 0), (land + 1.5, 1), (land + 4, 0)])
        f.shard(n, out=0.08 * rec + (0.75 + 0.12 * (i % 3) - SR[n]) * p, up=(FLOOR + 0.35 + 0.25 * ((i + 1) % 3) - SZ[n]) * p + 0.04 * hop,
                aim=(0.8, 0.3 if i % 2 else -0.3, -0.6), w=p)
    return f.pose()

CLIPS = {
    "idle": lambda: bake("idle", idle_pose, LONG, Air(period=IDLE, life=1.0), loop=True),
    "walk": lambda: bake("walk", walk_pose, LONG, GlideAir(drag=(0, 0.24, 0.05)), loop=True),
    "open": lambda: bake("open", open_pose, OPEN_END, Air(period=IDLE, life=1.4), spin=whirl(OPEN_END, 1)),
    "cast": lambda: bake("cast", cast_pose, CAST_END, Air(period=IDLE, life=1.0), spin=whirl(CAST_END, 1)),
    "flick": lambda: bake("flick", flick_pose, FLICK_END, Air(period=IDLE, life=1.0), spin=lambda f: 0.0),
    "lances": lambda: bake("lances", lances_pose, LANCE_END, Air(period=IDLE, life=1.0), spin=whirl(LANCE_END, 1)),
    "kneel": lambda: bake("kneel", kneel_pose, KNEEL_END, Air(period=IDLE, life=0.6), spin=whirl(KNEEL_END, 1)),
    "form": lambda: bake("form", form_pose, FORM_END, Air(period=IDLE, life=0.5, walls=lambda t: smooth((t - 8) / 14.0)), spin=lambda f: SPIN_RATE * (f - FORM_END)),
    "break": lambda: bake("break", break_pose, BREAK_END, Air(period=IDLE, life=0.5, walls=lambda t: 1 - smooth(t / 12.0), keep=("back",)), spin=lambda f: SPIN_RATE * (f - (f * f) / (2.0 * BREAK_END))),
}
for name, fn in CLIPS.items(): fn()

rig.animation_data.action = None
for pb in rig.pose.bones: pb.matrix_basis.identity()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
zdlib.emit({"actions": {a.name: [round(x) for x in a.frame_range] for a in bpy.data.actions}, "loop_seam_degrees": SEAM,
            "game_bones_not_keyed": sorted(GAME), "largest_shard_offset_m": MAXOFF, "turns": TURNS, "spin_signs": SPIN})
