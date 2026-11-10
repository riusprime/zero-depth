extends GutTest
## v0.11.1 T1 (owner L7, "yes skip them"): the test switch Main.quick_start, which E2e.boot turns on. Play opens the
## build pick with no hub, the pick starts the run with no walk into the portal, and floor 1's arrival runs in one
## frame: the World it leaves is the one the full path (the hub, the portal, the arrival) leaves, tick and state hash,
## and the hero can act at once. Through real input only.


func after_each() -> void:
	Input.action_release(&"move_right")  # KEY_D


## Boots (`real`: the full path), starts a Blade run, and returns the World's tick and state hash once the hero
## landed; frees that game after.
func _landed_state(real: bool) -> Array:
	var e := E2e.new(self)
	e.real_start = real
	var main: Main = await e.boot()
	await e.start_from_menu()
	var out := (
		[main.driver.reader.tick(), main.driver.reader.state_hash()]
		if main.driver != null
		else [-1, ""]
	)
	main.queue_free()
	await e.frames(2)
	return out


func test_play_goes_to_the_build_pick_and_the_hero_acts_at_once() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_true(Main.quick_start, "boot() turns the test switch on")
	await e.tap(KEY_ENTER)  # Play
	await e.frames(2)
	assert_null(main.hub, "no hub")
	assert_not_null(main.get_node_or_null("UI/BuildPicker"), "Play opens the build pick")
	await e.tap(KEY_ENTER)  # the Blade
	await e.loaded()
	assert_true(main.is_playing(), "the pick starts the run")
	assert_true(await e.landed(2), "floor 1's arrival is over on the floor's first frame")
	var w := e.world()
	var from := w.player_pos()
	e.key(KEY_D, true)
	await e.frames(30)
	e.key(KEY_D, false)
	await e.frames(1)
	assert_gt(w.player_pos().distance_to(from), 0.5, "the hero walks at once")


func test_the_quick_start_lands_on_the_full_paths_world() -> void:
	var real := await _landed_state(true)
	var quick := await _landed_state(false)
	assert_gt(int(real[0]), 0, "the full path's arrival ran")
	assert_eq(quick[0], real[0], "the same tick as after the hub, the portal and the arrival")
	assert_eq(quick[1], real[1], "the same state hash")
