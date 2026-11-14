class_name TimeCompiler
extends RefCounted
## Compiles a boss's time mechanics (BossDefinition.time, TimeRules.SPEC) into its table's BossTimeTable, in sim
## units (its own file: ContentCompiler is at its line limit).


## PatternCompiler.compile_cadence: the time mechanics, or none (t.time stays null).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var tm := def.time
	if tm.is_empty():
		return
	var tt := BossTimeTable.new()
	tt.wave_first_ticks = _ticks(tm, "wave_first_seconds")
	tt.wave_every_ticks = _ticks(tm, "wave_every_seconds")
	tt.wave_cut = _int(tm, "wave_cut_permille")
	tt.orb_count = _int(tm, "orb_count")
	tt.orb_gap_m = TimeRules.value(tm, "orb_gap_m")
	tt.orb_late_phase = _int(tm, "orb_late_phase")
	tt.orb = _orb(tm, 0)
	tt.orb_late = _orb(tm, _ticks(tm, "orb_late_seconds"))
	tt.gear_phase = _int(tm, "gear_phase")
	tt.gear_count = _int(tm, "gear_count")
	tt.gear_half = Vector2(
		TimeRules.value(tm, "gear_length_m") * 0.5, TimeRules.value(tm, "gear_width_m") * 0.5
	)
	tt.gear_ticks = _ticks(tm, "gear_seconds")
	tt.field_phase = _int(tm, "field_phase")
	tt.field_every_ticks = _ticks(tm, "field_every_seconds")
	tt.field = ShotFieldTable.new()
	tt.field.radius_m = TimeRules.value(tm, "field_radius_m")
	tt.field.life_ticks = _ticks(tm, "field_seconds")
	tt.field.speed_permille = _int(tm, "field_speed_permille")
	tt.field.max_count = _int(tm, "field_max")
	tt.dodge = TimeRules.value(tm, "dodge_mps") / SimTick.TICKS_PER_SECOND
	tt.rewind_phase = _int(tm, "rewind_phase")
	tt.step_ticks = _ticks(tm, "trail_step_seconds")
	tt.trail_ticks = _ticks(tm, "trail_seconds")
	tt.late_phase = _int(tm, "late_phase")
	tt.late_trail_ticks = _ticks(tm, "late_trail_seconds")
	tt.late_tolls = _int(tm, "late_tolls")
	tt.toll_gap_ticks = _ticks(tm, "toll_gap_seconds")
	tt.bell_first_ticks = _ticks(tm, "bell_first_seconds")
	tt.bell_every_ticks = _ticks(tm, "bell_every_seconds")
	tt.bell_cast_ticks = _ticks(tm, "bell_cast_seconds")
	tt.return_phase = _int(tm, "return_phase")
	tt.return_hp_permille = _int(tm, "return_hp_permille")
	tt.return_ticks = _ticks(tm, "return_seconds")
	tt.return_heal_permille = _int(tm, "return_heal_permille")
	tt.return_near_m = TimeRules.value(tm, "return_near_m")
	var reach := maxi(maxi(tt.trail_ticks, tt.late_trail_ticks), tt.return_ticks)
	tt.points = mini(reach / tt.step_ticks + 2, TimeRules.MAX_POINTS + 2)
	t.time = tt


## An hour orb that lies `life` ticks (0 = until taken or the next wave).
static func _orb(tm: Dictionary, life: int) -> BossPickupTable:
	var o := BossPickupTable.new()
	o.kind = BossPickupTable.Kind.RESTORE_ATTACK_SPEED
	o.amount = _int(tm, "orb_permille")
	o.radius_m = TimeRules.value(tm, "orb_radius_m")
	o.life_ticks = life
	o.max_count = _int(tm, "orb_count")
	return o


static func _int(tm: Dictionary, key: String) -> int:
	return int(TimeRules.value(tm, key))


static func _ticks(tm: Dictionary, key: String) -> int:
	return maxi(1, SimTick.seconds_to_ticks(TimeRules.value(tm, key)))
