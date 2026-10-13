class_name PatternCompiler
extends RefCounted
## v0.7.5 BF1 (owner N15; CONTENT_SCHEMA §4b): the dodge-first boss content in sim units, beside ContentCompiler
## (which calls it for every boss attack): a bullet pattern (BulletPatternDefinition -> BulletPatternTable), and a
## boss attack's lock, shield, marker spacing and pattern. Enemies (v0.7.5 EF) compile their patterns here too.


## v0.7.5 BF1: the tracked lock, the shield, the markers' spacing and the bullet pattern. A `marks` or `row_lanes`
## attack is active until its last marker strikes; a `pattern` attack for its pattern's whole duration (the data's
## active_seconds is a floor under both). v0.7.5 BF2: a `marks` attack with a pattern (eggs) until its last marker's
## burst has fired; a `burrow` may name one too (its eruption's ring; BossAi times that from the eruption).
static func compile_boss_attack(
	def: BossAttackDefinition, repo: ContentRepository, t: BossAttackTable
) -> void:
	var sp := def.shape_params
	t.lock_ticks = SimTick.seconds_to_ticks(def.lock_seconds)
	t.shielded = def.shielded
	t.mark_gap_ticks = SimTick.seconds_to_ticks(float(sp.get("stagger_seconds", 0.0)))
	if t.move == BossAttackTable.Move.MARKS or t.move == BossAttackTable.Move.ROW_LANES:
		t.active_ticks = maxi(t.active_ticks, (t.count - 1) * t.mark_gap_ticks + 1)
	if sp.has("pattern_id"):
		var pd: BulletPatternDefinition = repo.get_def(
			&"bullet_patterns", StringName(sp["pattern_id"])
		)
		if pd != null:
			t.pattern = compile_pattern(pd)
			t.active_ticks = maxi(t.active_ticks, t.pattern.duration_ticks())
			if t.move == BossAttackTable.Move.MARKS:  # v0.7.5 BF2: the last egg's burst, from its landing
				t.active_ticks = maxi(
					t.active_ticks,
					(
						(t.count - 1) * t.mark_gap_ticks
						+ t.pattern.duration_ticks()
						- t.pattern.lob_ticks
					)
				)


## v0.7.5 BF1: a bullet pattern in sim units (BulletPatterns fires it).
static func compile_pattern(def: BulletPatternDefinition) -> BulletPatternTable:
	var t := BulletPatternTable.new()
	t.id = def.id
	t.kind = def.kind as BulletPatternTable.Kind
	t.look = def.look
	t.speed = def.speed_mps / SimTick.TICKS_PER_SECOND
	t.radius_m = def.radius_m
	t.life_ticks = maxi(1, SimTick.seconds_to_ticks(def.range_m / def.speed_mps))
	t.waves = maxi(1, def.waves)
	t.wave_gap_ticks = maxi(1, SimTick.seconds_to_ticks(def.wave_gap_seconds))
	t.turn_per_wave = ContentCompiler.degrees_to_units(def.turn_per_wave_degrees)
	t.alternate = def.alternate
	t.aim_offset = ContentCompiler.degrees_to_units(def.aim_offset_degrees)
	t.safe_radius_m = def.safe_radius_m
	t.count = maxi(1, def.count)
	t.gap_count = def.gap_count
	t.gap_width = def.gap_width
	t.spread = ContentCompiler.degrees_to_units(def.spread_degrees)
	t.arms = maxi(1, def.arms)
	t.spin_milli = int(round(def.spin_dps * 4096.0 / 360.0 * 1000.0 / SimTick.TICKS_PER_SECOND))
	t.reverse_ticks = SimTick.seconds_to_ticks(def.reverse_at_seconds)
	t.wall_length_m = def.wall_length_m
	t.spacing_m = maxf(0.05, def.spacing_m)
	t.gap_m = def.gap_m
	t.gap_offset_m = def.gap_offset_m
	t.gap_shift_m = def.gap_shift_m
	t.crossing = def.crossing
	t.petals = def.petals
	t.petal_min_permille = def.petal_min_permille
	t.petal_cut_permille = def.petal_cut_permille
	t.lob_ticks = (
		SimTick.seconds_to_ticks(def.lob_seconds)
		if def.kind == BulletPatternDefinition.Kind.BURST
		else 0
	)
	t.land_radius_m = def.land_radius_m
	return t
