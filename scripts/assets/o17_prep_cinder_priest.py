"""v0.11.0 Step O17d: prepares the owner's Cinder Priest (unprocessed_images/models_v0110/cinder_priest.glb, a Tripo
export: one textured mesh, 9,193 triangles, one connected piece, about 1 unit tall, no rig, its front on raw +Z) for
the game, through mi_prep.py's enemy path (the one mi2_prep.py builds on): turned so its front is +X, scaled to
HEIGHT_M, cut into the parts CinderPriestAvatar moves, each part simplified apart (borders locked) into `base`
(charcoal, bone), `role` (the violet plates, greyscale in the texture so the game tints them) and `glow` (the ember
crystal and the gem visor), one UV atlas and the raw colour map baked onto it, written to
assets/models/enemies/cinder_priest.glb.

The parts (game frame: +X its front, +Y up, +Z its right side; heights as shares of the model's height h):
- `staff`: the tall rod (a line fitted to the raw mesh, 2026-11-08), the three-pronged claw and ember crystal on top,
  and the right hand gripping it; pivoted at the grip (the hand), so the arm carries it and it tilts in the hand;
- `arm_r`: the right forearm and upper arm reaching to the grip, pivoted at the right shoulder;
- `arm_l`: the free left arm hanging at its side with its open bone hand, pivoted at the left shoulder;
- `hood`: the tall pointed hood with the face plate and visor, above the shoulders, pivoted at the neck;
- `hem`: the robe below the waist belt with its ring of hem spikes, pivoted at the waist (it sways and trails);
- `body`: the rest (the chest, the shoulder capes, the belt), pivoted at the waist.

No xatlas wheel exists for this PC's Python 3.14 (and no compiler to build one): when `import xatlas` fails, mi_prep
gets XATLAS_VIA_GODOT, an xatlas stand-in that runs Godot's own embedded xatlas (scripts/assets/gd_unwrap.gd,
ArrayMesh.lightmap_unwrap) over every part at once. meshoptimizer isn't on Windows either: mi_prep simplifies through
Godot (gd_simplify.gd). Both need GODOT=<godot executable> (else `godot` on the PATH).

It prints one JSON line: raw triangles and file size, the triangles after (per part, with its pivot), the size in
metres, the file written, its size and sha256 (pasted into assets/models/manifest.json and the evidence by hand).

Run from the repo root:  python scripts/assets/o17_prep_cinder_priest.py   (GODOT=<godot executable>)
Needs: numpy, Pillow, scipy (and xatlas==0.0.11 where it installs; Godot 4.7 otherwise).
"""

import json
import os
import struct
import subprocess
import sys
import tempfile
import types

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

RID = "cinder_priest"
SRC = "unprocessed_images/models_v0110"
## The art list's height with the staff (docs/art/requests/v0.11.0_enemy_models.md: about 1.8 m; the stand-in's 1.75).
HEIGHT_M = 1.75
## Raw front +Z (read from scripts/shots/mi_models.gd's render, 2026-11-08) onto the game's +X.
YAW = 90.0
## Its triangle budget and colour map (the brief: about 5-7k triangles after simplify).
BUDGET = (6000, 1024)
## Texel classes (mi_prep.classify_texels): role saturation floor, glow value floor, glow saturation floor. The violet
## plates are saturated and darker than the ember crystal (value about 0.96) and the gem visor.
THRESHOLDS = (0.22, 0.74, 0.40)
## Where a glow texel may be (shares of the height): the ember crystal over the staff's claw and the gem visor on the
## face plate; a bright chipped edge elsewhere stays a plate.
CRYSTAL_ZONE = (0.69, 0.12)  # above this height and right of this z
VISOR_ZONE = (0.04, 0.72, 0.80, -0.025, 0.06)  # x over, height between, z within of
## Greys at or under this saturation are made neutral (the biomes tint them; a violet-tinged charcoal fights the tint).
NEUTRAL_SAT = 0.14

# --- the staff and the parts (shares of the model's height; game frame) -------------------------------------------
## The staff's rod: a vertical line through (x, z), from the floor to the claw.
STAFF_XZ = (0.12, 0.21)
STAFF_R = 0.034
STAFF_FOOT_R = 0.024  # near the floor, where the hem's spike ring meets it
CLAW_FROM = 0.70
CLAW_R = 0.115
GRIP = (0.11, 0.555, 0.205)  # the right hand round the rod
GRIP_R = 0.075
WAIST = 0.43  # the belt's lower edge: the hem below, the body above
NECK = 0.69
SHOULDER_R = (0.0, 0.63, 0.13)
SHOULDER_L = (-0.02, 0.62, -0.13)


def priest_parts(W, J, H):
    """Per welded triangle (game frame, metres): its part, and each part's pivot."""
    c = W[J].mean(1) / H
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    lab = np.array(["body"] * len(J), dtype=object)
    piv = {"body": np.array([0.0, WAIST, 0.0]) * H}

    def take(mask, name, pivot):
        mask = mask & (lab == "body")
        if mask.any():
            lab[mask] = name
            piv[name] = np.asarray(pivot, float) * H

    rod = np.hypot(x - STAFF_XZ[0], z - STAFF_XZ[1])
    grip = np.linalg.norm(c - np.array(GRIP), axis=1)
    staff = ((rod < STAFF_R) & (y > 0.09) & (y < CLAW_FROM + 0.02)) | ((rod < STAFF_FOOT_R) & (y <= 0.09))
    staff |= (y >= CLAW_FROM) & (rod < CLAW_R) & (z > 0.13)
    staff |= (grip < GRIP_R) & (z > 0.135)
    take(staff, "staff", GRIP)
    take((z > 0.105) & (y > 0.445) & (y < 0.62), "arm_r", SHOULDER_R)
    take((z < -0.14) & (y > 0.31) & (y < 0.64), "arm_l", SHOULDER_L)
    take(y > NECK, "hood", (0.0, NECK, -0.03))
    take(y < WAIST, "hem", (0.0, WAIST, 0.0))
    return lab, piv


# --- an xatlas stand-in: Godot's own (gd_unwrap.gd) -----------------------------------------------------------------
GD_UNWRAP = "scripts/assets/gd_unwrap.gd"


class _Options:
    """xatlas.ChartOptions / PackOptions: plain attributes (resolution and padding are read)."""

    resolution = 1024
    padding = 3


class _GodotAtlas:
    """The calls mi_prep.prepare makes on an xatlas.Atlas, answered by one Godot lightmap unwrap of every mesh added:
    atlas[i] -> (each new vertex's input vertex, the faces (input order and corner order), its UVs 0..1); width and
    height 1 (so mi_prep's uv * size * (tex_px / max size) is uv * tex_px); always one atlas page."""

    def __init__(self):
        self._meshes = []
        self._out = []
        self.width = 1
        self.height = 1
        self.atlas_count = 0
        self.texels_per_unit = 0.0

    def add_mesh(self, V, T, N):
        self._meshes.append((np.asarray(V, np.float32), np.asarray(T, np.uint32), np.asarray(N, np.float32)))

    def __getitem__(self, i):
        return self._out[i]

    def generate(self, chart_options=None, pack_options=None):
        res = int(getattr(pack_options, "resolution", 1024))
        pad = max(int(getattr(pack_options, "padding", 3)), 1)
        area = 0.0
        for V, T, _ in self._meshes:
            Td = T.astype(np.int64)
            area += 0.5 * np.linalg.norm(np.cross(V[Td[:, 1]] - V[Td[:, 0]], V[Td[:, 2]] - V[Td[:, 0]]), axis=1).sum()
        # Godot pads charts by one of its texels: its atlas about res / pad texels across (so the gap is about `pad`
        # output pixels), the charts filling about half of it.
        texel = float(np.sqrt(area / 0.5)) / (res / pad)
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = os.path.join(tmp, "in.bin"), os.path.join(tmp, "out.bin")
            with open(src, "wb") as f:
                f.write(struct.pack("<I", len(self._meshes)))
                for V, T, N in self._meshes:
                    f.write(struct.pack("<II", len(V), len(T)) + V.tobytes() + N.tobytes() + T.tobytes())
            godot = os.environ.get("GODOT", "godot")
            r = subprocess.run([godot, "--headless", "--path", ".", "-s", GD_UNWRAP, "--", src, dst, repr(texel)],
                               capture_output=True, text=True)
            if r.returncode != 0 or not os.path.exists(dst):
                raise RuntimeError("gd_unwrap failed (%d): %s" % (r.returncode, (r.stdout + r.stderr)[-2000:]))
            data = open(dst, "rb").read()
        o = 4
        n = struct.unpack_from("<I", data, 0)[0]
        assert n == len(self._meshes), (n, len(self._meshes))
        self._out = []
        for V, T, _ in self._meshes:
            nv, ni = struct.unpack_from("<II", data, o)
            o += 8
            P = np.frombuffer(data, np.float32, nv * 3, o).reshape(-1, 3)
            o += nv * 12
            UVs = np.frombuffer(data, np.float32, nv * 2, o).reshape(-1, 2).astype(np.float64)
            o += nv * 8
            idx = np.frombuffer(data, np.uint32, ni, o).astype(np.int64).reshape(-1, 3)
            o += ni * 4
            assert len(idx) == len(T), ("faces dropped", len(idx), len(T))
            # Godot's surface rebuild may reorder the faces: each output face is matched to its input face by its
            # corners' places (a KD-tree on the face centres, then corner by corner), and the faces and corners put
            # back in the input's order (mi_prep gives corner normals per input face and corner).
            Td = T.astype(np.int64)
            tree = cKDTree(V[Td].mean(1))
            _, src_face = tree.query(P[idx].mean(1))
            assert len(np.unique(src_face)) == len(Td), ("faces not one to one", len(np.unique(src_face)), len(Td))
            d = np.linalg.norm(P[idx][:, :, None, :] - V[Td[src_face]][:, None, :, :], axis=-1)  # (faces, out c, in c)
            which = d.argmin(2)
            assert d.min(2).max() < 1e-4, ("corner moved", float(d.min(2).max()))
            vmap = np.zeros(nv, np.int64)
            ordered = np.zeros_like(idx)
            for c in range(3):
                vmap[idx[:, c]] = Td[src_face, which[:, c]]
                ordered[src_face, which[:, c]] = idx[:, c]
            self._out.append((vmap.astype(np.uint32), ordered.astype(np.uint32), UVs))
        self.atlas_count = 1
        self.texels_per_unit = 1.0 / texel


XATLAS_VIA_GODOT = types.ModuleType("xatlas")
XATLAS_VIA_GODOT.Atlas = _GodotAtlas
XATLAS_VIA_GODOT.ChartOptions = _Options
XATLAS_VIA_GODOT.PackOptions = _Options

try:
    import xatlas  # noqa: F401  (the real one, where it installs)

    ATLAS_BACKEND = "xatlas"
except ImportError:
    sys.modules["xatlas"] = XATLAS_VIA_GODOT
    ATLAS_BACKEND = "godot"

import mi2_prep  # noqa: E402,F401  (the shared path: it brings mi_prep, whose enemy prepare() is used)
import mi_prep  # noqa: E402

_parts_of = mi_prep.parts_of


def _parts(name, W, J, comp, H):
    if name == RID:
        return priest_parts(W, J, H)
    return _parts_of(name, W, J, comp, H)


_classify = mi_prep.classify_texels
_nearest = mi_prep.Source.nearest
_last_query = {"pts": None}


def _remember_nearest(self, pts, normals, k=12):
    _last_query["pts"] = np.asarray(pts)
    return _nearest(self, pts, normals, k)


def _classify_in_zones(rgb, thr):
    """mi_prep.classify_texels for the priest's triangles: a glow class only inside CRYSTAL_ZONE or VISOR_ZONE (by the
    triangle centres the last Source.nearest query looked up; pixels, with no place, are classed as they are)."""
    cls = _classify(rgb, thr)
    pts = _last_query["pts"]
    if thr is not THRESHOLDS or pts is None or len(pts) != len(cls) or cls.ndim != 1:
        return cls
    c = pts / HEIGHT_M
    crystal = (c[:, 1] > CRYSTAL_ZONE[0]) & (c[:, 2] > CRYSTAL_ZONE[1])
    vx, vy0, vy1, vz, vr = VISOR_ZONE
    visor = (c[:, 0] > vx) & (c[:, 1] > vy0) & (c[:, 1] < vy1) & (np.abs(c[:, 2] - vz) < vr)
    out = cls.copy()
    stray = (cls == 2) & ~(crystal | visor)
    out[stray] = 1
    return out


def _neutral_greys(path):
    """The written colour map's greys made neutral (saturation under NEUTRAL_SAT: the charcoal and the staff), then
    the file rewritten; returns how many texels changed."""
    import io

    from PIL import Image

    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20 : 20 + n])
    bl = struct.unpack("<I", data[20 + n : 24 + n])[0]
    blob = bytearray(data[28 + n : 28 + n + bl])
    bv = j["bufferViews"][j["images"][0]["bufferView"]]
    off, ln = bv.get("byteOffset", 0), bv["byteLength"]
    img = np.asarray(Image.open(io.BytesIO(bytes(blob[off : off + ln]))).convert("RGB")).astype(np.float64) / 255.0
    mx, mn = img.max(-1), img.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    grey = (sat < NEUTRAL_SAT) & (mx > 0.02)
    lum = img @ np.array([0.299, 0.587, 0.114])
    img[grey] = lum[grey, None]
    buf = io.BytesIO()
    Image.fromarray(np.clip(img * 255, 0, 255).round().astype(np.uint8)).save(buf, "JPEG", quality=mi_prep.JPEG_QUALITY)
    jpeg = buf.getvalue()
    # Rebuild with the new image as the last buffer view (mi_prep.write_glb puts it last).
    assert bv is j["bufferViews"][-1] and off + ln <= len(blob)
    blob = mi_prep.pad4(bytes(blob[:off]) + jpeg)
    bv["byteLength"] = len(jpeg)
    j["buffers"][0]["byteLength"] = len(blob)
    js = mi_prep.pad4(json.dumps(j, separators=(",", ":")).encode(), b" ")
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0") + blob)
    return int(grey.sum())


def main():
    import hashlib

    mi_prep.SRC = SRC
    mi_prep.BUDGET["o17"] = BUDGET
    mi_prep.SPECS[RID] = ("o17", "enemies", HEIGHT_M, YAW)
    mi_prep.CLASS_THRESHOLDS[RID] = THRESHOLDS
    mi_prep.parts_of = _parts
    mi_prep.Source.nearest = _remember_nearest
    mi_prep.classify_texels = _classify_in_zones
    out = mi_prep.prepare(RID)
    out["neutral_texels"] = _neutral_greys(out["path"])
    out["bytes"] = os.path.getsize(out["path"])
    out["sha256"] = hashlib.sha256(open(out["path"], "rb").read()).hexdigest()
    out["path"] = out["path"].replace(os.sep, "/")
    out["simplify"] = mi_prep.BACKEND
    out["atlas"] = ATLAS_BACKEND
    print(json.dumps(out), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
