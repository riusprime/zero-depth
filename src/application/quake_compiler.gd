class_name QuakeCompiler
extends RefCounted
## v0.11.0 O3 (owner L5, Q9 a; BossQuake): compiles a boss's quake pillars (BossDefinition.quake, QuakeRules.SPEC)
## into its table's QuakeTable, in sim units (its own file: ContentCompiler is at its line limit).


## PatternCompiler.compile_cadence: the quake pillars, or none (t.quake stays null).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var q := def.quake
	if q.is_empty():
		return
	var qt := QuakeTable.new()
	qt.count = int(QuakeRules.value(q, "count"))
	qt.from_phase = int(QuakeRules.value(q, "from_phase"))
	qt.half_m = QuakeRules.value(q, "pillar_m") * 0.5
	qt.pulse_ticks = maxi(1, SimTick.seconds_to_ticks(QuakeRules.value(q, "pulse_seconds")))
	qt.warn_ticks = SimTick.seconds_to_ticks(QuakeRules.value(q, "warn_seconds"))
	qt.ring_m = QuakeRules.value(q, "ring_m")
	qt.damage_permille = int(QuakeRules.value(q, "damage_permille"))
	qt.stun_ticks = maxi(1, SimTick.seconds_to_ticks(QuakeRules.value(q, "stun_seconds")))
	qt.stun_permille = int(QuakeRules.value(q, "stun_permille"))
	qt.stuns_per_phase = int(QuakeRules.value(q, "stuns_per_phase"))
	qt.gap_m = QuakeRules.value(q, "gap_m")
	qt.wall_m = QuakeRules.value(q, "wall_m")
	qt.boss_m = QuakeRules.value(q, "boss_m")
	qt.cause_key = def.quake_cause_key
	t.quake = qt
