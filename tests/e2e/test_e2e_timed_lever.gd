extends GutTest
## v0.9.5 TS (owner: "if the door closes when you are inside you should be able to open it from the inside"; Q7 (a): "a
## lever inside reopens the door for 5 s") through main.tscn with real input: run seed SEED's floor 1 holds a timed
## door (asserted below). God from the dev panel, the stick walks to both switches and into the secret room. The game
## never shuts the door on the hero (it holds), so the shut is the one thing set up here: the test puts the door in its
## shut state with the hero inside (a knock-back or teleport would). Then the stick walks to the lever, the shared
## prompt reads "Pull the lever", E opens the door for 5 s, and the stick walks out through the doorway, which then
## shuts behind the hero.

## Run seed SEED: floor 1 holds a timed door (see test_e2e_timed_door.gd).
const SEED := 2


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_get_shut_inside_pull_the_lever_and_walk_out() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_not_null(w.timed, "this floor has a timed door")
	if w.timed == null:
		return
	var f := w.floor_layout
	assert_gte(w.timed.lever, 0, "and a lever inside")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	for k in 2:
		assert_true(await e.walk_to(f.timed_switches[k], 0.6), "walked up to switch %d" % k)
		await e.frames(2)
		await e.tap(KEY_E)
		await e.frames(2)
	assert_eq(w.timed.state, TimedDoor.State.OPEN, "both switches: the door opens")
	var t0 := w.timed.open_tick
	assert_true(await e.walk_to(f.rooms[f.timed_room].get_center(), 1.0), "walked into the room")
	assert_lt(w.tick - t0, w.timed.timer_ticks, "before the 20 s ran out")
	# the door shuts with the hero inside (not reachable in play: it holds)
	w.timed.state = TimedDoor.State.SHUT
	for s in w.timed.switches:
		w.interactables.state[s] = 0
		w.interactables.enabled[s] = 1
	w.interactables.enabled[w.timed.lever] = 1
	await e.frames(3)
	assert_eq(f.room_of(w.player_pos()), f.timed_room, "still inside")
	assert_true(w.floor_layout.timed_door_wall != null)
	assert_true(await e.walk_to(f.timed_lever, 0.6), "walked up to the lever")
	await e.frames(2)
	assert_eq(
		hud.interact.prompt_text(), tr("TIMED_LEVER_PROMPT"), "the shared prompt by the lever"
	)
	await e.tap(KEY_E)
	await e.frames(2)
	assert_eq(w.timed.state, TimedDoor.State.OPEN, "pulled: the door is open again")
	var pulled := w.tick
	assert_true(await e.walk_to(f.rooms[f.timed_host].get_center(), 1.5), "walked out")
	var out_ticks := w.tick - pulled
	gut.p(
		(
			"TIMED_LEVER_E2E| seed=%d walk_out_ticks=%d window=%d"
			% [SEED, out_ticks, w.timed.lever_ticks]
		)
	)
	assert_lt(out_ticks, w.timed.lever_ticks, "within the 5 s")
	assert_ne(f.room_of(w.player_pos()), f.timed_room, "out of the secret room")
	while w.tick - pulled < w.timed.lever_ticks + 30:
		await e.frames(10)
	assert_eq(w.timed.state, TimedDoor.State.SHUT, "and the door shuts when the 5 s end")
