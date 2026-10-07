extends GutTest
## The portal transit (v0.3.5 PT; owner F19, F20; EI-03): taking the portal holds the world still for
## BossFlow.enter_ticks (input ignored, the floor not over yet), then the floor ends exactly once; a floor after the
## first opens with arrive_ticks of the same hold before control returns; reduced motion shortens both; the transit
## is hashed.

const LONG := 1 << 24


## A real floor (the app's FloorScenario, as test_run_flow builds it) with an invulnerable player.
func _floor_world(seed_value: int) -> World:
	var w := FightLab.floor_world(seed_value, 1)
	w.floor_count = 3
	w.actors.invuln[0] = LONG
	return w


func _move(dir: Vector2, buttons: int = 0) -> InputFrame:
	return InputFrame.make(
		Vector2i(roundi(dir.x * SimTick.MOVE_MAX), roundi(dir.y * SimTick.MOVE_MAX)),
		Kin.angle_of(dir),
		1000,
		buttons,
		buttons
	)


func _events_of(w: World, kind: SimEvent.Kind) -> int:
	var n := 0
	for e in w.events_since(0):
		if e.kind == kind:
			n += 1
	return n


## Kills the boss so the portal opens, then walks into the gate until the portal takes the player.
func _into_portal(w: World) -> int:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 1, 1, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the portal is open")
	w.actors.set_pos(0, f.portal_front_point())
	var frame := _move(-f.portal_facing())
	for k in 240:
		w.step(frame)
		if w.boss_flow.state == BossFlow.State.ENTERING:
			return k
	return -1


func test_the_way_in_holds_the_world_then_ends_the_floor_once() -> void:
	var w := _floor_world(41)
	var reader := WorldReader.new(w)
	assert_gte(_into_portal(w), 0, "walking into the open gate takes the portal")
	assert_eq(_events_of(w, SimEvent.Kind.FLOOR_EXIT), 1, "FLOOR_EXIT as the hero goes in")
	assert_eq(reader.outcome(), 0, "the floor isn't over while the hero goes in")
	assert_true(reader.transit_holds())
	assert_true(reader.portal_active(), "the gate stays lit")
	var at := w.player_pos()
	var start := w.boss_flow.enter_tick
	var last := reader.portal_enter_progress()
	assert_gt(last, 0.0)
	# Input is ignored: walk, attack, dash every tick of the way in.
	var busy := _move(Vector2(1, 0), InputFrame.PRIMARY | InputFrame.DASH | InputFrame.UTILITY)
	var run_ticks := w.run_ticks
	for k in BossFlow.ENTER_TICKS - 1:
		w.step(busy)
		assert_eq(w.player_pos(), at, "the hero stands where the portal took it")
		var p := reader.portal_enter_progress()
		assert_gt(p, last, "the way in advances every tick")
		last = p
		assert_eq(reader.outcome(), 0)
	assert_eq(w.dash_ticks_left, 0, "no dash started")
	assert_eq(w.swing_t, 0, "no swing started")
	assert_eq(w.run_ticks, run_ticks, "the floor's clock stops")
	assert_eq(w.boss_flow.state, BossFlow.State.ENTERING, "one tick left")
	w.step(busy)
	assert_eq(w.boss_flow.state, BossFlow.State.EXITED, "after ENTER_TICKS the floor is over")
	assert_eq(w.boss_flow.exit_tick - start, BossFlow.ENTER_TICKS, "the way in lasts ENTER_TICKS")
	assert_eq(reader.outcome(), 3, "on to the next floor")
	assert_eq(reader.portal_enter_progress(), -1.0, "the way in is over")
	CombatLab.idle(w, 120)
	assert_eq(reader.outcome(), 3, "and stays over")
	assert_eq(_events_of(w, SimEvent.Kind.FLOOR_EXIT), 1, "the floor ends exactly once")
	assert_eq(w.player_pos(), at)


func test_the_arrival_holds_then_returns_control() -> void:
	var w := _floor_world(42)
	var reader := WorldReader.new(w)
	w.boss_flow.set_transit(false, true)
	assert_eq(w.boss_flow.arrive_ticks, BossFlow.ARRIVE_TICKS)
	assert_true(reader.transit_holds(), "the floor opens on the arrival")
	assert_eq(reader.arrival_progress(), 0.0)
	var at := w.player_pos()
	var go := _move(Vector2(1, 0), InputFrame.DASH)
	var last := -1.0
	for k in BossFlow.ARRIVE_TICKS:
		assert_true(reader.transit_holds(), "held on tick %d" % k)
		w.step(go)
		assert_eq(w.player_pos(), at, "the hero doesn't move while it materialises")
		var q := reader.arrival_progress()
		if k < BossFlow.ARRIVE_TICKS - 1:
			assert_gt(q, last, "the arrival advances every tick")
			last = q
	assert_eq(w.tick, BossFlow.ARRIVE_TICKS)
	assert_false(reader.transit_holds(), "control returns after ARRIVE_TICKS")
	assert_eq(reader.arrival_progress(), -1.0)
	assert_eq(w.run_ticks, 0, "the danger clock starts after the arrival")
	for k in 10:
		w.step(_move(Vector2(1, 0)))
	assert_gt(w.player_pos().x, at.x, "the stick moves the hero now")


func test_reduced_motion_shortens_both() -> void:
	var w := _floor_world(43)
	w.boss_flow.set_transit(true, true)
	assert_eq(w.boss_flow.enter_ticks, BossFlow.ENTER_TICKS_CALM)
	assert_eq(w.boss_flow.arrive_ticks, BossFlow.ARRIVE_TICKS_CALM)
	assert_lt(BossFlow.ENTER_TICKS_CALM, BossFlow.ENTER_TICKS)
	assert_lt(BossFlow.ARRIVE_TICKS_CALM, BossFlow.ARRIVE_TICKS)
	CombatLab.idle(w, BossFlow.ARRIVE_TICKS_CALM)
	assert_false(w.boss_flow.holds_world(), "the short arrival is over")
	assert_gte(_into_portal(w), 0)
	var start := w.boss_flow.enter_tick
	var used := CombatLab.until(w, func(x: World) -> bool: return x.boss_flow.exited(), 120)
	assert_gte(used, 0)
	assert_eq(w.boss_flow.exit_tick - start, BossFlow.ENTER_TICKS_CALM, "the short way in")


func test_the_first_floor_has_no_arrival_and_the_lengths_are_about_a_second() -> void:
	var w := _floor_world(44)
	assert_false(w.boss_flow.holds_world(), "a floor built without set_transit starts at once")
	w.boss_flow.set_transit(false, false)
	assert_false(w.boss_flow.holds_world(), "the run's first floor starts at once")
	assert_eq(w.boss_flow.enter_ticks, BossFlow.ENTER_TICKS)
	assert_almost_eq(float(BossFlow.ENTER_TICKS) / SimTick.TICKS_PER_SECOND, 1.0, 0.1, "~1.0 s in")
	assert_almost_eq(
		float(BossFlow.ARRIVE_TICKS) / SimTick.TICKS_PER_SECOND, 0.8, 0.1, "~0.8 s out"
	)


func test_the_transit_is_hashed_and_deterministic() -> void:
	var a := _floor_world(45)
	var b := _floor_world(45)
	assert_eq(a.state_hash(), b.state_hash())
	b.boss_flow.set_transit(false, true)
	assert_ne(a.state_hash(), b.state_hash(), "the arrival is part of the state")
	var hashes: Array[String] = []
	for k in 2:
		var w := _floor_world(46)
		w.boss_flow.set_transit(false, true)
		CombatLab.idle(w, BossFlow.ARRIVE_TICKS)
		_into_portal(w)
		CombatLab.idle(w, 30)
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same transit")
