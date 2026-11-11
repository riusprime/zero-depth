extends GutTest
## The lightning bolt (ZdBolt) is drawn by its shader from a few numbers: every bolt draws one fixed strip mesh, and a
## bolt that moves or flickers writes its ends, seed and flicker count, never a new mesh (bolt_ribbon.gdshader lays the
## jagged line out as ZdBolt.lines() does on the CPU; scripts/shots/gpu_fx_pairs.gd compares the pictures).

const A := Vector3(0, 0.6, 0)
const B := Vector3(4, 0.6, 3)


func _bolt() -> ZdBolt:
	var b := add_child_autofree(ZdBolt.new()) as ZdBolt
	b.visible = true
	return b


func _param(b: ZdBolt, layer: int, key: StringName) -> Variant:
	var mi := b.get_child(layer) as MeshInstance3D
	return (mi.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter(key)


func test_every_bolt_draws_the_one_fixed_strip() -> void:
	var one := _bolt()
	var two := _bolt()
	one.set_ends(A, B, 3)
	two.set_ends(A, B + Vector3(1, 0, 0), 4)
	var mesh := ZdBolt.strip_mesh()
	for b: ZdBolt in [one, two]:
		for layer in 2:
			assert_same((b.get_child(layer) as MeshInstance3D).mesh, mesh, "shared, never rebuilt")
	var arrays := mesh.surface_get_arrays(0)
	var points := ZdBolt.MAIN_POINTS + ZdBolt.FORK_MAX * ZdBolt.FORK_POINTS
	assert_eq((arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size(), points * 2, "two a point")
	var segs := ZdBolt.MAIN_POINTS - 1 + ZdBolt.FORK_MAX * (ZdBolt.FORK_POINTS - 1)
	assert_eq(
		(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), segs * 6, "two triangles a segment"
	)
	assert_eq(
		ZdBolt.MAIN_POINTS - 1, ZdBolt.SEG_MIN + ZdBolt.SEG_SPAN - 1, "room for the longest line"
	)


func test_the_shader_gets_the_line_s_numbers() -> void:
	var b := _bolt()
	b.position = Vector3(1, 0, 1)
	b.set_ends(A, B, 41, 0.2)
	for layer in 2:
		assert_eq(_param(b, layer, &"end_a"), A - b.position, "a, in the bolt's space")
		assert_eq(_param(b, layer, &"end_b"), B - b.position)
		assert_eq(_param(b, layer, &"bolt_seed"), 41)
		assert_eq(_param(b, layer, &"flicks"), 0)
		assert_almost_eq(float(_param(b, layer, &"width")), 0.2, 1e-6)
		assert_true(_param(b, layer, &"has_ends"), "shown")
	b._process(ZdBolt.FLICKER_S + 0.001)
	assert_eq(_param(b, 1, &"flicks"), 1, "a flicker is one number")


func test_a_seed_past_32_bits_keeps_its_low_bits() -> void:
	var b := _bolt()
	b.set_ends(A, B, 0x1_2345_6789)
	assert_eq(_param(b, 0, &"bolt_seed"), 0x2345_6789)
	b.set_ends(A, B, 0xFFFF_FFFF)
	assert_eq(_param(b, 0, &"bolt_seed"), -1, "the same 32 bits, signed")


func test_an_unchanged_bolt_writes_nothing_and_a_hidden_one_draws_nothing() -> void:
	var b := _bolt()
	b.set_ends(A, B, 8)
	var n := b.rebuilds
	b.set_ends(A, B, 8)
	assert_eq(b.rebuilds, n, "same ends, same seed: nothing written")
	b.set_ends(A, B + Vector3(0.5, 0, 0), 8)
	assert_eq(b.rebuilds, n + 1, "moved: its ends written again")
	b.visible = false
	b.visible = true  # (PackFx shows a bolt again when it reuses it)
	assert_false(_param(b, 0, &"has_ends"), "no line until its next ends")
	b._process(0.016)
	assert_false((b.get_child(0) as MeshInstance3D).visible)
	assert_false((b.get_child(1) as MeshInstance3D).visible)
