extends GutTest
## v0.9.0 RA (owner W §4 A: "Several rune pillars can be rotated. The player aligns symbols according to a visual clue
## to unlock a reward"; Q22; Q23) through main.tscn with real input only: run seed SEED's floor 1 holds a rune puzzle
## (asserted below). God from the dev panel (clicked with the mouse: the dev route, so the walk is safe), then the stick
## walks to each pillar, the shared prompt reads "Turn", E turns it a quarter until its face matches the carving; the
## last match opens the sealed doorway and the hidden room comes into sight; the hero walks in and its reward is there.

## Run seed SEED: floor 1 holds a rune puzzle (found with the floor plan, asserted below).
const SEED := 6


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_turn_the_pillars_to_the_carving_and_walk_in() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, SEED)
	await e.start_from_menu()
	var w := e.world()
	var hud: Hud = main.get_node("UI/Hud")
	assert_not_null(w.runes, "this floor has a rune puzzle")
	if w.runes == null:
		return
	var f := w.floor_layout
	var view := main.view.rune_view
	assert_not_null(view, "the pillars and the carving are drawn")
	assert_false(view.revealed, "the hidden room unseen")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var t0 := -1
	var presses := 0
	for k in w.runes.pillars.size():
		var entry := w.runes.pillars[k]
		assert_true(await e.walk_to(f.rune_pillars[k], 0.6), "walked up to pillar %d" % k)
		await e.frames(2)
		if t0 < 0:
			t0 = w.tick
		assert_eq(hud.interact.prompt_text(), tr("RUNE_PILLAR_PROMPT"), "the shared prompt by it")
		var guard := 0
		while w.interactables.state[entry] != w.runes.target[k] and guard < 4:
			var before := w.interactables.state[entry]
			await e.tap(KEY_E)
			await e.frames(2)
			assert_eq(w.interactables.state[entry], (before + 1) % 4, "E turned it a quarter")
			presses += 1
			guard += 1
		assert_eq(
			w.interactables.state[entry], w.runes.target[k], "pillar %d matches the carving" % k
		)
	assert_eq(w.runes.solved, 1, "all three: solved")
	await e.frames(2)
	assert_true(view.revealed, "and the hidden room comes into sight")
	var solve_ticks := w.tick - t0
	var inside := f.rooms[f.rune_room].get_center()
	assert_true(
		await e.walk_to(inside, 1.0), "walked through the opened doorway into the hidden room"
	)
	assert_eq(f.room_of(w.player_pos()), f.rune_room, "inside")
	assert_true(main.view.rewards.node_of(w.runes.reward_id).visible, "the room's reward in sight")
	gut.p("RUNES_E2E| seed=%d presses=%d solve_ticks=%d" % [SEED, presses, solve_ticks])
