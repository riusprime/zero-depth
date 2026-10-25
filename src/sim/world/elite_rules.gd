class_name EliteRules
extends RefCounted
## v0.9.0 EL (owner Q24, Q25; ELITES.md E0): where elites appear and what a kill gives, in sim units
## (RunContentCompiler.compile_elite_rules from EliteRulesDefinition, data/elites/rules.tres). The defaults equal the
## data's starting values. Content: read in play, never written (WorldSnapshot keeps it as loadout).

## The share of a floor's combat rooms holding an elite, per floor of a loop (1-based; the last repeats).
var room_permille := PackedInt32Array([0, 0, 0, 150, 250])
## At least this many rooms between two elite rooms; at most max_alive elites alive from the rooms.
var min_gap_rooms := 2
var max_alive := 1
## A killed elite drops its core's card with this chance (per mille).
var core_drop_permille := 300
## Breaker, Rift Hunter, Conduit (Elites.KINDS order).
var kind_weights := PackedInt32Array([1, 1, 1])
## The normal enemies with an Elite Lockdown's elite.
var lockdown_escort := 3
## v0.9.0 CF: how many enemies an elite counts as in a closed fight's at-once cap (ClosedFights.weight).
var elite_weight := 3


## The rooms' share on floor `floor_index` (1-based, within the loop; the last entry repeats).
func room_permille_on(floor_index: int) -> int:
	return SpawnTable.at(room_permille, floor_index - 1, 0)
