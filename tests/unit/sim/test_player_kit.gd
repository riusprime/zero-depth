extends GutTest
## The primary (PLAN v0.1.0 Step 2): swing arc and combo, charge and bolt. Aim angle 0 = +x.

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
	var w := _world()
	var t := w.player
	for i in 3:
		w.step(_f(0, P))
		_idle(w, t.swing_ticks + 2)
	assert_eq(_damage_amounts(w), t.swing_damage, "10, 10, 18 when chained")
	_idle(w, t.combo_window_ticks + 5)
	w.step(_f(0, P))
	_idle(w, 20)
	assert_eq(
		_damage_amounts(w).back(), t.swing_damage[0], "the window ran out: back to the first swing"
	)


func test_a_full_charge_fires_a_full_bolt() -> void:
	var w := _world(Vector2(6, 0))
	w.step(_f(P, P))
	for i in 70:
		w.step(_f(P))
	assert_eq(PlayerKit.charge_permille(w), 1000)
	w.step(_f())  # release
	_idle(w, 2)
	assert_eq(w.projectiles.size(), 1)
	assert_eq(w.projectiles.damage[0], w.player.bolt_max_damage)
	assert_ne(w.projectiles.tags[0] & SimEvent.TAG_FULL_CHARGE, 0)
	var freeze_seen := 0
	for i in 40:
		w.step(_f())
		freeze_seen = maxi(freeze_seen, w.freeze_ticks)
	assert_has(_damage_amounts(w), w.player.bolt_max_damage)
	assert_eq(freeze_seen, w.player.bolt_full_hitstop_ticks, "hit-stop on a full bolt")


func test_a_partial_charge_scales_and_a_short_hold_fires_nothing() -> void:
	var w := _world(Vector2.INF)
	var t := w.player
	w.step(_f(P, P))
	for i in t.charge_start_ticks - 2:
		w.step(_f(P))
	w.step(_f())
	_idle(w, 2)
	assert_eq(w.projectiles.size(), 0, "released before charging: only the swing")
	_idle(w, 30)
	w.step(_f(P, P))
	var hold := t.charge_start_ticks + (t.charge_full_ticks - t.charge_start_ticks) / 2
	for i in hold - 1:
		w.step(_f(P))
	w.step(_f())
	_idle(w, 2)
	assert_eq(w.projectiles.size(), 1)
	assert_between(w.projectiles.damage[0], t.bolt_min_damage + 1, t.bolt_max_damage - 1)


func test_charging_slows_movement() -> void:
	var a := _world(Vector2.INF)
	var b := _world(Vector2.INF)
	var move := Vector2i(127, 0)
	a.step(_f(P, P, move))
	b.step(_f(0, 0, move))
	for i in 40:
		a.step(_f(P, 0, move))
		b.step(_f(0, 0, move))
	assert_lt(a.player_pos().x, b.player_pos().x * 0.85)
