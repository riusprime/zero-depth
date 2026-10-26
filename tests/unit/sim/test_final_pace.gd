extends GutTest
## v0.8.0 N2 (owner O41: "each phase takes 1-2 minutes 1 minute being the most op and longer if you are not op,
## oneshoting (killing a phase in seconds should never happen)"; PLAN step N2; FINAL_BOSS.md "N2"): each body of the
## final boss lasts about a minute against the strongest build and longer against weaker ones. Scripted fights (test_
## boss_pace.gd's BladeRun: a hero that stands in melee reach and attacks while the body can be hurt, dashes the big
## attacks, is healed every tick), not the bot balance suite: a base build, a strong build and two absurd ones (RARITY's
## broken recipes at level 5, after Ascension loops). Each body's time is printed for the evidence.

const BP := preload("res://tests/unit/sim/test_boss_pace.gd")
## The builds: [name, weapon, loop, cards ([id, level])].
const BUILDS := [
	["base blade", &"blade", 1, []],
	[
		"strong blade",
		&"blade",
		1,
		[[&"double_slash", 3], [&"echo_slash", 3], [&"shared_explosive", 3]]
	],
	[
		"absurd gun (Chain Blast + Split + Spread Lv 5, loop 3)",
		&"gun",
		3,
		[[&"chain_blast", 5], [&"split_shot", 5], [&"gun_spread", 5]]
	],
	[
		"absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3)",
		&"blade",
		3,
		[[&"chain_blast", 5], [&"double_slash", 5], [&"trigger_on_hit_twice", 5]]
	],
]
## The N2 attacks: [boss, attack]. (v0.8.0 PR, owner O84: the Prism's prism_bolt_fan and cross_weave are gone; her
## orb spells' gaps and steps are test_prism.gd's.)
const NEW_ATTACKS := [
	[&"colossus", &"leap_slam_3"],
	[&"colossus", &"spike_chase_3"],
	[&"nemesis", &"fallen_storm"],
	[&"nemesis", &"fallen_rush"],
]
## The dodge keeps running this long after the attack ends (ticks).
const TAIL_TICKS := 150
## The whole fight within this (ticks: 12 minutes).
const LIMIT := 43200


static func bigs() -> Dictionary:
	var out := {}
	var repo := ContentRepository.load_all()
	for id: StringName in [&"colossus", &"prism", &"nemesis"]:
		for a in (repo.get_def(&"final_bosses", id) as BossDefinition).attacks:
			if a.hit_class == &"big":
				out[a.id] = true
	return out


## The final arena of build `b` with its cards held as the hero walks in (the catch-up reads them), the Colossus up.
static func arena(b: Array, seed_value: int = 21) -> World:
	var run := FinalLab.run_state(seed_value, b[1], b[2])
	var w := FinalLab.arena(run, false)
	NemesisLab.grant(w, b[3])
	CatchUp.start_floor(w)
	FinalArenaScenario.begin(w, run, 3)
	FinalLab.past_rise(w)
	return w


## Fights the final boss with build `b`; returns [won, [seconds of each body], [[max HP, measured dps] of each], bot,
## [the last body's raw seconds, the seconds it was gone]].
static func fight(b: Array, seed_value: int = 21) -> Array:
	var w := arena(b, seed_value)
	var bot := Hero.new(-1, bigs())
	var starts := []
	var reads := []
	var last := [0, 0]
	bot.fight(
		w,
		LIMIT,
		func(_w: World) -> bool:
			var i := FinalLab.body(w)
			if i >= 0 and w.actors.ids[i] != bot.aid:
				if bot.aid >= 0:
					reads.append(last.duplicate())
				bot.aid = w.actors.ids[i]
				starts.append(w.tick)
			if i >= 0:
				last[0] = w.actors.max_hp[i]  # (in place: a lambda's captures are copies)
				last[1] = w.final_fight.pace_dps / 1000
			return w.final_fight.won
	)
	reads.append(last.duplicate())
	starts.append(w.final_fight.won_tick if w.final_fight.won else w.tick)
	var secs := []
	for k in starts.size() - 1:
		secs.append(snappedf((starts[k + 1] - starts[k]) / 60.0, 0.1))
	# v0.9.5 BH6: the Fallen's two interphases (it is gone, 15 s and the 1 s ring each) are not fought: the pace's target
	# time leaves them out. The last body's time is the fight's without them; the raw time is the fourth item.
	var gone := w.final_fight.ip_total
	var raw: float = secs[secs.size() - 1]
	secs[secs.size() - 1] = snappedf(raw - gone / 60.0, 0.1)
	return [w.final_fight.won, secs, reads, bot, [raw, snappedf(gone / 60.0, 0.1)]]


## Each body from its rise to the next one's (its rise, the fight, its shatter): at least the pace's minute, at most
## the pace's three minutes plus the rise and the shatter; the base build's no quicker than the absurd ones'.
func test_each_body_lasts_a_minute_or_more_whatever_the_build() -> void:
	var base := []
	for b: Array in BUILDS:
		var r := fight(b)
		var bot: Hero = r[3]
		(
			gut
			. p(
				(
					(
						"N2 pace %s: won=%s, bodies (s, the Fallen's less its interphases) %s, [max HP, measured dps] %s, "
						+ "hits taken %d; the Fallen's raw time and interphase time (s) %s"
					)
					% [b[0], r[0], r[1], r[2], bot.hits, r[4]]
				)
			)
		)
		assert_true(r[0], "%s: the fight is won" % b[0])
		assert_eq((r[1] as Array).size(), 3, "%s: three bodies" % b[0])
		for k in (r[1] as Array).size():
			var s: float = r[1][k]
			# v0.9.5 BH1 (Q11): a looped run's minute is 12 % shorter per loop finished (at most 3)
			var floor_s := 60.0 * (1000 - 120 * mini(int(b[2]) - 1, 3)) / 1000.0
			assert_gte(
				s, floor_s, "%s body %d: never under %.1f s (%.1f s)" % [b[0], k, floor_s, s]
			)
			assert_lte(s, 185.0, "%s body %d: never past three minutes (%.1f s)" % [b[0], k, s])
			if base.is_empty():
				continue
			assert_gte(base[k], s - 1.0, "%s body %d: no slower than the base build" % [b[0], k])
		if base.is_empty():
			base = r[1]


# --- the pace's formula and its cap ---------------------------------------------------------------------------------


func _table(id: StringName) -> BossTable:
	var repo := ContentRepository.load_all()
	return ContentCompiler.compile_boss(repo.get_def(&"final_bosses", id), repo)


func test_the_time_falls_with_the_square_root_of_your_damage() -> void:
	var t := _table(&"colossus")
	assert_true(t.pace)
	assert_eq(t.pace_ref_dps, 30)
	assert_eq(FinalPace.seconds_at(30000, t), 7200, "the base hero (30 dps): 2 min")
	assert_eq(FinalPace.seconds_at(120000, t), 3600, "4x: 1 min")
	assert_eq(FinalPace.seconds_at(3000000, t), 3600, "100x: still 1 min (the floor)")
	assert_eq(FinalPace.seconds_at(7500, t), 10800, "a quarter: 3 min (the ceiling)")
	assert_between(FinalPace.seconds_at(60000, t), 5080, 5100, "2x: 85 s")
	assert_eq(FinalPace.hp_for(30000, t), 3600, "30 dps x 120 s")
	assert_eq(FinalPace.hp_for(120000, t), 7200, "120 dps x 60 s")
	assert_eq(FinalPace.hp_for(0, t), clampi(t.hp, t.dps_hp_min, t.dps_hp_max), "no meter: its own")
	var prism := _table(&"prism")
	assert_eq(FinalPace.hp_for(30000, prism), 3600 * prism.window_permille / 1000, "x her windows")
	for id: StringName in [&"colossus", &"prism", &"nemesis"]:
		assert_true(_table(id).pace, "%s is paced" % id)


## A build that hits the Colossus for 100,000 every tick (owner O41's "oneshoting"): its segment still lasts a minute
## of fighting; the world's own hit (owner 0, the dev panel's Kill boss) still ends it at once.
func test_no_build_takes_a_body_in_under_a_minute() -> void:
	var w := FinalLab.arena(FinalLab.run_state(31))
	w.actors.invuln[0] = NemesisLab.LONG
	FinalLab.past_rise(w)
	var pid := w.actors.ids[0]
	var ticks := 0
	var aid := w.actors.ids[FinalLab.body(w)]
	while ticks < 7200 and not FinalBoss.shattering(w):
		var i := FinalLab.body(w)
		w.actors.invuln[i] = 0
		var at := w.actors.pos(i)
		Damage.hit(w, i, 100000, pid, pid, w.take_root(), 0, at, at)
		w.step(InputFrame.new())
		ticks += 1
	var mhp := w.actors.max_hp[FinalLab.body(w)]
	gut.p("N2 cap: 100,000 a tick took the Colossus in %.1f s (max HP %d)" % [ticks / 60.0, mhp])
	assert_true(FinalBoss.shattering(w), "it falls")
	assert_gte(ticks, 3600, "never under a minute")
	assert_lte(ticks, 3700, "and about a minute")
	assert_true(w.final_fight.paced, "its HP from the meter")
	assert_eq(w.actors.ids[FinalLab.body(w)], aid)
	var w2 := FinalLab.arena(FinalLab.run_state(31))
	FinalLab.past_rise(w2)
	FinalLab.end_segment(w2)
	assert_true(FinalBoss.shattering(w2), "the dev panel's Kill boss is not capped")


func test_the_colossus_takes_its_hp_from_the_meter_keeping_its_fill() -> void:
	var w := FinalLab.arena(FinalLab.run_state(32))
	w.actors.invuln[0] = NemesisLab.LONG
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	var pid := w.actors.ids[0]
	var before := w.actors.max_hp[i]
	assert_false(w.final_fight.paced, "it rises with its own HP (no meter yet)")
	var n := 0
	while not w.final_fight.paced and n < 600:
		if n % 60 == 0:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 60, pid, pid, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i))
		w.step(InputFrame.new())
		n += 1
	assert_true(w.final_fight.paced, "paced once 5 s are measured")
	assert_between(n, 299, 362, "after 5 measured seconds")
	var t := BossAi.table_of(w, i)
	assert_eq(w.actors.max_hp[i], FinalPace.hp_for(w.final_fight.pace_dps, t))
	assert_ne(w.actors.max_hp[i], before)
	assert_gt(w.actors.hp[i], w.actors.max_hp[i] * 9 / 10, "its fill kept (it lost under a tenth)")


# --- The Fallen's windows -----------------------------------------------------------------------------------------


func test_the_fallen_mimics_you_in_windows_on_and_off() -> void:
	var w := NemesisLab.world(33, &"blade", [[&"echo_slash", 3]], true, false)
	var t := BossAi.table_of(w, FinalLab.body(w))
	assert_eq(t.window_ticks, 336, "5.6 s windows (v0.9.5 BH6, HC6: 20 % shorter than 7 s)")
	assert_eq(t.window_every_ticks, 1200, "one every 20 s")
	assert_eq(t.window_warn_ticks, 90, "warned 1.5 s ahead")
	assert_eq(FinalPace.window(w), FinalPace.Mimic.OFF, "it rises in its own kit")
	assert_false(FinalPace.copies(w))
	var start := w.tick
	var cues := []
	for k in 2700:
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.STATUS_APPLY and String(e.effect_id).begins_with("fallen_"):
				cues.append([e.effect_id, w.tick - start])
	gut.p("N2 windows (cue, ticks after the test began): %s" % [cues])
	assert_gte(cues.size(), 5)
	if cues.size() < 5:
		return
	assert_eq(cues[0][0], FinalPace.EFFECT_WARN, "the warning first")
	assert_eq(cues[1][0], FinalPace.EFFECT_OPEN)
	assert_eq(cues[2][0], FinalPace.EFFECT_CLOSE)
	assert_eq(cues[1][1] - cues[0][1], 90, "the window opens 1.5 s after its warning")
	assert_eq(cues[2][1] - cues[1][1], 336, "and lasts 5.6 s")
	assert_eq(cues[4][1] - cues[1][1], 1200, "the next one 20 s later")


func _window_world(seed_value: int, cards: Array = [[&"echo_slash", 3], [&"whirl", 2]]) -> World:
	var w := NemesisLab.world(seed_value, &"blade", cards, true, false)
	var i := FinalLab.body(w)
	w.actors.cd[i] = 1 << 20  # it picks nothing by itself meanwhile
	return w


func test_outside_a_window_it_fights_with_its_own_kit() -> void:
	var w := _window_world(34)
	var t := BossAi.table_of(w, FinalLab.body(w))
	assert_eq(FinalPace.window(w), FinalPace.Mimic.OFF)
	var card := t.attacks[t.attack_index(&"nemesis_card_1")]
	var own := t.attacks[t.attack_index(&"fallen_storm")]
	var gun := t.attacks[t.attack_index(&"nemesis_volley")]
	assert_false(BossNemesis.allowed(w, card), "no card outside a window")
	assert_true(BossNemesis.allowed(w, own), "its own attacks")
	assert_true(BossNemesis.allowed(w, gun), "both weapons' moves, whatever the run")
	var atk := NemesisLab.start(w, &"nemesis_combo")
	var arc := BossNemesis.combo_arc(w, FinalLab.body(w), 0)
	assert_false(w.final_fight.copying)
	assert_eq(arc[3], atk.half_arc, "its own arc, not your combo step")
	assert_eq(NemesisBuild.damage_of(w, atk), w.actors.max_hp[0] * 30 / 100, "its hit: 30 % of HP")
	NemesisLab.until_window(w, FinalPace.Mimic.ON)
	assert_true(FinalPace.copies(w), "the window opens")
	assert_true(BossNemesis.allowed(w, card), "your cards in a window")
	assert_false(BossNemesis.allowed(w, own), "never its own kit in one")
	assert_false(BossNemesis.allowed(w, gun), "only your weapon's moves")
	NemesisLab.start(w, &"nemesis_combo")
	assert_true(w.final_fight.copying, "the attack copies you")
	arc = BossNemesis.combo_arc(w, FinalLab.body(w), 0)
	assert_eq(arc[3], Modifiers.step(w, 0).half_arc, "your combo's own step")


func test_in_a_window_it_answers_your_dash_and_not_outside() -> void:
	var w := _window_world(35)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(5, 0))
	w.step(NemesisLab.dash(Vector2(0, 1)))
	var dashed := false
	for k in 30:
		w.step(InputFrame.new())
		dashed = dashed or w.final_fight.dash_t > 0
	assert_false(dashed, "outside a window it doesn't dash with you")
	NemesisLab.until_window(w, FinalPace.Mimic.ON)
	CombatLab.idle(w, 40)  # the hero's dash cooldown
	w.step(NemesisLab.dash(Vector2(0, -1)))
	for k in 30:
		w.step(InputFrame.new())
		dashed = dashed or w.final_fight.dash_t > 0
	assert_true(dashed, "in a window it dashes when you dash")


func test_in_a_window_your_damage_and_speed_are_pulled_to_its_level() -> void:
	var w := _window_world(36)
	var t := BossAi.table_of(w, FinalLab.body(w))
	w.final_fight.pace_dps = 300000  # a build ten times the base hero
	var pid := w.actors.ids[0]
	w.final_fight.pace_budget = 1 << 40
	assert_eq(FinalPace.cap_hit(w, 1000, pid), 1000, "off: yours")
	assert_eq(FinalPace.move_cap(w, 1500), 1500, "your speed bonus outside a window")
	NemesisLab.until_window(w, FinalPace.Mimic.ON)
	assert_eq(FinalPace.nerf_permille(w, t), 100, "30 / 300 dps: a tenth")
	w.final_fight.pace_budget = 1 << 40
	assert_eq(FinalPace.cap_hit(w, 1000, pid), 100, "your hit pulled to the base hero's level")
	assert_eq(FinalPace.cap_hit(w, 1000, 0), 1000, "the world's own hit is not")
	assert_eq(FinalPace.move_cap(w, 1500), 1000, "your speed: the base (Stats.move_permille)")
	assert_eq(FinalPace.move_cap(w, 800), 800, "a slow is never lifted")
	w.final_fight.pace_dps = 3000000
	assert_eq(FinalPace.nerf_permille(w, t), t.nerf_min_permille, "never under its floor")


func test_its_hits_follow_o27_outside_windows_and_copy_you_in_them() -> void:
	var w := _window_world(37)
	var t := BossAi.table_of(w, FinalLab.body(w))
	var hp := w.actors.max_hp[0]
	for pair: Array in [
		[&"nemesis_combo", 30],
		[&"nemesis_crescents", 22],
		[&"fallen_storm", 22],
		[&"fallen_rush", 30],
		[&"nemesis_point_blank", 34],
	]:
		var atk := t.attacks[t.attack_index(pair[0])]
		assert_eq(NemesisBuild.damage_of(w, atk), hp * int(pair[1]) / 100, "%s outside" % pair[0])
		assert_between(BossSchemas.hits_to_kill(hp, NemesisBuild.damage_of(w, atk)), 3, 5)
	var card := t.attacks[t.attack_index(&"nemesis_card_1")]
	w.final_fight.copying = true
	assert_eq(NemesisBuild.damage_of(w, card), hp / 2, "a card: a big hit (2 to kill)")
	w.final_fight.hit = 1 << 20
	assert_eq(NemesisBuild.damage_of(w, card, 2000), w.final_fight.hit_cap, "your build, capped")
	assert_eq(w.final_fight.hit_cap, hp / 2, "never more than half your HP")


# --- determinism and saves ----------------------------------------------------------------------------------------


func test_the_paced_fight_is_deterministic_and_round_trips_mid_window() -> void:
	var run := FinalLab.run_state(38, &"blade")
	var a := NemesisLab.world(38, &"blade", [[&"echo_slash", 3]], true, false)
	var b := NemesisLab.world(38, &"blade", [[&"echo_slash", 3]], true, false)
	NemesisLab.until_window(a, FinalPace.Mimic.ON)
	NemesisLab.until_window(b, FinalPace.Mimic.ON)
	CombatLab.idle(a, 60)
	CombatLab.idle(b, 60)
	assert_eq(a.state_hash(), b.state_hash(), "the same fight")
	var snap := a.to_snapshot()
	var c := FinalLab.arena(run, false)
	assert_eq(WorldSnapshot.apply(c, snap), "")
	assert_eq(c.state_hash(), a.state_hash(), "a snapshot mid-window")
	for k in 900:
		a.step(InputFrame.new())
		c.step(InputFrame.new())
	assert_eq(c.state_hash(), a.state_hash(), "the window, its end and the next go on the same")


func test_a_save_from_before_n2_mid_fight_still_loads() -> void:
	var run := FinalLab.run_state(39)
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = NemesisLab.LONG
	FinalLab.past_rise(w)
	CombatLab.idle(w, 200)
	var p := RunSaver.payload_of(w, run, 39, PackedByteArray())
	var ff: Dictionary = p["world"]["world"][&"final_fight"]
	for f: StringName in [&"paced", &"pace_dps", &"pace_budget", &"copying"]:
		assert_true(ff.has(f), "saved: %s" % f)
		ff.erase(f)  # as a payload written before N2
	var table := ContentCompiler.compile_run(
		ContentRepository.load_all().get_def(&"run", SaveLab.RUN_ID)
	)
	var w2 := FinalLab.arena(RunSaver.run_from(p, table), false)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "an FB3 snapshot restores")
	assert_false(w2.final_fight.paced, "with a fresh pace")
	var w3 := FinalLab.arena(RunSaver.run_from(p, table), false)
	assert_eq(WorldSnapshot.apply(w3, p["world"]), "")
	for k in 600:
		w2.step(InputFrame.new())
		w3.step(InputFrame.new())
	assert_eq(w2.state_hash(), w3.state_hash(), "two restores go on the same")


# --- the harder attacks: dashable after their telegraph -------------------------------------------------------------


## test_boss_pace.gd's _dodge, and the hero keeps running TAIL_TICKS more after the attack ends (a ring's stones and
## a volley's crescents still fly). Returns [the damage it took, the dash tick].
func _dodge(id: StringName, attack_id: StringName, dist: float, way: int) -> Array:
	var w: World = BP._world()
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(dist, 0))
	var t := BossAi.table_of(w, i)
	var atk := t.attacks[t.attack_index(attack_id)]
	BossLab.start(w, i, attack_id)
	var hp0 := w.actors.hp[0]
	var dir := [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)][way] as Vector2
	var commit := atk.lock_ticks if atk.lock_ticks > 0 else t.commit_ticks
	var at := BP.REACT_TICKS
	if BossAi.TRACKING_MOVES.has(atk.move):
		at = maxi(at, atk.windup_ticks - commit)
	var running := false
	var dashed := -1
	var tail := -1
	for n in 900:
		i = w.actors.index_of(aid)
		if i < 0 or w.player_dead():
			break
		var b := BossAi.entry_of(w, i)
		if tail < 0 and (w.bosses.attack[b] < 0 or w.actors.state[i] == EnemyAi.State.MOVE):
			tail = TAIL_TICKS
			w.actors.cd[i] = 1 << 20  # nothing more starts
		if tail == 0:
			break
		if tail > 0:
			tail -= 1
		var pressed := 0
		if w.actors.state[i] == EnemyAi.State.WINDUP and w.actors.state_t[i] == at and dashed < 0:
			running = true
			if w.dash_cooldown_left == 0:
				pressed = InputFrame.DASH
				dashed = n
		w.step(BP.BladeRun.frame_of(dir if running else Vector2.ZERO, dir, pressed))
	return [hp0 - w.actors.hp[0], dashed]


## test_boss_pace.gd's dodge (the hero 0.3 s after the telegraph, or at the lock of a tracking move, dashes left, right,
## away or toward and runs on) on each new attack, near and far: one way at least is clean.
func test_each_new_attack_is_dashable_after_its_telegraph() -> void:
	for pair: Array in NEW_ATTACKS:
		var w0: World = BP._world()
		var t := w0.boss_tables[BossLab.table_index(w0, pair[0])]
		var atk := t.attacks[t.attack_index(pair[1])]
		var near := maxf(atk.min_range_m + 0.5, t.radius_m + 1.2)
		var far := minf(atk.max_range_m - 0.5, 8.0)
		for dist: float in [near, far]:
			var ways := []
			var hit := []
			for way in 4:
				var r: Array = _dodge(pair[0], pair[1], dist, way)
				assert_gte(r[1], 0, "%s %s: the hero dashed" % pair)
				if r[0] == 0:
					ways.append(["left", "right", "away", "toward"][way])
				hit.append(r[0])
			gut.p(
				(
					"N2 dodge %s %s at %.1f m: clean by %s (damage left/right/away/toward %s)"
					% [pair[0], pair[1], dist, ways, hit]
				)
			)
			assert_false(ways.is_empty(), "%s %s at %.1f m is dashable" % [pair[0], pair[1], dist])


## The new attacks hit who stands still (real attacks, not decoration).
func test_standing_still_each_new_attack_hits() -> void:
	for pair: Array in NEW_ATTACKS:
		var w: World = BP._world()
		var i := BossLab.ready_boss(w, pair[0])
		var aid := w.actors.ids[i]
		var t := BossAi.table_of(w, i)
		var atk := t.attacks[t.attack_index(pair[1])]
		w.actors.set_pos(0, Vector2(maxf(atk.min_range_m + 0.5, t.radius_m + 1.5), 0))
		w.actors.hp[0] = 1000000
		w.actors.max_hp[0] = 1000000
		BossLab.start(w, i, pair[1])
		var hp0 := w.actors.hp[0]
		for n in 600:
			i = w.actors.index_of(aid)
			if i < 0 or w.bosses.attack[BossAi.entry_of(w, i)] < 0:
				break
			w.step(InputFrame.new())
		assert_gt(hp0 - w.actors.hp[0], 0, "%s %s hits who stands still" % pair)


## PF (docs/roadmap/v0.8.0/evidence/PERF.md): the new dense patterns stay under the hostile caps
## (BulletPatterns.MAX_ALIVE alive, MAX_SHOTS_PER_TICK a tick) with no LIMIT event, printed beside the attack they join.
func test_the_new_patterns_keep_the_shot_caps() -> void:
	for pair: Array in [
		[1, &"crown_ring"],
		[1, &"crown_spiral"],
		[1, &"crown_flower"],
		[0, &"leap_slam_2"],
		[0, &"leap_slam_3"],
	]:
		var w := FinalLab.arena(FinalLab.run_state(40))
		w.actors.invuln[0] = NemesisLab.LONG
		FinalLab.past_rise(w)
		if pair[0] > 0:
			FinalBoss.jump(w, pair[0])
			FinalLab.past_rise(w)
		var i := FinalLab.body(w)
		w.actors.set_pos(0, w.actors.pos(i) + Vector2(6, 0))
		var t := BossAi.table_of(w, i)
		BossAi.start_attack(w, i, t.attack_index(pair[1]))
		var most := 0
		var limits := 0
		var at := w.player_pos()
		for k in 900:
			var seq := w.last_event_seq()
			if w.actors.state[i] != EnemyAi.State.WINDUP:  # out of a leap's landing (a dodge), so its rings fly
				w.actors.set_pos(0, at + Vector2(0, 5))
			w.step(InputFrame.new())
			for e in w.events_since(seq):
				if e.kind == SimEvent.Kind.LIMIT and e.effect_id == BulletPatterns.EFFECT_CAP:
					limits += 1
			var n := 0
			for p in w.projectiles.size():
				if w.projectiles.team[p] != ActorStore.TEAM_PLAYER:
					n += 1
			most = maxi(most, n)
			w.actors.cd[i] = 1 << 20
		gut.p(
			"N2 shots %s: at most %d hostile shots alive, %d cap events" % [pair[1], most, limits]
		)
		assert_lt(most, BulletPatterns.MAX_ALIVE, "%s: under the cap" % pair[1])
		assert_eq(limits, 0, "%s: never capped" % pair[1])


## BladeRun, and on a Gun run it holds the trigger whenever it would swing.
class Hero:
	extends BP.BladeRun

	func frame(w: World) -> InputFrame:
		var f := super.frame(w)
		if (
			f.pressed & InputFrame.PRIMARY
			and PlayerBuild.has_gun(w)
			and not PlayerBuild.has_blade(w)
		):
			f.held |= InputFrame.SHOOT
		return f


# --- v0.9.5 BH1 (Q11, HC7): each finished loop (up to 3) eases the final fight -----------------------------------


func test_each_finished_loop_cuts_the_target_time_12_percent_and_the_floor_with_it() -> void:
	var t := _table(&"colossus")
	var w := FinalLab.arena(FinalLab.run_state(31))
	for n in 6:
		w.loop = 1 + n
		var k := mini(n, 3)
		assert_eq(FinalPace.loops_eased(w), k, "loop %d: %d loops finished count" % [1 + n, k])
		var e := FinalPace.ease_permille(w)
		assert_eq(e, 1000 - 120 * k)
		assert_eq(
			FinalPace.seconds_at(30000, t, e), 7200 * e / 1000, "the base hero, loop %d" % [1 + n]
		)
		assert_eq(FinalPace.seconds_at(3000000, t, e), 3600 * e / 1000, "the floor falls with it")
		assert_eq(FinalPace.hp_for(30000, t, e), 3600 * e / 1000, "30 dps x the eased time")
	assert_eq(FinalPace.seconds_at(30000, t, 1000), 7200, "no ease: as before")
	w.loop = 4
	assert_eq(FinalPace.ease_permille(w), 640, "three loops: -36 %")
	assert_eq(FinalPace.seconds_at(30000, t, 640), 4608, "76.8 s")


func test_each_finished_loop_cuts_the_final_bodies_damage_8_percent() -> void:
	for n in 5:
		var w := FinalLab.arena(FinalLab.run_state(31, &"blade", 1 + n))
		var i := FinalLab.body(w)
		assert_eq(w.loop, 1 + n)
		var k := mini(n, 3)
		assert_eq(FinalPace.damage_ease_permille(w), 1000 - 80 * k)
		var want := CatchUp.damage_permille(w.catch_up.boss) * (1000 - 80 * k) / 1000
		assert_eq(w.actors.power[i], want, "loop %d: x%d per mille" % [1 + n, 1000 - 80 * k])
