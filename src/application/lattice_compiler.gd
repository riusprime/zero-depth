class_name LatticeCompiler
extends RefCounted
## Compiles a boss's lattice (BossDefinition.lattice, LatticeRules.SPEC) into its table's BossLensTable, in sim units
## (its own file: ContentCompiler is at its line limit).

## 1/4096 turn, in thousandths, per degree a second over a tick (4096000 / 360 / 60).
const MILLI_TURN_PER_DPS_TICK := 4096000.0 / 21600.0


## PatternCompiler.compile_cadence: the lattice, or none (t.lens stays null). The table's attacks are compiled first.
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var f := def.lattice
	if f.is_empty():
		return
	var lt := BossLensTable.new()
	lt.feed_phase = _int(f, "feed_phase")
	lt.feed_cut = _int(f, "feed_cut_permille")
	lt.feed_cap = _int(f, "feed_cap_permille")
	lt.resend_ticks = _ticks(f, "resend_seconds")
	lt.split_attack = t.attack_index(StringName(str(f.get("split_attack", ""))))
	if lt.split_attack >= 0:
		lt.drone_kind = t.attacks[lt.split_attack].enemy_kind
	lt.beams = _indices(t, f.get("beam_attacks", []))
	lt.strip_phase = _int(f, "strip_phase")
	lt.strip_len_m = LatticeRules.value(f, "strip_length_m")
	lt.strip_half_m = LatticeRules.value(f, "strip_width_m") * 0.5
	lt.strip_ticks = _ticks(f, "strip_seconds")
	lt.strip_damage = _int(f, "strip_damage")
	lt.strip_step_ticks = _ticks(f, "strip_tick_seconds")
	lt.strip_max = _int(f, "strip_max")
	lt.strip_cause = t.attack_index(StringName(str(f.get("strip_cause", ""))))
	lt.lat_phase = _int(f, "lattice_phase")
	lt.lat_first_ticks = SimTick.seconds_to_ticks(LatticeRules.value(f, "lattice_first_seconds"))
	lt.lat_every_ticks = _ticks(f, "lattice_every_seconds")
	lt.lat_cast_ticks = _ticks(f, "lattice_cast_seconds")
	lt.lat_ticks = _ticks(f, "lattice_seconds")
	lt.lat_min = _int(f, "lattice_min_drones")
	lt.strand_half_m = LatticeRules.value(f, "strand_width_m") * 0.5
	lt.strand_hit = _int(f, "strand_hit_permille")
	lt.strand_lock_ticks = _ticks(f, "strand_lockout_seconds")
	lt.strand_cause = t.attack_index(StringName(str(f.get("strand_cause", ""))))
	lt.orbit_step = roundi(LatticeRules.value(f, "orbit_dps") * MILLI_TURN_PER_DPS_TICK)
	lt.orbit_min_m = LatticeRules.value(f, "orbit_min_m")
	lt.orbit_max_m = LatticeRules.value(f, "orbit_max_m")
	lt.calm_ticks = SimTick.seconds_to_ticks(LatticeRules.value(f, "calm_seconds"))
	lt.holds = _indices(t, f.get("lattice_holds", []))
	t.lens = lt


static func _indices(t: BossTable, ids: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id: Variant in ids:
		var k := t.attack_index(StringName(str(id)))
		if k >= 0:
			out.append(k)
	return out


static func _int(f: Dictionary, key: String) -> int:
	return int(LatticeRules.value(f, key))


static func _ticks(f: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(LatticeRules.value(f, key)))
