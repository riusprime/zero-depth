class_name IntensityCompiler
extends RefCounted
## v0.8.0 N5 (owner O58): IntensityDirectorDefinition into the sim's IntensityTable (CONTENT_SCHEMA §7). Its own
## file: ContentCompiler is at the lint's length limit.


## v0.8.0 N5: the intensity director in ticks and milli (intensity × 1000; per-second rates / 60, rounded); null
## without a definition (the director off).
static func compile(def: IntensityDirectorDefinition) -> IntensityTable:
	if def == null:
		return null
	var t := IntensityTable.new()
	t.close_radius_m = def.close_radius_m
	t.hit_full_hp_gain = def.hit_full_hp_gain * 1000
	t.close_kill_gain = def.close_kill_gain * 1000
	t.close_gain_per_tick = (def.close_gain_per_second * 1000 + 30) / SimTick.TICKS_PER_SECOND
	t.drain_per_tick = maxi(1, (def.drain_per_second * 1000 + 30) / SimTick.TICKS_PER_SECOND)
	t.calm_ticks = SimTick.seconds_to_ticks(def.calm_seconds)
	t.peak_level = def.peak_intensity * 1000
	t.peak_ticks_min = SimTick.seconds_to_ticks(def.peak_seconds_min)
	t.peak_ticks_max = SimTick.seconds_to_ticks(def.peak_seconds_max)
	t.pull_back_radius_m = def.pull_back_radius_m
	t.pull_back_enemies = def.pull_back_enemies
	t.pull_back_max_ticks = SimTick.seconds_to_ticks(def.pull_back_max_seconds)
	t.quiet_ticks_min = SimTick.seconds_to_ticks(def.quiet_seconds_min)
	t.quiet_ticks_max = SimTick.seconds_to_ticks(def.quiet_seconds_max)
	t.relax_level = def.relax_intensity * 1000
	t.build_interval_permille = def.build_interval_permille
	return t
