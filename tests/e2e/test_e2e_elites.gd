extends GutTest
## v0.9.0 EL (owner Q24-Q26; G1 docs/roadmap/v0.9.0/ELITES.md, "ok go for those") through main.tscn with real input
## only: a run saved on floor 4 (elites appear only on floors 4-5) is continued from the menu; God from the dev panel
## (clicked with the mouse: the dev route, so the fight is safe); the stick walks into the floor's elite room: its elite
## arrives there (the owner's model, its framed bar with its name over it); the stick and the right trigger fight it
## (its ability's mark shows on the ground meanwhile; its HP cut to SHORT_HP first, test setup) until it falls; its
## bar goes with it.

## Floor 4 of the first run seed from FIRST_SEED with an elite room reached from the start hall without crossing an
## arena, a Lockdown or the Overrun room (so the walk seals nothing on its way; found with SaveLab, as Main builds
## floors).
const FLOOR := 4
const FIRST_SEED := 1
const TRIES := 40
const MAX_FRAMES := 9000
const CLOSE_M := 1.6
## Test setup: the elite's HP once it has arrived (its floor-4 HP, printed, is a long fight for the base Blade).
const SHORT_HP := 300


func after_each() -> void:
	E2e.center_sticks()


func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## [run seed, elite room] for the first floor-4 world whose elite room the hero walks to without sealing anything.
func _find() -> Array:
	for s in range(FIRST_SEED, FIRST_SEED + TRIES):
		var w := SaveLab.floor_world(s, FLOOR)
		if w.elites == null:
			continue
		var f := w.floor_layout
		var shut := f.arena_rooms.duplicate()
		shut.append_array(f.lockdown_rooms)
		if f.overrun_room >= 0:
			shut.append(f.overrun_room)
		var seen := LockdownRooms.reached(f, shut)
		for r in w.elites.rooms:
			for nb in f.neighbours(r):
				if seen[nb] == 1:  # its doorway opens off a room reached with everything shut
					return [s, r]
	return []


func test_meet_an_elite_on_floor_4_and_kill_it() -> void:
	var found := _find()
	assert_false(
		found.is_empty(), "a floor-4 seed with a reachable elite room within %d seeds" % TRIES
	)
	if found.is_empty():
		return
	var seed_value: int = found[0]
	var room: int = found[1]
	var e := E2e.new(self)
	var run := SaveLab.run_state(seed_value, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, seed_value, PackedByteArray())))
	var main: Main = await e.boot(null, store, seed_value)
	var focus := main.get_viewport().gui_get_focus_owner()
	assert_eq(focus.name if focus != null else &"", &"Continue", "the save offers Continue")
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	assert_eq(main.run.floor_index, FLOOR, "floor 4 continues")
	var w := e.world()
	assert_not_null(w.elites, "this floor has elite rooms")
	if w.elites == null:
		return
	await e.landed()
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	assert_eq(Elites.alive(w), 0, "no elite before you walk in")
	var f := w.floor_layout
	assert_true(await e.walk_to(f.rooms[room].get_center(), 1.5), "walked into the elite room")
	var id := -1
	for k in 120:
		if Elites.alive(w) > 0:
			id = w.elites.ids[0]
			break
		await e.frames(1)
	assert_gte(id, 0, "its elite arrived")
	if id < 0:
		return
	var kind := w.actors.kinds[w.actors.index_of(id)]
	assert_eq(kind, w.elites.room_kinds[w.elites.rooms.find(room)], "the archetype the floor drew")
	await e.frames(60)  # it rises (0.7 s of arrival)
	var node := main.view.actors.actor_node(id)
	assert_not_null(node, "drawn")
	var avatar := node.get_meta(&"enemy_avatar") as EliteAvatar
	assert_not_null(avatar, "with the elite's own avatar")
	assert_true(avatar.has_model(), "the owner's model")
	var bar := node.get_meta(&"elite_bar") as EliteBar
	assert_true(bar.visible, "its framed bar shows")
	assert_eq(bar.name_text(), tr(w.enemy_table(kind).name_key), "with its name")
	var r := WorldReader.new(w)
	var ei := w.actors.index_of(id)
	gut.p("EL_E2E| the elite arrived with %d HP (floor 4's scaling)" % w.actors.hp[ei])
	w.actors.hp[ei] = mini(w.actors.hp[ei], SHORT_HP)  # test setup: a short fight for the base Blade
	var saw_mark := false
	var trigger := false
	for fr in MAX_FRAMES:
		var i := w.actors.index_of(id)
		if i < 0 or w.actors.dead[i] == 1:
			break
		var p := r.player_pos()
		var to := r.actor_pos(i) - p
		var walk := to.normalized() * 0.4 if to.length() <= CLOSE_M else to.normalized()
		_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, walk)
		_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, to.normalized())
		if trigger:
			e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
			trigger = false
		elif r.swing_tick() == 0 and to.length() < CLOSE_M + 0.8:
			e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
			trigger = true
		await e.frames(1)
		var j := w.actors.index_of(id)
		if j >= 0 and r.elite_attack(j) == WorldReader.ELITE_ABILITY:
			if r.actor_state(j) == WorldReader.STATE_WINDUP:
				saw_mark = saw_mark or main.view.telegraphs.count() > 0
	e.joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	E2e.center_sticks()
	await e.frames(3)
	assert_eq(w.actors.index_of(id), -1, "the elite fell to the swings")
	assert_true(saw_mark, "its ability's mark showed on the ground while it wound up")
	assert_gte(w.elites.kill_tick, 0, "the kill is known")
	await e.frames(60)
	assert_null(main.view.actors.actor_node(id), "its body and bar are gone")
	gut.p(
		(
			"EL_E2E| seed=%d room=%d kind=%d killed_at_tick=%d card_dropped=%d"
			% [seed_value, room, kind, w.elites.kill_tick, w.elites.kill_dropped]
		)
	)
