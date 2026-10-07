class_name PlayerBuildState
extends RefCounted
## The per-floor state of the build and regen (v0.3.0 P; World.build_state), hashed once touched
## (PlayerBuild.touched). The regen modifier hook lives on World itself (World.regen_bonus_permille) so the run
## carry and the gamble shrine reach it by name.

## The way the character faces (1/4096 turns): the last move direction, -1 before the first move (melee then goes
## along the aim). Melee swings go this way (L29); shots go along the aim.
var facing_angle := -1
## The damage remainders the build's per mille leaves (thousandths), so the average damage is exact.
var melee_residue := 0
var bolt_residue := 0
## The last tick the player dealt or took damage (-1 = never), the regen accumulator (HP x PlayerRegen.REGEN_UNIT)
## and the last tick regen healed (-1 = never).
var combat_tick := -1
var regen_acc := 0
var regen_tick := -1


## Any damage or regen field away from its default. The facing alone doesn't count: the kernel worlds walk (it
## changes) but never swing, and their golden hashes stay as they were.
func touched() -> bool:
	return melee_residue != 0 or bolt_residue != 0 or combat_tick != -1 or regen_acc != 0
