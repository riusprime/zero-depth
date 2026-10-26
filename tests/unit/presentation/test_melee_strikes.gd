extends GutTest
## v0.8.0 P1 (owner O25, O26, playtest 2): the Warden's red slam circle is drawn on the ground again and its model
## does a full overhead slam with a dust ring at the impact; every melee enemy raises its strike pose by
## AvatarBase.STRIKE_RAISE_BY of the windup's progress and holds it to the hit tick, then strikes with a clear snap.
## The pose follows the sim's state and progress only: a windup held at full progress never strikes on its own.

const DT := 1.0 / 60.0
const WINDUP_TICKS := 48


## [name, avatar, raise getter, strike getter] for each melee model.
func _melee() -> Array:
	var out := []
	var charger := ChargerAvatar.new()
	charger.setup(Color.BLACK)
	out.append(["charger", charger, charger.windup_amount, charger.strike_swing])
	var hatch := ChargerAvatar.new()
	hatch.setup(Color.BLACK, &"outline", WorldReader.KIND_HATCHLING)
	out.append(["hatchling", hatch, hatch.windup_amount, hatch.strike_swing])
	for kind: int in HordeAvatar.STRIKE_KINDS:
		var h := HordeAvatar.new()
		h.setup(kind, Color.BLACK)
		out.append(["horde %d" % kind, h, h.windup_pose, h.strike_pose])
	var warden := WardenAvatar.new()
	warden.setup(Color.BLACK)
	out.append(["warden", warden, warden.raise_amount, warden.slam_amount])
	for spec: Array in out:
		add_child_autofree(spec[1])
		(spec[1] as Node).set_process(false)
	return out


## One sim tick in `state` at windup progress p, then one frame.
func _tick(a: AvatarBase, t: int, state: int, p: float) -> void:
	a.call(&"apply_state", {"tick": t, "pos": Vector2.ZERO, "state": state, "windup": p})
	a.advance(DT)


func test_every_melee_strike_pose_is_raised_early_and_held_to_the_hit() -> void:
	for spec: Array in _melee():
		var a: AvatarBase = spec[1]
		var raise: Callable = spec[2]
		var t := 0
		for k in 20:
			t += 1
			_tick(a, t, WorldReader.STATE_MOVE, 0.0)
		var last := -1.0
		for k in WINDUP_TICKS:
			t += 1
			var p := float(k + 1) / WINDUP_TICKS
			_tick(a, t, WorldReader.STATE_WINDUP, p)
			var r: float = raise.call()
			assert_gte(r, last - 0.0001, "%s: the raise never sags during the windup" % spec[0])
			last = r
			if p >= AvatarBase.STRIKE_RAISE_BY:
				assert_almost_eq(
					r, 1.0, 0.001, "%s: fully raised and held at progress %.2f" % [spec[0], p]
				)
		var strike: Callable = spec[3]
		assert_almost_eq(
			float(strike.call()), 0.0, 0.001, "%s: no strike before the hit tick" % spec[0]
		)


func test_every_melee_strike_snaps_out_at_the_hit_tick_and_comes_back() -> void:
	for spec: Array in _melee():
		var a: AvatarBase = spec[1]
		var raise: Callable = spec[2]
		var strike: Callable = spec[3]
		var t := 0
		for k in WINDUP_TICKS:
			t += 1
			_tick(a, t, WorldReader.STATE_WINDUP, float(k + 1) / WINDUP_TICKS)
		t += 1
		_tick(a, t, WorldReader.STATE_ACTIVE, 0.0)
		var first: float = strike.call()
		assert_lt(first, 0.5, "%s: the strike starts at the hit tick, not before" % spec[0])
		var frames := 1
		while float(strike.call()) < 0.99 and frames < 30:
			t += 1
			_tick(a, t, WorldReader.STATE_RECOVER, 0.0)
			frames += 1
		assert_lte(frames, 6, "%s: out within ~0.1 s (%d frames)" % [spec[0], frames])
		assert_lt(float(raise.call()), 0.05, "%s: the raised pose is spent in the strike" % spec[0])
		for k in 90:
			t += 1
			_tick(a, t, WorldReader.STATE_MOVE, 0.0)
		assert_lt(float(strike.call()), 0.05, "%s: back to rest after the attack" % spec[0])


func test_a_windup_held_at_full_progress_never_strikes_by_itself() -> void:
	# No timer decides the strike: only the sim's ACTIVE state starts it.
	for spec: Array in _melee():
		var a: AvatarBase = spec[1]
		var strike: Callable = spec[3]
		for k in 240:
			_tick(a, k + 1, WorldReader.STATE_WINDUP, 1.0)
		assert_almost_eq(float(strike.call()), 0.0, 0.001, "%s: still holding" % spec[0])
		assert_almost_eq(
			float((spec[2] as Callable).call()), 1.0, 0.001, "%s: still raised" % spec[0]
		)


func test_the_warden_slams_overhead_and_kicks_up_a_dust_ring_the_size_of_its_circle() -> void:
	var a := WardenAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	var t := 0
	for k in 20:
		t += 1
		_tick(a, t, WorldReader.STATE_MOVE, 0.0)
	var hang := a.fist_height()
	for k in WINDUP_TICKS:
		t += 1
		(
			a
			. apply_state(
				{
					"tick": t,
					"pos": Vector2.ZERO,
					"state": WorldReader.STATE_WINDUP,
					"windup": float(k + 1) / WINDUP_TICKS,
					"radius": 2.4,
				}
			)
		)
		a.advance(DT)
		if k >= WINDUP_TICKS / 2:
			assert_gt(a.fist_height(), 1.0, "fists held overhead through the windup")
	assert_lt(a.dust_amount(), 0.0, "no dust before the slam")
	assert_false(a.dust.visible)
	t += 1
	_tick(a, t, WorldReader.STATE_ACTIVE, 0.0)
	var lowest := INF
	var widest := 0.0
	var seen := false
	for k in 40:
		t += 1
		_tick(a, t, WorldReader.STATE_RECOVER, 0.0)
		lowest = minf(lowest, a.fist_height())
		if a.dust.visible:
			seen = true
			widest = maxf(widest, a.dust.scale.x)
	assert_lt(lowest, hang * 0.6, "the fists come down to the ground, below where they hang")
	assert_true(seen, "a dust ring at the impact")
	assert_almost_eq(a.slam_radius(), 2.4, 0.001, "the telegraph's radius")
	assert_gt(widest, 2.4 * 0.85, "it runs out to the slam's circle")
	assert_lte(widest, 2.4 + 0.001, "and no further")
	for k in 60:
		t += 1
		_tick(a, t, WorldReader.STATE_MOVE, 0.0)
	assert_false(a.dust.visible, "the dust settles")


func test_the_wardens_red_circle_is_drawn_on_the_ground_again() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	var id := w.add_enemy(ActorStore.Kind.WARDEN, Vector2(1.5, 0))
	var reader := WorldReader.new(w)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	var drawn := 0
	for k in 600:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		tv.sync(reader)
		var i := w.actors.index_of(id)
		if w.actors.state[i] == EnemyAi.State.WINDUP:
			var tg := reader.telegraph(i)
			assert_eq(tg["shape"], &"disc")
			assert_true(tg["ground"], "on the ground")
			drawn = maxi(drawn, tv.count())
	assert_eq(drawn, 1, "the slam's red circle is drawn while it winds up")
