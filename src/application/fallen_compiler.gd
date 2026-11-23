class_name FallenCompiler
extends RefCounted
## Compiles The Fallen's own mechanics (FinalBossDefinition.reposition and remembered, FallenRules) into its table, in
## sim units: its dash between moves (FallenDashTable) and its remembered mechanics (FallenRememberedTable, with the
## source bosses' own tables filled from its numbers: the hour orbs' BossTimeTable, Riptide's BossDanceTable and the
## quake pillars' QuakeTable on BossTable.quake).

## A phase index no body reaches: the quake pillars and the late orbs never come by a phase of their own here.
const NEVER_PHASE := 1 << 20


static func compile_into(def: FinalBossDefinition, t: BossTable) -> void:
	if not def.reposition.is_empty():
		var r := def.reposition
		var dt := FallenDashTable.new()
		dt.dash_telegraph_ticks = SimTick.seconds_to_ticks(
			FallenRules.dash_value(r, "dash_telegraph_seconds")
		)
		dt.dash_ticks = maxi(1, SimTick.seconds_to_ticks(FallenRules.dash_value(r, "dash_seconds")))
		dt.dash_min_m = FallenRules.dash_value(r, "dash_min_m")
		dt.dash_max_m = FallenRules.dash_value(r, "dash_max_m")
		dt.dash_wall_m = FallenRules.dash_value(r, "dash_wall_m")
		t.reposition = dt
	if not def.remembered.is_empty():
		_remembered(def.remembered, t)


static func _ticks(d: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(FallenRules.value(d, key)))


static func _int(d: Dictionary, key: String) -> int:
	return int(FallenRules.value(d, key))


static func _remembered(d: Dictionary, t: BossTable) -> void:
	var m := FallenRememberedTable.new()
	m.gates = PackedInt32Array([_int(d, "first_permille"), _int(d, "second_permille")])
	m.every_ticks = _ticks(d, "every_seconds")
	m.first_ticks = SimTick.seconds_to_ticks(FallenRules.value(d, "first_seconds"))
	m.calm_ticks = _ticks(d, "calm_seconds")
	m.cast_ticks = _ticks(d, "cast_seconds")
	m.time_cut = _int(d, "time_cut_permille")
	m.time_ticks = _ticks(d, "time_seconds")
	var orb := BossPickupTable.new()
	orb.kind = BossPickupTable.Kind.RESTORE_ATTACK_SPEED
	orb.amount = _int(d, "time_orb_permille")
	orb.radius_m = FallenRules.value(d, "time_orb_radius_m")
	orb.life_ticks = m.time_ticks
	orb.max_count = _int(d, "time_orbs")
	var tt := BossTimeTable.new()
	tt.orb = orb
	tt.orb_late = orb
	tt.orb_late_phase = NEVER_PHASE
	tt.orb_count = orb.max_count
	tt.orb_gap_m = FallenRules.value(d, "time_orb_gap_m")
	m.time = tt
	var dt := BossDanceTable.new()
	dt.rip_phase = 0
	dt.ht_phase = NEVER_PHASE
	dt.mael_phase = NEVER_PHASE
	dt.rip_casts = _int(d, "riptide_casts")
	dt.rip_warn_ticks = _ticks(d, "riptide_warn_seconds")
	dt.rip_last_warn_ticks = dt.rip_warn_ticks
	dt.rip_wave_ticks = _ticks(d, "riptide_wave_seconds")
	dt.rip_run_margin = _int(d, "riptide_run_margin_permille")
	dt.rip_hit = _int(d, "riptide_permille")
	dt.rip_cause = t.attack_index(FallenRules.RIPTIDE_CARRIER)
	m.dance = dt
	m.pillar_ticks = _ticks(d, "pillar_seconds")
	m.pillar_hero_m = FallenRules.value(d, "pillar_hero_m")
	m.pillar_dash_ticks = _ticks(d, "pillar_dash_seconds")
	var q := QuakeTable.new()
	q.count = _int(d, "pillar_count")
	q.from_phase = NEVER_PHASE  # Raised by the mechanic only (BossRemembered), never by a phase
	q.half_m = FallenRules.value(d, "pillar_m") * 0.5
	q.pulse_ticks = _ticks(d, "pillar_pulse_seconds")
	q.warn_ticks = _ticks(d, "pillar_warn_seconds")
	q.ring_m = FallenRules.value(d, "pillar_ring_m")
	q.damage_permille = _int(d, "pillar_permille")
	q.stun_ticks = _ticks(d, "pillar_stun_seconds")
	q.stun_permille = _int(d, "stun_taken_permille")
	q.stuns_per_phase = _int(d, "pillar_stuns")
	q.gap_m = FallenRules.value(d, "pillar_gap_m")
	q.wall_m = FallenRules.value(d, "pillar_wall_m")
	q.boss_m = FallenRules.value(d, "pillar_boss_m")
	q.cause_key = &"CAUSE_GATEKEEPER_PILLAR"
	t.quake = q
	m.ward_ticks = _ticks(d, "ward_seconds")
	m.ward_windup_ticks = _ticks(d, "ward_windup_seconds")
	m.ward_lock_ticks = _ticks(d, "ward_lock_seconds")
	m.ward_speed = FallenRules.value(d, "ward_speed_mps") / SimTick.TICKS_PER_SECOND
	m.ward_overshoot_m = FallenRules.value(d, "ward_overshoot_m")
	m.ward_charges = _int(d, "ward_charges")
	m.ward_gap_ticks = _ticks(d, "ward_gap_seconds")
	m.ward_radius_m = FallenRules.value(d, "ward_radius_m")
	m.ward_edge_m = FallenRules.value(d, "ward_edge_m")
	m.ward_hit = _int(d, "ward_permille")
	m.ward_burst_m = FallenRules.value(d, "ward_burst_m")
	m.ward_burst_ticks = _ticks(d, "ward_burst_seconds")
	m.ward_burst_hit = _int(d, "ward_burst_permille")
	m.ward_stun_ticks = _ticks(d, "ward_stun_seconds")
	m.ward_cause = t.attack_index(FallenRules.SHADE_CARRIER)
	m.theft_gates = PackedInt32Array(
		[_int(d, "theft_first_permille"), _int(d, "theft_second_permille")]
	)
	m.theft_cast_ticks = _ticks(d, "theft_cast_seconds")
	m.theft_held = _int(d, "theft_held")
	m.theft_hits = _int(d, "theft_hits")
	m.theft_half_arc = roundi(FallenRules.value(d, "theft_arc_deg") * 2048.0 / 360.0)
	t.remembered = m
