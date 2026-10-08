class_name CardFrames
extends RefCounted
## The pick cards' crystal frames (v0.5.5 A4, owner: "two image for the new card select templates … the empty
## templates you'll have to crop to use them as real cards"). The 12 frames are the owner's art, cropped by
## scripts/art/crop_card_frames.py into assets/ui/cards/ (manifest.json lists each with its hash and size).
##
## A card's frame colour says its family (PLAN v0.5.5 "Card frame colours"). **This file is the one table to remap**:
## FRAME says which frame a family wears, FAMILY_OF says which family each card is in. Rules on top of the table:
## an epic card wears the epic frame, a cursed offer the curse frame. A card missing from FAMILY_OF falls back to
## its type's family (DEFAULT_BY_TYPE); tests/unit/presentation/test_card_frames.gd fails on a content card that is
## missing here, so a new card gets a family on purpose.
## Presentation only (EI-07): nothing here changes an outcome.

const DIR := "res://assets/ui/cards/"
## The frames' size in the PNGs (px), every frame the same.
const SIZE := Vector2(251, 505)

## Families → frame colour (the owner may remap any row).
const FRAME := {
	&"damage": &"red",
	&"projectile": &"blue",  # projectiles and frost
	&"economy": &"amber",  # economy and plain stats
	&"dash": &"purple",  # dash and void
	&"healing": &"green",
	&"time": &"silver",  # time, slow, echoes, cooldowns
	&"crit": &"pink",
	&"area": &"cyan",
	&"fire": &"orange",
	&"curse": &"violet",
	&"epic": &"gold",
	&"trinket": &"indigo",
}

## Each frame's tint, sampled from its crystals: the card's title colour and the panel's hairline.
const TINT := {
	&"red": Color("#FF6A4F"),
	&"blue": Color("#4FA8F0"),
	&"amber": Color("#F2B13E"),
	&"purple": Color("#B36BFF"),
	&"green": Color("#6FD36A"),
	&"silver": Color("#C9D6E6"),
	&"pink": Color("#FF5F8E"),
	&"cyan": Color("#4FDCEB"),
	&"orange": Color("#FF8A3D"),
	&"violet": Color("#A56BFF"),
	&"gold": Color("#F0D85A"),
	&"indigo": Color("#8C82FF"),
}

## Every card in the game → its family. Mods (items), stat cards, abilities.
const FAMILY_OF := {
	# Mods
	&"afterimage": &"dash",
	&"barbed_bolts": &"projectile",
	&"bulwark": &"damage",
	&"cinder_shot": &"fire",
	&"cluster_payload": &"area",
	&"cold_snap": &"projectile",
	&"conductor": &"area",
	&"ember_edge": &"fire",
	&"executioner": &"damage",
	&"frost_core": &"projectile",
	&"glacial_edge": &"projectile",
	&"heat_sink": &"fire",
	&"kinetic_dash": &"dash",
	&"long_edge": &"area",
	&"meltdown": &"fire",
	&"momentum": &"dash",
	&"overcharge": &"damage",
	&"overclocked_drone": &"projectile",
	&"phase_strike": &"dash",
	&"rapid_coil": &"projectile",
	&"razor_orbit": &"damage",
	&"ricochet_core": &"projectile",
	&"serrated_edge": &"damage",
	&"splinter_shot": &"projectile",
	&"static_chain": &"projectile",
	&"swift_feet": &"dash",
	&"thermal_edge": &"fire",
	&"thorn_mantle": &"projectile",
	&"twin_arc": &"time",
	&"vampiric_core": &"healing",
	&"wildfire": &"fire",
	# Stat cards
	&"area": &"area",
	&"armour": &"economy",
	&"attack_speed": &"economy",
	&"cooldowns": &"time",
	&"crit_chance": &"crit",
	&"crit_damage": &"crit",
	&"damage": &"damage",
	&"fast_hands": &"time",
	&"glass_cannon": &"damage",
	&"hoarder": &"economy",
	&"lifesprout": &"healing",  # v0.5.5 D9 (Step EC): heal orbs only with this card
	&"max_hp": &"healing",
	&"move_speed": &"dash",
	&"onrush": &"damage",
	&"overkill": &"damage",
	&"pickup_range": &"economy",
	&"regen": &"healing",
	&"shard_gain": &"economy",
	# Abilities
	&"aegis": &"time",
	&"arc_field": &"area",
	&"blink": &"dash",
	&"bomb_lobber": &"area",
	&"combo_sword": &"damage",
	&"drone_buddy": &"projectile",
	&"flame_trail": &"fire",
	&"frost_nova": &"projectile",
	&"orbit_blades": &"damage",
	&"pulse_gun": &"projectile",
}

## A card missing from FAMILY_OF: by card type (WorldReader.CARD_MOD / CARD_ABILITY / CARD_STAT).
const DEFAULT_BY_TYPE := {0: &"damage", 1: &"area", 2: &"economy"}
const DEFAULT_FAMILY := &"economy"

static var _cache := {}


## The family of card `id` of `type`, at `tier` (PickSlot.TIERS: 2 is epic), `cursed` for a cursed offer.
static func family(
	id: StringName, type: int = -1, tier: int = 0, cursed: bool = false
) -> StringName:
	if cursed:
		return &"curse"
	if tier == 2:
		return &"epic"
	if FAMILY_OF.has(id):
		return FAMILY_OF[id]
	return DEFAULT_BY_TYPE.get(type, DEFAULT_FAMILY)


## The frame id (a colour) a family wears.
static func frame_of(fam: StringName) -> StringName:
	return FRAME.get(fam, FRAME[DEFAULT_FAMILY])


static func tint(frame: StringName) -> Color:
	return TINT.get(frame, Color.WHITE)


static func path(frame: StringName) -> String:
	return DIR + "frame_%s.png" % frame


## The frame's texture (loaded once).
static func texture(frame: StringName) -> Texture2D:
	if not _cache.has(frame):
		_cache[frame] = load(path(frame))
	return _cache[frame]
