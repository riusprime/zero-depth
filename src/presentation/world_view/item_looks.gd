class_name ItemLooks
extends RefCounted
## One colour per item, used by the pedestal gem, the HUD card and icons, and the attack visuals it changes
## (PLAN v0.2.0 "Items": every item changes how you attack *and* how you look). COLORS is keyed by item kind (the
## first 8 items and the v0.3.0 G eight); ID_COLORS by item id, so items whose kind this build doesn't know yet
## still get their colour.

const COLORS := {
	WorldReader.ITEM_LONG_EDGE: Color("#7FE7FF"),
	WorldReader.ITEM_TWIN_ARC: Color("#B9A7FF"),
	WorldReader.ITEM_EMBER_EDGE: Color("#FF7A3D"),
	WorldReader.ITEM_SPLINTER_SHOT: Color("#9DFF8A"),
	WorldReader.ITEM_RAPID_COIL: Color("#FFE36A"),
	WorldReader.ITEM_RICOCHET_CORE: Color("#FFFFFF"),
	WorldReader.ITEM_KINETIC_DASH: Color("#4FD8FF"),
	WorldReader.ITEM_OVERCHARGE: Color("#FF5FD2"),
	WorldReader.ITEM_CINDER_SHOT: Color("#FFA24C"),
	WorldReader.ITEM_WILDFIRE: Color("#FF4A2A"),
	WorldReader.ITEM_CONDUCTOR: Color("#5C9DFF"),
	WorldReader.ITEM_SERRATED_EDGE: Color("#C8203A"),
	WorldReader.ITEM_BARBED_BOLTS: Color("#FF6A86"),
	WorldReader.ITEM_GLACIAL_EDGE: Color("#62C6F2"),
	WorldReader.ITEM_COLD_SNAP: Color("#E4FAFF"),
	WorldReader.ITEM_BULWARK: Color("#F2C14E"),
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
	&"cinder_shot": Color("#FFA24C"),
	&"wildfire": Color("#FF4A2A"),
	&"conductor": Color("#5C9DFF"),
	&"serrated_edge": Color("#C8203A"),
	&"barbed_bolts": Color("#FF6A86"),
	&"glacial_edge": Color("#62C6F2"),
	&"cold_snap": Color("#E4FAFF"),
	&"bulwark": Color("#F2C14E"),
	&"heat_sink": Color("#FF9A3C"),
	&"thermal_edge": Color("#FFD27A"),
	&"meltdown": Color("#FF3D1F"),
	&"cluster_payload": Color("#FFA05A"),  # v0.5.0 CP: the ability mods (CardPoolIcons.MOD_COLORS)
	&"overclocked_drone": Color("#FF6A3A"),
	&"razor_orbit": Color("#E04A5E"),
	&"afterimage": Color("#D2B8FF"),
}

## Engine status colours (v0.3.0 G): the enemy effects, pips and the combo frame use them.
const STATUS_COLORS := {
	&"burn": Color("#FF7A3D"),
	&"shock": Color("#9FC8FF"),
	&"bleed": Color("#D21F3C"),
	&"frost": Color("#BFF4FF"),
	&"frozen": Color("#E8FCFF"),
	&"guard": Color("#F2C14E"),
}

## One colour per named combo (v0.3.0 G): its card frame, badge and payoff effect.
const COMBO_COLORS := {
	&"plasma_arc": Color("#FF8A5C"),
	&"shatter_dash": Color("#A8EEFF"),
	&"resonance": Color("#E07CFF"),
	&"shrapnel_storm": Color("#C8FF8A"),
	&"blood_harvest": Color("#FF3B5C"),
	&"spiked_phase": Color("#9BE070"),
	&"slipstream": Color("#7CFFE0"),
	&"frozen_bastion": Color("#9FD8FF"),
}

## The colour of an item this table doesn't know.
const FALLBACK := Color("#E6E6E6")


static func color(kind: int) -> Color:
	return COLORS.get(kind, Color.WHITE)


static func color_of_id(id: StringName) -> Color:
	return ID_COLORS.get(id, FALLBACK)


static func status_color(status: StringName) -> Color:
	return STATUS_COLORS.get(status, FALLBACK)


static func combo_color(id: StringName) -> Color:
	return COMBO_COLORS.get(id, FALLBACK)
