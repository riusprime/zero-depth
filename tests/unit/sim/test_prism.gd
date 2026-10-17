# gdlint: disable=max-public-methods
extends GutTest
## v0.8.0 FB2 (owner O17; FINAL_BOSS.md F5, F7 "Phase-by-phase mix"; SIM_CONTRACTS "The final boss"): the Prism in the
## sim. She floats home; the Cross's beams turn a quarter turn per quarter, reverse, alternate their way, speed up as
## her HP drops, stop at the walls and never open on the player; she is shielded while they turn and open only in the
## window after; her shards fire the orb patterns (their gaps kept) and fast bolts after a 0.4 s aim line; her HP comes
## from the measured damage per second (the formula, its clamps, determinism); the death lines; saves mid-phase-2.

const LONG := 1 << 24


func _arena(seed_value: int = 41) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = LONG
	return w


## The arena with the Prism risen (jumped to from the Colossus's rise) and acting.
func _prism(seed_value: int = 41) -> World:
	var w := _arena(seed_value)
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	return w


func _attack(w: World, id: StringName) -> int:
	return BossAi.table_of(w, FinalLab.body(w)).attack_index(id)


## Starts Cross `id` now (its windup) and returns its table.
func _start(w: World, id: StringName = &"cross_ring") -> BossAttackTable:
	var i := FinalLab.body(w)
	BossAi.start_attack(w, i, _attack(w, id))
	return BossAi.attack_of(w, i)


## Steps until the Cross in progress is `st` ticks into its active time.
func _to_active(w: World, st: int = 0) -> void:
	var i := FinalLab.body(w)
	for k in 600:
		if w.actors.state[i] == EnemyAi.State.ACTIVE and w.actors.state_t[i] >= st:
			return
		w.step(InputFrame.new())


func _touches_any(w: World, beams: Array[Obb], p: Vector2) -> bool:
	for o in beams:
		if Collide.circle_vs_obb(p, w.player.radius_m, o) != Vector2.ZERO:
			return true
	return false


func _hostile(w: World, look: String) -> Array[int]:
	var out: Array[int] = []
	for k in w.projectiles.size():
		if w.projectiles.team[k] != ActorStore.TEAM_PLAYER and w.projectiles.look[k] == look:
			out.append(k)
	return out


# --- the body -------------------------------------------------------------------------------------------------------


func test_the_prism_is_a_skill_phase_in_data() -> void:
	var w := _prism()
	var t := BossAi.table_of(w, FinalLab.body(w))
	assert_true(t.dps_hp, "her HP comes from the measured damage per second")
	assert_true(t.floats_home)
	assert_eq(t.shard_count, 6)
	assert_eq(t.window_permille, 294, "a 2.5 s window in each 8.5 s cycle")
	for id: StringName in [&"cross_ring", &"cross_spiral", &"cross_flower", &"cross_weave"]:
		var a := t.attacks[t.attack_index(id)]
		assert_eq(a.move, BossAttackTable.Move.CROSS)
		assert_eq(a.count, 4, "four beams in a plus")
		assert_true(a.shielded)
		var bolt := &"prism_bolt_fan" if id == &"cross_weave" else &"prism_bolt"  # v0.8.0 N2
		assert_eq(a.bolt_attack, t.attack_index(bolt))
		assert_eq(t.attacks[a.bolt_attack].lock_ticks, 24, "the fast shots' aim line: 0.4 s")
		assert_eq(a.pattern.look, &"crown_orb", "her own fireball look")
	assert_eq(t.phase_attacks.size(), 1)
	assert_false(
		t.phase_attacks[0].has(t.attack_index(&"prism_bolt")), "the bolts fire inside a Cross"
	)


func test_she_floats_home_and_barely_moves() -> void:
	var w := _arena(42)
	FinalLab.past_rise(w)
	w.actors.set_pos(FinalLab.body(w), Vector2(6, 0))
	FinalBoss.jump(w, 1)
	var i := FinalLab.body(w)
	assert_eq(w.actors.pos(i), Vector2(6, 0), "she rises where the Colossus stood")
	var t := BossAi.table_of(w, i)
	var last := w.actors.pos(i)
	for k in 400:
		w.step(InputFrame.new())
		var p := w.actors.pos(i)
		assert_true(Kin.length(p - last) <= t.speed + 0.0001, "a slow glide")
		last = p
	assert_almost_eq(Kin.length(w.actors.pos(i) - w.final_fight.home), 0.0, 0.01, "at the centre")
	w.actors.set_pos(0, Vector2(3, 3))
	CombatLab.idle(w, 120)
	assert_almost_eq(Kin.length(w.actors.pos(i)), 0.0, 0.01, "she stays there, wherever you go")


# --- the Cross ------------------------------------------------------------------------------------------------------


func test_the_cross_never_starts_on_the_player() -> void:
	for k in 8:
		var w := _prism(50 + k)
		var i := FinalLab.body(w)
		var ang := k * 512 + 100
		w.actors.set_pos(0, Kin.dir(ang) * (3.0 + k))
		var atk := _start(w)
		var hp := w.actors.hp[0]
		w.actors.invuln[0] = 0
		var around := Kin.dir(ang + 1024)
		for t in atk.windup_ticks + 1:
			var arms: Array[Obb] = []
			for a in atk.count:
				arms.append(
					BossPrism.beam_at(w, i, BossPrism.arm_angle(atk, w.actors.lock_a[i], a))
				)
			assert_false(
				_touches_any(w, arms, w.player_pos()), "no aim line on the player (%d)" % k
			)
			var f := FinalLab.walk(w, w.player_pos() + around)
			w.step(f)
		assert_eq(w.actors.state[i], EnemyAi.State.ACTIVE, "the beams opened")
		assert_eq(w.actors.hp[0], hp, "not on the player (%d)" % k)


func test_the_arms_keep_the_player_midway_through_the_windup() -> void:
	var w := _prism(60)
	var i := FinalLab.body(w)
	var atk := _start(w)
	for t in atk.windup_ticks - 1:
		w.step(FinalLab.walk(w, Vector2(-8, 6)))
		var aim := Kin.angle_of(w.player_pos() - w.actors.pos(i))
		var off := (w.actors.lock_a[i] - aim) & 1023
		assert_true(absi(off - 512) <= 8, "the player stands midway between two arms (%d)" % off)


func test_the_beams_turn_a_quarter_per_quarter_and_reverse() -> void:
	var w := _prism(61)
	var i := FinalLab.body(w)
	var atk := _start(w)
	_to_active(w)
	var q := BossPrism.quarter(w, i)
	var way := w.bosses.span[BossAi.entry_of(w, i)]
	var a0 := BossPrism.angle_at(w, i, 0)
	assert_eq((BossPrism.angle_at(w, i, q) - a0) & 4095, (way * 1024) & 4095, "a quarter turn")
	var r := atk.reverse_ticks
	assert_eq(
		BossPrism.angle_at(w, i, r + 30),
		BossPrism.angle_at(w, i, r - 30),
		"then back the way it came"
	)
	for st in range(1, atk.spin_ticks):
		var d := (BossPrism.angle_at(w, i, st) - BossPrism.angle_at(w, i, st - 1) + 2048) & 4095
		assert_true(absi(d - 2048) <= 1024 / q + 1, "at most its step a tick")


func test_each_cross_turns_the_other_way() -> void:
	var w := _prism(62)
	var i := FinalLab.body(w)
	var b := BossAi.entry_of(w, i)
	var ways := []
	for n in 4:
		_start(w, [&"cross_ring", &"cross_spiral", &"cross_flower", &"cross_ring"][n])
		ways.append(w.bosses.span[b])
	assert_eq(ways[1], -ways[0])
	assert_eq(ways[2], ways[0])
	assert_eq(ways[3], -ways[0])


func test_the_cross_speeds_up_as_her_hp_drops() -> void:
	var w := _prism(63)
	var i := FinalLab.body(w)
	var atk := BossAi.table_of(w, i).attacks[_attack(w, &"cross_ring")]
	assert_eq(BossPrism.quarter_of(w, i, atk), atk.quarter_ticks, "full HP: 2.4 s a quarter")
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	assert_eq(
		BossPrism.quarter_of(w, i, atk),
		atk.fast_quarter_ticks + (atk.quarter_ticks - atk.fast_quarter_ticks) / 2,
		"half HP: halfway"
	)
	w.actors.hp[i] = 1
	assert_almost_eq(float(BossPrism.quarter_of(w, i, atk)), float(atk.fast_quarter_ticks), 1.0)
	_start(w)
	assert_eq(BossPrism.quarter(w, i), BossPrism.quarter_of(w, i, atk), "set as the windup begins")


func test_the_walls_stop_the_beams() -> void:
	var w := _prism(64)
	var i := FinalLab.body(w)
	var atk := _start(w)
	_to_active(w, 40)
	for o in BossPrism.beams(w, i, 40):
		var end := o.center + Kin.dir(o.angle) * o.half.x
		assert_true(o.half.x * 2.0 < atk.length_m, "cut short of its 40 m")
		var r := Kin.length(end)
		assert_true(r > 12.0 and r < 15.2, "it ends at the arena's wall (%.2f m out)" % r)
	var c := WorldReader.new(w).boss_cross(i)
	for arm: Array in c["arms"]:
		assert_true(arm[2], "the views see each beam hit the wall")


func test_the_beams_burn_at_most_once_per_burn() -> void:
	var w := _prism(65)
	var i := FinalLab.body(w)
	var atk := _start(w)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	var id := w.actors.ids[i]
	var windows := {}
	var hits := 0
	for k in atk.windup_ticks + atk.spin_ticks:
		w.actors.invuln[0] = 0  # no hurt iframes: only the burn holds it back
		w.actors.set_pos(0, Vector2(4, 0))
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		for e in w.events_since(seq):
			if (
				e.kind == SimEvent.Kind.DAMAGE
				and e.owner_id == id
				and e.target_id == w.actors.ids[0]
				and e.tags & SimEvent.TAG_AREA
			):
				hits += 1
				var win := w.actors.state_t[i] / atk.burn_ticks
				assert_false(windows.has(win), "once per burn at most")
				windows[win] = true
	assert_gt(hits, 1, "standing still, the arms sweep through you")


# --- the shield and the window ------------------------------------------------------------------------------------


func test_she_is_shielded_while_the_cross_turns_and_open_in_its_window() -> void:
	var w := _prism(66)
	var i := FinalLab.body(w)
	var atk := _start(w)
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i)
	var poke := func() -> int:
		var before := w.actors.hp[i]
		w.actors.invuln[i] = 0
		Damage.hit(w, i, 20, pid, pid, w.take_root(), 0, at, at)
		return before - w.actors.hp[i]
	assert_eq(poke.call(), 0, "shielded through the spin-up")
	_to_active(w, 10)
	assert_eq(poke.call(), 0, "shielded while the Cross turns")
	assert_false(WorldReader.new(w).boss_cross(i)["window"])
	_to_active(w, atk.spin_ticks)
	assert_true(WorldReader.new(w).boss_cross(i)["window"], "the window")
	assert_true((WorldReader.new(w).boss_cross(i)["arms"] as Array).is_empty(), "the beams are out")
	assert_gt(poke.call(), 0, "open in the window")
	var t := 0
	while w.actors.state[i] != EnemyAi.State.WINDUP and t < 600:
		w.step(InputFrame.new())
		t += 1
	assert_true(t <= atk.window_ticks + 3, "the next Cross follows the window")
	assert_eq(poke.call(), 0, "shielded again")


func test_a_whole_cycle_is_open_only_in_its_window() -> void:
	var w := _prism(67)
	var i := FinalLab.body(w)
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[i] == EnemyAi.State.WINDUP)
	var open := 0
	var total := 0
	for k in 1020:  # two cycles
		w.step(InputFrame.new())
		total += 1
		if not BossDodge.shielded(w, i):
			open += 1
	assert_almost_eq(float(open) / total, 0.294, 0.02, "open about 2.5 s of every 8.5 s")


# --- orbs and bolts -----------------------------------------------------------------------------------------------


func test_the_orbs_fly_from_her_orbiting_shards() -> void:
	var w := _prism(68)
	var i := FinalLab.body(w)
	var atk := _start(w)
	w.actors.set_pos(0, Vector2(-6, 5))
	var seen := 0
	for k in atk.windup_ticks + atk.spin_ticks:
		var before := {}
		for p in w.projectiles.size():
			before[w.projectiles.ids[p]] = true
		w.step(FinalLab.walk(w, w.player_pos()))
		var shards := BossPrism.shards(w, i)
		for p in _hostile(w, "crown_orb"):
			if before.has(w.projectiles.ids[p]):
				continue
			seen += 1
			var at := (
				Vector2(w.projectiles.pos_x[p], w.projectiles.pos_y[p])
				- Vector2(w.projectiles.vel_x[p], w.projectiles.vel_y[p])
			)
			var near := 99.0
			for s in shards:
				near = minf(near, Kin.length(at - s))
			assert_true(near < 0.6, "it leaves a shard (%.2f m)" % near)
			var safe := atk.pattern.safe_radius_m + w.player.radius_m
			assert_true(Kin.length(at - w.player_pos()) >= safe - 0.2, "never on the player")
			assert_eq(
				w.projectiles.cause[p],
				BossPrism.ORB_CAUSE + _attack(w, &"cross_ring"),
				"the orbs carry their line"
			)
	assert_gt(seen, 40, "volleys of orbs between the beams")


func test_every_orb_pattern_leaves_a_gap() -> void:
	var w := _prism(69)
	var t := BossAi.table_of(w, FinalLab.body(w))
	for id: StringName in [&"cross_ring", &"cross_spiral", &"cross_flower", &"cross_weave"]:
		var pat := t.attacks[t.attack_index(id)].pattern
		for kw in pat.waves:
			var shots := BulletPatterns.wave_shots(pat, kw, Vector2.ZERO, 1024, 0.5)
			var angs: Array[int] = []
			for v: Vector2 in shots[1]:
				angs.append(Kin.angle_of(v))
			angs.sort()
			var widest := 0
			for k in angs.size():
				var nxt := angs[(k + 1) % angs.size()] + (4096 if k == angs.size() - 1 else 0)
				widest = maxi(widest, nxt - angs[k])
			var gap_m := 4.0 * TAU * widest / 4096.0 - 2.0 * pat.radius_m
			assert_true(
				gap_m >= 2.0 * w.player.radius_m + 0.3,
				"%s wave %d: a gap you fit (%.2f m)" % [id, kw, gap_m]
			)


func test_a_fast_bolt_aims_for_0_4_s_then_flies_down_its_line() -> void:
	var w := _prism(70)
	var i := FinalLab.body(w)
	_start(w)
	w.actors.set_pos(0, Vector2(-7, 4))
	var reader := WorldReader.new(w)
	CombatLab.until(
		w, func(x: World) -> bool: return not BossPrism.bolt_state(x, i).is_empty(), 900
	)
	var aim := BossPrism.bolt_state(w, i)
	assert_false(aim.is_empty(), "an aim line shows")
	var from: Vector2 = aim["from"]
	var ang: int = aim["angle"]
	assert_eq(ang, Kin.angle_of(Vector2(-7, 4) - from), "aimed at where the player stood")
	assert_true(Kin.length(from - w.actors.pos(i)) > 2.0, "from a shard, off her body")
	var bolts := _hostile(w, "crown_bolt").size()
	var ticks := 0
	while _hostile(w, "crown_bolt").size() == bolts and ticks < 60:
		w.actors.set_pos(0, w.player_pos() + Vector2(0, 0.1))  # the player sidesteps
		w.step(InputFrame.new())
		ticks += 1
		if _hostile(w, "crown_bolt").size() == bolts:
			assert_false(reader.boss_cross(i)["bolt"].is_empty(), "the line shows until it fires")
	assert_eq(ticks, 24, "it fires 0.4 s after its line showed")
	var k: int = _hostile(w, "crown_bolt")[-1]
	var v := Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])
	assert_eq(Kin.angle_of(v), ang, "down the locked line, not at where the player went")
	assert_almost_eq(Kin.length(v) * 60.0, 22.0, 0.05, "fast: 22 m/s")
	assert_eq(w.projectiles.cause[k], _attack(w, &"prism_bolt"), "it names the bolt")


func test_no_bolt_fires_on_the_player() -> void:
	var w := _prism(71)
	var i := FinalLab.body(w)
	_start(w)
	CombatLab.until(
		w, func(x: World) -> bool: return not BossPrism.bolt_state(x, i).is_empty(), 900
	)
	var from: Vector2 = BossPrism.bolt_state(w, i)["from"]
	var bolts := _hostile(w, "crown_bolt").size()
	for k in 30:
		w.actors.set_pos(0, from)
		w.step(InputFrame.new())
	assert_eq(_hostile(w, "crown_bolt").size(), bolts, "standing on its shard, no bolt")


# --- the HP from the measured damage per second (F7) ----------------------------------------------------------------


func _fill_meter(w: World, per_second: Array) -> void:
	var f := w.final_fight
	for d: int in per_second:
		f.dps_acc = d
		f.close_second()


func test_her_hp_is_the_formula_of_the_measured_dps() -> void:
	var w := _arena(72)
	FinalLab.past_rise(w)
	var t := w.boss_tables[w.final_fight.tables[1]]
	var secs := []
	for k in 30:
		secs.append(1000 if k < 10 else 100)  # the last 20 s: 100 a second
	_fill_meter(w, secs)
	# v0.8.0 N2 (owner O41): the pace: at 100 dps she lasts 120 s × sqrt(30 / 100) = 65.6 s of windows
	var secs_at := FinalPace.seconds_at(100000, t)
	assert_eq(secs_at, 3938, "120 s × sqrt(30 / 100), in ticks (the integer root: 0.547)")
	var expect := 100 * secs_at / 60 * t.window_permille / 1000
	assert_eq(FinalBoss.dps_hp_of(w, t), expect, "100 dps × 65.6 s × 0.294 window share")
	assert_eq(expect, 1929)
	FinalBoss.jump(w, 1)
	var i := FinalLab.body(w)
	assert_eq(w.actors.max_hp[i], expect, "she rises with it")
	assert_eq(w.actors.hp[i], expect)


func test_the_formula_is_clamped() -> void:
	var w := _arena(73)
	var t := w.boss_tables[w.final_fight.tables[1]]
	_fill_meter(w, [1, 1, 1, 1, 1, 1])
	assert_eq(FinalBoss.dps_hp_of(w, t), t.dps_hp_min, "a weak build: her minimum (600)")
	var w2 := _arena(73)
	var big := []
	for k in 20:
		big.append(2000000)
	_fill_meter(w2, big)
	assert_eq(FinalBoss.dps_hp_of(w2, t), t.dps_hp_max, "super ultra omega OP: her maximum")
	var w3 := _arena(73)
	_fill_meter(w3, [500, 500])
	assert_eq(
		FinalBoss.dps_hp_of(w3, t),
		clampi(t.hp, t.dps_hp_min, t.dps_hp_max),
		"under 5 s measured: her own HP"
	)


func test_the_same_meter_gives_the_same_hp() -> void:
	var a := _arena(74)
	var b := _arena(74)
	var secs := [37, 120, 0, 455, 98, 301, 77, 15, 600, 3]
	_fill_meter(a, secs)
	_fill_meter(b, secs)
	var t := a.boss_tables[a.final_fight.tables[1]]
	assert_eq(FinalBoss.dps_hp_of(a, t), FinalBoss.dps_hp_of(b, t))
	assert_eq(
		FinalBoss.dps_hp_of(a, t),
		FinalPace.hp_for((37 + 120 + 455 + 98 + 301 + 77 + 15 + 600 + 3) * 1000 / 10, t)
	)


func test_the_meter_measures_the_colossus_fight_only() -> void:
	var w := _arena(75)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	var pid := w.actors.ids[0]
	var dealt := 0
	w.final_fight.dps_t = 0
	for k in 600:  # 10 s: one hit of 30 a second (the build's damage stats scale it)
		var seq := w.last_event_seq()
		if k % 60 == 0:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 30, pid, pid, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i))
		w.step(InputFrame.new())
		for e in w.events_since(seq):
			if (
				e.kind == SimEvent.Kind.DAMAGE
				and e.owner_id == pid
				and e.target_id == w.actors.ids[i]
			):
				dealt += e.amount
	var m := w.final_fight.measured(60)
	assert_eq(m[1], 10, "ten seconds measured")
	assert_eq(m[0], dealt, "every hit the player dealt, as dealt")
	assert_gt(dealt, 299)
	FinalLab.end_segment(w)
	var closed := w.final_fight.dps_closed
	FinalLab.through_shatter(w)
	assert_eq(w.final_fight.dps_closed, closed, "the shatter and her rise aren't measured")
	CombatLab.idle(w, 300)
	assert_eq(w.final_fight.dps_closed, closed, "nor her own fight")
	var t := BossAi.table_of(w, FinalLab.body(w))
	assert_eq(w.actors.max_hp[FinalLab.body(w)], FinalBoss.dps_hp_of(w, t), "her HP from it")


# --- the recap ----------------------------------------------------------------------------------------------------


func test_each_part_names_its_death() -> void:
	var w := _prism(76)
	var i := FinalLab.body(w)
	var cross := _attack(w, &"cross_spiral")
	w.killer_kind = w.actors.kinds[i]
	w.killer_attack = cross
	assert_eq(BossAi.cause_key(w), &"CAUSE_PRISM_BEAM")
	w.killer_attack = BossPrism.ORB_CAUSE + cross
	assert_eq(BossAi.cause_key(w), &"CAUSE_PRISM_ORBS")
	w.killer_attack = _attack(w, &"prism_bolt")
	assert_eq(BossAi.cause_key(w), &"CAUSE_PRISM_BOLT")


func test_the_beam_kills_with_its_line() -> void:
	var w := _prism(77)
	var i := FinalLab.body(w)
	_start(w)
	_to_active(w, 1)
	var o: Obb = BossPrism.beams(w, i, w.actors.state_t[i] + 1)[0]
	w.actors.set_pos(0, o.center)
	w.actors.invuln[0] = 0
	w.actors.hp[0] = 1
	w.step(InputFrame.new())
	assert_true(w.player_dead())
	assert_eq(BossAi.cause_key(w), &"CAUSE_PRISM_BEAM")


# --- determinism and saves ----------------------------------------------------------------------------------------


func test_phase_2_is_deterministic() -> void:
	var a := _prism(78)
	var b := _prism(78)
	for k in 900:
		var f := FinalLab.walk(a, Vector2(-6, 6) if (k / 120) % 2 == 0 else Vector2(6, -2))
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash())


func test_a_snapshot_mid_cross_round_trips() -> void:
	var run := FinalLab.run_state(79)
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = LONG
	FinalLab.past_rise(w)
	CombatLab.idle(w, 200)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	_start(w)
	_to_active(w, 130)
	var snap := w.to_snapshot()
	var w2 := FinalLab.arena(run, false)
	assert_eq(WorldSnapshot.apply(w2, snap), "")
	assert_eq(w2.state_hash(), w.state_hash())
	for k in 400:
		w.step(InputFrame.new())
		w2.step(InputFrame.new())
	assert_eq(w2.state_hash(), w.state_hash(), "the Cross, its orbs and bolts go on the same")


func test_a_save_from_before_fb2_mid_phase_2_restores() -> void:
	var run := FinalLab.run_state(80)
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = LONG
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	w.final_fight.dps_t = 0  # an FB1 world never ran the meter (it counted the Colossus's first acting tick)
	assert_eq(w.final_fight.dps_closed, 0)
	CombatLab.idle(w, 150)
	var p := RunSaver.payload_of(w, run, 80, PackedByteArray())
	var ff: Dictionary = p["world"]["world"][&"final_fight"]
	for f: StringName in [&"home", &"dps_secs", &"dps_head", &"dps_closed", &"dps_acc", &"dps_t"]:
		ff.erase(f)  # as a payload written by FB1
	var back := RunSaver.run_from(
		p, ContentCompiler.compile_run(ContentRepository.load_all().get_def(&"run", SaveLab.RUN_ID))
	)
	var w2 := FinalLab.arena(back, false)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "an FB1 snapshot restores mid-phase-2")
	assert_eq(w2.state_hash(), w.state_hash(), "the same state")
	for k in 300:
		w.step(InputFrame.new())
		w2.step(InputFrame.new())
	assert_eq(w2.state_hash(), w.state_hash(), "and her fight goes on the same")
