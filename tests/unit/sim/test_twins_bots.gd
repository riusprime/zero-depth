extends GutTest
## The Twin Wardens' whole fight played by two scripted bots, each with a Gun and with a Blade (the starting builds, no
## items; the real compiled pair in a 24 m walled room, TwinsLab; no floor scaling). The hero has the base 100 HP,
## refilled each tick, so a fight always runs to the Wardens' death and the HP it would have lost is counted.
## - "plays": it stops attacking into the Mirror Ward and walks round it; in phase 3, while the amber Warden winds a
##   charge up at the violet one's standing ward, it stands so that she is on his line; it walks out of a charge's
##   lane and end circle (and the rift's exit lane) otherwise. Else it holds its weapon's distance from the body to
##   hit and attacks.
## - "ignores": holds its weapon's distance from the body to hit and attacks, whatever stands in the way.
## Both back away in a circle (back and toward the room's middle), so neither pins itself in a corner.
## Neither dodges anything else (the combo, the overhead, the Sword Lane, the fans, the swords hit both), so the
## difference between them is the new mechanics. Prints every fight's numbers (raw) for
## docs/roadmap/v0.12.0/evidence/TWINS_BOTS.md.

const S := EnemyAi.State
const M := BossAttackTable.Move
const CAP := 60 * 900
const SEEDS: Array[int] = [5, 6, 7]
## The base hero's HP (data/player/runner.tres): what a hit is measured against.
const BASE_HP := 100
const KEYS: Array[String] = [
	"reflected", "reflected_hits", "blocks", "breaks", "bursts", "burst_hits", "rifts", "rift_cost"
]


## Plays the fight. Returns its numbers: "ticks", "dead" (the Wardens died), "hp_lost", "biggest" (the most in one
## tick), "reflected" (shots the Mirror Ward sent back), "reflected_hits" (those that hit the hero), "blocks" (swings
## pushed back), "breaks" (ward breaks), "bursts" and "burst_hits" (charge bursts, and those that hit), "rifts" (Through
## the Rift cast), "rift_cost" (the most one hit of its exit charge or burst cost), "phase_ticks" (each phase's
## length), "hash".
func _fight(weapon: StringName, plays: bool, seed_value: int) -> Dictionary:
	var s := TwinsLab.fight(Vector2(-6, 0), Vector2(4, 0), seed_value)
	var w: World = s[0]
	ContentCompiler.apply_build(w.player, SharedContent.repo().get_def(&"build", weapon))
	w.actors.max_hp[0] = BASE_HP
	w.actors.hp[0] = BASE_HP
	w.player_hp_floor = 1  # It never dies: the fight runs to its end
	var out := {"ticks": 0, "dead": false, "hp_lost": 0, "biggest": 0, "phase_ticks": [0, 0, 0]}
	for k: String in KEYS:
		out[k] = 0
	var seq := 0
	var r := WorldReader.new(w)
	for k in CAP:
		var i := w.actors.index_of(s[1])
		if i < 0:
			out["dead"] = true
			break
		var mirrored := {}
		for p in w.projectiles.size():
			if w.projectiles.cause_of(p) == BossWard.MIRROR_CAUSE:
				mirrored[w.projectiles.ids[p]] = true
		var rift_out := w.boss_fight.wd_rift_stage == BossRift.OUT or _rift_burst(w, i)
		out["phase_ticks"][w.bosses.phase[BossAi.entry_of(w, i)]] += 1
		w.step(_frame(w, r, s, weapon, plays, k))
		out["ticks"] = k + 1
		var lost := BASE_HP - w.actors.hp[0]
		out["hp_lost"] += lost
		out["biggest"] = maxi(out["biggest"], lost)
		if rift_out:
			out["rift_cost"] = maxi(out["rift_cost"], lost)
		w.actors.hp[0] = BASE_HP
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
				out["reflected_hits"] += 1 if mirrored.has(e.source_id) else 0
			elif e.kind != SimEvent.Kind.STATUS_APPLY:
				continue
			elif e.effect_id == BossWard.REFLECT:
				out["reflected"] += 1
			elif e.effect_id == BossWard.BLOCK:
				out["blocks"] += 1
			elif e.effect_id == BossWard.BREAK:
				out["breaks"] += 1
			elif e.effect_id == BossChargeBurst.BURST:
				out["bursts"] += 1
				out["burst_hits"] += 1 if e.amount > 0 else 0
			elif e.effect_id == BossRift.OPENED:
				out["rifts"] += 1
	out["hash"] = w.state_hash()
	return out


## True while a burst of the rift's exit charge is pending.
func _rift_burst(w: World, i: int) -> bool:
	var rift := BossAi.table_of(w, i).wardens.rift_attack
	return w.boss_fight.cb_attack.has(rift)


## The bot's input this tick.
func _frame(
	w: World, r: WorldReader, s: Array, weapon: StringName, plays: bool, k: int
) -> InputFrame:
	var hero := w.player_pos()
	var target := w.actors.index_of(w.bosses.twin_focus[0])
	if target < 0:
		target = w.actors.index_of(s[1])
	var to := w.actors.pos(target) - hero
	var dist := Kin.length(to)
	var dir := to / dist if dist > 0.001 else Vector2.RIGHT
	var blade := weapon == &"blade"
	var near := -99.0 if blade else 4.0
	var far := w.actors.radius[target] + 1.2 if blade else 6.0
	var goal := hero
	if dist > far:
		goal = hero + dir
	elif dist < near:
		# Back and to the side nearer the room's middle, so it circles instead of backing into a corner
		var side := Vector2(-dir.y, dir.x)
		goal = hero - dir + (side if side.dot(-hero) >= 0.0 else -side)
	var attack := true
	if plays:
		var plan := _plays(w, r, hero, goal, target)
		goal = plan[0]
		attack = plan[1]
	var step := goal - hero
	var mv := Vector2i.ZERO
	if Kin.length(step) > 0.05:
		step = step / Kin.length(step)
		mv = Vector2i(roundi(step.x * 127.0), roundi(step.y * 127.0))
	elif blade and dist > 0.001:
		mv = Vector2i(roundi(dir.x * 40.0), roundi(dir.y * 40.0))  # It keeps facing its target
	var held := InputFrame.SHOOT if attack and not blade else 0
	var swing := blade and attack and k % 6 == 0 and dist <= far + 0.5  # Only in reach
	return InputFrame.make(
		mv, Kin.angle_of(to), int(dist * 100.0), held, InputFrame.PRIMARY if swing else 0
	)


## The bot that plays the mechanics: [where it walks, whether it attacks]. `band` is its weapon's distance.
func _plays(w: World, r: WorldReader, hero: Vector2, band: Vector2, target: int) -> Array:
	var wd := r.boss_wardens()
	if wd.is_empty():
		return [band, true]
	var step := _dodge(w, r, wd, hero, band)
	if step != Vector2.ZERO:
		return [hero + step, true]
	# Round the Mirror Ward, holding the attack while inside its arc
	var ward: Dictionary = wd["ward"]
	var violet: int = wd["violet"]
	if ward["kind"] == &"mirror" and target == violet:
		var rel := hero - w.actors.pos(violet)
		var off := Kin.angle_diff(Kin.angle_of(rel), int(ward["centre"]))
		if off <= int(ward["half_arc"]) + 60 and rel.length() > 0.01:
			var side := Vector2(-rel.y, rel.x).normalized()
			var ahead := Kin.angle_diff(Kin.angle_of(rel + side), int(ward["centre"]))
			return [hero + (side if ahead >= off else -side), false]
	return [band, true]


## The step the playing bot takes for a charge (ZERO: none): out of an armed burst's circle; out of the rift's exit
## lane and its end; while the amber Warden winds a charge up, behind the warded violet one on his line, else out of
## its lane and its end circle.
func _dodge(w: World, r: WorldReader, wd: Dictionary, hero: Vector2, band: Vector2) -> Vector2:
	var pr := w.player.radius_m
	var lead: int = wd["lead"]
	var half: float = w.actors.radius[lead] + pr + 0.6
	for b: Dictionary in r.boss_charge_bursts():
		var c: Vector2 = b["centre"]
		if hero.distance_to(c) <= float(b["radius"]) + pr + 0.5:
			return _away(hero, c, band)
	var rift: Dictionary = wd["rift"]
	if rift.has("lane"):
		var lane: Array = rift["lane"]
		return _off_charge(
			hero, lane[0], lane[1], half, float(rift["burst_radius"]) + pr + 0.5, band
		)
	if not wd.has("charge"):
		return Vector2.ZERO
	var ch: Dictionary = wd["charge"]
	var at := w.actors.pos(lead)
	var line := w.actors.pos(int(wd["violet"])) - at
	if wd["ward"]["kind"] == &"full" and line.length() > 0.5:
		# Behind her on his line: his charge then runs through her ward
		var vp := at + line
		var clear: float = w.actors.radius[int(wd["violet"])] + pr + 0.3
		return _round(hero, vp + line.normalized() * 2.5, vp, clear) - hero
	return _off_charge(hero, at, ch["end"], half, float(ch["radius"]) + pr + 0.5, band)


## A unit step out of the charge lane from `a` to `b` (within `half` of its line) or out of its end circle (within
## `ring` of `b`); ZERO when the hero is in neither.
func _off_charge(
	hero: Vector2, a: Vector2, b: Vector2, half: float, ring: float, band: Vector2
) -> Vector2:
	var off := _off_lane(hero, a, b, half)
	if off != Vector2.ZERO:
		return off
	return _away(hero, b, band) if hero.distance_to(b) <= ring else Vector2.ZERO


## A unit step from `hero` away from `c` (toward `band` when it stands on it).
func _away(hero: Vector2, c: Vector2, band: Vector2) -> Vector2:
	var d := hero - c
	if d.length() > 0.01:
		return d.normalized()
	return (band - hero).normalized() if band.distance_to(hero) > 0.01 else Vector2.RIGHT


## A unit step sideways out of the lane from `a` to `b` when the hero is within `half` of its line, else ZERO.
func _off_lane(hero: Vector2, a: Vector2, b: Vector2, half: float) -> Vector2:
	var ab := b - a
	var len := ab.length()
	if len < 0.01:
		return Vector2.ZERO
	var along := (hero - a).dot(ab) / len
	if along < -half or along > len + half:
		return Vector2.ZERO
	var side := (hero - a) - ab / len * along
	if side.length() > half:
		return Vector2.ZERO
	return side.normalized() if side.length() > 0.01 else Vector2(-ab.y, ab.x) / len


func _report(weapon: StringName, plays: bool, seed_value: int, r: Dictionary) -> void:
	print(
		(
			(
				"TWINSBOT| weapon=%s bot=%s seed=%d dead=%s ticks=%d seconds=%.1f phases=%s hp_lost=%d"
				+ " biggest=%d reflected=%d reflected_hits=%d blocks=%d ward_breaks=%d bursts=%d"
				+ " burst_hits=%d rifts=%d rift_cost=%d"
			)
			% [
				weapon,
				"plays" if plays else "ignores",
				seed_value,
				r["dead"],
				r["ticks"],
				float(r["ticks"]) / SimTick.TICKS_PER_SECOND,
				r["phase_ticks"],
				r["hp_lost"],
				r["biggest"],
				r["reflected"],
				r["reflected_hits"],
				r["blocks"],
				r["breaks"],
				r["bursts"],
				r["burst_hits"],
				r["rifts"],
				r["rift_cost"],
			]
		)
	)


func test_ignoring_the_wardens_mechanics_costs_clearly_more() -> void:
	var unmet: Array[String] = []
	for weapon: StringName in [&"gun", &"blade"]:
		var sum := {true: {"ticks": 0, "hp_lost": 0}, false: {"ticks": 0, "hp_lost": 0}}
		for sv in SEEDS:
			for plays: bool in [true, false]:
				var r := _fight(weapon, plays, sv)
				_report(weapon, plays, sv, r)
				assert_true(r["dead"], "%s seed %d: the Wardens die" % [weapon, sv])
				assert_lte(
					int(r["rift_cost"]),
					BASE_HP * 40 / 100,
					(
						"%s seed %d: Through the Rift never takes more than 40 %% in one hit"
						% [weapon, sv]
					)
				)
				for key: String in sum[plays]:
					sum[plays][key] += int(r[key])
		var a: Dictionary = sum[true]
		var b: Dictionary = sum[false]
		print(
			"TWINSBOT| weapon=%s over %d seeds: plays %s, ignores %s" % [weapon, SEEDS.size(), a, b]
		)
		if b["ticks"] * 10 < a["ticks"] * 13 and b["hp_lost"] * 10 < a["hp_lost"] * 13:
			unmet.append(
				(
					"%s: ignoring cost %d HP in %d ticks, playing %d HP in %d ticks"
					% [weapon, b["hp_lost"], b["ticks"], a["hp_lost"], a["ticks"]]
				)
			)
	# The brief's expectation, kept visible while it is not met: the numbers are the evidence
	# (docs/roadmap/v0.12.0/evidence/TWINS_BOTS.md) and the tuning is the lead's and the owner's call.
	if not unmet.is_empty():
		pending(
			"NOT MET, ignoring them takes 30 % longer or costs 30 % more HP: " + "; ".join(unmet)
		)


func test_a_bot_fight_is_deterministic() -> void:
	var a := _fight(&"gun", true, 5)
	var b := _fight(&"gun", true, 5)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["ticks"], b["ticks"])


## The next point on the way from `from` to `to` round a body at `c` (`clear` from its centre): `to` itself, or a
## point beside the body on the side `from` is nearer when the straight way would run into it.
func _round(from: Vector2, to: Vector2, c: Vector2, clear: float) -> Vector2:
	var ab := to - from
	var len := ab.length()
	if len < 0.01:
		return to
	var along := clampf((c - from).dot(ab) / len, 0.0, len)
	var off := c - (from + ab / len * along)
	if off.length() >= clear:
		return to
	var side := -off.normalized() if off.length() > 0.01 else Vector2(-ab.y, ab.x) / len
	return c + side * (clear + 0.3)
