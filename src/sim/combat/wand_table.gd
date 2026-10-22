class_name WandTable
extends RefCounted
## v0.6.5 WN1: the wand's numbers in sim units (WandDefinition compiled by WandCompiler.compile). Loadout: compiled at
## setup, never written in play (World.wand_table; null = a lab world: six slots, and a trigger's child spell takes
## these defaults, which mirror data/wand/wand.tres).

var slots_per_floor := PackedInt32Array([4, 6, 8])
var child_size_permille := 600
var child_range_permille := 600
var child_damage_permille := 500
## v0.8.0 BL (docs/roadmap/v0.8.0/BLADE_AUDIT.md B3): on a Blade run a slash's hit (On Hit, On Kill, On Finisher) casts
## a trigger's child spell this many times, each blade_cast_gap_ticks after the one before (the Gun's hits: once).
var blade_hit_casts := 2
var blade_cast_gap_ticks := 6
## v0.8.0 BL (B6): the hook cards whose child spells never split or explode again: a spec made by one of these hooks
## (its lineage holds one) takes none of their hooks (the first shot splits and explodes; its splits don't).
var once_per_line: Array[StringName] = [&"split_shot", &"shared_explosive"]
## v0.8.0 PF2 (owner O9; docs/roadmap/v0.8.0/evidence/PERF.md PF2): the hook cards whose child spells cast no trigger's
## spell: a spec made by one of these hooks (its lineage holds one) takes no trigger cut (the trigger still ends it, so
## the cards to its right don't rewrite it). Blade Storm's returning blades pass each enemy twice a throw and a Double
## Slash swing throws up to 36; each hit casting On Hit's slash multiplied the tick's work.
var cast_free_lines: Array[StringName] = [&"blade_storm"]
## v0.8.0 BL (B6): in one tick, past this many blasts of these hooks (Explosive's), a blast within its radius of one
## already set off that tick merges into it (it doesn't go off); one farther away still does. 0 = never merge.
var blast_merge_after := 8
var blast_merge_ids: Array[StringName] = [&"shared_explosive"]
## v0.8.0 P2 (owner O24, Void's black holes; BlackHoles): a hole's life (ticks), how many stand at once, its pull's
## reach (m) and step (m a tick), its core (m) and the ticks between its pulses.
var hole_ticks := 120
var hole_max := 3
var hole_pull_radius_m := 3.5
var hole_pull_step_m := 0.05
var hole_radius_m := 1.4
var hole_period_ticks := 12
## v0.8.0 MR (owner O91; SecondaryProc): a secondary attack's proc (per mille of its statuses, its hooks' statuses and
## its trigger casts' damage), and the cards that do nothing right of a trigger (Wand.flags).
var secondary_proc_permille := 500
var after_trigger_dead: Array[StringName] = [&"gun_echo", &"double_slash", &"gun_charge"]
## v0.8.0 RM (owner O91; Remnants): the remnants alive at once in all and per kind (RemnantRule.Kind order; the oldest
## replaced), and the activations a tick (then one LIMIT event).
var remnant_max := 96
var remnant_kind_max := PackedInt32Array([48, 16, 48, 48])
var remnant_activations_max := 64
## v0.8.0 RM (Engines.thermal_break): Thermal Break's hit (base + per burn stack) and its shatter's ticks (the view).
var thermal_base := 6
var thermal_per_burn := 4
var thermal_shatter_ticks := 18
## v0.6.5 WN5b (WandMigrationDefinition, data/wand/migration.tres): the retired v0.6 cards (item or ability ids) and
## what each becomes in a held build on a Blade run and on a Gun run (&"": refunded as shards). WandMigration reads
## them when a build that still holds an old card is loaded (an old save's carry or snapshot). Empty: no migration.
var migrate_ids: Array[StringName] = []
var migrate_blade: Array[StringName] = []
var migrate_gun: Array[StringName] = []


## The slot count on floor `f` (the last entry past the end; at least 1).
func slots_at(f: int) -> int:
	if slots_per_floor.is_empty():
		return 1
	return maxi(1, slots_per_floor[clampi(f - 1, 0, slots_per_floor.size() - 1)])
