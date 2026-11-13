"""rig.blend -> anim.blend: the Clockwork Judge's actions, each also stashed on an NLA track.

Every clip is a function from time to a flat table of numbers (lean, turn, arm angles, foot offsets...), and
figure() turns that table into a pose. The table is what gets blended (an attack eases out of and back into the idle
stance), and what a later joint reads a little later than the one above it.

The machine's own rules, kept by figure():
  - a leg has a hip and an ankle and no knee: the foot is placed, the leg points at it and its rods telescope;
  - an elbow is a hinge: the upper arm is turned at the shoulder's ball so the hinge's pin is square to both halves of
    the arm, and the forearm only swings about that pin;
  - a gavel hangs on a ring at the wrist: it can sag towards the ground under its own weight."""
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
def clamp(t, a=0.0, b=1.0): return max(a, min(b, t))
def smooth(t): t = clamp(t); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def ramp(t, f0, f1): return clamp((t - f0) / (f1 - f0))
def curve(t, keys):
    """Eased interpolation through (frame, value) keys."""
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def ring(t, t0, period, decay):
    """A stop that rings: a fading swing that starts at t0."""
    return math.exp(-(t - t0) / decay) * math.sin(TAU * (t - t0) / period) if t > t0 else 0.0
def settle(x):
    """One tick's jolt over 0..1: a quick drop and two fading rebounds."""
    x %= 1.0; return math.exp(-5 * x) * math.sin(TAU * 2 * x)
def ratchet(x):
    """A part ticking into place over 0..1: there in a tenth of the time, a little past, then still."""
    x = clamp(x); return 1 - math.exp(-9 * x) * math.cos(TAU * 2.2 * x)

SIDES = (("L", ".L", 1), ("R", ".R", -1))
def head_of(n): return P.rest[n].translation.copy()
def dir_of(n): return P.rest[n].to_3x3().col[1].normalized()
def flat(v): return Vector((0, v.y, v.z)).normalized()
ANK = {sd: head_of("foot" + sfx) for sd, sfx, _ in SIDES}
LEG = {sd: (head_of("foot" + sfx) - head_of("thigh" + sfx)).length for sd, sfx, _ in SIDES}
# The arm, read in the plane its elbow swings in (the model's arms also lean a little outwards; that stays built in).
U0 = flat(dir_of("upper_arm.L")); G0 = {sd: dir_of("gavel" + sfx) for sd, sfx, _ in SIDES}
_tip = head_of("gavel.L") + dir_of("gavel.L") * P.len["gavel.L"]
F0 = flat(_tip - head_of("forearm.L"))                 # the elbow to the gavel's point
LU = (Vector((0, 1, 1)) * (head_of("forearm.L") - head_of("upper_arm.L"))).length
LL = (Vector((0, 1, 1)) * (_tip - head_of("forearm.L"))).length
def fwd_of(v): return math.degrees(math.atan2(-v.y, -v.z))
RU, RF = fwd_of(U0), fwd_of(F0)
SOLE = (Vector((0, -0.44, -0.38)), Vector((0, 0.49, -0.38)))      # the sole's front and back edge, from the ankle

def d(fwd, out, sgn):
    """A direction: straight down swung forward by fwd degrees (180 is straight up), then outwards by out."""
    f = math.radians(fwd); o = math.radians(out)
    return Vector((sgn * math.sin(o), -math.sin(f) * math.cos(o), -math.cos(f) * math.cos(o)))

KEYS = ["bx", "by", "bz", "bp", "br", "byw", "cp", "cr", "cyw", "hp", "hr", "hyw", "pend", "gear", "apx", "apy"]
SIDE_KEYS = ["uf", "uo", "ff", "fo", "wf", "ws", "wt", "hang", "iku", "ikf", "tx", "ty", "tz",
             "fx", "fy", "fz", "fp", "fyw", "pax", "pay", "paz", "finx", "finy", "t1x", "t1y", "t2x", "t2y"]
def base():
    p = {k: 0.0 for k in KEYS}
    for sd, _, _ in SIDES:
        for k in SIDE_KEYS: p[sd + k] = 0.0
        p[sd + "uf"] = RU; p[sd + "ff"] = RF
    return p
def mix(a, b, t):
    out = {k: lerp(a[k], b[k], t) for k in a}
    out["gear"] = b["gear"]            # a gear's turn is never blended away: it ends on a whole turn by itself
    return out

MISS = {}; SHO = {}
def frame3(a, u):
    a = (a - u * a.dot(u)).normalized()
    return Matrix((a, u, a.cross(u))).transposed()

def figure(p, clip=""):
    pose = {}
    Qb = qe(p["bp"], p["br"], p["byw"]); Qc = qe(p["cp"], p["cr"], p["cyw"]) @ Qb
    pose["body"] = {"loc": (p["bx"], p["by"], p["bz"]), "rot": Qb}
    pose["chest"] = {"rot": qe(p["cp"], p["cr"], p["cyw"])}
    pose["head"] = {"rot": qe(p["hp"], p["hr"], p["hyw"])}
    pose["pendulum"] = {"rot": Quaternion(Qc @ Y, math.radians(p["pend"]))}
    pose["gear"] = {"rot": Quaternion(Qb @ Y, math.radians(p["gear"]))}
    pose["apron"] = {"rot": qe(x=p["apx"], y=p["apy"])}
    for sd, sfx, sg in SIDES:
        pose["pauldron" + sfx] = {"rot": qe(p[sd + "pax"], p[sd + "pay"], p[sd + "paz"])}
        pose["fin" + sfx] = {"rot": qe(x=p[sd + "finx"], y=p[sd + "finy"])}
        pose["tail1" + sfx] = {"rot": qe(x=p[sd + "t1x"], y=p[sd + "t1y"])}
        pose["tail2" + sfx] = {"rot": qe(x=p[sd + "t2x"], y=p[sd + "t2y"])}
    world, _ = P.solve(pose)
    for sd, sfx, sg in SIDES:
        # The leg: the foot is placed (lifted just enough that a pitched sole stays on the ground), the leg points
        # at the ankle and the shin slides to reach it.
        qf = qe(x=p[sd + "fp"], z=p[sd + "fyw"])
        low = min((qf @ v).z for v in SOLE)
        ankle = ANK[sd] + Vector((p[sd + "fx"], p[sd + "fy"], p[sd + "fz"] - (low + 0.38)))
        dv = ankle - world["thigh" + sfx].translation
        pose["thigh" + sfx] = {"aim": dv}
        pose["shin" + sfx] = {"loc": dv.normalized() * (dv.length - LEG[sd])}
        pose["foot" + sfx] = {"abs": qf}
        # The arm.
        uf, uo, ff, fo = p[sd + "uf"], p[sd + "uo"], p[sd + "ff"], p[sd + "fo"]
        if p[sd + "iku"] > 0 or p[sd + "ikf"] > 0:      # reach for a point with the gavel's tip
            S = world["upper_arm" + sfx].translation; T = Vector((p[sd + "tx"], p[sd + "ty"], p[sd + "tz"]))
            dv = T - S; reach = (LU + LL) * 0.985
            if min(p[sd + "iku"], p[sd + "ikf"]) > 0.999:
                MISS[clip] = max(MISS.get(clip, -9.0), dv.length - reach); SHO.setdefault(clip + sd, [round(x, 2) for x in S])
            dist = min(dv.length, reach); n = dv.normalized()
            a_ = (LU * LU - LL * LL + dist * dist) / (2 * dist); hh = math.sqrt(max(LU * LU - a_ * a_, 0.0))
            pole = Vector((sg * 0.25, 1.0, 0.3)); pole = (pole - n * pole.dot(n)).normalized()
            E = S + n * a_ + pole * hh
            u_ = (E - S).normalized(); f_ = (S + n * dist - E).normalized()
            uf = lerp(uf, fwd_of(u_), p[sd + "iku"]); uo = lerp(uo, math.degrees(math.asin(clamp(sg * u_.x, -1, 1))), p[sd + "iku"])
            ff = lerp(ff, fwd_of(f_), p[sd + "ikf"]); fo = lerp(fo, math.degrees(math.asin(clamp(sg * f_.x, -1, 1))), p[sd + "ikf"])
        u = d(uf, uo, sg); f = d(ff, fo, sg)
        a = -(u.cross(f))
        if a.length < 0.1: a = a + (U0.rotation_difference(u) @ X) * (0.1 - a.length)
        a.normalize()
        Qu = (frame3(a, u) @ frame3(X, U0).transposed()).to_quaternion()
        fc = Qu @ F0; fcp = (fc - a * fc.dot(a)).normalized(); fp = (f - a * f.dot(a)).normalized()
        Qf = Quaternion(a, math.atan2(a.dot(fcp.cross(fp)), fcp.dot(fp))) @ Qu
        Qg = Qf; h = Qf @ G0[sd]
        if p[sd + "hang"] > 0:
            ax, an = h.rotation_difference(Vector((0, 0, -1))).to_axis_angle()
            Qg = Quaternion(ax, min(an * p[sd + "hang"], math.radians(125))) @ Qg; h = Qg @ G0[sd]
        side = a.cross(h).normalized()
        Qw = Quaternion(a, -math.radians(p[sd + "wf"])) @ Quaternion(side, math.radians(p[sd + "ws"]))
        Qg = Quaternion(Qw @ h, math.radians(p[sd + "wt"])) @ Qw @ Qg
        pose["upper_arm" + sfx] = {"abs": Qu}
        pose["forearm" + sfx] = {"abs": Qf}
        pose["gavel" + sfx] = {"abs": Qg}
    return pose

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True
def record(name, fn, end, loop):
    act = poser.new_action(rig, name); P.prevq.clear()
    for f in range(end + 1):
        P.key(figure(fn(float(f)), name), f)
    act.frame_range = (0, end); act.use_frame_range = True; act.use_cyclic = loop
    stash(act)

# ---------------------------------------------------------------- idle
IDLE_N = 96            # four ticks, 0.8 s apart; the arms swing once, the chest's pendulum twice
LOOKS = (0, 11, 0, -11)
def idle_p(ph):
    p = base()
    tk = lambda late=0.0: settle(ph * 4 - late)
    p["bz"] = -0.006 - 0.012 * tk(); p["bx"] = 0.012 * s(ph); p["br"] = 0.7 * s(ph); p["bp"] = 0.4 * tk(0.03)
    p["cyw"] = 1.5 * s(ph - 0.06); p["cp"] = 0.6 * tk(0.06); p["cr"] = -0.5 * s(ph - 0.05)
    x = ph * 4 - 0.10; k = math.floor(x)
    p["hyw"] = lerp(LOOKS[k % 4], LOOKS[(k + 1) % 4], ratchet(x - k)); p["hp"] = 0.9 * tk(0.12)
    p["pend"] = 5.0 * c(2 * ph)
    k = math.floor(ph * 4 + 1e-6); p["gear"] = 90.0 * (k + ratchet(ph * 4 - k))
    for sd, sfx, sg in SIDES:
        q = ph + (0.0 if sd == "L" else 0.5)
        p[sd + "uf"] = RU + 5 * s(q); p[sd + "ff"] = RF + 8 * s(q - 0.06)
        p[sd + "wf"] = 4 * s(q - 0.15) + 1.2 * tk(0.10)
        p[sd + "pay"] = -sg * 0.8 * tk(0.06)
        p[sd + "finx"] = 1.5 * s(ph - 0.2) + 0.8 * tk(0.12); p[sd + "finy"] = sg * 0.5 * s(ph - 0.25)
        p[sd + "t1x"] = 1.0 * s(ph - 0.2 - 0.03 * sg) + 0.6 * tk(0.10); p[sd + "t1y"] = 0.8 * s(ph - 0.25)
        p[sd + "t2x"] = 1.6 * s(ph - 0.3 - 0.03 * sg) + 1.0 * tk(0.18); p[sd + "t2y"] = 1.0 * s(ph - 0.33)
    p["apx"] = 0.8 * s(ph - 0.1) + 0.8 * tk(0.10)
    return p
record("idle", lambda f: idle_p(f / IDLE_N), IDLE_N, True)
IDLE0 = idle_p(0.0)

# ---------------------------------------------------------------- walk
WALK_N = 28            # two steps
STANCE = 0.60          # share of the cycle a foot is on the ground
STEP = 0.36            # a planted foot travels +-STEP under the hip: the cycle covers 2*STEP/STANCE = 1.2 m
MID = -0.09            # where that travel is centred, from the foot's place at rest (the ankle rests behind the hip)
def foot_path(q):
    """Phase 0 = the foot lands. Returns (offset back, lift, pitch: + is heel up)."""
    q %= 1.0
    if q < STANCE:
        u = q / STANCE
        return MID + lerp(-STEP, STEP, u), 0.0, 13 * smooth((u - 0.74) / 0.26)
    v = (q - STANCE) / (1 - STANCE)
    y = MID + lerp(STEP, -STEP, smooth(v) * 0.6 + v * 0.4)
    return y, 0.12 * (1 - (2 * v - 1) ** 4), lerp(13, -3, smooth(v * 1.5)) * (1 - smooth((v - 0.8) / 0.2))
def walk_p(ph):
    p = base()
    hit = lambda late=0.0: (lambda x: math.exp(-4 * x) * math.sin(TAU * 1.5 * x))((2 * ph - late) % 1.0)   # each footfall
    for sd, sfx, sg in SIDES:
        y, lift, pitch = foot_path(ph + (0.0 if sd == "R" else 0.5))
        p[sd + "fy"] = y; p[sd + "fz"] = lift; p[sd + "fp"] = pitch; p[sd + "fx"] = -sg * 0.03
    p["bz"] = -0.045 - 0.022 * hit(); p["bx"] = -0.05 * s(ph + 0.10); p["br"] = -2.2 * s(ph + 0.08)
    p["byw"] = 5 * c(ph); p["bp"] = 2.0 + 1.0 * hit(0.02)
    p["cyw"] = -8 * c(ph - 0.04); p["cp"] = 1.0 + 1.3 * hit(0.07); p["cr"] = 1.2 * s(ph + 0.04)
    p["hyw"] = -0.8 * (p["byw"] + p["cyw"]); p["hp"] = -2.0 + 1.6 * hit(0.13); p["hr"] = 1.0 * s(ph)
    p["pend"] = 6 * c(ph - 0.05)
    k = math.floor(ph * 4 + 1e-6); p["gear"] = 90.0 * (k + ratchet(ph * 4 - k))
    for sd, sfx, sg in SIDES:
        q = ph + (0.0 if sd == "L" else 0.5)         # the left arm comes forward with the right foot
        p[sd + "uf"] = RU + 11 * c(q - 0.03); p[sd + "ff"] = RF + 4 + 15 * c(q - 0.10)
        p[sd + "wf"] = 7 * c(q - 0.20) + 1.5 * hit(0.1); p[sd + "uo"] = 2.0
        p[sd + "pay"] = -sg * 1.2 * hit(0.08); p[sd + "pax"] = -1.5 * c(q - 0.05)
        p[sd + "finx"] = 2.0 + 2.5 * hit(0.15) + 1.5 * c(q - 0.2); p[sd + "finy"] = 1.5 * s(ph - 0.1)
        back = max(0.0, foot_path(ph + (0.0 if sd == "R" else 0.5) - 0.05)[0] - MID) / STEP     # this side's leg is behind
        p[sd + "t1x"] = 2.5 + 7 * back + 2.0 * hit(0.12); p[sd + "t2x"] = 2.0 + 5 * back + 3.5 * hit(0.22)
        p[sd + "t1y"] = 1.5 * s(ph - 0.12); p[sd + "t2y"] = 2.5 * s(ph - 0.22)
    p["apx"] = -2.0 - 2.5 * hit(0.12)
    return p
record("walk", lambda f: walk_p(f / WALK_N), WALK_N, True)

# ---------------------------------------------------------------- attacks
def attack(prim, end, t):
    """An attack's table: eased out of the idle stance and back into it, with the hanging pieces trailing the body."""
    p = prim(t)
    lean = lambda tt: (lambda q: q["bp"] + q["cp"])(prim(tt)); turn = lambda tt: (lambda q: q["byw"] + q["cyw"])(prim(tt))
    drop = lambda tt: prim(tt)["bz"]
    for sd, sfx, sg in SIDES:
        p[sd + "finx"] += -0.9 * max(p["bp"] + p["cp"], -4.0) + 0.25 * (lean(t) - lean(t - 3)) + 60 * (drop(t - 2) - drop(t - 4))
        p[sd + "finy"] += 0.25 * (turn(t - 3) - turn(t)) * sg
        p[sd + "t1x"] += -0.9 * max(p["bp"], 0.0) + 0.25 * (lean(t) - lean(t - 3)) + 25 * (drop(t - 2) - drop(t - 4))
        p[sd + "t2x"] += 0.3 * (lean(t - 2) - lean(t - 6)) + 25 * (drop(t - 4) - drop(t - 7))
        p[sd + "t1y"] += 0.2 * (turn(t - 3) - turn(t)); p[sd + "t2y"] += 0.3 * (turn(t - 6) - turn(t - 2))
    p["apx"] += -0.6 * max(p["bp"], 0.0) - 0.4 * (lean(t) - lean(t - 3)) - 50 * (drop(t - 2) - drop(t - 4))
    w = min(smooth(ramp(t, 0, 3)), 1 - smooth(ramp(t, end - 9, end)))
    return mix(IDLE0, p, w)

# Where a raised gavel sits: the upper arm forward and up, the elbow folded, the gavel above and behind the shoulder.
UP_UF, UP_FF, UP_UO, UP_FO = 116.0, 198.0, 12.0, 5.0

# The gavel strike (the Verdict): the right gavel hauled up over the shoulder in three ratchet notches, held aloft,
# then driven down point first onto the ground ahead; the body drops onto it and rings.
STRIKE_END = 80; STRIKE_HIT = 45
def strike_p(t):
    p = base()
    a = lambda dt=0: curve(t - dt, [(0, 0), (6, 1), (12, 0)])
    haul = lambda dt=0: curve(t - dt, [(5, 0), (12, 0.42), (14, 0.39), (20, 0.76), (22, 0.73), (29, 1.0)]) * (1 - smooth(ramp(t - dt, 41, 45)))
    coil = lambda dt=0: curve(t - dt, [(31, 0), (40, 1)]) * (1 - smooth(ramp(t - dt, 42, 45)))
    hit = lambda dt=0: smooth(ramp(t - dt, 42, 45)) * (1 - smooth(ramp(t - dt, 58, 76)))
    rg = lambda dt=0: ring(t - dt, 45, 7.0, 5.0)
    wound = curve(t, [(5, 0), (12, 0.42), (14, 0.39), (20, 0.76), (22, 0.73), (29, 1.0)])
    p["bz"] = -0.05 * a() + 0.03 * haul() - 0.19 * hit() + 0.03 * rg(); p["by"] = 0.04 * haul() + 0.06 * hit()
    p["bp"] = 2 * a() - 3 * haul() - 2 * coil() + 16 * hit() - 1.2 * rg(1); p["byw"] = 2 * a() - 6 * haul() + 8 * hit()
    p["br"] = 2 * haul() - 3 * hit()
    p["cp"] = 2 * a(1) - 5 * haul(1) - 3 * coil(1) + 25 * hit(0.5) - 2.0 * rg(2)
    p["cyw"] = 3 * a(1) - 12 * haul(1) - 3 * coil(1) + 20 * hit(0.5); p["cr"] = 3 * haul(1) - 5 * hit(0.5)
    p["hyw"] = -0.75 * (p["byw"] + p["cyw"]); p["hp"] = -6 * haul(2) - 0.45 * (16 * hit(1) + 25 * hit(1.5)) + 3 * rg(3)
    p["pend"] = 0.4 * (p["cyw"]) * 0 + 5 * rg(1) + 3 * math.sin(t * 0.9) * coil()
    p["gear"] = 360 * wound - 360 * smooth(ramp(t, 41, 49))                # wound up notch by notch, let go at once
    # The right arm.
    k_u = ramp(t, 41, 45) ** 1.6; k_f = ramp(t, 41.6, 45) ** 1.6
    let = 1 - smooth(ramp(t, 58, 68))
    p["Ruf"] = RU - 14 * a() + (UP_UF - RU) * haul() + 5 * coil(); p["Ruo"] = UP_UO * haul() + 3 * a()
    p["Rff"] = RF - 10 * a(1) + (UP_FF - RF) * haul(2) + 7 * coil(1) - 7 * ring(t, 66, 16.0, 7.0); p["Rfo"] = UP_FO * haul(2) + 14 * math.sin(math.pi * ramp(t, 40, 45))
    p["Riku"] = k_u * let; p["Rikf"] = k_f * smooth(let)
    p["Rtx"] = -0.62; p["Rty"] = -1.12; p["Rtz"] = 0.0
    p["Rwf"] = -30 * (haul() - haul(3)) - 16 * math.sin(math.pi * ramp(t, 41, 45)) + 1.5 * math.sin(t * 2.3) * coil() + 2 * rg()
    p["Rpax"] = -6 * haul(1) - 2 * coil() + 3 * hit(); p["Rpay"] = 3 * haul(1)
    # The left arm balances: forward and in as the body winds, thrown back as it strikes.
    p["Luf"] = RU + 10 * haul(1) - 26 * hit(0.5) + 6 * ring(t, 60, 18.0, 8.0); p["Luo"] = 4 * haul() + 9 * hit(0.5)
    p["Lff"] = RF + 16 * haul(2) - 18 * hit(1.5) + 9 * ring(t, 61, 18.0, 8.0); p["Lfo"] = 3 * haul() + 6 * hit(1)
    p["Lwf"] = 8 * (haul(2) - haul(5)) - 10 * (hit(1.5) - hit(4)); p["Lpay"] = -2 * hit()
    return p
record("gavel_strike", lambda f: attack(strike_p, STRIKE_END, f), STRIKE_END, False)

# The double slam (the Gavel Slam): both gavels up in two notches, then both driven down together beside the feet.
SLAM_END = 62; SLAM_HIT = 25
def slam_p(t):
    p = base()
    a = lambda dt=0: curve(t - dt, [(0, 0), (5, 1), (10, 0)])
    haul = lambda dt=0: curve(t - dt, [(4, 0), (10, 0.55), (11.5, 0.52), (18, 1.0)]) * (1 - smooth(ramp(t - dt, 21, 25)))
    coil = lambda dt=0: curve(t - dt, [(17, 0), (21, 1)]) * (1 - smooth(ramp(t - dt, 22, 25)))
    hit = lambda dt=0: smooth(ramp(t - dt, 22, 25)) * (1 - smooth(ramp(t - dt, 40, 58)))
    rg = lambda dt=0: ring(t - dt, 25, 7.0, 5.0)
    wound = curve(t, [(4, 0), (10, 0.55), (11.5, 0.52), (18, 1.0)])
    p["bz"] = -0.05 * a() + 0.04 * haul() - 0.19 * hit() + 0.035 * rg(); p["by"] = 0.05 * haul() + 0.08 * hit()
    p["bp"] = 2 * a() - 4 * haul() - 1.5 * coil() + 18 * hit() - 1.5 * rg(1)
    p["cp"] = 3 * a(1) - 7 * haul(1) - 3 * coil(1) + 26 * hit(0.5) - 2.5 * rg(2)
    p["hp"] = -9 * haul(2) - 3 * coil() - 20 * hit(1) + 4 * rg(3)
    p["pend"] = 6 * rg(1); p["gear"] = 360 * wound - 360 * smooth(ramp(t, 21, 29))
    let = 1 - smooth(ramp(t, 40, 50))
    for sd, sfx, sg in SIDES:
        late = 0.0 if sd == "R" else 0.6                 # the left arm a touch behind the right on the way up
        p[sd + "uf"] = RU - 14 * a(late) + (UP_UF - RU) * haul(late) + 5 * coil(); p[sd + "uo"] = UP_UO * haul(late) + 3 * a()
        p[sd + "ff"] = RF - 10 * a(1 + late) + (UP_FF - RF) * haul(2 + late) + 7 * coil(1) - 7 * ring(t, 48, 16.0, 7.0)
        p[sd + "fo"] = UP_FO * haul(2 + late)
        p[sd + "iku"] = (ramp(t, 21, 25) ** 1.6) * let; p[sd + "ikf"] = (ramp(t, 21.6, 25) ** 1.6) * smooth(let)
        p[sd + "tx"] = sg * 0.80; p[sd + "ty"] = -0.84; p[sd + "tz"] = 0.0
        p[sd + "wf"] = -30 * (haul(late) - haul(3 + late)) - 16 * math.sin(math.pi * ramp(t, 21, 25)) + 2 * rg()
        p[sd + "pax"] = -6 * haul(1 + late) - 2 * coil() + 3 * hit(); p[sd + "pay"] = sg * 3 * haul(1 + late)
    return p
record("double_slam", lambda f: attack(slam_p, SLAM_END, f), SLAM_END, False)

# The spread (the echo): it draws in, then throws both arms wide and leans back, the clock presented, the gavels
# hanging from the wrists and swaying while the gear races.
SPREAD_END = 84; SPREAD_HIT = 24; SPREAD_HOLD = 54
def spread_p(t):
    p = base()
    a = lambda dt=0: curve(t - dt, [(0, 0), (6, 1), (12, 0)])
    op = lambda dt=0: curve(t - dt, [(6, 0), (19, 1.07), (24, 0.97), (29, 1.0)]) * (1 - smooth(ramp(t - dt, 54, 76)))
    hold = curve(t, [(20, 0), (28, 1), (54, 1), (62, 0)])
    rg = lambda dt=0: ring(t - dt, 19, 9.0, 7.0)
    p["bz"] = -0.05 * a() + 0.03 * op(); p["by"] = 0.05 * op(); p["bp"] = 3 * a() - 4 * op()
    p["cp"] = 4 * a(1) - 9 * op(1) + 1.2 * rg(1); p["hp"] = 3 * a(2) - 11 * op(2) + 2 * rg(3)
    p["bx"] = 0.004 * math.sin(t * 2.1) * hold
    p["pend"] = 9 * math.sin(TAU * t / 9.0) * curve(t, [(6, 0), (20, 1), (60, 1), (78, 0)])
    p["gear"] = 1080 * (lambda x: x * x * x * (x * (6 * x - 15) + 10))(ramp(t, 5, 78))
    # Held out like the two pans of a balance: the arms level, the gavels hanging straight down from the wrists, and
    # the whole beam tipping slowly one way and then the other.
    tip = lambda dt=0: math.sin(TAU * (t - dt - 24) / 30.0) * curve(t - dt, [(22, 0), (30, 1), (52, 1), (60, 0)])
    p["cr"] = -3.0 * tip(); p["hr"] = 2.0 * tip(2); p["br"] = -0.8 * tip()
    for sd, sfx, sg in SIDES:
        late = 0.0 if sd == "R" else 1.0
        o = lambda dt=0: op(dt + late)
        p[sd + "uf"] = RU + 12 * a(late) + (8 - RU) * o(); p[sd + "uo"] = -4 * a(late) + 78 * o() + sg * 5 * tip(1)
        p[sd + "ff"] = RF + 22 * a(1 + late) + (0 - RF) * o(2); p[sd + "fo"] = -3 * a(late) + 100 * o(2) + sg * 8 * tip(2)
        p[sd + "hang"] = smooth(o(1) * 1.3)
        p[sd + "wf"] = 8 * rg(3 + late) + 3 * math.sin(TAU * (t - late * 3) / 26.0) * hold
        p[sd + "ws"] = -12 * (o(1) - o(5)) + 5 * rg(4 + late) - sg * 5 * (tip(3) - tip(7))
        p[sd + "pay"] = -sg * (6 * o(1) + 1.2 * rg(2)); p[sd + "pax"] = -2 * o(1)
    return p
record("spread", lambda f: attack(spread_p, SPREAD_END, f), SPREAD_END, False)

# The brace (the Gear Spiral): a small rise, then it drops into a crouch, chest forward, the arms half out to the
# sides and ahead; it shakes as the gear runs away and the hanging gavels circle.
BRACE_END = 76; BRACE_HIT = 23; BRACE_HOLD = 50
def brace_p(t):
    p = base()
    a = lambda dt=0: curve(t - dt, [(0, 0), (5, 1), (10, 0)])
    dn = lambda dt=0: curve(t - dt, [(5, 0), (15, 1.08), (19, 0.97), (23, 1.0)]) * (1 - smooth(ramp(t - dt, 50, 70)))
    hold = curve(t, [(15, 0), (22, 1), (50, 1), (58, 0)])
    rg = lambda dt=0: ring(t - dt, 15, 8.0, 6.0)
    shake = math.sin(TAU * t / 3.0) * hold
    p["bz"] = 0.03 * a() - 0.16 * dn() + 0.02 * rg() + 0.004 * shake; p["by"] = -0.04 * dn(); p["bx"] = 0.006 * math.sin(TAU * t / 3.7) * hold
    p["bp"] = -2 * a() + 5 * dn(); p["cp"] = -3 * a(1) + 13 * dn(1) + 1.5 * rg(1); p["cr"] = 0.5 * shake
    p["hp"] = -12 * dn(2) + 2 * rg(3); p["hyw"] = 1.2 * math.sin(TAU * t / 3.3) * hold
    p["pend"] = 10 * math.sin(TAU * t / 7.0) * curve(t, [(5, 0), (18, 1), (54, 1), (70, 0)])
    p["gear"] = 1440 * (lambda x: x * x * x * (x * (6 * x - 15) + 10))(ramp(t, 4, 72))
    for sd, sfx, sg in SIDES:
        late = 0.0 if sd == "L" else 0.8
        dd = lambda dt=0: dn(dt + late)
        p[sd + "uf"] = RU - 8 * a(late) + (32 - RU) * dd(); p[sd + "uo"] = 3 * a(late) + 30 * dd()
        p[sd + "ff"] = RF - 4 * a(1 + late) + (76 - RF) * dd(2); p[sd + "fo"] = 36 * dd(2)
        p[sd + "hang"] = 0.8 * smooth(dd(1))
        turn = TAU * t / 14.0 + (0.0 if sd == "L" else math.pi)
        p[sd + "wf"] = 6 * rg(3 + late) + 9 * math.cos(turn) * hold; p[sd + "ws"] = 9 * math.sin(turn) * hold
        p[sd + "pay"] = -sg * (6 * dd(1) + 0.6 * shake); p[sd + "pax"] = 2 * dd(1)
    return p
record("brace", lambda f: attack(brace_p, BRACE_END, f), BRACE_END, False)

sc.frame_start = 0; sc.frame_end = IDLE_N
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
zdlib.emit({"actions": {a_.name: list(a_.frame_range) for a_ in bpy.data.actions}, "rest_arm_angles": [round(RU, 1), round(RF, 1)],
            "arm_lengths": [round(LU, 3), round(LL, 3)], "reach_short_by_m": {k: round(v, 3) for k, v in MISS.items()}, "shoulder_at_hit": SHO})
