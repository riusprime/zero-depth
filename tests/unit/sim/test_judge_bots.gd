extends GutTest
## The Clockwork Judge's whole fight played by two scripted bots, each with a Gun and with a Blade (the starting
## builds, no items; the real compiled Judge in a 24 m walled room, JudgeLab; no floor scaling). The hero never dies
## (its HP is refilled each tick), so a fight always runs to the Judge's death and the HP it would have lost is
## counted.
## - "plays": while it has attack speed to win back it walks to the nearest hour orb (round the stopped gears), and
##   it steps out of a locked Bell's Verdict square it stands in (the square the Bell threw it onto). Otherwise it
##   holds its weapon's distance and attacks.
## - "ignores": holds its weapon's distance and attacks; it never walks to an orb and never leaves a square on
##   purpose.
## Neither dodges anything else (the Gavel Slam, the echo and the spirals hit both), so the difference between them
## is the new mechanics. Prints every fight's numbers (raw) for docs/roadmap/v0.12.0/evidence/JUDGE_BOTS.md.

const S := EnemyAi.State
const CAP := 60 * 900
const SEEDS: Array[int] = [5, 6, 7]
## The base hero's HP (data/player/runner.tres): what a hit is measured against.
const BASE_HP := 100


## Plays the fight. Returns its numbers: "ticks", "dead" (the Judge died), "hp_lost" (the damage the hero took),
## "biggest" (the most in one tick) and "biggest_in" (the Judge's attack then), "waves", "orbs" (taken), "snaps" (Bell
## throws), "snaps_in_verdict" (throws that landed inside a Verdict's square while it wound up), "verdict_hits",
## "verdict_hits_after_snap" (those in a Verdict the hero was thrown during), "verdict_cost" (the most HP the tick
## of a Verdict's hit cost), "bell_verdicts" (the Bell's Verdicts that dropped), "bell_hits" (those that hit) and
## "bell_cost" (the most one cost: what one miss of the signature costs), "hash".
func _fight(weapon: StringName, plays: bool, seed_value: int) -> Dictionary:
	var w := JudgeLab.world(seed_value)
	ContentCompiler.apply_build(w.player, SharedContent.repo().get_def(&"build", weapon))
	var aid := w.actors.ids[BossLab.ready_boss(w, &"clockwork_judge", Vector2(6, 0))]
	w.actors.set_pos(0, Vector2(-4, 0))
	w.actors.hp[0] = JudgeLab.LONG
	w.actors.max_hp[0] = JudgeLab.LONG
	var out := {"ticks": 0, "dead": false, "hp_lost": 0, "biggest": 0, "waves": 0, "orbs": 0}
	out["biggest_in"] = &""
	for k: String in [
		"snaps",
		"snaps_in_verdict",
		"verdict_hits",
		"verdict_hits_after_snap",
		"verdict_cost",
		"bell_verdicts",
		"bell_hits",
		"bell_cost"
	]:
		out[k] = 0
	var seq := 0
	var thrown := false
	var verdict := BossAi.table_of(w, w.actors.index_of(aid)).attack_index(&"verdict")
	for k in CAP:
		var i := w.actors.index_of(aid)
		if i < 0:
			out["dead"] = true
			break
		w.step(_frame(w, i, weapon, plays, k))
		out["ticks"] = k + 1
		var lost := JudgeLab.LONG - w.actors.hp[0]
		out["hp_lost"] += lost
		w.actors.hp[0] = JudgeLab.LONG
		i = w.actors.index_of(aid)
		var b := BossAi.entry_of(w, i) if i >= 0 else -1
		if lost > out["biggest"]:
			out["biggest"] = lost
			var now := BossAi.attack_of(w, i) if i >= 0 else null
			out["biggest_in"] = now.id if now != null else &"none"
		var in_verdict := b >= 0 and w.bosses.attack[b] == verdict
		if not in_verdict or w.actors.state[i] == S.RECOVER:
			thrown = false
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.BOSS_PICKUP_TAKEN:
				out["orbs"] += 1
			elif e.kind != SimEvent.Kind.STATUS_APPLY:
				continue
			elif e.effect_id == BossTime.WAVE:
				out["waves"] += 1
			elif e.effect_id == BossRewind.BELL_VERDICT:
				out["bell_verdicts"] += 1
				out["bell_hits"] += 1 if e.amount > 0 else 0
				out["bell_cost"] = maxi(out["bell_cost"], e.amount)
			elif e.effect_id == BossRewind.SNAP:
				out["snaps"] += 1
				if in_verdict and w.actors.state[i] == S.WINDUP and _in_square(w, i):
					out["snaps_in_verdict"] += 1
					thrown = true
		# The tick the pendulum hit (the hit-stop's frozen ticks after it lose nothing, so it counts once)
		if in_verdict and w.actors.state[i] == S.ACTIVE and w.actors.state_t[i] == 0:
			if w.bosses.hit[b] == 1 and lost > 0:
				out["verdict_hits"] += 1
				out["verdict_hits_after_snap"] += 1 if thrown else 0
				out["verdict_cost"] = maxi(out["verdict_cost"], lost)
	out["hash"] = w.state_hash()
	return out


## True while the hero touches the Verdict square of boss i.
func _in_square(w: World, i: int) -> bool:
	var sq := BossJudge.verdict_square(w, i, BossAi.attack_of(w, i))
	return Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, sq) != Vector2.ZERO


## The bot's input this tick.
func _frame(w: World, i: int, weapon: StringName, plays: bool, k: int) -> InputFrame:
	var hero := w.player_pos()
	var to := w.actors.pos(i) - hero
	var dist := Kin.length(to)
	var dir := to / dist if dist > 0.001 else Vector2.RIGHT
	var blade := weapon == &"blade"
	var near := -99.0 if blade else 4.0
	var far := w.actors.radius[i] + 1.2 if blade else 6.0
	var goal := hero
	if dist > far:
		goal = hero + dir
	elif dist < near:
		goal = hero - dir
	if plays:
		goal = _plays_goal(w, hero, goal)
	var step := goal - hero
	var mv := Vector2i.ZERO
	if Kin.length(step) > 0.05:
		step = step / Kin.length(step)
		mv = Vector2i(roundi(step.x * 127.0), roundi(step.y * 127.0))
	elif blade and dist > 0.001:
		mv = Vector2i(roundi(dir.x * 40.0), roundi(dir.y * 40.0))  # It keeps facing the Judge
	var held := 0 if blade else InputFrame.SHOOT
	var pressed := InputFrame.PRIMARY if blade and k % 6 == 0 and dist <= far + 0.5 else 0  # Only in reach
	return InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), held, pressed)


## Where the bot that plays the mechanics walks: out of a locked Bell's Verdict square it stands in; else to the
## nearest hour orb (round a gear in the way) while it has attack speed to win back; else `band` (its distance).
func _plays_goal(w: World, hero: Vector2, band: Vector2) -> Vector2:
	for sq: Dictionary in WorldReader.new(w).boss_time().get("bell_squares", []):
		var c: Vector2 = sq["center"]
		var square := BossJudge.square_of(c, sq["half"])
		if (
			not sq["locked"]
			or Collide.circle_vs_obb(hero, w.player.radius_m, square) == Vector2.ZERO
		):
			continue
		var away := hero - c
		if Kin.length(away) > 0.01:
			return hero + away
		return hero + (band - hero if Kin.length(band - hero) > 0.01 else Vector2.RIGHT)
	if BossSlow.cut(w) <= 0:
		return band
	var best := band
	var best_d := INF
	for o: Dictionary in WorldReader.new(w).boss_pickups():
		var c: Vector2 = o["centre"]
		if c.distance_to(hero) < best_d:
			best_d = c.distance_to(hero)
			best = c
	return _around(w, hero, best) if best_d < INF else band


## The next point on the way from `from` to `to`: `to` itself, or a corner of the first gear in the way, a little
## clear of it: at the end that makes the shorter way round, first the corner on the bot's side, then (once it is
## past the gear's end) the one on the side it is going to.
func _around(w: World, from: Vector2, to: Vector2) -> Vector2:
	var r := w.player.radius_m + 0.03
	var m := w.player.radius_m + 0.07
	var line := to - from
	var length := line.length()
	var n := int(minf(length, 8.0) / 0.25)
	for s in range(1, n + 1):
		var p := from + line * (s * 0.25 / length)
		for g in w.boss_fight.gear_x.size():
			var o := BossGears.obb(w.boss_fight, g)
			if Collide.circle_vs_obb(p, r, o) == Vector2.ZERO:
				continue
			var reach := o.axis_u * (o.half.x + m)
			var by_a := from.distance_to(o.center + reach) + (o.center + reach).distance_to(to)
			var by_b := from.distance_to(o.center - reach) + (o.center - reach).distance_to(to)
			var end := 1.0 if by_a <= by_b else -1.0
			var side := 1.0 if (from - o.center).dot(o.axis_v) >= 0.0 else -1.0
			var past := (from - o.center).dot(o.axis_u) * end >= o.half.x + m - 0.05
			var far_side := 1.0 if (to - o.center).dot(o.axis_v) >= 0.0 else -1.0
			var across := o.axis_v * ((o.half.y + m) * (far_side if past else side))
			return o.center + reach * end + across
	return to


func _report(weapon: StringName, plays: bool, seed_value: int, r: Dictionary) -> void:
	print(
		(
			(
				"JUDGEBOT| weapon=%s bot=%s seed=%d dead=%s ticks=%d seconds=%.1f hp_lost=%d biggest=%d"
				+ " biggest_in=%s waves=%d orbs=%d snaps=%d snaps_in_verdict=%d verdict_hits=%d"
				+ " verdict_hits_after_snap=%d verdict_cost=%d bell_verdicts=%d bell_hits=%d bell_cost=%d"
			)
			% [
				weapon,
				"plays" if plays else "ignores",
				seed_value,
				r["dead"],
				r["ticks"],
				float(r["ticks"]) / SimTick.TICKS_PER_SECOND,
				r["hp_lost"],
				r["biggest"],
				r["biggest_in"],
				r["waves"],
				r["orbs"],
				r["snaps"],
				r["snaps_in_verdict"],
				r["verdict_hits"],
				r["verdict_hits_after_snap"],
				r["verdict_cost"],
				r["bell_verdicts"],
				r["bell_hits"],
				r["bell_cost"],
			]
		)
	)


func test_ignoring_the_time_mechanics_costs_clearly_more() -> void:
	for weapon: StringName in [&"gun", &"blade"]:
		var sum := {
			true: {"ticks": 0, "hp_lost": 0, "orbs": 0},
			false: {"ticks": 0, "hp_lost": 0, "orbs": 0}
		}
		for sv in SEEDS:
			for plays: bool in [true, false]:
				var r := _fight(weapon, plays, sv)
				_report(weapon, plays, sv, r)
				assert_true(r["dead"], "%s seed %d: the Judge dies" % [weapon, sv])
				assert_gt(int(r["waves"]), 0, "a Time Wave landed")
				assert_lte(
					maxi(int(r["verdict_cost"]), int(r["bell_cost"])),
					BASE_HP * 40 / 100,
					(
						(
							"%s seed %d: a Verdict's hit (what a missed Rewind costs) is at most 40 %% of"
							% [weapon, sv]
						)
						+ " the base hero's HP"
					)
				)
				for key: String in sum[plays]:
					sum[plays][key] += int(r[key])
		var a: Dictionary = sum[true]
		var b: Dictionary = sum[false]
		print(
			"JUDGEBOT| weapon=%s over %d seeds: plays %s, ignores %s" % [weapon, SEEDS.size(), a, b]
		)
		assert_gt(int(a["orbs"]), int(b["orbs"]), "%s: the bot that plays takes the orbs" % weapon)
		assert_true(
			b["ticks"] * 10 >= a["ticks"] * 13 or b["hp_lost"] * 10 >= a["hp_lost"] * 13,
			"%s: ignoring them takes at least 30 %% longer or costs at least 30 %% more HP" % weapon
		)


func test_a_bot_fight_is_deterministic() -> void:
	var a := _fight(&"gun", true, 5)
	var b := _fight(&"gun", true, 5)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["ticks"], b["ticks"])
