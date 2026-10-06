extends GutTest


func test_same_seed_same_sequence() -> void:
	var a := RngStream.derive(42, "combat")
	var b := RngStream.derive(42, "combat")
	for i in 100:
		assert_eq(a.next_u32(), b.next_u32())


func test_streams_are_independent() -> void:
	var a := RngStream.derive(42, "combat")
	var b := RngStream.derive(42, "loot")
	assert_ne(a.state, b.state)
	var c := RngStream.derive(42, "combat")
	b.next_u32()  # drawing from another stream never moves this one
	assert_eq(a.next_u32(), c.next_u32())


func test_matches_deathventory_math() -> void:
	# xorshift32 13/17/5 from 1: the first draw is 270369 (Deathventory's DeterministicRng).
	assert_eq(DeterministicRng.next_u32(1).value, 270369)
	assert_eq(
		DeterministicRng.next_u32(0).next_state, DeterministicRng.next_u32(0x6D2B79F5).next_state
	)


func test_range_is_inclusive_and_unbiased() -> void:
	var r := RngStream.derive(7, "test")
	var counts := PackedInt32Array([0, 0, 0])
	var n := 30000
	for i in n:
		var v := r.range_int(0, 2)
		assert_between(v, 0, 2)
		counts[v] += 1
	for c in counts:
		assert_almost_eq(float(c) / n, 1.0 / 3.0, 0.015)


func test_pick_weighted_rejects_bad_weights() -> void:
	var r := RngStream.derive(1, "test")
	assert_eq(r.pick_weighted(PackedInt32Array()), -1)
	assert_eq(r.pick_weighted(PackedInt32Array([1, 0])), -1)
	assert_between(r.pick_weighted(PackedInt32Array([1, 3])), 0, 1)
