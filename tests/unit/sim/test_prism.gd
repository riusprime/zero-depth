# gdlint: disable=max-public-methods
extends GutTest
## v0.8.0 FB2 (owner O17; FINAL_BOSS.md F5, F7 "Phase-by-phase mix"; SIM_CONTRACTS "The final boss"): the Prism in the
## sim. She floats home; the Cross's beams turn a quarter turn per quarter, reverse, alternate their way, speed up as
## her HP drops, stop at the walls and never open on the player; she is shielded while they turn and open only in the
## window after; her shards fire the orb patterns (their gaps kept) and fast bolts after a 0.4 s aim line; her HP comes
## from the measured damage per second (the formula, its clamps, determinism); the death lines; saves mid-phase-2.
## v0.8.0 PR (owner O84): the Cross turns 15 % slower; the orbs are three spells of their own in fixed, dodgeable
## patterns from her centre; her spells rotate one at a time (Cross, orbs, Cross, …) and never overlap: no orb or bolt
## is in the air while a beam is aimed or burning; the bolts fire only in the window.

const LONG := 1 << 24
## v0.8.0 PR: the rotation, in order (one spell at a time).
const ROTATION: Array[StringName] = [
	&"cross_ring", &"crown_ring", &"cross_spiral", &"crown_spiral", &"cross_flower", &"crown_flower"
]
## The orb spells and their pattern kinds (three distinct patterns).
const ORB_SPELLS := {
	&"crown_ring": BulletPatternTable.Kind.RING,
	&"crown_spiral": BulletPatternTable.Kind.SPIRAL,
	&"crown_flower": BulletPatternTable.Kind.FLOWER,
}
## The hero's usual distance from her for the gap numbers (m): the patterns' validation distance.
const USUAL_M := BulletPatternDefinition.GAP_CHECK_M
## FB2's Cross, before PR (ticks): quarter 2.4 s, fast quarter 1.2 s, reverse 3.0 s.
const OLD_QUARTER := 144
const OLD_FAST := 72
const OLD_REVERSE := 180


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
	assert_true(t.rotation, "v0.8.0 PR: her spells rotate")
	assert_true(t.window_permille > 100 and t.window_permille < 300, "the open share of a rotation")
	for id: StringName in [&"cross_ring", &"cross_spiral", &"cross_flower"]:
		var a := t.attacks[t.attack_index(id)]
		assert_eq(a.move, BossAttackTable.Move.CROSS)
		assert_eq(a.count, 4, "four beams in a plus")
		assert_true(a.shielded)
		assert_eq(a.bolt_attack, t.attack_index(&"prism_bolt"))
		assert_eq(t.attacks[a.bolt_attack].lock_ticks, 24, "the fast shots' aim line: 0.4 s")
		assert_null(a.pattern, "v0.8.0 PR: a Cross fires no orbs")
	for id: StringName in ORB_SPELLS:
		var a := t.attacks[t.attack_index(id)]
		assert_eq(a.move, BossAttackTable.Move.PATTERN)
		assert_true(a.shielded, "shielded while she casts")
		assert_eq(a.fixed_aim, 0, "a fixed aim, not at the player")
		assert_eq(a.pattern.look, &"crown_orb", "her own fireball look")
	assert_eq(t.phase_attacks.size(), 1)
	var listed: Array[StringName] = []
	for k in t.phase_attacks[0]:
		listed.append(t.attacks[k].id)
	assert_eq(listed, ROTATION, "the rotation: Cross, orbs, Cross, orbs, Cross, orbs")
	assert_eq(t.attack_index(&"cross_weave"), -1, "N2's weave Cross is gone (O84)")


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
	assert_eq(BossPrism.quarter_of(w, i, atk), atk.quarter_ticks, "full HP: 2.82 s a quarter")
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
	assert_true(t <= atk.window_ticks + 90, "the next spell follows the window (%d)" % t)
	assert_eq(
		BossAi.table_of(w, i).attacks[w.bosses.attack[BossAi.entry_of(w, i)]].id, &"crown_ring"
	)
	assert_eq(poke.call(), 0, "shielded again while she casts the orbs")


## v0.8.0 PR: over a whole rotation she is open about the share her HP is set from (window_permille).
func test_a_whole_rotation_is_open_about_its_window_share() -> void:
	var w := _prism(67)
	var i := FinalLab.body(w)
	var b := BossAi.entry_of(w, i)
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[i] == EnemyAi.State.WINDUP)
	var open := 0
	var total := 0
	var starts := 0
	var last := w.bosses.attack[b]
	while starts < ROTATION.size() and total < 6000:  # one rotation, from the first Cross's windup
		w.step(InputFrame.new())
		total += 1
		if not BossDodge.shielded(w, i):
			open += 1
		if w.bosses.attack[b] >= 0 and w.bosses.attack[b] != last:
			starts += 1
		if w.bosses.attack[b] >= 0:
			last = w.bosses.attack[b]
	var share := BossAi.table_of(w, i).window_permille / 1000.0
	gut.p(
		(
			"PR rotation: %d ticks (%.1f s), open %d ticks (%.3f; compiled %.3f)"
			% [total, total / 60.0, open, float(open) / total, share]
		)
	)
	assert_eq(starts, ROTATION.size(), "a whole rotation ran")
	assert_almost_eq(float(open) / total, share, 0.02, "open about her window share")


# --- orbs and bolts -----------------------------------------------------------------------------------------------


## v0.8.0 PR (O84: "a predictable pattern"): each orb spell fires from her centre at its fixed angle, wherever the
## player stands, the same orbs each time.
func test_the_orbs_fly_from_her_centre_at_a_fixed_angle() -> void:
	var sets := []
	for spot: Vector2 in [Vector2(-6, 5), Vector2(7, 2)]:
		var w := _prism(68)
		var i := FinalLab.body(w)
		w.actors.set_pos(0, spot)
		var atk := _start(w, &"crown_ring")
		var dirs: Array[int] = []
		for k in atk.windup_ticks + atk.pattern.duration_ticks():
			var before := {}
			for p in w.projectiles.size():
				before[w.projectiles.ids[p]] = true
			w.step(InputFrame.new())
			for p in _hostile(w, "crown_orb"):
				if before.has(w.projectiles.ids[p]):
					continue
				var v := Vector2(w.projectiles.vel_x[p], w.projectiles.vel_y[p])
				var at := Vector2(w.projectiles.pos_x[p], w.projectiles.pos_y[p])  # not moved yet
				var out := at - w.actors.pos(i)
				assert_almost_eq(
					Kin.length(out),
					w.actors.radius[i] + atk.pattern.radius_m + BulletPatterns.MUZZLE_M,
					0.05,
					"from her edge"
				)
				assert_eq(Kin.angle_of(v), Kin.angle_of(out), "straight out from her centre")
				assert_eq(w.projectiles.cause[p], _attack(w, &"crown_ring"), "they name the orbs")
				dirs.append(Kin.angle_of(v))
		dirs.sort()
		sets.append(dirs)
	assert_eq((sets[0] as Array).size(), 4 * 24, "four rings of 24 orbs (32 less 4 gaps of 2)")
	assert_eq(sets[0], sets[1], "the same orbs wherever the player stands")


## The angles (1/4096 turns) of wave kw's shots, sorted.
func _wave_angles(pat: BulletPatternTable, kw: int) -> Array[int]:
	var shots := BulletPatterns.wave_shots(pat, kw, Vector2.ZERO, 0, 1.75)
	var angs: Array[int] = []
	for v: Vector2 in shots[1]:
		angs.append(Kin.angle_of(v))
	angs.sort()
	return angs


## The angle steps between neighbouring shots of a wave (1/4096 turns), round the circle.
func _steps(angs: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for k in angs.size():
		var nxt := angs[(k + 1) % angs.size()] + (4096 if k == angs.size() - 1 else 0)
		out.append(nxt - angs[k])
	return out


## The clear corridor (m) between two neighbouring shots `step` apart, `r` out: the chord less a shot's width.
func _corridor(step: int, r: float, shot_r: float) -> float:
	return 2.0 * r * sin(PI * step / 4096.0) - 2.0 * shot_r


## The angles where the hero stands clear of a wave's shots `r` out (1/4096 turns).
func _clear(angs: Array[int], r: float, reach: float) -> Dictionary:
	var out := {}
	for a in 4096:
		var ok := true
		for s in angs:
			var d := absi(((a - s + 2048) & 4095) - 2048)
			if TAU * d / 4096.0 * r < reach:
				ok = false
				break
		if ok:
			out[a] = true
	return out


## The least turn (1/4096 turns) from any clear angle of one wave to any of the next.
func _least_move(c0: Dictionary, c1: Dictionary) -> int:
	var best := 4096
	for a: int in c0:
		if c1.has(a):
			return 0
		for b: int in c1:
			best = mini(best, absi(((a - b + 2048) & 4095) - 2048))
	return best


## v0.8.0 PR (O84: "3 different patters with enough space to be dodged but not easy to dodge"): three distinct
## patterns; every wave's gaps are a clear corridor of 2-3 hero widths at the usual distance, and between the gaps the
## orbs stand too close to slip through; each next wave (ring, flower) moves the gaps so the hero must step, at a
## speed under his run; the spiral's arms turn at a walk round her.
func test_the_three_orb_patterns_are_dodgeable_but_not_easy() -> void:
	var w := _prism(69)
	var t := BossAi.table_of(w, FinalLab.body(w))
	var hero := 2.0 * w.player.radius_m
	var run := w.player.move_speed * 60.0
	var kinds := {}
	for id: StringName in ORB_SPELLS:
		var pat := t.attacks[t.attack_index(id)].pattern
		assert_eq(pat.kind, ORB_SPELLS[id], "%s: its own pattern" % id)
		kinds[pat.kind] = true
		var reach := pat.radius_m + w.player.radius_m
		var slowest := pat.speed
		var prev := {}
		for kw in pat.waves:
			var angs := _wave_angles(pat, kw)
			var steps := _steps(angs)
			var least := 4096
			var gaps: Array[float] = []
			for st in steps:
				least = mini(least, st)
			for st in steps:
				var c := _corridor(st, USUAL_M, pat.radius_m)
				if st > least * 3 / 2 or pat.kind == BulletPatternTable.Kind.SPIRAL:
					gaps.append(c)
				else:
					assert_lt(c, hero, "%s wave %d: no slipping between the orbs" % [id, kw])
			assert_false(gaps.is_empty(), "%s wave %d: gaps" % [id, kw])
			for c in gaps:
				assert_gte(
					c, 2.0 * hero, "%s wave %d: a gap of 2+ hero widths (%.2f m)" % [id, kw, c]
				)
				assert_lte(c, 3.0 * hero, "%s wave %d: but not wide open (%.2f m)" % [id, kw, c])
			if kw == 0:
				var shots := BulletPatterns.wave_shots(pat, kw, Vector2.ZERO, 0, 1.75)
				for v: Vector2 in shots[1]:
					slowest = minf(slowest, Kin.length(v))
				(
					gut
					. p(
						(
							"PR gaps %s: %d gaps, corridor %.2f m at %.1f m (%.2f hero widths), %d orbs a wave"
							% [id, gaps.size(), gaps.min(), USUAL_M, gaps.min() / hero, angs.size()]
						)
					)
				)
			if pat.kind == BulletPatternTable.Kind.SPIRAL:
				continue
			var clear := _clear(angs, USUAL_M, reach)
			if kw > 0:
				var move := _least_move(prev, clear)
				var metres := TAU * move / 4096.0 * USUAL_M
				var free := pat.wave_gap_ticks / 60.0 - 2.0 * reach / (slowest * 60.0)
				var need := metres / free
				assert_gt(move, 0, "%s wave %d: the gaps move, you must step" % [id, kw])
				assert_lt(
					need, 0.7 * run, "%s wave %d: a step you make (%.2f m/s)" % [id, kw, need]
				)
				if kw == 1:
					gut.p(
						(
							"PR step %s: %.2f m in %.2f s between waves: %.2f m/s (run %.1f m/s)"
							% [id, metres, free, need, run]
						)
					)
			prev = clear
		if pat.kind == BulletPatternTable.Kind.SPIRAL:
			var along := pat.speed * 60.0 * pat.wave_gap_ticks / 60.0 - 2.0 * pat.radius_m
			assert_lt(along, hero, "the arms are solid streams")
			var ride := absf(pat.spin_milli) / 1000.0 * 60.0 * TAU / 4096.0 * USUAL_M
			assert_lt(ride, 0.7 * run, "you can walk round with the arms (%.2f m/s)" % ride)
			assert_gt(pat.reverse_ticks, 0, "and they turn back")
			gut.p("PR spiral: the arms sweep %.2f m/s at %.1f m (run %.1f)" % [ride, USUAL_M, run])
	assert_eq(kinds.size(), 3, "three different patterns")


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
	# v0.8.0 PR (O84): the rotation's open share, 0.180 (was the Cross's 0.294)
	assert_eq(FinalBoss.dps_hp_of(w, t), expect, "100 dps × 65.6 s × 0.180 window share")
	assert_eq(expect, 1181)
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
	for id: StringName in ORB_SPELLS:
		w.killer_attack = _attack(w, id)
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


# --- v0.8.0 PR (owner O84): slower, one spell at a time ----------------------------------------------------------


## "the lasers on a cross should be 15% slower": every turn of the Cross takes 1 / 0.85 as long (to the tick).
func test_the_cross_turns_15_percent_slower() -> void:
	var w := _prism(81)
	var i := FinalLab.body(w)
	var t := BossAi.table_of(w, i)
	for id: StringName in [&"cross_ring", &"cross_spiral", &"cross_flower"]:
		var a := t.attacks[t.attack_index(id)]
		assert_eq(a.quarter_ticks, roundi(OLD_QUARTER / 0.85), "%s: a quarter turn in 2.82 s" % id)
		assert_eq(a.fast_quarter_ticks, roundi(OLD_FAST / 0.85), "at no HP in 1.41 s")
		assert_eq(a.reverse_ticks, roundi(OLD_REVERSE / 0.85), "reversing after 3.53 s")
		assert_eq(a.windup_ticks, 60, "the aim lines: 1.0 s, as before")
		assert_eq(a.burn_ticks, 30, "the burn: 0.5 s, as before")
		for pair: Array in [[OLD_QUARTER, a.quarter_ticks], [OLD_FAST, a.fast_quarter_ticks]]:
			var ratio := float(pair[0]) / float(pair[1])
			assert_almost_eq(ratio, 0.85, 0.005, "%s turns at 85 %% of its old speed" % id)
	_start(w)
	_to_active(w)
	var q := BossPrism.quarter(w, i)
	assert_eq(q, roundi(OLD_QUARTER / 0.85), "full HP: the slow quarter")
	var a0 := BossPrism.angle_at(w, i, 0)
	var way := w.bosses.span[BossAi.entry_of(w, i)]
	assert_eq(
		(BossPrism.angle_at(w, i, q) - a0) & 4095, (way * 1024) & 4095, "a quarter in q ticks"
	)
	var old_step := 1024.0 / OLD_QUARTER
	var step := absf(float(((BossPrism.angle_at(w, i, 60) - a0 + 2048) & 4095) - 2048)) / 60.0
	gut.p(
		"PR cross: %.2f -> %.2f units a tick at full HP (%.3f)" % [old_step, step, step / old_step]
	)
	assert_almost_eq(step / old_step, 0.85, 0.01, "85 % of the old turn a tick")


## O84: "he shouldnt have all 3 spells at the same time, we should rotate, and never make small balls and lasers at
## the same time". A whole phase (three rotations): the spells come in the fixed order, one at a time; on every tick a
## beam is aimed (the windup's lines) or burning, no shot of hers is in the air; orbs only in an orb spell, bolts only
## in a Cross's window; and every spell begins after a gap.
func test_her_spells_rotate_one_at_a_time_and_never_overlap() -> void:
	var w := _prism(82)
	var i := FinalLab.body(w)
	var id := w.actors.ids[i]
	var b := BossAi.entry_of(w, i)
	var t := BossAi.table_of(w, i)
	w.actors.set_pos(0, Vector2(-4, 3))
	var order: Array[StringName] = []
	var starts: Array[float] = []
	var last := -1
	var beam_ticks := 0
	var quiet := 1  # ticks since the last shot of hers or beam (none before her first spell)
	for k in 3 * 3000:
		var spot := Vector2(-4, 3) if (k / 240) % 2 == 0 else Vector2(3, 4)
		w.step(FinalLab.walk(w, spot))
		i = w.actors.index_of(id)
		var atk_k := w.bosses.attack[b]
		if atk_k >= 0 and atk_k != last and w.actors.state[i] == EnemyAi.State.WINDUP:
			order.append(t.attacks[atk_k].id)
			starts.append(w.tick / 60.0)
			assert_gte(quiet, 1, "%s begins after a gap" % t.attacks[atk_k].id)
		if atk_k >= 0:
			last = atk_k
		var atk: BossAttackTable = t.attacks[atk_k] if atk_k >= 0 else null
		var s := w.actors.state[i]
		var beams := (
			atk != null
			and atk.move == BossAttackTable.Move.CROSS
			and (
				s == EnemyAi.State.WINDUP
				or (s == EnemyAi.State.ACTIVE and w.actors.state_t[i] < atk.spin_ticks)
			)
		)
		var orbs := 0
		var bolts := 0
		for p in w.projectiles.size():
			if w.projectiles.owner[p] != id:
				continue
			if w.projectiles.look[p] == "crown_orb":
				orbs += 1
			else:
				bolts += 1
		if beams:
			beam_ticks += 1
			assert_eq(
				orbs + bolts, 0, "tick %d: no shot of hers while a beam is aimed or burns" % w.tick
			)
		if orbs > 0:
			assert_true(
				atk != null and atk.move == BossAttackTable.Move.PATTERN,
				"orbs only in an orb spell"
			)
			assert_eq(bolts, 0, "never orbs and bolts together")
		quiet = 0 if beams or orbs + bolts > 0 else quiet + 1
		if order.size() > 3 * ROTATION.size():
			break
	gut.p("PR order: %s" % [order])
	gut.p("PR starts (s): %s" % [starts.map(func(x: float) -> float: return snappedf(x, 0.01))])
	assert_gt(beam_ticks, 0, "the Cross ran")
	assert_gte(order.size(), 2 * ROTATION.size(), "two rotations or more")
	for k in order.size():
		assert_eq(order[k], ROTATION[k % ROTATION.size()], "spell %d in the fixed order" % k)


## The bolts (the third spell) fire only in the window, once the beams are out.
func test_the_bolts_fire_only_in_the_window() -> void:
	var w := _prism(83)
	var i := FinalLab.body(w)
	var atk := _start(w)
	w.actors.set_pos(0, Vector2(-7, 4))
	var fired := 0
	for k in atk.windup_ticks + atk.active_ticks:
		var n := _hostile(w, "crown_bolt").size()
		var in_spin := (
			w.actors.state[i] == EnemyAi.State.WINDUP or w.actors.state_t[i] < atk.spin_ticks
		)
		if in_spin:
			assert_true(BossPrism.bolt_state(w, i).is_empty(), "no aim line while the beams turn")
		w.step(InputFrame.new())
		if _hostile(w, "crown_bolt").size() > n:
			fired += 1
			assert_true(BossPrism.in_window(w, i), "a bolt flies only in the window")
	assert_eq(fired, 2, "two bolts in each 2.5 s window")


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
	assert_eq(
		w2.state_hash(), w.state_hash(), "the Cross, its bolts and the next spell go on the same"
	)


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
