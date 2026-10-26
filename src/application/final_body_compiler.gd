class_name FinalBodyCompiler
extends RefCounted
## v0.8.0 FB2 (owner F7; FINAL_BOSS.md F5): a final body's own rules, beside ContentCompiler (which calls it for a
## FinalBossDefinition): its Crosses' bolt attacks (by index), its float and shards, and an HP set from the measured
## damage per second (the window share from its Crosses' cycles: windup, active, recovery and cooldown).
## v0.8.0 PR (owner O84): a body with spell_rotation casts its phase's attacks in order (BossTable.rotation); its
## window share is then the open part of one whole rotation (each Cross's window, every recovery and cooldown, and the
## active time of an attack that isn't shielded) over the rotation's length.
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
	t.rotation = def.spell_rotation
	if t.rotation and not def.phases.is_empty() and def.phases[0] != null:
		cycle = 0
		window = 0
		for id in def.phases[0].attack_ids:
			var k := t.attack_index(StringName(id))
			if k < 0:
				continue
			var at := t.attacks[k]
			if at.pattern != null and at.move != BossAttackTable.Move.CROSS:
				# an orb spell lasts until its last orb is gone (its last wave plus the orbs' life), so the next
				# Cross never waits on it in the open
				at.active_ticks = maxi(
					at.active_ticks, at.pattern.duration_ticks() + at.pattern.life_ticks
				)
			var open := at.recover_ticks + at.cooldown_ticks
			if at.move == BossAttackTable.Move.CROSS:
				open += at.window_ticks
			elif not at.shielded:
				open += at.windup_ticks + at.active_ticks
			cycle += at.windup_ticks + at.active_ticks + at.recover_ticks + at.cooldown_ticks
			window += open
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
	# v0.8.0 N2 (owner O41, O42, O52): the pace and The Fallen's windows.
	t.pace = def.pace
	t.pace_ref_dps = def.pace_ref_dps
	t.pace_ref_ticks = SimTick.seconds_to_ticks(def.pace_ref_seconds)
	t.pace_min_ticks = maxi(1, SimTick.seconds_to_ticks(def.pace_min_seconds))
	t.pace_max_ticks = SimTick.seconds_to_ticks(def.pace_max_seconds)
	t.pace_burst_ticks = SimTick.seconds_to_ticks(def.pace_burst_seconds)
	t.window_ticks = SimTick.seconds_to_ticks(def.mimic_window_seconds)
	t.window_every_ticks = maxi(1, SimTick.seconds_to_ticks(def.mimic_every_seconds))
	t.window_first_ticks = SimTick.seconds_to_ticks(def.mimic_first_seconds)
	t.window_warn_ticks = SimTick.seconds_to_ticks(def.mimic_warn_seconds)
	t.nerf_min_permille = def.mimic_nerf_min_permille
	_compile_mimic(def, t)
	_compile_interphase(def, t)


## v0.9.5 BH6 (BOSSES_HARD.md HC4-HC6): the Fallen's interphases and dashes, in sim units.
static func _compile_interphase(def: FinalBossDefinition, t: BossTable) -> void:
	if def.interphase.is_empty():
		return
	var ip := InterphaseTable.new()
	ip.thresholds = PackedInt32Array(
		[int(def.interphase_value("first_permille")), int(def.interphase_value("second_permille"))]
	)
	ip.ticks = SimTick.seconds_to_ticks(def.interphase_value("seconds"))
	ip.finish_ticks = SimTick.seconds_to_ticks(def.interphase_value("finish_seconds"))
	ip.atk_rays = t.attack_index(&"fallen_rays")
	ip.atk_rain = t.attack_index(&"fallen_rain")
	ip.atk_dark = t.attack_index(&"fallen_dark")
	ip.atk_erupt = t.attack_index(&"fallen_erupt")
	ip.atk_return = t.attack_index(&"fallen_return")
	ip.grace_ticks = SimTick.seconds_to_ticks(def.interphase_value("grace_seconds"))
	ip.slam_m = def.interphase_value("slam_m")
	ip.beam_count = int(def.interphase_value("beam_count"))
	ip.beam_half_m = float(def.interphase_value("beam_width_m")) * 0.5
	ip.beam_turn_milli = int(
		round(float(def.interphase_value("beam_turn_dps")) * 4096.0 * 1000.0 / 360.0 / 60.0)
	)
	ip.erupt_ticks = SimTick.seconds_to_ticks(def.interphase_value("erupt_seconds"))
	ip.erupt_m = def.interphase_value("erupt_m")
	ip.rain_ticks = SimTick.seconds_to_ticks(def.interphase_value("rain_seconds"))
	ip.rain_balls = int(def.interphase_value("rain_balls"))
	ip.rain_gap_slots = int(def.interphase_value("rain_gap_slots"))
	ip.rain_speed = float(def.interphase_value("rain_speed_mps")) / SimTick.TICKS_PER_SECOND
	ip.rain_radius_m = def.interphase_value("rain_radius_m")
	ip.rain_inset_m = def.interphase_value("rain_inset_m")
	ip.spike_ticks = SimTick.seconds_to_ticks(def.interphase_value("spike_seconds"))
	ip.spike_half_m = float(def.interphase_value("spike_width_m")) * 0.5
	ip.spike_speed = float(def.interphase_value("spike_speed_mps")) / SimTick.TICKS_PER_SECOND
	ip.spike_len_m = def.interphase_value("spike_length_m")
	ip.dark_balls = int(def.interphase_value("dark_balls"))
	ip.dark_ball_speed = (
		float(def.interphase_value("dark_ball_speed_mps")) / SimTick.TICKS_PER_SECOND
	)
	ip.dark_ball_radius_m = def.interphase_value("dark_ball_radius_m")
	ip.dark_erupt_ticks = SimTick.seconds_to_ticks(def.interphase_value("dark_erupt_seconds"))
	ip.light_m = def.interphase_value("light_m")
	ip.lamp_m = def.interphase_value("lamp_m")
	ip.lamp_ticks = SimTick.seconds_to_ticks(def.interphase_value("lamp_seconds"))
	ip.relight_m = def.interphase_value("relight_m")
	ip.lamp_inset_m = def.interphase_value("lamp_inset_m")
	ip.dash_telegraph_ticks = SimTick.seconds_to_ticks(
		def.interphase_value("dash_telegraph_seconds")
	)
	ip.dash_ticks = maxi(1, SimTick.seconds_to_ticks(def.interphase_value("dash_seconds")))
	ip.dash_min_m = def.interphase_value("dash_min_m")
	ip.dash_max_m = def.interphase_value("dash_max_m")
	ip.dash_wall_m = def.interphase_value("dash_wall_m")
	t.interphase = ip


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
