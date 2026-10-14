"""v0.8.0 RT (owner O12): the designed room layouts' source. The prefab clusters and the layouts built from them are
written here in metres; running it writes data/room_layouts/<x>x<y>_<n>.tres (the files the game loads, validated by
RoomLayoutDefinition.validate), prints each layout's numbers at the room sizes a floor can draw (groups kept by the
generator's spacing rules, blocking and dressed share, slits) and, with Pillow installed, a top-down preview of each
at a typical size into build/room_layouts/. Edit the layouts here, not in the .tres files, and re-run:

    python3 -I scripts/content/room_layouts.py .

Starting values throughout: the owner picks at the G2 (docs/roadmap/v0.8.0/evidence/ROOMS.md)."""
import sys, os, math, copy

try:
    from PIL import Image, ImageDraw
except ImportError:  # previews are optional
    Image = None

REPO = sys.argv[1] if len(sys.argv) > 1 else "."
OUT_DIR = os.path.join(REPO, "data/room_layouts")
HERE = os.path.join(REPO, "build/room_layouts")

DECOR = {"grass_tuft", "rubble_small", "debris_low"}


def S(piece, x, y, w, h, height=0.0):
    return dict(piece=piece, at=(x, y), size=(w, h), yaw=0.0, height=height, solid=True)


def D(piece, x, y, w=None, h=None, yaw=0.0, height=0.0):
    nat = {"grass_tuft": (0.6, 0.6), "rubble_small": (0.6, 0.6), "debris_low": (0.9, 0.45)}
    if w is None:
        w, h = nat.get(piece, (0.5, 0.5))
    return dict(piece=piece, at=(x, y), size=(w, h), yaw=yaw, height=height, solid=False)


def flip(pieces, fx, fy):
    out = []
    for p in pieces:
        q = copy.deepcopy(p)
        q["at"] = (p["at"][0] * fx, p["at"][1] * fy)
        if not p["solid"]:
            y = p["yaw"]
            if fx < 0:
                y = 180.0 - y
            if fy < 0:
                y = -y
            q["yaw"] = (y + 360.0) % 360.0
        out.append(q)
    return out


def turn(pieces):
    """A quarter turn (x, y) -> (-y, x): solids swap their size."""
    out = []
    for p in pieces:
        q = copy.deepcopy(p)
        q["at"] = (-p["at"][1], p["at"][0])
        if p["solid"]:
            q["size"] = (p["size"][1], p["size"][0])
        else:
            q["yaw"] = (p["yaw"] + 90.0) % 360.0
        out.append(q)
    return out


# --- prefabs (corner prefabs: the corner at (0, 0), the room toward +x +y; wall prefabs: the wall along y = 0,
# the room toward +y; free prefabs: centred). fringe() adds grass, rubble and debris round each cluster's solids
# (the reference's tufts round every block). ---

def fringe(pieces, step=1.15, off=0.35, seed=1):
    solids = [p for p in pieces if p["solid"]]
    rects = [(p["at"][0] - p["size"][0] / 2, p["at"][1] - p["size"][1] / 2,
              p["at"][0] + p["size"][0] / 2, p["at"][1] + p["size"][1] / 2) for p in solids]
    out = list(pieces)
    kinds = ["grass_tuft", "grass_tuft", "rubble_small", "grass_tuft", "debris_low", "grass_tuft", "rubble_small"]
    k = seed
    taken = []
    for r in rects:
        pts = []
        x0, y0, x1, y1 = r[0] - off, r[1] - off, r[2] + off, r[3] + off
        for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
            length = math.hypot(bx - ax, by - ay)
            n = max(1, int(length / step))
            for i in range(n):
                t = (i + 0.5) / n
                pts.append((ax + (bx - ax) * t, ay + (by - ay) * t))
        for (x, y) in pts:
            k = (k * 1103515245 + 12345) % 2147483648
            if k % 100 < 38:
                continue
            if any(q[0] - 0.15 < x < q[2] + 0.15 and q[1] - 0.15 < y < q[3] + 0.15 for q in rects):
                continue
            if any(math.hypot(x - tx, y - ty) < 0.8 for (tx, ty) in taken):
                continue
            taken.append((x, y))
            kind = kinds[k % len(kinds)]
            jx = ((k >> 8) % 21 - 10) / 50.0
            jy = ((k >> 13) % 21 - 10) / 50.0
            out.append(D(kind, round(x + jx, 2), round(y + jy, 2), yaw=float((k >> 3) % 180)))
    return out


def block_corner():
    return fringe([
        S("slab_concrete", 1.3, 1.2, 2.6, 2.4, 3.0),
        S("slab_concrete", 3.8, 1.2, 2.4, 2.4, 2.2),
        S("crate_stack", 0.7, 3.05, 1.4, 1.3, 1.4),
        S("crate_stack", 0.6, 4.3, 1.2, 1.2, 0.9),
        S("crate_stack", 5.65, 0.55, 1.3, 1.1, 1.0),
        S("rock_large", 2.0, 2.95, 1.2, 1.1),
    ], seed=3)


def wreck_corner():
    return fringe([
        S("car_wreck", 2.4, 1.1, 4.8, 2.2),
        S("crate_stack", 0.7, 2.9, 1.4, 1.4, 1.5),
        S("crate_stack", 0.6, 4.2, 1.2, 1.2),
        S("fire_barrel", 5.15, 0.35, 0.7, 0.7),
        S("wall_broken", 6.65, 0.3, 2.3, 0.6, 0.9),
        S("wall_pillar", 8.3, 0.5, 1.0, 1.0, 1.7),
    ], seed=5)


def crate_corner():
    return fringe([
        S("crate_stack", 0.65, 0.65, 1.3, 1.3, 1.9),
        S("crate_stack", 1.95, 0.65, 1.3, 1.3, 1.3),
        S("crate_stack", 0.65, 1.95, 1.3, 1.3, 1.0),
        S("crate_stack", 3.2, 0.6, 1.2, 1.2, 0.9),
        S("rock_large", 2.0, 2.0, 1.4, 1.4),
        S("slab_concrete", 0.7, 3.6, 1.4, 2.0, 2.6),
        S("slab_wide", 5.0, 0.6, 2.4, 1.2, 2.0),
    ], seed=7)


def ruin_corner():
    return fringe([
        S("wall_broken", 1.9, 0.3, 3.8, 0.6, 1.1),
        S("wall_pillar", 4.3, 0.5, 1.0, 1.0, 1.9),
        S("wall_broken", 6.0, 0.3, 2.4, 0.6, 0.8),
        S("wall_broken", 0.3, 2.4, 0.6, 3.6, 1.0),
        S("wall_pillar", 0.5, 4.7, 1.0, 1.0, 1.7),
        S("crate_stack", 1.6, 1.25, 2.0, 1.3),
        S("dead_tree", 3.2, 1.1, 1.2, 1.0),
    ], seed=11)


def wall_row():
    return fringe([
        S("slab_concrete", -3.0, 1.1, 2.0, 2.2, 2.8),
        S("slab_concrete", -1.0, 0.9, 2.0, 1.8, 2.2),
        S("crate_stack", 0.65, 0.65, 1.3, 1.3, 1.3),
        S("crate_stack", 1.95, 0.55, 1.3, 1.1, 0.9),
        S("wall_broken", 3.6, 0.3, 2.0, 0.6, 1.0),
    ], seed=13)


def wall_fire():
    return fringe([
        S("wall_broken", 0.0, 0.3, 3.6, 0.6, 1.0),
        S("fire_barrel", 0.0, 1.05, 0.8, 0.9),
        S("crate_stack", -1.15, 0.9, 1.6, 1.2),
        S("crate_stack", 1.15, 0.9, 1.6, 1.2, 0.9),
        S("wall_pillar", 2.3, 0.5, 1.0, 1.0, 1.7),
        S("slab_concrete", -2.5, 0.9, 1.4, 1.8, 2.4),
    ], seed=17)


def free_big():
    return fringe([
        S("slab_concrete", -1.6, -0.9, 2.6, 2.4, 3.0),
        S("slab_concrete", 1.0, -0.9, 2.6, 2.4, 2.3),
        S("crate_stack", -1.9, 1.0, 1.4, 1.4, 1.3),
        S("crate_stack", -0.5, 0.85, 1.4, 1.1, 0.9),
        S("rock_large", 2.9, 0.4, 1.4, 1.4),
    ], seed=19)


def free_wreck():
    return fringe([
        S("car_wreck", 0.0, 0.0, 4.8, 2.2),
        S("crate_stack", 3.0, -0.5, 1.2, 1.2),
        S("crate_stack", -3.0, 0.4, 1.2, 1.4, 1.6),
        S("rock_large", -1.0, -1.8, 1.4, 1.4),
    ], seed=23)


def free_ruin():
    return fringe([
        S("wall_pillar", -4.0, 0.0, 1.0, 1.0, 2.0),
        S("wall_broken", -2.4, 0.0, 2.2, 0.6, 0.9),
        S("wall_pillar", -0.8, 0.0, 1.0, 1.0, 1.6),
        S("wall_pillar", 2.3, 0.0, 1.0, 1.0, 1.8),
        S("wall_broken", 4.1, 0.0, 2.6, 0.6, 0.7),
        S("crate_stack", 3.5, 0.9, 1.2, 1.2),
    ], seed=29)


def free_camp():
    return fringe([
        S("crate_stack", -0.6, 0.0, 1.2, 1.2),
        S("crate_stack", 0.6, 0.0, 1.2, 1.2, 0.9),
        S("fire_barrel", 0.0, 0.95, 0.7, 0.7),
        S("wall_broken", 0.0, -0.9, 3.6, 0.6, 1.0),
    ], seed=31)


def free_slabs():
    return fringe([
        S("slab_wide", 0.0, 0.0, 3.4, 1.4, 2.8),
        S("slab_concrete", 2.4, 0.3, 1.4, 2.0, 2.0),
        S("crate_stack", -2.3, -0.1, 1.2, 1.2),
        S("crate_stack", -2.3, 1.1, 1.2, 1.2, 0.9),
    ], seed=37)


def free_complex():
    """A ruined building's remains: tall blocks, a pillar, crates and a rock round a small yard."""
    return fringe([
        S("slab_concrete", -2.4, -1.5, 2.4, 2.6, 3.2),
        S("slab_wide", 0.4, -2.2, 3.2, 1.2, 2.4),
        S("wall_pillar", 2.5, -2.3, 1.0, 1.0, 2.0),
        S("crate_stack", -2.6, 0.5, 1.4, 1.4, 1.5),
        S("crate_stack", -1.25, 0.45, 1.3, 1.3, 1.0),
        S("crate_stack", -0.55, -0.9, 1.3, 1.4, 1.2),
        S("crate_stack", 0.85, -0.9, 1.5, 1.4, 1.6),
        S("rock_large", 2.4, -0.8, 1.6, 1.6),
    ], seed=43)


def big_pair():
    """A block cluster and a wreck with a 1.6 m lane between them (one group)."""
    return combine(shift(free_big(), 0.0, -2.0), shift(free_wreck(), 0.0, 4.3))


def free_rocks():
    return fringe([
        S("rock_large", 0.0, 0.0, 1.9, 1.9),
        S("rock_large", 1.55, -0.55, 1.2, 1.2),
        S("dead_tree", -1.45, 0.5, 1.0, 1.0),
        S("crate_stack", 0.0, 1.55, 1.2, 1.2, 0.8),
    ], seed=41)


def shift(pieces, dx, dy):
    out = []
    for p in pieces:
        q = copy.deepcopy(p)
        q["at"] = (round(p["at"][0] + dx, 3), round(p["at"][1] + dy, 3))
        out.append(q)
    return out


def combine(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def slits(pieces):
    """Corridors 0.6-1.4 m wide between two solids facing each other, not filled by the group's other solids."""
    rs = [rect_of(p, 0, 0) for p in pieces if p["solid"]]
    out = []
    for i in range(len(rs)):
        for j in range(i + 1, len(rs)):
            a, b = rs[i], rs[j]
            oy = (max(a[1], b[1]), min(a[3], b[3]))
            ox = (max(a[0], b[0]), min(a[2], b[2]))
            box = None
            if oy[1] - oy[0] > 0.01 and (b[0] - a[2] > 0.6 or a[0] - b[2] > 0.6):
                g = max(b[0] - a[2], a[0] - b[2])
                x0 = a[2] if b[0] >= a[2] else b[2]
                box = (x0, oy[0], x0 + g, oy[1])
            elif ox[1] - ox[0] > 0.01 and (b[1] - a[3] > 0.6 or a[1] - b[3] > 0.6):
                g = max(b[1] - a[3], a[1] - b[3])
                y0 = a[3] if b[1] >= a[3] else b[3]
                box = (ox[0], y0, ox[1], y0 + g)
            if box is None or g >= LANE:
                continue
            open_pts = 0
            n = 8
            for u in range(n):
                for v in range(n):
                    x = box[0] + (box[2] - box[0]) * (u + 0.5) / n
                    y = box[1] + (box[3] - box[1]) * (v + 0.5) / n
                    if not any(r[0] <= x <= r[2] and r[1] <= y <= r[3] for k, r in enumerate(rs) if k not in (i, j)):
                        open_pts += 1
            if open_pts:
                out.append((i, j, round(g, 2)))
    return out


def lane_errors(name):
    return [(gi, e) for gi, g in enumerate(LAYOUTS[name]["groups"]) for e in slits(g["pieces"])]


CORNER = {  # anchor, flip
    (0, 0): (1, 1), (1, 0): (-1, 1), (0, 1): (1, -1), (1, 1): (-1, -1)}


def corner(prefab, c):
    fx, fy = CORNER[c]
    return dict(anchor=c, pieces=flip(prefab, fx, fy))


def wall(prefab, u, side):
    """side: 'top' (y=0), 'bottom' (y=1), 'left' (x=0), 'right' (x=1); u the fraction along it."""
    if side == "top":
        return dict(anchor=(u, 0), pieces=prefab)
    if side == "bottom":
        return dict(anchor=(u, 1), pieces=flip(prefab, 1, -1))
    if side == "left":  # wall along x=0, room toward +x: (x, y) -> (y, x)? use a turn of -90: (x,y)->(y,-x)
        return dict(anchor=(0, u), pieces=flip(turn(turn(turn(prefab))), 1, 1))
    return dict(anchor=(1, u), pieces=turn(prefab))


def free(prefab, ax, ay, turns=0, fx=1, fy=1):
    p = prefab
    for _ in range(turns):
        p = turn(p)
    return dict(anchor=(ax, ay), pieces=flip(p, fx, fy))


LAYOUTS = {}

# 2 x 2 "crossroads": four different corners, a wall row, round an open centre with cover at its four sides.
LAYOUTS["2x2_1"] = dict(
    cells=(2, 2),
    keep=[(0.37, 0.36, 0.26, 0.28)],
    groups=[
        corner(block_corner(), (0, 0)),
        corner(wreck_corner(), (1, 1)),
        corner(ruin_corner(), (1, 0)),
        corner(crate_corner(), (0, 1)),
        free(free_big(), 0.22, 0.5, turns=1),
        free(free_slabs(), 0.78, 0.5, turns=1),
        free(free_camp(), 0.5, 0.22),
        free(free_rocks(), 0.46, 0.72),
    ],
)

# 3 x 2 "the yard": a long room, wreck and fire at one end, ruins at the other, two rows of cover with lanes.
LAYOUTS["3x2_1"] = dict(
    cells=(3, 2),
    keep=[(0.42, 0.3, 0.16, 0.4)],
    groups=[
        corner(wreck_corner(), (0, 0)),
        corner(crate_corner(), (0, 1)),
        corner(ruin_corner(), (1, 0)),
        corner(block_corner(), (1, 1)),
        wall(wall_fire(), 0.5, "top"),
        wall(wall_row(), 0.5, "bottom"),
        free(free_big(), 0.28, 0.5),
        free(free_ruin(), 0.72, 0.5),
        free(free_rocks(), 0.62, 0.22),
        free(free_camp(), 0.66, 0.72),
        wall(wall_fire(), 0.54, "right"),
        free(free_rocks(), 0.3, 0.75),
        wall(wall_row(), 0.51, "left"),
        free(free_slabs(), 0.39, 0.21),
    ],
)

# 3 x 3 "the ruined square": a big hall, four corner clusters, mid-wall clusters, an inner ring of cover round an
# open middle.
LAYOUTS["3x3_1"] = dict(
    cells=(3, 3),
    keep=[(0.39, 0.39, 0.22, 0.22)],
    groups=[
        corner(block_corner(), (0, 0)),
        corner(wreck_corner(), (1, 0)),
        corner(crate_corner(), (1, 1)),
        corner(ruin_corner(), (0, 1)),
        wall(wall_row(), 0.5, "top"),
        wall(wall_fire(), 0.5, "bottom"),
        wall(wall_row(), 0.5, "left"),
        wall(wall_fire(), 0.5, "right"),
        free(free_complex(), 0.27, 0.27),
        free(free_wreck(), 0.73, 0.27, turns=1),
        free(big_pair(), 0.7, 0.7),
        free(free_ruin(), 0.27, 0.73, turns=1),
        free(free_camp(), 0.5, 0.27),
        free(free_wreck(), 0.42, 0.75, turns=1),
        free(free_slabs(), 0.28, 0.44),
        free(free_camp(), 0.75, 0.48),
        free(free_camp(), 0.12, 0.72, turns=1),
    ],
)

# --- checks ---
GAP = 2.2
LANE = 2.0


def rect_of(p, ax, ay, flipx=False):
    x, y = p["at"]
    w, h = p["size"]
    return (ax + x - w / 2, ay + y - h / 2, ax + x + w / 2, ay + y + h / 2)


def gap(a, b):
    dx = max(a[0] - b[2], b[0] - a[2], 0)
    dy = max(a[1] - b[3], b[1] - a[3], 0)
    return math.hypot(dx, dy)


def overlap(a, b):
    return a[0] < b[2] - 1e-6 and b[0] < a[2] - 1e-6 and a[1] < b[3] - 1e-6 and b[1] < a[3] - 1e-6


def foot(rects):
    return (min(r[0] for r in rects), min(r[1] for r in rects), max(r[2] for r in rects), max(r[3] for r in rects))


def place(lay, L, Sz):
    groups = []
    for g in lay["groups"]:
        ax, ay = g["anchor"][0] * L, g["anchor"][1] * Sz
        solids = [rect_of(p, ax, ay) for p in g["pieces"] if p["solid"]]
        props = [(ax + p["at"][0], ay + p["at"][1], p) for p in g["pieces"] if not p["solid"]]
        groups.append((solids, props))
    return groups


def check(name, lay, L, Sz, verbose=False):
    groups = place(lay, L, Sz)
    kept = []
    problems = []
    for gi, (solids, props) in enumerate(groups):
        if not solids:
            kept.append(gi)
            continue
        f = foot(solids)
        ok = True
        if f[0] < -0.02 or f[1] < -0.02 or f[2] > L + 0.02 or f[3] > Sz + 0.02:
            ok = False
            problems.append((gi, "leaves room"))
        # flush or slab gap from each wall
        for d in (f[0], f[1], L - f[2], Sz - f[3]):
            if 0.005 < d < GAP:
                ok = False
                problems.append((gi, "wall gap %.2f" % d))
        for kj in kept:
            sj = groups[kj][0]
            if not sj:
                continue
            dmin = min(min(gap(f, r) for r in sj), min(gap(foot(solids), r) for r in sj))
            dmin = min(dmin, min(gap(r, foot(sj)) for r in solids))
            if dmin < GAP:
                ok = False
                problems.append((gi, "gap to group %d %.2f" % (kj, dmin)))
        for kr in lay["keep"]:
            kr_m = (kr[0] * L, kr[1] * Sz, (kr[0] + kr[2]) * L, (kr[1] + kr[3]) * Sz)
            for r in solids:
                if overlap(r, kr_m):
                    ok = False
                    problems.append((gi, "in keep clear"))
        if ok:
            kept.append(gi)
    block = sum((r[2] - r[0]) * (r[3] - r[1]) for gi in kept for r in groups[gi][0])
    decor = sum(1.0 for gi in kept for (_, _, p) in groups[gi][1])
    return kept, problems, block / (L * Sz), (block + decor) / (L * Sz)


def sizes(cells):
    x = {2: (22.6, 33.0), 3: (36.4, 49.8), 4: (50.2, 66.6), 1: (8.8, 19.2)}
    y = {2: (18.6, 27.0), 3: (30.4, 40.8), 4: (42.2, 54.6), 1: (7.0, 13.4)}
    cx, cy = cells
    out = []
    # turn even: L = x of cx cells, S = y of cy cells; odd: L = y of cx cells, S = x of cy cells
    for Lr, Sr in ((x[cx], y[cy]), (y[cx], x[cy])):
        mid = (sum(Lr) / 2, sum(Sr) / 2)
        out.append(("mid", mid))
        for a in Lr:
            for b in Sr:
                out.append(("ext", (a, b)))
    return out


def preview(name, lay, L, Sz, path):
    k = 20
    img = Image.new("RGB", (int(L * k) + 20, int(Sz * k) + 20), (60, 52, 48))
    d = ImageDraw.Draw(img)
    o = 10
    d.rectangle([o, o, o + L * k, o + Sz * k], outline=(200, 200, 200))
    for kr in lay["keep"]:
        d.rectangle([o + kr[0] * L * k, o + kr[1] * Sz * k, o + (kr[0] + kr[2]) * L * k, o + (kr[1] + kr[3]) * Sz * k], outline=(80, 160, 80))
    kept, _, _, _ = check(name, lay, L, Sz)
    col = {"slab_concrete": (150, 150, 150), "slab_wide": (130, 130, 140), "crate_stack": (150, 100, 60),
           "car_wreck": (120, 70, 60), "fire_barrel": (255, 140, 0), "wall_broken": (110, 100, 90),
           "wall_pillar": (170, 160, 150), "rock_large": (100, 100, 110), "dead_tree": (90, 70, 40)}
    for gi, (solids, props) in enumerate(place(lay, L, Sz)):
        lay_g = lay["groups"][gi]
        sp = [p for p in lay_g["pieces"] if p["solid"]]
        for r, p in zip(solids, sp):
            c = col.get(p["piece"], (200, 0, 200)) if gi in kept else (255, 0, 0)
            d.rectangle([o + r[0] * k, o + r[1] * k, o + r[2] * k, o + r[3] * k], fill=c, outline=(20, 20, 20))
        for (x, y, p) in props:
            c = (90, 140, 50) if p["piece"] == "grass_tuft" else (110, 100, 90)
            d.ellipse([o + x * k - 4, o + y * k - 4, o + x * k + 4, o + y * k + 4], fill=c)
    img.save(path)


# --- .tres ---

def fmt(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def write_tres(name, lay):
    lines = ['[gd_resource type="Resource" script_class="RoomLayoutDefinition" format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://src/content/defs/room_layout_piece.gd" id="1_piece"]')
    lines.append('[ext_resource type="Script" path="res://src/content/defs/room_layout_group.gd" id="2_group"]')
    lines.append('[ext_resource type="Script" path="res://src/content/defs/room_layout_definition.gd" id="3_layout"]')
    lines.append("")
    gids = []
    for gi, g in enumerate(lay["groups"]):
        pids = []
        for pi, p in enumerate(g["pieces"]):
            pid = "P%d_%d" % (gi, pi)
            pids.append(pid)
            lines.append('[sub_resource type="Resource" id="%s"]' % pid)
            lines.append('script = ExtResource("1_piece")')
            lines.append('piece = &"%s"' % p["piece"])
            lines.append("at = Vector2(%s, %s)" % (fmt(p["at"][0]), fmt(p["at"][1])))
            lines.append("size = Vector2(%s, %s)" % (fmt(p["size"][0]), fmt(p["size"][1])))
            if p["yaw"]:
                lines.append("yaw = %s" % fmt(p["yaw"]))
            if p["height"]:
                lines.append("height = %s" % fmt(p["height"]))
            if p["solid"]:
                lines.append("solid = true")
            lines.append("")
        gid = "G%d" % gi
        gids.append(gid)
        lines.append('[sub_resource type="Resource" id="%s"]' % gid)
        lines.append('script = ExtResource("2_group")')
        lines.append("anchor = Vector2(%s, %s)" % (fmt(g["anchor"][0]), fmt(g["anchor"][1])))
        lines.append('pieces = Array[ExtResource("1_piece")]([%s])' % ", ".join('SubResource("%s")' % p for p in pids))
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("3_layout")')
    lines.append("cells = Vector2i(%d, %d)" % lay["cells"])
    lines.append('groups = Array[ExtResource("2_group")]([%s])' % ", ".join('SubResource("%s")' % g for g in gids))
    lines.append("keep_clear = Array[Rect2i]([%s])" % ", ".join(
        "Rect2i(%d, %d, %d, %d)" % tuple(round(v * 1000) for v in k) for k in lay["keep"]))
    lines.append('id = &"%s"' % ("room_" + name))
    lines.append("")
    with open(os.path.join(OUT_DIR, "%s.tres" % name), "w") as fh:
        fh.write("\n".join(lines))


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, lay in LAYOUTS.items():
        print("==", name, "groups", len(lay["groups"]), "slits", lane_errors(name))
        for kind, (L, Sz) in sizes(lay["cells"]):
            kept, probs, b, dd = check(name, lay, L, Sz)
            print("  %s %5.1f x %5.1f kept %2d/%d block %.1f%% dressed %.1f%%  %s" % (
                kind, L, Sz, len(kept), len(lay["groups"]), b * 100, dd * 100, probs[:4] if kind == "mid" or len(kept) < len(lay["groups"]) * 0.6 else ""))
        (L, Sz) = sizes(lay["cells"])[0][1]
        if Image is not None:
            os.makedirs(HERE, exist_ok=True)
            preview(name, lay, L, Sz, os.path.join(HERE, "%s_mid.png" % name))
        write_tres(name, lay)
