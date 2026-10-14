class_name FinalBodyCompiler
extends RefCounted
## v0.8.0 FB2 (owner F7; FINAL_BOSS.md F5): a final body's own rules, beside ContentCompiler (which calls it for a
## FinalBossDefinition): its Crosses' bolt attacks (by index), its float and shards, and an HP set from the measured
## damage per second (the window share from its Crosses' cycles: windup, active, recovery and cooldown).


static func compile_into(def: FinalBossDefinition, t: BossTable) -> void:
	var cycle := 0
	var window := 0
	for k in def.attacks.size():
		var at := t.attacks[k]
		if at.move != BossAttackTable.Move.CROSS:
			continue
		t.floats_home = true
		var bolt := StringName(def.attacks[k].shape_params.get("bolt_attack", ""))
		at.bolt_attack = t.attack_index(bolt) if bolt != &"" else -1
		cycle += at.windup_ticks + at.active_ticks + at.recover_ticks + at.cooldown_ticks
		window += at.window_ticks
	t.window_permille = clampi(window * 1000 / maxi(1, cycle), 1, 1000) if cycle > 0 else 1000
	t.shard_count = def.shard_count
	t.shard_orbit_m = def.shard_orbit_m
	t.shard_turn_milli = int(
		round(def.shard_turn_dps * 4096.0 / 360.0 * 1000.0 / SimTick.TICKS_PER_SECOND)
	)
	t.dps_hp = def.hp_from_dps
	t.dps_seconds = def.dps_measure_seconds
	t.dps_min_seconds = def.dps_min_measured_seconds
	t.dps_target_ticks = SimTick.seconds_to_ticks(def.dps_target_seconds)
	t.dps_hp_min = def.dps_hp_min
	t.dps_hp_max = def.dps_hp_max
