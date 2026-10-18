"""v0.8.0 Step BD: cuts the owner's five boss doors (unprocessed_images/models_v080/boss_door_<biome>.glb) into the
game's door: a frame (two jambs and the lintel between them) and the slab that sinks into the floor.

The raw files are Tripo exports of a closed door (46-49k triangles, a 4096 px colour map, about 1 unit wide, the
opening along raw x, the front face +z). The raw files stay untouched. For each door this script:
1. reads where the slab is (CUTS, measured from front and back depth renders of the raw file: the groove round the
   slab, its top, the slab's front and back faces) and finds the round socket in the slab's middle on each face
   (socket(): the sunken disc on a depth grid of the slab's faces);
2. turns the door into the game's local frame (BossDoorView: the gap along Z, +X into the boss room, the front face
   toward -X, the approach): scaled evenly so the slab is SLAB_H tall (about 18 % over the code-made door's 2.2 m),
   the depth (X) to DEPTH_SHARE of that scale (the raw frame is about twice as deep as the request's), centred on
   the opening;
3. splits every triangle across the cut planes (the opening's two sides, the slab's top, the slab's box in front of
   and behind it) and sorts the pieces into four parts: `jamb_n` and `jamb_p` (the frame beyond each side of the
   opening, all heights), `lintel` (the frame over and in front of the opening) and `slab` (inside the opening, under
   the lintel, within the slab's box). The game keeps each jamb unscaled at its side of the gap and stretches the
   lintel and the slab along the gap to the sim's door width, so the seams (on the cut planes) meet at any width;
4. simplifies each part apart (meshoptimizer, borders locked so the seams and cuts stay on their planes) to the
   budgets (FRAME_BUDGET over the three frame parts, SLAB_BUDGET), then caps the cuts: the jambs' inner faces and the
   lintel's underside where the slab was, the slab's top and sides, flat quads over the slab's thickness;
5. gives the whole a new UV atlas (xatlas), bakes the raw colour map onto it (mi_prep's bake: nearest raw surface,
   TEX_PX), and writes assets/models/doors/boss_door_<biome>.glb (one node per part, its origin at its pivot).
It prints, per door, the triangle counts, the sizes and the socket (paste them into BossDoorModels.SPECS, the
manifest and the evidence by hand).

Run from the repo root:  python3 -I scripts/assets/bd_prep.py [biomes...]
Needs what mi_prep.py needs (numpy, Pillow, meshoptimizer==0.2.30a0, xatlas==0.0.11, scipy; offline tool).
"""

import hashlib
import io
import json
import os
import sys

import numpy as np
import xatlas
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mi_prep  # noqa: E402  (the shared bake, simplify and glb writer)

SRC = "unprocessed_images/models_v080"
OUT = "assets/models/doors"
BIOMES = ["ruins", "night_rocks", "red_canyon", "frozen_shore", "starfall"]
## The slab's height in game metres: the code-made door's 2.2 m slab x 1.18 (owner: "15-20% bigger").
SLAB_H = 2.6
## The depth (game X) as a share of the even scale.
DEPTH_SHARE = 0.65
FRAME_BUDGET = 5000
SLAB_BUDGET = 1500
TEX_PX = 1024
LINTEL_WEIGHT = 2.0
## How far (raw units) in front of and behind the slab's faces its box reaches (its chains and carvings).
RELIEF = 0.03

## Per door, in raw units (from depth renders of the raw file, front and back, median over bands): the groove's
## middle on the opening's -x and +x sides, the groove over the slab's top, and the slab's front (+z) and back faces.
CUTS = {
    "ruins": {"x_neg": -0.200, "x_pos": 0.209, "top": 0.398, "front": 0.023, "back": -0.024},
    "night_rocks": {"x_neg": -0.228, "x_pos": 0.214, "top": 0.431, "front": 0.053, "back": -0.055},
    "red_canyon": {"x_neg": -0.188, "x_pos": 0.201, "top": 0.381, "front": 0.051, "back": -0.028},
    "frozen_shore": {"x_neg": -0.188, "x_pos": 0.193, "top": 0.389, "front": 0.035, "back": -0.051},
    "starfall": {"x_neg": -0.198, "x_pos": 0.201, "top": 0.400, "front": 0.059, "back": -0.044},
}


def split_plane(V, T, axis, value):
    """Splits every triangle crossing the plane V[axis] = value; new vertices are shared along each cut edge."""
    d = V[:, axis] - value
    eps = 1e-9
    side = np.where(d > eps, 1, np.where(d < -eps, -1, 0))
    s = side[T]
    crossing = (s.max(1) == 1) & (s.min(1) == -1)
    if not crossing.any():
        return V, T
    newV = list(V)
    cache = {}

    def cut(a, b):
        key = (a, b) if a < b else (b, a)
        if key not in cache:
            pa, pb = V[key[0]], V[key[1]]
            t = (value - pa[axis]) / (pb[axis] - pa[axis])
            p = pa + (pb - pa) * t
            p[axis] = value
            cache[key] = len(newV)
            newV.append(p)
        return cache[key]

    out = [T[~crossing]]
    extra = []
    for tri in T[crossing]:
        sv = side[tri]
        # Rotate so the lone vertex (on its own side, or on the plane) comes first.
        for r in range(3):
            a, b, c = tri[r], tri[(r + 1) % 3], tri[(r + 2) % 3]
            sa, sb, sc = side[a], side[b], side[c]
            if sa == 0 and sb * sc < 0:  # one vertex on the plane, the edge b-c crosses
                m = cut(b, c)
                extra += [[a, b, m], [a, m, c]]
                break
            if sa != 0 and sb != 0 and sc != 0 and sa != sb and sb == sc:
                m1, m2 = cut(a, b), cut(a, c)
                extra += [[a, m1, m2], [m1, b, c], [m1, c, m2]]
                break
            if sa != 0 and sb == 0 and sc == -sa:
                m = cut(a, c)
                extra += [[a, b, m], [m, b, c]]
                break
        else:
            raise RuntimeError("triangle not split: %s" % sv)
    out.append(np.array(extra, np.int64))
    return np.array(newV), np.concatenate(out)


def socket(P, I, fn, cut, face):
    """The sunken round socket on the slab's front (face = 1) or back (-1) face: its centre (raw x, y), radius and
    depth (raw z), from a 0.008-unit grid of the outermost surface over the slab's middle."""
    c = P[I].mean(1)
    lim = cut["front"] if face > 0 else cut["back"]
    m = (
        (c[:, 0] > cut["x_neg"] + 0.03) & (c[:, 0] < cut["x_pos"] - 0.03)
        & (c[:, 1] > 0.03) & (c[:, 1] < cut["top"] - 0.03)
        & (fn[:, 2] * face > 0.5) & (np.abs(c[:, 2] - lim) < 0.06)
    )
    cell = 0.008
    gx = np.floor(c[m, 0] / cell).astype(int)
    gy = np.floor(c[m, 1] / cell).astype(int)
    z = c[m, 2] * face
    best = {}
    for x, y, v in zip(gx, gy, z):
        if v > best.get((x, y), -1e9):
            best[(x, y)] = v
    keys = np.array(list(best))
    zs = np.array([best[tuple(k)] for k in keys])
    centre_x = (cut["x_neg"] + cut["x_pos"]) * 0.5
    # The socket: cells near the slab's middle sunk well under its face.
    xy = (keys + 0.5) * cell
    near = (np.abs(xy[:, 0] - centre_x) < 0.12) & (np.abs(xy[:, 1] - cut["top"] * 0.55) < 0.14)
    sunk = near & (zs < lim * face - 0.008)
    if sunk.sum() < 8:
        return None
    pts = xy[sunk]
    cx, cy = np.median(pts, 0)
    for _ in range(3):  # the disc round the median, refined (stray sunk cells in the carvings fall away)
        d = np.hypot(pts[:, 0] - cx, pts[:, 1] - cy)
        pts_in = pts[d < 0.09]
        cx, cy = pts_in.mean(0)
    d = np.hypot(pts_in[:, 0] - cx, pts_in[:, 1] - cy)
    r = float(np.percentile(d, 95)) + cell * 0.5  # cells are sampled by triangle centres: the rim's 95th percentile
    zin = zs[sunk][np.hypot(pts[:, 0] - cx, pts[:, 1] - cy) < r]
    return {"x": float(cx), "y": float(cy), "r": r, "z": float(np.median(zin) * face)}


def quad(corners, normal):
    """Two triangles over four corners in order, wound so they face `normal` (glTF: counter-clockwise front)."""
    a, b, c, d = [np.asarray(p, float) for p in corners]
    tris = [[a, b, c], [a, c, d]]
    if np.dot(np.cross(b - a, c - a), normal) < 0:
        tris = [[a, c, b], [a, d, c]]
    return np.array(tris)


def prepare(biome):
    cut = CUTS[biome]
    src_path = os.path.join(SRC, "boss_door_%s.glb" % biome)
    P0, UV, I, colour = mi_prep.read_glb(src_path)
    fn0, _ = mi_prep.face_normals(P0, I)
    sockets = {"front": socket(P0, I, fn0, cut, 1), "back": socket(P0, I, fn0, cut, -1)}
    centre = (cut["x_neg"] + cut["x_pos"]) * 0.5
    s = SLAB_H / cut["top"]
    sd = s * DEPTH_SHARE

    def game(p):  # raw -> the game's local frame
        p = np.atleast_2d(p)
        return np.stack([-p[:, 2] * sd, p[:, 1] * s, (p[:, 0] - centre) * s], 1)

    P = game(P0)
    source = mi_prep.Source(P, UV, I, colour)
    half_w = (cut["x_pos"] - cut["x_neg"]) * 0.5 * s
    x_front, x_back = -cut["front"] * sd, -cut["back"] * sd  # the slab's faces (front toward -X)
    box_lo, box_hi = -(cut["front"] + RELIEF) * sd, -(cut["back"] - RELIEF) * sd
    ext = P.max(0) - P.min(0)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    J = J[keep]
    for axis, value in ((2, -half_w), (2, half_w), (1, SLAB_H), (0, box_lo), (0, box_hi)):
        W, J = split_plane(W, J, axis, value)
    c = W[J].mean(1)
    part = np.array(["lintel"] * len(J), dtype=object)
    part[c[:, 2] < -half_w] = "jamb_n"
    part[c[:, 2] > half_w] = "jamb_p"
    inside = (np.abs(c[:, 2]) < half_w) & (c[:, 1] < SLAB_H) & (c[:, 0] > box_lo) & (c[:, 0] < box_hi)
    part[inside] = "slab"
    pivots = {
        "jamb_n": np.array([0.0, 0.0, -half_w]),
        "jamb_p": np.array([0.0, 0.0, half_w]),
        "lintel": np.zeros(3),
        "slab": np.zeros(3),
    }
    # The lintel carries the crest (the door's face): it gets LINTEL_WEIGHT times its share of the frame's budget.
    weight = {pn: (LINTEL_WEIGHT if pn == "lintel" else 1.0) * (part == pn).sum() for pn in pivots if pn != "slab"}
    frame_total = sum(weight.values())
    simplified = {}
    scale = 1.0
    for _attempt in range(6):
        for pn in pivots:
            m = part == pn
            if pn == "slab":
                share = SLAB_BUDGET
            else:
                share = max(int(round(FRAME_BUDGET * scale * weight[pn] / frame_total)), 12)
            simplified[pn] = mi_prep.simplify(W, J[m], share, lock_border=True)
        frame_after = sum(len(simplified[pn]) for pn in pivots if pn != "slab")
        if frame_after <= FRAME_BUDGET * 1.02:
            break
        scale *= FRAME_BUDGET / frame_after * 0.97
    # The caps: flat quads over the slab's thickness on the cut planes.
    xf, xb = x_front, x_back
    caps = {
        "jamb_n": [quad([[xf, 0, -half_w], [xb, 0, -half_w], [xb, SLAB_H, -half_w], [xf, SLAB_H, -half_w]], [0, 0, 1])],
        "jamb_p": [quad([[xf, 0, half_w], [xb, 0, half_w], [xb, SLAB_H, half_w], [xf, SLAB_H, half_w]], [0, 0, -1])],
        "lintel": [quad([[xf, SLAB_H, -half_w], [xb, SLAB_H, -half_w], [xb, SLAB_H, half_w], [xf, SLAB_H, half_w]],
                        [0, -1, 0])],
        "slab": [
            quad([[xf, SLAB_H, -half_w], [xb, SLAB_H, -half_w], [xb, SLAB_H, half_w], [xf, SLAB_H, half_w]], [0, 1, 0]),
            quad([[xf, 0, -half_w], [xb, 0, -half_w], [xb, SLAB_H, -half_w], [xf, SLAB_H, -half_w]], [0, 0, -1]),
            quad([[xf, 0, half_w], [xb, 0, half_w], [xb, SLAB_H, half_w], [xf, SLAB_H, half_w]], [0, 0, 1]),
        ],
    }
    atlas = xatlas.Atlas()
    order = list(pivots)
    per_part = {}
    for pn in order:
        T = simplified[pn]
        used, inv = np.unique(T.ravel(), return_inverse=True)
        V = W[used]
        Tl = inv.reshape(-1, 3)
        for q in caps[pn]:
            base = len(V)
            V = np.concatenate([V, q.reshape(-1, 3)])
            Tl = np.concatenate([Tl, base + np.arange(len(q) * 3).reshape(-1, 3)])
        per_part[pn] = (V, Tl)
        fnv = np.zeros_like(V)
        fnp, area = mi_prep.face_normals(V, Tl)
        for c3 in range(3):
            np.add.at(fnv, Tl[:, c3], fnp * area[:, None])
        fnv /= np.maximum(np.linalg.norm(fnv, axis=1), 1e-12)[:, None]
        atlas.add_mesh(V.astype(np.float32), Tl.astype(np.uint32), fnv.astype(np.float32))
    copt = xatlas.ChartOptions()
    copt.max_iterations = 2
    popt = xatlas.PackOptions()
    popt.resolution = TEX_PX
    popt.padding = mi_prep.PAD_PX // 2
    popt.bilinear = True
    popt.rotate_charts = True
    atlas.generate(copt, popt)
    while atlas.atlas_count > 1:
        popt.texels_per_unit = atlas.texels_per_unit * 0.9
        atlas.generate(copt, popt)
    img = np.zeros((TEX_PX, TEX_PX, 3))
    filled = np.zeros((TEX_PX, TEX_PX), bool)
    nodes = []
    counts = {}
    for mi, pn in enumerate(order):
        V, Tl = per_part[pn]
        vmap, idx, uvs = atlas[mi]
        idx = idx.astype(np.int64)
        pos = V[vmap]
        corner_n = mi_prep.corner_normals(V, Tl)
        uv_px = uvs * np.array([atlas.width, atlas.height]) * (TEX_PX / max(atlas.width, atlas.height, 1))
        fnp, _ = mi_prep.face_normals(pos, idx)
        p3, n3, wh = mi_prep.rasterise_faces(uv_px, idx, pos, fnp, TEX_PX)
        if len(p3):
            t, b = source.nearest(p3, n3)
            img[wh[:, 1], wh[:, 0]] = source.colour_at(t, b)
            filled[wh[:, 1], wh[:, 0]] = True
        cp = pos[idx].reshape(-1, 3)
        cn = corner_n.reshape(-1, 3)
        cu = (uvs[idx] * np.array([atlas.width, atlas.height]) / max(atlas.width, atlas.height, 1)).reshape(-1, 2)
        n_c = len(cp)
        nodes.append((pn, pivots[pn], [(0, cp - pivots[pn], cn, cu, np.arange(n_c).reshape(-1, 3))]))
        counts[pn] = len(Tl)
    img = mi_prep.dilate(img, filled, mi_prep.PAD_PX * 2)
    gain = min(max(mi_prep.BRIGHT_MEAN / max(img[filled].mean(), 1e-3), 1.0), mi_prep.BRIGHT_MAX)
    img = np.clip(img * gain, 0.0, 1.0)
    buf = io.BytesIO()
    Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8)).save(
        buf, "JPEG", quality=mi_prep.JPEG_QUALITY
    )
    os.makedirs(OUT, exist_ok=True)
    out_id = "boss_door_%s" % biome
    dst = os.path.join(OUT, out_id + ".glb")
    mi_prep.write_glb(dst, out_id, nodes, buf.getvalue(), [mi_prep.material("albedo")])
    lo, hi = W.min(0), W.max(0)
    frame = part != "slab"
    flo, fhi = W[J[frame]].reshape(-1, 3).min(0), W[J[frame]].reshape(-1, 3).max(0)
    seal = {}
    for face, sk in sockets.items():
        if sk is None:
            seal[face] = None
            continue
        g = game(np.array([sk["x"], sk["y"], sk["z"]]))[0]
        seal[face] = {"y": round(float(g[1]), 3), "z": round(float(g[2]), 3), "x": round(float(g[0]), 3),
                      "r": round(sk["r"] * s, 3)}
    return {
        "id": out_id, "raw_tris": len(I), "raw_bytes": os.path.getsize(src_path),
        "tris": counts, "frame_tris": sum(v for k, v in counts.items() if k != "slab"), "tex": TEX_PX,
        "opening_w": round(2 * half_w, 3), "slab_h": SLAB_H, "slab_x": [round(x_front, 3), round(x_back, 3)],
        "frame_size_xyz": [round(float(v), 3) for v in (fhi - flo)], "height": round(float(hi[1]), 3),
        "scale": round(s, 3), "depth_scale": round(sd, 3), "seal": seal,
        "path": dst, "bytes": os.path.getsize(dst), "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
    }


def main():
    for biome in sys.argv[1:] or BIOMES:
        print(json.dumps(prepare(biome)), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
