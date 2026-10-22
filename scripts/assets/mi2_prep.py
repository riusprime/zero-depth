"""v0.9.0 Step MI2: prepares the owner's v0.9.0 models (unprocessed_images/models_v090/new_assets_{1..4}/) and three
textures (unprocessed_images/v090_tex/) for the game, the way mi_prep.py prepared v0.8.0's (its bake, simplify and glb
writer are reused; on a PC without the meshoptimizer package its simplify() runs Godot's, gd_simplify.gd).

The raw files are Tripo exports: one textured mesh each (about 9-29k triangles; the portal machine 496k), about one unit
across, no rig. The raw files stay untouched. Per model (SPECS):
1. two files hold two models each ("(2models)" in the name, owner 2026-10-22: "some models have 2 which you will also
   have to split, it is marked in the name"): each model is one connected piece of the raw mesh, picked by the side
   of x its centre lies on (PICK). The stone spike file holds three spike clusters: the tallest is installed;
2. turned into the game's frame (yaw: raw -> game, degrees about Y), centred on x/z with its bottom at y = 0, and
   scaled: evenly to a height (m), or to fill a box (W x H x D m: the altar, low because the sim has no height);
3. cut into parts where the game moves pieces (PARTS: the elites' limbs for code animation, the owner: "enemies are
   not animted, you will have to do it manually"; the arena pillar's floating crystal), each part one glTF node with
   its origin at its pivot;
4. welded, simplified to its role's triangle budget (BUDGET; parts apart, borders locked), given a new UV atlas
   (xatlas) and the raw colour map baked onto it (mi_prep's bake), brightened like v0.8.0's room pieces unless the
   spec says DARK (the final arena's violet stone keeps its own dark colour);
5. written to assets/models/<folder>/<id>.glb. The elites get two materials per part: `base` and `glow` (their small
   bright accents: eyes, runes, crystals; GLOW_THRESHOLDS), the rest one (`albedo`).
The textures: rune_marking.png (a decal: kept as delivered, 512 px), ground_arena.png and ground_snow.png (ground
textures: the middle square made seamless by mi_prep's offset cross-fade, 1024 px) into assets/textures/kit/.

It prints, per model, one JSON line: raw triangles and file size, the triangles after (per part), the size in metres,
the file written, its size and sha256 (pasted into assets/models/manifest.json and the evidence by hand).

Run from the repo root:  python -I scripts/assets/mi2_prep.py [ids...]   (GODOT=<godot executable> without
meshoptimizer). Needs what mi_prep.py needs (numpy, Pillow, xatlas==0.0.11, scipy; meshoptimizer or Godot 4.7).
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

SRC = "unprocessed_images/models_v090"
TEX_SRC = "unprocessed_images/v090_tex"
OUT = "assets/models"
TEX_OUT = "assets/textures/kit"

## Per role: the triangle budget and the colour map's size (mi_prep's, plus the spike: up to MAX_SPIKES of it in one
## MultiMesh).
BUDGET = dict(mi_prep.BUDGET)
BUDGET["spike"] = (600, 512)
BUDGET["pedestal"] = (1000, 512)

## id: raw file (under SRC), role, folder (under OUT), yaw (degrees, raw -> game), and "height" (m, even scale) or
## "size" (W x H x D m: the box it fills), optional "pick" (the raw piece: "x-" / "x+", the connected pieces whose
## centre lies on that side of x = 0), "parts" (a PARTS rule) and "dark" (no brightening).
## Frames: a prop's front (raw +Z, the generator's) stays +Z when the view turns it itself (ShopModels yaw 0 pieces),
## else onto +X (the game's facing: elites, as v0.8.0's enemies).
SPECS = {
    # Wave 1: the arrival and the final approach. The altar fills ShopModels' 6.6 x 0.45 x 6.6 m box (SA: low, the
    # sim has no height); its stone is neutral, the game lights it blue or purple.
    "arrival_altar": {"src": "new_assets_1/arrival_altar.glb", "role": "set", "folder": "devices", "yaw": 0.0,
                      "size": (6.6, 0.45, 6.6)},
    # The causeway's stair flight: its treads climb along raw +X, a curved flight 1.0 across (raw z); in game the
    # climb runs along +X (FinalArenaStage turns it up the causeway), 3.0 m deep, low (the sim is flat).
    "approach_stairs": {"src": "new_assets_1/approach_stairs.glb", "role": "cover", "folder": "arena", "yaw": 0.0,
                        "size": (3.0, 0.5, 6.0), "dark": True},
    # The final arena's pieces (FinalArenaStage.PIECES: the code pieces' sizes; the frame is the piece's node's).
    # The wall segment: its concave face (the arena side) is raw -X, its length along raw z: kept (FinalArenaStage
    # puts +X outward, the length along the ring); 3.0 m long (one sim segment), its own proportions.
    "arena_wall_segment": {"src": "new_assets_1/arena_wall_segment.glb", "role": "cover", "folder": "arena",
                           "yaw": 0.0, "length": 3.0, "dark": True},
    "arena_pillar": {"src": "new_assets_1/arena_pillar.glb", "role": "cover", "folder": "arena", "yaw": 0.0,
                     "height": 5.0, "parts": "arena_pillar", "dark": True},
    "arena_brazier": {"src": "new_assets_1/arena_brazier.glb", "role": "cover", "folder": "arena", "yaw": 0.0,
                      "height": 1.4, "dark": True},
    # The gate: its arch's face raw +Z turned to -X (toward the arena's centre: the gate node's +X points out), its
    # width (raw x) onto z; 7.6 m across, the code gate's.
    "arena_gate": {"src": "new_assets_1/arena_gate.glb", "role": "set", "folder": "arena", "yaw": -90.0,
                   "width": 7.6, "dark": True},
    # Wave 4: the elites (heights from the art list), cut into parts, front onto +X.
    "elite_breaker": {"src": "new_assets_1/elite_breaker.glb", "role": "enemy", "folder": "enemies", "yaw": 90.0,
                      "height": 2.6, "parts": "elite_breaker"},
    "elite_rift_hunter": {"src": "new_assets_2/elite_rift_hunter.glb", "role": "enemy", "folder": "enemies",
                          "yaw": 90.0, "height": 2.1, "parts": "elite_rift_hunter"},
    "elite_conduit": {"src": "new_assets_2/elite_conduit.glb", "role": "enemy", "folder": "enemies", "yaw": 90.0,
                      "height": 2.3, "parts": "elite_conduit"},
    # Puzzles and secrets (TD, RA, DX, HF), the shrines and the dais (SH, DP): front +Z kept (the views turn them).
    # The timed door: the owner's file is a gate of iron bars with no frame, so it is the part that sinks whole (the
    # view keeps its stone frame); its width (raw x) onto z, 3.0 x 3.0 m, 0.5 m thick (TimedDoorView's slab).
    "timed_door": {"src": "new_assets_4/timed_door.glb", "role": "cover", "folder": "devices", "yaw": 90.0,
                   "size": (0.5, 3.0, 3.0)},
    "rune_switch": {"src": "new_assets_3/rune_switch.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                    "height": 1.3},
    "rune_pillar": {"src": "new_assets_3/rune_pillar.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                    "height": 2.2},
    "rune_mural": {"src": "new_assets_3/rune_mural.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                   "height": 1.6},
    "cracked_wall": {"src": "new_assets_1/cracked_wall_and_cracked_wall_broken(2models).glb", "role": "cover",
                     "folder": "devices", "yaw": 0.0, "height": 3.0, "pick": "x-"},
    "cracked_wall_broken": {"src": "new_assets_1/cracked_wall_and_cracked_wall_broken(2models).glb",
                            "role": "cover", "folder": "devices", "yaw": 0.0, "height": 3.0, "pick": "x+"},
    "healing_fountain": {"src": "new_assets_2/healing_fountain.glb", "role": "cover", "folder": "devices",
                         "yaw": 0.0, "height": 1.4},
    "shrine_blood": {"src": "new_assets_3/shrine_blood.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                     "height": 2.0},
    "shrine_chaos": {"src": "new_assets_4/shrine_chaos.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                     "height": 2.2},
    "shrine_fortune": {"src": "new_assets_3/shrine_fortune.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                       "height": 2.0},
    "purple_rune_dais": {"src": "new_assets_3/purple_rune_dais.glb", "role": "cover", "folder": "devices",
                         "yaw": 0.0, "width": 3.0},
    # The Gatekeeper's stone spike (StoneSpikeViews): the tallest of the file's three clusters.
    "stone_spike": {"src": "new_assets_3/stone_spike.glb", "role": "spike", "folder": "fx", "yaw": 0.0,
                    "height": 1.0, "pick": "x+spike", "dark": True},
    # Not used by any floor since PT (floor 1 has the altar, later floors arrive by a portal): manifest only.
    "floor_receiver": {"src": "new_assets_2/floor_receiver.glb", "role": "cover", "folder": "devices", "yaw": 0.0,
                       "width": 2.2},
    # Wave 5: the hub (HB): heights from the art list (starting values).
    "hub_portal_machine": {"src": "new_assets_4/hub_portal_machine.glb", "role": "device", "folder": "hub",
                           "yaw": 0.0, "height": 6.0},
    "hub_archive": {"src": "new_assets_2/hub_archive.glb", "role": "cover", "folder": "hub", "yaw": 0.0,
                    "height": 3.5},
    "hub_wardrobe": {"src": "new_assets_2/hub_wardrobe.glb", "role": "cover", "folder": "hub", "yaw": 0.0,
                     "height": 2.4},
    "hub_station": {"src": "new_assets_2/hub_station.glb", "role": "cover", "folder": "hub", "yaw": 0.0,
                    "height": 1.6},
    "hub_trophy_pedestal": {"src": "new_assets_2/hub_trophy_pedestal.glb", "role": "pedestal", "folder": "hub",
                            "yaw": 0.0, "height": 1.1},
    # The two pedestals in one file: the slim one with the round cradle (the art list's prompt) and a wider square
    # one with a plaque recess (`_b`).
    "hub_collectible_pedestal": {"src": "new_assets_2/hub_collectible_pedestal(2models).glb", "role": "pedestal",
                                 "folder": "hub", "yaw": 0.0, "height": 1.0, "pick": "x+"},
    "hub_collectible_pedestal_b": {"src": "new_assets_2/hub_collectible_pedestal(2models).glb", "role": "pedestal",
                                   "folder": "hub", "yaw": 0.0, "height": 1.0, "pick": "x-"},
}

## The elites' glow texels (very bright and saturated: eyes, rune inlays, crystals), as mi_prep's CLASS_THRESHOLDS:
## (unused role floor, glow value floor, glow saturation floor).
GLOW_THRESHOLDS = {
    "elite_breaker": (1.1, 0.93, 0.55),
    "elite_rift_hunter": (1.1, 0.85, 0.45),
    "elite_conduit": (1.1, 0.92, 0.35),
}


# --- picking a piece -----------------------------------------------------------------------------------------------


def pick(P, I, rule):
    """The raw triangles of one model in a file that holds several: whole connected pieces, by their centre's x."""
    ext = P.max(0) - P.min(0)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    comp = mi_prep.components(len(W), J)
    tc = comp[J[:, 0]]
    n = tc.max() + 1
    cx = np.bincount(tc, weights=W[J].mean(1)[:, 0], minlength=n) / np.maximum(np.bincount(tc, minlength=n), 1)
    if rule == "x-":
        sel = cx < 0.0
    elif rule == "x+":
        sel = cx > 0.0
    elif rule == "x+spike":  # the tallest cluster stands past x = 0.13 (with its own small rocks)
        sel = cx > 0.13
    else:
        raise ValueError(rule)
    return I[sel[tc]]


# --- parts ---------------------------------------------------------------------------------------------------------


def parts_of(rule, W, J, comp, H):
    """Per welded triangle (game frame, metres): its part, and each part's pivot. Game frame: +X front, +Y up, +Z the
    figure's right side (forward x up)."""
    c = W[J].mean(1)
    n = len(J)
    lab = np.array(["body"] * n, dtype=object)
    piv = {"body": np.zeros(3)}
    tri_comp = comp[J[:, 0]]
    sizes = np.bincount(tri_comp)
    main = np.argmax(sizes)
    lo_y = np.full(len(sizes), np.inf)
    np.minimum.at(lo_y, tri_comp, W[J].min(1)[:, 1])
    floating = (np.arange(len(sizes)) != main) & (lo_y > 0.05 * H)

    def take(mask, name, pivot):
        mask = mask & (lab == "body")
        if mask.any():
            lab[mask] = name
            piv[name] = np.asarray(pivot, float)

    if rule == "arena_pillar":
        # The crystal floating over the column and its chips: their own pieces, above half the height.
        m = floating[tri_comp] & (lo_y[tri_comp] > 0.5 * H)
        take(m, "shard", c[m].mean(0) if m.any() else np.zeros(3))
    elif rule in ELITE_PARTS:
        ELITE_PARTS[rule](c, W, J, H, floating[tri_comp], take)
    return lab, piv


def breaker_parts(c, W, J, H, floating, take):
    """The Breaker: the huge stone right fist and its arm, the smaller left arm, the head, the slab on its back, the
    two legs; the torso stays `body`."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    take((z > 0.26 * H) & (y < 0.78 * H), "arm_r", [0.0, 0.7 * H, 0.27 * H])
    take((z < -0.24 * H) & (y < 0.74 * H), "arm_l", [0.0, 0.68 * H, -0.25 * H])
    take((x < -0.12 * H) & (y > 0.45 * H), "back_slab", [-0.15 * H, 0.62 * H, 0.0])
    take((y > 0.62 * H) & (x > 0.02 * H) & (np.abs(z) < 0.12 * H), "head", [0.04 * H, 0.66 * H, 0.0])
    take((y < 0.26 * H) & (z > 0.0), "leg_r", [0.0, 0.26 * H, 0.1 * H])
    take((y < 0.26 * H) & (z <= 0.0), "leg_l", [0.0, 0.26 * H, -0.1 * H])


def rift_hunter_parts(c, W, J, H, floating, take):
    """The Rift Hunter: the floating shards over its shoulders, the crescent head, the two blade forearms, the two
    backward legs; the torso and the cloak strips stay `body`."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    take(floating, "shards", [0.0, 0.8 * H, 0.0])
    take(y > 0.82 * H, "head", [0.0, 0.8 * H, 0.0])
    take((z > 0.2 * H) & (y > 0.25 * H), "blade_r", [0.0, 0.72 * H, 0.2 * H])
    take((z < -0.2 * H) & (y > 0.25 * H), "blade_l", [0.0, 0.72 * H, -0.2 * H])
    take((y < 0.42 * H) & (z > 0.0), "leg_r", [0.0, 0.45 * H, 0.08 * H])
    take((y < 0.42 * H) & (z <= 0.0), "leg_l", [0.0, 0.45 * H, -0.08 * H])


def conduit_parts(c, W, J, H, floating, take):
    """The Conduit: the floating rune shards, the staff (held at its side), the ring round its chest, the hooded head;
    the robe stays `body`."""
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    take(floating, "shards", [0.0, 0.7 * H, 0.0])
    # The staff: a rod held in front of the robe, leaning out to the crystal cage over its left shoulder (the line
    # fitted to the raw mesh's thin rod, 2026-10-22), with the hands on it; pivoted at the hands.
    a, b = np.array([0.097, 0.06, 0.068]) * H, np.array([0.117, 0.975, -0.343]) * H
    d = b - a
    t = np.clip(((c - a) @ d) / (d @ d), 0.0, 1.0)
    dist = np.linalg.norm(c - (a + t[:, None] * d), axis=1)
    take((dist < 0.028 * H) | ((dist < 0.1 * H) & (t > 0.75)), "staff", [0.11 * H, 0.55 * H, -0.12 * H])
    r = np.hypot(x, z)
    take((y > 0.5 * H) & (y < 0.66 * H) & (r > 0.2 * H), "ring", [0.0, 0.58 * H, 0.0])
    take(y > 0.72 * H, "head", [0.0, 0.72 * H, 0.0])


ELITE_PARTS = {
    "elite_breaker": breaker_parts,
    "elite_rift_hunter": rift_hunter_parts,
    "elite_conduit": conduit_parts,
}


# --- one model -----------------------------------------------------------------------------------------------------


def to_game_frame(P, spec):
    a = np.radians(spec["yaw"])
    R = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    Q = P @ R.T
    lo, hi = Q.min(0), Q.max(0)
    Q = Q - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    ext = np.maximum(hi - lo, 1e-9)
    if "size" in spec:
        s = np.asarray(spec["size"], float) / ext
    elif "length" in spec:  # along z
        s = np.full(3, spec["length"] / ext[2])
    elif "width" in spec:  # the larger of x and z
        s = np.full(3, spec["width"] / max(ext[0], ext[2]))
    else:
        s = np.full(3, spec["height"] / ext[1])
    return Q * s


def prepare(rid):
    spec = SPECS[rid]
    role = spec["role"]
    budget, tex_px = BUDGET[role]
    src_path = os.path.join(SRC, spec["src"])
    P0, UV, I0, colour = mi_prep.read_glb(src_path)
    I = pick(P0, I0, spec["pick"]) if "pick" in spec else I0
    # Only the picked piece's vertices (its bounds then frame it).
    used, inv = np.unique(I.ravel(), return_inverse=True)
    P = to_game_frame(P0[used], spec)
    UVp = UV[used]
    I = inv.reshape(-1, 3)
    source = mi_prep.Source(P, UVp, I, colour)
    ext = P.max(0) - P.min(0)
    W, J, keep = mi_prep.weld(P, I, ext.max() * 2e-5)
    J = J[keep]
    elite = rid in GLOW_THRESHOLDS
    if "parts" in spec:
        comp = mi_prep.components(len(W), J)
        part, pivots = parts_of(spec["parts"], W, J, comp, ext[1])
    else:
        part = np.array(["body"] * len(J), dtype=object)
        pivots = {"body": np.zeros(3)}
    if elite:
        cen = W[J].mean(1)
        fn, _ = mi_prep.face_normals(W, J)
        t, b = source.nearest(cen, fn, k=6)
        glow = (mi_prep.classify_texels(source.colour_at(t, b), GLOW_THRESHOLDS[rid]) == 2).astype(int) * 2
    else:
        glow = np.zeros(len(J), int)
    groups = sorted({(p, k) for p, k in zip(part, glow)}, key=lambda g: (g[0], g[1]))
    total = len(J)
    scale = 1.0
    for _attempt in range(6):
        simplified = {}
        for g in groups:
            m = (part == g[0]) & (glow == g[1])
            share = max(int(round(budget * scale * m.sum() / total)), 24 if g[1] == 2 else 12)
            simplified[g] = mi_prep.simplify(W, J[m], share, lock_border=len(groups) > 1)
        tris_after = sum(len(v) for v in simplified.values())
        if tris_after <= budget * 1.02:
            break
        scale *= budget / tris_after * 0.97
    atlas = xatlas.Atlas()
    order = sorted(pivots)
    per_part = {}
    for pn in order:
        T = np.concatenate([simplified[g] for g in groups if g[0] == pn] or [np.zeros((0, 3), np.int64)])
        K = np.concatenate([np.full(len(simplified[g]), g[1]) for g in groups if g[0] == pn] or [np.zeros(0, int)])
        if len(T) == 0:
            continue
        u, iv = np.unique(T.ravel(), return_inverse=True)
        V = W[u]
        Tl = iv.reshape(-1, 3)
        per_part[pn] = (V, Tl, K)
        fnv = np.zeros_like(V)
        fn, area = mi_prep.face_normals(V, Tl)
        for c3 in range(3):
            np.add.at(fnv, Tl[:, c3], fn * area[:, None])
        fnv /= np.maximum(np.linalg.norm(fnv, axis=1), 1e-12)[:, None]
        atlas.add_mesh(V.astype(np.float32), Tl.astype(np.uint32), fnv.astype(np.float32))
    copt = xatlas.ChartOptions()
    copt.max_iterations = 2
    popt = xatlas.PackOptions()
    popt.resolution = tex_px
    popt.padding = mi_prep.PAD_PX // 2
    popt.bilinear = True
    popt.rotate_charts = True
    atlas.generate(copt, popt)
    while atlas.atlas_count > 1:
        popt.texels_per_unit = atlas.texels_per_unit * 0.9
        atlas.generate(copt, popt)
    img = np.zeros((tex_px, tex_px, 3))
    filled = np.zeros((tex_px, tex_px), bool)
    nodes = []
    names = [pn for pn in order if pn in per_part]
    for mi, pn in enumerate(names):
        V, Tl, K = per_part[pn]
        vmap, idx, uvs = atlas[mi]
        idx = idx.astype(np.int64)
        pos = V[vmap]
        corner_n = mi_prep.corner_normals(V, Tl)
        uv_px = uvs * np.array([atlas.width, atlas.height]) * (tex_px / max(atlas.width, atlas.height, 1))
        fnp, _ = mi_prep.face_normals(pos, idx)
        p3, n3, wh = mi_prep.rasterise_faces(uv_px, idx, pos, fnp, tex_px)
        if len(p3):
            t, b = source.nearest(p3, n3)
            img[wh[:, 1], wh[:, 0]] = source.colour_at(t, b)
            filled[wh[:, 1], wh[:, 0]] = True
        cp = pos[idx].reshape(-1, 3)
        cn = corner_n.reshape(-1, 3)
        cu = (uvs[idx] * np.array([atlas.width, atlas.height]) / max(atlas.width, atlas.height, 1)).reshape(-1, 2)
        prims = []
        for k in (0, 2):
            sel = np.where(K == k)[0]
            if len(sel) == 0:
                continue
            ci = (sel[:, None] * 3 + np.arange(3)[None]).ravel()
            prims.append(((1 if k == 2 else 0) if elite else 0, cp[ci] - pivots[pn], cn[ci], cu[ci],
                          np.arange(len(ci)).reshape(-1, 3)))
        nodes.append((pn, pivots[pn], prims))
    img = mi_prep.dilate(img, filled, mi_prep.PAD_PX * 2)
    gain = 1.0
    if not elite and not spec.get("dark") and filled.any():
        gain = min(max(mi_prep.BRIGHT_MEAN / max(img[filled].mean(), 1e-3), 1.0), mi_prep.BRIGHT_MAX)
        img = np.clip(img * gain, 0.0, 1.0)
    buf = io.BytesIO()
    Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8)).save(
        buf, "JPEG", quality=mi_prep.JPEG_QUALITY
    )
    mats = [mi_prep.material("base"), mi_prep.material("glow", [1.0, 1.0, 1.0])] if elite else [
        mi_prep.material("albedo")
    ]
    os.makedirs(os.path.join(OUT, spec["folder"]), exist_ok=True)
    dst = os.path.join(OUT, spec["folder"], rid + ".glb")
    mi_prep.write_glb(dst, rid, nodes, buf.getvalue(), mats)
    return {
        "id": rid, "raw": spec["src"], "raw_tris": len(I0), "picked_tris": len(I), "raw_bytes": os.path.getsize(src_path),
        "tris": tris_after, "budget": budget, "tex": tex_px, "gain": round(gain, 2), "backend": mi_prep.BACKEND,
        "size": [round(float(v), 3) for v in ext], "path": dst.replace(os.sep, "/"), "bytes": os.path.getsize(dst),
        "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
        "parts": {pn: [len(per_part[pn][1]), int((per_part[pn][2] == 2).sum()), [round(float(v), 3) for v in pivots[pn]]]
                  for pn in names},
    }


# --- textures ------------------------------------------------------------------------------------------------------

GROUND_PX = 1024


def prepare_textures():
    os.makedirs(TEX_OUT, exist_ok=True)
    out = []
    for name in ("ground_arena", "ground_snow"):
        src = Image.open(os.path.join(TEX_SRC, name + ".png")).convert("RGB")
        w, h = src.size
        s = min(w, h)
        sq = src.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
        a = np.asarray(sq).astype(float)
        tex = Image.fromarray(mi_prep.seamless_blend(a).round().clip(0, 255).astype(np.uint8)).resize(
            (GROUND_PX, GROUND_PX), Image.LANCZOS
        )
        p = os.path.join(TEX_OUT, name + ".png")
        tex.save(p)
        out.append((name, p, src.size))
    src = Image.open(os.path.join(TEX_SRC, "rune_marking.png")).convert("RGBA")
    if max(src.size) > 512:
        src = src.resize((512, 512), Image.LANCZOS)
    p = os.path.join(TEX_OUT, "rune_marking.png")
    src.save(p)
    out.append(("rune_marking", p, Image.open(os.path.join(TEX_SRC, "rune_marking.png")).size))
    for name, p, raw in out:
        print(json.dumps({"id": name, "raw_px": list(raw), "path": p.replace(os.sep, "/"),
                          "bytes": os.path.getsize(p), "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()}))


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
