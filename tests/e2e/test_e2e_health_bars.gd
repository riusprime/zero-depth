extends GutTest
## v0.8.0 N4 (owner O56, O57): the boss bar's damage chunk through main.tscn with real input only
## (Input.parse_input_event): a Gun run, backtick opens the dev panel, clicks turn God on and summon the first boss;
## the pad's right stick aims at it and the right trigger holds fire. The first hit opens a chunk behind the fill; it
## holds from that first hit while the shots keep landing (they don't restart it), then drains even under fire, and
## once the trigger is let go it drains to the fill.

const HOLD_FRAMES := 30  # HealthBarTrail.HOLD_S at 60 fps


func after_each() -> void:
	Input.action_release(&"shoot")


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## The right stick toward a sim-plane direction (the inverse of InputLatch.screen_to_sim).
func _aim(e: E2e, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(JOY_AXIS_RIGHT_X, (dir.x + dir.y) * c)
	e.joy_axis(JOY_AXIS_RIGHT_Y, -(dir.y - dir.x) * c)


func _aim_at_boss(e: E2e, reader: WorldReader) -> void:
	var i := reader.boss_index()
	if i >= 0:
		_aim(e, (reader.actor_pos(i) - reader.player_pos()).normalized())


func test_a_hit_boss_shows_a_chunk_that_holds_then_drains() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	await _click(e, main, "SpawnBoss")
	await e.frames(2)
	var reader := main.driver.reader
	assert_true(reader.boss_alive(), "a boss came")
	var hud := main.ui.find_child("Hud", true, false) as Hud
	var bar := hud.boss_bar
	for k in BossAi.INTRO_TICKS + 10:  # its rise: the sim's own fill, no chunk
		_aim_at_boss(e, reader)
		await e.frames(1)
	assert_almost_eq(bar.hp_fraction(), 1.0, 0.001, "risen: a full bar")
	assert_eq(bar.chunk_fraction(), 0.0, "no chunk yet")
	var trail := bar.hp_bar().trail
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var first := -1
	for k in 600:
		_aim_at_boss(e, reader)
		await e.frames(1)
		if bar.chunk_fraction() > 0.0:
			first = k
			break
	assert_gt(first, -1, "a shot landed: the chunk shows behind the fill")
	if first < 0:
		e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
		return
	var edge := trail.chunk
	for k in HOLD_FRAMES - 8:  # still firing, inside the hold
		_aim_at_boss(e, reader)
		await e.frames(1)
		assert_almost_eq(trail.chunk, edge, 0.0001, "it holds from the first hit (frame %d)" % k)
	var fill_in_hold := bar.shown_fraction()
	var drained_under_fire := false
	for k in 60:  # still firing: the later hits never restart the hold, so it drains
		_aim_at_boss(e, reader)
		await e.frames(1)
		if trail.chunk < edge - 0.0001:
			drained_under_fire = true
			break
	assert_true(drained_under_fire, "the chunk drains while the shots keep landing")
	assert_lt(bar.shown_fraction(), 1.0, "the boss was hurt")
	assert_lte(bar.shown_fraction(), fill_in_hold, "and the fill only went down")
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	for k in 150:
		await e.frames(1)
		if bar.chunk_fraction() == 0.0:
			break
	assert_eq(bar.chunk_fraction(), 0.0, "fire stopped: the chunk drained to the fill")
	assert_almost_eq(bar.shown_fraction(), bar.hp_fraction(), 0.001, "the fill is the boss's HP")
	assert_eq(get_errors().size(), 0, "no engine or script error")
