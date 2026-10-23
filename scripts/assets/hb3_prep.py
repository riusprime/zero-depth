"""v0.9.0 Step HB3: prepares the owner's eight hub pieces (unprocessed_images/hub_v090/, delivered 2026-10-23, art list
§4b) for the game, the way mi2_prep.py prepared the first hub models (its pipeline is reused: weld, simplify to a
triangle budget, a new UV atlas, the raw colour map baked onto it at 1024 px or less, brightened like the other hub
pieces). The raw files stay untouched.

The models (Tripo exports: one textured mesh each, about 19k triangles, normalised to a 1 m cube, front +Z):
- hub_wall_segment: one curved wall section (its inner face +Z). Its own curve is much tighter than the plaza's (a
  radius of about 6 m at 8 m long), so the script re-bends it: the mesh is scaled to the plaza's segment (30 degrees
  of a ring whose inner face lies RING_R m from the centre), straightened along a fitted quadratic, then wrapped onto
  that ring. It is written in the hub's frame (the plaza's centre at the origin, the segment's middle on +Z, its
  inner face toward the origin), so HubView turns one copy per segment about the centre (ShopModels "as_is");
- hub_pillar_brazier, hub_floor_rune: scaled (the rune flattened to a floor stone);
- hub_sealed_gate: cut in two by region (the two door leaves: |x| < 0.195, z < -0.012, y < 0.6 of the raw cube) into
  hub_sealed_gate (the frame) and hub_sealed_gate_doors, both in the whole gate's frame (ShopModels "as_is"), so
  the gate opens by hiding the doors;
- hub_props: four objects side by side, cut by their connected pieces' centres (raw x): the credits stone (x < -0.25),
  the trophy back wall (< 0.11), the crates, barrel and scrolls (< 0.36: two pieces), the crystal-tree planter.
The textures (into assets/textures/hub/):
- hub_ground.png: the tileable paving, 1254 px -> 1024 px;
- hub_ground_path.png: the walkway (its cobbled borders on the image's left and right, tiling top to bottom),
  1536 x 1024 -> 1024 x 683;
- hub_ground_centre.png: the medallion. Its 14 sockets are found (bronze rings on the socket band), a circle is fitted
  through them, the image is cropped square on that circle's centre; the medallion has no socket at 3 and 9 o'clock,
  so the top socket's patch is turned and copied there (16 sockets, as the art list asks); 1024 px with its alpha.
  It prints the sockets' angles (degrees, counter-clockwise from the image's right) and their ring's share of the
  medallion's radius: data/hub/rune_ring.tres (rune_angles) and HubView (MEDALLION_SOCKET) carry them by hand.

It prints one JSON line per output (raw triangles, triangles after, size in metres, the file, its size and sha256:
pasted into assets/models/manifest.json and the evidence by hand).

Run from the repo root:  python -I scripts/assets/hb3_prep.py [ids...]   (GODOT=<godot executable> without
meshoptimizer; numpy, Pillow, xatlas, scipy as mi_prep.py).
"""

import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mi_prep  # noqa: E402
import mi2_prep  # noqa: E402  (its prepare(): weld, simplify, atlas, bake, write)

SRC = "unprocessed_images/hub_v090"
OUT = "assets/models"
TEX_OUT = "assets/textures/hub"

## The plaza's ring (m): the wall's inner face (its bench's front) lies this far from the centre, and one segment
## spans SEGMENT_DEG of it (12 segments round the plaza).
RING_R = 16.0
SEGMENT_DEG = 30.0
WALL_HEIGHT = 4.6

## Per role: (triangle budget, colour map px).
ROLES = {
    "hub_wall": (3000, 1024),
    "hub_pillar": (1800, 1024),
    "hub_rune": (450, 512),
    "hub_gate": (2600, 1024),
    "hub_doors": (600, 1024),
    "hub_prop": (1500, 1024),
}

## id: raw file, role, and its frame: "ring" (the wall), "height" / "width" (even scale, m), "size" (W x H x D m);
## "cut" (a region or piece rule); "frame_of" (frame the cut by the whole raw file's bounds).
SPECS = {
    "hub_wall_segment": {"src": "hub_wall_segment.glb", "role": "hub_wall", "ring": True},
    "hub_pillar_brazier": {"src": "hub_pillar_brazier.glb", "role": "hub_pillar", "height": 3.6},
    "hub_floor_rune": {"src": "hub_floor_rune.glb", "role": "hub_rune", "size": (1.25, 0.14, 1.25)},
    "hub_sealed_gate": {"src": "hub_sealed_gate.glb", "role": "hub_gate", "width": 6.4, "cut": "gate_frame",
                        "frame_of": True},
    "hub_sealed_gate_doors": {"src": "hub_sealed_gate.glb", "role": "hub_doors", "width": 6.4, "cut": "gate_doors",
                              "frame_of": True},
    "hub_credits_stone": {"src": "hub_props.glb", "role": "hub_prop", "width": 2.2, "cut": "props_credits"},
    "hub_trophy_wall": {"src": "hub_props.glb", "role": "hub_prop", "width": 3.8, "cut": "props_trophy"},
    "hub_crates": {"src": "hub_props.glb", "role": "hub_prop", "width": 1.9, "cut": "props_crates"},
    "hub_crystal_planter": {"src": "hub_props.glb", "role": "hub_prop", "height": 2.4, "cut": "props_planter"},
}

PROP_BANDS = {"props_credits": (-1.0, -0.25), "props_trophy": (-0.25, 0.11), "props_crates": (0.11, 0.36),
              "props_planter": (0.36, 1.0)}


def cut(P, I, rule):
    """The raw triangles one output keeps."""
    if rule in ("gate_frame", "gate_doors"):
        c = P[I].mean(1)
        doors = (np.abs(c[:, 0]) < 0.195) & (c[:, 2] < -0.012) & (c[:, 1] < 0.6)
        return I[doors] if rule == "gate_doors" else I[~doors]
    lo, hi = PROP_BANDS[rule]
    ext = P.max(0) - P.min(0)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    comp = mi_prep.components(len(W), J)
    tc = comp[J[:, 0]]
    n = tc.max() + 1
    cx = np.bincount(tc, weights=W[J].mean(1)[:, 0], minlength=n) / np.maximum(np.bincount(tc, minlength=n), 1)
    sel = (cx >= lo) & (cx < hi)
    return I[sel[tc]]


def bend_to_ring(P):
    """The wall in the hub's frame: scaled to one segment, straightened, wrapped onto the ring (see the docstring)."""
    lo, hi = P.min(0), P.max(0)
    Q = P - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    arc = RING_R * np.radians(SEGMENT_DEG)  # the inner face's length (m)
    s = arc / (hi[0] - lo[0])
    Q[:, 0] *= s
    Q[:, 2] *= s
    Q[:, 1] *= WALL_HEIGHT / (hi[1] - lo[1])
    # The raw section's mid-surface: z = a x^2 + b x + c (least squares over every vertex).
    A = np.stack([Q[:, 0] ** 2, Q[:, 0], np.ones(len(Q))], 1)
    coef, *_ = np.linalg.lstsq(A, Q[:, 2], rcond=None)
    straight = Q[:, 2] - A @ coef  # the depth off the mid-surface, +Z toward the inner face
    depth = straight.max() - straight  # 0 at the inner face's front, growing outward
    phi = Q[:, 0] / RING_R
    rho = RING_R + depth
    # Middle on +Z, the inner face toward the origin; the raw right (+x, seen from the front) stays on the viewer's
    # right for someone standing in the plaza (looking along +Z, the right is -X).
    return np.stack([-rho * np.sin(phi), Q[:, 1], rho * np.cos(phi)], 1)


def framed(P, spec, whole=None):
    """Even scale onto the spec's width / height; centred on x/z, bottom at y = 0 (on `whole`'s bounds when given)."""
    ref = whole if whole is not None else P
    lo, hi = ref.min(0), ref.max(0)
    Q = P - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    ext = np.maximum(hi - lo, 1e-9)
    if "size" in spec:
        return Q * (np.asarray(spec["size"], float) / ext)
    if "width" in spec:
        return Q * (spec["width"] / ext[0])
    return Q * (spec["height"] / ext[1])


def prepare(rid):
    spec = dict(SPECS[rid])
    whole = None
    if spec.get("frame_of"):
        whole, _uv, _i, _c = mi_prep.read_glb(os.path.join(SRC, spec["src"]))

    def to_frame(P, s):
        return bend_to_ring(P) if s.get("ring") else framed(P, s, whole)

    mi2_prep.SRC = SRC
    mi2_prep.OUT = OUT
    mi2_prep.BUDGET[spec["role"]] = ROLES[spec["role"]]
    mi2_prep.to_game_frame = to_frame
    mi2_prep.pick = cut
    m2 = {"src": spec["src"], "role": spec["role"], "folder": "hub", "yaw": 0.0}
    for k in ("ring", "size", "width", "height"):
        if k in spec:
            m2[k] = spec[k]
    if "cut" in spec:
        m2["pick"] = spec["cut"]
    mi2_prep.SPECS[rid] = m2
    return mi2_prep.prepare(rid)


# --- textures ------------------------------------------------------------------------------------------------------

GROUND_PX = 1024


def _out(name, img, raw_size):
    os.makedirs(TEX_OUT, exist_ok=True)
    p = os.path.join(TEX_OUT, name + ".png")
    img.save(p)
    return {"id": name, "raw_px": list(raw_size), "px": list(img.size), "path": p.replace(os.sep, "/"),
            "bytes": os.path.getsize(p), "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()}


def _sockets(a, cx, cy, R):
    """The medallion's sockets: centres of bronze rings on its socket band (score: bronze on a circle of the socket's
    ring radius, none just inside it), the best 14 apart by 10 degrees or more."""
    r, b = a[..., 0], a[..., 2]
    bronze = ((r - b > 35) & (r > 100)).astype(float)
    th = np.linspace(0, 2 * np.pi, 90, endpoint=False)
    ring = np.stack([np.cos(th), np.sin(th)], 1)
    rad = 0.09 * R
    cands = []
    for d in np.arange(0.72, 0.85, 0.005) * R:
        for deg in np.arange(0.0, 360.0, 0.5):
            t = np.radians(deg)
            c = np.array([cx + np.cos(t) * d, cy - np.sin(t) * d])
            on = (c + ring * rad).astype(int)
            inn = (c + ring * rad * 0.6).astype(int)
            cands.append((bronze[on[:, 1], on[:, 0]].mean() - bronze[inn[:, 1], inn[:, 0]].mean(), c[0], c[1]))
    cands.sort(key=lambda v: -v[0])
    picked = []
    for s, x, y in cands:
        deg = np.degrees(np.arctan2(cy - y, x - cx)) % 360
        if all(min(abs(deg - q[0]), 360 - abs(deg - q[0])) > 10 for q in picked):
            picked.append((deg, x, y, s))
        if len(picked) == 14:
            break
    return picked


def prepare_textures():
    out = []
    src = Image.open(os.path.join(SRC, "hub_ground.png")).convert("RGB")
    out.append(_out("hub_ground", src.resize((GROUND_PX, GROUND_PX), Image.LANCZOS), src.size))
    src = Image.open(os.path.join(SRC, "hub_ground_path.png")).convert("RGB")
    w, h = src.size
    out.append(_out("hub_ground_path", src.resize((GROUND_PX, round(GROUND_PX * h / w)), Image.LANCZOS), src.size))
    src = Image.open(os.path.join(SRC, "hub_ground_centre.png")).convert("RGBA")
    a = np.asarray(src).astype(float)
    ys, xs = np.nonzero(a[..., 3] > 128)
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    R = (xs.max() - xs.min() + ys.max() - ys.min()) / 4
    found = _sockets(a, cx, cy, R)
    # The circle through the sockets (algebraic least squares): its centre is the medallion's.
    X = np.array([[f[1], f[2]] for f in found])
    M = np.column_stack([2 * X, np.ones(len(X))])
    sol, *_ = np.linalg.lstsq(M, (X ** 2).sum(1), rcond=None)
    fx, fy = sol[0], sol[1]
    fr = float(np.sqrt(sol[2] + fx ** 2 + fy ** 2))
    half = max(fx - xs.min(), xs.max() - fx, fy - ys.min(), ys.max() - fy) + 2
    box = (int(round(fx - half)), int(round(fy - half)), int(round(fx + half)), int(round(fy + half)))
    img = src.crop(box)
    ox, oy = fx - box[0], fy - box[1]
    # The top socket's patch, turned, copied to 3 and 9 o'clock (a soft round edge).
    top = min(found, key=lambda f: abs(f[0] - 90.0))
    pr = int(0.12 * fr)
    tx, ty = top[1] - box[0], top[2] - box[1]
    patch = img.crop((int(tx - pr), int(ty - pr), int(tx + pr), int(ty + pr)))
    yy, xx = np.mgrid[0 : 2 * pr, 0 : 2 * pr]
    dist = np.sqrt((xx - pr + 0.5) ** 2 + (yy - pr + 0.5) ** 2) / pr
    mask = Image.fromarray((np.clip((1.0 - dist) / 0.15, 0.0, 1.0) * 255).astype(np.uint8))
    for deg, turn in ((0.0, -90), (180.0, 90)):
        t = np.radians(deg)
        px, py = ox + np.cos(t) * fr, oy - np.sin(t) * fr
        img.paste(patch.rotate(turn), (int(round(px - pr)), int(round(py - pr))), mask.rotate(turn))
    scale = GROUND_PX / img.size[0]
    angles = sorted([round(float(np.degrees(np.arctan2(fy - f[2], f[1] - fx)) % 360), 1) for f in found] + [0.0, 180.0])
    med = _out("hub_ground_centre", img.resize((GROUND_PX, GROUND_PX), Image.LANCZOS), src.size)
    med["socket_share"] = round(fr / half, 4)
    med["socket_angles_deg"] = angles
    med["centre_px"] = [round(ox * scale, 1), round(oy * scale, 1)]
    out.append(med)
    for o in out:
        print(json.dumps(o))


def main():
    ids = sys.argv[1:] or list(SPECS) + ["textures"]
    for rid in ids:
        if rid == "textures":
            prepare_textures()
            continue
        print(json.dumps(prepare(rid)), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
