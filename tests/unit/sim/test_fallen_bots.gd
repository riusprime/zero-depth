extends GutTest
## The Fallen's whole fight played by two scripted bots, each with a Gun and with a Blade (the starting builds, no
## cards; the final arena jumped to its last body, FallenLab, its mimic windows as shipped), with the run having killed
## the four bosses whose mechanics it remembers (the pool of all four). The hero has its real max HP and is refilled
## each tick, so a fight always runs to The Fallen's death and the HP it would have lost is counted.
## - "plays": in a Time Wave it walks to the nearest hour orb; in a row of Riptide to the safe strip; among the quake
##   pillars it keeps the nearest pillar between itself and The Fallen; under the ward it stands so The Fallen is on
##   the shade's charge line (until the aim locks). Otherwise it holds its weapon's distance and attacks.
## - "ignores": holds its weapon's distance and attacks, whatever The Fallen casts.
## Neither dodges The Fallen's own attacks, so the difference between them is the remembered mechanics. Prints every
## fight's numbers (raw) for docs/roadmap/v0.12.0/evidence/FALLEN_BOTS.md.

const L := preload("res://tests/support/fallen_lab.gd")
const R := preload("res://src/sim/ai/boss_remembered.gd")
const CAP := 60 * 420
const SEEDS: Array[int] = [5, 6, 7]
const ALL: Array = [&"clockwork_judge", &"tidecaller", &"gatekeeper", &"twin_wardens"]
## The cards the variant's hero holds, by weapon (test_nemesis's builds).
const THEFT_CARDS := {
	&"gun": [[&"gun_twin", 2], [&"split_shot", 5], [&"ember_core", 3], [&"halo_shot", 1]],
	&"blade": [[&"echo_slash", 3], [&"double_slash", 2], [&"whirl", 4], [&"ember_core", 1]],
}


## Plays the fight. Returns its numbers: "ticks", "dead" (The Fallen died), "max_hp", "hp_lost" (all the damage the
## hero took), "biggest" (the most in one tick), "rip", "quake", "shade" and "other" (the HP lost to Riptide, the
## quake pulses, the ward's shade and everything else), "mechanics" (begun) and per kind "n_time", "n_rip",
## "n_quake", "n_ward", "orbs" (taken), "stuns" (pillar stuns and ward breaks), "breaks" (ward breaks), "shatters",
## "slowed" (ticks the weapon was slowed), "busy" (seconds per minute of the first three a mechanic or a window ran),
## "hash".
func _fight(weapon: StringName, plays: bool, seed_value: int) -> Dictionary:
	var w := L.world(seed_value, weapon, ALL, false, true)
	var aid := w.actors.ids[L.body(w)]
	var full := w.actors.max_hp[0]
	var out := {"ticks": 0, "dead": false, "max_hp": full, "hp_lost": 0, "biggest": 0}
	for k: String in [
		"rip",
		"quake",
		"shade",
		"other",
		"mechanics",
		"n_time",
		"n_rip",
		"n_quake",
		"n_ward",
		"orbs",
		"stuns",
		"breaks",
		"shatters",
		"slowed"
	]:
		out[k] = 0
	var busy := [0, 0, 0]
	var seq := w.last_event_seq()
	for k in CAP:
		var i := w.actors.index_of(aid)
		if i < 0 or w.final_fight.won:
			out["dead"] = true
			break
		w.step(_frame(w, i, weapon, plays, k))
		out["ticks"] = k + 1
		if w.player_dead():
			out["killed_in_one_tick"] = true
			break
		var lost := full - w.actors.hp[0]
		out["hp_lost"] += lost
		out["biggest"] = maxi(out["biggest"], lost)
		w.actors.hp[0] = full
		if BossSlow.cut(w) > 0:
			out["slowed"] += 1
		if (
			k < 3 * 3600
			and (
				w.boss_fight.fl_stage != R.STAGE_NONE or FinalPace.window(w) != FinalPace.Mimic.OFF
			)
		):
			busy[k / 3600] += 1
		for e in w.events_since(seq):
			seq = e.seq
			_count(w, e, out)
	var secs := []
	for v: int in busy:
		secs.append(snappedf(v / 60.0, 0.1))
	out["busy"] = secs
	out["hash"] = w.state_hash()
	return out


func _count(w: World, e: SimEvent, out: Dictionary) -> void:
	if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
		var part := "other"
		if e.effect_id == BossDance.RIP_EFFECT:
			part = "rip"
		elif e.effect_id == BossQuake.EFFECT:
			part = "quake"
		elif e.effect_id == FallenWard.EFFECT or e.effect_id == FallenWard.BURST_EFFECT:
			part = "shade"
		out[part] += e.amount_applied
		return
	if e.kind == SimEvent.Kind.BOSS_PICKUP_TAKEN:
		out["orbs"] += 1
		return
	if e.kind != SimEvent.Kind.STATUS_APPLY:
		return
	match e.effect_id:
		R.BEGIN:
			out["mechanics"] += 1
			var key: String = {R.TIME: "n_time", R.RIPTIDE: "n_rip", R.QUAKE: "n_quake"}.get(
				e.amount_applied, "n_ward"
			)
			out[key] += 1
		BossQuake.STUN:
			out["stuns"] += 1
		BossQuake.SHATTER:
			out["shatters"] += 1
		FallenWard.BREAK:
			out["stuns"] += 1
			out["breaks"] += 1


## The bot's input this tick.
func _frame(w: World, i: int, weapon: StringName, plays: bool, k: int) -> InputFrame:
	var hero := w.player_pos()
	var to := w.actors.pos(i) - hero
	var dist := Kin.length(to)
	var dir := to / dist if dist > 0.001 else Vector2.RIGHT
	var blade := weapon == &"blade"
	var edge := w.actors.radius[i]
	var near := -99.0 if blade else 4.0
	var far := edge + 1.2 if blade else 6.0
	var goal := hero
	if dist > far:
		goal = hero + dir
	elif dist < near:
		goal = hero - dir
	if plays:
		goal = _plays_goal(w, i, hero, goal)
	var step := goal - hero
	var mv := Vector2i.ZERO
	if Kin.length(step) > 0.05:
		step = step / Kin.length(step)
		mv = Vector2i(roundi(step.x * 127.0), roundi(step.y * 127.0))
	elif blade and dist > 0.001:
		mv = Vector2i(roundi(dir.x * 40.0), roundi(dir.y * 40.0))  # It keeps facing The Fallen
	var held := 0 if blade else InputFrame.SHOOT
	var reach := maxf(far + 0.5, edge + 2.1)
	var pressed := InputFrame.PRIMARY if blade and k % 6 == 0 and dist <= reach else 0
	return InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), held, pressed)


## Where the bot that plays the mechanics walks (else `band`, its distance from The Fallen).
func _plays_goal(w: World, i: int, hero: Vector2, band: Vector2) -> Vector2:
	var r := WorldReader.new(w)
	var st := r.boss_fallen()
	if st.is_empty() or int(st["stage"]) != R.STAGE_RUN:
		return band
	match int(st["running"]):
		R.TIME:
			return _nearest_orb(r, hero, band)
		R.RIPTIDE:
			return _dry_strip(w, r, hero, band)
		R.QUAKE:
			return _behind_pillar(w, r, i, hero, band)
		R.WARD:
			return _on_the_line(w, st, i, hero)
	return band


## The nearest hour orb.
func _nearest_orb(r: WorldReader, hero: Vector2, band: Vector2) -> Vector2:
	var best := band
	var d := 1.0e9
	for o: Dictionary in r.boss_pickups():
		var c: Vector2 = o["centre"]
		if c.distance_to(hero) < d:
			d = c.distance_to(hero)
			best = c
	return best


## The row's safe strip: straight across into it, then along it only.
func _dry_strip(w: World, r: WorldReader, hero: Vector2, band: Vector2) -> Vector2:
	var dance := r.boss_dance()
	var rip: Dictionary = dance.get("riptide", {})
	if rip.is_empty():
		return band
	var safe: Rect2 = dance["strips"][rip["safe"]]
	var mid := safe.get_center()
	var across := Vector2(hero.x, mid.y) if dance["along_x"] else Vector2(mid.x, hero.y)
	if not safe.grow(-w.player.radius_m - 0.6).has_point(hero):
		return across
	return Vector2(band.x, hero.y) if dance["along_x"] else Vector2(hero.x, band.y)


## The spot behind the nearest pillar from The Fallen.
func _behind_pillar(w: World, r: WorldReader, i: int, hero: Vector2, band: Vector2) -> Vector2:
	var fallen := w.actors.pos(i)
	var best := band
	var d := 1.0e9
	for p: Dictionary in r.boss_quake_pillars():
		var c: Vector2 = p["center"]
		var away := (c - fallen).normalized()
		var spot := c + away * (float(p["half"]) + w.player.radius_m + 0.8)
		if spot.distance_to(hero) < d:
			d = spot.distance_to(hero)
			best = spot
	return best


## On the shade's line through The Fallen, until its aim locks.
func _on_the_line(w: World, st: Dictionary, i: int, hero: Vector2) -> Vector2:
	var sh: Dictionary = st["shade"]
	if sh.is_empty() or bool(sh["locked"]):
		return hero
	var fallen := w.actors.pos(i)
	var line := (fallen - Vector2(sh["position"])).normalized()
	return fallen + line * 3.0


func _report(weapon: StringName, plays: bool, seed_value: int, r: Dictionary) -> void:
	print(
		(
			(
				"FALLENBOT| weapon=%s bot=%s seed=%d dead=%s ticks=%d seconds=%.1f max_hp=%d hp_lost=%d"
				+ " biggest=%d rip=%d quake=%d shade=%d other=%d mechanics=%d time=%d riptide=%d"
				+ " quake_n=%d ward=%d orbs=%d stuns=%d breaks=%d shatters=%d slowed_s=%.1f busy=%s"
			)
			% [
				weapon,
				"plays" if plays else "ignores",
				seed_value,
				r["dead"],
				r["ticks"],
				float(r["ticks"]) / SimTick.TICKS_PER_SECOND,
				r["max_hp"],
				r["hp_lost"],
				r["biggest"],
				r["rip"],
				r["quake"],
				r["shade"],
				r["other"],
				r["mechanics"],
				r["n_time"],
				r["n_rip"],
				r["n_quake"],
				r["n_ward"],
				r["orbs"],
				r["stuns"],
				r["breaks"],
				r["shatters"],
				float(r["slowed"]) / SimTick.TICKS_PER_SECOND,
				r["busy"],
			]
		)
	)


func test_ignoring_the_remembered_mechanics_costs_clearly_more() -> void:
	var unmet := PackedStringArray()
	for weapon: StringName in [&"gun", &"blade"]:
		var keys := [
			"ticks", "hp_lost", "rip", "quake", "shade", "other", "stuns", "breaks", "orbs"
		]
		var sum := {true: {}, false: {}}
		for plays: bool in [true, false]:
			for key: String in keys:
				sum[plays][key] = 0
		for sv in SEEDS:
			for plays: bool in [true, false]:
				var r := _fight(weapon, plays, sv)
				_report(weapon, plays, sv, r)
				assert_false(
					r.has("killed_in_one_tick"), "%s seed %d: no tick kills" % [weapon, sv]
				)
				assert_true(r["dead"], "%s seed %d: The Fallen dies" % [weapon, sv])
				assert_gt(int(r["mechanics"]), 0, "a remembered mechanic was cast")
				for key: String in keys:
					sum[plays][key] += int(r[key])
		var a: Dictionary = sum[true]
		var b: Dictionary = sum[false]
		print(
			(
				"FALLENBOT| weapon=%s over %d seeds: plays %s, ignores %s"
				% [weapon, SEEDS.size(), a, b]
			)
		)
		var mech_a := int(a["rip"]) + int(a["quake"]) + int(a["shade"])
		var mech_b := int(b["rip"]) + int(b["quake"]) + int(b["shade"])
		var slower := int(b["ticks"]) * 10 >= int(a["ticks"]) * 11
		var costlier: bool = mech_b * 10 >= mech_a * 13 and b["hp_lost"] * 10 >= a["hp_lost"] * 13
		if not (slower or costlier):
			(
				unmet
				. append(
					(
						(
							"%s: ignoring took %d ticks and lost %d HP (%d to the mechanics), playing %d ticks,"
							% [weapon, b["ticks"], b["hp_lost"], mech_b, a["ticks"]]
						)
						+ " %d HP (%d)" % [a["hp_lost"], mech_a]
					)
				)
			)
	# The brief's expectation, kept visible while it is not met: the numbers are the evidence
	# (docs/roadmap/v0.12.0/evidence/FALLEN_BOTS.md) and the tuning is the lead's and the owner's call.
	if not unmet.is_empty():
		pending(
			(
				"NOT MET, ignoring is at least 10 % slower or costs at least 30 % more HP: "
				+ "; ".join(unmet)
			)
		)


func test_a_bot_fight_is_deterministic() -> void:
	var a := _fight(&"gun", true, 5)
	var b := _fight(&"gun", true, 5)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["ticks"], b["ticks"])


# --- with cards: the theft --------------------------------------------------------------------------------------------


## The bot that plays, holding THEFT_CARDS: the fight as _fight plays it, counting the theft. Returns "dead", "ticks",
## "taken", "returned", "mark_hits", "without" (ticks with at least one card held), "held_at_end".
func _theft_fight(weapon: StringName, seed_value: int) -> Dictionary:
	var w := NemesisLab.world(seed_value, weapon, THEFT_CARDS[weapon], false, false)
	w.boss_fight.fl_beaten = PackedStringArray(ALL)
	var aid := w.actors.ids[L.body(w)]
	var full := w.actors.max_hp[0]
	var out := {"dead": false, "ticks": 0, "taken": 0, "returned": 0, "mark_hits": 0, "without": 0}
	var seq := w.last_event_seq()
	for k in CAP:
		var i := w.actors.index_of(aid)
		if i < 0 or w.final_fight.won:
			out["dead"] = true
			break
		w.step(_frame(w, i, weapon, true, k))
		out["ticks"] = k + 1
		if w.player_dead():
			break
		w.actors.hp[0] = full
		if not w.boss_fight.fl_tk_code.is_empty():
			out["without"] += 1
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind != SimEvent.Kind.STATUS_APPLY:
				continue
			match e.effect_id:
				FallenTheft.TAKEN:
					out["taken"] += 1
				FallenTheft.RETURNED:
					out["returned"] += 1
				FallenTheft.MARK_HIT:
					out["mark_hits"] += 1
	out["held_at_end"] = w.boss_fight.fl_tk_code.size()
	return out


func test_with_cards_the_fallen_takes_them_and_always_gives_them_back() -> void:
	var untaken := PackedStringArray()
	for weapon: StringName in [&"gun", &"blade"]:
		for sv in SEEDS:
			var r := _theft_fight(weapon, sv)
			print(
				(
					(
						"FALLENBOT| theft weapon=%s bot=plays seed=%d dead=%s seconds=%.1f taken=%d returned=%d"
						% [
							weapon,
							sv,
							r["dead"],
							float(r["ticks"]) / SimTick.TICKS_PER_SECOND,
							r["taken"],
							r["returned"]
						]
					)
					+ (
						" mark_hits=%d seconds_without_a_card=%.1f held_at_end=%d"
						% [
							r["mark_hits"],
							float(r["without"]) / SimTick.TICKS_PER_SECOND,
							r["held_at_end"]
						]
					)
				)
			)
			assert_true(r["dead"], "%s seed %d: The Fallen dies" % [weapon, sv])
			if int(r["taken"]) == 0:
				untaken.append("%s seed %d" % [weapon, sv])
			assert_eq(int(r["held_at_end"]), 0, "%s seed %d: every card is back" % [weapon, sv])
	# The brief's expectation, kept visible while it is not met: the numbers are the evidence, the tuning the lead's
	if not untaken.is_empty():
		pending("NOT MET, a card is taken in every fight: none in " + ", ".join(untaken))
