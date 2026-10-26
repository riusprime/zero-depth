class_name CatchUpTable
extends RefCounted
## The hidden growth-matching difficulty's numbers (v0.5.5 DS; CatchUpDefinition compiled by
## ContentCompiler.compile_catch_up). All per mille; per-floor tables are indexed f − 1 and their last entry repeats.
## Part of the loadout (World.catch_up_table; null = off, so worlds without it hash as before).

var expected_permille := PackedInt32Array([1000])
var cap_permille := PackedInt32Array([1500])
var boss_expected_permille := PackedInt32Array([2000])
var boss_cap_permille := PackedInt32Array([2000])
var threat_cap_permille := 250
## v0.9.5 BH1 (Q2): each boss's HP spread, +- this per mille, drawn once per fight (CatchUp.read_boss).
var boss_spread_permille := 80
var ability_level_permille := 120
var item_permille := 80
var combo_permille := 150


## Floor f's entry of a per-floor table (the last entry past its end; 1000 for an empty table).
static func at_floor(table: PackedInt32Array, f: int) -> int:
	return SpawnTable.at(table, f - 1, 1000)
