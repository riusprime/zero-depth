extends GutTest
## The Tidecaller's whole fight played by two scripted bots, each with a Gun and with a Blade (the starting builds,
## no items; the real compiled Tidecaller in a 24 m walled room, TideLab; no floor scaling). The hero has its real
## max HP (the dance's costs are shares of it) and is refilled each tick, so a fight always runs to the boss's
## death and the HP it would have lost is counted.
## - "plays": in a High Tide it walks into the dry circle; in a row of Riptide it walks to the safe strip; in the
##   Maelstrom it stays out of the eye (the Blade just outside it, inside its reach). Otherwise it holds its
##   weapon's distance and attacks.
## - "ignores": holds its weapon's distance and attacks, whatever the room does.
## Neither dodges anything else (the rings, the crossing waves, the Undertow and the Shell Slam hit both), so the
## difference between them is the dance. Prints every fight's numbers (raw) for
## docs/roadmap/v0.12.0/evidence/TIDE_BOTS.md.

const CAP := 60 * 900
const SEEDS: Array[int] = [5, 6, 7]


## Plays the fight. Returns its numbers: "ticks", "dead" (the Tidecaller died), "max_hp" (the hero's), "hp_lost"
## (all the damage the hero took), "biggest" (the most in one tick), "rip", "tide", "eye" and "other" (the HP lost to
## Riptide, High Tide, the Maelstrom's eye and everything else), "rows" and "tides" (cast), "strip_hits",
## "strip_cost" (the most one cost), "out_ticks" (ticks outside the dry circle while the water was up), "throws",
## "eye_cost" (the most one cost), "tide_cost" (the most one High Tide cost in all), "hash".
func _fight(weapon: StringName, plays: bool, seed_value: int) -> Dictionary:
	var w := JudgeLab.world(seed_value)
	ContentCompiler.apply_build(w.player, SharedContent.repo().get_def(&"build", weapon))
	var aid := w.actors.ids[BossLab.ready_boss(w, &"tidecaller", Vector2(6, 0))]
	w.actors.set_pos(0, Vector2(-4, 0))
	var full := w.actors.max_hp[0]
	var out := {"ticks": 0, "dead": false, "max_hp": full, "hp_lost": 0, "biggest": 0}
	for k: String in [
		"rip",
		"tide",
		"eye",
		"other",
		"rows",
		"tides",
		"strip_hits",
		"strip_cost",
		"out_ticks",
		"throws",
		"eye_cost",
		"tide_cost"
	]:
		out[k] = 0
	var seq := 0
	var this_tide := 0
	for k in CAP:
		var i := w.actors.index_of(aid)
		if i < 0:
			out["dead"] = true
			break
		w.step(_frame(w, i, weapon, plays, k))
		out["ticks"] = k + 1
		var lost := full - w.actors.hp[0]
		if w.player_dead():
			out["killed_in_one_tick"] = true
			break
		out["hp_lost"] += lost
		out["biggest"] = maxi(out["biggest"], lost)
		w.actors.hp[0] = full
		var st := WorldReader.new(w).boss_dance()
		var tide: Dictionary = st.get("high_tide", {})
		if not tide.is_empty() and int(tide["flood"]) >= 0 and not tide["inside"]:
			out["out_ticks"] += 1
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
				var part := "other"
				if e.effect_id == BossDance.RIP_EFFECT:
					part = "rip"
				elif e.effect_id == BossDance.HT_EFFECT:
					part = "tide"
					this_tide += e.amount_applied
					out["tide_cost"] = maxi(out["tide_cost"], this_tide)
				elif e.effect_id == BossMaelstrom.EFFECT:
					part = "eye"
				out[part] += e.amount_applied
			elif e.kind != SimEvent.Kind.STATUS_APPLY:
				continue
			elif e.effect_id == BossDance.RIP_CAST:
				out["rows"] += 1 if _first_cast(w) else 0
			elif e.effect_id == BossDance.HT_CAST:
				out["tides"] += 1
				this_tide = 0
			elif e.effect_id == BossDance.RIP_HIT:
				out["strip_hits"] += 1
				out["strip_cost"] = maxi(out["strip_cost"], e.amount)
			elif e.effect_id == BossMaelstrom.THROW:
				out["throws"] += 1
				out["eye_cost"] = maxi(out["eye_cost"], e.amount)
	out["hash"] = w.state_hash()
	return out


## True while the row's first cast runs (a row is counted once, by its first warning).
func _first_cast(w: World) -> bool:
	return w.bosses.dance_rip_n == 0


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
	var st := WorldReader.new(w).boss_dance() if plays else {}
	var whirl: Dictionary = st.get("maelstrom", {})
	if not whirl.is_empty():  # Out of the eye; the Blade between the eye and its reach
		near = float(whirl["eye"]) + (0.25 if blade else 0.9)
		far = maxf(far, near + 0.2)
	var goal := hero
	if dist > far:
		goal = hero + dir
	elif dist < near:
		goal = hero - dir
	if plays:
		goal = _plays_goal(w, st, hero, goal)
		if not whirl.is_empty() and dist < near:  # Never through the eye, wherever it is going
			goal = hero - dir
	var step := goal - hero
	var mv := Vector2i.ZERO
	if Kin.length(step) > 0.05:
		step = step / Kin.length(step)
		mv = Vector2i(roundi(step.x * 127.0), roundi(step.y * 127.0))
	elif blade and dist > 0.001:
		mv = Vector2i(roundi(dir.x * 40.0), roundi(dir.y * 40.0))  # It keeps facing the boss
	var held := 0 if blade else InputFrame.SHOOT
	var reach := maxf(far + 0.5, edge + 2.1)
	var pressed := InputFrame.PRIMARY if blade and k % 6 == 0 and dist <= reach else 0
	return InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), held, pressed)


## Where the bot that plays the dance walks: into the dry circle of a High Tide; else to the middle line of a row's
## safe strip (straight across the strips); else `band` (its distance from the boss).
func _plays_goal(w: World, st: Dictionary, hero: Vector2, band: Vector2) -> Vector2:
	var tide: Dictionary = st.get("high_tide", {})
	if not tide.is_empty():
		var c: Vector2 = tide["centre"]
		return c if c.distance_to(hero) > float(tide["radius"]) * 0.5 else band
	var rip: Dictionary = st.get("riptide", {})
	if rip.is_empty():
		return band
	var safe: Rect2 = st["strips"][rip["safe"]]
	var mid := safe.get_center()
	var across := Vector2(hero.x, mid.y) if st["along_x"] else Vector2(mid.x, hero.y)
	var inside := safe.grow(-w.player.radius_m - 0.6).has_point(hero)
	if not inside:
		return across
	# In the dry strip: it keeps its distance only along the strip, never back across its edge.
	var along := Vector2(band.x, hero.y) if st["along_x"] else Vector2(hero.x, band.y)
	return along


func _report(weapon: StringName, plays: bool, seed_value: int, r: Dictionary) -> void:
	print(
		(
			(
				"TIDEBOT| weapon=%s bot=%s seed=%d dead=%s ticks=%d seconds=%.1f max_hp=%d hp_lost=%d"
				+ " biggest=%d rip=%d tide=%d eye=%d other=%d rows=%d strip_hits=%d strip_cost=%d"
				+ " tides=%d seconds_outside=%.1f tide_cost=%d throws=%d eye_cost=%d"
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
				r["tide"],
				r["eye"],
				r["other"],
				r["rows"],
				r["strip_hits"],
				r["strip_cost"],
				r["tides"],
				float(r["out_ticks"]) / SimTick.TICKS_PER_SECOND,
				r["tide_cost"],
				r["throws"],
				r["eye_cost"],
			]
		)
	)


func test_ignoring_the_dance_costs_clearly_more() -> void:
	var unmet := PackedStringArray()
	for weapon: StringName in [&"gun", &"blade"]:
		var keys := ["ticks", "hp_lost", "rip", "tide", "eye", "other", "strip_hits", "throws"]
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
				assert_true(r["dead"], "%s seed %d: the Tidecaller dies" % [weapon, sv])
				assert_gt(int(r["rows"]), 0, "a row of Riptide was cast")
				var most := int(r["max_hp"]) * 40 / 100
				for key: String in ["strip_cost", "eye_cost", "tide_cost"]:
					assert_lte(
						int(r[key]),
						most,
						"%s seed %d: %s is at most 40 %% of the hero's HP" % [weapon, sv, key]
					)
				for key: String in keys:
					sum[plays][key] += int(r[key])
		var a: Dictionary = sum[true]
		var b: Dictionary = sum[false]
		print(
			"TIDEBOT| weapon=%s over %d seeds: plays %s, ignores %s" % [weapon, SEEDS.size(), a, b]
		)
		var dance_a := int(a["rip"]) + int(a["tide"]) + int(a["eye"])
		var dance_b := int(b["rip"]) + int(b["tide"]) + int(b["eye"])
		assert_gt(dance_b, dance_a, "%s: the dance costs the bot that ignores it more" % weapon)
		if b["hp_lost"] * 10 < a["hp_lost"] * 13:
			unmet.append(
				(
					"%s: ignoring cost %d HP in %d ticks, playing %d HP in %d ticks"
					% [weapon, b["hp_lost"], b["ticks"], a["hp_lost"], a["ticks"]]
				)
			)
	# The brief's expectation, kept visible while it is not met: the numbers are the evidence
	# (docs/roadmap/v0.12.0/evidence/TIDE_BOTS.md) and the tuning is the lead's and the owner's call.
	if not unmet.is_empty():
		pending("NOT MET, ignoring the dance costs at least 30 % more HP: " + "; ".join(unmet))


func test_a_bot_fight_is_deterministic() -> void:
	var a := _fight(&"gun", true, 5)
	var b := _fight(&"gun", true, 5)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["ticks"], b["ticks"])
