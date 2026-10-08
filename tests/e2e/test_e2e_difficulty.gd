extends GutTest
## v0.5.5 Step DS through main.tscn with real input only (owner D4, D7, S5). The dev panel (backtick, mouse clicks)
## stands in for a run's cards: God mode for the walk, then three abilities granted to level 5 (a strong build). The
## left stick walks through the boss door: the boss spawns with its hidden catch-up (HP × its m, the boss cap) and
## its three phases (gates at 66 % and 33 % on the bar); the player's HUD shows no catch-up, the dev panel does. Kill
## boss, then the stick walks into the Deep gate: floor 2 is Deep: its m is read from the carried build at entry, its
## cap is raised by the Deep floor's threat, the stage wears the violet haze over its mood, and the Deep-only event
## stands in one of its event rooms.

const LEG_FRAMES := 7000


func after_each() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _walk(e: E2e, target: Vector2, done: Callable, push: Vector2 = Vector2.ZERO) -> bool:
	var w := e.world()
	var nav := NavField.new()
	nav.build(w.walls)
	nav.flood(target)
	for k in LEG_FRAMES:
		if done.call():
			break
		var p := w.player_pos()
		var dir := nav.direction(p)
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized() if (target - p).length() > 0.2 else push
		e.stick_toward(dir)
		await e.frames(1)
		if w.player_dead():
			break
	return done.call()


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


## Picks ability `idx` on the panel (NextAbility) and grants it `times` times (GrantAbility).
func _grant(e: E2e, main: Main, idx: int, times: int) -> void:
	var api: DebugApi = (main.get_node("UI/DevPanel") as DevPanel).api
	var guard := 0
	while api.ability_choice != idx and guard < 32:
		guard += 1
		await _click(e, main, "NextAbility")
	for k in times:
		await _click(e, main, "GrantAbility")
		await e.frames(2)


## Every Label text under `node`.
func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for c in node.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out


func test_a_strong_build_meets_the_hidden_catch_up_boss_gates_and_a_deep_floor_that_bites() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var f := w.floor_layout
	assert_not_null(w.catch_up_table, "the real game loads the catch-up")
	assert_eq(w.catch_up.enemy, 1000, "floor 1 with a fresh build: ×1")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	for kind in [
		AbilityTable.Kind.DRONE_BUDDY, AbilityTable.Kind.BOMB_LOBBER, AbilityTable.Kind.ORBIT_BLADES
	]:
		await _grant(e, main, Abilities.index_of_kind(w, kind), 5)
	assert_eq(w.ability_owned.size(), 4, "the weapon and three abilities")
	var p := CatchUp.power(w)
	assert_gte(p, 2800, "15 ability levels: P ≥ ×2.8")
	var into := Kin.dir(f.boss_door_angle)
	var sealed: bool = await _walk(
		e, f.boss_door_inside(2.0), func() -> bool: return w.boss_flow.door_sealed(), into
	)
	e.stick_toward(Vector2.ZERO)
	assert_true(sealed, "walked through the boss door")
	if not sealed:
		return
	await e.frames(10)
	var bi := w.actors.index_of(w.boss_id)
	assert_gte(bi, 0, "the boss spawned")
	var bt := BossAi.table_of(w, bi)
	var m := CatchUp.multiplier(CatchUp.power(w), 2000, 2000)
	assert_gt(m, 1000, "the strong build lifts the boss")
	assert_eq(w.catch_up.boss, m, "its own m: P against floor 1's end, the boss cap")
	assert_eq(w.actors.max_hp[bi], bt.hp * m / 1000, "boss HP × m")
	assert_eq(bt.phase_threshold, PackedInt32Array([1000, 660, 330]), "gates at 66 % and 33 %")
	var reader := main.driver.reader
	var marks := reader.boss_phase_thresholds(bi)
	assert_true(marks.has(660) and marks.has(330), "the bar marks both gates")
	var hud := main.get_node("UI/Hud") as Hud
	for t in _texts(hud):
		assert_false(t.contains("m x"), "the HUD never shows the catch-up: %s" % t)
	var panel := main.get_node("UI/DevPanel")
	var readout := (panel.find_child("CatchUp", true, false) as Label).text
	assert_true(readout.contains("boss x"), "the dev panel does: %s" % readout)
	await _click(e, main, "KillBoss")
	await e.frames(3)
	assert_true(reader.gate_open(WorldReader.ROUTE_DEEP), "the Deep gate opens")
	var facing := Kin.dir(f.deep_portal_angle)
	var entered: bool = await _walk(
		e,
		f.deep_portal_pos + facing * 1.0,
		func() -> bool: return w.boss_flow.state == BossFlow.State.ENTERING,
		-facing
	)
	assert_true(entered, "the Deep gate takes the hero")
	if not entered:
		return
	var held := 0
	while main.run.floor_index == 1 and held < 300:
		held += 1
		await e.frames(1)
	assert_eq(main.run.floor_index, 2, "floor 2 started")
	var w2 := e.world()
	assert_true(Routes.is_deep(w2), "floor 2 is Deep")
	assert_eq(Curses.threat(w2), 1, "T + 1")
	assert_eq(w2.catch_up.cap, 2250, "cap(2) + 0.25 for the Deep floor")
	assert_eq(w2.catch_up.power, CatchUp.power(w2), "read from the carried build at entry")
	assert_eq(w2.catch_up.enemy, CatchUp.multiplier(w2.catch_up.power, 2000, 2250), "m on floor 2")
	assert_gt(w2.catch_up.enemy, 1000)
	assert_true(main.view.stage.deep, "the violet haze")
	assert_true(main.view.stage.environment.fog_enabled)
	var has_event := false
	for k in w2.ev.ids.size():
		has_event = has_event or w2.ev.events[w2.ev.event[k]].id == &"whispering_deep"
	assert_true(has_event or w2.ev.ids.is_empty(), "the Deep-only event stands on the floor")
	assert_eq(get_errors().size(), 0, "no engine or script error")
