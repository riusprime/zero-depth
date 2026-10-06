extends GutTest


func test_all_data_validates() -> void:
	var repo := ContentRepository.load_all()
	assert_gt(repo.paths.size(), 0, "the scanner found data")
	for i in repo.errors():
		fail_test("%s: %s (%s)" % [i.path, i.message, i.code])
	assert_eq(repo.count(&"player"), 1)
	assert_eq(repo.count(&"biomes"), 1)


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
	assert_eq(
		[a.hp, a.radius_m, a.move_speed, a.dash_distance_m, a.dash_ticks, a.dash_cooldown_ticks],
		[b.hp, b.radius_m, b.move_speed, b.dash_distance_m, b.dash_ticks, b.dash_cooldown_ticks]
	)
