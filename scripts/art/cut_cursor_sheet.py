"""Cuts the owner's cursor sheet into the game's cursor sprites (v0.9.5 MC2).

Run: python -I scripts/art/cut_cursor_sheet.py [--sheet PATH] [--out DIR] [--contact PATH]
Grid mode (v0.10.5 W8, the Astral sheet: 1920x960, real alpha, 4x2 cells of 480 px): add --grid.
  python scripts/art/cut_cursor_sheet.py --grid   (sheet art_raw/sheets/cursors_astral.png, contact
  build/shots/v0.10.5/cursors/contact.png). Cells in order: default, hover, click, interact, aim, invalid,
  disabled, empty. No keying (scipy not needed); the pointers share one window anchored on the tip; aim is centred.
Writes <state>_<size>.png (32/48/64) and hotspots.json (fractions of the size) to assets/ui/cursors/.
The sheet's dark background is keyed out: alpha from the colour distance to the background, the colour
un-premultiplied so the red glow fades to transparent, not to a dark fringe. The arrows share one window
anchored on the arrow's tip, so the hotspot does not move between states.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

SHEET = "docs/art/reference/v0.9.5_cursor_sheet.png"
OUT = "assets/ui/cursors"
SIZES = (32, 48, 64)
# state -> ((x0, y0, x1, y1) search cell on the sheet, captions excluded; is_arrow)
CELLS = {
    "default": ((20, 40, 195, 235), True),
    "hover": ((215, 40, 390, 235), True),
    "click": ((410, 40, 585, 235), True),
    "disabled": ((590, 40, 781, 235), True),
    "aim": ((40, 330, 200, 480), False),
    "interact": ((230, 330, 390, 480), True),
    "invalid": ((620, 330, 781, 480), True),
}
STRONG = 60  # colour distance of "solid" pixels
REF = 150.0  # distance that counts as fully opaque for soft (glow) pixels
FLOOR = 9.0  # below this distance: background noise
PAD = 6  # transparent margin kept around an icon, in sheet pixels


def key(rgb, bg):
    from scipy import ndimage

    d = np.sqrt(((rgb - bg) ** 2).sum(-1))
    solid = ndimage.binary_fill_holes(ndimage.binary_closing(d > STRONG, iterations=2))
    core = ndimage.binary_erosion(solid, iterations=1)
    a = np.where(d < FLOOR, 0.0, np.clip((d - FLOOR) / (REF - FLOOR), 0, 1))
    a = np.where(core, 1.0, a)
    af = np.maximum(a, 1e-4)[..., None]
    f = (rgb - (1 - af) * bg) / af
    f = np.where(core[..., None], rgb, np.clip(f, 0, 255))
    return f, a, d


GRID_SHEET = "art_raw/sheets/cursors_astral.png"
GRID_CONTACT = "build/shots/v0.10.5/cursors/contact.png"
GRID_STATES = ("default", "hover", "click", "interact", "aim", "invalid", "disabled", "empty")


def write_states(full, jobs, out, contact):
    """jobs: state -> (cell box, window origin, window side, hotspot px); full is HxWx4 (rgb, alpha 0-255)."""
    os.makedirs(out, exist_ok=True)
    hot = {}
    for state, ((cx0, cy0, cx1, cy1), (ox, oy), w, (hx, hy)) in jobs.items():
        canvas = np.zeros((w, w, 4), np.float64)
        sx0, sy0 = max(ox, cx0), max(oy, cy0)
        sx1, sy1 = min(ox + w, cx1), min(oy + w, cy1)
        canvas[sy0 - oy : sy1 - oy, sx0 - ox : sx1 - ox] = full[sy0:sy1, sx0:sx1]
        hot[state] = {"x": hx / w, "y": hy / w}
        pm = canvas.copy()
        pm[..., :3] *= pm[..., 3:4] / 255.0  # premultiplied resampling: no dark fringe
        for sz in SIZES:
            chans = [
                np.asarray(
                    Image.fromarray(pm[..., c].astype(np.float32), "F").resize(
                        (sz, sz), Image.LANCZOS
                    )
                )
                for c in range(4)
            ]
            o = np.stack(chans, -1)
            al = np.clip(o[..., 3], 0, 255)
            rgb = np.where(
                al[..., None] > 0.5, o[..., :3] / np.maximum(al[..., None] / 255.0, 1e-4), 0
            )
            res = np.dstack([np.clip(rgb, 0, 255), al]).round().astype(np.uint8)
            Image.fromarray(res, "RGBA").save(os.path.join(out, f"{state}_{sz}.png"))
    with open(os.path.join(out, "hotspots.json"), "w") as fh:
        json.dump(hot, fh, indent=2, sort_keys=True)
        fh.write("\n")
    if contact:
        os.makedirs(os.path.dirname(contact) or ".", exist_ok=True)
        cw = 48 * 4
        names = list(jobs)
        sheet = Image.new("RGB", (cw * len(names), cw * 2))
        for row, col in enumerate(((22, 24, 30), (225, 227, 232))):
            for i, s in enumerate(names):
                tile = Image.new("RGBA", (cw, cw), col + (255,))
                im = Image.open(os.path.join(out, f"{s}_48.png")).resize((cw, cw), Image.NEAREST)
                tile.alpha_composite(im)
                px, py = int(hot[s]["x"] * cw), int(hot[s]["y"] * cw)
                for k in range(-4, 5):
                    for qx, qy in ((px + k, py), (px, py + k)):
                        if 0 <= qx < cw and 0 <= qy < cw:
                            tile.putpixel((qx, qy), (0, 255, 0, 255))
                sheet.paste(tile.convert("RGB"), (i * cw, row * cw))
        sheet.save(contact)
    return hot


def grid_main(args):
    im = Image.open(args.sheet or GRID_SHEET).convert("RGBA")
    if im.size != (1920, 960):
        print("warning: sheet is %dx%d, expected 1920x960" % im.size)
    full = np.asarray(im).astype(np.float64)
    cw, ch = im.size[0] // 4, im.size[1] // 2
    found = {}
    for i, state in enumerate(GRID_STATES[:-1]):  # cell 8 is empty
        cx0, cy0 = (i % 4) * cw, (i // 4) * ch
        ys, xs = np.nonzero(full[cy0 : cy0 + ch, cx0 : cx0 + cw, 3] >= 128)
        if len(xs) == 0:
            raise SystemExit("cell %d (%s) has no opaque pixels" % (i + 1, state))
        box = tuple(int(v) for v in (cx0 + xs.min(), cy0 + ys.min(), cx0 + xs.max() + 1, cy0 + ys.max() + 1))
        k = int(np.argmin(xs + ys))
        tip = (cx0 + int(xs[k]), cy0 + int(ys[k]))
        found[state] = ((cx0, cy0, cx0 + cw, cy0 + ch), tip, box)
    ptr = [v for s, v in found.items() if s != "aim"]
    left = max(v[1][0] - v[2][0] for v in ptr) + PAD
    top = max(v[1][1] - v[2][1] for v in ptr) + PAD
    right = max(v[2][2] - v[1][0] for v in ptr) + PAD
    bottom = max(v[2][3] - v[1][1] for v in ptr) + PAD
    side = max(left + right, top + bottom)
    jobs = {}
    for state, (cell, tip, box) in found.items():
        if state != "aim":
            org = (tip[0] - left, tip[1] - top)
            jobs[state] = (cell, org, side, (float(left), float(top)))
            print("%-9s tip %s crop %s" % (state, tip, org + (org[0] + side, org[1] + side)))
        else:
            w = max(box[2] - box[0], box[3] - box[1]) + 2 * PAD
            org = (
                int(round((box[0] + box[2]) / 2.0 - w / 2.0)),
                int(round((box[1] + box[3]) / 2.0 - w / 2.0)),
            )
            jobs[state] = (cell, org, w, (w / 2.0, w / 2.0))
            print("%-9s bbox %s crop %s" % (state, box, org + (org[0] + w, org[1] + w)))
    hot = write_states(full, jobs, args.out or OUT, args.contact or GRID_CONTACT)
    print("side", side, json.dumps(hot))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grid", action="store_true", help="cut the v0.10.5 Astral 4x2 alpha sheet")
    ap.add_argument("--sheet", default=None)
    ap.add_argument("--out", default=None)
    ap.add_argument("--contact", default=None)
    args = ap.parse_args()
    if args.grid:
        return grid_main(args)
    args.sheet = args.sheet or SHEET
    args.out = args.out or OUT
    args.contact = args.contact or "build/shots/v0.9.5/mc2/sheet.png"
    from scipy import ndimage

    img = np.asarray(Image.open(args.sheet).convert("RGB")).astype(np.float64)
    bg = np.median(img[296:326, 0:781].reshape(-1, 3), axis=0)  # the empty band between the rows
    f, a, d = key(img, bg)
    found = {}
    for state, ((x0, y0, x1, y1), is_arrow) in CELLS.items():
        strong = d[y0:y1, x0:x1] > STRONG
        lab, n = ndimage.label(ndimage.binary_dilation(strong, iterations=2))
        sizes = ndimage.sum(strong, lab, range(1, n + 1))
        main_c = 1 + int(np.argmax(sizes))
        ys, xs = np.nonzero(strong & (lab == main_c))
        i = int(np.argmin(xs + ys))
        tip = (x0 + int(xs[i]), y0 + int(ys[i]))
        ys2, xs2 = np.nonzero(a[y0:y1, x0:x1] > 0.08)
        box = (x0 + xs2.min(), y0 + ys2.min(), x0 + xs2.max() + 1, y0 + ys2.max() + 1)
        found[state] = (tip, box, is_arrow)
    arrows = [s for s, v in found.items() if v[2]]
    left = max(found[s][0][0] - found[s][1][0] for s in arrows) + PAD
    top = max(found[s][0][1] - found[s][1][1] for s in arrows) + PAD
    right = max(found[s][1][2] - found[s][0][0] for s in arrows) + PAD
    bottom = max(found[s][1][3] - found[s][0][1] for s in arrows) + PAD
    side = max(left + right, top + bottom)
    os.makedirs(args.out, exist_ok=True)
    hot = {}
    full = np.dstack([f, a * 255.0])
    for state, (tip, box, is_arrow) in found.items():
        if is_arrow:
            w = side
            ox, oy = tip[0] - left, tip[1] - top
            hx, hy = float(left), float(top)
        else:
            w = max(box[2] - box[0], box[3] - box[1]) + 2 * PAD
            ox = int(round((box[0] + box[2]) / 2.0 - w / 2.0))
            oy = int(round((box[1] + box[3]) / 2.0 - w / 2.0))
            hx = hy = w / 2.0
        cx0, cy0, cx1, cy1 = CELLS[state][0]
        canvas = np.zeros((w, w, 4), np.float64)
        sx0, sy0 = max(ox, cx0), max(oy, cy0)
        sx1, sy1 = min(ox + w, cx1), min(oy + w, cy1)
        canvas[sy0 - oy : sy1 - oy, sx0 - ox : sx1 - ox] = full[sy0:sy1, sx0:sx1]
        hot[state] = {"x": hx / w, "y": hy / w}
        pm = canvas.copy()
        pm[..., :3] *= pm[..., 3:4] / 255.0  # premultiplied resampling: no dark fringe
        for sz in SIZES:
            chans = [
                np.asarray(
                    Image.fromarray(pm[..., c].astype(np.float32), "F").resize(
                        (sz, sz), Image.LANCZOS
                    )
                )
                for c in range(4)
            ]
            o = np.stack(chans, -1)
            al = np.clip(o[..., 3], 0, 255)
            rgb = np.where(
                al[..., None] > 0.5, o[..., :3] / np.maximum(al[..., None] / 255.0, 1e-4), 0
            )
            out = np.dstack([np.clip(rgb, 0, 255), al]).round().astype(np.uint8)
            Image.fromarray(out, "RGBA").save(os.path.join(args.out, f"{state}_{sz}.png"))
    with open(os.path.join(args.out, "hotspots.json"), "w") as fh:
        json.dump(hot, fh, indent=2, sort_keys=True)
        fh.write("\n")
    if args.contact:
        os.makedirs(os.path.dirname(args.contact), exist_ok=True)
        cw = 48 * 4
        names = list(CELLS)
        sheet = Image.new("RGB", (cw * len(names), cw * 2))
        for row, col in enumerate(((22, 24, 30), (225, 227, 232))):
            for i, s in enumerate(names):
                tile = Image.new("RGBA", (cw, cw), col + (255,))
                im = Image.open(os.path.join(args.out, f"{s}_48.png")).resize(
                    (cw, cw), Image.NEAREST
                )
                tile.alpha_composite(im)
                px, py = int(hot[s]["x"] * cw), int(hot[s]["y"] * cw)
                for k in range(-4, 5):
                    for qx, qy in ((px + k, py), (px, py + k)):
                        if 0 <= qx < cw and 0 <= qy < cw:
                            tile.putpixel((qx, qy), (0, 255, 0, 255))
                sheet.paste(tile.convert("RGB"), (i * cw, row * cw))
        sheet.save(args.contact)
    print("side", side, json.dumps(hot))


if __name__ == "__main__":
    main()
