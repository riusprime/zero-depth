class_name CardOrder
extends RefCounted
## v0.10.5 O1 (owner L23: "remove them from the game to have a cleaner code"): the frozen index orders of the item,
## ability and combo tables. Saves hold indices, not ids (RunCarry.FIELDS, World.to_snapshot), so a deleted card keeps
## its place, the way EventCompiler.RETIRED_CURSES keeps a deleted curse's: a stub table (its id, kind, rarity and
## weapon, `retired`, no modifiers) that no run offers, that WandMigration still maps by id (data/wand/migration.tres)
## and that a load drops. Live cards keep the indices they had at 2aaae7a0, so the goldens and old saves are unchanged.
## A card added later takes the next index (ModifierCompiler.item_defs' order among the cards past this list).
## Stubs are emitted only for the shipped content (a repository holding data/wand/migration.tres); a lab repository
## keeps its own cards in this order with no stubs.

## Every item id at 2aaae7a0, in item index order (ModifierCompiler.item_defs then).
const ITEMS: Array[StringName] = [
	&"afterimage",
	&"barbed_bolts",
	&"bulwark",
	&"cinder_shot",
	&"cluster_payload",
	&"cold_snap",
	&"conductor",
	&"ember_edge",
	&"executioner",
	&"frost_core",
	&"glacial_edge",
	&"heat_sink",
	&"kinetic_dash",
	&"long_edge",
	&"meltdown",
	&"momentum",
	&"overcharge",
	&"overclocked_drone",
	&"phase_strike",
	&"rapid_coil",
	&"razor_orbit",
	&"ricochet_core",
	&"serrated_edge",
	&"splinter_shot",
	&"static_chain",
	&"swift_feet",
	&"thermal_edge",
	&"thorn_mantle",
	&"twin_arc",
	&"vampiric_core",
	&"wildfire",
	&"aether_shell",
	&"aftershock",
	&"ascension",
	&"blade_orbit",
	&"bomb_rounds",
	&"boomerang",
	&"echo_slash",
	&"echo_storm",
	&"edge_rounds",
	&"ember_core",
	&"ember_trail",
	&"gravity_well",
	&"halo_shot",
	&"heat_sink_rounds",
	&"inferno_core",
	&"long_shadow",
	&"meltdown_edge",
	&"mirror_drone",
	&"orbit_rounds",
	&"phase_dash",
	&"rearguard",
	&"resonance_core",
	&"seeker",
	&"shatter",
	&"shock_circles",
	&"short_fuse",
	&"split_shot",
	&"storm_core",
	&"tempest_core",
	&"twin_cast",
	&"venom_core",
	&"wide_arc",
	&"trigger_on_end",
	&"trigger_on_finisher",
	&"trigger_on_hit",
	&"trigger_on_kill",
	&"gun_backfire",
	&"gun_big_shot",
	&"gun_bomb",
	&"gun_charge",
	&"gun_echo",
	&"gun_glaive",
	&"gun_homing",
	&"gun_lance",
	&"gun_laser",
	&"gun_mine",
	&"gun_pierce",
	&"gun_rapid_fire",
	&"gun_ricochet",
	&"gun_ring",
	&"gun_rune_explosion",
	&"gun_scatter",
	&"gun_seekers",
	&"gun_spiral",
	&"gun_spread",
	&"gun_swirl",
	&"gun_twin",
	&"gun_void",
	&"gun_wave",
	&"gun_wisps",
	&"chain_cut",
	&"counter",
	&"double_slash",
	&"finisher_plus",
	&"fissure",
	&"flurry",
	&"heavy",
	&"lunge_step",
	&"parry_edge",
	&"split_wave",
	&"thrust",
	&"whirl",
	&"shared_bleed",
	&"shared_explosive",
	&"trigger_on_end_twice",
	&"trigger_on_hit_twice",
	&"trigger_on_kill_twice",
	&"blade_storm",
	&"riposte_chain",
	&"chain_blast",
	&"gun_threadline",
	&"mut_double_exposure",
	&"mut_grand_finale",
	&"shared_faultline",
	&"shared_gravity_stitch",
	&"shared_stress_mark",
]

## The item cards deleted in O1: id -> [ItemTable.kind, ItemTable.rarity, ItemTable.requires_weapon] (WandMigration
## refunds an unmatched card at its rarity's salvage price; the weapon picks its migration row).
const RETIRED_ITEMS := {
	&"afterimage": [30, 1, 0],
	&"barbed_bolts": [20, 0, 2],
	&"cinder_shot": [16, 0, 2],
	&"cluster_payload": [27, 1, 0],
	&"conductor": [18, 1, 1],
	&"ember_edge": [2, 0, 1],
	&"glacial_edge": [21, 0, 1],
	&"long_edge": [0, 0, 1],
	&"overcharge": [7, 0, 1],
	&"overclocked_drone": [28, 1, 0],
	&"rapid_coil": [4, 0, 2],
	&"razor_orbit": [29, 1, 0],
	&"ricochet_core": [5, 0, 2],
	&"serrated_edge": [19, 0, 1],
	&"splinter_shot": [3, 0, 2],
	&"static_chain": [9, 0, 2],
	&"twin_arc": [1, 0, 1],
	&"aether_shell": [31, 1, 0],
	&"aftershock": [31, 0, 0],
	&"ascension": [31, 1, 0],
	&"bomb_rounds": [31, 1, 2],
	&"boomerang": [31, 1, 2],
	&"echo_storm": [31, 2, 1],
	&"edge_rounds": [31, 0, 0],
	&"ember_trail": [31, 0, 0],
	&"gravity_well": [31, 0, 0],
	&"heat_sink_rounds": [31, 1, 0],
	&"inferno_core": [31, 2, 0],
	&"meltdown_edge": [31, 1, 0],
	&"mirror_drone": [31, 1, 0],
	&"phase_dash": [31, 1, 0],
	&"rearguard": [31, 0, 1],
	&"resonance_core": [31, 1, 0],
	&"seeker": [31, 1, 1],
	&"shatter": [31, 0, 0],
	&"shock_circles": [31, 1, 0],
	&"short_fuse": [31, 1, 0],
	&"tempest_core": [31, 2, 0],
	&"twin_cast": [31, 0, 1],
	&"trigger_on_end": [32, 0, 0],
	&"trigger_on_finisher": [32, 0, 0],
	&"trigger_on_hit": [32, 0, 0],
	&"trigger_on_kill": [32, 0, 0],
	&"gun_bomb": [33, 1, 2],
	&"gun_charge": [33, 0, 2],
	&"gun_scatter": [33, 1, 2],
	&"gun_spread": [33, 0, 2],
	&"shared_explosive": [33, 0, 0],
	&"trigger_on_end_twice": [32, 2, 0],
	&"trigger_on_hit_twice": [32, 2, 0],
	&"trigger_on_kill_twice": [32, 2, 0],
	&"mut_double_exposure": [33, 2, 0],
	&"mut_grand_finale": [33, 2, 0],
	&"shared_gravity_stitch": [33, 1, 0],
}

## Every ability id at 2aaae7a0, in ability index order (by id).
const ABILITIES: Array[StringName] = [
	&"aegis",
	&"arc_field",
	&"blink",
	&"bomb_lobber",
	&"combo_sword",
	&"drone_buddy",
	&"flame_trail",
	&"frost_nova",
	&"orbit_blades",
	&"pulse_gun",
]

## The abilities deleted in O1: id -> AbilityTable.Kind.
const RETIRED_ABILITIES := {
	&"arc_field": AbilityTable.Kind.ARC_FIELD,
	&"bomb_lobber": AbilityTable.Kind.BOMB_LOBBER,
	&"drone_buddy": AbilityTable.Kind.DRONE_BUDDY,
	&"flame_trail": AbilityTable.Kind.FLAME_TRAIL,
	&"frost_nova": AbilityTable.Kind.FROST_NOVA,
	&"orbit_blades": AbilityTable.Kind.ORBIT_BLADES,
}

## Every combo id at 2aaae7a0, in combo index order (by id; World.combos_owned's indices).
const COMBOS: Array[StringName] = [
	&"blade_dance",
	&"blink_charge",
	&"blood_harvest",
	&"ember_ward",
	&"frozen_bastion",
	&"glacier_ring",
	&"napalm_drone",
	&"plasma_arc",
	&"resonance",
	&"shatter_dash",
	&"shrapnel_storm",
	&"slipstream",
	&"spiked_phase",
	&"storm_bombs",
	&"superconductor",
	&"wingman",
]

## The combos deleted in O1 (owner P1: "The combos can go away yeah, that's old"; "Keep those 4"): id ->
## ComboTable.Effect. A save's combos_owned entry for one is dropped on load (World._refresh_combos).
const RETIRED_COMBOS := {
	&"blade_dance": ComboTable.Effect.BLADE_DANCE,
	&"blink_charge": ComboTable.Effect.BLINK_CHARGE,
	&"ember_ward": ComboTable.Effect.EMBER_WARD,
	&"frozen_bastion": ComboTable.Effect.FROZEN_BASTION,
	&"glacier_ring": ComboTable.Effect.GLACIER_RING,
	&"napalm_drone": ComboTable.Effect.NAPALM_DRONE,
	&"plasma_arc": ComboTable.Effect.PLASMA_ARC,
	&"resonance": ComboTable.Effect.RESONANCE,
	&"shrapnel_storm": ComboTable.Effect.SHRAPNEL_STORM,
	&"storm_bombs": ComboTable.Effect.STORM_BOMBS,
	&"superconductor": ComboTable.Effect.SUPERCONDUCTOR,
	&"wingman": ComboTable.Effect.WINGMAN,
}


## True when `repo` is the shipped content (it holds the wand migration table), so the stubs keep the saved indices.
static func shipped(repo: ContentRepository) -> bool:
	return WandCompiler.migration(repo) != null


## The item slots in index order: an ItemDefinition, or a retired id (a stub's place). The frozen ids first (a live
## one the repository lacks is left out), then every later card in ModifierCompiler.item_defs' order.
static func item_slots(repo: ContentRepository) -> Array:
	var stubs := shipped(repo)
	var out := []
	var frozen := {}
	for id in ITEMS:
		frozen[id] = true
		var def: ItemDefinition = repo.get_def(&"items", id)
		if def != null:
			out.append(def)
		elif stubs and RETIRED_ITEMS.has(id):
			out.append(id)
	for def: ItemDefinition in ModifierCompiler.item_defs(repo):
		if not frozen.has(def.id):
			out.append(def)
	return out


## The item ids in index order (item_slots), for the compilers that turn ids into item indices.
static func item_ids(repo: ContentRepository) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in item_slots(repo):
		out.append(s if s is StringName else (s as ItemDefinition).id)
	return out


## A deleted item's stub table (class doc).
static func item_stub(id: StringName) -> ItemTable:
	var row: Array = RETIRED_ITEMS[id]
	var t := ItemTable.new()
	t.id = id
	t.kind = row[0]
	t.rarity = row[1]
	t.requires_weapon = row[2]
	t.retired = true
	return t


## The ability slots in index order: an AbilityDefinition, or a retired id (as item_slots).
static func ability_slots(repo: ContentRepository) -> Array:
	var stubs := shipped(repo)
	var out := []
	var frozen := {}
	for id in ABILITIES:
		frozen[id] = true
		var def: AbilityDefinition = repo.get_def(&"ability", id)
		if def != null:
			out.append(def)
		elif stubs and RETIRED_ABILITIES.has(id):
			out.append(id)
	for def: AbilityDefinition in repo.all_of(&"ability"):
		if not frozen.has(def.id):
			out.append(def)
	return out


## A deleted ability's stub table: never offered, no start weapon, no button.
static func ability_stub(id: StringName) -> AbilityTable:
	var t := AbilityTable.new()
	t.id = id
	t.kind = RETIRED_ABILITIES[id]
	t.auto = false
	t.retired = true
	t.offered = false
	return t


## The combo slots in index order: a ComboDefinition, or a retired id (as item_slots).
static func combo_slots(repo: ContentRepository) -> Array:
	var stubs := shipped(repo)
	var out := []
	var frozen := {}
	for id in COMBOS:
		frozen[id] = true
		var def := repo.get_def(&"combos", id) as ComboDefinition
		if def != null:
			out.append(def)
		elif stubs and RETIRED_COMBOS.has(id):
			out.append(id)
	for def in repo.all_of(&"combos"):
		if def is ComboDefinition and not frozen.has(def.id):
			out.append(def)
	return out


## A deleted combo's stub table: no halves (never earned), `retired`.
static func combo_stub(id: StringName) -> ComboTable:
	var t := ComboTable.new()
	t.id = id
	t.effect = RETIRED_COMBOS[id]
	t.retired = true
	return t
