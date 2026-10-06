# Ported from riusprime/deathventory@1d697803:src/domain/core/deterministic_rng.gd.
# Changes: weighted_index and the new below() use rejection sampling instead of `value % total`.
class_name DeterministicRng extends RefCounted

const DEFAULT_REMAP_SEED: int = 0x6D2B79F5
const FNV_OFFSET_BASIS_32: int = 0x811C9DC5
const FNV_PRIME_32: int = 0x01000193


static func derive_stream_seed(run_seed: int, stream_name: StringName) -> int:
	var h: int = FNV_OFFSET_BASIS_32
	var s: int = run_seed & 0xFFFFFFFF

	# Seed bytes little-endian
	var b0: int = s & 0xFF
	var b1: int = (s >> 8) & 0xFF
	var b2: int = (s >> 16) & 0xFF
	var b3: int = (s >> 24) & 0xFF

	var bytes: PackedByteArray = PackedByteArray([b0, b1, b2, b3, 0x3A])
	var lower_name: String = String(stream_name).to_lower()
	bytes.append_array(lower_name.to_utf8_buffer())

	for byte in bytes:
		h = (h ^ byte) & 0xFFFFFFFF
		h = (h * FNV_PRIME_32) & 0xFFFFFFFF

	if h == 0:
		h = DEFAULT_REMAP_SEED
	return h & 0xFFFFFFFF


static func next_u32(state: int) -> RngStep:
	var s: int = state & 0xFFFFFFFF
	if s == 0:
		s = DEFAULT_REMAP_SEED
	s ^= (s << 13) & 0xFFFFFFFF
	s ^= (s >> 17) & 0xFFFFFFFF
	s ^= (s << 5) & 0xFFFFFFFF
	s &= 0xFFFFFFFF

	var step := RngStep.new()
	step.value = s
	step.next_state = s
	return step


static func weighted_index(state: int, weights: PackedInt32Array) -> RngStep:
	if weights.is_empty():
		return null
	var total_weight: int = 0
	for w in weights:
		if w <= 0:
			return null
		total_weight += w
	if total_weight <= 0:
		return null

	var step := below(state, total_weight)
	var roll: int = step.value
	var running: int = 0
	var chosen_index: int = -1
	for i in range(weights.size()):
		running += weights[i]
		if roll < running:
			chosen_index = i
			break

	var result := RngStep.new()
	result.value = chosen_index
	result.next_state = step.next_state
	return result


## A uniform int in [0, n) with no modulo bias: draws above the largest multiple of n are rejected.
static func below(state: int, n: int) -> RngStep:
	assert(n > 0)
	var limit: int = 0x100000000 - (0x100000000 % n)
	var step := next_u32(state)
	while step.value >= limit:
		step = next_u32(step.next_state)
	var result := RngStep.new()
	result.value = step.value % n
	result.next_state = step.next_state
	return result
