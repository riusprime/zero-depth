extends GutTest
## v0.9.5 Step BH5 (owner rows HC1, HC2, HC3; BOSSES_HARD.md): the Hollow Crown's first two bodies. The Colossus hits
## faster (fists 6.5 m/s, Leap Slam telegraph 0.55 s and its quake ring 7.5 m/s, boulders 5.2 m/s; Spike Chase
## unchanged). The Prism's balls leave room in the middle of the arena (ring 28 with 4 gaps 3 wide, flower 52, spiral
## 8 arms: a hero-sized circle fits a gap 3-7 m out) and her hit window opens wider (the Cross's last 3.5 s, and 2.0 s
## after each ball pattern), still shut while the lasers spin.

const LONG := 1 << 24
const HERO_R := 0.5
const NEAR_M := 3.0
const FAR_M := 7.0


func _arena(seed_value: int) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = LONG
	return w


func _colossus(seed_value: int = 301) -> World:
	var w := _arena(seed_value)
	FinalLab.past_rise(w)
	return w


func _prism(seed_value: int = 302) -> World:
	var w := _arena(seed_value)
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	return w


func _atk(w: World, id: StringName) -> BossAttackTable:
	var t := BossAi.table_of(w, FinalLab.body(w))
	var k := t.attack_index(id)
	assert_gte(k, 0, "has %s" % id)
	return t.attacks[k]


func _mps(per_tick: float) -> float:
	return per_tick * SimTick.TICKS_PER_SECOND


# --- HC1: the Colossus --------------------------------------------------------------------------------------------


func test_the_colossus_fists_fly_at_6_5() -> void:
	var w := _colossus()
	for id: StringName in [&"fist_combo", &"fist_combo_3"]:
		assert_almost_eq(_mps(_atk(w, id).speed), 6.5, 0.001, "%s: 6.5 m/s (was 5.5)" % id)


func test_leap_slam_telegraphs_in_0_55_s_and_its_ring_runs_at_7_5() -> void:
	var w := _colossus()
	for id: StringName in [&"leap_slam", &"leap_slam_2", &"leap_slam_3"]:
		var a := _atk(w, id)
		assert_eq(
			a.windup_ticks, 33, "%s: 0.55 s telegraph (was 0.7; 0.7 x 0.75 is under the floor)" % id
		)
		assert_gte(a.windup_ticks, 33, "never under 0.55 s")
		assert_gte(a.windup_ticks, a.lock_ticks, "the lock fits in the telegraph")
		assert_almost_eq(
			_mps(a.pattern.speed), 7.5, 0.001, "%s: ring stones 7.5 m/s (was 6.5)" % id
		)


func test_boulders_lob_at_5_2_and_spike_chase_is_unchanged() -> void:
	var w := _colossus()
	for id: StringName in [&"boulder_throw", &"boulder_throw_3"]:
		assert_almost_eq(_mps(_atk(w, id).pattern.speed), 5.2, 0.001, "%s: 5.2 m/s (was 4.2)" % id)
	for id: StringName in [&"spike_chase", &"spike_chase_2", &"spike_chase_3"]:
		var a := _atk(w, id)
		assert_eq(a.windup_ticks, 54, "%s: still the 0.9 s telegraph" % id)
	assert_eq(_atk(w, &"spike_chase").step_m, 1.6, "and its spacing")


# --- HC2: the Prism's balls ---------------------------------------------------------------------------------------


func test_the_ball_patterns_hold_fewer_orbs() -> void:
	var w := _prism()
	var ring := _atk(w, &"crown_ring").pattern
	assert_eq(ring.count, 28, "ring 28 per wave (was 32)")
	assert_eq(ring.gap_count, 4)
	assert_eq(ring.gap_width, 3, "gaps 3 wide (was 2)")
	assert_eq(_atk(w, &"crown_flower").pattern.count, 52, "flower 52 per wave (was 64)")
	assert_eq(_atk(w, &"crown_spiral").pattern.arms, 8, "spiral 8 arms (was 10)")


## The widest gap (m) a wave leaves `r` out from her centre: the chord between neighbouring orbs less an orb's width.
func _widest(pat: BulletPatternTable, kw: int, r: float) -> float:
	var shots := BulletPatterns.wave_shots(pat, kw, Vector2.ZERO, 0, 1.75)
	var angs: Array[int] = []
	for v: Vector2 in shots[1]:
		angs.append(Kin.angle_of(v))
	angs.sort()
	var best := 0.0
	for k in angs.size():
		var nxt := angs[(k + 1) % angs.size()] + (4096 if k == angs.size() - 1 else 0)
		var step := nxt - angs[k]
		best = maxf(best, 2.0 * r * sin(PI * step / 4096.0) - 2.0 * pat.radius_m)
	return best


## "Dodgeable from the middle of the room": for every pattern and wave, at every metre from 3 to 7 m out a 0.5 m-radius
## hero fits a gap of at least 1.2 m, so a safe path never has to go near the wall.
func test_a_hero_fits_a_gap_in_the_middle_third_of_the_room() -> void:
	var w := _prism()
	for id: StringName in [&"crown_ring", &"crown_spiral", &"crown_flower"]:
		var pat := _atk(w, id).pattern
		var least := 99.0
		var most := 0.0
		for kw in pat.waves:
			if pat.kind == BulletPatternTable.Kind.SPIRAL and kw > 0:
				continue  # the arms are the same every wave; they only turn
			for m in range(int(NEAR_M), int(FAR_M) + 1):
				var g := _widest(pat, kw, float(m))
				least = minf(least, g)
				most = maxf(most, g)
				assert_gte(g, 2.0 * HERO_R, "%s wave %d at %d m: the hero fits" % [id, kw, m])
				assert_gte(g, 1.2, "%s wave %d at %d m: a gap of 1.2 m+ (%.2f)" % [id, kw, m, g])
		gut.p(
			(
				"BH5 gap %s: widest gap per ring 3-7 m out, least %.2f m, most %.2f m"
				% [id, least, most]
			)
		)


# --- HC3: the Prism's hit window ----------------------------------------------------------------------------------


func _poke(w: World, i: int) -> int:
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i)
	var before := w.actors.hp[i]
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 20, pid, pid, w.take_root(), 0, at, at)
	return before - w.actors.hp[i]


func test_the_crosses_window_is_the_last_3_5_s_and_the_spin_is_shut() -> void:
	var w := _prism()
	var i := FinalLab.body(w)
	for id: StringName in [&"cross_ring", &"cross_spiral", &"cross_flower"]:
		var a := _atk(w, id)
		assert_eq(a.window_ticks, 210, "%s: 3.5 s window (was 2.5)" % id)
		assert_eq(a.spin_ticks, 300, "%s: the spin is still 5 s" % id)
		assert_eq(
			a.active_ticks,
			a.spin_ticks + a.window_ticks,
			"the window is the last part of the active time"
		)
	var atk := _atk(w, &"cross_ring")
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(&"cross_ring"))
	assert_eq(_poke(w, i), 0, "shut through the windup")
	var shut := 0
	var open := 0
	for k in 600:
		if w.actors.state[i] == EnemyAi.State.ACTIVE:
			var st := w.actors.state_t[i]
			var probe := (
				st % 15 == 0
				or st == atk.spin_ticks - 1
				or st == atk.spin_ticks
				or st == atk.active_ticks - 1
			)
			if st < atk.spin_ticks:
				shut += 1
				if probe:
					assert_eq(_poke(w, i), 0, "no hit while the beams spin (tick %d)" % st)
			elif st < atk.active_ticks:
				open += 1
				if probe:
					assert_gt(_poke(w, i), 0, "hurt in the window (tick %d)" % st)
		w.step(InputFrame.new())
		if (
			w.actors.state[i] != EnemyAi.State.ACTIVE
			and w.actors.state[i] != EnemyAi.State.WINDUP
			and open > 0
		):
			break
	assert_eq(shut, atk.spin_ticks, "all 300 spin ticks were shut")
	assert_eq(open, 210, "all 210 window ticks were open")


func test_she_can_be_hurt_for_2_s_after_each_ball_pattern_ends() -> void:
	var w := _prism()
	var i := FinalLab.body(w)
	for id: StringName in [&"crown_ring", &"crown_spiral", &"crown_flower"]:
		var a := _atk(w, id)
		assert_eq(a.recover_ticks, 120, "%s: 2.0 s open after the pattern" % id)
		assert_eq(a.cooldown_ticks, 0, "and nothing else added to it")
		BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(id))
		var shielded_ticks := 0
		var open_after := 0
		var seen_recover := false
		for k in 2400:
			var s := w.actors.state[i]
			if s == EnemyAi.State.WINDUP or s == EnemyAi.State.ACTIVE:
				assert_true(BossDodge.shielded(w, i), "%s: shielded while she casts" % id)
				shielded_ticks += 1
			elif s == EnemyAi.State.RECOVER:
				if not seen_recover:
					assert_eq(BossPrism.shots_alive(w, i), 0, "%s: no orb left as she opens" % id)
				seen_recover = true
				assert_false(BossDodge.shielded(w, i), "%s: open in the recovery" % id)
				open_after += 1
			elif seen_recover:
				break
			w.step(InputFrame.new())
		assert_gt(shielded_ticks, 0)
		assert_eq(open_after, 120, "%s: 120 open ticks after the last orb is gone" % id)
