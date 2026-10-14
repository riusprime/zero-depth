extends GutTest
## v0.8.0 FB1 (owner O17; FINAL_BOSS.md F4): the Colossus, the final boss's first body, in the sim. Fast melee with
## short fair locks (0.5 s): fist combos that follow you then slam, tracked leaps that land in a shockwave ring, stone
## spikes that chase you and burst round it, boulders lobbed onto tracked circles that shatter into shards. Every strike
## shows locked for its lock before it lands; no shard spawns on you; the fight is deterministic.

const LONG := 1 << 24


func _arena(seed_value: int = 101) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	FinalLab.past_rise(w)
	w.actors.max_hp[0] = 100000
	w.actors.hp[0] = 100000
	w.actors.invuln[0] = 0
	return w


func _colossus(w: World) -> int:
	return FinalLab.body(w)


func _start(w: World, attack_id: StringName) -> BossAttackTable:
	var i := _colossus(w)
	var t := BossAi.table_of(w, i)
	var k := t.attack_index(attack_id)
	assert_gte(k, 0, "the Colossus has %s" % attack_id)
	BossAi.start_attack(w, i, k)
	w.bosses.chained[BossAi.entry_of(w, i)] = 1
	return t.attacks[k]


func _hp(w: World) -> int:
	return w.actors.hp[0]


## Steps with the player held at `at` (moved there before each tick, still).
func _hold(w: World, at: Vector2, n: int) -> void:
	for k in n:
		w.actors.set_pos(0, at)
		w.vel = Vector2.ZERO
		w.step(InputFrame.new())


func test_every_move_locks_half_a_second_before_it_lands() -> void:
	var w := _arena(102)
	var t := BossAi.table_of(w, _colossus(w))
	assert_eq(t.kind, ActorStore.Kind.COLOSSUS)
	for atk in t.attacks:
		assert_eq(atk.lock_ticks, 30, "%s locks for 0.5 s (F4)" % atk.id)
		assert_gt(atk.windup_ticks, atk.lock_ticks, "%s tracks before it locks" % atk.id)
	assert_gt(t.speed * SimTick.TICKS_PER_SECOND, 4.0, "it moves fast between attacks")
	assert_eq(t.front_mult_permille, 1000, "no shield")
	for atk in t.attacks:
		assert_false(atk.shielded, "no shielded attack (F4: no shield phases)")


func test_the_combo_follows_you_then_locks() -> void:
	var w := _arena(103)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2.ZERO)
	_hold(w, Vector2(5, 0), 1)
	var atk := _start(w, &"fist_combo")
	var reader := WorldReader.new(w)
	var aims := []
	var first_strike := BossColossus.strike_tick(atk, 0)
	var lock_at := first_strike - atk.lock_ticks
	for k in lock_at - 2:
		var at := Vector2(5, 0).rotated(0.4 * sin(k * 0.2))
		_hold(w, at, 1)
		aims.append(w.actors.lock_a[i])
	var distinct := {}
	for a: int in aims:
		distinct[a] = true
	assert_gt(distinct.size(), 3, "the swing's aim follows the player while it tracks")
	_hold(w, Vector2(5, 0), 3)
	var tg := reader.telegraph(i)
	assert_eq(tg["shape"], &"arc")
	assert_true(tg["locked"], "locked for its last half second")
	var locked_a := w.actors.lock_a[i]
	_hold(w, Vector2(0, 5), 10)
	assert_eq(w.actors.lock_a[i], locked_a, "a locked swing no longer follows")


func test_each_combo_strike_lands_on_its_tick_and_the_slam_closes_it() -> void:
	var w := _arena(104)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2.ZERO)
	_hold(w, Vector2(3.0, 0), 1)
	var atk := _start(w, &"fist_combo_3")
	var reader := WorldReader.new(w)
	var strikes := {}
	var shapes := {}
	var locked_for := {}
	var last_t := -1
	for k in 600:
		_hold(w, Vector2(3.0, 0), 1)
		if w.actors.state[i] != EnemyAi.State.WINDUP and w.actors.state[i] != EnemyAi.State.ACTIVE:
			break
		var t := BossDodge.attack_ticks(w, i, atk)
		if t == last_t:
			continue  # a hit-stop held the clock
		last_t = t
		var tg := reader.telegraph(i)
		var s := int(tg["strike"])
		if tg["locked"]:
			locked_for[s] = int(locked_for.get(s, 0)) + 1
		if tg.get("striking", false):
			strikes[s] = t
			shapes[s] = tg["shape"]
	assert_eq(strikes.size(), 4, "three swings and the slam")
	assert_eq(
		[shapes[0], shapes[1], shapes[2], shapes[3]],
		[&"arc", &"arc", &"arc", &"disc"],
		"swings, then the slam's circle"
	)
	for k in 3:
		assert_eq(
			strikes[k + 1] - strikes[k],
			atk.mark_gap_ticks,
			"the strikes stand stagger_seconds apart"
		)
	for s: int in locked_for:
		assert_gte(locked_for[s], atk.lock_ticks, "strike %d showed locked for its whole lock" % s)


func test_a_combo_hits_who_stays_and_misses_who_steps_out() -> void:
	var w := _arena(105)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2.ZERO)
	_hold(w, Vector2(3.0, 0), 1)
	var atk := _start(w, &"fist_combo")
	var hp0 := _hp(w)
	_hold(w, Vector2(3.0, 0), atk.windup_ticks + 1)
	assert_lt(_hp(w), hp0, "standing in the locked swing is a hit")
	var w2 := _arena(105)
	var i2 := _colossus(w2)
	w2.actors.set_pos(i2, Vector2.ZERO)
	_hold(w2, Vector2(3.0, 0), 1)
	var atk2 := _start(w2, &"fist_combo")
	_hold(w2, Vector2(3.0, 0), atk2.windup_ticks - atk2.lock_ticks + 2)
	var hp1 := _hp(w2)
	_hold(w2, Vector2(-9.0, 0), atk2.lock_ticks + 2)  # out of the locked arc, behind it
	assert_eq(_hp(w2), hp1, "stepping out after the lock dodges it")


func test_the_spikes_chase_the_player() -> void:
	var w := _arena(106)
	var i := _colossus(w)
	var b := BossAi.entry_of(w, i)
	w.actors.set_pos(i, Vector2(-8, 0))
	w.actors.facing[i] = 0
	_hold(w, Vector2(6, 0), 1)
	var atk := _start(w, &"spike_chase")
	var reader := WorldReader.new(w)
	var seen := {}
	var last := Vector2(-8, 0)
	for k in atk.windup_ticks + atk.active_ticks:
		var target := Vector2(6, 6.0 * sin(k * 0.05))
		_hold(w, target, 1)
		var tg := reader.telegraph(i)
		if tg.get("shape", &"") != &"marks":
			continue
		for item: Dictionary in tg["items"]:
			var c: Vector2 = item["center"]
			var key := str(c)
			if not seen.has(key):
				seen[key] = int(item["progress"])
				assert_lte(
					Kin.length(c - last),
					atk.step_m + w.actors.radius[i] + 0.01,
					"a step on from the last"
				)
				last = c
			assert_true(item["locked"], "every spike shows locked until it erupts")
	assert_gte(seen.size(), 6, "a line of spikes was laid")
	for key in seen:
		assert_eq(seen[key], 0, "each spike shows from the start of its lock")
	assert_lt(Kin.length(last - Vector2(6, 0)), 7.0, "the line ended near the player")
	assert_true(BossColossus.chase_stop(w, b, 0) >= 0)


func test_standing_still_in_the_chase_is_a_hit() -> void:
	var w := _arena(107)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2(-6, 0))
	_hold(w, Vector2(2, 0), 1)
	var atk := _start(w, &"spike_chase")
	var hp0 := _hp(w)
	_hold(w, Vector2(2, 0), atk.windup_ticks + atk.active_ticks)
	assert_lt(_hp(w), hp0, "the spikes reach a player who stands still")


func test_a_chase_line_stops_at_the_wall() -> void:
	var w := _arena(108)
	var i := _colossus(w)
	var b := BossAi.entry_of(w, i)
	var r := FinalArena.radius_of(w.floor_layout)
	w.actors.set_pos(i, Vector2(r - 5.0, 0))
	_hold(w, Vector2(r - 1.0, 0), 1)
	var atk := _start(w, &"spike_chase")
	for k in atk.windup_ticks + atk.active_ticks:
		_hold(w, Vector2(r + 6.0, 0), 1)  # held past the ring: the line runs into the wall
		w.actors.set_pos(0, Vector2(r - 1.0, 0))
	assert_lt(BossColossus.chase_stop(w, b, 0), atk.steps, "the line stopped short at the wall")


func test_the_burst_rays_open_toward_the_player() -> void:
	var w := _arena(109)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2.ZERO)
	_hold(w, Vector2(4.5, 0), 1)
	var atk := _start(w, &"spike_burst")
	var hp0 := _hp(w)
	var reader := WorldReader.new(w)
	var rings := 0
	for k in atk.windup_ticks + atk.active_ticks:
		_hold(w, Vector2(4.5, 0), 1)
		var tg := reader.telegraph(i)
		if tg.get("shape", &"") == &"marks" and int(tg["progress"]) == 1000:
			rings += 1
	assert_eq(rings, atk.steps, "every ring erupted")
	assert_eq(_hp(w), hp0, "the player on the aim stands between two rays")
	var w2 := _arena(109)
	var i2 := _colossus(w2)
	w2.actors.set_pos(i2, Vector2.ZERO)
	_hold(w2, Vector2(4.5, 0), 1)
	var atk2 := _start(w2, &"spike_burst")
	var on_ray := Kin.dir(BossColossus.burst_angle(atk2, w2.actors.lock_a[i2], 0)) * 4.5
	var hp1 := _hp(w2)
	_hold(w2, on_ray, atk2.windup_ticks + atk2.active_ticks)
	assert_lt(_hp(w2), hp1, "standing on a ray is a hit")


func test_boulders_land_on_tracked_circles_and_shatter_into_shards() -> void:
	var w := _arena(110)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2(-7, 0))
	_hold(w, Vector2(3, 0), 1)
	var atk := _start(w, &"boulder_throw")
	var reader := WorldReader.new(w)
	var lobs := 0
	var shots_near := 0
	var shots := 0
	var seen := {}
	var lock_at := atk.windup_ticks - atk.lock_ticks
	for k in atk.windup_ticks + atk.active_ticks + 60:
		var me := Vector2(3, 0) if k < lock_at + 2 else Vector2(3, 5)  # out of the locked circles
		_hold(w, me, 1)
		var tg := reader.telegraph(i)
		for item: Dictionary in tg.get("items", []):
			if item.has("lob"):
				lobs += 1
		for j in w.projectiles.size():
			if w.projectiles.team[j] == ActorStore.TEAM_PLAYER or seen.has(w.projectiles.ids[j]):
				continue
			seen[w.projectiles.ids[j]] = true
			shots += 1
			var p := Vector2(w.projectiles.pos_x[j], w.projectiles.pos_y[j])
			if Kin.length(p - me) < atk.pattern.safe_radius_m + w.player.radius_m - 0.3:
				shots_near += 1
	assert_gt(lobs, 0, "a boulder flies onto each locked circle")
	assert_gt(shots, 0, "it shatters into shards")
	assert_eq(shots_near, 0, "no shard spawns on the player")


func test_the_leap_lands_in_a_shockwave_ring() -> void:
	var w := _arena(111)
	var i := _colossus(w)
	w.actors.set_pos(i, Vector2(-6, 0))
	_hold(w, Vector2(4, 0), 1)
	var atk := _start(w, &"leap_slam")
	var landed := false
	var ring := 0
	for k in atk.windup_ticks + atk.active_ticks + 4:
		var before := w.projectiles.size()
		_hold(w, Vector2(4, 0) if k < atk.windup_ticks - atk.lock_ticks else Vector2(4, 4), 1)
		if w.projectiles.size() > before and not landed:
			landed = true
			ring = w.projectiles.size() - before
	assert_true(landed, "a ring of shards flies out where it lands")
	assert_gt(ring, 12, "a ring, its gap toward the player")
	assert_lt(ring, atk.pattern.count, "with a gap")
	assert_lt(
		Kin.length(w.actors.pos(i) - Vector2(4, 0)),
		0.5,
		"it landed where it locked, not where you went"
	)


func test_the_colossus_fight_is_deterministic() -> void:
	var a := _arena(112)
	var b := _arena(112)
	a.actors.invuln[0] = LONG
	b.actors.invuln[0] = LONG
	for k in 1500:
		var f := FinalLab.walk(a, Kin.dir((k * 23) & 4095) * 9.0)
		if k % 9 == 0:
			f.pressed |= InputFrame.PRIMARY
			f.held |= InputFrame.PRIMARY
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same fight")
	assert_eq(a.final_fight.phase, 0, "still the Colossus")
