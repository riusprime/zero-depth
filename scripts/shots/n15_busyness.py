"""v0.8.0 Step N15 (owner O73, "Night biome textures look busy … how could we make it less busy keeping this model?"):
a repeatable busyness number for the walls at the game's camera.

scripts/shots/walls_n10.gd with mask=1 saves, per spot, the frame (<biome>_<spot>.png) and the same frame with the
procedural walls drawn flat magenta (<biome>_<spot>_mask.png; the ink pass still draws its lines over them). The wall
pixels are the magenta ones, eroded by ERODE px (so the walls' outline against the floor, the ink lines and the fog's
soft edge are not counted). Over them, on the frame's luma (Rec. 709, 0-1):
- edge: the mean Sobel gradient magnitude (|gx|, |gy| over a 3 x 3 kernel / 8; how much the image changes pixel to
  pixel: fine grain, joints, chips) — the busyness number;
- contrast: the mean local standard deviation in a WIN x WIN window (the blotchiness a few pixels across);
- luma: the walls' mean brightness (so a calmer wall is not just a darker one);
- rel_edge, rel_contrast: edge and contrast over luma (the same change on a darker or brighter wall).
And over the whole wall:
- area: the walls' silhouette in pixels (the magenta closed over CLOSE px, so the ink lines inside it count as wall):
  the same ruin seen from the camera keeps about the same area;
- ink: the share of that silhouette under the ink pass's lines (the modelled edges: steps, joints, missing blocks).

Prints one line per shot and one per biome (the mean over its shots), and writes the same to
build/shots/n15_busyness/<tag>.txt. Writes only under build/.

Run from the repo root: python3 -I scripts/shots/n15_busyness.py <tag> [<tag> ...]   (needs Pillow and numpy)
"""

import glob
import os
import sys

import numpy as np
from PIL import Image

SRC = "build/shots/n10"
OUT = "build/shots/n15_busyness"
ERODE = 2
CLOSE = 3
WIN = 9
KEYS = ["edge", "contrast", "luma", "rel_edge", "rel_contrast", "area", "ink"]


def _luma(path: str) -> np.ndarray:
    a = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def _magenta(path: str) -> np.ndarray:
    a = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    return (a[..., 0] > 0.6) & (a[..., 2] > 0.6) & (a[..., 0] - a[..., 1] > 0.25) & (a[..., 2] - a[..., 1] > 0.25)


def _erode(m: np.ndarray, n: int) -> np.ndarray:
    for _ in range(n):
        e = m.copy()
        e[1:, :] &= m[:-1, :]
        e[:-1, :] &= m[1:, :]
        e[:, 1:] &= m[:, :-1]
        e[:, :-1] &= m[:, 1:]
        m = e
    return m


def _dilate(m: np.ndarray, n: int) -> np.ndarray:
    return ~_erode(~m, n)


def _sobel(y: np.ndarray) -> np.ndarray:
    p = np.pad(y, 1, mode="edge")
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    return np.hypot(gx, gy) / 8.0


def _box(a: np.ndarray, r: int) -> np.ndarray:
    p = np.pad(a, r + 1, mode="edge")
    c = p.cumsum(0).cumsum(1)
    n = 2 * r + 1
    s = c[n:, n:] - c[:-n, n:] - c[n:, :-n] + c[:-n, :-n]
    return s[: a.shape[0], : a.shape[1]] / (n * n)


def _local_std(y: np.ndarray) -> np.ndarray:
    r = WIN // 2
    m = _box(y, r)
    m2 = _box(y * y, r)
    return np.sqrt(np.maximum(m2 - m * m, 0.0))


def measure(frame: str, mask: str) -> dict:
    y = _luma(frame)
    mag = _magenta(mask)
    m = _erode(mag, ERODE)
    whole = _erode(_dilate(mag, CLOSE), CLOSE)
    n = int(m.sum())
    area = int(whole.sum())
    out = {k: 0.0 for k in KEYS}
    out["px"] = n
    if n == 0 or area == 0:
        return out
    out["edge"] = float(_sobel(y)[m].mean())
    out["contrast"] = float(_local_std(y)[m].mean())
    out["luma"] = float(y[m].mean())
    out["rel_edge"] = out["edge"] / out["luma"]
    out["rel_contrast"] = out["contrast"] / out["luma"]
    out["area"] = area
    out["ink"] = 1.0 - float((mag & whole).sum()) / area
    return out


def _line(tag: str, name: str, r: dict) -> str:
    return "%s %-22s edge=%.4f contrast=%.4f luma=%.3f rel_edge=%.3f rel_contrast=%.3f area=%7d ink=%.3f" % (
        tag,
        name,
        r["edge"],
        r["contrast"],
        r["luma"],
        r["rel_edge"],
        r["rel_contrast"],
        r["area"],
        r["ink"],
    )


def main(tags: list) -> int:
    os.makedirs(OUT, exist_ok=True)
    for tag in tags:
        lines = []
        per_biome = {}
        for mask in sorted(glob.glob(os.path.join(SRC, tag, "*_mask.png"))):
            frame = mask.replace("_mask.png", ".png")
            name = os.path.basename(frame)[:-4]
            r = measure(frame, mask)
            lines.append(_line(tag, name, r))
            per_biome.setdefault(name.rsplit("_", 1)[0], []).append(r)
        for biome, rs in sorted(per_biome.items()):
            mean = {k: sum(r[k] for r in rs) / len(rs) for k in KEYS}
            lines.append(_line(tag, biome + " (mean)", mean))
        with open(os.path.join(OUT, tag + ".txt"), "w") as f:
            f.write("\n".join(lines) + "\n")
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
