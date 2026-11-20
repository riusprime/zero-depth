"""Installs the owner's two big focal pieces (unprocessed_images/models_v0120_b/{grand_arch,great_monolith}.glb, made
from docs/art/requests/v0.12.0_models.md Part 4) as assets/models/kit/<id>.glb.

Each raw file is a Tripo export: one mesh (about 4.6k triangles, kept as it is: the room pieces' budget), one 2048 px
colour map, Y up, about 1 unit across. Like scripts/assets/rooms_v0120_prep.py (whose reading, texture and writing
this reuses), for each piece this script:
1. keeps the owner's triangles, normals and UVs; the arch's long side is already on +X and the monolith is square, so
   neither is turned;
2. centres it on x/z with its base on y = 0 and scales it evenly (proportions kept) to its request row: the arch to
   the row's width (6.0 m), the monolith to the row's height (6.0 m). The models do not keep the rows' other sides
   (the arch's fallen blocks make it deeper and its lintel lower; the monolith's base crystals make it wider), so
   the printed sizes are the pieces' own and KitModels' "foot" and "height" are those;
3. gives each piece its own copy of the colour map at the kit's 1024 px, brightened toward the kit's mean and never
   darkened (rooms_v0120_prep.piece_texture), material matte (metallic 0, roughness 0.9). One surface each: the game
   tints the whole piece with the biome's hue like the other room pieces, so no tinted / untinted split.
The raw files stay untouched. It prints one JSON line: per piece its triangles, size (m, x/z/y), the file's size and
sha256 (paste the sha256 into assets/models/manifest.json by hand).

Run from the repo root:  python3 scripts/assets/focal_v0120_prep.py [ids...]   (needs numpy and Pillow)
"""

import hashlib
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rooms_v0120_prep as rooms  # noqa: E402

SRC = "unprocessed_images/models_v0120_b"
OUT = "assets/models/kit"
## The request rows (Part 4): width (x), depth (z), height (y), metres; FIT_WIDTH pieces are scaled to the width.
SIZE = {
    "grand_arch": (6.0, 1.6, 5.0),
    "great_monolith": (2.0, 2.0, 6.0),
}
## The arch is scaled to its width: a gateway's span is what it is asked for (the gap between its pillars).
FIT_WIDTH = {"grand_arch"}


def main():
    only = set(sys.argv[1:])
    report = {}
    for rid in SIZE:
        if only and rid not in only:
            continue
        P, N, UV, I, img = rooms.read_glb(os.path.join(SRC, rid + ".glb"))
        used, inv = np.unique(I.ravel(), return_inverse=True)
        P, N, UV, idx = P[used], N[used], UV[used], inv.reshape(-1, 3)
        lo, hi = P.min(0), P.max(0)
        ext = hi - lo
        w, _, h = SIZE[rid]
        s = w / ext[0] if rid in FIT_WIDTH else h / ext[1]
        pos = (P - np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])) * s
        nrm = N / np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]
        jpeg, gain = rooms.piece_texture(img, UV, idx)
        dst = os.path.join(OUT, rid + ".glb")
        rooms.write_glb(dst, rid, pos, nrm, UV, idx, jpeg)
        ext = pos.max(0) - pos.min(0)
        report[rid] = {
            "tris": int(len(idx)),
            "size_m": [round(float(ext[0]), 3), round(float(ext[2]), 3), round(float(ext[1]), 3)],
            "gain": round(gain, 3),
            "bytes": os.path.getsize(dst),
            "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
            "path": dst.replace(os.sep, "/"),
        }
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
