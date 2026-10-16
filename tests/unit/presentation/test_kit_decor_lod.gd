extends GutTest
## v0.8.0 P3 (owner O29): the kit's scattered decoration (grass, rubble, debris) is drawn from its coarsest generated
## level of detail (under half its triangles), the same box and material; a small code-made piece is drawn as it is.


static func _tris(m: Mesh) -> int:
	var idx: Variant = m.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	return (idx as PackedInt32Array).size() / 3


func test_kit_decoration_is_drawn_from_a_small_level_of_detail() -> void:
	for id: StringName in [&"grass_tuft", &"rubble_small", &"debris_low"]:
		var piece := StageKit.piece_of(id)
		if piece.is_empty():
			pass_test("no kit in this checkout")
			return
		var full: Mesh = piece["mesh"]
		var low := KitModels.decor_mesh(full)
		assert_gt(_tris(full), KitModels.DECOR_TRIS, "%s: the kit piece is big" % id)
		assert_lt(_tris(low), _tris(full) / 2, "%s: under half the triangles" % id)
		assert_gt(_tris(low), 50, "%s: still a real shape" % id)
		var a := full.get_aabb()
		var b := low.get_aabb()
		assert_almost_eq(b.size.y, a.size.y, a.size.y * 0.05, "%s: the same height" % id)
		assert_almost_eq(b.size.x, a.size.x, a.size.x * 0.05, "%s: the same width" % id)
		assert_same(KitModels.decor_mesh(full), low, "%s: cached" % id)


func test_a_small_piece_is_drawn_as_it_is() -> void:
	var piece := StageKit.piece_of(&"snow_drift")
	assert_false(piece.is_empty())
	assert_same(KitModels.decor_mesh(piece["mesh"]), piece["mesh"])
