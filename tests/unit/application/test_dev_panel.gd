extends GutTest
## The dev panel's release gate and its single-tick step (PLAN v0.0.1 Step 12).


func test_release_builds_keep_it_closed() -> void:
	assert_false(DevPanel.unlocked(false))
	assert_true(DevPanel.unlocked(true))


func test_step_advances_exactly_one_tick() -> void:
	var driver := SimDriver.new()
	driver.setup(World.new(1, PlayerTable.starting_values()))
	driver.input_source = func() -> Array: return [Vector2.ZERO, Vector2.RIGHT, 1.0]
	driver.debug = DebugApi.new(driver.world)
	add_child_autofree(driver)
	driver.debug.toggle_pause()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t := driver.world.tick
	driver.debug.request_step()
	for i in 5:
		await get_tree().physics_frame
	assert_eq(driver.world.tick, t + 1, "one request, one tick")
	assert_eq(driver.debug.hash_now(), driver.world.state_hash())


func test_panel_strings_use_keys() -> void:
	var panel := DevPanel.new(DebugApi.new(World.new(1, PlayerTable.starting_values())))
	for b in panel.find_children("*", "Button", true, false):
		assert_true((b as Button).text.begins_with("UI_DEV_"), (b as Button).name)
	panel.free()
