extends GutTest
## Kit pieces (v0.5.9 Step 3): each owner model loads once and is normalised to a unit box (long side on +X,
## footprint -0.5..0.5, bottom at 0, top at 1), with its natural size from its height spec; a missing file gives {}.


func after_each() -> void:
	KitModels.dir = KitModels.DIR
	KitModels.clear_cache()


func test_every_piece_loads_into_the_unit_box() -> void:
	for id: StringName in KitModels.SPECS:
		var piece := KitModels.get_piece(id)
		assert_false(piece.is_empty(), "%s loads" % id)
		if piece.is_empty():
			continue
		var box: AABB = (piece["mesh"] as ArrayMesh).get_aabb()
		assert_almost_eq(
			box.position,
			Vector3(-0.5, 0, -0.5),
			Vector3.ONE * 0.001,
			"%s starts at the corner" % id
		)
		assert_almost_eq(box.size, Vector3.ONE, Vector3.ONE * 0.001, "%s fills the unit box" % id)
		var size: Vector3 = piece["size"]
		assert_almost_eq(
			size.y, float(KitModels.SPECS[id]["height"]), 0.001, "%s natural height" % id
		)
		assert_not_null(piece["material"], "%s keeps its textured material" % id)


func test_long_pieces_lie_along_x() -> void:
	for id: StringName in [&"wall_2m", &"car_wreck", &"slab_wide", &"chest"]:
		var size: Vector3 = KitModels.get_piece(id)["size"]
		assert_gt(size.x, size.z, "%s is longer in x than in z" % id)


func test_a_piece_is_read_once_and_a_missing_one_falls_back() -> void:
	var a := KitModels.get_piece(&"wall_1m")
	assert_same(KitModels.get_piece(&"wall_1m")["mesh"], a["mesh"], "cached")
	KitModels.clear_cache()
	KitModels.dir = "res://nowhere/"
	assert_eq(KitModels.get_piece(&"wall_1m"), {}, "missing file: the caller draws its primitive")
	assert_eq(KitModels.get_piece(&"no_such_piece"), {})


func test_roles() -> void:
	assert_has(KitModels.ids_with_role(&"wall"), &"wall_2m")
	assert_has(KitModels.ids_with_role(&"light"), &"fire_barrel")
	assert_eq(KitModels.ids_with_role(&"reward"), [&"chest"] as Array[StringName])
