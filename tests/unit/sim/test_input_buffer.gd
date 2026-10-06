extends GutTest


func _dash_world() -> World:
	var w := World.new(1, PlayerTable.starting_values())
	w.dash_cooldown_left = 100  # dash unavailable, so presses stay buffered
	return w


func test_press_is_kept_for_six_ticks() -> void:
	var w := _dash_world()
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.DASH))
	assert_eq(w.buffered(InputFrame.DASH), 6)
	for i in 5:
		w.step(InputFrame.new())
	assert_eq(w.buffered(InputFrame.DASH), 1, "still buffered on the 6th tick")
	w.step(InputFrame.new())
	assert_eq(w.buffered(InputFrame.DASH), 0)


func test_buffered_dash_fires_when_it_becomes_available() -> void:
	var w := _dash_world()
	w.dash_cooldown_left = 3
	w.step(InputFrame.make(Vector2i(127, 0), 0, 0, 0, InputFrame.DASH))
	assert_false(w.is_dashing())
	w.step(InputFrame.make(Vector2i(127, 0), 0, 0, 0, 0))
	w.step(InputFrame.make(Vector2i(127, 0), 0, 0, 0, 0))
	assert_true(w.is_dashing(), "the buffered press started the dash")


func test_freeze_ticks_do_not_age_the_buffer() -> void:
	var w := _dash_world()
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.DASH))
	w.add_freeze(5)
	for i in 5:
		w.step(InputFrame.new())
	assert_eq(w.buffered(InputFrame.DASH), 6)
	assert_eq(w.tick, 6, "freeze ticks still count as ticks")


func test_freeze_is_capped() -> void:
	var w := _dash_world()
	w.add_freeze(100)
	assert_eq(w.freeze_ticks, SimTick.FREEZE_CAP_TICKS)
