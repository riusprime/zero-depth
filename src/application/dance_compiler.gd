class_name DanceCompiler
extends RefCounted
## Compiles a boss's dance (BossDefinition.dance, DanceRules.SPEC) into its table's BossDanceTable, in sim units (its
## own file: ContentCompiler is at its line limit).


## PatternCompiler.compile_cadence: the dance, or none (t.dance stays null).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var d := def.dance
	if d.is_empty():
		return
	var dt := BossDanceTable.new()
	dt.pull = _int(d, "pull_permille")
	dt.pull_late = _int(d, "pull_late_permille")
	dt.pull_late_phase = _int(d, "pull_late_phase")
	dt.push_m = DanceRules.value(d, "push_m")
	dt.rip_phase = _int(d, "riptide_phase")
	dt.rip_first_ticks = _ticks(d, "riptide_first_seconds")
	dt.rip_every_ticks = _ticks(d, "riptide_every_seconds")
	dt.rip_casts = _int(d, "riptide_casts")
	dt.rip_warn_ticks = _ticks(d, "riptide_warn_seconds")
	dt.rip_last_warn_ticks = _ticks(d, "riptide_last_warn_seconds")
	dt.rip_wave_ticks = _ticks(d, "riptide_wave_seconds")
	dt.rip_hit = _int(d, "riptide_permille")
	dt.rip_cause = _first(def, &"wave")
	dt.ht_phase = _int(d, "high_tide_phase")
	dt.ht_first_ticks = _ticks(d, "high_tide_first_seconds")
	dt.ht_every_ticks = _ticks(d, "high_tide_every_seconds")
	dt.ht_cast_ticks = _ticks(d, "high_tide_cast_seconds")
	dt.ht_flood_ticks = _ticks(d, "high_tide_seconds")
	dt.ht_step_ticks = _ticks(d, "high_tide_tick_seconds")
	dt.ht_radius_m = DanceRules.value(d, "high_tide_radius_m")
	dt.ht_gap_m = DanceRules.value(d, "high_tide_gap_m")
	dt.ht_hit = maxi(
		1,
		roundi(
			(
				DanceRules.value(d, "high_tide_permille_per_second")
				* DanceRules.value(d, "high_tide_tick_seconds")
			)
		)
	)
	dt.tide_cause = _first(def, &"tide")
	dt.mael_phase = _int(d, "maelstrom_phase")
	dt.mael_spin = _int(d, "maelstrom_spin_permille")
	dt.mael_in = _int(d, "maelstrom_in_permille")
	dt.mael_eye_m = DanceRules.value(d, "maelstrom_eye_m")
	dt.mael_hit = _int(d, "maelstrom_permille")
	dt.mael_throw_m = DanceRules.value(d, "maelstrom_throw_m")
	dt.mael_throw_ticks = _ticks(d, "maelstrom_throw_seconds")
	dt.mael_grace_ticks = _ticks(d, "maelstrom_grace_seconds")
	t.dance = dt


## The index of the boss's first attack with `move` (the table's attacks keep the definition's order), or -1.
static func _first(def: BossDefinition, move: StringName) -> int:
	for k in def.attacks.size():
		if def.attacks[k] != null and def.attacks[k].move == move:
			return k
	return -1


static func _int(d: Dictionary, key: String) -> int:
	return int(DanceRules.value(d, key))


static func _ticks(d: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(DanceRules.value(d, key)))
