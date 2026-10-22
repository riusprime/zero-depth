extends GutTest
## v0.7.5 BF1 (owner N15; BOSS_FIGHTS.md; SIM_CONTRACTS §10d): the bullet pattern engine. Each shape's counts and
## its gap, the turn per wave, determinism, no shot spawning on the player or in a wall, shots stopping at walls,
## the per-tick cap, and each shot's look.

const K := BulletPatternDefinition.Kind


func _def(kind: int) -> BulletPatternDefinition:
	var d := BulletPatternDefinition.new()
	d.id = &"test_pattern"
	d.look = &"ember_stone"
	d.kind = kind
	return d


func _table(d: BulletPatternDefinition) -> BulletPatternTable:
	assert_eq(d.validate(), [], "the test pattern is valid content")
	return PatternCompiler.compile_pattern(d)


## The directions (1/4096 turns) of wave k's shots from the origin.
func _angles(p: BulletPatternTable, k: int, aim: int = 0) -> Array:
	var shots := BulletPatterns.wave_shots(p, k, Vector2.ZERO, aim, 1.0)
	var out := []
	for v in shots[1]:
		out.append(Kin.angle_of(v))
	return out


## The widest angular gap between neighbouring shots, in 1/4096 turns.
func _widest_gap(angles: Array) -> int:
	var a := angles.duplicate()
	a.sort()
	var best := 0
	for j in a.size():
		var nxt: int = a[(j + 1) % a.size()] + (4096 if j == a.size() - 1 else 0)
		best = maxi(best, nxt - int(a[j]))
	return best


func test_a_ring_has_its_count_minus_the_gap_and_the_gap_turns_each_wave() -> void:
	var d := _def(K.RING)
	d.count = 16
	d.gap_count = 1
	d.gap_width = 2
	d.waves = 3
	d.turn_per_wave_degrees = 22.5
	var p := _table(d)
	for k in 3:
		var a := _angles(p, k)
		assert_eq(a.size(), 14, "16 round, 2 left out")
		assert_gte(_widest_gap(a), 3 * 256 - 2, "the gap is three steps wide (two shots left out)")
	var a0 := _angles(p, 0)
	var a1 := _angles(p, 1)
	assert_false(a0.has(0), "wave 0's gap is on the aim")
	assert_false(a0.has(3840), "two shots wide")
	assert_true(a1.has(3840), "wave 1's gap has turned a step")
	assert_false(a1.has(256), "a step round")


func test_a_ring_with_two_gaps_leaves_both_open() -> void:
	var d := _def(K.RING)
	d.count = 24
	d.gap_count = 2
	d.gap_width = 3
	var a := _angles(_table(d), 0)
	assert_eq(a.size(), 18)
	assert_false(a.has(0))
	assert_false(a.has(2048), "the second gap is opposite")


func test_a_fan_spreads_its_count_toward_the_aim_and_alternates() -> void:
	var d := _def(K.FAN)
	d.count = 7
	d.spread_degrees = 60.0
	d.waves = 3
	d.turn_per_wave_degrees = 5.0
	d.alternate = true
	var p := _table(d)
	var a := _angles(p, 0, 1024)
	assert_eq(a.size(), 7)
	a.sort()
	assert_almost_eq(int(a[0]), 1024 - 341, 2, "half the spread one side")
	assert_almost_eq(int(a[6]), 1024 + 341, 2, "and the other")
	assert_eq(_angles(p, 2, 1024), _angles(p, 0, 1024), "every other wave only")
	assert_ne(_angles(p, 1, 1024), _angles(p, 0, 1024), "offset each wave")
	assert_gt(_widest_gap(a), 2048, "the back is open")


func test_a_spiral_turns_then_reverses() -> void:
	var d := _def(K.SPIRAL)
	d.arms = 3
	d.spin_dps = 90.0
	d.waves = 40
	d.wave_gap_seconds = 0.1
	d.reverse_at_seconds = 1.0
	var p := _table(d)
	assert_eq(_angles(p, 0).size(), 3, "one shot an arm")
	assert_eq(BulletPatterns.spin_at(p, 0), 0)
	assert_almost_eq(BulletPatterns.spin_at(p, 60), 1024, 2, "90 degrees in a second")
	assert_almost_eq(BulletPatterns.spin_at(p, 90), 512, 2, "then it turns back")
	assert_gt(_widest_gap(_angles(p, 5)), 1300, "the arms leave gaps between them")


func test_a_cross_is_four_streams_turning_slowly() -> void:
	var d := _def(K.CROSS)
	d.arms = 4
	d.spin_dps = 30.0
	d.waves = 10
	d.wave_gap_seconds = 0.2
	var p := _table(d)
	var a := _angles(p, 0)
	a.sort()
	assert_eq(a, [0, 1024, 2048, 3072], "a plus")
	var later := _angles(p, 5)
	assert_almost_eq(int(later.min()), 341, 3, "turned 30 degrees a second, for a second")


func test_a_wall_marches_with_its_gap_bouncing_inside_it() -> void:
	var d := _def(K.WALL)
	d.wall_length_m = 10.0
	d.spacing_m = 0.5
	d.gap_m = 2.0
	d.gap_shift_m = 3.0
	d.waves = 6
	var p := _table(d)
	for k in 6:
		var shots := BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 1.0)
		var g := BulletPatterns.wall_gap(p, k)
		assert_lte(absf(g), (10.0 - 2.0) * 0.5 + 0.001, "the gap stays inside the wall")
		for j in (shots[0] as PackedVector2Array).size():
			var pos: Vector2 = shots[0][j]
			assert_almost_eq(pos.x, 1.0, 0.001, "a line across the aim")
			assert_gt(absf(pos.y - g), 1.0, "nothing in the gap")
			assert_eq(Kin.angle_of(shots[1][j]), 0, "marching along the aim")
		assert_between((shots[0] as PackedVector2Array).size(), 14, 18)
	d.crossing = true
	var both := BulletPatterns.wave_shots(_table(d), 0, Vector2.ZERO, 0, 1.0)
	var across := 0
	for v: Vector2 in both[1]:
		if Kin.angle_of(v) == 1024:
			across += 1
	assert_gt(across, 10, "crossing: a second wall at right angles")


func test_a_flower_leaves_gaps_between_its_petals_and_its_petals_are_faster() -> void:
	var d := _def(K.FLOWER)
	d.count = 40
	d.petals = 5
	var p := _table(d)
	var shots := BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 1.0)
	var n := (shots[1] as PackedVector2Array).size()
	assert_lt(n, 40, "the valleys are left out")
	assert_gt(n, 20)
	var lo := 99.0
	var hi := 0.0
	for v: Vector2 in shots[1]:
		lo = minf(lo, v.length())
		hi = maxf(hi, v.length())
	assert_almost_eq(hi, p.speed, 0.0001, "a petal's tip at the full speed")
	assert_lt(lo, hi * 0.8, "slower toward the valleys")
	assert_gt(_widest_gap(_angles(p, 0)), 4096 / 40, "gaps between the petals")


func test_a_burst_lands_then_bursts_into_its_star() -> void:
	var d := _def(K.BURST)
	d.count = 8
	d.lob_seconds = 0.5
	var p := _table(d)
	assert_eq(BulletPatterns.wave_at(p, 0), -1, "the shell is flying")
	assert_eq(BulletPatterns.wave_at(p, 30), 0, "it bursts as it lands")
	var shots := BulletPatterns.wave_shots(p, 0, Vector2(5, 5), 0, 0.0)
	assert_eq((shots[0] as PackedVector2Array).size(), 8)
	for pos: Vector2 in shots[0]:
		assert_eq(pos, Vector2(5, 5), "from the landing point")


func test_no_shot_spawns_on_the_player_or_in_a_wall() -> void:
	var w := BossLab.world()
	var d := _def(K.RING)
	d.count = 16
	d.gap_count = 1
	d.gap_width = 1
	var p := _table(d)
	w.actors.set_pos(0, Vector2(-1.0, 0.0))  # right on the ring's left muzzle (shot 8 of 16)
	var dummy := w.add_dummy(Vector2.ZERO, 0.5, 100)
	var i := w.actors.index_of(dummy)
	var all := BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 1.0)
	var fired := BulletPatterns.fire(w, i, p, 0, Vector2.ZERO, 0, 1.0, 5)
	assert_lt(
		fired, (all[0] as PackedVector2Array).size(), "the shots near the player are left out"
	)
	var safe := p.safe_radius_m + w.player.radius_m
	w.step(InputFrame.new())  # the queued shots spawn at the end of the tick, where they were queued
	assert_eq(w.projectiles.size(), fired)
	for k in w.projectiles.size():
		var at := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
		assert_gte((at - Vector2(-1, 0)).length(), safe - 0.001, "no shot spawned on the player")
	var walled := BossLab.world()
	var wall := Obb.make(Vector2(1.0, 0.0), Vector2(0.3, 3.0), 0)
	walled.set_walls([wall])
	walled.actors.set_pos(0, Vector2(-20, 0))
	var j := walled.actors.index_of(walled.add_dummy(Vector2.ZERO, 0.5, 100))
	var n := BulletPatterns.fire(walled, j, p, 0, Vector2.ZERO, 0, 1.0, 5)
	assert_lt(n, (all[0] as PackedVector2Array).size(), "the shots inside the wall are left out")


func test_shots_stop_at_walls() -> void:
	var w := BossLab.world()
	w.set_walls([Obb.make(Vector2(4.0, 0.0), Vector2(0.3, 6.0), 0)])
	w.actors.set_pos(0, Vector2(-20, 0))
	var d := _def(K.FAN)
	d.count = 3
	d.spread_degrees = 20.0
	var p := _table(d)
	var i := w.actors.index_of(w.add_dummy(Vector2.ZERO, 0.5, 100))
	assert_eq(BulletPatterns.fire(w, i, p, 0, Vector2.ZERO, 0, 1.0, 5), 3)
	var max_x := 0.0
	for t in 120:
		w.step(InputFrame.new())
		for k in w.projectiles.size():
			max_x = maxf(max_x, w.projectiles.pos_x[k])
	assert_eq(w.projectiles.size(), 0, "every shot ended")
	assert_lt(max_x, 3.7, "none went through the wall")


func test_the_per_tick_cap_drops_the_rest_with_one_limit_event() -> void:
	var w := BossLab.world()
	w.actors.set_pos(0, Vector2(-30, 0))
	var d := _def(K.RING)
	d.count = 64
	d.gap_count = 1
	d.gap_width = 4
	var p := _table(d)
	var i := w.actors.index_of(w.add_dummy(Vector2.ZERO, 0.5, 100))
	var seq := w.last_event_seq()
	var total := 0
	for k in 4:
		total += BulletPatterns.fire(w, i, p, 0, Vector2.ZERO, k * 64, 1.0, 5)
	assert_eq(total, BulletPatterns.MAX_SHOTS_PER_TICK, "capped in one tick")
	var limits := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.LIMIT
	)
	assert_eq(limits.size(), 2, "one LIMIT for each wave that was cut")
	assert_eq(limits[0].effect_id, BulletPatterns.EFFECT_CAP)
	w.step(InputFrame.new())
	assert_eq(
		BulletPatterns.fire(w, i, p, 0, Vector2.ZERO, 0, 1.0, 5), 60, "the next tick has room"
	)


func test_each_shot_carries_its_look_and_the_hash_holds_it() -> void:
	var w := BossLab.world()
	w.actors.set_pos(0, Vector2(-30, 0))
	var before := w.state_hash()
	var p := _table(_def(K.CROSS))
	var i := w.actors.index_of(w.add_dummy(Vector2.ZERO, 0.5, 100))
	BulletPatterns.fire(w, i, p, 0, Vector2.ZERO, 0, 1.0, 5)
	w.step(InputFrame.new())
	var reader := WorldReader.new(w)
	assert_gt(reader.projectile_count(), 0)
	for k in reader.projectile_count():
		assert_eq(reader.projectile_look(k), "ember_stone")
	assert_ne(w.state_hash(), before)


func test_a_pattern_fight_is_deterministic() -> void:
	var hashes := []
	for run in 2:
		var w := BossLab.world(91)
		var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
		w.actors.set_pos(0, Vector2(7, 2))
		w.actors.hp[0] = 1 << 20
		w.actors.max_hp[0] = 1 << 20
		BossLab.start(w, i, &"rock_rings")
		for t in 300:
			w.step(InputFrame.make(Vector2i(0, 60 if (t / 60) % 2 == 0 else -60), 0, 500, 0, 0))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_the_shipped_patterns_each_leave_a_gap_the_hero_fits() -> void:
	var repo := ContentRepository.load_all()
	var hero := PlayerTable.starting_values().radius_m * 2.0 + 0.2
	for def: BulletPatternDefinition in repo.all_of(&"bullet_patterns"):
		var p := PatternCompiler.compile_pattern(def)
		for k in p.waves:
			var shots := BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, 1.3)
			if p.kind == BulletPatternTable.Kind.WALL:
				var g := BulletPatterns.wall_gap(p, k)
				var free := 99.0
				for j in (shots[0] as PackedVector2Array).size():
					if Kin.angle_of(shots[1][j]) == 0:  # the first wall (a crossing one is at 1024)
						free = minf(free, absf((shots[0][j] as Vector2).y - g))
				assert_gte(free * 2.0 - 2.0 * p.radius_m, hero, "%s wave %d: its gap" % [def.id, k])
				continue
			var a := []
			for v: Vector2 in shots[1]:
				a.append(Kin.angle_of(v))
			# The gap's width 4 m out, between the shots' edges.
			var gap_m := 2.0 * PI * 4.0 * _widest_gap(a) / 4096.0 - 2.0 * p.radius_m
			assert_gte(gap_m, hero, "%s wave %d: a gap the hero fits" % [def.id, k])
