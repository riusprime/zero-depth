class_name ForgeCompiler
extends RefCounted
## Compiles a boss's forge (BossDefinition.forge, ForgeRules.SPEC) into its table's BossForgeTable, in sim units (its
## own file: ContentCompiler is at its line limit).


## PatternCompiler.compile_cadence: the forge, or none (t.forge stays null). The table's attacks are compiled first.
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var f := def.forge
	if f.is_empty():
		return
	var ft := BossForgeTable.new()
	ft.plate_phase = _int(f, "plate_phase")
	ft.plate_first_ticks = _ticks(f, "plate_first_seconds")
	ft.plate_every_ticks = _ticks(f, "plate_every_seconds")
	ft.plate_cast_ticks = _ticks(f, "plate_cast_seconds")
	ft.plate_taken = _int(f, "plate_taken_permille")
	ft.exposed_ticks = _ticks(f, "exposed_seconds")
	ft.exposed_taken = _int(f, "exposed_taken_permille")
	ft.drone_blast_m = ForgeRules.value(f, "drone_blast_m")
	ft.drone_distance_m = ForgeRules.value(f, "drone_distance_m")
	ft.drone_gap_ticks = SimTick.seconds_to_ticks(ForgeRules.value(f, "drone_gap_seconds"))
	for a in t.attacks:  # The drones are the boss's first brood attack's kind
		if a.move == BossAttackTable.Move.BROOD:
			ft.drone_kind = a.enemy_kind
			break
	ft.slab_phase = _int(f, "slab_phase")
	ft.slab_cool_ticks = _ticks(f, "slab_cool_seconds")
	ft.slab_ticks = _ticks(f, "slab_seconds")
	ft.drop_ticks = SimTick.seconds_to_ticks(ForgeRules.value(f, "slag_drop_seconds"))
	ft.over_phase = _int(f, "overpressure_phase")
	ft.over_first_ticks = _ticks(f, "overpressure_first_seconds")
	ft.over_every_ticks = _ticks(f, "overpressure_every_seconds")
	ft.over_cast_ticks = _ticks(f, "overpressure_cast_seconds")
	ft.over_ticks = _ticks(f, "overpressure_seconds")
	ft.over_step_ticks = _ticks(f, "overpressure_tick_seconds")
	ft.over_hit = _step(f, "overpressure_permille_per_second", "overpressure_tick_seconds")
	ft.over_cause = t.attack_index(StringName(str(f.get("overpressure_cause", ""))))
	ft.scald_phase = _int(f, "scald_phase")
	ft.scald_max = _int(f, "scald_max")
	ft.scald_hit = _int(f, "scald_hit")
	ft.scald_lava = _int(f, "scald_lava")
	ft.scald_open = _int(f, "scald_open")
	ft.scald_step_ticks = _ticks(f, "scald_tick_seconds")
	ft.scald_drain = roundi(
		ForgeRules.value(f, "scald_drain_per_second") * ForgeRules.value(f, "scald_tick_seconds")
	)
	ft.scald_burn = _step(f, "scald_burn_permille_per_second", "scald_tick_seconds")
	ft.scald_cause = t.attack_index(StringName(str(f.get("scald_cause", ""))))
	t.forge = ft


## A step's per mille of max HP (at least 1).
static func _step(f: Dictionary, per_second: String, tick: String) -> int:
	return maxi(1, roundi(ForgeRules.step_permille(f, per_second, tick)))


static func _int(f: Dictionary, key: String) -> int:
	return int(ForgeRules.value(f, key))


static func _ticks(f: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(ForgeRules.value(f, key)))
