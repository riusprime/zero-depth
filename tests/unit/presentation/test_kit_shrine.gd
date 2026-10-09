extends GutTest
## The owner's gamble shrine (v0.6.0 Step SR): with the new look the shrine view draws the owner's model at the sim's
## shrine position, standing on the floor over the sim's footprint and turned to the camera, keeps its cues (the
## price, the glow in reach, the spin and landing flash without a shader change, the shake on a refusal), and falls
## back to the code-built obelisk when the model is missing. Presentation only: the sim's spot and footprint are
## the same with either body.


func after_each() -> void:
	KitModels.dir = KitModels.DIR
	KitModels.clear_cache()


func _world() -> World:
	var w := World.new(5, PlayerTable.starting_values())
	w.gamble_id = w.take_root()
	w.gamble_pos = Vector2(3.4, -2.6)
	w.actors.set_pos(0, w.gamble_pos + Vector2(1.2, 0))
	return w


func _view(w: World, model: bool) -> GambleShrineView:
	var view := GambleShrineView.new()
	view.kit_model = model
	add_child_autofree(view)
	view.set_process(false)
	view.setup(WorldReader.new(w).gamble_pos())
	view.sync(WorldReader.new(w))
	return view


func test_the_view_loads_the_model_at_the_sim_position() -> void:
	var w := _world()
	var view := _view(w, true)
	assert_true(view.uses_model(), "the new look draws the owner's model")
	var piece := KitModels.get_piece(GambleShrineView.MODEL_ID)
	assert_same(
		view.model().mesh, piece["mesh"], "the kit's normalised mesh (cached, with its LODs)"
	)
	assert_eq(
		view.root.position, SimPlane.to_3d(w.gamble_pos), "placed at the sim's shrine position"
	)
	var box := view.model().global_transform * view.model().mesh.get_aabb()
	assert_almost_eq(box.position.y, 0.0, 0.001, "it stands on the floor")
	assert_almost_eq(
		box.end.y, float(KitModels.SPECS[&"gamble_shrine"]["height"]), 0.001, "its height"
	)
	var centre := SimPlane.to_sim(box.get_center())
	assert_almost_eq(centre.distance_to(w.gamble_pos), 0.0, 0.001, "centred on the shrine")


func test_the_model_covers_the_sim_footprint_like_the_old_plinth() -> void:
	var w := _world()
	var view := _view(w, true)
	var size: Vector3 = KitModels.get_piece(GambleShrineView.MODEL_ID)["size"]
	var foot := Gamble.collider(w.gamble_pos)
	# The model's sides line up with the footprint square's (both turned 45°): its half extents along the square's
	# axes cover the square (0.5 m) and stay within the old obelisk's 0.78 m plinth.
	assert_almost_eq(
		view.model().global_rotation.y, SimPlane.yaw_of(512), 0.001, "turned like the footprint"
	)
	assert_eq(
		foot.half, Vector2(Gamble.FOOTPRINT_HALF_M, Gamble.FOOTPRINT_HALF_M), "footprint kept"
	)
	for half: float in [size.x * 0.5, size.z * 0.5]:
		assert_gte(half, Gamble.FOOTPRINT_HALF_M, "the model covers the solid square")
		assert_lte(half, 0.8, "and stays about the old plinth's size")


func test_the_cues_work_on_the_model() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var view := _view(w, true)
	assert_true(view.price_label.visible, "near: the price floats above it")
	assert_eq(view.price_label.text, "25")
	assert_eq(view.price_label.modulate, GambleShrineView.PRICE_POOR, "red: can't afford it")
	var before := DamageFlashKeys.of(view)
	for m in view.materials():
		assert_true(m.emission_enabled, "emission on from creation")
	w.actors.set_pos(0, w.gamble_pos + Vector2(4.0, 0))
	view.sync(reader)
	view._process(1.0 / 60.0)
	var idle: float = view._light.light_energy
	w.actors.set_pos(0, w.gamble_pos + Vector2(1.2, 0))
	view.sync(reader)
	view._process(1.0 / 60.0)
	assert_gt(view._light.light_energy, idle, "the crystal's light brightens in reach")
	w.shards = 100
	view.sync(reader)
	w.input_buffer[3] = 1
	Gamble.interact(w)
	view.sync(reader)
	assert_true(view.spinning(), "a use spins the shards")
	var flashed := false
	for k in 80:
		view._process(1.0 / 60.0)
		flashed = flashed or view.materials().back().emission_energy_multiplier > 0.0
	assert_false(view.spinning(), "the spin ends")
	assert_true(flashed, "the model flashes on the landing")
	assert_eq(DamageFlashKeys.of(view), before, "the spin and the flash changed no shader")
	w.shards = 0
	w.input_buffer[3] = 1
	Gamble.interact(w)
	view.sync(reader)
	assert_true(view.shaking(), "a refused use shakes the model")


func test_a_missing_model_draws_the_obelisk() -> void:
	KitModels.clear_cache()
	KitModels.dir = "res://nowhere/"
	var view := _view(_world(), true)
	assert_false(view.uses_model(), "missing file: the code-built shrine (L15)")
	assert_not_null(view.price_label)
	KitModels.dir = KitModels.DIR
	KitModels.clear_cache()
	assert_false(_view(_world(), false).uses_model(), "the old look keeps the obelisk")
