extends GutTest
## The owner's boss attack pieces (BossPieceModels; docs/OWNER_TODO.md §3.5): each loads cut into the parts the game
## moves, at the request's size, on a matte material of his map; and with the files missing, every view still builds
## its code-made stand-in (L15).


func after_each() -> void:
	BossPieceModels.dir = BossPieceModels.DIR
	BossPieceModels.clear_cache()


func _size(piece: Dictionary) -> Vector3:
	var box := AABB()
	var first := true
	for part: Dictionary in (piece["parts"] as Dictionary).values():
		var b := (part["mesh"] as Mesh).get_aabb()
		b.position += part["at"]
		box = b if first else box.merge(b)
		first = false
	return box.size


func test_the_war_banner_is_a_pole_a_top_and_a_cloth_of_its_own() -> void:
	var p := BossPieceModels.get_piece(&"war_banner", ["pole", "top", "cloth"])
	assert_false(p.is_empty(), "listed and on disk")
	if p.is_empty():
		return
	assert_almost_eq(_size(p).y, 3.2, 0.01, "3.2 m tall")
	var cloth: Mesh = p["parts"]["cloth"]["mesh"]
	var arrays := cloth.surface_get_arrays(0)
	assert_not_null(
		arrays[Mesh.ARRAY_TEX_UV2], "the cloth's second UVs: across it and down from its top"
	)
	var mat := p["material"] as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "his colour map")
	assert_eq(mat.roughness, 1.0, "matte, lit like the walls")
	assert_eq(mat.metallic, 0.0)
	assert_lte(mat.albedo_texture.get_width(), 1024, "the kit's texture budget")


func test_the_hour_clock_is_0_7_m_across_its_minute_hand_apart_round_the_hub() -> void:
	var p := BossPieceModels.get_piece(&"hour_clock", ["clock", "minute_hand"])
	assert_false(p.is_empty())
	if p.is_empty():
		return
	assert_almost_eq(_size(p).x, 0.7, 0.01, "0.7 m across")
	var hand := (p["parts"]["minute_hand"]["mesh"] as Mesh).get_aabb()
	assert_lt(hand.position.length(), 0.3, "its hand starts by the hub (the origin)")
	assert_gt(hand.size.length(), 0.15, "and reaches toward the rim")


func test_the_siege_cart_is_a_body_on_four_wheels_front_on_plus_x() -> void:
	var p := BossPieceModels.get_piece(&"siege_cart", ["body"] + SiegeCartModel.MODEL_WHEELS)
	assert_false(p.is_empty())
	if p.is_empty():
		return
	var size := _size(p)
	assert_almost_eq(size.x, 2.0, 0.01, "2.0 m long")
	assert_between(size.z, 1.1, 1.35, "about 1.3 m wide")
	assert_between(size.y, 0.9, 1.15, "about 1.1 m tall")
	var body := (p["parts"]["body"]["mesh"] as Mesh).get_aabb()
	var wheels_from := INF
	var wheels_to := -INF
	for id: String in SiegeCartModel.MODEL_WHEELS:
		var at: Vector3 = p["parts"][id]["at"]
		var w := (p["parts"][id]["mesh"] as Mesh).get_aabb()
		wheels_from = minf(wheels_from, at.x + w.position.x)
		wheels_to = maxf(wheels_to, at.x + w.end.x)
		assert_almost_eq(w.get_center().x, 0.0, 0.05, "%s turns about its own hub" % id)
		assert_almost_eq(w.get_center().y, 0.0, 0.05)
		assert_almost_eq(at.y - w.size.y * 0.5, 0.0, 0.05, "%s stands on the floor" % id)
	assert_gt(
		body.end.x - wheels_to,
		wheels_from - body.position.x,
		"its tow bar (the front) reaches out on +X"
	)
	var root := Node3D.new()
	add_child_autofree(root)
	var parts := SiegeCartModel.build(root)
	assert_eq((parts[1] as Array).size(), 4, "the wheels that turn")
	assert_between(float(parts[2]), 0.2, 0.32, "their radius, for the roll")


func test_without_the_files_every_piece_builds_its_stand_in() -> void:
	BossPieceModels.dir = "res://assets/models/no_such_folder/"
	BossPieceModels.clear_cache()
	assert_true(BossPieceModels.get_piece(&"war_banner").is_empty())
	var banner := WarBannerViews.new()
	add_child_autofree(banner)
	assert_false(bool(banner.banner_model()["from_model"]), "the code-made banner")
	assert_almost_eq(
		float(banner.banner_model()["snap_y"]),
		WarlordLooks.BAR_Y - 0.6,
		0.0001,
		"snapping where it did"
	)
	var cart := SiegeCartViews.new()
	add_child_autofree(cart)
	assert_eq(cart.cart_wheels(), 4, "the code-made wagon")
	var clocks := JudgeTimeViews.new()
	add_child_autofree(clocks)
	assert_gt(clocks.orb_hand(0).get_child_count(), 0, "the code-made clock's hand")
	assert_almost_eq(clocks.orb_hand(0).position.z, 0.105, 0.0001, "over its code face")
