class_name EnemyPalettes
extends RefCounted
## v0.8.0 EC (owner O2, Q1 "By role"): the normal enemy kinds' colours, one table, so the owner's G2 pick is a data
## swap. Families by role, shades differing inside a role: melee rushers red / orange, ranged casters blue / violet,
## bombers and mines yellow, support green, tanks bronze. Every kind keeps its glowing eye (or visor), the outline,
## the team ring and the red bar, so it still reads as hostile. Bosses keep their own colours; elites keep their crown.
## Presentation only (EI-07): avatars read this when they build; nothing here reaches the sim.
##
## Each palette gives every kind four slots (hex):
## - body: the main plate (the Charger's hood, the Warden's shell, the Needle's cube, a robe, a hull);
## - trim: the second plate or trim (the Charger's back flap, the Warden's visor frame, the Needle's pods, a hem, a cap,
##   the Splitter's right half, the Shield Bearer's shield bands);
## - grey: the kind's limbs and frame (legs, arms, staff, barrel); the biome casts its tint on it
##   (ActorViews.tint_greys);
## - eye: the glowing eye, slit or visor.
## The palettes: `current` (today's red and grey, the shipped default until the owner picks), and the G2 candidates
## `a` (saturated role colours), `b` (muted, weathered role colours on the plates, closer to the kit's worn look) and
## `c` (grey bodies, the role colour only on the trims and the glowing eye). Starting values.

const CURRENT := &"current"
const CANDIDATES: Array[StringName] = [&"a", &"b", &"c"]
const SLOTS: Array[StringName] = [&"body", &"trim", &"grey", &"eye"]
## The 14 normal kinds by id (data/enemies/<id>.tres), with their role.
const ROLES := {
	&"charger": &"melee",
	&"hatchling": &"melee",
	&"swarmer": &"melee",
	&"splitter": &"melee",
	&"splitling": &"melee",
	&"needle": &"ranged",
	&"arc_caster": &"ranged",
	&"sniper": &"ranged",
	&"lens_drone": &"ranged",
	&"bomb_drone": &"bomber",
	&"mine_layer": &"bomber",
	&"mender": &"support",
	&"warden": &"tank",
	&"shield_bearer": &"tank",
}
const KIND_IDS := {
	WorldReader.KIND_CHARGER: &"charger",
	WorldReader.KIND_HATCHLING: &"hatchling",
	WorldReader.KIND_SWARMER: &"swarmer",
	WorldReader.KIND_SPLITTER: &"splitter",
	WorldReader.KIND_SPLITLING: &"splitling",
	WorldReader.KIND_NEEDLE: &"needle",
	WorldReader.KIND_ARC_CASTER: &"arc_caster",
	WorldReader.KIND_SNIPER: &"sniper",
	WorldReader.KIND_LENS_DRONE: &"lens_drone",
	WorldReader.KIND_BOMB_DRONE: &"bomb_drone",
	WorldReader.KIND_MINE_LAYER: &"mine_layer",
	WorldReader.KIND_MENDER: &"mender",
	WorldReader.KIND_WARDEN: &"warden",
	WorldReader.KIND_SHIELD_BEARER: &"shield_bearer",
}
## palette -> {"eyes_on_all": the Splitter / Splitling and the Mender get an eye slit too (their seam and heal
## crystal keep their own colours, so every hostile shows the palette's eye), "kinds": id -> [body, trim, grey, eye]}.
## `current` holds the exact colours the avatars drew before v0.8.0 EC, so the shipped look does not change.
const TABLE := {
	&"current":
	{
		"eyes_on_all": false,
		"kinds":
		{
			&"charger": ["#D8433A", "#C63B34", "#6E605D", "#FF2A22"],
			&"hatchling": ["#D8433A", "#C63B34", "#6E605D", "#FF2A22"],
			&"swarmer": ["#D8433A", "#5F5551", "#5F5551", "#FF2A22"],
			&"splitter": ["#D8433A", "#A9302B", "#5F5551", "#FF2A22"],
			&"splitling": ["#D8433A", "#A9302B", "#5F5551", "#FF2A22"],
			&"needle": ["#E03C30", "#5F5551", "#5F5551", "#FF2A22"],
			&"arc_caster": ["#D8433A", "#A9302B", "#5F5551", "#FF2A22"],
			&"sniper": ["#D8433A", "#24272D", "#5F5551", "#FF2A22"],
			&"lens_drone": ["#D8433A", "#5F5551", "#5F5551", "#FF2A22"],
			&"bomb_drone": ["#D8433A", "#5F5551", "#5F5551", "#FF2A22"],
			&"mine_layer": ["#D8433A", "#5F5551", "#5F5551", "#FF2A22"],
			&"mender": ["#D8433A", "#5F5551", "#5F5551", "#FF2A22"],
			&"warden": ["#DA4036", "#2E2B2E", "#6E5B53", "#FC2824"],
			&"shield_bearer": ["#D8433A", "#D8433A", "#5F5551", "#FF2A22"],
		},
	},
	# A: saturated role colours on the plates and trims; the eye stays the hostile red.
	&"a":
	{
		"eyes_on_all": true,
		"kinds":
		{
			&"charger": ["#D8433A", "#A8302A", "#6E605D", "#FF2A22"],
			&"hatchling": ["#C93A1E", "#9A2C16", "#6E605D", "#FF2A22"],
			&"swarmer": ["#B82A48", "#8A1E36", "#5F5551", "#FF2A22"],
			&"splitter": ["#D8682A", "#A84E1E", "#5F5551", "#FF2A22"],
			&"splitling": ["#EE8E62", "#C06C46", "#5F5551", "#FF2A22"],
			&"needle": ["#3A6BD4", "#2A50A0", "#5F5551", "#FF2A22"],
			&"arc_caster": ["#8A50D8", "#6A3CA8", "#5F5551", "#FF2A22"],
			&"sniper": ["#3A55C0", "#2C4092", "#5F5551", "#FF2A22"],
			&"lens_drone": ["#A855C8", "#7E3E96", "#5F5551", "#FF2A22"],
			&"bomb_drone": ["#E8C22E", "#B09222", "#5F5551", "#FF2A22"],
			&"mine_layer": ["#C29A14", "#92740E", "#5F5551", "#FF2A22"],
			&"mender": ["#44A856", "#337E40", "#5F5551", "#FF2A22"],
			&"warden": ["#9A6232", "#744A26", "#6E5B53", "#FF2A22"],
			&"shield_bearer": ["#80592E", "#A87A48", "#5F5551", "#FF2A22"],
		},
	},
	# B: the same families muted and weathered (closer to the kit's worn stone and metal), on the plates.
	&"b":
	{
		"eyes_on_all": true,
		"kinds":
		{
			&"charger": ["#9E4A40", "#7A3A32", "#6E605D", "#FF2A22"],
			&"hatchling": ["#8E3E2E", "#6E3024", "#6E605D", "#FF2A22"],
			&"swarmer": ["#8A3A4A", "#6C2C3A", "#5F5551", "#FF2A22"],
			&"splitter": ["#A0603A", "#7C4A2C", "#5F5551", "#FF2A22"],
			&"splitling": ["#B47E62", "#8C624C", "#5F5551", "#FF2A22"],
			&"needle": ["#4E6898", "#3C5076", "#5F5551", "#FF2A22"],
			&"arc_caster": ["#6A5294", "#523F72", "#5F5551", "#FF2A22"],
			&"sniper": ["#44528A", "#343F6A", "#5F5551", "#FF2A22"],
			&"lens_drone": ["#86609A", "#684A78", "#5F5551", "#FF2A22"],
			&"bomb_drone": ["#B4A048", "#8C7C38", "#5F5551", "#FF2A22"],
			&"mine_layer": ["#94803A", "#72622C", "#5F5551", "#FF2A22"],
			&"mender": ["#4E8056", "#3C6242", "#5F5551", "#FF2A22"],
			&"warden": ["#7C5E40", "#5E4832", "#6E5B53", "#FF2A22"],
			&"shield_bearer": ["#6E5A44", "#8C7458", "#5F5551", "#FF2A22"],
		},
	},
	# C: grey bodies; the role colour only on the trims and on the glowing eye.
	&"c":
	{
		"eyes_on_all": true,
		"kinds":
		{
			&"charger": ["#6B6360", "#D8433A", "#6E605D", "#FF2A22"],
			&"hatchling": ["#6B6360", "#C93A1E", "#6E605D", "#FF3A3A"],
			&"swarmer": ["#6B6360", "#B82A48", "#5F5551", "#FF2058"],
			&"splitter": ["#6B6360", "#D8682A", "#5F5551", "#FF7A1A"],
			&"splitling": ["#6B6360", "#EE8E62", "#5F5551", "#FFA070"],
			&"needle": ["#6B6360", "#3A6BD4", "#5F5551", "#3E7BFF"],
			&"arc_caster": ["#6B6360", "#8A50D8", "#5F5551", "#A060FF"],
			&"sniper": ["#6B6360", "#3A55C0", "#5F5551", "#5A62FF"],
			&"lens_drone": ["#6B6360", "#A855C8", "#5F5551", "#E070FF"],
			&"bomb_drone": ["#6B6360", "#E8C22E", "#5F5551", "#FFE03A"],
			&"mine_layer": ["#6B6360", "#C29A14", "#5F5551", "#E8B000"],
			&"mender": ["#6B6360", "#44A856", "#5F5551", "#2EE05A"],
			&"warden": ["#6B6360", "#9A6232", "#6E5B53", "#C88A4A"],
			&"shield_bearer": ["#6B6360", "#A87A48", "#5F5551", "#A87040"],
		},
	},
}

## The palette the avatars build with. `current` until the owner picks (then the pick's key here, a one-line swap);
## the G2 shot script sets it to render each candidate.
static var active := CURRENT


## Kind `kind`'s colour in `slot` (body / trim / grey / eye) under `palette` (default: the active one). A kind
## outside the table (a boss, the player) is magenta, as ThemePalette's unknown role, so it shows up at once.
static func color(kind: int, slot: StringName, palette: StringName = &"") -> Color:
	return color_of(KIND_IDS.get(kind, &""), slot, palette)


static func color_of(id: StringName, slot: StringName, palette: StringName = &"") -> Color:
	var p: Dictionary = TABLE.get(palette if palette != &"" else active, TABLE[CURRENT])
	var row: Array = (p["kinds"] as Dictionary).get(id, [])
	var k := SLOTS.find(slot)
	if row.is_empty() or k < 0:
		return ThemePalette.UNKNOWN
	return Color(String(row[k]))


## True when the active palette gives the Splitter / Splitling and the Mender their own eye slit.
static func eyes_on_all(palette: StringName = &"") -> bool:
	var p: Dictionary = TABLE.get(palette if palette != &"" else active, TABLE[CURRENT])
	return bool(p["eyes_on_all"])
