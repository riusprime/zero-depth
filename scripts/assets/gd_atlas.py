"""v0.11.0 O17c: one UV atlas over a model's parts through Godot (scripts/assets/gd_unwrap_parts.gd: ArrayMesh.lightmap_unwrap,
the xatlas Godot embeds), for a PC where the Python xatlas package can't be installed (no wheel for Python 3.14 on
Windows, no compiler to build one). Same answer shape as mi_prep's xatlas use: per part (vmap, idx, uvs), where vmap
maps each new vertex to the part's input vertex, idx are the new triangles in the input's face order, and uvs are 0..1
over the atlas's width and height; plus the atlas's width and height in texels.

unwrap(parts, tex_px, fill=0.6): parts = [(V float (n, 3), T int (m, 3), N float (n, 3)), ...]. The texel size is
searched so the atlas's longer side is about fill x tex_px (Godot pads its charts by one texel and aligns them to
blocks; scaled up to tex_px that leaves wider gutters for mi_prep's dilate and the mipmaps). The GODOT environment
variable names the Godot executable (else `godot` on the PATH). An offline tool: nothing in the game calls it.
"""

import os
import struct
import subprocess
import tempfile

import numpy as np

GD_UNWRAP = "scripts/assets/gd_unwrap_parts.gd"


def _run(parts, texel):
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, "in.bin"), os.path.join(tmp, "out.bin")
        with open(src, "wb") as f:
            f.write(struct.pack("<I", len(parts)))
            for V, T, N in parts:
                f.write(struct.pack("<II", len(V), T.size))
                f.write(np.ascontiguousarray(V, np.float32).tobytes())
                f.write(np.ascontiguousarray(N, np.float32).tobytes())
                f.write(np.ascontiguousarray(T.ravel(), np.uint32).tobytes())
        godot = os.environ.get("GODOT", "godot")
        r = subprocess.run([godot, "--headless", "--path", ".", "-s", GD_UNWRAP, "--", src, dst, repr(float(texel))],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(dst):
            raise RuntimeError("gd_unwrap failed (%d): %s" % (r.returncode, (r.stdout + r.stderr)[-2000:]))
        data = open(dst, "rb").read()
    w, h = struct.unpack("<II", data[:8])
    o = 8
    out = []
    for _ in parts:
        nv = struct.unpack("<I", data[o : o + 4])[0]
        o += 4
        pos = np.frombuffer(data, np.float32, nv * 3, o).reshape(-1, 3)
        o += nv * 12
        uv = np.frombuffer(data, np.float32, nv * 2, o).reshape(-1, 2)
        o += nv * 8
        ni = struct.unpack("<I", data[o : o + 4])[0]
        o += 4
        idx = np.frombuffer(data, np.uint32, ni, o).astype(np.int64).reshape(-1, 3)
        o += ni * 4
        out.append((pos.astype(np.float64), uv.astype(np.float64), idx))
    return w, h, out


def _match(V, T, pos, uv, idx):
    """The new vertices back to the input's (exact positions: Godot copies them) and the faces into the input's order."""
    key = {tuple(np.round(p, 5)): k for k, p in enumerate(V.astype(np.float32).astype(np.float64))}
    vmap = np.array([key[tuple(np.round(p, 5))] for p in pos], np.int64)
    by_face = {}
    for f, t in enumerate(idx):
        by_face.setdefault(tuple(sorted(vmap[t])), []).append(f)
    order = []
    for t in T:
        fs = by_face.get(tuple(sorted(t)))
        if not fs:
            raise RuntimeError("gd_unwrap dropped a face")
        order.append(fs.pop(0))
    return vmap, idx[np.array(order, np.int64)], uv


def unwrap(parts, tex_px, fill=0.6):
    area = sum(float(np.linalg.norm(np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]]), axis=1).sum()) * 0.5
               for V, T, _N in parts)
    target = fill * tex_px
    texel = np.sqrt(area * 2.0) / target  # a first guess (charts fill about half the square)
    for _attempt in range(6):
        w, h, out = _run(parts, texel)
        side = max(w, h)
        if abs(side - target) <= 0.08 * target:
            break
        texel *= side / target
    res = [_match(V, T, *o) for (V, T, _N), o in zip(parts, out)]
    return w, h, res
