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
## v0.10.5 O2b (owner D38 (a)): a floor boss's HP multiplier at the expected power, per floor (entry f − 1, the last
## repeats); empty = off (the boss's HP takes the catch-up m, as before). CatchUp.pace_multiplier.
var boss_pace_permille := PackedInt32Array()
## v0.10.5 O2b: the power, per mille of the boss's expected power, past which its HP stops growing (the one-shot cap).
var boss_pace_cap_permille := 3000
## v0.10.5 O2b: the paced HP multiplier never goes under this, per mille.
var boss_pace_min_permille := 1000
var ability_level_permille := 120
var item_permille := 80
var combo_permille := 150


## Floor f's entry of a per-floor table (the last entry past its end; 1000 for an empty table).
static func at_floor(table: PackedInt32Array, f: int) -> int:
	return SpawnTable.at(table, f - 1, 1000)
