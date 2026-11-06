# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 BH6 (owner, 2026-10-25: "for phase 3 ... interphases ... where he dissapears ... rays, balls, and thing that
## come out of the ground ... about 15 seconds ... 6/10 difficulty ... and then he comes back"; BOSSES_HARD.md HC4-HC6):
## The Fallen vanishes at 66 % and 33 % of its HP for 15 s of one pattern set (rays, rain or Lights Out; never the same
## twice running, drawn from the `boss:interphase` stream), is untargetable with its HP and the pace frozen, slams back
## down at the arena's centre after a 1 s ring, dashes to a new spot between every two moves, and its mimic windows are
## 5.6 s. The sets' numbers, the gaps (at least 1.6 m) and the no-overlap rule are sampled.

const SEED := 811
const R := preload("res://src/sim/ai/boss_interphase.gd")


func _world(seed_value: int = SEED, held: bool = true) -> World:
	return NemesisLab.world(seed_value, &"blade", [], held, false)


func _body(w: World) -> int:
	return FinalLab.body(w)


func _ip(w: World) -> InterphaseTable:
	return R.table_of(w)


func _table(w: World) -> BossTable:
	return BossAi.table_of(w, _body(w))


## What a boss hit of `amount` takes off the hero (their armour and the held weapon's damage taken).
func _taken(w: World, amount: int) -> int:
	var taken := Stats.armour_permille(w) * PlayerBuild.taken_permille(w) / 1000
	return amount if taken == 1000 else maxi(1, (amount * taken + 500) / 1000)


## Takes the Fallen just under `permille` of its HP and steps until it has vanished (at most `limit` ticks): the ticks
## stepped, or -1.
func _vanish(w: World, permille: int, limit: int = 240) -> int:
	var i := _body(w)
	w.actors.hp[i] = maxi(1, w.actors.max_hp[i] * permille / 1000 - 1)
	for k in limit:
		w.step(InputFrame.new())
		if w.final_fight.ip_stage >= R.STAGE_VANISHED:
			return k + 1
	return -1


## Vanishes it and runs set `pick` from its first tick.
func _in_set(w: World, pick: int) -> void:
	assert_gt(_vanish(w, 660), 0, "it vanishes")
	var t := _table(w)
	R.set_up(w, t, t.interphase, w.final_fight, pick)


func _until_return(w: World, limit: int = 1200) -> int:
	for k in limit:
		if w.final_fight.ip_stage == R.STAGE_NONE:
			return k
		w.step(InputFrame.new())
	return -1


# --- data -----------------------------------------------------------------------------------------------------------


func test_the_interphase_is_data_and_obeys_the_hard_rules() -> void:
	var w := _world()
	var t := _table(w)
	var ip := t.interphase
	assert_not_null(ip)
	assert_eq(ip.thresholds, PackedInt32Array([660, 330]), "66 % and 33 % of its HP")
	assert_eq(ip.ticks, 900, "15 s")
	assert_eq(ip.finish_ticks, 60, "it finishes its move within 1 s")
	for id: StringName in [
		&"fallen_rays", &"fallen_rain", &"fallen_dark", &"fallen_erupt", &"fallen_return"
	]:
		var a := t.attacks[t.attack_index(id)]
		assert_eq(a.move, BossAttackTable.Move.INTERPHASE, "%s is a carrier" % id)
		assert_eq(a.damage, 15, "%s hits for 15" % id)
		assert_gte(a.windup_ticks, 48, "%s telegraphs at least 0.8 s" % id)
		assert_ne(a.cause_key, &"", "%s names its death" % id)
		for ph in t.phase_attacks:
			assert_false(ph.has(t.attack_index(id)), "%s is never picked" % id)
	assert_eq(t.attacks[ip.atk_return].windup_ticks, 60, "the return shows 1 s")
	assert_eq(ip.slam_m, 2.5)
	assert_eq(t.window_ticks, 336, "HC6: the mimic windows are 5.6 s (7 s less 20 %)")
	assert_eq(t.window_every_ticks, 1200, "one every 20 s still")
	assert_eq(ip.dash_telegraph_ticks, 24, "the dash's line shows 0.4 s")
	assert_eq([ip.dash_min_m, ip.dash_max_m, ip.dash_wall_m], [6.0, 9.0, 3.0])
	assert_true(ip.grace_ticks >= 30, "no two interphase hits within 0.5 s")


func test_bad_interphase_numbers_are_refused() -> void:
	var repo := ContentRepository.load_all()
	var d: FinalBossDefinition = repo.get_def(&"final_bosses", &"nemesis").duplicate()
	assert_eq(d.validate().size(), 0, "the shipped data is clean")
	for bad: Array in [
		["seconds", 2.0],
		["beam_count", 9],
		["spike_length_m", 1.0],
		["dash_min_m", 30.0],
		["nope", 1]
	]:
		var e: FinalBossDefinition = d.duplicate()
		e.interphase = d.interphase.duplicate()
		e.interphase[bad[0]] = bad[1]
		assert_gt(e.validate().size(), 0, "%s = %s is refused" % [bad[0], bad[1]])
	var swapped: FinalBossDefinition = d.duplicate()
	swapped.interphase = d.interphase.duplicate()
	swapped.interphase["second_permille"] = 700
	assert_gt(swapped.validate().size(), 0, "the thresholds fall in order")
	var quick: FinalBossDefinition = d.duplicate()
	quick.attacks = d.attacks.duplicate()
	var carrier: BossAttackDefinition = d.attacks[d.attacks.size() - 2].duplicate()
	carrier.telegraph_seconds = 0.5
	quick.attacks[quick.attacks.size() - 2] = carrier
	assert_gt(quick.validate().size(), 0, "an interphase telegraph under 0.8 s is refused")


# --- the thresholds -------------------------------------------------------------------------------------------------


func test_the_two_thresholds_trigger_once_each() -> void:
	var w := _world()
	var f := w.final_fight
	var i := _body(w)
	assert_eq(f.ip_done, 0)
	for k in 200:
		w.step(InputFrame.new())
	assert_eq(f.ip_stage, R.STAGE_NONE, "full HP: no interphase")
	var n := _vanish(w, 660)
	assert_between(n, 1, 62, "it finishes its move (at most 1 s) and vanishes")
	assert_eq(f.ip_done, 1, "the first")
	assert_eq(w.actors.state[i], R.STATE)
	assert_eq(
		_until_return(w),
		959,
		"15 s then the 1 s ring (the vanish tick is the first), then it is back"
	)
	assert_eq(f.ip_stage, R.STAGE_NONE)
	assert_eq(f.ip_done, 1)
	for k in 400:
		w.step(InputFrame.new())
	assert_eq(f.ip_done, 1, "the first never comes twice (HP still 66 %)")
	assert_gt(_vanish(w, 330, 400), 0, "the second at 33 % (after the 5 s between)")
	assert_eq(f.ip_done, 3)
	_until_return(w)
	w.actors.hp[i] = 5
	for k in 700:
		w.step(InputFrame.new())
	assert_eq(f.ip_done, 3, "no third")
	assert_eq(f.ip_stage, R.STAGE_NONE)


func test_a_move_in_progress_is_cut_after_a_second() -> void:
	var w := _world()
	var i := _body(w)
	NemesisLab.start(w, &"nemesis_card_3")  # a 1 s windup, a 0.7 s recovery: longer than the allowance
	w.actors.cd[i] = 1 << 20
	var n := _vanish(w, 660)
	assert_between(n, 1, 61, "vanished within 1 s of reaching the threshold")
	assert_eq(w.bosses.attack[BossAi.entry_of(w, i)], -1, "its move is cut")


# --- untargetable, frozen, paused -----------------------------------------------------------------------------------


func test_vanished_it_cannot_be_hurt_or_seen_and_its_hp_and_pace_are_frozen() -> void:
	var w := _world()
	var f := w.final_fight
	var i := _body(w)
	assert_gt(_vanish(w, 660), 0)
	var hp := w.actors.hp[i]
	var budget := f.pace_budget
	var dps_t := f.dps_t
	var pid := w.actors.ids[0]
	var r := WorldReader.new(w)
	for k in 300:
		w.step(InputFrame.new())
		Damage.hit(w, i, 500, pid, pid, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i))
		w.actors.invuln[i] = 0 if k == 7 else w.actors.invuln[i]  # even uncovered, the clamp holds it
		assert_eq(w.actors.hp[i], hp, "tick %d: HP frozen" % k)
	assert_true(BossAi.hidden(w, i), "not drawn")
	assert_true(r.boss_invulnerable(i))
	assert_eq(FinalPace.window(w), FinalPace.Mimic.OFF, "no mimic window while it is gone")
	assert_eq(f.pace_budget, budget, "the rate cap's bucket does not fill")
	assert_eq(f.dps_t, dps_t, "the damage meter's second does not run")
	assert_eq(f.ip_total, 301, "its ticks are counted for the pace's clock")


func test_the_interphase_does_not_move_the_mimic_windows() -> void:
	var w := _world()
	var f := w.final_fight
	for k in 600:
		w.step(InputFrame.new())
	assert_gt(_vanish(w, 660), 0)
	var before := FinalPace.window_clock(w)
	_until_return(w)
	var after := FinalPace.window_clock(w)
	assert_eq(after[1], before[1], "the same window state as when it left (%s)" % [before])
	assert_between(
		after[0] - before[0], -3, 3, "and the same time left in it (%s, %s)" % [before, after]
	)
	assert_gt(f.ip_total, 900)


func test_windows_are_5_6_seconds_every_20() -> void:
	var w := _world()
	var on := 0
	var starts := []
	var was := FinalPace.Mimic.OFF
	for k in 2800:
		w.step(InputFrame.new())
		var now := FinalPace.window(w)
		if now == FinalPace.Mimic.ON:
			on += 1
		if now == FinalPace.Mimic.ON and was != FinalPace.Mimic.ON:
			starts.append(w.tick)
		was = now
	assert_eq(starts.size(), 2, "two windows in 46 s")
	assert_eq(starts[1] - starts[0], 1200, "20 s apart")
	assert_eq(on, 2 * 336, "each 336 ticks: 5.6 s")


# --- the draw -------------------------------------------------------------------------------------------------------


func _sets(seed_value: int) -> Array:
	var w := _world(seed_value)
	var out := []
	assert_gt(_vanish(w, 660), 0)
	out.append(w.final_fight.ip_set)
	_until_return(w)
	assert_gt(_vanish(w, 330, 400), 0)
	out.append(w.final_fight.ip_set)
	return out


func test_sets_never_repeat_and_follow_the_seed() -> void:
	var seen := {}
	for s in range(900, 912):
		var a := _sets(s)
		assert_ne(a[0], a[1], "seed %d: the second set is another (%s)" % [s, a])
		assert_eq(_sets(s), a, "seed %d: the same draw again" % s)
		seen[a[0]] = true
	assert_eq(seen.size(), 3, "all three sets come first for some seed")


# --- rays -----------------------------------------------------------------------------------------------------------


func test_rays_are_three_slow_beams_and_an_eruption_every_2_seconds() -> void:
	var w := _world()
	_in_set(w, R.SET_RAYS)
	var f := w.final_fight
	var ip := _ip(w)
	var t := _table(w)
	var r := WorldReader.new(w)
	w.actors.set_pos(0, f.home + Vector2(2.0, 1.0))
	var first := r.final_interphase()
	assert_eq((first["beams"] as Array).size(), 3, "three beams")
	assert_almost_eq(float(first["beams"][0]["half"]) * 2.0, 0.6, 0.001, "0.6 m wide")
	assert_false(bool(first["beams"][0]["live"]), "shown still first")
	assert_almost_eq(float(first["beams"][0]["len"]), f.ip_r, 0.01, "from the centre to the edge")
	var spawns := []
	var strikes := []
	var seen := {}
	var a0 := -1
	var a1 := -1
	for k in 900:
		w.step(InputFrame.new())
		if k == 47:
			a0 = (r.final_interphase()["beams"][0]["angle"] as int)
		if k == 107:
			a1 = (r.final_interphase()["beams"][0]["angle"] as int)
		for j in f.er_t.size():
			if not seen.has(f.er_t[j]):
				seen[f.er_t[j]] = true
				spawns.append(w.tick - 1)
				strikes.append(f.er_t[j])
	assert_eq(t.attacks[ip.atk_rays].windup_ticks, 48)
	var turned := absi(((a1 - a0 + 6144) & 4095) - 2048)
	assert_between(turned, 280, 290, "25 degrees a second: %d / 4096 of a turn in 1 s" % turned)
	assert_gte(strikes.size(), 6, "an eruption about every 2 s: %d" % strikes.size())
	for k in strikes.size():
		assert_eq(strikes[k] - spawns[k], t.attacks[ip.atk_erupt].windup_ticks, "0.8 s telegraph")
		if k > 0:
			assert_between(strikes[k] - strikes[k - 1], 120, 150, "2 s apart (6 ticks a retry)")
	assert_almost_eq(ip.erupt_m, 1.4, 0.001)


func test_a_beam_and_an_eruption_hit_for_15_once_a_grace() -> void:
	var w := _world(SEED, false)
	_in_set(w, R.SET_RAYS)
	var f := w.final_fight
	var ip := _ip(w)
	var i := _body(w)
	var t := _table(w)
	for k in 48:
		w.step(InputFrame.new())
	var hp0 := w.actors.hp[0]
	var box := R.beam_obb(ip, f, t, 0, f.ip_t)
	w.actors.set_pos(0, f.home + Kin.dir(box.angle) * 5.0)
	w.step(InputFrame.new())
	var dmg := _taken(w, BossAi.powered(w, i, 15))
	assert_eq(hp0 - w.actors.hp[0], dmg, "a beam takes 15 (x the boss's power, the hero's armour)")
	hp0 = w.actors.hp[0]
	var j := 0
	while j < 10:  # standing on, it cannot hit again within the grace
		w.actors.set_pos(0, f.home + Kin.dir(R.beam_angle(ip, f, t, 0, f.ip_t)) * 5.0)
		w.step(InputFrame.new())
		j += 1
	assert_eq(hp0 - w.actors.hp[0], 0, "no second hit inside 0.5 s")
	assert_eq(f.ip_grace - w.tick > 0, true)


# --- rain -----------------------------------------------------------------------------------------------------------


func test_rain_rings_leave_alternate_pairs_every_1_2_seconds() -> void:
	var w := _world()
	_in_set(w, R.SET_RAIN)
	var f := w.final_fight
	R._clear_hazards(f)  # (the spike lines keep balls out of their way: tested below)
	var ip := _ip(w)
	w.actors.set_pos(0, f.home + Vector2(0.5, 0.5))
	var rings := []
	for k in 400:
		var before := w.projectiles.size()
		w.step(InputFrame.new())
		var n := NemesisLab.shots(w, R.BALL_LOOK).size()
		if f.ip_t == 49 or f.ip_t == 121 or f.ip_t == 193:
			rings.append(n)
	assert_eq(ip.rain_balls, 16)
	assert_eq(ip.rain_gap_slots, 3)
	assert_almost_eq(ip.rain_speed * 60.0, 2.8, 0.001, "2.8 m/s")
	assert_eq(R.ring_pair(0), [0, 2] as Array[int], "north and south, then")
	assert_eq(R.ring_pair(1), [1, 3] as Array[int], "east and west")
	assert_eq(R.gap_slots(ip, 0).size(), 6, "two gaps of three")
	var first_at := ip.rain_ticks
	assert_eq(first_at, 72, "a ring every 1.2 s")
	assert_eq(rings.size(), 3)
	assert_eq(rings[0], 20, "two points fire 10 balls each (16 slots less two gaps of 3)")
	assert_gt(rings[1], rings[0], "the next pair adds its own")


func test_no_ball_is_fired_into_a_spike_line() -> void:
	var w := _world()
	_in_set(w, R.SET_RAIN)
	var f := w.final_fight
	var ip := _ip(w)
	R._clear_hazards(f)
	# one line walking +x from the west, 10 m long across the middle, starting to move at tick 100
	f.sl_x.append(f.home.x - 10.0)
	f.sl_y.append(f.home.y)
	f.sl_a.append(0)
	f.sl_t.append(100)
	f.sl_len.append(ip.spike_len_m)
	f.sl_off.append(0.0)
	f.sl_hit.append(0)
	var at := f.home + Vector2(0.0, 9.0)
	var into := Vector2(0.0, -ip.rain_speed)  # straight down through the middle of the line's length
	assert_true(
		R.crosses_line(60, f, ip, at, into, 0.3, 500), "a ball that will cross it is held back"
	)
	assert_false(R.crosses_line(60, f, ip, at, -into, 0.3, 500), "one flying away is not")
	var aside := f.home + Vector2(12.0, 9.0)  # the line reaches x = 12 after the ball has left its band
	assert_false(
		R.crosses_line(60, f, ip, aside, into, 0.3, 500),
		"nor one that is out of its band when the line comes"
	)
	var late := R.crosses_line(2000, f, ip, at, into, 0.3, 500)
	assert_false(late, "nor one fired when the line is long gone")


func test_rain_gaps_are_wide_and_spike_lines_walk() -> void:
	var w := _world()
	_in_set(w, R.SET_RAIN)
	var f := w.final_fight
	var ip := _ip(w)
	var t := _table(w)
	assert_almost_eq(ip.spike_half_m * 2.0, 1.0, 0.001, "1 m wide")
	assert_almost_eq(ip.spike_speed * 60.0, 4.0, 0.001, "4 m/s")
	assert_gte(ip.spike_len_m, 4.0)
	w.actors.set_pos(0, f.home + Vector2(0.0, 0.0))
	var started := []
	var walk0 := Vector2.ZERO
	var walk1 := Vector2.ZERO
	var tw: int = t.attacks[ip.atk_rain].windup_ticks
	for j in f.sl_t.size():  # the lines are all drawn at the set's start (no ball is fired into one)
		started.append([f.sl_t[j] - tw, f.sl_t[j]])
	for k in 700:
		w.step(InputFrame.new())
		if f.sl_t.size() > 0 and w.tick == f.sl_t[0] + 30:
			walk0 = R.line_boxes(ip, f, 0, R.line_walked(ip, f, 0, w.tick))[0].center
		if f.sl_t.size() > 0 and w.tick == f.sl_t[0] + 90:
			walk1 = R.line_boxes(ip, f, 0, R.line_walked(ip, f, 0, w.tick))[0].center
	assert_gte(
		started.size(),
		2,
		"a line about every 3 s (one only starts if it can cross before the 15 s end)"
	)
	assert_eq(started[0][1] - started[0][0], t.attacks[ip.atk_rain].windup_ticks, "0.8 s telegraph")
	assert_between(walk0.distance_to(walk1), 3.9, 4.1, "4 m in 1 s: 4 m/s")
	for k in range(1, started.size()):
		assert_between(started[k][0] - started[k - 1][0], 180, 190, "3 s apart")


# --- lights out -----------------------------------------------------------------------------------------------------


func test_lights_out_is_the_shades_dark_with_slow_balls_and_eruptions() -> void:
	var w := _world()
	_in_set(w, R.SET_DARK)
	var f := w.final_fight
	var ip := _ip(w)
	var r := WorldReader.new(w)
	w.actors.set_pos(0, f.home)
	w.step(InputFrame.new())
	var l := r.boss_light()
	assert_true(bool(l["dark"]), "the room is dark")
	assert_eq((l["lamps"] as Array).size(), 4, "four lanterns")
	assert_almost_eq(float(l["light_m"]), 3.5, 0.001, "your light")
	assert_almost_eq(float(l["lamp_m"]), 3.0, 0.001, "a lantern's")
	assert_true(R.lit(w, w.player_pos()), "lit where you stand")
	assert_false(R.lit(w, f.home + Vector2(5.5, 0.0)), "dark beyond 3.5 m")
	var lamp0: Vector2 = l["lamps"][0]["pos"]
	assert_true(R.lit(w, lamp0), "lit at a lit lantern")
	var most := 0
	var strikes := {}
	for k in 880:
		w.step(InputFrame.new())
		var n := NemesisLab.shots(w, R.BALL_LOOK).size()
		most = maxi(most, n)
		for s in f.er_t:
			strikes[s] = true
	assert_lte(most, ip.dark_balls, "never more than six drifting balls")
	assert_gte(most, 4, "and they do come (%d)" % most)
	assert_almost_eq(ip.dark_ball_speed * 60.0, 1.6, 0.001, "1.6 m/s")
	assert_gte(strikes.size(), 4, "an eruption about every 2.5 s")
	f.lamp_t[0] = 0
	w.actors.set_pos(0, lamp0)
	w.step(InputFrame.new())
	assert_eq(f.lamp_t[0], ip.lamp_ticks, "walking up to a lantern relights it")


# --- fair: gaps and overlaps, sampled -------------------------------------------------------------------------------


## Distance from p to the edge of a disc ["disc", centre, radius] or a box ["obb", Obb] (0 inside).
func _dist(p: Vector2, z: Array) -> float:
	if z[0] == "disc":
		return maxf(0.0, p.distance_to(z[1]) - float(z[2]))
	var o: Obb = z[1]
	var d := p - o.center
	var q := Vector2(absf(d.dot(o.axis_u)) - o.half.x, absf(d.dot(o.axis_v)) - o.half.y)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()


## The damage zones standing in the arena now: [class, shape...] (a live beam, an eruption from its telegraph to its
## burst, a walking line's boxes, a ball, the return ring).
func _zones(w: World) -> Array:
	var f := w.final_fight
	var ip := _ip(w)
	var t := _table(w)
	var out := []
	if f.ip_stage == R.STAGE_RETURN:
		out.append(["slam", ["disc", f.home, ip.slam_m]])
		return out
	if f.ip_set == R.SET_RAYS and f.ip_t >= t.attacks[ip.atk_rays].windup_ticks:
		for j in ip.beam_count:
			out.append(["beam", ["obb", R.beam_obb(ip, f, t, j, f.ip_t)]])
	for j in f.er_t.size():
		out.append(["erupt", ["disc", Vector2(f.er_x[j], f.er_y[j]), ip.erupt_m]])
	for j in f.sl_t.size():
		if w.tick >= f.sl_t[j]:
			for box in R.line_boxes(ip, f, j, R.line_walked(ip, f, j, w.tick)):
				out.append(["line", ["obb", box]])
	for k in w.projectiles.size():
		if w.projectiles.team[k] != ActorStore.TEAM_PLAYER:
			var c := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
			out.append(["ball", ["disc", c, w.projectiles.radius[k]]])
	return out


## Runs set `pick` for its 15 s and the return with the hero walking a slow circle; samples every 15 ticks: the widest
## free circle in the arena (the gap, m), and every pair of different damage zones overlapping where the eruption's
## 0.5 s round its strike counts. Returns [least widest-gap (m), beam x eruption overlaps, ball x eruption overlaps,
## ball x line overlaps, samples].
func _sample(seed_value: int, pick: int) -> Array:
	var w := _world(seed_value)
	_in_set(w, pick)
	var f := w.final_fight
	var least := 99.0
	var be := 0
	var bae := 0
	var bl := 0
	var n := 0
	var k := 0
	while f.ip_stage >= R.STAGE_VANISHED and k < 1100:
		var ang := k * 3
		w.step(FinalLab.walk(w, f.home + Vector2(4.0, 0.0).rotated(ang * TAU / 4096.0 * 0.5)))
		k += 1
		var zones := _zones(w)
		var win := []
		for j in f.er_t.size():
			win.append(absi(w.tick - f.er_t[j]) <= R.OVERLAP_TICKS)
		var strikes := _strike_zones(w, zones)
		for a in strikes:
			for b in strikes:
				if a[0] == "erupt" and b[0] == "beam" and _hits(a[1], b[1]):
					be += 1
				if a[0] == "erupt" and b[0] == "ball" and _hits(a[1], b[1]):
					bae += 1
				if a[0] == "line" and b[0] == "ball" and _hits(a[1], b[1]):
					bl += 1
		if k % 15 == 0:
			n += 1
			least = minf(least, _widest_gap(w, zones))
	return [least, be, bae, bl, n]


## `zones` with the eruptions kept only inside their 0.5 s round the strike.
func _strike_zones(w: World, zones: Array) -> Array:
	var f := w.final_fight
	var out := []
	var e := 0
	for z in zones:
		if z[0] != "erupt":
			out.append(z)
			continue
		if absi(w.tick - f.er_t[e]) <= R.OVERLAP_TICKS:
			out.append(z)
		e += 1
	return out


func _hits(a: Array, b: Array) -> bool:
	if a[0] == "disc" and b[0] == "disc":
		return a[1].distance_to(b[1]) < float(a[2]) + float(b[2])
	if a[0] == "disc":
		return _dist(a[1], b) < float(a[2])
	if b[0] == "disc":
		return _dist(b[1], a) < float(b[2])
	return false


## The radius of the widest circle that fits between the arena's wall and every zone (searched on a 1 m grid).
func _widest_gap(w: World, zones: Array) -> float:
	var f := w.final_fight
	var best := 0.0
	var x := -f.ip_r
	while x <= f.ip_r:
		var y := -f.ip_r
		while y <= f.ip_r:
			var p := f.home + Vector2(x, y)
			var room := f.ip_r - p.distance_to(f.home)
			if room > 0.0:
				var c := room
				for z in zones:
					c = minf(c, _dist(p, z[1]))
					if c <= best:
						break
				best = maxf(best, c)
			y += 1.0
		x += 1.0
	return best


func test_every_set_always_leaves_a_gap_of_1_6_m_and_stacks_nothing() -> void:
	var rows := []
	for pick in [R.SET_RAYS, R.SET_RAIN, R.SET_DARK]:
		var least := 99.0
		var be := 0
		var bae := 0
		var bl := 0
		for s in [821, 822]:
			var r := _sample(s, pick)
			least = minf(least, r[0])
			be += r[1]
			bae += r[2]
			bl += r[3]
		rows.append([pick, snappedf(least * 2.0, 0.01), be, bae, bl])
		assert_gte(
			least * 2.0,
			1.6,
			"set %d: a gap of at least 1.6 m always (%.2f m)" % [pick, least * 2.0]
		)
		assert_eq(be, 0, "set %d: no eruption within 0.5 s of a beam on the same spot" % pick)
		assert_eq(bae, 0, "set %d: no ball on an eruption within 0.5 s of its strike" % pick)
		assert_eq(bl, 0, "set %d: no ball on a spike line standing there" % pick)
	(
		gut
		. p(
			(
				"BH6 sampled [set, narrowest widest-gap (m), beam x eruption, ball x eruption, ball x line]: %s"
				% [rows]
			)
		)
	)


# --- the return -----------------------------------------------------------------------------------------------------


func test_it_slams_back_down_in_the_centre_after_a_one_second_ring() -> void:
	var w := _world(SEED, true)
	_in_set(w, R.SET_RAYS)
	var f := w.final_fight
	var i := _body(w)
	var ip := _ip(w)
	var r := WorldReader.new(w)
	for k in 900:
		w.step(FinalLab.walk(w, f.home + Vector2(10.0, 0.0)))
	w.actors.invuln[0] = 0
	assert_eq(f.ip_stage, R.STAGE_RETURN, "the ring")
	var ret: Dictionary = r.final_interphase()["ret"]
	assert_eq(ret["center"], f.home)
	assert_almost_eq(float(ret["radius"]), 2.5, 0.001)
	assert_eq(w.projectiles.size(), 0, "the shots are gone")
	assert_true(r.final_interphase()["beams"].is_empty(), "and the beams")
	w.actors.set_pos(0, f.home + Vector2(1.5, 0.0))  # inside the slam
	var hp0 := w.actors.hp[0]
	for k in 59:
		assert_eq(f.ip_stage, R.STAGE_RETURN, "tick %d" % k)
		w.actors.set_pos(0, f.home + Vector2(1.5, 0.0))
		w.step(InputFrame.new())
	assert_eq(hp0, w.actors.hp[0], "not hurt before the slam")
	w.actors.set_pos(0, f.home + Vector2(1.5, 0.0))
	w.step(InputFrame.new())
	assert_eq(f.ip_stage, R.STAGE_NONE, "it is back")
	assert_eq(hp0 - w.actors.hp[0], _taken(w, BossAi.powered(w, i, 15)), "the slam took 15")
	assert_eq(w.actors.pos(i), f.home, "in the centre")
	assert_eq(w.actors.state[i], EnemyAi.State.MOVE)
	assert_eq(w.actors.invuln[i], 0, "and can be hurt")
	assert_false(BossAi.hidden(w, i))
	assert_eq(ip.slam_m, 2.5)
	var w2 := _world(SEED, true)
	_in_set(w2, R.SET_RAYS)
	for k in 899:
		w2.step(FinalLab.walk(w2, w2.final_fight.home + Vector2(5.0, 0.0)))
	w2.actors.invuln[0] = 0
	var hp2 := w2.actors.hp[0]
	for k in 61:
		w2.actors.set_pos(0, w2.final_fight.home + Vector2(4.0, 0.0))
		w2.step(InputFrame.new())
	assert_eq(w2.final_fight.ip_stage, R.STAGE_NONE)
	assert_eq(w2.actors.hp[0], hp2, "a hero outside the ring is not hurt by the slam")


# --- the dash between moves -----------------------------------------------------------------------------------------


func test_it_dashes_to_a_new_spot_between_every_two_moves() -> void:
	var w := _world(831)
	var f := w.final_fight
	var i := _body(w)
	var ip := _ip(w)
	var dashes := []
	var moves := 0
	var last_attack := -1
	var line_t := 0
	var from := Vector2.ZERO
	var walk := [Vector2(4, 3), Vector2(-4, 2), Vector2(2, -5), Vector2(-3, -3)]
	var telegraphs := 0
	for k in 3000:
		w.step(FinalLab.walk(w, f.home + walk[(k / 150) % 4]))
		var b := BossAi.entry_of(w, i)
		var atk := w.bosses.attack[b]
		if atk >= 0 and last_attack < 0:
			moves += 1
		last_attack = atk
		if f.rd_t > 0:
			telegraphs += 1
			if line_t == 0:
				from = w.actors.pos(i)
			line_t += 1
			assert_eq(w.actors.pos(i), from, "it stands still while the line shows")
		elif line_t > 0:
			dashes.append([from, f.rd_to, line_t])
			line_t = 0
	gut.p("BH6 dash: %d moves, %d dashes" % [moves, dashes.size()])
	assert_gte(dashes.size(), moves * 8 / 10, "a dash between (nearly) every two moves")
	assert_gte(dashes.size(), 8)
	var hero := Vector2.ZERO
	for d in dashes:
		assert_eq(d[2], 24, "0.4 s telegraph")
		var len := (d[0] as Vector2).distance_to(d[1])
		assert_between(len, 6.0 - 0.01, 9.0 + 0.01, "6 to 9 m")
		for dir in 8:
			var run := EnemyAi.clear_run(w, d[1], dir * 512, ip.dash_wall_m, 0.5)
			assert_gte(run, ip.dash_wall_m - 0.02, "ends at least 3 m from walls")


func test_a_dash_never_passes_through_the_hero() -> void:
	var w := _world(832)
	var i := _body(w)
	var ip := _ip(w)
	var tries := 0
	for k in 300:
		var hero := w.final_fight.home + Vector2(sin(k * 0.7) * 5.0, cos(k * 1.3) * 5.0)
		w.actors.set_pos(0, hero)
		var at := w.actors.pos(i)
		var to := BossNemesis.reposition_spot(w, i, ip)
		if to.x > 1.0e8:
			continue
		tries += 1
		var d := BossNemesis.segment_distance(hero, at, to)
		assert_gt(d, w.actors.radius[i] + w.player.radius_m, "try %d: the line misses the hero" % k)
		w.actors.set_pos(i, w.final_fight.home + Vector2(cos(k * 0.9), sin(k * 0.9)) * 6.0)
	assert_gt(tries, 200)


# --- saves ----------------------------------------------------------------------------------------------------------


func test_a_snapshot_mid_interphase_round_trips_and_runs_on_the_same() -> void:
	for pick in [R.SET_RAYS, R.SET_RAIN, R.SET_DARK]:
		var run := FinalLab.run_state(841, &"blade")
		var w := FinalLab.arena(run)
		w.actors.invuln[0] = NemesisLab.LONG
		FinalLab.past_rise(w)
		FinalBoss.jump(w, 2)
		FinalLab.past_rise(w)
		_in_set(w, pick)
		for k in 300:
			w.step(FinalLab.walk(w, w.final_fight.home + Vector2(3, 2)))
		var snap := w.to_snapshot()
		var w2 := FinalLab.arena(run, false)
		assert_eq(WorldSnapshot.apply(w2, snap), "", "set %d restores" % pick)
		assert_eq(w2.state_hash(), w.state_hash(), "set %d: the same hash" % pick)
		assert_eq(w2.final_fight.ip_set, pick)
		for k in 700:
			var fr := FinalLab.walk(w, w.final_fight.home + Vector2(-3, 1))
			w.step(fr)
			w2.step(fr)
		assert_eq(w2.state_hash(), w.state_hash(), "set %d: the same interphase to its end" % pick)
		assert_eq(w2.final_fight.ip_stage, w.final_fight.ip_stage)


func test_an_older_save_without_interphase_state_loads_and_keeps_fighting() -> void:
	var run := FinalLab.run_state(842, &"blade")
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = NemesisLab.LONG
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 2)
	FinalLab.past_rise(w)
	for k in 100:
		w.step(InputFrame.new())
	var snap := w.to_snapshot()
	var ff: Dictionary = snap["world"][&"final_fight"]
	for key: StringName in WorldSnapshot.ADDED_SINCE_V05[&"FinalFight"]:
		if (key as String).begins_with("ip_") or (key as String).begins_with("rd_"):
			ff.erase(key)
		elif key in [&"er_x", &"er_y", &"er_t", &"sl_x", &"sl_y", &"sl_a", &"sl_t", &"sl_len"]:
			ff.erase(key)
		elif key in [&"sl_off", &"sl_hit", &"lamp_t"]:
			ff.erase(key)
	var w2 := FinalLab.arena(run, false)
	assert_eq(WorldSnapshot.apply(w2, snap), "", "an older save loads")
	assert_eq(w2.final_fight.ip_done, 0)
	assert_eq(w2.final_fight.ip_stage, 0)
	for k in 200:
		w2.step(InputFrame.new())
	assert_eq(w2.final_fight.ip_done, 0, "and fights on")


func test_an_unused_fight_hashes_as_it_did() -> void:
	var f := FinalFight.new()
	var h1 := StateHasher.new()
	f.hash_into(h1)
	var g := FinalFight.new()
	var h0 := StateHasher.new()
	g.hash_into(h0)
	var none := h1.finish_hex()
	assert_eq(h0.finish_hex(), none, "a fight with none hashes the same")
	g.ip_done = 1
	var h2 := StateHasher.new()
	g.hash_into(h2)
	assert_ne(h2.finish_hex(), none, "an interphase that has happened is in the hash")


# --- death names the cause ------------------------------------------------------------------------------------------


func test_each_new_hit_names_its_death() -> void:
	var w := _world()
	var t := _table(w)
	for pair: Array in [
		[&"fallen_rays", &"CAUSE_FALLEN_RAYS"],
		[&"fallen_rain", &"CAUSE_FALLEN_RAIN"],
		[&"fallen_dark", &"CAUSE_FALLEN_DARK"],
		[&"fallen_erupt", &"CAUSE_FALLEN_ERUPTION"],
		[&"fallen_return", &"CAUSE_FALLEN_RETURN"],
	]:
		var k := t.attack_index(pair[0])
		w.killer_kind = w.actors.kinds[_body(w)]
		w.killer_attack = k
		assert_eq(BossAi.cause_key(w), pair[1])
		for lang in ["en", "es"]:
			assert_ne(
				TranslationServer.get_translation_object(lang).get_message(pair[1]),
				"",
				"%s has %s text" % [pair[1], lang]
			)
