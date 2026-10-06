class_name RngStream
extends RefCounted
## A named, mutable random stream over Deathventory's xorshift32 math (SIM_CONTRACTS §5).
## Its 32-bit state lives in World, so it is hashed and saved.

var state: int


func _init(seed_state: int = DeterministicRng.DEFAULT_REMAP_SEED) -> void:
	state = seed_state & 0xFFFFFFFF


static func derive(run_seed: int, stream_name: String) -> RngStream:
	return RngStream.new(DeterministicRng.derive_stream_seed(run_seed, StringName(stream_name)))


func next_u32() -> int:
	var step := DeterministicRng.next_u32(state)
	state = step.next_state
	return step.value


## A uniform int in [lo, hi], both inclusive.
func range_int(lo: int, hi: int) -> int:
	assert(hi >= lo)
	var step := DeterministicRng.below(state, hi - lo + 1)
	state = step.next_state
	return lo + step.value


## True with probability permille / 1000.
func chance_permille(permille: int) -> bool:
	return range_int(0, 999) < permille


## An index chosen in proportion to positive weights; -1 if the weights are invalid.
func pick_weighted(weights: PackedInt32Array) -> int:
	var step := DeterministicRng.weighted_index(state, weights)
	if step == null:
		return -1
	state = step.next_state
	return step.value
