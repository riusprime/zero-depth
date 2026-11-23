# gdlint: disable=max-public-methods
extends GutTest
## The Warlord's faster charge, War Banner and Duel (BossWarlord, BossDuel), in WarlordLab's walled 24 m room: the
## charge's timings and its burst; the banner's clock, its two shares by who stands inside, its fall to a charge
## through its pole and to its time; the cage's clamp for the hero and the Warlord, its tick-exact closing, the fence's
## hit and lockout, the shield down only in it, the attacks allowed in it, the recall's warning and hit, the cage
## always inside the room over seeds; one big mechanic at a time with the great javelin; what ends with the fight;
## determinism and a save.

const S := EnemyAi.State
## The fence closes this much in a tick (and a read after a step describes the next tick), with a float's slack.
const ONE_TICK_M := 4.0 / 720.0 + 0.001


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _fx(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return WarlordLab.effects(w, effect, seq)


## A hit of `amount` from the hero on boss i from `from`: the DAMAGE's amount (0 none).
func _hero_hit(w: World, i: int, amount: int, from: Vector2) -> int:
	var seq := w.last_event_seq()
	var hero := w.actors.ids[0]
	w.actors.invuln[i] = 0
	Damage.hit(
		w, i, amount, hero, hero, w.take_root(), SimEvent.TAG_PROJECTILE, from, w.actors.pos(i)
	)
	for e in w.events_since(seq):
		if e.target_id == w.actors.ids[i] and e.kind == SimEvent.Kind.DAMAGE:
			return e.amount
	return 0


# --- content ------------------------------------------------------------------------------------------------------


func test_the_data_is_valid_and_compiles_to_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"warlord")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	var dash := t.attacks[t.attack_index(&"lunge_dash")]
	assert_eq([dash.windup_ticks, dash.lock_ticks, dash.burst_ticks], [36, 24, 15], "0.6 s, 0.4 s")
	assert_almost_eq(dash.speed, 26.0 / 60.0, 0.0001, "26 m/s")
	assert_almost_eq(dash.length_m, 16.0, 0.0001, "over the same 16 m")
	assert_almost_eq(dash.burst_radius_m, 3.5, 0.0001, "a 3.5 m burst")
	assert_true(dash.opens_weak, "the weak point after it stays")
	var wt := t.warlord
	assert_not_null(wt)
	assert_eq(
		[wt.banner_phase, wt.banner_first_ticks, wt.banner_gap_ticks, wt.banner_cast_ticks],
		[1, 480, 720, 60],
		"the banner's clock"
	)
	assert_eq([wt.banner_ticks, wt.banner_cooldown, wt.banner_damage], [1200, 700, 1400])
	assert_almost_eq(wt.banner_radius_m, 6.0, 0.0001)
	assert_almost_eq(wt.banner_pole_m, 0.8, 0.0001)
	assert_eq(
		[wt.duel_phase, wt.duel_first_ticks, wt.duel_gap_ticks, wt.duel_cast_ticks, wt.duel_ticks],
		[2, 480, 1500, 72, 720],
		"the duel's clock"
	)
	assert_almost_eq(wt.duel_radius_m, 9.0, 0.0001)
	assert_almost_eq(wt.duel_end_radius_m, 5.0, 0.0001)
	assert_eq(
		[wt.fence_hit, wt.fence_every_ticks, wt.recall_warn_ticks, wt.recall_hit],
		[100, 36, 60, 400]
	)
	var allowed := []
	for k in wt.duel_attacks:
		allowed.append(t.attacks[k].id)
	assert_eq(allowed, [&"shield_bash", &"lunge_dash", &"spear_lines"], "the duel's attacks")
	assert_eq(t.attacks[wt.fence_cause].cause_key, &"CAUSE_WARLORD_FAN", "the fence's recap line")
	assert_eq(BossSignatures.late_cause_key(t, wt.recall_cause), &"CAUSE_WARLORD_RECALL")
	assert_null(ContentCompiler.compile_boss(repo.get_def(&"bosses", &"foundry"), repo).warlord)


func test_the_rules_refuse_what_breaks_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var base: BossDefinition = repo.get_def(&"bosses", &"warlord")
	var cases := [
		[{"nonsense": 1}, &"unknown_field"],
		[{"recall_permille": 500}, &"range"],
		[{"fence_permille": 450}, &"range"],
		[{"banner_cast_seconds": 0.2}, &"range"],
		[{"duel_cast_seconds": 0.39}, &"range"],
		[{"recall_warn_seconds": 0.35}, &"range"],
		[{"duel_phase": 1}, &"range"],
		[{"duel_end_radius_m": 10.0}, &"range"],
		[{"recall_radius_m": 4.8}, &"range"],
		[{"fence_cause": "no_such_attack"}, &"attacks"],
		[{"duel_attacks": ["great_javelin"]}, &"attacks"],
		[{"duel_attacks": []}, &"range"],
	]
	for c: Array in cases:
		var def: BossDefinition = base.duplicate(true)
		var d: Dictionary = def.warlord.duplicate()
		d.merge(c[0], true)
		def.warlord = d
		var codes := def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
		assert_true(codes.has(c[1]), "%s is refused (%s)" % [c[0], codes])


# --- the charge ---------------------------------------------------------------------------------------------------


func test_the_charge_tracks_then_locks_runs_fast_and_bursts_where_it_ends() -> void:
	var s := WarlordLab.fight(Vector2(-10, 0))
	var w: World = s[0]
	var i := _i(w, s[1])
	WarlordLab.hush(w, s[1])
	var atk := WarlordLab.table(w, s[1]).attacks[WarlordLab.table(w, s[1]).attack_index(
		&"lunge_dash"
	)]
	BossLab.start(w, i, &"lunge_dash")
	WarlordLab.idle(w, 5)
	var before := w.actors.lock_a[i]
	w.actors.set_pos(0, Vector2(-10, 3))
	WarlordLab.idle(w, 1)
	assert_ne(w.actors.lock_a[i], before, "the aim follows the hero before the lock")
	WarlordLab.idle(w, atk.windup_ticks - atk.lock_ticks - w.actors.state_t[i])
	var locked := w.actors.lock_a[i]
	w.actors.set_pos(0, Vector2(-10, -5))
	WarlordLab.idle(w, 3)
	assert_eq(w.actors.lock_a[i], locked, "locked for the last 0.4 s")
	var tg := BossAi.telegraph(w, i)
	assert_true(tg.has("burst"), "the telegraph carries the end circle")
	var end := BossChargeBurst.end_of(w, i)
	assert_almost_eq(float(tg["burst"]["radius"]), 3.5, 0.0001)
	assert_true((tg["burst"]["center"] as Vector2).is_equal_approx(end), "at the lane's end")
	# Beside the end, off the lane: the body misses, the burst does not.
	var side := Kin.dir(w.actors.lock_a[i] + 1024) * 2.6
	w.actors.set_pos(0, end + side)
	var seq := w.last_event_seq()
	var ticks := 0
	while w.actors.state[i] == S.WINDUP:
		WarlordLab.idle(w, 1)
	var run_from := w.tick
	while w.actors.state[i] == S.ACTIVE and ticks < 120:
		WarlordLab.idle(w, 1)
		ticks += 1
	var run := w.tick - run_from
	var dist := Kin.length(end - Vector2(w.actors.lock_x[i], w.actors.lock_y[i]))
	assert_between(run, int(dist / atk.speed), int(dist / atk.speed) + 2, "26 m/s")
	var armed := _fx(w, BossChargeBurst.ARMED, seq)
	assert_eq(armed.size(), 1, "a burst is armed where it stopped")
	WarlordLab.idle(w, atk.burst_ticks + 1)
	var bursts := _fx(w, BossChargeBurst.BURST, seq)
	assert_eq(bursts.size(), 1)
	if bursts.size() == 1 and armed.size() == 1:
		assert_eq(bursts[0].tick - armed[0].tick, atk.burst_ticks, "0.25 s after it stops")
		assert_gt(bursts[0].amount, 0, "a hero beside the end is hit")


func test_a_hero_off_the_end_is_not_burst() -> void:
	var s := WarlordLab.fight(Vector2(-10, 0))
	var w: World = s[0]
	var i := _i(w, s[1])
	WarlordLab.hush(w, s[1])
	BossLab.start(w, i, &"lunge_dash")
	WarlordLab.idle(w, 20)
	var end := BossChargeBurst.end_of(w, i)
	w.actors.set_pos(0, end + Kin.dir(w.actors.lock_a[i] + 1024) * 4.5)
	var seq := w.last_event_seq()
	WarlordLab.idle(w, 120)
	var bursts := _fx(w, BossChargeBurst.BURST, seq)
	assert_eq(bursts.size(), 1)
	if bursts.size() == 1:
		assert_eq(bursts[0].amount, 0, "4.5 m off the end: no burst")


# --- the banner ---------------------------------------------------------------------------------------------------


func test_nothing_runs_before_the_second_phase() -> void:
	var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.PLAIN, false)
	var w: World = s[0]
	WarlordLab.idle(w, 900)
	assert_eq(w.boss_fight.wl_boss, -1, "nothing runs (and nothing is hashed) in the first phase")
	assert_eq(WarlordLab.state(w), {})


func test_the_banner_is_planted_on_its_clock_and_falls_after_its_time() -> void:
	var s := WarlordLab.fight(Vector2(-8, 0))
	var w: World = s[0]
	WarlordLab.hush(w, s[1])
	WarlordLab.set_phase(w, s[1], WarlordLab.BANNER)
	var t0 := w.tick
	WarlordLab.idle(w, 1)
	var wt := WarlordLab.wl(w, s[1])
	assert_eq(w.boss_fight.wl_next, t0 + wt.banner_first_ticks, "8 s after the phase begins")
	WarlordLab.idle(w, wt.banner_first_ticks + wt.banner_cast_ticks + wt.banner_ticks + 10)
	var cast := _fx(w, BossWarlord.BANNER_CAST)
	var planted := _fx(w, BossWarlord.BANNER_PLANTED)
	var fell := _fx(w, BossWarlord.BANNER_FALLEN)
	assert_eq([cast.size(), planted.size(), fell.size()], [1, 1, 1])
	if fell.size() != 1:
		return
	assert_eq(cast[0].tick, t0 + wt.banner_first_ticks, "cast when due (the Warlord is free)")
	assert_eq(planted[0].tick - cast[0].tick, wt.banner_cast_ticks, "a 1.0 s cast")
	assert_true(planted[0].pos.is_equal_approx(w.actors.pos(_i(w, s[1]))), "where it stands")
	assert_eq(fell[0].tick - planted[0].tick, wt.banner_ticks, "it stands 20 s")
	assert_eq(fell[0].amount, BossWarlord.FELL_TIME)
	assert_eq(w.boss_fight.wl_next, fell[0].tick + wt.banner_gap_ticks, "the next 12 s after")


func test_the_warlord_stands_and_starts_nothing_while_it_casts() -> void:
	var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := WarlordLab.table(w, s[1])
	t.speed = 2.1 / 60.0
	t.phase_attacks[1] = PackedInt32Array([t.attack_index(&"lunge_dash")])
	var at := w.actors.pos(i)
	WarlordLab.idle(w, 1)
	assert_true(BossWarlord.casting(w, i), "it casts")
	for k in WarlordLab.wl(w, s[1]).banner_cast_ticks - 2:
		WarlordLab.idle(w, 1)
		assert_eq(w.actors.state[i], S.MOVE, "no attack starts in the cast")
	assert_true(w.actors.pos(i).is_equal_approx(at), "it stands")
	assert_true(WarlordLab.state(w)["held"])


func test_inside_the_banner_the_hero_deals_forty_percent_more() -> void:
	var s := WarlordLab.ready(Vector2(-3, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var i := _i(w, s[1])
	assert_gt(WarlordLab.to_banner(w), 0)
	var side := w.actors.pos(i) + Vector2(0, 3)  # Its side: not the shield, not the back
	w.actors.facing[i] = 0
	w.actors.set_pos(0, side)
	var inside := _hero_hit(w, i, 100, side)
	assert_true(WarlordLab.state(w)["banner"]["hero_inside"])
	assert_true(WarlordLab.state(w)["banner"]["boss_inside"])
	w.boss_fight.wl_bn_x = 9.0  # The same spot 9 m from its pole: outside
	assert_false(WarlordLab.state(w)["banner"]["hero_inside"])
	var outside := _hero_hit(w, i, 100, side)
	assert_eq(outside, 100, "outside: as ever")
	assert_eq(inside, 140, "inside: ×1.4")


func test_inside_the_banner_the_warlords_cooldowns_run_at_seventy_percent() -> void:
	for inside: bool in [true, false]:
		var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.BANNER)
		var w: World = s[0]
		var i := _i(w, s[1])
		assert_gt(WarlordLab.to_banner(w), 0)
		if not inside:
			w.boss_fight.wl_bn_x = 50.0  # The banner stands far off
		w.actors.cd[i] = 100
		var n := 0
		while w.actors.cd[i] > 0 and n < 200:
			WarlordLab.idle(w, 1)
			n += 1
		if inside:
			assert_between(n, 69, 71, "100 ticks of cooldown run out in 70")
		else:
			assert_eq(n, 100, "outside: 100")


func test_a_charge_through_its_pole_knocks_the_banner_down() -> void:
	for off: float in [1.8, 3.0]:
		var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.BANNER)
		var w: World = s[0]
		var i := _i(w, s[1])
		assert_gt(WarlordLab.to_banner(w), 0)
		var pole := BossWarlord.pole(w)
		w.actors.set_pos(i, pole + Vector2(8, off))
		w.actors.set_pos(0, pole + Vector2(-8, off))
		var seq := w.last_event_seq()
		BossLab.start(w, i, &"lunge_dash")
		WarlordLab.idle(w, 36 + 40)
		var fell := _fx(w, BossWarlord.BANNER_FALLEN, seq)
		# Within 0.8 m of its lane (the body's radius 1.45 m plus the contact slop each side) it falls
		if off < 1.45 + 0.02 + 0.8:
			assert_eq(fell.size(), 1, "%.1f m off the pole: knocked down" % off)
			if fell.size() == 1:
				assert_eq(fell[0].amount, BossWarlord.FELL_CHARGE)
			assert_gt(_fx(w, BossChargeBurst.ARMED, seq).size(), 0, "the charge goes on to its end")
		else:
			assert_eq(fell.size(), 0, "%.1f m off: it stands" % off)


func test_the_banner_falls_as_the_last_phase_begins() -> void:
	var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.BANNER)
	var w: World = s[0]
	assert_gt(WarlordLab.to_banner(w), 0)
	var seq := w.last_event_seq()
	WarlordLab.set_phase(w, s[1], WarlordLab.DUEL)
	WarlordLab.idle(w, 2)
	var fell := _fx(w, BossWarlord.BANNER_FALLEN, seq)
	assert_eq(fell.size(), 1)
	if fell.size() == 1:
		assert_eq(fell[0].amount, BossWarlord.FELL_CLEARED)
	assert_eq(w.boss_fight.wl_bn_stage, 0, "never with the duel's phase")


# --- the duel -----------------------------------------------------------------------------------------------------


func test_the_cage_closes_on_the_midpoint_and_shrinks_tick_exact() -> void:
	var s := WarlordLab.ready(Vector2(-4, 2), WarlordLab.DUEL)  # The midpoint leaves the room 2.75 m each way
	var w: World = s[0]
	var i := _i(w, s[1])
	var wt := WarlordLab.wl(w, s[1])
	var mid := (w.actors.pos(i) + w.player_pos()) * 0.5
	var seq := w.last_event_seq()
	assert_gt(WarlordLab.to_cage(w), 0)
	var cast := _fx(w, BossDuel.CAST_EV, seq)
	var start := _fx(w, BossDuel.START, seq)
	assert_eq([cast.size(), start.size()], [1, 1])
	if start.size() != 1:
		return
	assert_eq(start[0].tick - cast[0].tick, wt.duel_cast_ticks, "a 1.2 s cast")
	assert_true(BossDuel.centre(w).is_equal_approx(mid), "on the midpoint")
	for k in wt.duel_ticks:
		var r := float(WarlordLab.state(w)["duel"]["radius"])
		var t := w.tick - start[0].tick
		assert_almost_eq(r, 9.0 - 4.0 * float(t) / float(wt.duel_ticks), 0.0001, "tick %d" % t)
		if absf(r - (9.0 - 4.0 * float(t) / float(wt.duel_ticks))) > 0.0001:
			return
		w.actors.set_pos(0, BossDuel.centre(w))  # Away from the fence and the recall's timing aside
		WarlordLab.idle(w, 1)
	assert_eq(WarlordLab.state(w)["duel"]["stage"], BossDuel.RECALL)
	assert_almost_eq(float(WarlordLab.state(w)["duel"]["radius"]), 5.0, 0.0001)


func test_the_cage_is_moved_inward_to_stay_in_the_room() -> void:
	var s := WarlordLab.ready(Vector2(-11, -11), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	w.actors.set_pos(i, Vector2(-9, -10))
	assert_gt(WarlordLab.to_cage(w), 0)
	var c := BossDuel.centre(w)
	var room := w.bosses.arena
	assert_true(room.grow(-9.0).has_point(c), "the whole 9 m circle inside the room (%s)" % c)


func test_neither_the_hero_nor_the_warlord_can_leave_the_cage() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	assert_gt(WarlordLab.to_cage(w), 0)
	var c := BossDuel.centre(w)
	for k in 240:
		w.step(InputFrame.make(Vector2i(-127, 0), 0, 0, 0, 0))  # Walks out to the west
		WarlordLab.take_lost(w)
	var wt := WarlordLab.wl(w, s[1])
	var r := BossDuel.radius(w, wt)
	var hero := Kin.length(w.player_pos() - c) + w.player.radius_m
	assert_lte(hero, r + ONE_TICK_M, "the hero's body stays inside the fence")
	assert_gt(hero, r - 0.3, "pressed to it")
	w.actors.set_pos(i, c + Vector2(0, 12))
	WarlordLab.idle(w, 1)
	assert_lte(
		Kin.length(w.actors.pos(i) - c) + w.actors.radius[i],
		BossDuel.radius(w, wt) + ONE_TICK_M,
		"and the Warlord's"
	)


func test_its_charge_is_cut_short_at_the_fence_and_still_bursts() -> void:
	var s := WarlordLab.ready(Vector2(-3, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	assert_gt(WarlordLab.to_cage(w), 0)
	var c := BossDuel.centre(w)
	var wt := WarlordLab.wl(w, s[1])
	w.actors.set_pos(0, c + Vector2(-2, 0))
	w.actors.set_pos(i, c + Vector2(2, 0))
	var seq := w.last_event_seq()
	BossLab.start(w, i, &"lunge_dash")
	WarlordLab.idle(w, 30)
	var end := BossChargeBurst.end_of(w, i)
	assert_lte(
		Kin.length(end - c) + w.actors.radius[i],
		BossDuel.radius(w, wt) + ONE_TICK_M,
		"the lane ends at the fence"
	)
	WarlordLab.idle(w, 60)
	var armed := _fx(w, BossChargeBurst.ARMED, seq)
	assert_eq(armed.size(), 1, "its burst still happens")
	if armed.size() == 1:
		assert_lte(Kin.length(armed[0].pos - c), BossDuel.radius(w, wt), "inside the cage")


func test_the_fence_hurts_ten_percent_at_most_once_in_point_six_seconds() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var wt := WarlordLab.wl(w, s[1])
	assert_gt(WarlordLab.to_cage(w), 0)
	var start := w.tick
	var c := BossDuel.centre(w)
	var seq := w.last_event_seq()
	for k in 180:
		var r := BossDuel.radius(w, wt) - w.player.radius_m
		w.actors.set_pos(0, c + Vector2(-r, 0))  # On the fence
		w.actors.invuln[0] = 0
		WarlordLab.idle(w, 1)
	var hurts := WarlordLab.hurts(w, BossDuel.FENCE_EFFECT, seq)
	assert_between(
		hurts.size(), 180 / wt.fence_every_ticks - 1, 180 / wt.fence_every_ticks, "every 0.6 s"
	)
	for k in hurts.size():
		assert_eq(hurts[k].amount, 100, "10 % of 1000")
		if k > 0:
			assert_gte(hurts[k].tick - hurts[k - 1].tick, wt.fence_every_ticks, "never sooner")
	if not hurts.is_empty():
		assert_gte(
			hurts[0].tick - start, wt.fence_every_ticks - 1, "a hero dragged in has a moment"
		)
	# Off the fence, nothing
	seq = w.last_event_seq()
	for k in 60:
		w.actors.set_pos(0, c + Vector2(-1.0, 0))
		WarlordLab.idle(w, 1)
	assert_eq(WarlordLab.hurts(w, BossDuel.FENCE_EFFECT, seq).size(), 0, "away from it: nothing")


func test_the_shield_is_down_only_in_the_cage() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	w.actors.facing[i] = 2048  # Facing the hero at -x
	var front := w.actors.pos(i) + Vector2(-2.5, 0)
	assert_eq(_hero_hit(w, i, 100, front), 0, "before: the front blocks")
	assert_gt(WarlordLab.to_cage(w), 0)
	w.actors.facing[i] = 2048
	front = w.actors.pos(i) + Vector2(-2.5, 0)
	assert_eq(_hero_hit(w, i, 100, front), 100, "in the cage: the front takes the normal share")
	assert_true(WarlordLab.state(w)["duel"]["shield_down"])
	WarlordLab.idle(
		w, WarlordLab.wl(w, s[1]).duel_ticks + WarlordLab.wl(w, s[1]).recall_warn_ticks + 2
	)
	assert_eq(w.boss_fight.wl_du_stage, 0, "the duel is over")
	w.actors.facing[i] = 2048
	front = w.actors.pos(i) + Vector2(-2.5, 0)
	w.bosses.exposed_t[BossAi.entry_of(w, i)] = 0
	assert_eq(_hero_hit(w, i, 100, front), 0, "after: blocked again")


func test_in_the_cage_only_the_duels_attacks() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := WarlordLab.table(w, s[1])
	var ids := [&"javelin_fan_fast", &"great_javelin", &"shield_wall_cross", &"spear_wall"]
	ids.append_array([&"shield_bash", &"lunge_dash", &"spear_lines"])
	for id: StringName in ids:
		assert_true(BossSiege.may_use(w, i, t.attacks[t.attack_index(id)]), "%s before" % id)
	assert_gt(WarlordLab.to_cage(w), 0)
	for id: StringName in ids:
		var ok := [&"shield_bash", &"lunge_dash", &"spear_lines"].has(id)
		assert_eq(BossSiege.may_use(w, i, t.attacks[t.attack_index(id)]), ok, "%s in the cage" % id)


func test_the_recall_warns_then_hits_the_centre_for_forty_percent() -> void:
	for at_centre: bool in [true, false]:
		var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
		var w: World = s[0]
		var wt := WarlordLab.wl(w, s[1])
		assert_gt(WarlordLab.to_cage(w), 0)
		var c := BossDuel.centre(w)
		var seq := w.last_event_seq()
		var spot := c if at_centre else c + Vector2(-3.8, 0)
		for k in wt.duel_ticks + wt.recall_warn_ticks + 2:
			w.actors.set_pos(0, spot)
			w.actors.invuln[0] = 0
			WarlordLab.idle(w, 1)
		var warn := _fx(w, BossDuel.WARN, seq)
		var hit := _fx(w, BossDuel.RECALL_EV, seq)
		assert_eq([warn.size(), hit.size(), _fx(w, BossDuel.END, seq).size()], [1, 1, 1])
		if hit.size() != 1:
			continue
		assert_eq(hit[0].tick - warn[0].tick, wt.recall_warn_ticks, "a 1.0 s warning")
		assert_eq(hit[0].amount, 400 if at_centre else 0, "40 % in the centre, nothing outside it")
		assert_eq(w.boss_fight.wl_du_stage, 0, "then the cage is gone")
		assert_eq(w.boss_fight.wl_next, hit[0].tick + wt.duel_gap_ticks, "the next 25 s after")


func test_the_recall_names_the_javelins_flying_back() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var wt := WarlordLab.wl(w, s[1])
	assert_gt(WarlordLab.to_cage(w), 0)
	WarlordLab.idle(w, wt.duel_ticks)
	w.actors.set_pos(0, BossDuel.centre(w))
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 1000
	w.actors.invuln[0] = 0
	for k in wt.recall_warn_ticks + 4:
		w.actors.set_pos(0, BossDuel.centre(w))
		w.step(InputFrame.new())
		if w.player_dead():
			break
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), &"CAUSE_WARLORD_RECALL")


func test_the_cage_is_always_inside_the_room_over_seeds() -> void:
	var seeds := Seeds.count(400)
	var bad := []
	for sv in seeds:
		var rng := RngStream.new(sv + 1)
		var boss := Vector2(rng.range_int(-1050, 1050), rng.range_int(-1050, 1050)) / 100.0
		var hero := Vector2(rng.range_int(-1150, 1150), rng.range_int(-1150, 1150)) / 100.0
		var s := WarlordLab.ready(hero, WarlordLab.DUEL, true, sv)
		var w: World = s[0]
		var i := _i(w, s[1])
		w.actors.set_pos(i, boss)
		w.actors.set_pos(0, hero)
		if WarlordLab.to_cage(w) < 0:
			bad.append("seed %d: no cage" % sv)
			continue
		var c := BossDuel.centre(w)
		var r := w.boss_fight.wl_du_r0
		if not w.bosses.arena.grow(-r + 0.001).has_point(c) or r < 9.0 - 0.0001:
			bad.append("seed %d: %s r %.2f" % [sv, c, r])
	assert_eq(bad, [], "every cage is whole inside the room")


# --- one big mechanic at a time -----------------------------------------------------------------------------------


func test_neither_begins_while_a_great_javelin_is_out_and_none_is_thrown_while_one_runs() -> void:
	for phase: int in [WarlordLab.BANNER, WarlordLab.DUEL]:
		var s := WarlordLab.ready(Vector2(-10, 0), phase, false)
		var w: World = s[0]
		var i := _i(w, s[1])
		var t := WarlordLab.table(w, s[1])
		var gj := t.attacks[t.attack_index(&"great_javelin")]
		BossLab.start(w, i, &"great_javelin")
		w.boss_fight.wl_next = w.tick + 2  # Due while it winds up
		var waited := 0
		while (BossGreatJavelin.is_out(w, s[1]) or w.actors.state[i] != S.MOVE) and waited < 900:
			assert_false(BossWarlord.running(w), "phase %d: it waits for the javelin" % phase)
			WarlordLab.idle(w, 1)
			waited += 1
		assert_gt(waited, gj.windup_ticks, "the javelin was out a while")
		WarlordLab.idle(w, 1)
		assert_true(BossWarlord.running(w), "phase %d: then it begins" % phase)
		assert_false(BossSiege.may_use(w, i, gj), "and no great javelin while it runs")


func test_an_attack_in_progress_finishes_before_the_cast() -> void:
	var s := WarlordLab.ready(Vector2(-3, 0), WarlordLab.BANNER, false)
	var w: World = s[0]
	var i := _i(w, s[1])
	BossLab.start(w, i, &"shield_bash")
	w.boss_fight.wl_next = w.tick
	while w.actors.state[i] != S.MOVE:
		assert_false(BossWarlord.running(w), "not in the bash or its recovery")
		WarlordLab.idle(w, 1)
	WarlordLab.idle(w, 1)
	assert_true(BossWarlord.running(w))


# --- the end of a fight -------------------------------------------------------------------------------------------


func test_everything_clears_when_the_hero_dies() -> void:
	for phase: int in [WarlordLab.BANNER, WarlordLab.DUEL]:
		var s := WarlordLab.ready(Vector2(-4, 0), phase)
		var w: World = s[0]
		var i := _i(w, s[1])
		WarlordLab.idle(w, 150)
		assert_true(BossWarlord.running(w))
		var seq := w.last_event_seq()
		w.actors.hp[0] = 0
		w.actors.dead[0] = 1
		w.step(InputFrame.new())
		assert_false(BossWarlord.running(w), "phase %d: gone" % phase)
		assert_eq(WarlordLab.state(w)["banner"], {})
		assert_eq(WarlordLab.state(w)["duel"], {})
		assert_false(BossDuel.shield_down(w, i))
		var ends := _fx(w, BossWarlord.BANNER_FALLEN, seq) + _fx(w, BossDuel.END, seq)
		assert_eq(ends.size(), 1, "told once")
		w.step(InputFrame.new())
		assert_eq(
			_fx(w, BossWarlord.BANNER_FALLEN, seq).size() + _fx(w, BossDuel.END, seq).size(), 1
		)


func test_everything_goes_with_the_warlord() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	assert_gt(WarlordLab.to_cage(w), 0)
	w.actors.hp[i] = 0
	w.actors.dead[i] = 1
	WarlordLab.idle(w, 2)
	assert_eq(w.boss_fight.wl_boss, -1)
	assert_eq(w.boss_fight.wl_du_stage, 0)
	assert_eq(WarlordLab.state(w), {})


func test_deterministic_hashed_and_a_save_mid_duel_restores() -> void:
	var make := func() -> World:
		var s := WarlordLab.fight(Vector2(-5, 0), Vector2(3, 0), 7)
		var w: World = s[0]
		WarlordLab.set_phase(w, s[1], WarlordLab.DUEL)
		WarlordLab.idle(w, 1)
		w.boss_fight.wl_next = w.tick + 30
		var k := 0
		while k < 1800 and w.boss_fight.wl_du_stage != BossDuel.CAGE:  # It begins once it is free
			w.step(InputFrame.make(Vector2i(40, 90), 0, 300, InputFrame.SHOOT, 0))
			w.actors.hp[0] = WarlordLab.LONG
			k += 1
		for n in 120:
			w.step(InputFrame.make(Vector2i(40, 90), 0, 300, InputFrame.SHOOT, 0))
			w.actors.hp[0] = WarlordLab.LONG
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	assert_ne(a.boss_fight.wl_du_stage, 0, "mid-duel")
	var before := a.state_hash()
	a.boss_fight.wl_du_r0 += 0.5
	assert_ne(a.state_hash(), before, "the cage is hashed")
	a.boss_fight.wl_du_r0 -= 0.5
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), JudgeLab.world(7))
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	assert_eq(WarlordLab.state(restored), WarlordLab.state(a))
	for k in 600:
		var f := InputFrame.make(Vector2i(60, -40), 0, 300, InputFrame.SHOOT, 0)
		a.step(f)
		restored.step(f)
		a.actors.hp[0] = WarlordLab.LONG
		restored.actors.hp[0] = WarlordLab.LONG
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 600 ticks on")


func test_a_world_without_the_warlord_keeps_no_warlord_state() -> void:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	CombatLab.idle(w, 120)
	assert_eq(w.boss_fight.wl_boss, -1)
	assert_eq(WorldReader.new(w).boss_warlord(), {})
