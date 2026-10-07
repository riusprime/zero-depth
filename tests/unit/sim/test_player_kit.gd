extends GutTest
## Melee and shooting (PLAN v0.1.0 Steps 2, 7b): swing arc and combo; hold-to-shoot. Aim angle 0 = +x.

const P := InputFrame.PRIMARY


func _world(enemy_at: Vector2 = Vector2(1.2, 0), hp: int = 500) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	if enemy_at != Vector2.INF:
		w.add_dummy(enemy_at, 0.35, hp)
	return w


func _f(held: int = 0, pressed: int = 0, move: Vector2i = Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, 0, 300, held, pressed)


func _run(w: World, frames: Array) -> void:
	for f in frames:
		w.step(f)


func _idle(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


func _damage_amounts(w: World) -> Array:
	var out := []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE:
			out.append(e.amount)
	return out


func test_a_tap_shorter_than_a_frame_swings() -> void:
	var w := _world()
	w.step(_f(0, P))  # pressed but not held: press and release inside one frame
	_idle(w, 20)
	assert_eq(_damage_amounts(w), [10])


func test_the_swing_misses_behind_and_beyond_reach() -> void:
	for at in [Vector2(-1.2, 0), Vector2(3.0, 0), Vector2(0.2, 1.6)]:
		var w := _world(at)
		w.step(_f(0, P))
		_idle(w, 20)
		assert_eq(_damage_amounts(w), [], "no hit at %s" % at)


func test_the_combo_chains_then_resets() -> void:
	var w := _world(Vector2(1.2, 0), 999)
	w.dummy_speed = 0.0
	var t := w.player
	for i in t.combo.size():
		w.step(_f(0, P))
		_idle(w, t.step(w.combo_step).ticks + t.step(w.combo_step).hitstop_ticks + 1)
	assert_eq(_damage_amounts(w), [10, 10, 12, 24], "the four slashes when chained")
	_idle(w, 2)
	w.step(_f(0, P))
	assert_eq(w.combo_step, 0, "after the finisher the combo starts over")
	_idle(w, 20)
	w.step(_f(0, P))
	assert_eq(w.combo_step, 1, "chained again")
	_idle(w, 20 + t.combo_window_ticks + 5)
	w.step(_f(0, P))
	_idle(w, 20)
	assert_eq(w.combo_step, 0, "the window ran out: back to the first swing")
	assert_eq(_damage_amounts(w).back(), 10)


func test_holding_shoot_fires_a_steady_stream() -> void:
	var w := _world(Vector2.INF)
	var t := w.player
	for i in t.shot_period_ticks * 5:
		w.step(_f(InputFrame.SHOOT))
	assert_eq(
		w.projectiles.size(), 5, "one bolt every %d ticks, the first at once" % t.shot_period_ticks
	)
	for k in w.projectiles.size():
		assert_eq(w.projectiles.damage[k], t.bolt_damage)
	_idle(w, 60)
	w.step(_f(InputFrame.SHOOT))
	_idle(w, 2)
	assert_eq(w.projectiles.size(), 1, "releasing stops it; pressing again fires at once")


func test_bolts_hit_for_their_damage_and_melee_is_a_separate_button() -> void:
	var w := _world(Vector2(5, 0))
	for i in 3:
		w.step(_f(InputFrame.SHOOT))
	_idle(w, 30)
	assert_eq(
		_damage_amounts(w), [w.player.bolt_damage], "the first bolt landed; shooting never swings"
	)
	assert_eq(w.combo_step, 0)


func test_a_swing_pauses_shooting() -> void:
	var w := _world(Vector2.INF)
	w.step(_f(InputFrame.SHOOT, InputFrame.PRIMARY))
	assert_gt(w.swing_t, 0)
	assert_eq(w.projectiles.size(), 0, "no bolt during the swing")
