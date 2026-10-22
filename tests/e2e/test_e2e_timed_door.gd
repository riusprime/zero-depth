extends GutTest
## v0.9.0 TD (owner W §2: "1. The player discovers the closed door. 2. Two interactive switches … must be activated.
## 3. Activating both opens the door … 6. The player must reach the entrance before the timer expires"; Q20; Q23)
## through main.tscn with real input only: run seed SEED's floor 1 holds a timed door (asserted below). God from the
## dev panel (clicked with the mouse: the dev route, so the walk is safe), then the stick walks to each rune switch,
## the shared prompt reads "Activate", E switches it on; the second opens the door and the secret room comes into
## sight; the hero walks through the doorway into it before the timer runs out, and the door stays open while the
## hero is inside.

## Run seed SEED: floor 1 holds a timed door (found with the floor plan, asserted below; v0.9.0 FV: 2 on the
## five-floor run, seed 3 before).
const SEED := 2


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_press_both_switches_and_walk_in_before_the_timer() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_not_null(w.timed, "this floor has a timed door")
	if w.timed == null:
		return
	var f := w.floor_layout
	var view := main.view.timed_door
	assert_not_null(view, "the door and its switches are drawn")
	assert_false(view.revealed, "the secret room unseen")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	for k in 2:
		var at := f.timed_switches[k]
		assert_true(await e.walk_to(at, 0.6), "walked up to switch %d" % k)
		await e.frames(2)
		assert_eq(hud.interact.prompt_text(), tr("TIMED_SWITCH_PROMPT"), "the shared prompt by it")
		await e.tap(KEY_E)
		await e.frames(2)
		assert_eq(w.interactables.state[w.timed.switches[k]], 1, "E switched it on")
	assert_eq(w.timed.state, TimedDoor.State.OPEN, "both: the door opens")
	assert_true(view.revealed, "and the secret room comes into sight")
	var t0 := w.timed.open_tick
	var inside := f.rooms[f.timed_room].get_center()
	assert_true(await e.walk_to(inside, 1.0), "walked through the doorway into the secret room")
	assert_lt(w.tick - t0, w.timed.timer_ticks, "before the timer ran out")
	assert_eq(f.room_of(w.player_pos()), f.timed_room, "inside")
	gut.p("TIMED_E2E| seed=%d walk_in_ticks=%d timer=%d" % [SEED, w.tick - t0, w.timed.timer_ticks])
	while w.tick - t0 < w.timed.timer_ticks + 30:
		await e.frames(10)
	assert_eq(w.timed.state, TimedDoor.State.HELD, "time's up with the hero inside: it stays open")
	assert_true(main.view.rewards.node_of(w.timed.reward_id).visible, "the room's reward in sight")
