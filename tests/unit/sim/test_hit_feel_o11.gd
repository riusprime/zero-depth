extends GutTest
## v0.10.5 O11 (the lead's overnight pick): F1 a direct hit pushes a normal enemy back (an elite half, a boss none,
## walls stop it), F2 a dash cancels a Blade swing's recovery only and the combo goes on, F3 the finisher's recovery.

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT


func _world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.dummy_speed = 0.0
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, aim, 300, held, pressed)


## Swings the first slash at a dummy 1.2 m ahead; returns how far (x) it ended up pushed.
func _pushed_by() -> float:
	var w := _world()
	var at := w.player_pos() + Vector2(1.2, 0)
	var d := w.add_dummy(at, 0.35, 900)
	w.step(_f(0, P))
	while w.swing_t > 0:
		w.step(_f())
	for _k in 12:
		w.step(_f())
	return w.actors.pos(w.actors.index_of(d)).x - at.x


func test_a_slash_pushes_a_normal_enemy_015_m() -> void:
	assert_almost_eq(_pushed_by(), 0.15, 0.002)


func test_the_finisher_pushes_045_m() -> void:
	var w := _world()
	for k in 3:
		w.step(_f(0, P))
		while w.swing_t > 0:
			w.step(_f())
	w.step(_f(0, P))  # the finisher starts
	var d := w.add_dummy(w.player_pos() + Vector2(1.8, 0), 0.35, 900)
	var at := w.actors.pos(w.actors.index_of(d))
	while w.swing_t > 0:
		w.step(_f())
	for _k in 12:
		w.step(_f())
	assert_almost_eq(w.actors.pos(w.actors.index_of(d)).x - at.x, 0.45, 0.01)


func test_an_elite_is_pushed_half_and_a_boss_not_at_all() -> void:
	var w := _world()
	var e := w.actors.index_of(w.add_dummy(Vector2(5, 0), 0.35, 500))
	w.actors.kinds[e] = ActorStore.Kind.BREAKER
	BladeForms.hit_push(w, e, Vector2.ZERO, 0.4)
	assert_eq(w.blade.k_ids.size(), 1)
	assert_almost_eq(w.blade.k_step[0] * 8.0, 0.2, 0.001)
	var w2 := _world()
	var bi := w2.actors.index_of(w2.add_dummy(Vector2(6, 0), 0.35, 500))
	w2.actors.kinds[bi] = ActorStore.Kind.GATEKEEPER
	BladeForms.hit_push(w2, bi, Vector2.ZERO, 0.4)
	assert_eq(w2.blade.k_ids.size(), 0, "a boss is never pushed")


func test_a_wall_behind_the_enemy_stops_the_push() -> void:
	var w := _world()
	var start := w.player_pos()
	# The dummy (r 0.35) at 1.2 m ahead; a wall whose face is 0.05 m behind its far side leaves 0.05 m of room.
	w.set_walls([Obb.make(start + Vector2(1.2 + 0.35 + 0.05 + 0.5, 0.0), Vector2(0.5, 6.0), 0)])
	var d := w.add_dummy(start + Vector2(1.2, 0), 0.35, 900)
	w.step(_f(0, P))
	while w.swing_t > 0:
		w.step(_f())
	for _k in 12:
		w.step(_f())
	var moved := w.actors.pos(w.actors.index_of(d)).x - (start.x + 1.2)
	assert_lt(moved, 0.1, "pushed no further than the wall allows")
	assert_gt(moved, -0.01)


func _bolt_push(crit: bool) -> float:
	var w := _world()
	w.player.crit_chance_permille = 1000 if crit else 0
	w.add_dummy(w.player_pos() + Vector2(3, 0), 0.35, 900)
	var after := w.last_event_seq()
	for _k in 40:
		w.step(_f(S))
		if not w.blade.k_ids.is_empty():
			break
	assert_false(w.events_since(after).is_empty())
	return w.blade.k_step[0] * 8.0


func test_a_bolt_pushes_006_m_and_a_crit_012_m() -> void:
	assert_almost_eq(_bolt_push(false), 0.06, 0.001)
	assert_almost_eq(_bolt_push(true), 0.12, 0.001)


func test_the_values_are_in_the_data() -> void:
	var t := ContentCompiler.compile_player(
		ContentRepository.load_all().get_def(&"player", &"runner")
	)
	assert_almost_eq(t.hit_push_m, 0.15, 0.0001)
	assert_almost_eq(t.finisher_push_m, 0.45, 0.0001)
	assert_almost_eq(t.bolt_push_m, 0.06, 0.0001)
	assert_almost_eq(t.bolt_crit_push_m, 0.12, 0.0001)


# --- F2 ---------------------------------------------------------------------------------------------------------
func _until_swing_t(w: World, t: int) -> void:
	for _k in 40:
		if w.swing_t == t:
			return
		w.step(_f())


func test_a_dash_in_recovery_ends_the_swing_and_keeps_the_combo() -> void:
	var w := _world()
	w.step(_f(0, P))
	var cur := PlayerKit.current_step(w)
	_until_swing_t(w, cur.active_tick + 2)  # inside the recovery
	assert_eq(w.combo_step, 0)
	w.step(_f(0, InputFrame.DASH))
	assert_eq(w.swing_t, 0, "the swing ended")
	assert_true(w.is_dashing())
	assert_gt(w.combo_window, 0)
	while w.is_dashing():
		w.step(_f())
	var left := w.combo_window
	assert_gt(left, 0, "the combo window outlasts a 9 tick dash")
	w.step(_f(0, P))
	assert_eq(w.combo_step, 1, "the next press continues the combo")


func test_a_dash_in_start_up_or_on_the_active_tick_does_not_cancel() -> void:
	var w := _world()
	w.step(_f(0, P))
	var cur := PlayerKit.current_step(w)
	assert_lt(w.swing_t, cur.active_tick)
	assert_false(PlayerKit.cancel_recovery(w), "start-up")
	assert_gt(w.swing_t, 0)
	_until_swing_t(w, cur.active_tick)
	assert_eq(w.swing_t, cur.active_tick)
	assert_false(PlayerKit.cancel_recovery(w), "the active tick")
	w.step(_f(0, InputFrame.DASH))
	assert_gt(w.swing_t, 0, "the swing goes on")


# --- F3 ---------------------------------------------------------------------------------------------------------
func test_the_finisher_recovers_in_18_ticks_and_the_combo_is_68() -> void:
	var t := PlayerTable.starting_values()
	assert_eq(t.step(3).recovery_ticks(), 18)
	var total := 0
	for k in 4:
		total += t.step(k).ticks
	assert_eq(total, 68)
