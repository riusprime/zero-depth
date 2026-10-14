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
## v0.8.0 BL (B6): in one tick, past this many blasts of these hooks (Explosive's), a blast within its radius of one
## already set off that tick merges into it (it doesn't go off); one farther away still does. 0 = never merge.
var blast_merge_after := 8
var blast_merge_ids: Array[StringName] = [&"shared_explosive"]
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
