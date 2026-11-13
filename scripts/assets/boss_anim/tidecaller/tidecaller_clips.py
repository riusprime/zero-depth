# The clips (run inside tidecaller_anim.py). Loops take a phase 0..1, attacks a frame number (30 a second).
STAND = -0.03                      # the hips sit a little under the rest pose, so the knees are never locked
W_HANG = WL0 + V(0.0, 0.05, -0.03) # the reaching arm at ease: the elbow a little bent

# ---------------------------------------------------------------- idle: breathing under the shell
IDLE_N = 96            # 3.2 s: one slow breath, one shift of weight

def idle_pose(ph):
    br = lambda d=0: s(ph - d)                       # the breath, read later up the body
    sway = lambda d=0: s(ph + 0.2 - d)
    pose = {}
    loc = V(0.016 * sway(), 0.006 * c(ph), STAND - 0.010 * br())
    pose["hips"] = {"loc": loc, "rot": qe(x=0.8 * br(), y=1.0 * sway(), z=1.2 * s(ph + 0.1))}
    pose["spine"] = {"rot": qe(x=-1.2 * br(0.04), y=-0.5 * sway(0.05))}
    pose["chest"] = {"rot": qe(x=-2.4 * br(0.08), y=-0.5 * sway(0.1), z=-1.0 * s(ph))}
    pose["shell"] = {"rot": qe(x=1.6 * br(0.16), y=0.9 * sway(0.2))}
    pose["neck"] = {"rot": qe(x=1.0 * br(0.12))}
    pose["head"] = {"rot": qe(x=1.6 * br(0.2), z=3.5 * s(ph - 0.35), y=1.0 * s(2 * (ph - 0.1)))}
    pose["shoulder.L"] = {"rot": qe(y=-1.2 * br(0.1))}
    pose["shoulder.R"] = {"rot": qe(y=1.2 * br(0.1))}
    legs(pose)
    # The staff stands on its mark; the hand rides the breath and rocks the top a little.
    grip = G0 + loc + V(0.014 * s(ph - 0.15), 0.022 * s(ph - 0.1), 0.012 * br(0.1))
    staff(pose, T0, grip - T0)
    claw(pose, W_HANG + loc + V(0.018 * s(ph - 0.2), 0.03 * s(ph - 0.25), 0.03 * br(0.15)),
         curl=7 * s(2 * (ph - 0.2)) + 6 * s(ph - 0.4), flex=4 * s(ph - 0.35))
    return pose

def idle_wind(ph, name, j):
    """A slow current: it keeps the bell, the tassels and the cloth moving while the body only breathes."""
    k = {"bell": 1.0, "tassel": 0.55, "clapper": 1.0, "pendant": 0.8}.get(name, 1.0 if name.startswith("sleeve") else 1.6)
    d = 0.07 * j + (hash(name) % 7) * 0.03
    return V(0.6 * s(ph - d), 0.75 * c(ph - d - 0.1), 0) * k

build("idle", idle_pose, IDLE_N, loop=True, wind=idle_wind)

# ---------------------------------------------------------------- walk: short steps under the robe, the staff a third leg
WALK_N = 26            # two steps in 0.87 s
STANCE = 0.60          # share of the cycle a foot is on the ground
STEP = 0.36            # the foot travels +-STEP on the ground: the cycle covers 2*STEP/STANCE = 1.2 m
WALK_DROP = -0.13      # it walks with its knees bent

def foot(p):
    """Phase 0 = heel strike. Returns (forward offset, lift, pitch in degrees: + is heel up)."""
    p %= 1.0
    if p < STANCE:
        u = p / STANCE
        return lerp(-STEP, STEP, u), 0.0, -8 * (1 - smooth(u / 0.16)) + 22 * smooth((u - 0.6) / 0.4) ** 1.5
    v = (p - STANCE) / (1 - STANCE)
    return lerp(STEP, -STEP, smooth(v) * 0.75 + v * 0.25), 0.11 * math.sin(math.pi * v) ** 0.9, lerp(22, -8, smooth(v * 1.15))

def leg(pose, sd, p):
    y, lift, pitch = foot(p)
    qf = qe(x=pitch)
    heel = max(0.0, -math.sin(math.radians(pitch))) * 0.3
    ball = BALL[sd] + V(0, y, lift + heel)
    pose[f"thigh.{sd}"] = {"ik": (ball + qf @ (ANKLE[sd] - BALL[sd]), KNEE[sd])}
    pose[f"foot.{sd}"] = {"abs": qf}

def walk_pose(ph):
    pose = {}
    leg(pose, "R", ph); leg(pose, "L", ph + 0.5)
    loc = V(-0.05 * s(ph - 0.05), -0.03, WALK_DROP - 0.028 * c(2 * (ph - 0.06)))
    pose["hips"] = {"loc": loc, "rot": qe(x=5 + 1.2 * c(2 * (ph - 0.08)), y=2.5 * s(ph - 0.06), z=5 * c(ph))}
    pose["spine"] = {"rot": qe(x=2.5, y=-1.5 * s(ph - 0.1), z=-3.5 * c(ph - 0.03))}
    pose["chest"] = {"rot": qe(x=2 + 1.5 * c(2 * (ph - 0.13)), y=-1.5 * s(ph - 0.13), z=-4.5 * c(ph - 0.06))}
    pose["shell"] = {"rot": qe(x=-2.0 * c(2 * (ph - 0.22)), y=2.2 * s(ph - 0.2))}
    pose["neck"] = {"rot": qe(x=-2.5, z=1.5 * c(ph - 0.08))}
    pose["head"] = {"rot": qe(x=-4 + 1.5 * c(2 * (ph - 0.2)), y=1.0 * s(ph - 0.16), z=2.0 * c(ph - 0.1))}
    # The staff goes down with the left foot, stays on its mark while the body passes it, then swings ahead.
    p = (ph - 0.5 + 0.04) % 1.0; PLANT = 0.56; HALF = 0.5 * PLANT * 1.2
    if p < PLANT:
        ty = lerp(-HALF, HALF, p / PLANT); tz = 0.0
    else:
        v = (p - PLANT) / (1 - PLANT)
        ty = lerp(HALF, -HALF, smooth(v)); tz = 0.16 * math.sin(math.pi * v) ** 0.8
    tip = T0 + V(-0.06, -0.12 + ty, tz)
    grip = G0 + loc + V(0.0, -0.10 + 0.5 * ty, 0.03 * c(2 * (ph - 0.1)))
    pose["shoulder.R"] = {"rot": qe(y=1.5 * c(ph - 0.55))}
    staff(pose, tip, grip - tip)
    # The reaching arm swings a little against the left leg, the wrist and the claws trailing.
    sw = c(ph - 0.04)
    pose["shoulder.L"] = {"rot": qe(z=1.5 * sw)}
    claw(pose, W_HANG + loc + V(0.02 * s(ph), 0.02 - 0.07 * sw, 0.01 + 0.02 * c(2 * (ph - 0.15))),
         curl=10 + 8 * c(ph - 0.22) + 4 * c(2 * (ph - 0.3)), flex=5 * c(ph - 0.14))
    return pose

build("walk", walk_pose, WALK_N, loop=True)
