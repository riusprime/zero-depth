class_name WarlordCompiler
extends RefCounted
## Compiles the Warlord's own mechanics (BossDefinition.warlord, WarlordRules.SPEC) into its table's
## BossWarlordTable, in sim units (its own file: ContentCompiler is at its line limit).


## PatternCompiler.compile_cadence: the banner and the duel, or none (t.warlord stays null). The table's attacks are
## compiled first.
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var d := def.warlord
	if d.is_empty():
		return
	var wt := BossWarlordTable.new()
	wt.banner_phase = _int(d, "banner_phase")
	wt.banner_first_ticks = _ticks(d, "banner_first_seconds")
	wt.banner_gap_ticks = _ticks(d, "banner_gap_seconds")
	wt.banner_cast_ticks = _ticks(d, "banner_cast_seconds")
	wt.banner_radius_m = WarlordRules.value(d, "banner_radius_m")
	wt.banner_ticks = _ticks(d, "banner_seconds")
	wt.banner_cooldown = _int(d, "banner_cooldown_permille")
	wt.banner_damage = _int(d, "banner_damage_permille")
	wt.banner_pole_m = WarlordRules.value(d, "banner_pole_m")
	wt.duel_phase = _int(d, "duel_phase")
	wt.duel_first_ticks = _ticks(d, "duel_first_seconds")
	wt.duel_gap_ticks = _ticks(d, "duel_gap_seconds")
	wt.duel_cast_ticks = _ticks(d, "duel_cast_seconds")
	wt.duel_radius_m = WarlordRules.value(d, "duel_radius_m")
	wt.duel_end_radius_m = WarlordRules.value(d, "duel_end_radius_m")
	wt.duel_ticks = _ticks(d, "duel_seconds")
	wt.fence_touch_m = WarlordRules.value(d, "fence_touch_m")
	wt.fence_hit = _int(d, "fence_permille")
	wt.fence_every_ticks = _ticks(d, "fence_every_seconds")
	wt.recall_warn_ticks = _ticks(d, "recall_warn_seconds")
	wt.recall_radius_m = WarlordRules.value(d, "recall_radius_m")
	wt.recall_hit = _int(d, "recall_permille")
	for id: Variant in d.get(WarlordRules.DUEL_ATTACKS, []):
		var k := t.attack_index(StringName(str(id)))
		if k >= 0:
			wt.duel_attacks.append(k)
	wt.fence_cause = t.attack_index(StringName(str(d.get("fence_cause", ""))))
	var late := t.attack_index(StringName(str(d.get("recall_cause", ""))))  # Its late part's line
	wt.recall_cause = BossSignatures.LATE_CAUSE + late if late >= 0 else -1
	t.warlord = wt


static func _int(d: Dictionary, key: String) -> int:
	return int(WarlordRules.value(d, key))


static func _ticks(d: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(WarlordRules.value(d, key)))
