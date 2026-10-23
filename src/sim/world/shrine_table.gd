class_name ShrineTable
extends RefCounted
## v0.9.0 SH, HF (owner Q29b, W36: "Blood (health for a reward), Chaos (a challenge for an extra upgrade), Fortune (a
## resource for a random reward)"; "Healing fountains (rare, one use)"): the shrines' and the fountain's numbers in
## sim units (RunContentCompiler.compile_shrines from ShrineDefinition, data/shrines/shrines.tres). The defaults equal
## the data's starting values. Content: read in play, never written (WorldSnapshot keeps it as loadout).

## The floor's one shrine (ShrineDefinition.kind_weights is indexed by them). FORTUNE is today's gamble shrine
## (Gamble), its rules unchanged; BLOOD and CHAOS are Shrines'.
enum Kind { FORTUNE, BLOOD, CHAOS }

## Each kind's weight (per Kind) for the floor's shrine, and the first floor (1-based, within a loop) each may stand on.
var kind_weights := PackedInt32Array([400, 300, 300])
var kind_floor_min := PackedInt32Array([1, 1, 1])
## Blood: the price, a share (per mille) of the hero's current HP, rounded up and never more than HP - 1 (it can't
## kill); below blood_min_permille of max HP it refuses. One use; it raises blood_altars free altars beside it.
var blood_cost_permille := 300
var blood_min_permille := 250
var blood_altars := 1
## Chaos: the challenge's enemies on floors 1-5 (the last repeats), spawned at once round the shrine's room; clearing
## them raises chaos_altars free altars. chaos_elite_permille is step EL's hook (owner Q29b: "the Chaos challenge may
## bring an elite, a designed exception"): 0, so no elite, until the owner's ELITES.md G1.
var chaos_sizes := PackedInt32Array([5, 6, 6, 7, 7])
var chaos_elite_permille := 0
var chaos_altars := 1
## The healing fountain: the chance a floor has one (per mille), from fountain_floor_min; one press heals
## fountain_heal_permille of max HP (rounded half up, to full at most), then it is dry.
var fountain_permille := 250
var fountain_floor_min := 2
var fountain_heal_permille := 400
## How near (m) the hero stands to use a shrine or the fountain (the gamble shrine's own reach, 1.8 m).
var reach_m := 1.8


## The challenge's size on floor `floor_index` (1-based; the last repeats).
func chaos_size(floor_index: int) -> int:
	return SpawnTable.at(chaos_sizes, floor_index - 1, 0)
