class_name FinalBodyCompiler
extends RefCounted
## v0.8.0 FB2 (owner F7; FINAL_BOSS.md F5): a final body's own rules, beside ContentCompiler (which calls it for a
## FinalBossDefinition): its Crosses' bolt attacks (by index), its float and shards, and an HP set from the measured
## damage per second (the window share from its Crosses' cycles: windup, active, recovery and cooldown).
## v0.8.0 FB3: a mimic body's numbers (the Nemesis: its echo, dash, stances, cards, its HP and hit from the build and
## the clamps on its copies of the player's attacks), in sim units.


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
	_compile_mimic(def, t)


## v0.8.0 FB3 (FINAL_BOSS.md F6, F7).
static func _compile_mimic(def: FinalBossDefinition, t: BossTable) -> void:
	t.mimic = def.mimic
	t.echo_ticks = clampi(SimTick.seconds_to_ticks(def.echo_seconds), 0, FinalFight.ECHO_MAX - 1)
	t.dash_react_ticks = maxi(1, SimTick.seconds_to_ticks(def.dash_reaction_seconds))
	t.stance_ticks = maxi(1, SimTick.seconds_to_ticks(def.stance_seconds))
	t.stance_weights = def.stance_weights.duplicate()
	t.back_off_m = def.back_off_m
	t.card_casts = def.card_casts
	t.build_hp = def.hp_from_build  # the meter's rules (dps_seconds ...) are the Prism's, above
	t.build_hp_permille = def.build_hp_permille
	t.build_damage_permille = def.build_damage_permille
	t.damage_min = def.build_damage_min
	t.damage_cap_permille = def.build_damage_cap_permille
	t.shot_speed_min = def.shot_speed_min_mps / SimTick.TICKS_PER_SECOND
	t.shot_speed_max = def.shot_speed_max_mps / SimTick.TICKS_PER_SECOND
	t.shot_radius_min_m = def.shot_radius_min_m
	t.shot_radius_max_m = def.shot_radius_max_m
	t.shot_range_m = def.shot_range_m
	t.shots_max = def.shots_max
	t.reach_max_m = def.reach_max_m
	t.blast_min_m = def.blast_min_m
	t.blast_max_m = def.blast_max_m
