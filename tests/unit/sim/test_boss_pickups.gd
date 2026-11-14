extends GutTest
## The floor pickups a boss places (BossPickups): taken when the hero's circle touches one, the effect once, oldest
## first; expiry; the cap; gone with the boss, the hero's death and outside the arena; their events; the snapshot and
## the seed.

const LONG := 1 << 20
## A hit pauses the world for a few ticks (the hero's hit-stop); the fight's clean-up runs on the first tick after it.
const HIT_STOP := 10
const FAR := Vector2(30, 30)


func _fight(seed_value := 11, player_at := FAR) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"clockwork_judge", Vector2(-30, -30))
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	# TEST HELPER: held staggered, so it never attacks.
	w.actors.state[i] = BossAi.STAGGERED
	w.bosses.stagger_t[BossAi.entry_of(w, i)] = LONG
	return [w, w.actors.ids[i]]


func _step(w: World, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())


func _orb(life := 0, cap := 3) -> BossPickupTable:
	var t := BossPickupTable.new()
	t.amount = 250
	t.radius_m = 0.8
	t.life_ticks = life
	t.max_count = cap
	return t


func _events(w: World, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == kind:
			out.append(e)
	return out


func test_three_orbs_return_the_whole_cut() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	var spots := [Vector2(10, 10), Vector2(-10, 10), Vector2(10, -10)]
	var ids := []
	for c: Vector2 in spots:
		ids.append(BossPickups.place(w, s[1], _orb(), c))
	assert_eq(ids, [0, 1, 2])
	var spawned := _events(w, SimEvent.Kind.BOSS_PICKUP_SPAWN)
	assert_eq(spawned.size(), 3)
	assert_eq(spawned[1].pos, spots[1])
	assert_eq(spawned[1].target_id, 1, "the event names the pickup")
	assert_eq(spawned[1].source_id, s[1], "and its boss")
	assert_eq(WorldReader.new(w).boss_pickups().size(), 3, "the view's read")
	_step(w, 30)
	assert_eq(w.bosses.pk_x.size(), 3, "untouched: they stay")
	assert_eq(BossSlow.cut(w), 750)
	var left := 750
	for k in 3:
		w.actors.set_pos(0, spots[k])
		_step(w, 1)
		left -= 250
		assert_eq(BossSlow.cut(w), left, "orb %d returns 25 points" % k)
		assert_eq(w.bosses.pk_x.size(), 2 - k)
		_step(w, 5)
		assert_eq(BossSlow.cut(w), left, "once: standing there returns no more")
	assert_eq(AttackRate.rate(w, 0), 1000)
	var taken := _events(w, SimEvent.Kind.BOSS_PICKUP_TAKEN)
	assert_eq(taken.size(), 3)
	assert_eq(taken[0].target_id, 0)
	assert_eq(taken[0].owner_id, w.actors.ids[0], "the hero took it")
	assert_eq([taken[0].amount, taken[0].amount_applied], [250, 250])
	assert_eq(_events(w, SimEvent.Kind.BOSS_PICKUP_END).size(), 0)


func test_it_is_taken_on_touch_not_before() -> void:
	var s := _fight()
	var w: World = s[0]
	var reach := 0.8 + w.player.radius_m
	BossPickups.place(w, s[1], _orb(), Vector2.ZERO)
	w.actors.set_pos(0, Vector2(reach + 0.05, 0))
	_step(w, 1)
	assert_eq(w.bosses.pk_x.size(), 1, "a hair outside")
	w.actors.set_pos(0, Vector2(reach - 0.05, 0))
	_step(w, 1)
	assert_eq(w.bosses.pk_x.size(), 0, "the circles touch")


func test_one_taken_with_nothing_to_return_still_goes() -> void:
	var s := _fight(11, Vector2.ZERO)
	var w: World = s[0]
	BossPickups.place(w, s[1], _orb(), Vector2.ZERO)
	_step(w, 1)
	assert_eq(w.bosses.pk_x.size(), 0)
	var taken := _events(w, SimEvent.Kind.BOSS_PICKUP_TAKEN)
	assert_eq([taken[0].amount, taken[0].amount_applied], [250, 0])


func test_two_under_the_hero_are_taken_oldest_first() -> void:
	var s := _fight(11, Vector2.ZERO)
	var w: World = s[0]
	BossSlow.apply(w, s[1], 300)
	BossPickups.place(w, s[1], _orb(), Vector2(0.2, 0))
	BossPickups.place(w, s[1], _orb(), Vector2(-0.2, 0))
	_step(w, 1)
	var taken := _events(w, SimEvent.Kind.BOSS_PICKUP_TAKEN)
	assert_eq(taken.size(), 2)
	assert_eq([taken[0].target_id, taken[1].target_id], [0, 1])
	assert_eq([taken[0].amount_applied, taken[1].amount_applied], [250, 50])
	assert_eq(BossSlow.cut(w), 0)


func test_one_with_a_lifetime_goes_when_its_time_is_up() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	BossPickups.place(w, s[1], _orb(10), Vector2(5, 5))
	assert_eq(WorldReader.new(w).boss_pickups()[0]["left"], 10)
	_step(w, 10)
	assert_eq(w.bosses.pk_x.size(), 1, "it lies there for its ten ticks")
	_step(w, 1)
	assert_eq(w.bosses.pk_x.size(), 0, "and goes on the next")
	var ended := _events(w, SimEvent.Kind.BOSS_PICKUP_END)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].amount, BossPickups.END_EXPIRED)
	assert_eq(BossSlow.cut(w), 750, "nothing came back")


func test_the_cap_removes_the_oldest() -> void:
	var s := _fight()
	var w: World = s[0]
	for k in 5:
		BossPickups.place(w, s[1], _orb(0, 3), Vector2(k, 0))
	assert_eq(BossPickups.count_of(w, s[1]), 3)
	assert_eq(Array(w.bosses.pk_id), [2, 3, 4], "the two oldest went")
	var ended := _events(w, SimEvent.Kind.BOSS_PICKUP_END)
	assert_eq(ended.size(), 2)
	assert_eq([ended[0].target_id, ended[0].amount], [0, BossPickups.END_CAP])


func test_they_go_with_their_boss() -> void:
	var s := _fight()
	var w: World = s[0]
	BossPickups.place(w, s[1], _orb(), Vector2(5, 5))
	BossPickups.place(w, s[1], _orb(), Vector2(6, 5))
	BossSignatures.on_boss_gone(w, 999999)
	assert_eq(w.bosses.pk_x.size(), 2, "another boss's leaving leaves them")
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(w.bosses.pk_x.size(), 0)
	var ended := _events(w, SimEvent.Kind.BOSS_PICKUP_END)
	assert_eq(ended.size(), 2)
	assert_eq(ended[0].amount, BossPickups.END_CLEARED)


func test_they_go_when_the_hero_dies_or_leaves_the_arena() -> void:
	var s := _fight()
	var w: World = s[0]
	w.bosses.arena = Rect2(-40, -40, 80, 80)
	BossPickups.place(w, s[1], _orb(), Vector2(5, 5))
	_step(w, 3)
	assert_eq(w.bosses.pk_x.size(), 1)
	w.actors.set_pos(0, Vector2(60, 0))
	_step(w, 1)
	assert_eq(w.bosses.pk_x.size(), 0, "outside the arena")
	w.actors.set_pos(0, FAR)
	BossPickups.place(w, s[1], _orb(), Vector2(5, 5))
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, LONG * 4, s[1], s[1], w.take_root(), 0, FAR, FAR)
	_step(w, HIT_STOP + 1)
	assert_true(w.player_dead())
	assert_eq(w.bosses.pk_x.size(), 0, "the hero dead")


func test_a_snapshot_keeps_them() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	BossPickups.place(w, s[1], _orb(), Vector2(5, 5))
	BossPickups.place(w, s[1], _orb(300), Vector2(-5, 5))
	_step(w, 20)
	var hash_a := w.state_hash()
	var back := World.from_snapshot(
		bytes_to_var(var_to_bytes(WorldSnapshot.take(w))), BossLab.world(11)
	)
	assert_not_null(back, "restores")
	if back == null:
		return
	assert_eq(back.state_hash(), hash_a, "the restored world hashes the same")
	assert_eq(back.bosses.pk_x, w.bosses.pk_x)
	for x: World in [w, back]:
		x.actors.set_pos(0, Vector2(5, 5))
		_step(x, 120)
	assert_eq(BossSlow.cut(back), 500)
	assert_eq(back.state_hash(), w.state_hash(), "and runs on the same")


func test_a_pickup_is_hashed() -> void:
	var s := _fight()
	var w: World = s[0]
	var clean := w.state_hash()
	BossPickups.place(w, s[1], _orb(), Vector2(5, 5))
	var one := w.state_hash()
	assert_ne(one, clean, "a pickup is state")
	w.bosses.pk_x[0] = 6.0
	assert_ne(w.state_hash(), one, "and so is where it lies")


func test_same_seed_same_hash() -> void:
	var run := func(seed_value: int) -> Array:
		var s := _fight(seed_value)
		var w: World = s[0]
		BossSlow.apply(w, s[1], 750)
		for c: Vector2 in [Vector2(28, 30), Vector2(26, 30), Vector2(24, 30)]:
			BossPickups.place(w, s[1], _orb(200), c)
		var f := InputFrame.new()
		f.move = Vector2i(-SimTick.MOVE_MAX, 0)
		for k in 150:
			w.step(f)
		return [w.state_hash(), BossSlow.cut(w), w.bosses.pk_x.size()]
	var a: Array = run.call(21)
	assert_eq(a, run.call(21), "the same seed and inputs, the same hash")
	assert_lt(a[1], 750, "the walk took at least one")
