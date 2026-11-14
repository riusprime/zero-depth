class_name WardensCompiler
extends RefCounted
## Compiles the Twin Wardens' own mechanics (BossDefinition.wardens, WardensRules.SPEC) into their table's
## BossWardensTable, in sim units, and the attack numbers they add: a charge's burst, a sword combo's and Shadow
## Swords' active time (its own file: ContentCompiler and PatternCompiler are near their line limits).


## PatternCompiler.compile_cadence: the Wardens' mechanics, or none (t.wardens stays null).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var wd := def.wardens
	if wd.is_empty():
		return
	var wt := BossWardensTable.new()
	wt.dash_m = WardensRules.value(wd, "dash_m")
	wt.dash_ticks = _ticks(wd, "dash_seconds")
	wt.dash_every_ticks = _ticks(wd, "dash_every_seconds")
	wt.combo_light_permille = _int(wd, "combo_light_permille")
	wt.lane_max_m = WardensRules.value(wd, "sword_lane_max_m")
	wt.mirror_ticks = _ticks(wd, "mirror_seconds")
	wt.mirror_half_arc = ContentCompiler.degrees_to_units(
		WardensRules.value(wd, "mirror_arc_degrees") * 0.5
	)
	wt.mirror_permille = _int(wd, "mirror_damage_permille")
	wt.mirror_cap_permille = _int(wd, "mirror_cap_permille")
	wt.mirror_range_m = WardensRules.value(wd, "mirror_range_m")
	wt.mirror_push_m = WardensRules.value(wd, "mirror_push_m")
	wt.mirror_look = StringName(String(wd.get("mirror_look", "")))
	wt.mirror_cause_key = StringName(String(wd.get("mirror_cause_key", "")))
	wt.sword_count = mini(_int(wd, "sword_count"), WardensRules.MAX_SWORDS)
	wt.sword_ring_m = WardensRules.value(wd, "sword_ring_m")
	wt.sword_fan = ContentCompiler.degrees_to_units(WardensRules.value(wd, "sword_fan_degrees"))
	wt.sword_len_m = WardensRules.value(wd, "sword_length_m")
	wt.sword_half_m = WardensRules.value(wd, "sword_width_m") * 0.5
	wt.sword_gap_ticks = _ticks(wd, "sword_gap_seconds")
	wt.ward_phase = _int(wd, "ward_phase")
	wt.stun_ticks = _ticks(wd, "ward_stun_seconds")
	wt.stun_permille = _int(wd, "ward_stun_permille")
	wt.stagger_ticks = _ticks(wd, "ward_stagger_seconds")
	wt.return_ticks = _ticks(wd, "ward_return_seconds")
	wt.rift_hp_permille = _int(wd, "rift_hp_permille")
	wt.rift_gap_m = WardensRules.value(wd, "rift_gap_m")
	wt.rift_radius_m = WardensRules.value(wd, "rift_radius_m")
	wt.rift_open_ticks = _ticks(wd, "rift_open_seconds")
	wt.rift_inside_ticks = _ticks(wd, "rift_inside_seconds")
	wt.rift_mark_ticks = mini(_ticks(wd, "rift_mark_seconds"), wt.rift_inside_ticks)
	wt.rift_attack = t.attack_index(StringName(String(wd.get("rift_attack", ""))))
	for a in t.attacks:  # The cuts run one after another: the attack is active until its last
		if a.move == BossAttackTable.Move.SHADOW_SWORDS:
			a.active_ticks = maxi(a.active_ticks, (wt.sword_count - 1) * wt.sword_gap_ticks + 1)
	t.wardens = wt


## PatternCompiler.compile_boss_attack: a charge's burst where it ends; a sword combo is active until its last hit.
static func compile_attack(def: BossAttackDefinition, t: BossAttackTable) -> void:
	var sp := def.shape_params
	t.burst_radius_m = float(sp.get("burst_radius_m", 0.0))
	t.burst_ticks = maxi(1, SimTick.seconds_to_ticks(float(sp.get("burst_seconds", 0.0))))
	if t.move == BossAttackTable.Move.SWORD_COMBO:
		t.active_ticks = maxi(t.active_ticks, (t.count - 1) * t.gap_ticks + 1)


static func _int(wd: Dictionary, key: String) -> int:
	return int(WardensRules.value(wd, key))


static func _ticks(wd: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(WardensRules.value(wd, key)))
