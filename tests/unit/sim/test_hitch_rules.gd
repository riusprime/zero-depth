extends GutTest
## The catch-up rules that keep a hitch from eating game time (ARCHITECTURE §4). The real-time half of this
## proof is scripts/checks/hitch_probe.gd, which can't run under --fixed-fps.


func test_project_holds_the_tick_settings() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60)
	assert_eq(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame"), 4)
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))
	assert_eq(ProjectSettings.get_setting("physics/common/physics_jitter_fix"), 0.0)


func test_a_press_before_back_to_back_ticks_is_consumed_once() -> void:
	var driver := SimDriver.new()
	driver.setup(World.new(1, PlayerTable.starting_values()))
	driver.input_source = func() -> Array: return [Vector2.ZERO, Vector2.RIGHT, 1.0]
	driver.latch.note_pressed(InputFrame.DASH)
	for i in 4:  # a catch-up frame: four ticks with no input events between them
		driver.step_once()
	assert_true(
		driver.world.is_dashing() or driver.world.dash_cooldown_left > 0, "the dash happened"
	)
	assert_eq(driver.world.buffered(InputFrame.DASH), 0, "and was consumed")
	driver.free()
