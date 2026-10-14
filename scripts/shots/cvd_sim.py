"""Simulates a colour-vision deficiency on rendered shots (v0.8.0 EC G2 evidence).

Uses the same model as tests/unit/presentation/test_colour_modes.gd (Machado, Oliveira and Fernandes 2009,
severity 1.0, applied in linear RGB). Reads PNGs and writes `<name>_sim_<deficiency>.png` next to each, under
build/ only (tools never write into tracked evidence).

    python3 scripts/shots/cvd_sim.py <deficiency> <png> [<png> ...]

<deficiency> is protanopia, deuteranopia or tritanopia. Needs numpy and Pillow.
"""

import os
import sys

import numpy as np
from PIL import Image

SIM = {
    "protanopia": [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ],
    "deuteranopia": [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501, 0.047413],
        [-0.011820, 0.042940, 0.968881],
    ],
    "tritanopia": [
        [1.255528, -0.076749, -0.178779],
        [-0.078411, 0.930809, 0.147602],
        [0.004733, 0.691367, 0.303900],
    ],
}


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def main(argv):
    if len(argv) < 3 or argv[1] not in SIM:
        print(__doc__)
        return 2
    m = np.array(SIM[argv[1]])
    for path in argv[2:]:
        if not os.path.abspath(path).startswith(os.path.abspath("build") + os.sep):
            print("refusing to write outside build/: %s" % path)
            return 1
        img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
        lin = to_linear(img) @ m.T
        out = to_srgb(np.clip(lin, 0.0, 1.0))
        dst = "%s_sim_%s.png" % (os.path.splitext(path)[0], argv[1])
        Image.fromarray(np.round(out * 255.0).astype(np.uint8)).save(dst)
        print("cvd_sim:", dst)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
