"""rig.blend -> anim.blend: the Tidecaller's actions, each also stashed on an NLA track.

Every clip is a function from time to a pose of the driven bones (body, legs, arms, the staff by where its foot and
its top are). Everything that hangs (the bell, its clapper, the tassels, the sleeves, the pendant, the robe) is then
swung by a small simulation over the keyed frames: each link is a weight on a fixed length that is pulled back to
where it hangs at rest, so it starts late, passes its mark and settles by itself.
"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, poser
from poser import *
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
rig = bpy.data.objects["Rig"]; P = Poser(rig)
mesh = [o for o in bpy.data.objects if o.type == 'MESH'][0]
sc = bpy.context.scene; sc.render.fps = 30
ONLY = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
TAU = math.tau
def c(ph): return math.cos(TAU * ph)
def s(ph): return math.sin(TAU * ph)
def smooth(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def ramp(t, f0, f1): return max(0.0, min(1.0, (t - f0) / (f1 - f0)))
def sr(t, f0, f1): return smooth(ramp(t, f0, f1))
def curve(t, keys):
    if t <= keys[0][0]: return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if t <= f1: return lerp(v0, v1, smooth((t - f0) / (f1 - f0)))
    return keys[-1][1]
def bez(p0, p1, p2, u):
    return (1 - u) * (1 - u) * Vector(p0) + 2 * u * (1 - u) * Vector(p1) + u * u * Vector(p2)
def V(*a): return Vector(a)
def rest_dir(n): return P.rest[n].to_3x3().col[1].normalized()
def rest_head(n): return P.rest[n].translation.copy()
def rest_tail(n): return rest_head(n) + rest_dir(n) * P.len[n]
def hinge(n, axis, deg):
    """A turn about an axis given in the figure's rest space, applied in the bone's own frame."""
    return Quaternion(P.rest[n].to_3x3().inverted() @ Vector(axis).normalized(), math.radians(deg))

# ---------------------------------------------------------------- what the rest pose gives
ANKLE = {sd: rest_head(f"foot.{sd}") for sd in "LR"}
BALL = {sd: rest_tail(f"foot.{sd}") for sd in "LR"}
KNEE = {"R": V(-0.12, -1, 0.1), "L": V(0.12, -1, 0.1)}
HIP = rest_head("hips")
D0 = rest_dir("staff"); G0 = rest_head("staff")
# The pole's foot: the lowest point of the staff.
gi = mesh.vertex_groups["staff"].index
low = min((v.co for v in mesh.data.vertices if any(g.group == gi and g.weight > 0.9 for g in v.groups)),
          key=lambda p: p.dot(D0))
TIP = (low - G0).dot(D0)                    # metres along the staff from the grip (negative: below it)
T0 = G0 + D0 * TIP
OFFG = G0 - rest_head("hand.R")
WL0 = rest_head("hand.L"); H0 = rest_dir("hand.L"); C0 = rest_dir("claws.L")
CURL = H0.cross(C0).normalized()            # the knuckles' axis: a turn about it closes the claws
SHL = rest_head("upper_arm.L")
ELBOW_L = V(0.5, 0.5, -1.0); ELBOW_R = V(-0.5, 0.9, -0.5)

def legs(pose):
    for sd in "LR":
        pose[f"thigh.{sd}"] = {"ik": (ANKLE[sd], KNEE[sd])}
        pose[f"foot.{sd}"] = {"abs": Quaternion()}

def torso(pose, loc, L, Tw, Ti=lambda d=0: 0.0, head=None):
    """Lean (forward), twist (to its left) and tilt (to its left) in degrees, each joint reading them a little later."""
    pose["hips"] = {"loc": loc, "rot": qe(x=0.30 * L(0), z=0.30 * Tw(0), y=0.4 * Ti(0))}
    pose["spine"] = {"rot": qe(x=0.30 * L(1), z=0.30 * Tw(1), y=0.3 * Ti(1))}
    pose["chest"] = {"rot": qe(x=0.40 * L(2), z=0.40 * Tw(2), y=0.3 * Ti(2))}
    pose["neck"] = {"rot": qe(x=-0.20 * L(3), z=-0.25 * Tw(3))}
    pose["head"] = {"rot": (head or Quaternion()) @ qe(x=-0.30 * L(4), z=-0.30 * Tw(4), y=-0.5 * Ti(4))}
    # The shell is a weight on its back: it starts after the body and catches up.
    pose["shell"] = {"rot": qe(x=0.22 * (L(6) - L(1)), z=0.2 * (Tw(6) - Tw(1)))}

def with_body(p, loc, lean, twist):
    """Where a point of the rest pose goes when the torso leans and twists (roughly: about the hips)."""
    return HIP + Vector(loc) + qe(x=lean, z=twist) @ (Vector(p) - HIP)

def staff(pose, tip, top, pole=ELBOW_R):
    """The staff by its foot and the direction of its top; the arm follows the grip."""
    pose["_staff"] = (Vector(tip), Vector(top).normalized(), Vector(pole))

def claw(pose, wrist, aim=None, curl=0.0, flex=0.0, pole=ELBOW_L):
    pose["upper_arm.L"] = {"ik": (Vector(wrist), Vector(pole))}
    pose["hand.L"] = {"lrot": hinge("hand.L", CURL, flex)}
    if aim is not None: pose["hand.L"]["aimvec"] = (H0, Vector(aim))
    pose["claws.L"] = {"lrot": hinge("claws.L", CURL, curl)}

def evaluate(fn, t):
    pose = fn(t); st = pose.pop("_staff", None)
    if st:
        tip, top, pole = st
        wrist = tip - top * TIP - D0.rotation_difference(top) @ OFFG
        pose["hand.R"] = {"aimvec": (D0, top)}
        for _ in range(4):                 # the hand's twist moves the grip a little: correct until the foot is on its mark
            pose["upper_arm.R"] = {"ik": (wrist.copy(), pole)}
            world, _b = P.solve(pose)
            err = tip - (world["staff"] @ P.rest["staff"].inverted() @ T0)
            if err.length < 0.002: break
            wrist += err
    return pose

# ---------------------------------------------------------------- the hanging things
# k: how hard a link is pulled back to its rest line (1/s2; a free pendulum of length l has 9.8/l), c: drag (1/s),
# carry: how much its rest line turns with the bone it hangs from, maxang: the furthest it may swing (degrees).
def chain(name, bones, k, c, carry=0.0, maxang=60.0, floor=False, limit=None, follow=0.5):
    return dict(name=name, bones=bones, k=k, c=c, carry=carry, maxang=math.radians(maxang), floor=floor, limit=limit, follow=follow)
def bell_limit(d_local):
    """The bell hangs a hand's width in front of the pole: it cannot swing back through it."""
    if d_local.y > BELL_BACK: d_local.y = BELL_BACK + 0.25 * (d_local.y - BELL_BACK)
    return d_local
_bo = rest_tail("bell") - rest_head("bell")
BELL_BACK = _bo.y + 0.05
CHAINS_A = [
    chain("bell", ["bell"], 15.0, 1.7, maxang=34, limit=bell_limit),
    chain("tassel", ["tassel1", "tassel2", "tassel3"], 13.0, 1.6, maxang=50),
    chain("sleeve.L", ["sleeve1.L", "sleeve2.L"], 16.0, 3.0, carry=0.35, maxang=40, follow=0.65),
    chain("sleeve.R", ["sleeve1.R", "sleeve2.R"], 16.0, 3.0, carry=0.35, maxang=40, follow=0.65),
    chain("pendant", ["pendant1", "pendant2"], 16.0, 2.2, carry=0.3, maxang=40, follow=0.6),
] + [chain(f"skirt_{sd}", [f"skirt1_{sd}", f"skirt2_{sd}"], 34.0, 6.0, carry=0.45, maxang=55, floor=True, follow=0.3)
     for sd in ("f.L", "f.R", "s.L", "s.R", "b.L", "b.R")]
CHAINS_B = [chain("clapper", ["clapper"], 24.0, 0.9, maxang=22)]

def simulate(seq, chains, wind=None, period=None, sub=6):
    worlds = [P.solve(p)[0] for p in seq]
    h = 1.0 / 30 / sub
    for ch in chains:
        bones = ch["bones"]; par = P.par[bones[0]]
        offs = [rest_dir(b) * P.len[b] for b in bones]
        Rp = [w[par].to_3x3() @ P.rest[par].to_3x3().inverted() for w in worlds]
        piv = [w[bones[0]].translation.copy() for w in worlds]
        zmin = [rest_tail(b).z for b in bones]
        nodes = []; base = piv[0]
        for o in offs:
            base = base + Rp[0] @ o; nodes.append(base.copy())
        vel = [Vector() for _ in bones]
        for f in range(len(seq)):
            if f > 0:
                for st in range(1, sub + 1):
                    a = st / sub; base = piv[f - 1].lerp(piv[f], a); R = Rp[f]
                    for j in range(len(nodes)): nodes[j] += (piv[f] - piv[f - 1]) * (ch["follow"] / sub)   # water and hand carry it part of the way
                    ph = ((f - 1 + a) % period) / period if period else (f - 1 + a) / 30.0
                    for j, o in enumerate(offs):
                        carried = (R @ o).normalized()
                        ref = (o.normalized() * (1 - ch["carry"]) + carried * ch["carry"]).normalized()
                        want = base + ref * o.length
                        if ch["floor"]: want.z = zmin[j]        # the robe stands on the floor: it keeps its height
                        acc = ch["k"] * (want - nodes[j]) - ch["c"] * vel[j]
                        if wind: acc += wind(ph, ch["name"], j)
                        vel[j] += acc * h
                        d = (nodes[j] + vel[j] * h - base).normalized()
                        ang = d.angle(ref)
                        if ang > ch["maxang"]: d = ref.slerp(d, ch["maxang"] / ang)
                        if ch["limit"]:
                            d = (R @ ch["limit"](R.inverted() @ d * o.length)).normalized()
                        new = base + d * o.length
                        if ch["floor"] and new.z < zmin[j]:
                            # When the hips sink the cloth cannot go into the floor: it spreads outwards instead.
                            dz = zmin[j] - base.z; flat = Vector((d.x, d.y, 0))
                            if abs(dz) < o.length and flat.length > 1e-5:
                                new = base + flat.normalized() * math.sqrt(o.length ** 2 - dz * dz) + Vector((0, 0, dz))
                        vel[j] = (new - nodes[j]) / h; nodes[j] = new; base = new
            base = piv[f]
            for j, b in enumerate(bones):
                seq[f][b] = {"aim": nodes[j] - base}; base = nodes[j]

def stash(act):
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act); st.name = act.name
    tr.mute = True
    act.use_fake_user = True

BUILT = {}
def build(name, fn, n, loop=False, wind=None):
    if ONLY and name not in ONLY: return
    if loop:
        cyc = [evaluate(fn, f / n) for f in range(n)]
        seq = [dict(p) for _ in range(3) for p in cyc]
    else:
        seq = [evaluate(fn, float(f)) for f in range(n + 1)]
    simulate(seq, CHAINS_A, wind, n if loop else None)
    simulate(seq, CHAINS_B, wind, n if loop else None)
    frames = seq[2 * n:3 * n] + [seq[2 * n]] if loop else seq
    act = poser.new_action(rig, name); P.prevq.clear()
    for f, pose in enumerate(frames): P.key(pose, f)
    act.frame_range = (0, n); act.use_frame_range = True; act.use_cyclic = loop
    stash(act); BUILT[name] = n

exec(open(os.path.join(os.path.dirname(__file__), "tidecaller_clips.py")).read())
exec(open(os.path.join(os.path.dirname(__file__), "tidecaller_attacks.py")).read())

sc.frame_start = 0; sc.frame_end = 96
if not ONLY:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim.blend"))
else:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "anim_try.blend"))
zdlib.emit({"actions": BUILT, "strikes_s": {k: [round(v[0] / 30, 3), round(v[1] / 30, 3)] for k, v in STRIKES.items()}, "tip": [round(x, 3) for x in T0], "tip_len": round(TIP, 3)})
