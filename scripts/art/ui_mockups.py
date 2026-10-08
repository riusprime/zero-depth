#!/usr/bin/env python3
"""G2 mockups of the HUD and the pause menu in the crystal-card style (v0.5.5 Step CD, PLAN row A5).

A tool for the owner's pick, not the game: nothing here ships. Each option is drawn over a real game frame with the
HUD hidden (scripts/shots/crystal_cards.gd writes it) and uses the owner's card frames from assets/ui/cards/.
The numbers on the mockups (HP, timer, kills, shards, cooldowns) are illustrative, not from a run.

    python3 scripts/art/ui_mockups.py <game_no_hud.png> <game_with_hud.png> <out_dir>

Writes <out_dir>/hud_<a|b|c>.png, pause_<a|b|c>.png (1920 x 1080) and ui_mockups_sheet.png. Needs Pillow.
Evidence copies are made by hand (CLAUDE.md: tools never write into tracked evidence).
"""

import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT_B = os.path.join(ROOT, "assets", "fonts", "AtkinsonHyperlegible-Bold.ttf")
FONT_R = os.path.join(ROOT, "assets", "fonts", "AtkinsonHyperlegible-Regular.ttf")
CARDS = os.path.join(ROOT, "assets", "ui", "cards")
W, H = 1920, 1080

CYAN = (43, 196, 226)
ICE = (158, 217, 230)
EMBER = (255, 138, 61)
HOT = (240, 68, 74)
AMBER = (242, 177, 62)
VIOLET = (179, 107, 255)
TEXT = (233, 237, 240)
DIM = (150, 158, 168)
PANEL = (10, 12, 18)
# The minimap's place in a 1920 x 1080 frame with the shipped HUD (crop source).
MINIMAP = (1597, 89, 1887, 379)


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT_R, size)


def frame(colour):
    return Image.open(os.path.join(CARDS, "frame_%s.png" % colour)).convert("RGBA")


def chamfer(rect, c):
    x0, y0, x1, y1 = rect
    return [(x0 + c, y0), (x1, y0), (x1, y1 - c), (x1 - c, y1), (x0, y1), (x0, y0 + c)]


def glow(base, shape_fn, colour, radius, strength=1.0):
    """Adds a blurred, coloured copy of a shape (drawn by shape_fn on a mask) to base."""
    mask = Image.new("L", base.size, 0)
    shape_fn(ImageDraw.Draw(mask))
    mask = mask.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        mask = mask.point(lambda v: min(255, int(v * strength)))
    layer = Image.new("RGB", base.size, colour)
    black = Image.new("RGB", base.size, (0, 0, 0))
    add = Image.composite(layer, black, mask)
    rgb = ImageChops.add(base.convert("RGB"), add)
    out = rgb.convert("RGBA")
    base.paste(out)


def plate(img, rect, fill=PANEL, alpha=200, edge=None, edge_alpha=120, c=10):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(chamfer(rect, c), fill=fill + (alpha,))
    if edge:
        d.line(chamfer(rect, c) + [chamfer(rect, c)[0]], fill=edge + (edge_alpha,), width=2)
    img.alpha_composite(layer)


def crystal(d, cx, cy, w, h, colour, lit=1.0):
    """A faceted gem: a long diamond split into a light and a dark facet, outlined dark."""
    top, right, bottom, left = (cx, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2), (cx - w / 2, cy)
    light = tuple(min(255, int(v * (0.7 + 0.5 * lit) + 40 * lit)) for v in colour)
    dark = tuple(int(v * (0.35 + 0.35 * lit)) for v in colour)
    d.polygon([top, bottom, left], fill=light)
    d.polygon([top, right, bottom], fill=dark)
    d.line([top, right, bottom, left, top], fill=(14, 10, 18), width=2)
    d.line([top, (cx, cy + h * 0.15)], fill=tuple(min(255, v + 60) for v in light), width=1)


def text(img, xy, s, size, colour=TEXT, bold=False, anchor="la", shadow=True):
    d = ImageDraw.Draw(img)
    f = font(size, bold)
    if shadow:
        d.text((xy[0] + 2, xy[1] + 2), s, font=f, fill=(0, 0, 0, 200), anchor=anchor)
    d.text(xy, s, font=f, fill=colour, anchor=anchor)


def bar(img, rect, frac, colour, track=(255, 255, 255, 40), c=4):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = rect
    d.polygon(chamfer(rect, c), fill=track)
    xf = x0 + (x1 - x0) * frac
    d.polygon(chamfer((x0, y0, xf, y1), c), fill=colour)


def hex_points(cx, cy, r):
    return [(cx + r * dx, cy + r * dy) for dx, dy in ((0, -1), (0.87, -0.5), (0.87, 0.5), (0, 1), (-0.87, 0.5), (-0.87, -0.5))]


def glyph(d, kind, cx, cy, s, colour):
    """Tiny stand-in ability symbols (the game draws its own; these only fill the mockup's slots)."""
    if kind == "blade":
        d.line([(cx - s * 0.5, cy + s * 0.5), (cx + s * 0.45, cy - s * 0.45)], fill=colour, width=4)
        d.line([(cx - s * 0.45, cy + s * 0.05), (cx - s * 0.05, cy + s * 0.45)], fill=colour, width=4)
    elif kind == "drone":
        d.ellipse([cx - s * 0.3, cy - s * 0.2, cx + s * 0.3, cy + s * 0.3], outline=colour, width=3)
        d.line([(cx - s * 0.55, cy - s * 0.4), (cx + s * 0.55, cy - s * 0.4)], fill=colour, width=3)
    elif kind == "frost":
        for a, b in (((0, -1), (0, 1)), ((-0.87, -0.5), (0.87, 0.5)), ((-0.87, 0.5), (0.87, -0.5))):
            d.line([(cx + a[0] * s * 0.5, cy + a[1] * s * 0.5), (cx + b[0] * s * 0.5, cy + b[1] * s * 0.5)], fill=colour, width=3)
    elif kind == "dash":
        for o in (-0.3, 0.15):
            d.line([(cx + o * s - s * 0.15, cy - s * 0.35), (cx + o * s + s * 0.2, cy), (cx + o * s - s * 0.15, cy + s * 0.35)], fill=colour, width=4)


SLOTS = [("blade", (255, 106, 79), 0.0, "LMB"), ("drone", (79, 168, 240), 0.0, ""), ("frost", (79, 168, 240), 0.55, ""), ("", None, 0.0, "")]


# --- Option A: Crystal crown -------------------------------------------------------------------------------------
def hud_a(bg, mini):
    img = bg.copy()
    d = ImageDraw.Draw(img)
    # Top centre: a dark tablet under a crown of crystals; danger as five crystals lighting cold → hot.
    plate(img, (760, 14, 1160, 108), alpha=205, edge=ICE, edge_alpha=70, c=14)
    d = ImageDraw.Draw(img)
    text(img, (960, 22), "FLOOR 1 · RUINS", 18, DIM, True, "ma")
    text(img, (960, 44), "03:42", 40, TEXT, True, "ma")
    text(img, (1146, 62), "87", 22, TEXT, True, "ra")
    text(img, (1146, 86), "KILLS", 13, DIM, True, "ra")
    heat = [ICE, (232, 203, 114), EMBER, HOT, HOT]
    for k in range(5):
        lit = 1.0 if k < 3 else 0.25
        crystal(d, 784 + k * 20, 62, 14, 30, heat[k], lit)
    glow(img, lambda m: [m.polygon(hex_points(784 + k * 20, 62, 13), fill=255) for k in range(3)], EMBER, 10, 0.7)
    d = ImageDraw.Draw(img)
    text(img, (776, 86), "HORDE", 12, EMBER, True, "la")
    # Top right: shards in a small plate; the minimap in a silver crystal rim.
    plate(img, (1600, 14, 1890, 62), alpha=200, edge=VIOLET, edge_alpha=80)
    d = ImageDraw.Draw(img)
    crystal(d, 1626, 38, 18, 34, VIOLET)
    text(img, (1650, 22), "146", 26, TEXT, True)
    text(img, (1880, 30), "SHARDS", 13, DIM, True, "ra")
    img.alpha_composite(mini, (1600, 76))
    d = ImageDraw.Draw(img)
    d.rectangle([1598, 74, 1892, 368], outline=(201, 214, 230, 200), width=2)
    for x, y in ((1598, 74), (1892, 74), (1598, 368), (1892, 368)):
        crystal(d, x, y, 16, 30, (201, 214, 230))
    # Bottom left: HP in a plate with the hero's cyan core crystal; ability sockets as hexes with family rims.
    plate(img, (24, 950, 470, 1054), alpha=205, edge=CYAN, edge_alpha=80, c=14)
    d = ImageDraw.Draw(img)
    glow(img, lambda m: m.polygon(hex_points(62, 1002, 30), fill=255), CYAN, 14, 0.9)
    d = ImageDraw.Draw(img)
    crystal(d, 62, 1002, 30, 62, CYAN)
    text(img, (100, 962), "HP", 15, DIM, True)
    text(img, (456, 958), "72 / 100", 20, TEXT, True, "ra")
    bar(img, (100, 990, 456, 1006), 0.72, (233, 237, 240, 255))
    text(img, (100, 1018), "[Q] LUNGE CLEAVE", 15, ICE, True)
    for k in range(2):
        crystal(d, 372 + k * 18, 1028, 12, 22, CYAN, 1.0 if k == 0 else 0.3)
    text(img, (456, 1020), "DASH", 13, DIM, True, "ra")
    for k, (kind, col, cd, key) in enumerate(SLOTS):
        cx, cy = 66 + k * 92, 890
        d.polygon(hex_points(cx, cy, 40), fill=(10, 12, 18, 220))
        rim = col or (90, 96, 108)
        d.line(hex_points(cx, cy, 40) + [hex_points(cx, cy, 40)[0]], fill=rim, width=3)
        if kind:
            glyph(d, kind, cx, cy, 36, rim)
        if cd:
            d.pieslice([cx - 30, cy - 30, cx + 30, cy + 30], -90, -90 + 360 * cd, fill=(0, 0, 0, 150))
            text(img, (cx, cy - 12), "2.1", 18, TEXT, True, "ma")
        if key:
            text(img, (cx, cy + 44), key, 12, DIM, True, "ma")
    # Bottom centre: heat as a crystal bar, cold to hot glow.
    plate(img, (720, 1012, 1200, 1056), alpha=190, c=10)
    for k in range(20):
        x = 736 + k * 23
        t = k / 19
        col = ICE if t < 0.4 else ((232, 203, 114) if t < 0.65 else (EMBER if t < 0.85 else HOT))
        d = ImageDraw.Draw(img)
        d.polygon([(x, 1046), (x + 9, 1022), (x + 18, 1046)], fill=col if k < 13 else (60, 64, 72))
    glow(img, lambda m: m.rectangle([736, 1022, 736 + 13 * 23, 1046], fill=255), EMBER, 12, 0.45)
    text(img, (1214, 1022), "HOT", 18, EMBER, True)
    return img


def pause_a(bg):
    img = Image.alpha_composite(bg.copy(), Image.new("RGBA", bg.size, (4, 5, 9, 150)))
    f = frame("silver").resize((502, 1010), Image.LANCZOS)
    glow(img, lambda m: m.bitmap((709, 35), f.getchannel("A")), (150, 170, 200), 30, 0.35)
    img.alpha_composite(f, (709, 35))
    d = ImageDraw.Draw(img)
    plate(img, (800, 470, 1120, 930), fill=(6, 8, 12), alpha=200, edge=(201, 214, 230), edge_alpha=60, c=12)
    text(img, (960, 492), "PAUSED", 34, (220, 230, 242), True, "ma")
    d = ImageDraw.Draw(img)
    d.line([(860, 542), (1060, 542)], fill=(201, 214, 230, 120), width=1)
    items = ["Resume", "Restart run", "Options", "Main menu"]
    for k, s in enumerate(items):
        y = 572 + k * 70
        if k == 0:
            plate(img, (828, y - 8, 1092, y + 46), fill=(30, 40, 56), alpha=200, edge=ICE, edge_alpha=160, c=8)
            d = ImageDraw.Draw(img)
            crystal(d, 846, y + 19, 12, 24, ICE)
            crystal(d, 1074, y + 19, 12, 24, ICE)
        text(img, (960, y), s, 26, TEXT if k == 0 else DIM, True, "ma")
    text(img, (960, 870), "Floor 1 · 03:42 · 87 kills", 16, DIM, False, "ma")
    text(img, (960, 892), "Enter / A to choose · Esc / B to resume", 14, DIM, False, "ma")
    return img


# --- Option B: Ember stone ---------------------------------------------------------------------------------------
def stone(img, rect, c=12, ember=True):
    x0, y0, x1, y1 = rect
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = [(x0 + c, y0), (x1 - c * 0.6, y0 + 2), (x1, y0 + c), (x1 - 3, y1 - c * 0.7), (x1 - c, y1), (x0 + c * 0.5, y1 - 2), (x0, y1 - c), (x0 + 2, y0 + c * 0.6)]
    d.polygon(pts, fill=(34, 30, 30, 235))
    d.line(pts + [pts[0]], fill=(14, 10, 10, 255), width=3)
    d.line([pts[0], pts[1]], fill=(92, 84, 80, 255), width=2)  # lit top edge
    img.alpha_composite(layer)
    if ember:
        glow(img, lambda m: m.line([(x0 + c, y1 - 4), (x1 - c, y1 - 4)], fill=255, width=4), EMBER, 6, 0.8)


def hud_b(bg, mini):
    img = bg.copy()
    stone(img, (790, 12, 1130, 96))
    d = ImageDraw.Draw(img)
    text(img, (960, 20), "Floor 1 · Ruins", 17, (214, 196, 170), True, "ma")
    text(img, (960, 40), "03:42", 38, (250, 236, 214), True, "ma")
    text(img, (1116, 58), "87 kills", 15, (214, 196, 170), True, "ra")
    for k in range(5):
        x = 812 + k * 18
        d.polygon([(x, 78), (x + 7, 62), (x + 14, 78)], fill=EMBER if k < 3 else (70, 60, 56))
    glow(img, lambda m: m.rectangle([812, 62, 862, 78], fill=255), EMBER, 8, 0.6)
    stone(img, (1640, 12, 1890, 60), 10, False)
    d = ImageDraw.Draw(img)
    crystal(d, 1664, 36, 16, 30, AMBER)
    text(img, (1688, 20), "146", 24, (250, 236, 214), True)
    stone(img, (1588, 70, 1902, 384), 16, False)
    img.alpha_composite(mini, (1600, 82))
    stone(img, (20, 960, 480, 1060))
    d = ImageDraw.Draw(img)
    text(img, (40, 972), "HP  72 / 100", 18, (250, 236, 214), True)
    bar(img, (40, 1000, 460, 1014), 0.72, (226, 90, 76, 255), (0, 0, 0, 120))
    text(img, (40, 1024), "[Q] Lunge Cleave", 15, (214, 196, 170), True)
    for k in range(2):
        d.ellipse([400 + k * 22, 1026, 414 + k * 22, 1040], fill=EMBER if k == 0 else (70, 60, 56))
    for k, (kind, col, cd, key) in enumerate(SLOTS):
        x = 24 + k * 88
        stone(img, (x, 856, x + 76, 940), 10, False)
        d = ImageDraw.Draw(img)
        if kind:
            glyph(d, kind, x + 38, 898, 34, (250, 236, 214))
            d.line([(x + 12, 932), (x + 64, 932)], fill=col, width=3)
        if cd:
            d.rectangle([x + 6, 864, x + 70, 864 + 64 * cd], fill=(0, 0, 0, 160))
            text(img, (x + 38, 884), "2.1", 18, (250, 236, 214), True, "ma")
    stone(img, (700, 1010, 1220, 1060), 10, False)
    d = ImageDraw.Draw(img)
    bar(img, (720, 1028, 1200, 1042), 0.62, EMBER + (255,), (0, 0, 0, 140))
    glow(img, lambda m: m.rectangle([720, 1028, 720 + 480 * 0.62, 1042], fill=255), EMBER, 10, 0.8)
    text(img, (720, 1012), "HEAT", 12, (214, 196, 170), True)
    text(img, (1200, 1012), "HOT", 12, EMBER, True, "ra")
    return img


def pause_b(bg):
    img = Image.alpha_composite(bg.copy(), Image.new("RGBA", bg.size, (8, 5, 4, 160)))
    stone(img, (660, 230, 1260, 850), 22)
    d = ImageDraw.Draw(img)
    text(img, (960, 262), "PAUSED", 40, (250, 236, 214), True, "ma")
    d.line([(760, 322), (1160, 322)], fill=(120, 90, 70), width=2)
    for k, s in enumerate(["Resume", "Restart run", "Options", "Main menu"]):
        y = 352 + k * 66
        if k == 0:
            glow(img, lambda m: m.rectangle([760, y - 4, 1160, y + 40], fill=255), EMBER, 12, 0.55)
            d = ImageDraw.Draw(img)
            d.line([(760, y + 42), (1160, y + 42)], fill=EMBER, width=2)
        text(img, (960, y), s, 26, (250, 236, 214) if k == 0 else (170, 156, 140), True, "ma")
    # The build so far, as small crystal frames (a proposal for the pause screen).
    text(img, (960, 640), "Your build", 16, (214, 196, 170), True, "ma")
    for k, c in enumerate(["red", "blue", "blue", "amber", "pink", "orange"]):
        f = frame(c).resize((50, 100), Image.LANCZOS)
        img.alpha_composite(f, (790 + k * 58, 672))
    text(img, (960, 800), "Esc / B to resume", 14, (170, 156, 140), False, "ma")
    return img


# --- Option C: Cold glass ----------------------------------------------------------------------------------------
def glass(img, rect, colour, c=8):
    plate(img, rect, fill=(8, 12, 18), alpha=130, edge=colour, edge_alpha=90, c=c)
    x0, y0, x1, y1 = rect
    glow(img, lambda m: m.line([(x0 + c, y0), (x1, y0)], fill=255, width=2), colour, 5, 0.9)


def hud_c(bg, mini):
    img = bg.copy()
    text(img, (960, 18), "Floor 1 · Ruins", 17, DIM, True, "ma")
    text(img, (960, 38), "03:42", 36, TEXT, True, "ma")
    d = ImageDraw.Draw(img)
    for k in range(5):
        crystal(d, 900 + k * 30, 98, 12, 22, [ICE, ICE, (232, 203, 114), EMBER, HOT][k], 1.0 if k < 3 else 0.2)
    text(img, (1060, 50), "87", 20, TEXT, True)
    glass(img, (1700, 16, 1890, 58), VIOLET)
    d = ImageDraw.Draw(img)
    crystal(d, 1722, 37, 14, 26, VIOLET)
    text(img, (1742, 22), "146", 24, TEXT, True)
    m = mini.copy()
    m.putalpha(215)
    img.alpha_composite(m, (1600, 72))
    glow(img, lambda mm: mm.rectangle([1600, 72, 1890, 362], outline=255, width=2), ICE, 6, 0.8)
    glass(img, (24, 1000, 440, 1052), CYAN)
    d = ImageDraw.Draw(img)
    bar(img, (40, 1016, 330, 1028), 0.72, (233, 237, 240, 255), (255, 255, 255, 30), 3)
    text(img, (344, 1008), "72", 26, TEXT, True)
    text(img, (384, 1018), "/100", 14, DIM, True)
    text(img, (40, 1032), "DASH ●●", 12, ICE, True)
    for k, (kind, col, cd, key) in enumerate(SLOTS):
        cx, cy = 52 + k * 70, 950
        rim = col or (70, 76, 88)
        glass(img, (cx - 28, cy - 28, cx + 28, cy + 28), rim, 6)
        d = ImageDraw.Draw(img)
        if kind:
            glyph(d, kind, cx, cy, 30, TEXT)
        if cd:
            d.rectangle([cx - 26, cy + 26 - 52 * cd, cx + 26, cy + 26], fill=(0, 0, 0, 120))
    text(img, (330, 940), "[Q] LUNGE CLEAVE", 15, ICE, True)
    d = ImageDraw.Draw(img)
    d.line([(760, 1044), (1160, 1044)], fill=(255, 255, 255, 50), width=4)
    d.line([(760, 1044), (760 + 400 * 0.62, 1044)], fill=EMBER, width=4)
    glow(img, lambda m: m.line([(760, 1044), (760 + 400 * 0.62, 1044)], fill=255, width=6), EMBER, 8, 1.0)
    text(img, (1170, 1034), "HOT", 15, EMBER, True)
    return img


def pause_c(bg):
    img = bg.copy().filter(ImageFilter.GaussianBlur(6))
    shade = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for x in range(W):
        a = int(220 * max(0.0, 1.0 - x / 1100))
        sd.line([(x, 0), (x, H)], fill=(4, 6, 10, max(a, 90)))
    img.alpha_composite(shade)
    text(img, (180, 300), "PAUSED", 48, TEXT, True)
    d = ImageDraw.Draw(img)
    for k, s in enumerate(["Resume", "Restart run", "Options", "Main menu"]):
        y = 400 + k * 64
        if k == 0:
            crystal(d, 160, y + 17, 14, 28, CYAN)
            glow(img, lambda m: m.line([(180, y + 42), (440, y + 42)], fill=255, width=3), CYAN, 6, 1.0)
            d = ImageDraw.Draw(img)
        text(img, (180, y), s, 28, TEXT if k == 0 else DIM, True)
    text(img, (180, 680), "Floor 1 · 03:42 · 87 kills · 146 shards", 16, DIM)
    # The build on the right as three crystal cards (the pick's frames), dimmed.
    for k, c in enumerate(["red", "blue", "pink"]):
        f = frame(c).resize((226, 455), Image.LANCZOS)
        img.alpha_composite(f, (1030 + k * 250, 300))
    text(img, (1405, 790), "Your build: 3 of 9 cards", 16, DIM, True, "ma")
    return img


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    bg = Image.open(sys.argv[1]).convert("RGBA").resize((W, H), Image.LANCZOS)
    hud = Image.open(sys.argv[2]).convert("RGBA").resize((W, H), Image.LANCZOS)
    mini = hud.crop(MINIMAP)
    out = sys.argv[3]
    os.makedirs(out, exist_ok=True)
    shots = []
    for name, fn in (("hud_a", lambda: hud_a(bg, mini)), ("pause_a", lambda: pause_a(bg)),
                     ("hud_b", lambda: hud_b(bg, mini)), ("pause_b", lambda: pause_b(bg)),
                     ("hud_c", lambda: hud_c(bg, mini)), ("pause_c", lambda: pause_c(bg))):
        img = fn().convert("RGB")
        img.save(os.path.join(out, name + ".png"))
        shots.append(img)
        print("wrote", os.path.join(out, name + ".png"))
    sheet = Image.new("RGB", (W, H * 3 // 2), (12, 12, 16))
    for i, img in enumerate(shots):
        sheet.paste(img.resize((W // 2, H // 2), Image.LANCZOS), ((i % 2) * W // 2, (i // 2) * H // 2))
    d = ImageDraw.Draw(sheet)
    for i, label in enumerate(["A  Crystal crown", "B  Ember stone", "C  Cold glass"]):
        d.text((12, i * H // 2 + 8), label, font=font(30, True), fill=(255, 255, 255))
    sheet.save(os.path.join(out, "ui_mockups_sheet.png"))
    print("wrote", os.path.join(out, "ui_mockups_sheet.png"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
