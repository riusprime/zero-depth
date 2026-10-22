"""v0.8.0 SR (owner O13): the biomes' shop rooms' source. One shop room per biome: the tent stall (a counter in front
of a tent, the art list's 3.0 x 2.2 m, docs/art/requests/v0.8.0_ART_LIST.md section 1) and the dressing groups round
it, in metres, in the shop frame: y = 0 is the room's way in (its first doorway's side), y = 1 its back, the stall's
counter faces -y. Running it writes data/shop_rooms/<biome>.tres (the files the game loads, validated by
ShopRoomDefinition.validate) and prints each one's groups. The prefabs' helpers (S, D, fringe, corner, wall, free) are
scripts/content/room_layouts.py's, so a shop room is built the way the designed rooms are. Edit here, not in the
.tres files, and re-run:

    python3 -I scripts/content/shop_rooms.py .

Starting values throughout; the look is the owner's (OWNER ONLY), and the owner's models replace the stand-ins."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import room_layouts as rl  # noqa: E402  (the designed rooms' prefab helpers)

REPO = sys.argv[1] if len(sys.argv) > 1 else "."
OUT_DIR = os.path.join(REPO, "data/shop_rooms")
S, D, fringe, corner, wall, free = rl.S, rl.D, rl.fringe, rl.corner, rl.wall, rl.free

# --- the stall: the counter (1.0 m tall) in front, the tent (2.6 m to its awning's peak) behind; goods on the
# counter, sacks of stock under the awning. Metres from the stall's centre, its front toward -y. ---


def stall():
    """The owner's desert stall's footprint (4.0 across, 3.4 deep; ShopRoomDefinition.STALL_SIZE): a 0.9 m counter in
    front of the tent. The goods and sacks are the stand-in tent's (the owner's stall has its own baked in)."""
    return [
        S("shop_counter", 0.0, -1.25, 4.0, 0.9, 1.0),
        S("shop_tent", 0.0, 0.45, 4.0, 2.5, 2.6),
        D("shop_wares", 0.75, -1.27, 1.0, 0.6),
        D("shop_wares", -1.25, -1.27, 0.7, 0.5, yaw=12.0),
        D("shop_sack", -1.5, 1.2, 0.6, 0.6, yaw=20.0),
        D("shop_sack", 1.5, 1.2, 0.55, 0.55, yaw=-35.0),
    ]


# The stall's spots, tried in order (fractions of the room, shop frame): a little behind the middle so the way in
# stays open, then nearer and farther, then to either side, then flush with the back wall, then into a back corner
# (small rooms, or a room whose reward stands in the middle).
SPOTS = [
    (0.5, 0.56), (0.5, 0.64), (0.5, 0.48), (0.5, 0.72), (0.38, 0.6), (0.62, 0.6), (0.25, 0.6), (0.75, 0.6),
    (0.5, 1.0), (0.3, 1.0), (0.7, 1.0), (0.0, 1.0), (1.0, 1.0), (0.0, 0.6), (1.0, 0.6),
]
APPROACH = (6.0, 3.0)

# --- dressing prefabs (corner prefabs: the corner at (0, 0), the room toward +x +y; wall prefabs: the wall along
# y = 0, the room toward +y; free prefabs: centred) ---


def lantern_post():
    """A lantern on a crooked pole, its warm light (ShopStallView), with a crate of goods at its foot."""
    return fringe([
        S("shop_lantern", 0.0, 0.0, 0.5, 0.5, 2.2),
        S("crate_stack", 0.0, 0.85, 0.9, 0.9, 0.8),
        D("shop_wares", 0.0, 0.85, 0.7, 0.5, yaw=30.0),
    ], seed=53)


def supply_corner():
    """Stock waiting to be sold: stacked crates with goods on top, sacks, a burning barrel."""
    return fringe([
        S("crate_stack", 0.65, 0.65, 1.3, 1.3, 1.6),
        S("crate_stack", 1.95, 0.6, 1.3, 1.2, 1.0),
        S("crate_stack", 0.6, 1.9, 1.2, 1.2, 0.9),
        S("fire_barrel", 3.0, 0.4, 0.8, 0.8),
        D("shop_wares", 1.95, 0.6, 0.9, 0.6, yaw=8.0),
        D("shop_sack", 0.6, 1.9, 0.6, 0.6, yaw=40.0),
    ], seed=59)


def junk_corner():
    """The Ruins scavenger's haul: a stripped wreck, crates of parts, a broken wall."""
    return fringe([
        S("car_wreck", 2.4, 1.1, 4.8, 2.2),
        S("crate_stack", 0.7, 2.9, 1.4, 1.4, 1.2),
        D("shop_wares", 0.7, 2.9, 0.9, 0.6, yaw=-15.0),
        S("wall_broken", 0.3, 4.6, 0.6, 2.2, 0.9),
    ], seed=61)


def rock_corner():
    """Rocks and a dead tree, a brazier's light (Night Rocks, Red Canyon, Starfall)."""
    return fringe([
        S("rock_large", 1.0, 1.0, 2.0, 2.0),
        S("rock_large", 2.6, 0.6, 1.2, 1.2),
        S("dead_tree", 0.7, 2.6, 1.0, 1.0),
        S("brazier_pole", 3.55, 0.4, 0.7, 0.7),
    ], seed=67)


def ice_corner():
    """Frozen Shore: crates of the catch, a warm barrel, a rock."""
    return fringe([
        S("crate_stack", 0.65, 0.65, 1.3, 1.3, 1.3),
        S("crate_stack", 1.95, 0.55, 1.3, 1.1, 0.9),
        S("rock_large", 0.8, 2.1, 1.4, 1.4),
        S("fire_barrel", 3.0, 0.4, 0.8, 0.8),
        D("shop_sack", 1.95, 0.55, 0.6, 0.6, yaw=10.0),
    ], seed=71)


def mesa_wall():
    """Red Canyon: stacked slabs along a wall, crates of trade at their feet."""
    return fringe([
        S("slab_concrete", -1.6, 1.0, 2.2, 2.0, 2.6),
        S("slab_concrete", 0.6, 0.8, 2.2, 1.6, 1.9),
        S("crate_stack", 2.4, 0.6, 1.2, 1.2, 1.0),
        D("shop_wares", 2.4, 0.6, 0.8, 0.5, yaw=-20.0),
    ], seed=73)


def crate_wall():
    """A row of crates and sacks along a wall, a broken wall behind."""
    return fringe([
        S("wall_broken", 0.0, 0.3, 3.4, 0.6, 1.0),
        S("crate_stack", -0.65, 1.15, 1.3, 1.1, 1.1),
        S("crate_stack", 0.65, 1.15, 1.3, 1.1, 0.8),
        D("shop_sack", 0.65, 1.15, 0.6, 0.6, yaw=-30.0),
        D("shop_wares", -0.65, 1.15, 0.8, 0.5),
    ], seed=79)


def brazier_wall():
    """Two rocks against a wall, a brazier in front of them (light for the way in)."""
    return fringe([
        S("rock_large", -0.7, 0.7, 1.4, 1.4),
        S("rock_large", 0.7, 0.7, 1.4, 1.4),
        S("brazier_pole", 0.0, 1.75, 0.7, 0.7),
    ], seed=83)


def crate_pile():
    """Two crates of stock with goods on top and a sack, free-standing or against a wall."""
    return fringe([
        S("crate_stack", -0.6, 0.6, 1.2, 1.2, 0.9),
        S("crate_stack", 0.6, 0.55, 1.2, 1.1, 1.2),
        D("shop_wares", -0.6, 0.6, 0.8, 0.5, yaw=10.0),
        D("shop_sack", 0.6, 0.55, 0.55, 0.55, yaw=25.0),
    ], seed=89)


def small_light():
    """A lone lantern post with a sack at its foot (fits where nothing else does)."""
    return fringe([
        S("shop_lantern", 0.0, 0.0, 0.5, 0.5, 2.2),
    ], seed=97)


def extras(side_prefab, back_prefab):
    """The lower-priority groups every shop room tries after its own: the back wall, more of the side walls, the
    front corners and lone lanterns (each dropped whole where it doesn't fit)."""
    return [
        wall(back_prefab, 0.5, "bottom"),
        wall(crate_pile(), 0.22, "left"),
        wall(crate_pile(), 0.78, "right"),
        wall(side_prefab, 0.78, "left"),
        wall(side_prefab, 0.22, "right"),
        corner(rl.shift(crate_pile(), 1.2, 0.0), (0, 0)),
        corner(rl.shift(crate_pile(), 1.2, 0.0), (1, 0)),
        free(small_light(), 0.2, 0.75),
        free(small_light(), 0.8, 0.75),
        free(small_light(), 0.25, 0.3),
        free(small_light(), 0.75, 0.3),
    ]


SHOPS = {}

SHOPS["ruins"] = [
    corner(junk_corner(), (0, 1)),
    corner(supply_corner(), (1, 1)),
    wall(crate_wall(), 0.5, "left"),
    wall(crate_wall(), 0.5, "right"),
    free(lantern_post(), 0.28, 0.4),
    free(lantern_post(), 0.72, 0.4, fx=-1),
] + extras(crate_wall(), crate_wall())

SHOPS["night_rocks"] = [
    corner(rock_corner(), (0, 1)),
    corner(rock_corner(), (1, 1)),
    wall(brazier_wall(), 0.5, "left"),
    corner(supply_corner(), (1, 0)),
    free(lantern_post(), 0.28, 0.4),
    free(lantern_post(), 0.72, 0.4, fx=-1),
] + extras(brazier_wall(), crate_wall())

SHOPS["red_canyon"] = [
    corner(supply_corner(), (0, 1)),
    corner(rock_corner(), (1, 1)),
    wall(mesa_wall(), 0.5, "left"),
    wall(mesa_wall(), 0.5, "right"),
    free(lantern_post(), 0.28, 0.4),
    free(lantern_post(), 0.72, 0.4, fx=-1),
] + extras(mesa_wall(), crate_wall())

SHOPS["frozen_shore"] = [
    corner(ice_corner(), (0, 1)),
    corner(ice_corner(), (1, 1)),
    wall(crate_wall(), 0.5, "right"),
    corner(rock_corner(), (0, 0)),
    free(lantern_post(), 0.28, 0.4),
    free(lantern_post(), 0.72, 0.4, fx=-1),
] + extras(crate_wall(), brazier_wall())

SHOPS["starfall"] = [
    corner(rock_corner(), (0, 1)),
    corner(supply_corner(), (1, 1)),
    wall(brazier_wall(), 0.5, "left"),
    wall(brazier_wall(), 0.5, "right"),
    free(lantern_post(), 0.28, 0.4),
    free(lantern_post(), 0.72, 0.4, fx=-1),
] + extras(brazier_wall(), crate_wall())


def piece_lines(pid, p):
    fmt = rl.fmt
    out = ['[sub_resource type="Resource" id="%s"]' % pid, 'script = ExtResource("1_piece")']
    out.append('piece = &"%s"' % p["piece"])
    out.append("at = Vector2(%s, %s)" % (fmt(p["at"][0]), fmt(p["at"][1])))
    out.append("size = Vector2(%s, %s)" % (fmt(p["size"][0]), fmt(p["size"][1])))
    if p["yaw"]:
        out.append("yaw = %s" % fmt(p["yaw"]))
    if p["height"]:
        out.append("height = %s" % fmt(p["height"]))
    if p["solid"]:
        out.append("solid = true")
    out.append("")
    return out


def write_tres(biome, groups):
    fmt = rl.fmt
    lines = ['[gd_resource type="Resource" script_class="ShopRoomDefinition" format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://src/content/defs/room_layout_piece.gd" id="1_piece"]')
    lines.append('[ext_resource type="Script" path="res://src/content/defs/room_layout_group.gd" id="2_group"]')
    lines.append('[ext_resource type="Script" path="res://src/content/defs/shop_room_definition.gd" id="3_shop"]')
    lines.append("")
    gids = []
    for gi, g in enumerate(groups + [dict(anchor=(0.5, 0.5), pieces=stall())]):
        pids = []
        for pi, p in enumerate(g["pieces"]):
            pid = "P%d_%d" % (gi, pi)
            pids.append(pid)
            lines.extend(piece_lines(pid, p))
        gid = "G%d" % gi
        gids.append(gid)
        lines.append('[sub_resource type="Resource" id="%s"]' % gid)
        lines.append('script = ExtResource("2_group")')
        lines.append("anchor = Vector2(%s, %s)" % (fmt(g["anchor"][0]), fmt(g["anchor"][1])))
        lines.append('pieces = Array[ExtResource("1_piece")]([%s])' % ", ".join('SubResource("%s")' % p for p in pids))
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("3_shop")')
    lines.append('biome = &"%s"' % biome)
    lines.append('stall = SubResource("%s")' % gids[-1])
    lines.append("stall_spots = Array[Vector2]([%s])" % ", ".join("Vector2(%s, %s)" % (fmt(x), fmt(y)) for x, y in SPOTS))
    lines.append("approach = Vector2(%s, %s)" % (fmt(APPROACH[0]), fmt(APPROACH[1])))
    lines.append('groups = Array[ExtResource("2_group")]([%s])' % ", ".join('SubResource("%s")' % g for g in gids[:-1]))
    lines.append('id = &"shop_%s"' % biome)
    lines.append("")
    with open(os.path.join(OUT_DIR, "%s.tres" % biome), "w") as fh:
        fh.write("\n".join(lines))


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for biome, groups in SHOPS.items():
        solids = sum(1 for g in groups for p in g["pieces"] if p["solid"])
        drawn = sum(1 for g in groups for p in g["pieces"] if not p["solid"])
        slit = [(gi, e) for gi, g in enumerate(groups) for e in rl.slits(g["pieces"])]
        print("== shop_%s groups %d solids %d drawn %d slits %s" % (biome, len(groups), solids, drawn, slit))
        write_tres(biome, groups)
