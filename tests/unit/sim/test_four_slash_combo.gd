extends GutTest
## v0.3.0 L11 (owner: "sword should be a 4 moment combo, composed of 4 different kind of slashes the 4th being
## stronger"): each step's own shape (who gets hit at which angle and reach), sequencing and reset, damages,
## lunges, the finisher's hit-stop and recovery, the data's validation, and the items that read the combo.
## Aim angle 0 = +x; the player's and the dummies' radius is 0.35.

const P := InputFrame.PRIMARY
const K := ItemTable.Kind

var _tables: Array[ItemTable] = []


func before_all() -> void:
	_tables = ContentCompiler.compile_items(ContentRepository.load_all())


func _world(kinds: Array = []) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
	for k: int in kinds:
		for i in _tables.size():
			if _tables[i].kind == k:
				assert_true(w.add_item(i))
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, aim, 300, held, pressed)


## Presses melee, then steps until that swing has ended (the combo window is open again).
func _swing(w: World, aim: int = 0) -> void:
	w.step(_f(0, P, aim))
	while w.swing_t > 0:
		w.step(_f(0, 0, aim))


## Chains `n` swings at aim 0 so the next press starts step n.
func _chain(w: World, n: int) -> void:
	for i in n:
		_swing(w)


func _damage(w: World, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == SimEvent.Kind.DAMAGE:
			out.append(e)
	return out


func _amounts(events: Array[SimEvent]) -> Array:
	return events.map(func(e: SimEvent) -> int: return e.amount)


## True if step `step`, swung at aim 0, hits a dummy placed at `rel` from where the player stands when that
## step's hit lands (after its lunge).
func _hits(step: int, rel: Vector2) -> bool:
	var w := _world()
	_chain(w, step)
	var at := w.player_pos() + Vector2(w.player.step(step).lunge_m, 0)
	w.add_dummy(at + rel, 0.35, 500)
	var after := w.last_event_seq()
	_swing(w)
	assert_eq(w.combo_step, step, "swung step %d" % step)
	return not _damage(w, after).is_empty()


func _at(deg: float, dist: float) -> Vector2:
	return Kin.dir(int(round(deg * 4096.0 / 360.0))) * dist


func test_the_slashes_hit_a_wide_arc_at_short_reach() -> void:
	# +-60 degrees, 1.6 m beyond the edge: a dummy (r 0.35) is touched out to 0.35 + 1.6 + 0.35 = 2.3 m.
	for step in [0, 1]:
		assert_true(_hits(step, _at(50, 1.5)), "step %d: inside the arc" % step)
		assert_true(_hits(step, _at(-50, 1.5)), "step %d: the other side" % step)
		assert_false(_hits(step, _at(75, 1.5)), "step %d: outside the arc" % step)
		assert_true(_hits(step, _at(0, 2.25)), "step %d: at the reach" % step)
		assert_false(_hits(step, _at(0, 2.45)), "step %d: beyond the reach" % step)
		assert_false(_hits(step, _at(180, 1.2)), "step %d: behind" % step)


func test_the_thrust_is_narrow_and_long() -> void:
	# +-20 degrees, 2.3 m: touched out to 3.0 m along the aim, but not where a slash would hit at 35 degrees.
	assert_true(_hits(2, _at(0, 2.95)), "at the thrust's reach")
	assert_false(_hits(2, _at(0, 3.1)), "beyond it")
	assert_true(_hits(2, _at(15, 2.0)), "inside the narrow arc")
	assert_false(_hits(2, _at(35, 1.5)), "outside it, where a slash hits")
	assert_true(_hits(0, _at(35, 1.5)), "(a slash does)")
	assert_false(_hits(0, _at(0, 2.95)), "(and a slash doesn't reach this far)")


func test_the_finisher_hits_all_around() -> void:
	# 360 degrees, 1.9 m: touched out to 2.6 m in every direction.
	for deg in [0.0, 90.0, 180.0, -135.0]:
		assert_true(_hits(3, _at(deg, 2.5)), "at %s degrees" % deg)
	assert_false(_hits(3, _at(180, 2.7)), "beyond the reach")


func test_steps_damages_and_sequence() -> void:
	var w := _world()
	w.add_dummy(Vector2(1.2, 0), 0.35, 999)
	var steps := []
	for i in 6:
		w.step(_f(0, P))
		steps.append(w.combo_step)
		while w.swing_t > 0:
			w.step(_f())
	assert_eq(steps, [0, 1, 2, 3, 0, 1], "four steps, then the combo starts over")
	assert_eq(_amounts(_damage(w)), [10, 10, 12, 24, 10, 10])


func test_after_the_finisher_no_window_opens() -> void:
	var w := _world()
	_chain(w, 4)
	assert_eq(w.combo_window, 0, "the finisher ends the combo")
	w.step(_f(0, P))
	assert_eq(w.combo_step, 0)


func test_a_lapsed_window_restarts_the_combo() -> void:
	var w := _world()
	_chain(w, 2)
	assert_eq(w.combo_window, w.player.combo_window_ticks)
	# The window counts from the tick the swing ends: a press on that tick or the next 11 chains.
	for i in w.player.combo_window_ticks - 2:
		w.step(_f())
	w.step(_f(0, P))
	assert_eq(w.combo_step, 2, "a press on the window's last tick chains")
	var v := _world()
	_chain(v, 2)
	for i in v.player.combo_window_ticks - 1:
		v.step(_f())
	v.step(_f(0, P))
	assert_eq(v.combo_step, 0, "one tick later it starts over")


func test_a_press_during_a_swing_buffers_the_next_step() -> void:
	var w := _world()
	w.step(_f(0, P))
	for i in w.player.step(0).ticks - 3:
		w.step(_f())
	w.step(_f(0, P))  # buffered: the swing has 3 ticks left
	while w.combo_step == 0:
		w.step(_f())
	assert_eq(w.combo_step, 1)
	assert_eq(w.swing_t, 1, "the next step starts the tick the last one ends")


func test_each_step_lasts_its_ticks_and_hits_on_its_active_tick() -> void:
	for step in 4:
		var w := _world()
		_chain(w, step)
		var s := w.player.step(step)
		var at := w.player_pos() + Vector2(s.lunge_m, 0)
		w.add_dummy(at + Vector2(1.2, 0), 0.35, 999)
		w.step(_f(0, P))
		var swing_ticks := 1
		var frozen := 0
		var hit_at := -1
		var after := w.last_event_seq()
		while w.swing_t > 0:
			var before := w.swing_t
			w.step(_f())
			if w.swing_t == before:
				frozen += 1
			else:
				swing_ticks += 1
			if hit_at < 0 and not _damage(w, after).is_empty():
				hit_at = before
		assert_eq(swing_ticks - 1, s.ticks, "step %d lasts its ticks" % step)
		assert_eq(hit_at, s.active_tick, "step %d hits on its active tick" % step)
		assert_eq(frozen, s.hitstop_ticks, "step %d: its own hit-stop" % step)


func test_the_finisher_has_the_biggest_hit_stop_and_the_longest_recovery() -> void:
	var t := PlayerTable.starting_values()
	var fin := t.step(3)
	for k in 3:
		assert_gt(fin.hitstop_ticks, t.step(k).hitstop_ticks, "hit-stop over step %d" % k)
		assert_gt(fin.recovery_ticks(), t.step(k).recovery_ticks(), "recovery over step %d" % k)
		assert_gt(fin.damage, t.step(k).damage, "damage over step %d" % k)
	assert_eq(fin.hitstop_ticks, 7)
	assert_eq(fin.recovery_ticks(), 24)


func test_the_thrust_steps_and_the_finisher_lunges_forward() -> void:
	var w := _world()
	var moved := []
	for step in 4:
		var from := w.player_pos()
		_swing(w, 1024)  # aim +y
		moved.append(w.player_pos() - from)
	for k in 4:
		var s := w.player.step(k)
		assert_almost_eq(moved[k].x, 0.0, 1e-4, "step %d stays on the aim" % k)
		assert_almost_eq(moved[k].y, s.lunge_m, 1e-4, "step %d moves its lunge along the aim" % k)
	assert_eq(moved[0], Vector2.ZERO, "the slashes don't step")
	assert_gt(moved[3].y, moved[2].y, "the finisher lunges farther than the thrust steps")


func test_the_lunge_lands_before_the_hit() -> void:
	# Out of the thrust's reach from where it starts, inside it after the 0.35 m step.
	var w := _world()
	_chain(w, 2)
	w.add_dummy(w.player_pos() + Vector2(3.2, 0), 0.35, 500)
	var after := w.last_event_seq()
	_swing(w)
	assert_eq(_amounts(_damage(w, after)), [12])


# --- Data -----------------------------------------------------------------------------------------------------
func _def() -> PlayerDefinition:
	var d: PlayerDefinition = (
		(ContentRepository.load_all().get_def(&"player", &"runner") as PlayerDefinition)
		. duplicate(true)
	)
	return d


func _codes(d: PlayerDefinition) -> Array:
	return d.validate().map(func(i: ValidationIssue) -> StringName: return i.code)


func test_the_shipped_combo_validates() -> void:
	assert_eq(_codes(_def()), [])
	assert_eq(_def().primary.combo.size(), 4)


func test_bad_steps_are_reported() -> void:
	var cases := [
		["arc_degrees", 0.0, &"range"],
		["arc_degrees", 400.0, &"range"],
		["reach_m", 0.0, &"not_positive"],
		["damage", 0, &"not_positive"],
		["active_seconds", 0.0, &"not_positive"],
		["active_seconds", 0.004, &"duration_zero_ticks"],
		["recovery_seconds", -0.1, &"duration_negative"],
		["hitstop_seconds", 0.004, &"duration_zero_ticks"],
		["lunge_m", -0.1, &"range"],
		["lunge_m", 3.0, &"range"],
	]
	for c: Array in cases:
		var d := _def()
		d.primary.combo[1].set(c[0], c[1])
		assert_has(_codes(d), c[2], "%s = %s" % [c[0], c[1]])


func test_a_lunge_needs_a_tick_before_the_hit() -> void:
	var d := _def()
	d.primary.combo[0].lunge_m = 0.3
	assert_does_not_have(_codes(d), &"order", "step 1 hits on tick 2: one tick to lunge in")
	var e := _def()
	e.primary.combo[0].active_seconds = 1.0 / 60.0
	e.primary.combo[0].lunge_m = 0.3
	assert_has(_codes(e), &"order")


func test_an_empty_or_huge_combo_is_reported() -> void:
	var d := _def()
	d.primary.combo.clear()
	assert_has(_codes(d), &"missing")
	var e := _def()
	for i in PlayerDefinition.MAX_COMBO_STEPS:
		e.primary.combo.append(e.primary.combo[0])
	assert_has(_codes(e), &"range")


# --- Items ----------------------------------------------------------------------------------------------------
func test_long_edge_scales_every_steps_reach() -> void:
	var w := _world([K.LONG_EDGE])
	var r := WorldReader.new(w)
	for k in 4:
		assert_almost_eq(r.swing_reach_m(k), w.player.step(k).reach_m * 1.35, 1e-5, "step %d" % k)
		assert_eq(r.swing_shape(k)[1], r.swing_reach_m(k), "the drawn blade is the hit reach")
		assert_eq(r.swing_shape(k)[0], w.player.step(k).half_arc, "and the hit arc")
	# The thrust with Long Edge reaches 0.35 + 2.3 x 1.35 + 0.35 = 3.805 m.
	_chain(w, 2)
	w.add_dummy(w.player_pos() + Vector2(0.35 + 3.7, 0), 0.35, 500)
	var after := w.last_event_seq()
	_swing(w)
	assert_eq(_amounts(_damage(w, after)), [12])


func test_twin_arc_echoes_each_steps_own_shape() -> void:
	# A dummy behind: the slashes and the thrust (and their echoes) miss it; the spin and its echo both hit.
	var w := _world([K.TWIN_ARC])
	w.add_dummy(Vector2(-1.2, 0), 0.35, 999)
	var r := WorldReader.new(w)
	var steps := []
	for i in 4:
		_swing(w)
		while r.echo_pending():
			w.step(_f())
		steps.append(r.echo_step())
	assert_eq(steps, [0, 1, 2, 3], "each echo keeps its step")
	var d := _damage(w)
	assert_eq(_amounts(d), [24, 12], "only the spin and its echo reach behind")
	assert_eq(d[1].effect_id, &"twin_arc")


func test_momentum_empowers_any_step() -> void:
	# Chain three slashes, dash out, and the finisher started within the window deals 24 x 1.6.
	var w := _world([K.MOMENTUM])
	_chain(w, 3)
	w.step(_f(0, InputFrame.DASH, 2048))
	while w.is_dashing():
		w.step(_f(0, 0, 2048))
	w.add_dummy(w.player_pos() + Vector2(1.2, 0), 0.35, 999)
	var after := w.last_event_seq()
	w.step(_f(0, P))
	assert_eq(w.combo_step, 3, "the window outlasted the dash")
	assert_true(w.swing_momentum)
	while w.swing_t > 0:
		w.step(_f())
	assert_eq(_amounts(_damage(w, after)), [38], "24 x 1.6, rounded down")
