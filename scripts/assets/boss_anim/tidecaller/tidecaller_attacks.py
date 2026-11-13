# The attacks (run inside tidecaller_anim.py, after tidecaller_clips.py). Time is a frame number (30 a second).
# Each returns to the stance the idle breathes around. STRIKES: (strike pose, end of the active part) in frames.
STRIKES = {}
def stance_staff(pose, loc, extra=V(0, 0, 0), tip=None):
    """The staff on its mark, its top following the body."""
    tip = T0 if tip is None else tip
    staff(pose, tip, G0 + Vector(loc) * 0.9 + extra - tip)

# ---------------------------------------------------------------- bell_raise: the staff up high, rung, then planted
RAISE_N = 96; STRIKES["bell_raise"] = (30, 66)
def bell_raise_pose(t):
    a = lambda d=0: curve(t - d, [(0, 0), (5, 1), (10, 0)])                      # the dip before the lift
    up = lambda d=0: curve(t - d, [(5, 0), (15, 1.06), (19, 1.0)]) * (1 - ramp(t - d, 26, 30) ** 2)
    hit = lambda d=0: curve(t - d, [(26, 0), (30, 1.15), (35, 0.96), (40, 1.0), (66, 1.0), (96, 0)])
    out = lambda d=0: curve(t - d, [(27, 0), (33, 1.08), (38, 1.0), (66, 1.0), (92, 0)])   # the arm, after the staff
    back = sr(t, 66, 96)
    shake = math.sin(TAU * (t - 15) / 7.0) * curve(t, [(15, 0), (17, 1), (25, 1), (28, 0)])
    L = lambda d=0: 3 * a(d) - 9 * up(d) + 13 * hit(d)
    Tw = lambda d=0: -7 * up(d) + 9 * hit(d)
    loc = V(-0.02 * up() + 0.02 * hit(), 0.03 * up() - 0.06 * hit(), STAND - 0.05 * a() + 0.025 * up() - 0.13 * hit())
    pose = {}
    torso(pose, loc, L, Tw, head=qe(x=-8 * up(3) + 5 * hit(3)))
    legs(pose)
    tip = T0 + V(-0.04, -0.16, 0.78) * up() + V(-0.05, -0.30, 0) * hit() + V(0, 0, 0.10 * math.sin(math.pi * back))
    calm = D0 + V(0.02, -0.06, 0) * up() + V(0.02, -0.05, 0) * hit()
    top = calm + V(0.10 * shake, 0.18 * shake, 0)
    tip = tip - calm.normalized() * TIP + top.normalized() * TIP          # the shake turns the staff in the hand
    staff(pose, tip, top)
    pose["shoulder.R"] = {"rot": qe(y=10 * up(1) + 2 * hit(1))}
    # The other arm gathers in under the lift, then is thrown out over the water as the staff lands.
    w_in = with_body(W_HANG + V(-0.22, 0.30, 0.22), loc, L(2), Tw(2))
    w_out = with_body(V(1.18, -0.62, 1.82), loc, L(2), Tw(2)) + V(0, 0, 0.015 * math.sin(t * 1.9)) * hit()
    w = W_HANG + loc + (w_in - W_HANG - loc) * up(2)
    w = w.lerp(w_out, out())
    pose["shoulder.L"] = {"rot": qe(y=-9 * out(), z=-6 * out())}
    claw(pose, w, curl=28 * up(4) - 26 * out(3) + 3 * math.sin(t * 1.3) * hit(), flex=12 * up(3) - 22 * out(2),
         pole=ELBOW_L.lerp(V(0.2, 0.9, -0.6), out()))
    return pose
build("bell_raise", bell_raise_pose, RAISE_N)

# ---------------------------------------------------------------- bell_toll: one hard toll of the bell
TOLL_N = 60; STRIKES["bell_toll"] = (24, 40)
def bell_toll_pose(t):
    a = lambda d=0: curve(t - d, [(0, 0), (5, 1), (9, 0)])
    wind = lambda d=0: curve(t - d, [(5, 0), (17, 1.05), (20, 1.0)]) * (1 - ramp(t - d, 20, 24) ** 1.6)
    hit = lambda d=0: curve(t - d, [(20, 0), (24, 1.14), (28, 0.97), (32, 1.0), (40, 1.0), (60, 0)])
    L = lambda d=0: 2 * a(d) - 7 * wind(d) + 12 * hit(d)
    Tw = lambda d=0: -9 * wind(d) + 6 * hit(d)
    loc = V(-0.02 * wind(), 0.03 * wind() - 0.05 * hit(), STAND - 0.04 * a() + 0.02 * wind() - 0.08 * hit())
    pose = {}
    torso(pose, loc, L, Tw, head=qe(x=-5 * wind(3) + 4 * hit(3)))
    legs(pose)
    tip = T0 + V(0.0, 0.10, 0.30) * wind() + V(-0.03, -0.20, 0) * hit()
    top = D0 + V(-0.10, 0.20, 0) * wind() + V(0.03, -0.15, 0) * hit()
    staff(pose, tip, top)
    pose["shoulder.R"] = {"rot": qe(y=6 * wind(1))}
    w = W_HANG + loc + V(-0.05, 0.10, 0.14) * wind(2) + V(0.14, 0.10, -0.08) * hit(3)
    pose["shoulder.L"] = {"rot": qe(y=-3 * hit(2))}
    claw(pose, w, curl=18 * wind(4) - 14 * hit(4), flex=8 * wind(3) - 8 * hit(3))
    return pose
build("bell_toll", bell_toll_pose, TOLL_N)

# ---------------------------------------------------------------- claw_sweep: the long arm sweeps a wave across
SWEEP_N = 54; STRIKES["claw_sweep"] = (21, 30)
W_WIND = V(-0.05, -0.86, 1.58); W_FAR = V(1.30, -0.38, 1.40); W_PAST = V(1.22, 0.05, 1.22)
def claw_sweep_pose(t):
    a = lambda d=0: curve(t - d, [(0, 0), (4, 1), (8, 0)])
    wind = lambda d=0: sr(t - d, 4, 15)
    coil = lambda d=0: curve(t - d, [(13, 0), (16, 1), (18, 0)])
    def cut(d=0):
        u = ramp(t - d, 16, 24); return min(1.0, u ** 1.5 * (1.0 + 0.4 * (1 - u)))
    past = lambda d=0: sr(t - d, 23, 30)
    back = lambda d=0: sr(t - d, 32, 54)
    Tw = lambda d=0: -18 * wind(d) - 4 * coil(d) + 40 * cut(d) + 5 * past(d) - 27 * back(d)
    L = lambda d=0: 3 * a(d) + 5 * wind(d) + 7 * cut(d) - 12 * back(d)
    loc = V(-0.04 * wind() + 0.10 * cut() - 0.06 * back(), -0.02 * wind() - 0.04 * cut() + 0.06 * back(),
            STAND - 0.03 * a() - 0.03 * wind() - 0.04 * cut() + 0.07 * back())
    pose = {}
    torso(pose, loc, L, Tw, Ti=lambda d=0: 3 * wind(d) - 6 * cut(d) + 3 * back(d))
    legs(pose)
    stance_staff(pose, loc, V(-0.03, 0.02, 0) * cut() * (1 - back()))
    P_IN = V(0.9, 0.2, -0.6); P_OUT = V(0.2, 0.8, -0.7)
    if t <= 16:
        w = bez(W_HANG, V(0.60, -0.95, 1.55), W_WIND, wind()) + V(-0.04, 0.05, 0.03) * coil(); pole = ELBOW_L.lerp(P_IN, wind())
    elif t <= 23:
        w = bez(W_WIND, V(0.40, -1.30, 1.50), W_FAR, cut()); pole = P_IN.lerp(P_OUT, cut())
    elif t <= 32:
        w = W_FAR.lerp(W_PAST, past()); pole = P_OUT
    else:
        w = bez(W_PAST, V(1.05, -0.55, 1.25), W_HANG + loc, back()); pole = P_OUT.lerp(ELBOW_L, back())
    reach = wind() - cut()
    pose["shoulder.L"] = {"rot": qe(z=-10 * reach + 8 * (cut() - back()), y=-5 * wind() + 5 * back())}
    claw(pose, w, curl=26 * wind(3) - 44 * cut(2) + 18 * back(3),
         flex=14 * wind(2) - 26 * cut(1) + 12 * back(2), pole=pole)
    return pose
build("claw_sweep", claw_sweep_pose, SWEEP_N)

# ---------------------------------------------------------------- claw_drag: a long reach, then the arm rips back
DRAG_N = 84; STRIKES["claw_drag"] = (48, 58)
W_REACH = V(0.42, -1.34, 1.86); W_YANK = V(0.64, -0.40, 1.46)
def claw_drag_pose(t):
    a = lambda d=0: curve(t - d, [(0, 0), (5, 1), (10, 0)])
    rch = lambda d=0: (sr(t - d, 6, 30) + 0.07 * sr(t - d, 30, 44))
    def yank(d=0): return curve(t - d, [(44, 0), (48, 1.12), (53, 0.97), (58, 1.0)])
    back = lambda d=0: sr(t - d, 58, 84)
    hold = lambda d=0: rch(d) * (1 - min(1.0, yank(d)))
    kept = lambda d=0: yank(d) * (1 - back(d))
    L = lambda d=0: 2 * a(d) + 15 * hold(d) - 6 * kept(d)
    Tw = lambda d=0: -14 * hold(d) + 11 * kept(d)
    loc = V(0.03 * hold(), -0.08 * hold() + 0.06 * kept(), STAND - 0.03 * a() - 0.04 * hold() - 0.07 * kept())
    pose = {}
    torso(pose, loc, L, Tw, head=qe(x=-4 * hold(3)))
    legs(pose)
    stance_staff(pose, loc, V(0.0, 0.03, 0) * kept())
    grasp = 2.5 * math.sin(t * 1.7) * sr(t, 26, 34) * (1 - ramp(t, 43, 45))        # the claws work at the water
    home = W_HANG + loc
    w = home + (W_REACH + V(0, 0, 0.012 * math.sin(t * 0.9)) - home) * min(1.07, rch())
    if t > 44: w = w.lerp(W_YANK, min(1.12, yank()))
    if t > 58: w = bez(W_YANK, V(0.80, -0.55, 1.30), home, back())
    pose["shoulder.L"] = {"rot": qe(z=-12 * hold(1) + 10 * kept(1), y=-6 * hold(1))}
    claw(pose, w, curl=-24 * rch(4) * (1 - ramp(t, 43, 47)) + 62 * ramp(t, 43, 47) * (1 - back(2)) + grasp,
         flex=-16 * hold(3) + 24 * kept(1), pole=ELBOW_L.lerp(V(0.8, 0.5, -0.8), kept()))
    return pose
build("claw_drag", claw_drag_pose, DRAG_N)

# ---------------------------------------------------------------- shell_slam: it rears, then drops its whole weight
SLAM_N = 72; STRIKES["shell_slam"] = (21, 40)
def shell_slam_pose(t):
    a = lambda d=0: curve(t - d, [(0, 0), (4, 1), (7, 0)])
    rear = lambda d=0: curve(t - d, [(4, 0), (13, 1.05), (16, 1.0)]) * (1 - ramp(t - d, 16, 21) ** 1.8)
    hit = lambda d=0: curve(t - d, [(16, 0), (21, 1.12), (25, 0.95), (30, 1.0), (40, 1.0), (72, 0)])
    bump = lambda d=0: curve(t - d, [(20, 0), (24, 1), (31, 0)])
    L = lambda d=0: 2 * a(d) - 12 * rear(d) + 32 * hit(d)
    Tw = lambda d=0: -4 * rear(d) + 4 * hit(d)
    loc = V(0, 0.04 * rear() - 0.10 * hit(), STAND - 0.03 * a() + 0.03 * rear() - 0.28 * hit())
    pose = {}
    torso(pose, loc, L, Tw, head=qe(x=-8 * rear(3) - 10 * hit(4)))
    pose["shell"]["rot"] = qe(x=7 * bump(1)) @ pose["shell"]["rot"]
    legs(pose)
    tip = T0 + V(0, 0.04, 0.45) * rear() + V(-0.12, -0.36, 0) * hit()
    top = D0 + V(-0.06, 0.10, 0) * rear() + V(-0.04, -0.22, 0) * hit()
    staff(pose, tip, top)
    pose["shoulder.R"] = {"rot": qe(y=7 * rear(1))}
    w_up = with_body(V(1.02, -0.55, 2.30), loc, L(2), Tw(2))
    w_dn = V(0.80, -1.02, 0.66)
    w = (W_HANG + loc).lerp(w_up, rear(1))
    w = w.lerp(w_dn, hit(1))
    pose["shoulder.L"] = {"rot": qe(y=-10 * rear(1), z=-5 * hit(1))}
    claw(pose, w, curl=18 * rear(3) - 30 * hit(2), flex=10 * rear(2) - 30 * hit(1),
         pole=ELBOW_L.lerp(V(0.9, 0.5, 0.2), min(1.0, hit())))
    return pose
build("shell_slam", shell_slam_pose, SLAM_N)
