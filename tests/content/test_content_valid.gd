extends GutTest


func test_all_data_validates() -> void:
	var repo := ContentRepository.load_all()
	assert_gt(repo.paths.size(), 0, "the scanner found data")
	for i in repo.errors():
		fail_test("%s: %s (%s)" % [i.path, i.message, i.code])
	assert_eq(repo.count(&"player"), 1)
	assert_eq(repo.count(&"biomes"), 3)
	assert_eq(repo.count(&"credits"), 1)
	assert_eq(repo.count(&"utility"), 2, "guard and blink")


func test_manifest_hash_is_stable_across_loads() -> void:
	var a := ContentRepository.load_all().manifest_hash
	var b := ContentRepository.load_all().manifest_hash
	assert_eq(a.length(), 64)
	assert_eq(a, b)


func test_player_compiles_to_ticks() -> void:
	var def: PlayerDefinition = ContentRepository.load_all().get_def(&"player", &"runner")
	var t := ContentCompiler.compile_player(def)
	assert_eq(t.dash_ticks, 9, "0.15 s at 60 Hz")
	assert_eq(t.dash_cooldown_ticks, 48, "0.8 s at 60 Hz")
	assert_almost_eq(t.move_speed, 0.1, 1e-9, "6 m/s is 0.1 m per tick")


func test_compiled_player_matches_the_kernel_starting_values() -> void:
	# The golden and smoke worlds use PlayerTable.starting_values(); the data must agree with it.
	var def: PlayerDefinition = ContentRepository.load_all().get_def(&"player", &"runner")
	var a := ContentCompiler.compile_player(def)
	var b := PlayerTable.starting_values()
	for prop in a.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["name"] != "combo":
			assert_eq(a.get(prop["name"]), b.get(prop["name"]), prop["name"])
	assert_eq(a.combo.size(), b.combo.size(), "combo steps")
	for k in mini(a.combo.size(), b.combo.size()):
		var x := a.combo[k].to_array()
		var y := b.combo[k].to_array()
		for j in x.size():
			if x[j] is float:
				assert_almost_eq(x[j], y[j], 1e-6, "combo[%d] field %d" % [k, j])
			else:
				assert_eq(x[j], y[j], "combo[%d] field %d" % [k, j])


func test_the_combo_compiles_to_the_four_slashes() -> void:
	# v0.3.0 L11: the data's four steps in ticks (the starting-value table in FOUR_SLASHES.md).
	var def: PlayerDefinition = ContentRepository.load_all().get_def(&"player", &"runner")
	var c := ContentCompiler.compile_player(def).combo
	var got := []
	for s in c:
		got.append(
			[s.motion, s.ticks, s.active_tick, s.half_arc, s.damage, s.hitstop_ticks, s.sweep_ticks]
		)
	assert_eq(
		got,
		[
			[SwingStep.Motion.SLASH_RIGHT_TO_LEFT, 13, 2, 683, 10, 3, 5],
			[SwingStep.Motion.SLASH_LEFT_TO_RIGHT, 14, 3, 683, 10, 3, 5],
			[SwingStep.Motion.THRUST, 16, 4, 228, 12, 4, 4],
			[SwingStep.Motion.SPIN, 31, 7, 2048, 24, 7, 9],
		]
	)


func test_the_run_validates_and_catches_bad_values() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"run"), 1, "one run definition (v0.3.0 B)")
	var def: RunDefinition = (load("res://data/run/three_floors.tres") as RunDefinition).duplicate()
	assert_eq(def.validate().size(), 0)
	def.floors = 0
	def.biomes = []
	def.enemy_hp_per_floor = -0.1
	def.heal_between_floors = 1.5
	var codes := []
	for i in def.validate():
		codes.append(String(i.code))
	assert_has(codes, "not_positive", "floors must be > 0")
	assert_has(codes, "missing", "biomes can't be empty")
	assert_has(codes, "negative", "scaling can't be negative")
	assert_has(codes, "range", "the heal is a share of max HP")
