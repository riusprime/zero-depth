extends GutTest
## v0.9.0 LK (owner Q21: "A new room type"; "1-2 a floor, short"; "a visible seal with a sound"; "a reward on clear")
## through main.tscn with real input only: the first run seed from 1 whose floor 2 holds a Lockdown (found with
## SaveLab, as Main builds floors; a save of it continued from the menu, as the rune e2e does: floor 1 holds one on
## about two floors in three). God from the dev panel (clicked with the mouse), then the stick walks into the Lockdown
## room: it seals, the bars come down into its doorways and the banner reads LOCKDOWN; each formation is cleared with
## the dev panel's Clear wave (clicked); the last opens the room: the bars rise out of sight and a free altar stands.

const FLOOR := 2


func after_each() -> void:
	E2e.center_sticks()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _seed() -> int:
	for s in range(1, 40):
		if SaveLab.floor_world(s, FLOOR).lockdown != null:
			return s
	return -1


func test_walk_into_a_lockdown_see_the_bars_clear_it_and_they_rise() -> void:
	var run_seed := _seed()
	assert_gt(run_seed, 0, "a floor-2 seed with a Lockdown")
	if run_seed < 0:
		return
	var e := E2e.new(self)
	var run := SaveLab.run_state(run_seed, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, run_seed, PackedByteArray())))
	var main: Main = await e.boot(null, store, run_seed)
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 2 continues")
	var w := e.world()
	assert_not_null(w.lockdown, "this floor has a Lockdown")
	if w.lockdown == null:
		return
	var f := w.floor_layout
	var room := f.lockdown_rooms[0]
	var view := main.view.lockdowns
	var hud: Hud = main.get_node("UI/Hud")
	assert_not_null(view, "the bars are built")
	assert_false(view.bars_visible(room), "open: no bars in sight")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	assert_true(
		await e.walk_to(Lockdowns.reward_spot(f, room), 0.8), "walked into the Lockdown room"
	)
	assert_eq(w.lockdown.room, room, "it sealed")
	await e.frames(30)
	assert_eq(view.bars_down(room), 1.0, "the bars came down into its doorways")
	assert_true(view.bars_visible(room))
	assert_true(hud.lockdown_hud.visible, "the banner")
	assert_eq(
		hud.lockdown_hud.title.text,
		tr("HUD_LOCKDOWN") if w.lockdown.kind == 0 else tr("HUD_LOCKDOWN_HAZARD")
	)
	var sealed_tick := w.lockdown.sealed_tick
	var clicks := 0
	while w.lockdown.sealed() and clicks < 12:
		await e.frames(75)  # the next formation stands
		await e.tap(KEY_QUOTELEFT)
		await _click(e, main, "ClearWave")
		await e.tap(KEY_QUOTELEFT)
		clicks += 1
		await e.frames(5)
	assert_false(w.lockdown.sealed(), "cleared")
	assert_eq(w.lockdown.cleared, PackedInt32Array([room]))
	assert_eq(w.lockdown.forced.size(), 0, "by the clear, not the cap")
	var secs := float(w.lockdown.clear_tick - sealed_tick) / 60.0
	await e.frames(int(LockdownView.RISE_S * 60.0) + 30)
	assert_eq(view.bars_down(room), 0.0, "the bars rose")
	assert_false(view.bars_visible(room), "out of sight")
	assert_eq(hud.lockdown_hud.progress.text, tr("HUD_LOCKDOWN_CLEARED"), "the exits are open")
	var altar := w.lockdown.reward_ids[0]
	assert_true(main.view.rewards.node_of(altar).visible, "its altar in sight")
	gut.p(
		(
			"LK_E2E| seed=%d room=%d kind=%d clicks=%d seconds_sealed=%.1f"
			% [run_seed, room, f.lockdown_kinds[0], clicks, secs]
		)
	)
