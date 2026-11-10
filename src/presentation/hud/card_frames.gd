class_name CardFrames
extends RefCounted
## The cards' colours by family (v0.5.5 A4 "Card frame colours"; the crystal frames that first wore them were retired
## in v0.8.0 MU, owner O14: "we're just throwing away the shard cards"). A card's colour says its family: the stone
## card's title and inlay groove (StoneCard), a plaque's inlay (Plaques), a wand tile's and a pip's ring, a Codex
## tile's, and in the world a core's and an altar's light. **This file is the one table to remap**: FRAME says which
## colour a family wears, FAMILY_OF says which family each card is in. Rules on top of the table: an epic card wears
## the epic gold, a cursed offer the curse violet; a legendary card (the boss's tier, PickSlot tier
## LEGENDARY_TIER) wears the gold with a paler title (LEGENDARY_TINT) and a stronger glow. A card missing from
## FAMILY_OF falls back to its type's family (DEFAULT_BY_TYPE); tests/unit/presentation/test_card_frames.gd fails on a
## content card that is missing here, so a new card gets a family on purpose.
## Presentation only (EI-07): nothing here changes an outcome.

## Families → colour id (the owner may remap any row).
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

## Each colour id's tint (first sampled from the retired crystal frames): the card's title colour and its inlays.
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
	&"bulwark": &"damage",
	&"cold_snap": &"projectile",
	&"executioner": &"damage",
	&"frost_core": &"projectile",
	&"heat_sink": &"fire",
	&"kinetic_dash": &"dash",
	&"meltdown": &"fire",
	&"momentum": &"dash",
	&"phase_strike": &"dash",
	&"swift_feet": &"dash",
	&"thermal_edge": &"fire",
	&"thorn_mantle": &"projectile",
	&"vampiric_core": &"healing",
	&"wildfire": &"fire",
	# The M-list's modifier cards (trinkets indigo) and the boss tier's legendary ones
	&"blade_orbit": &"damage",
	&"echo_slash": &"time",
	&"ember_core": &"fire",
	&"halo_shot": &"trinket",
	&"long_shadow": &"dash",
	&"orbit_rounds": &"trinket",
	&"split_shot": &"projectile",
	&"storm_core": &"area",
	&"venom_core": &"damage",
	&"wide_arc": &"area",
	# The wand's trigger cards (placeholder frame until WN5 gives them their look)
	# The Gun pool's new cards (G5, G9, G10, G16 keep theirs above)
	&"gun_backfire": &"projectile",
	&"gun_big_shot": &"damage",
	&"gun_echo": &"time",
	&"gun_homing": &"projectile",
	&"gun_mine": &"area",
	&"gun_pierce": &"damage",
	&"gun_rapid_fire": &"projectile",
	&"gun_ricochet": &"projectile",
	&"gun_spiral": &"trinket",
	&"gun_twin": &"time",
	&"gun_ring": &"area",  # The order rule's Ring and Swirl
	&"gun_laser": &"projectile",  # The Laser form
	&"gun_void": &"dash",  # The Void form (the retired Void card's family)
	&"gun_wave": &"area",  # The Wave form
	&"gun_wisps": &"trinket",  # The Wisps form (Orbit Rounds' family)
	&"gun_lance": &"crit",  # The Lance form (the retired Charge card's family)
	&"gun_rune_explosion": &"trinket",  # The Rune Explosion form (replaces Scatter)
	&"gun_glaive": &"trinket",  # The Glaive form (the retired Boomerang card's family)
	&"gun_seekers": &"projectile",  # The Seekers form (the Homing card's family)
	&"gun_swirl": &"trinket",
	# The Blade pool's new cards (B3–B16; Wide Arc, Wave, Afterimage and Orbit Blades keep theirs above)
	&"chain_cut": &"damage",
	&"counter": &"dash",
	&"double_slash": &"time",
	&"finisher_plus": &"area",
	&"fissure": &"area",
	&"flurry": &"time",
	&"heavy": &"damage",
	&"lunge_step": &"dash",
	&"parry_edge": &"damage",
	&"split_wave": &"projectile",
	&"thrust": &"damage",
	&"whirl": &"area",
	# BLADE_AUDIT B4: the Blade's two multiplier cards
	&"blade_storm": &"trinket",
	&"riposte_chain": &"damage",
	# The remnant cards and the two mutations (Dodge Imprint and Fracture Bank keep theirs)
	&"gun_threadline": &"projectile",
	&"shared_faultline": &"area",
	&"shared_stress_mark": &"damage",
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
	&"lifesprout": &"healing",  # Step EC: heal orbs only with this card
	&"max_hp": &"healing",
	&"move_speed": &"dash",
	&"onrush": &"damage",
	&"overkill": &"damage",
	&"pickup_range": &"economy",
	&"regen": &"healing",
	&"shard_gain": &"economy",
	# The rule cards that replace the flat stats
	&"vent_mend": &"healing",
	&"heat_shield": &"economy",
	&"adrenaline": &"dash",
	&"close_quarters": &"damage",
	&"third_strike": &"damage",
	&"reflex": &"time",
	&"scavenger": &"economy",
	# Abilities
	&"aegis": &"time",
	&"blink": &"dash",
	&"combo_sword": &"damage",
	&"pulse_gun": &"projectile",
	# The shared pool's new cards (S1-S4 and S6 keep their v0.6 cards' frames above)
	&"shared_bleed": &"damage",
	&"chain_blast": &"area",  # The Legendary pre-nerf Explosive
}

## The legendary tier (PickSlot.TIERS index): the gold, its title a paler gold.
const LEGENDARY_TIER := 4
const LEGENDARY_TINT := Color("#FFF0A8")

## A card missing from FAMILY_OF: by card type (WorldReader.CARD_MOD / CARD_ABILITY / CARD_STAT).
const DEFAULT_BY_TYPE := {0: &"damage", 1: &"area", 2: &"economy"}
const DEFAULT_FAMILY := &"economy"


## The family of card `id` of `type`, at `tier` (PickSlot.TIERS: 2 is epic), `cursed` for a cursed offer.
static func family(
	id: StringName, type: int = -1, tier: int = 0, cursed: bool = false
) -> StringName:
	if cursed:
		return &"curse"
	if tier == 2 or tier == LEGENDARY_TIER:
		return &"epic"
	if FAMILY_OF.has(id):
		return FAMILY_OF[id]
	return DEFAULT_BY_TYPE.get(type, DEFAULT_FAMILY)


## The colour id a family wears.
static func frame_of(fam: StringName) -> StringName:
	return FRAME.get(fam, FRAME[DEFAULT_FAMILY])


static func tint(frame: StringName) -> Color:
	return TINT.get(frame, Color.WHITE)
