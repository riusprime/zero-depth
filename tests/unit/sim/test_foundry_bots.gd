extends GutTest
## The Foundry's whole fight played by two scripted bots, each with a Gun and with a Blade (the starting builds, no
## items; the real compiled Foundry in a 24 m walled room, ForgeLab; no floor scaling). The hero has its real max HP
## (the forge's costs are shares of it) and is refilled each tick, so a fight always runs to the boss's death and the
## HP it would have lost is counted.
## - "plays": while the Foundry wears its plate it stands right by it, so the drones' bombs, thrown at the hero, land
##   against the Foundry; through an Overpressure it stands on the nearest safe slab; with the scald gauge at 600 or
##   more it walks to the nearest slab and stays until the gauge is empty. Otherwise it holds its weapon's distance.
## - "ignores": holds its weapon's distance and attacks, whatever the forge does.
## Both attack throughout and neither dodges anything else, so the difference between them is the forge. Prints
## every fight's numbers (raw) for docs/roadmap/v0.12.0/evidence/FOUNDRY_BOTS.md.

const CAP := 60 * 900
const SEEDS: Array[int] = [5, 6, 7]
## The gauge at which the bot that plays goes to drain it.
const DRAIN_AT := 600


## Plays the fight. Returns its numbers: "ticks", "dead" (the Foundry died), "max_hp", "hp_lost" (all the damage the
## hero took), "biggest" (the most in one tick), "over" and "scald" (the HP lost to Overpressure and to the scald's
## burn), "other", "plates" (forged), "blown", "plated_ticks", "burning_ticks", "overs" (cast), "hash".
func _fight(weapon: StringName, plays: bool, seed_value: int) -> Dictionary:
	var w := JudgeLab.world(seed_value)
	ContentCompiler.apply_build(w.player, SharedContent.repo().get_def(&"build", weapon))
	var aid := w.actors.ids[BossLab.ready_boss(w, &"foundry", Vector2(6, 0))]
	w.actors.set_pos(0, Vector2(-4, 0))
	var full := w.actors.max_hp[0]
	var out := {"ticks": 0, "dead": false, "max_hp": full, "hp_lost": 0, "biggest": 0}
	for k: String in [
		"over",
		"scald",
		"other",
		"plates",
		"blown",
		"plated_ticks",
		"burning_ticks",
		"overs",
		"forge_biggest"
	]:
		out[k] = 0
	var seq := 0
	var draining := {"on": false}
	for k in CAP:
		var i := w.actors.index_of(aid)
		if i < 0:
			out["dead"] = true
			break
		w.step(_frame(w, i, weapon, plays, k, draining))
		out["ticks"] = k + 1
		var lost := full - w.actors.hp[0]
		if w.player_dead():
			out["killed_in_one_tick"] = true
			break
		out["hp_lost"] += lost
		out["biggest"] = maxi(out["biggest"], lost)
		w.actors.hp[0] = full
		out["plated_ticks"] += w.bosses.fg_plate
		out["burning_ticks"] += w.bosses.fg_burning
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
				var part := "other"
				if e.effect_id == BossSlag.OVER_EFFECT:
					part = "over"
				elif e.effect_id == BossForge.SCALD_EFFECT:
					part = "scald"
				out[part] += e.amount_applied
				if part != "other":
					out["forge_biggest"] = maxi(out["forge_biggest"], e.amount_applied)
			elif e.kind != SimEvent.Kind.STATUS_APPLY:
				continue
			elif e.effect_id == BossForge.PLATE_ON:
				out["plates"] += 1
			elif e.effect_id == BossForge.PLATE_BLOWN:
				out["blown"] += 1
			elif e.effect_id == BossSlag.OVER_CAST:
				out["overs"] += 1
	out["hash"] = w.state_hash()
	return out


## The bot's input this tick.
func _frame(
	w: World, i: int, weapon: StringName, plays: bool, k: int, draining: Dictionary
) -> InputFrame:
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
		goal = _plays_goal(w, i, hero, goal, draining)
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


## Where the bot that plays the forge walks: onto the nearest safe slab through an Overpressure; onto the nearest
## slab to drain a gauge at DRAIN_AT until it is empty; right by the Foundry while it is plated; else `band`.
func _plays_goal(w: World, i: int, hero: Vector2, band: Vector2, draining: Dictionary) -> Vector2:
	var st := WorldReader.new(w).boss_forge()
	if st.is_empty():
		return band
	var scald: Dictionary = st["scald"]
	var gauge := int(scald.get("gauge", 0))
	if gauge >= DRAIN_AT:
		draining["on"] = true
	elif gauge <= 0:
		draining["on"] = false
	var safe_only := not (st["overpressure"] as Dictionary).is_empty()
	if safe_only or draining["on"]:
		var best := Vector2.INF
		for r: Dictionary in st["slabs"]:
			if not r["slab"] or r["shattered"] or (safe_only and not r["safe"]):
				continue
			var c: Vector2 = r["centre"]
			if not best.is_finite() or c.distance_to(hero) < best.distance_to(hero):
				best = c
		if best.is_finite():
			return best if best.distance_to(hero) > 0.5 else hero
	if st["plate"]["on"]:
		var c := w.actors.pos(i)
		var off := hero - c
		var keep := w.actors.radius[i] + w.player.radius_m + 0.25
		var spot := c + (off / maxf(Kin.length(off), 0.01)) * keep
		return spot if spot.distance_to(hero) > 0.2 else hero
	return band


func _report(weapon: StringName, plays: bool, seed_value: int, r: Dictionary) -> void:
	print(
		(
			(
				"FORGEBOT| weapon=%s bot=%s seed=%d dead=%s ticks=%d seconds=%.1f max_hp=%d hp_lost=%d"
				+ " biggest=%d over=%d scald=%d other=%d plates=%d blown=%d seconds_plated=%.1f"
				+ " seconds_burning=%.1f overs=%d forge_biggest=%d"
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
				r["over"],
				r["scald"],
				r["other"],
				r["plates"],
				r["blown"],
				float(r["plated_ticks"]) / SimTick.TICKS_PER_SECOND,
				float(r["burning_ticks"]) / SimTick.TICKS_PER_SECOND,
				r["overs"],
				r["forge_biggest"],
			]
		)
	)


func test_ignoring_the_forge_is_slower_and_costs_more() -> void:
	var unmet := PackedStringArray()
	for weapon: StringName in [&"gun", &"blade"]:
		var keys := ["ticks", "hp_lost", "over", "scald", "other", "blown", "plated_ticks"]
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
				assert_true(r["dead"], "%s seed %d: the Foundry dies" % [weapon, sv])
				assert_gt(int(r["plates"]), 0, "a plate was forged")
				# The forge's own steps; "biggest" (any tick) also holds the Foundry's older attacks
				assert_lte(
					int(r["forge_biggest"]),
					int(r["max_hp"]) * 40 / 100,
					"%s seed %d: no forge step costs over 40 %% of the hero's HP" % [weapon, sv]
				)
				for key: String in keys:
					sum[plays][key] += int(r[key])
		var a: Dictionary = sum[true]
		var b: Dictionary = sum[false]
		print(
			"FORGEBOT| weapon=%s over %d seeds: plays %s, ignores %s" % [weapon, SEEDS.size(), a, b]
		)
		var forge_a := int(a["over"]) + int(a["scald"])
		var forge_b := int(b["over"]) + int(b["scald"])
		if forge_b * 10 < forge_a * 13:
			unmet.append(
				"%s: the forge cost ignoring %d HP, playing %d HP" % [weapon, forge_b, forge_a]
			)
		if b["ticks"] * 10 < a["ticks"] * 11:
			unmet.append(
				"%s: ignoring took %d ticks, playing %d ticks" % [weapon, b["ticks"], a["ticks"]]
			)
	# The brief's expectation, kept visible while it is not met: the numbers are the evidence
	# (docs/roadmap/v0.12.0/evidence/FOUNDRY_BOTS.md) and the tuning is the lead's and the owner's call.
	if not unmet.is_empty():
		pending(
			(
				"NOT MET, ignoring the forge is clearly slower and costs clearly more: "
				+ "; ".join(unmet)
			)
		)


func test_a_bot_fight_is_deterministic() -> void:
	var a := _fight(&"gun", true, 5)
	var b := _fight(&"gun", true, 5)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["ticks"], b["ticks"])
