extends GutTest
## Aim assist in the real game: aimed a few degrees off an enemy (the dev panel spawns one), the frame the sim gets
## turns about a tenth of the way toward it, with the mouse and with the right stick; with Options' Aim assist off
## (main menu, keyboard only) the frame holds the raw aim. Input events only; reads of nodes and the World are fine.

## How far off the enemy the player aims, in degrees.
const OFF_DEG := 6.0
## 1/4096-turn units in a degree.
const UNITS_PER_DEG := 4096.0 / 360.0


func _focused(main: Main) -> Control:
	return main.get_viewport().gui_get_focus_owner()


func _key_to(e: E2e, main: Main, key: Key, target: StringName, budget: int = 24) -> bool:
	for k in budget:
		if _focused(main) != null and _focused(main).name == target:
			return true
		await e.tap(key)
	return _focused(main) != null and _focused(main).name == target


## A run with God on and one freshly spawned enemy; returns its actor id.
func _run_with_enemy(e: E2e, main: Main) -> int:
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await e.click_dev("God")
	var w := e.world()
	var before := 0
	for i in range(1, w.actors.size()):
		before = maxi(before, w.actors.ids[i])
	await e.click_dev("SpawnEnemy")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)  # close the panel: the run goes on
	var id := -1
	for i in range(1, w.actors.size()):
		if w.actors.ids[i] > before and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			id = w.actors.ids[i]
	assert_gt(id, 0, "an enemy came")
	var i := w.actors.index_of(id)
	assert_false(EnemyAi.is_critter(w.actors.kinds[i]), "a target kind")
	for k in 120:  # It rises in invulnerable (no target yet); then it can be hit
		if w.actors.invuln[w.actors.index_of(id)] == 0:
			break
		await e.frames(1)
	assert_eq(w.actors.invuln[w.actors.index_of(id)], 0, "it has risen")
	return id


## The point OFF_DEG degrees clockwise of the enemy, at its distance from the hero, as a screen position.
func _beside(main: Main, id: int) -> Vector2:
	var w := main.driver.world
	var hero := w.player_pos()
	var to := w.actors.pos(w.actors.index_of(id)) - hero
	var p := hero + to.rotated(-deg_to_rad(OFF_DEG))
	return main.view.rig.camera.unproject_position(SimPlane.to_3d(p, SimPlane.CORE_HEIGHT))


static func _units(a: int, b: int) -> int:
	return ((a - b + 2048) & 4095) - 2048


## The recorded aim's turn from the raw aim (1/4096 turns), and the raw aim's angle to the enemy (degrees).
func _turn(main: Main, id: int) -> Array:
	var raw: Vector2 = (main.view.get_node("PlayerInput") as PlayerInput).raw_aim()
	var w := main.driver.world
	var to := w.actors.pos(w.actors.index_of(id)) - w.player_pos()
	return [
		_units(main.driver.last_frame.aim_angle, Kin.angle_of(raw)), rad_to_deg(raw.angle_to(to))
	]


func _assert_a_tenth(got: Array, how: String) -> void:
	var off: float = got[1]
	assert_almost_eq(
		off, OFF_DEG, 1.5, "%s: the raw aim is about %s° off the enemy" % [how, OFF_DEG]
	)
	var want := off * 0.1 * UNITS_PER_DEG
	assert_almost_eq(float(got[0]), want, 2.0, "%s: the aim turned a tenth of the way" % how)


func test_the_aim_turns_a_tenth_toward_an_enemy_with_the_mouse_and_the_stick() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	var id := await _run_with_enemy(e, main)
	await e.mouse_to(_beside(main, id))
	await e.frames(2)
	_assert_a_tenth(_turn(main, id), "mouse")
	# The right stick, pushed along the same raw direction (screen-relative: the inverse of the +45° turn).
	var w := main.driver.world
	var to := w.actors.pos(w.actors.index_of(id)) - w.player_pos()
	var dir := to.normalized().rotated(-deg_to_rad(OFF_DEG))
	var c := InputLatch.C45
	e.joy_axis(JOY_AXIS_RIGHT_X, (dir.x + dir.y) * c)
	e.joy_axis(JOY_AXIS_RIGHT_Y, -(dir.y - dir.x) * c)
	await e.frames(2)
	assert_eq((main.view.get_node("PlayerInput") as PlayerInput).device, PlayerInput.Device.GAMEPAD)
	_assert_a_tenth(_turn(main, id), "stick")
	E2e.center_sticks()


func test_with_aim_assist_off_in_options_the_frame_holds_the_raw_aim() -> void:
	var profile := ProfileStore.new("")
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	assert_true(await _key_to(e, main, KEY_DOWN, &"Options"), "down to Options")
	await e.tap(KEY_ENTER)
	await e.frames(2)
	assert_true(await _key_to(e, main, KEY_DOWN, &"TabControls"), "down to Controls")
	await e.tap(KEY_RIGHT)
	assert_true(await _key_to(e, main, KEY_DOWN, &"aim_assist"), "down to Aim assist")
	await e.tap(KEY_RIGHT)  # On -> Off
	await e.frames(2)
	assert_eq(GameSettings.get_value(profile, "aim_assist"), "off")
	await e.tap(KEY_ESCAPE)  # to the category
	await e.tap(KEY_ESCAPE)  # out of Options
	await e.frames(2)
	assert_null(main.get_node_or_null("UI/OptionsMenu"), "Options closed")
	assert_true(await _key_to(e, main, KEY_UP, &"Play"), "up to Play")
	var id := await _run_with_enemy(e, main)
	await e.mouse_to(_beside(main, id))
	await e.frames(2)
	var got := _turn(main, id)
	assert_almost_eq(float(got[1]), OFF_DEG, 1.5, "the raw aim is about 6° off the enemy")
	assert_eq(got[0], 0, "off: the frame holds the raw aim")
