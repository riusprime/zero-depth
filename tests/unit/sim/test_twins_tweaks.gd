extends GutTest
## The Twin Wardens after the owner's playtest (PLAN rows F1-F3, F7-F9; TwinsLab: the real compiled pair in a 24 m
## walled room). The amber Warden keeps close: his close attacks only within 7 m, his ranged ones only beyond it. His
## phase-1 charge runs on its own clock at any distance, shows no lane, flashes and leads a walking hero; the
## ward-breaking charge of phase 3 runs on its own clock while the ward stands. The whole ward is cast a few seconds
## into phase 3, and while it stands he takes a quarter. The shelter Crossfire is test_twin_wardens.gd's.

const S := EnemyAi.State
const CLOSE := [&"sword_combo", &"overhead"]
const RANGED := [&"chain_sweep", &"chain_sweep_fast"]


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## Every attack body `aid` starts over `ticks` ticks, the hero put at `hero.call(w)` before each: [[tick, id], ...].
func _starts(w: World, aid: int, ticks: int, hero: Callable) -> Array:
	var out := []
	var held := false  # A hit's stop holds a wind-up's first tick: one start, counted once
	for k in ticks:
		w.actors.set_pos(0, hero.call(w))
		w.step(InputFrame.new())
		var i := _i(w, aid)
		var b := BossAi.entry_of(w, i)
		var first := w.actors.state[i] == S.WINDUP and w.actors.state_t[i] == 0
		if first and not held and w.bosses.attack[b] >= 0:
			out.append([w.tick, BossAi.table_of(w, i).attacks[w.bosses.attack[b]].id])
		held = first
	return out


func _ids(starts: Array) -> Array:
	return starts.map(func(s: Array) -> StringName: return s[1])


func _ticks_of(starts: Array, id: StringName) -> Array:
	return (
		starts
		. filter(func(s: Array) -> bool: return s[1] == id)
		. map(func(s: Array) -> int: return s[0])
	)


func test_close_attacks_up_close_ranged_ones_only_beyond_7_m() -> void:
	var s := TwinsLab.fight(Vector2(3, 0), Vector2.ZERO)
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := TwinsLab.table(w, s[1])
	for d: float in [2.0, 4.5, 6.0, 7.5, 10.0]:
		w.actors.set_pos(0, w.actors.pos(i) + Vector2(d, 0))
		for id: StringName in CLOSE + RANGED:
			var atk := t.attacks[t.attack_index(id)]
			var picked := BossTwin.may_use(w, i, atk)
			assert_eq(picked, (d <= 7.0) == CLOSE.has(id), "%s with the hero %.1f m off" % [id, d])
	# Over 20 s with the hero kept 3 m off him, then 10 m off: only the close, then only the ranged ones
	var near := _starts(
		w, s[1], 1200, func(x: World) -> Vector2: return x.actors.pos(i) + Vector2(3, 0)
	)
	var far := _starts(
		w, s[1], 1200, func(x: World) -> Vector2: return x.actors.pos(i) + Vector2(-10, 0)
	)
	var picked_near := _ids(near).filter(
		func(id: StringName) -> bool: return id != &"warden_charge"
	)
	var picked_far := _ids(far).filter(func(id: StringName) -> bool: return id != &"warden_charge")
	assert_gte(picked_near.size(), 3, "he attacks up close")
	assert_gte(picked_far.size(), 2, "and at range")
	for id: StringName in picked_near:
		assert_has(CLOSE, id, "up close")
	for id: StringName in picked_far:
		assert_has(RANGED, id, "at range")


func test_the_phase_one_charge_comes_on_its_clock_at_any_distance() -> void:
	for d: float in [2.0, 18.0]:
		var s := TwinsLab.fight(Vector2(-9.0 + d, 0), Vector2(-9, 0))
		var w: World = s[0]
		var t := TwinsLab.table(w, s[1])
		t.speed = 0.0  # He stands: the hero stays d m off until he charges
		t.punish_ticks = 0
		t.gap_ticks = 0
		var wt := t.wardens
		var hero := Vector2(-9.0 + d, 0)
		var starts := _starts(w, s[1], 60 * 50, func(_x: World) -> Vector2: return hero)
		var charges := _ticks_of(starts, &"warden_charge")
		assert_gte(charges.size(), 3, "%.0f m off: a charge every 10-15 s" % d)
		assert_between(charges[0], wt.charge_min_ticks, wt.charge_max_ticks + 200, "the first")
		for k in range(1, charges.size()):
			var gap: int = charges[k] - charges[k - 1]
			# A due charge waits for his attack in progress (at most a Sword Lane's 2.6 s)
			assert_between(gap, wt.charge_min_ticks, wt.charge_max_ticks + 160, "start to start")
		assert_false(BossTwin.may_use(w, _i(w, s[1]), t.attacks[wt.charge_attack]), "never picked")


func test_the_phase_one_charge_shows_no_lane_flashes_and_leads_a_walker() -> void:
	var s := TwinsLab.fight(Vector2(0, -6), Vector2(-8, 0))
	var w: World = s[0]
	TwinsLab.hush(w, s[1])
	var i := _i(w, s[1])
	var walk := InputFrame.make(Vector2i(0, 127), 0, 0, 0, 0)
	for k in 30:  # Up to full walking speed (6 m/s along +y)
		w.step(walk)
	BossLab.start(w, i, &"warden_charge")
	var atk := BossAi.attack_of(w, i)
	var t := TwinsLab.table(w, s[1])
	var r := WorldReader.new(w)
	var commit := atk.windup_ticks - t.commit_ticks
	var want := Vector2.ZERO
	while w.actors.state[i] == S.WINDUP:
		var tg := r.telegraph(i)
		assert_eq(tg.get("shape"), &"signature", "nothing on the ground")
		assert_false(bool(tg.get("ground", true)), "no lane")
		assert_false(tg.has("burst"), "no end circle")
		assert_true(r.boss_twin(i).has("flash"), "his body's flash is the tell")
		if w.actors.state_t[i] == commit - 1:  # The last aim before it commits
			var left := atk.windup_ticks - w.actors.state_t[i]
			var run := (w.player_pos() - w.actors.pos(i)).length() / atk.speed
			want = w.player_pos() + w.vel * (left + run)
		w.step(walk)
	assert_eq(atk.windup_ticks, 24, "0.4 s, the telegraph floor")
	var to_hero := Kin.angle_of(w.player_pos() - w.actors.pos(i))
	var led := Kin.angle_of(want - w.actors.pos(i))
	assert_lte(Kin.angle_diff(w.actors.lock_a[i], led), 24, "aimed where the walk takes the hero")
	assert_gte(Kin.angle_diff(w.actors.lock_a[i], to_hero), 60, "ahead of where they stand")
	var hp := w.actors.hp[0]
	for k in 60:
		w.step(walk)
	assert_gt(hp - w.actors.hp[0], 0, "walking on does not take the hero out of it")


func test_a_dash_across_it_avoids_the_phase_one_charge() -> void:
	var s := TwinsLab.fight(Vector2(0, -6), Vector2(-8, 0))
	var w: World = s[0]
	TwinsLab.hush(w, s[1])
	var i := _i(w, s[1])
	var walk := InputFrame.make(Vector2i(0, 127), 0, 0, 0, 0)
	for k in 30:
		w.step(walk)
	BossLab.start(w, i, &"warden_charge")
	while w.actors.state[i] == S.WINDUP:
		w.step(walk)
	var hp := w.actors.hp[0]
	# As it runs the hero dashes back across its lane, then stands
	var back := InputFrame.make(Vector2i(0, -127), 0, 0, 0, InputFrame.DASH)
	w.step(back)
	for k in 60:
		w.step(InputFrame.new())
	assert_eq(hp - w.actors.hp[0], 0, "the dash takes the hero off the lane and out of the burst")


func test_the_ward_breaking_charge_runs_on_its_clock_while_the_ward_stands() -> void:
	var s := TwinsLab.fight(Vector2(5, -6), Vector2(-9, -6))
	var w: World = s[0]
	var t := TwinsLab.table(w, s[1])
	TwinsLab.set_phase(w, s[1], 2)
	t.speed = 0.0
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.twin_bolt = -1
	var wt := t.wardens
	w.actors.set_pos(_i(w, s[2]), Vector2(0, 9))  # Off his lanes: the ward holds
	TwinsLab.raise_ward(w, s[1])
	var hero := Vector2(5, -6)
	var starts := _starts(w, s[1], 60 * 40, func(_x: World) -> Vector2: return hero)
	var charges := _ticks_of(starts, &"warden_charge_long")
	assert_true(BossWard.full(w, _i(w, s[2])), "the ward stood throughout")
	assert_gte(charges.size(), 3, "one every 10-12 s")
	for k in range(1, charges.size()):
		var gap: int = charges[k] - charges[k - 1]
		assert_between(gap, wt.ward_charge_min_ticks, wt.ward_charge_max_ticks + 160, "the clock")
	assert_eq(TwinsLab.table(w, s[1]).attacks[wt.ward_charge_attack].windup_ticks, 144, "2.4 s")
	# The ward down: no long charge at all
	w.boss_fight.wd_full = 0
	w.boss_fight.wd_ward_due = 1 << 20  # and not cast again meanwhile
	var none := _starts(w, s[1], 60 * 15, func(_x: World) -> Vector2: return hero)
	assert_eq(_ticks_of(none, &"warden_charge_long"), [], "no ward, no ward-breaking charge")


func test_the_whole_ward_is_cast_4_s_into_phase_3_and_shelters_him() -> void:
	var s := TwinsLab.fight(Vector2(6, 0), Vector2(-9, 0))
	var w: World = s[0]
	TwinsLab.hush(w, s[1])
	TwinsLab.set_phase(w, s[1], 2)
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	var wt := TwinsLab.wardens(w, s[1])
	var r := WorldReader.new(w)
	w.step(InputFrame.new())
	var first := w.tick
	assert_false(BossWard.full(w, j), "no whole ward at the phase's start")
	assert_false(r.boss_twin(i)["sheltered"])
	for e in w.bosses.exposed_t.size():
		w.bosses.exposed_t[e] = 0
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(1.5, 0))
	assert_eq(TwinsLab.hit(w, s[1], 100, w.player_pos()), 100, "before it, he takes hits as ever")
	var seq := TwinsLab.mark(w)
	var cast_at := -1
	for k in wt.ward_first_ticks + 120:
		w.step(InputFrame.new())
		if cast_at < 0 and BossWard.casting(w, j):
			cast_at = w.tick
			assert_true(r.boss_wardens()["ward"]["raising"], "the cast shows")
			assert_eq(w.actors.state[j], S.WINDUP, "she casts it")
	assert_eq(cast_at - first, wt.ward_first_ticks, "the cast starts 4 s in")
	var ups := TwinsLab.effects(w, BossWard.UP, seq)
	assert_eq(ups.size(), 1, "then it stands")
	if ups.is_empty():
		return
	var cast := TwinsLab.table(w, s[1]).attacks[wt.ward_attack]
	assert_eq(ups[0].amount_applied, 1, "the whole ward")
	assert_between(
		ups[0].tick - cast_at, cast.windup_ticks - 1, cast.windup_ticks + 1, "as the cast ends"
	)
	assert_true(BossWard.full(w, j))
	assert_true(r.boss_twin(i)["sheltered"], "he is sheltered")
	assert_false(r.boss_wardens()["ward"]["raising"])
	for e in w.bosses.exposed_t.size():
		w.bosses.exposed_t[e] = 0
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(1.5, 0))
	var seq2 := TwinsLab.mark(w)
	assert_eq(TwinsLab.hit(w, s[1], 100, w.player_pos()), 25, "a quarter while her ward stands")
	var hits := w.events_since(seq2).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.HIT and e.target_id == s[1]
	)
	assert_gt(hits.size(), 0)
	if not hits.is_empty():
		assert_true(hits[0].tags & SimEvent.TAG_ARMOURED != 0, "the dull spark")
