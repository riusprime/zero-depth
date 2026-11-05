"""Draws the game's cursor sprites in the Astral style (v0.10.5 W3-O20).

Run: python -I scripts/art/astral_cursors.py [--out DIR] [--contact PATH]
Writes <state>_<size>.png (32/48/64) for the seven GameCursor states to assets/ui/cursors/ and leaves
hotspots.json as it is: the arrow's tip stays at the same fraction of the size as the owner's sheet cut
(cut_cursor_sheet.py, v0.9.5 MC2), so GameCursor.HOTSPOTS and its test hold.

The look (W3_O13_UI_STYLE_G2.md round 2, Astral): no stone, no red gem, no glow. A slim dart on ink with a 1 px
silver contour and a faint inner contour, a small four-point star in its body; hover lights the contour and adds a
spark at the tail, a click fills the star, disabled is a dim hollow dart, interact adds a small ring by the tail,
invalid turns the contour Astral's rose and crosses the ring. The aim is a thin ring with four ticks and a centre
diamond. Drawn 8x larger and scaled down, so the lines are crisp and the diagonals smooth.
"""
import argparse
import math
import os

from PIL import Image, ImageDraw

OUT = "assets/ui/cursors"
SIZES = (32, 48, 64)
SS = 8
# Astral's tokens (AstralCardArt / HudStyle).
INK = (13, 17, 32)
LINE = (110, 118, 160)
LINE_HI = (228, 230, 255)
METAL = (201, 204, 230)
ACCENT = (181, 189, 240)
DIM = (144, 149, 180)
ROSE = (216, 138, 154)
# The dart, as fractions of the size: the tip at the sheet's hotspot (0.1753, 0.0779), the left wing, the notch,
# the right wing.
TIP = (0.17532467532467533, 0.07792207792207792)
DART = [TIP, (0.25, 0.80), (0.405, 0.585), (0.72, 0.545)]


def rgba(c, a):
    return (c[0], c[1], c[2], int(round(255 * a)))


def px(p, size):
    return (p[0] * size * SS, p[1] * size * SS)


def inset(poly, d):
    """Moves each point of `poly` toward the centroid by `d` (canvas px)."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for x, y in poly:
        vx, vy = cx - x, cy - y
        n = math.hypot(vx, vy) or 1.0
        out.append((x + vx / n * d, y + vy / n * d))
    return out


def star(draw, c, r, col, inner=0.22):
    pts = []
    for k in range(8):
        a = -math.pi / 2 + k * math.pi / 4
        rr = r if k % 2 == 0 else r * inner
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
    draw.polygon(pts, fill=col)


def diamond(draw, c, r, fill, line, w):
    pts = [(c[0], c[1] - r), (c[0] + r, c[1]), (c[0], c[1] + r), (c[0] - r, c[1])]
    draw.polygon(pts, fill=fill)
    draw.line(pts + [pts[0]], fill=line, width=w, joint="curve")


def dart(draw, size, line, fill_a, star_col, star_fill, inner_a=0.3):
    lw = SS  # 1 px at the final size
    poly = [px(p, size) for p in DART]
    draw.polygon(poly, fill=rgba(INK, fill_a))
    draw.line(inset(poly, 3.2 * SS) + [inset(poly, 3.2 * SS)[0]], fill=rgba(line, inner_a), width=lw, joint="curve")
    draw.line(poly + [poly[0]], fill=rgba(line, 1.0), width=int(lw * 1.4), joint="curve")
    c = (poly[0][0] * 0.3 + poly[2][0] * 0.7, poly[0][1] * 0.3 + poly[2][1] * 0.7)
    r = size * SS * 0.075
    if star_fill:
        star(draw, c, r, rgba(star_col, 1.0))
    else:
        diamond(draw, c, r * 0.45, rgba(INK, 1.0), rgba(star_col, 0.9), lw)
    return poly


def ring(draw, c, r, col, w):
    draw.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=col, width=w)


def render(state, size):
    big = size * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    lw = SS
    if state == "aim":
        c = (big / 2, big / 2)
        r = big * 0.27
        ring(d, c, r, rgba(METAL, 0.9), lw)
        for k in range(4):
            a = k * math.pi / 2
            p0 = (c[0] + math.cos(a) * (r - big * 0.06), c[1] + math.sin(a) * (r - big * 0.06))
            p1 = (c[0] + math.cos(a) * (r + big * 0.17), c[1] + math.sin(a) * (r + big * 0.17))
            d.line([p0, p1], fill=rgba(LINE_HI, 1.0), width=int(lw * 1.4))
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            p = (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r)
            d.ellipse([p[0] - lw, p[1] - lw, p[0] + lw, p[1] + lw], fill=rgba(METAL, 0.7))
        diamond(d, c, big * 0.045, rgba(ACCENT, 1.0), rgba(LINE_HI, 1.0), lw)
    elif state == "default":
        dart(d, size, METAL, 0.9, ACCENT, False)
    elif state == "hover":
        poly = dart(d, size, LINE_HI, 0.94, LINE_HI, True, 0.45)
        tail = (poly[2][0] + big * 0.1, poly[2][1] + big * 0.1)
        star(d, tail, big * 0.075, rgba(LINE_HI, 1.0))
    elif state == "click":
        poly = dart(d, size, LINE_HI, 0.98, ACCENT, True, 0.6)
        d.polygon(inset(poly, 3.2 * SS), fill=rgba(ACCENT, 0.18))
    elif state == "disabled":
        dart(d, size, DIM, 0.55, DIM, False, 0.18)
    elif state == "interact":
        poly = dart(d, size, LINE_HI, 0.92, ACCENT, True, 0.4)
        c = (poly[2][0] + big * 0.17, poly[2][1] + big * 0.17)
        ring(d, c, big * 0.1, rgba(ACCENT, 1.0), lw)
        star(d, c, big * 0.055, rgba(LINE_HI, 1.0))
    elif state == "invalid":
        poly = dart(d, size, ROSE, 0.9, ROSE, False, 0.3)
        c = (poly[2][0] + big * 0.17, poly[2][1] + big * 0.17)
        r = big * 0.1
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=rgba(INK, 0.85))
        ring(d, c, r, rgba(ROSE, 1.0), int(lw * 1.4))
        o = r * 0.7071
        d.line([(c[0] - o, c[1] + o), (c[0] + o, c[1] - o)], fill=rgba(ROSE, 1.0), width=int(lw * 1.4))
    return im.resize((size, size), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--contact", default="")
    a = ap.parse_args()
    states = ["default", "hover", "click", "disabled", "aim", "interact", "invalid"]
    os.makedirs(a.out, exist_ok=True)
    for s in states:
        for size in SIZES:
            render(s, size).save(os.path.join(a.out, "%s_%d.png" % (s, size)))
    if a.contact:
        scale = 3
        sheet = Image.new("RGBA", (len(states) * 64 * scale, 64 * scale), (40, 46, 70, 255))
        for i, s in enumerate(states):
            im = render(s, 64).resize((64 * scale, 64 * scale), Image.NEAREST)
            sheet.alpha_composite(im, (i * 64 * scale, 0))
        sheet.save(a.contact)
    print("astral_cursors: wrote %d sprites to %s" % (len(states) * len(SIZES), a.out))


if __name__ == "__main__":
    main()
