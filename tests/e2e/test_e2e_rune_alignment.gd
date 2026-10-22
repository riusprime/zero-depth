extends GutTest
## v0.9.0 RA (owner W §4 A: "Several rune pillars can be rotated. The player aligns symbols according to a visual clue
## to unlock a reward"; Q22; Q23) through main.tscn with real input only: run seed SEED's floor 2 holds a rune puzzle
## (asserted below; a save of it continued from the menu). God from the dev panel (clicked with the mouse: the dev
## route, so the walk is safe), then the stick walks to each pillar, the shared prompt reads "Turn", E turns it a
## quarter until its face matches the carving; the last match opens the sealed doorway
## and the hidden room comes into sight; the hero walks in and its reward is there.

## Run seed SEED: floor 2 holds a rune puzzle (found with SaveLab, as Main builds floors; asserted below). v0.9.0 FV:
## five floors made floor 1 10-12 rooms, its dead ends all taken (no rune puzzle in 160 seeds), so the run is saved on
## floor 2 and continued, as a player's would be.
const SEED := 28
const FLOOR := 2


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func test_turn_the_pillars_to_the_carving_and_walk_in() -> void:
	var e := E2e.new(self)
	var run := SaveLab.run_state(SEED, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, SEED, PackedByteArray())))
	var main: Main = await e.boot(null, store, SEED)
	var focus := main.get_viewport().gui_get_focus_owner()
	assert_eq(focus.name if focus != null else &"", &"Continue", "the save offers Continue")
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 2 continues")
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
	# v0.9.0 FV: on floor 2 the last pillar can stand off the doorway's line, so the walk goes by the doorway, then to
	# the room's reward (its centre can be under the reward's stand), as the cracked wall's e2e walks.
	var inside := w.rewards.pos(w.rewards.index_of(w.runes.reward_id))
	assert_true(
		await e.walk_to(f.door_centers[f.rune_door], 0.6), "walked up to the opened doorway"
	)
	assert_true(
		await e.walk_to(inside, 1.2), "walked through the opened doorway into the hidden room"
	)
	assert_eq(f.room_of(w.player_pos()), f.rune_room, "inside")
	assert_true(main.view.rewards.node_of(w.runes.reward_id).visible, "the room's reward in sight")
	gut.p("RUNES_E2E| seed=%d presses=%d solve_ticks=%d" % [SEED, presses, solve_ticks])
