extends GutTest


func test_order_and_values_matter() -> void:
	var a := StateHasher.new()
	a.add_int(1)
	a.add_int(2)
	var b := StateHasher.new()
	b.add_int(2)
	b.add_int(1)
	assert_ne(a.finish_hex(), b.finish_hex())


func test_negative_zero_equals_zero() -> void:
	var a := StateHasher.new()
	a.add_f32(-0.0)
	a.add_f32s(PackedFloat32Array([-0.0, 1.5]))
	var b := StateHasher.new()
	b.add_f32(0.0)
	b.add_f32s(PackedFloat32Array([0.0, 1.5]))
	assert_eq(a.finish_hex(), b.finish_hex())


func test_world_hash_changes_with_state_and_repeats_with_seed() -> void:
	var w1 := KernelScenario.golden(5)
	var w2 := KernelScenario.golden(5)
	assert_eq(w1.state_hash(), w2.state_hash())
	w1.actors.pos_x[0] += 0.001
	assert_ne(w1.state_hash(), w2.state_hash())


func test_canonical_value_encodes_floats_as_float32() -> void:
	assert_eq(CanonicalValue.encode(0.1).size(), 5, "tag + 4 bytes")
	assert_eq(CanonicalValue.sha256_hex(-0.0), CanonicalValue.sha256_hex(0.0))
