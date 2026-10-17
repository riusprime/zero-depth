"""v0.8.0 Step N13: the before (the kit) | after (option A) pairs of every biome's walls. scripts/shots/walls_n10.gd
writes the shots (tag=n13_old with walls=old, tag=n13_a with walls=a) under build/shots/n10/<tag>/<biome>_<spot>.png;
this joins each biome and spot's pair, each scaled to WIDTH px wide and labelled, into
build/shots/n13_sheet/<biome>_<spot>.jpg (copied into docs/roadmap/v0.8.0/evidence/n13_shots/ by hand). Prints each
file written. Writes only under build/.

Run from the repo root: python3 -I scripts/shots/n13_sheet.py   (needs Pillow)
"""

import glob
import os

from PIL import Image, ImageDraw

SRC = "build/shots/n10"
OUT = "build/shots/n13_sheet"
PAIR = [("n13_old", "before: kit pieces"), ("n13_a", "after: procedural ruin (N13)")]
WIDTH = 640


def _label(img, label):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 8 + 6 * len(label), 20], fill=(0, 0, 0))
    d.text((4, 4), label, fill=(255, 255, 255))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SRC, PAIR[1][0], "*.png"))):
        name = os.path.basename(path)
        tiles = []
        for tag, label in PAIR:
            p = os.path.join(SRC, tag, name)
            if not os.path.exists(p):
                tiles = []
                break
            img = Image.open(p).convert("RGB")
            img = img.resize((WIDTH, round(img.height * WIDTH / img.width)), Image.LANCZOS)
            _label(img, label)
            tiles.append(img)
        if not tiles:
            print("missing a pair: " + name)
            continue
        sheet = Image.new("RGB", (WIDTH * 2 + 4, tiles[0].height), (0, 0, 0))
        sheet.paste(tiles[0], (0, 0))
        sheet.paste(tiles[1], (WIDTH + 4, 0))
        out = os.path.join(OUT, name.replace(".png", ".jpg"))
        sheet.save(out, quality=85)
        print("wrote " + out)


if __name__ == "__main__":
    main()
