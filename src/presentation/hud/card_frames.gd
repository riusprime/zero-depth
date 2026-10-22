class_name CardFrames
extends RefCounted
## The cards' colours by family (v0.5.5 A4 "Card frame colours"; the crystal frames that first wore them were retired
## in v0.8.0 MU, owner O14: "we're just throwing away the shard cards"). A card's colour says its family: the stone
## card's title and inlay groove (StoneCard), a plaque's inlay (Plaques), a wand tile's and a pip's ring, a Codex
## tile's, and in the world a core's and an altar's light. **This file is the one table to remap**: FRAME says which
## colour a family wears, FAMILY_OF says which family each card is in. Rules on top of the table: an epic card wears
## the epic gold, a cursed offer the curse violet; v0.5.5 AR (X1b): a legendary card (the boss's tier, PickSlot tier
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
	# v0.6.0 MX4: the M-list's modifier cards (trinkets indigo) and the boss tier's legendary ones
	&"aether_shell": &"healing",
	&"aftershock": &"area",
	&"ascension": &"crit",
	&"blade_orbit": &"damage",
	&"bomb_rounds": &"area",
	&"boomerang": &"trinket",
	&"echo_slash": &"time",
	&"echo_storm": &"time",
	&"edge_rounds": &"damage",
	&"ember_core": &"fire",
	&"ember_trail": &"fire",
	&"gravity_well": &"dash",
	&"halo_shot": &"trinket",
	&"heat_sink_rounds": &"fire",
	&"inferno_core": &"fire",
	&"long_shadow": &"dash",
	&"meltdown_edge": &"fire",
	&"mirror_drone": &"projectile",
	&"orbit_rounds": &"trinket",
	&"phase_dash": &"dash",
	&"rearguard": &"projectile",
	&"resonance_core": &"damage",
	&"seeker": &"projectile",
	&"shatter": &"projectile",
	&"shock_circles": &"trinket",
	&"short_fuse": &"trinket",
	&"split_shot": &"projectile",
	&"storm_core": &"area",
	&"tempest_core": &"area",
	&"twin_cast": &"time",
	&"venom_core": &"damage",
	&"wide_arc": &"area",
	# v0.6.5 WN1: the wand's trigger cards (placeholder frame until WN5 gives them their look)
	&"trigger_on_end": &"time",
	&"trigger_on_finisher": &"time",
	&"trigger_on_hit": &"time",
	&"trigger_on_kill": &"time",
	&"trigger_on_hit_twice": &"time",  # v0.6.5 WN5b: the legendary triggers
	&"trigger_on_kill_twice": &"time",
	&"trigger_on_end_twice": &"time",
	# v0.6.5 WN3: the Gun pool's new cards (G5, G9, G10, G16 keep theirs above)
	&"gun_backfire": &"projectile",
	&"gun_big_shot": &"damage",
	&"gun_charge": &"crit",
	&"gun_echo": &"time",
	&"gun_homing": &"projectile",
	&"gun_mine": &"area",
	&"gun_pierce": &"damage",
	&"gun_rapid_fire": &"projectile",
	&"gun_ricochet": &"projectile",
	&"gun_spiral": &"trinket",
	&"gun_spread": &"projectile",
	&"gun_twin": &"time",
	&"gun_ring": &"area",  # v0.8.0 AO (owner O37): the order rule's Ring and Swirl
	&"gun_swirl": &"trinket",
	# v0.6.5 WN4: the Blade pool's new cards (B3–B16; Wide Arc, Wave, Afterimage and Orbit Blades keep theirs above)
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
	# v0.8.0 BL (BLADE_AUDIT B4): the Blade's two multiplier cards
	&"blade_storm": &"trinket",
	&"riposte_chain": &"damage",
	# v0.8.0 RM (owner O91): the remnant cards and the two mutations (Dodge Imprint and Fracture Bank keep theirs)
	&"gun_threadline": &"projectile",
	&"shared_faultline": &"area",
	&"shared_gravity_stitch": &"time",
	&"shared_stress_mark": &"damage",
	&"mut_double_exposure": &"time",
	&"mut_grand_finale": &"epic",
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
	# v0.6.5 WN5a: the shared pool's new cards (S1-S4 and S6 keep their v0.6 cards' frames above)
	&"shared_bleed": &"damage",
	&"shared_explosive": &"area",
	&"chain_blast": &"area",  # v0.8.0 RR: the Legendary pre-nerf Explosive
}

## v0.5.5 AR (X1b): the legendary tier (PickSlot.TIERS index): the gold, its title a paler gold.
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
