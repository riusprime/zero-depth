class_name ItemLooks
extends RefCounted
## One colour per item, used by the pedestal gem, the HUD card and icons, and the attack visuals it changes
## (PLAN v0.2.0 "Items": every item changes how you attack *and* how you look). COLORS is keyed by item kind (the
## first 8 items); ID_COLORS by item id, so items whose kind this build doesn't know yet still get their colour.

const COLORS := {
	WorldReader.ITEM_LONG_EDGE: Color("#7FE7FF"),
	WorldReader.ITEM_TWIN_ARC: Color("#B9A7FF"),
	WorldReader.ITEM_EMBER_EDGE: Color("#FF7A3D"),
	WorldReader.ITEM_SPLINTER_SHOT: Color("#9DFF8A"),
	WorldReader.ITEM_RAPID_COIL: Color("#FFE36A"),
	WorldReader.ITEM_RICOCHET_CORE: Color("#FFFFFF"),
	WorldReader.ITEM_KINETIC_DASH: Color("#4FD8FF"),
	WorldReader.ITEM_OVERCHARGE: Color("#FF5FD2"),
}

const ID_COLORS := {
	&"long_edge": Color("#7FE7FF"),
	&"twin_arc": Color("#B9A7FF"),
	&"ember_edge": Color("#FF7A3D"),
	&"splinter_shot": Color("#9DFF8A"),
	&"rapid_coil": Color("#FFE36A"),
	&"ricochet_core": Color("#FFFFFF"),
	&"kinetic_dash": Color("#4FD8FF"),
	&"overcharge": Color("#FF5FD2"),
	&"vampiric_core": Color("#E8364F"),
	&"static_chain": Color("#8FB8FF"),
	&"momentum": Color("#FFB347"),
	&"frost_core": Color("#BFF4FF"),
	&"thorn_mantle": Color("#6FCB5A"),
	&"executioner": Color("#C7C2D6"),
	&"swift_feet": Color("#7CFFC9"),
	&"phase_strike": Color("#C77DFF"),
}

## The colour of an item this table doesn't know.
const FALLBACK := Color("#E6E6E6")


static func color(kind: int) -> Color:
	return COLORS.get(kind, Color.WHITE)


static func color_of_id(id: StringName) -> Color:
	return ID_COLORS.get(id, FALLBACK)
