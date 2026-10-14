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
	if t.move == BossAttackTable.Move.GRID:  # v0.7.5 BF3: until its last volley strikes
		t.active_ticks = maxi(t.active_ticks, (t.volleys - 1) * t.mark_gap_ticks + 1)
	if t.move == BossAttackTable.Move.COMBO:  # v0.8.0 FB1: until the slam after its last swing
		t.active_ticks = maxi(t.active_ticks, t.count * t.mark_gap_ticks + 1)
	if t.move == BossAttackTable.Move.SPIKE_CHASE or t.move == BossAttackTable.Move.SPIKE_BURST:
		t.active_ticks = maxi(t.active_ticks, (t.steps - 1) * t.mark_gap_ticks + 1)
	if t.move == BossAttackTable.Move.CROSS:  # v0.8.0 FB2: the spin, then its window
		t.spin_ticks = SimTick.seconds_to_ticks(float(sp.get("spin_seconds", 0.0)))
		t.window_ticks = SimTick.seconds_to_ticks(float(sp.get("window_seconds", 0.0)))
		t.active_ticks = maxi(t.active_ticks, t.spin_ticks + t.window_ticks)
		t.fast_quarter_ticks = SimTick.seconds_to_ticks(float(sp.get("fast_quarter_seconds", 0.0)))
		t.bolt_every_ticks = SimTick.seconds_to_ticks(float(sp.get("bolt_every_seconds", 0.0)))
	_compile_signature(def, t)
	if t.pillar_ticks > 0:  # v0.8.0 BS1 (S1): the last cross's pillars rise the tick after it strikes
		t.active_ticks = maxi(t.active_ticks, (t.count - 1) * t.mark_gap_ticks + 2)
	if sp.has("pattern_id"):
		var pd: BulletPatternDefinition = repo.get_def(
			&"bullet_patterns", StringName(sp["pattern_id"])
		)
		if pd != null:
			t.pattern = compile_pattern(pd)
			var own_clock := (
				t.move == BossAttackTable.Move.GAZE
				or t.move == BossAttackTable.Move.LEAP
				or t.move == BossAttackTable.Move.CROSS
			)  # v0.8.0 FB1: a leap's ring fires on its landing, inside its flight; FB2: a Cross's orbs repeat
			if t.egg_ticks <= 0 and not own_clock:
				# v0.8.0 BS1 (S3): an egg bursts on its own clock, after the attack; v0.8.0 BS2 (S4): a gaze's orbs
				# fire again and again over its own active time.
				t.active_ticks = maxi(t.active_ticks, t.pattern.duration_ticks())
			if t.recall_ticks > 0:  # v0.8.0 BS1 (S2): out, stuck, then back along the same lines
				t.recall_at = t.pattern.duration_ticks() + t.pattern.life_ticks + t.recall_ticks
				t.active_ticks = maxi(t.active_ticks, t.recall_at + t.pattern.life_ticks + 1)
			if t.move == BossAttackTable.Move.MARKS and t.egg_ticks <= 0:  # v0.7.5 BF2: the last egg's burst
				t.active_ticks = maxi(
					t.active_ticks,
					(
						(t.count - 1) * t.mark_gap_ticks
						+ t.pattern.duration_ticks()
						- t.pattern.lob_ticks
					)
				)


## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S1-S3): the signature numbers: the Gatekeeper's pillars, the Warlord's
## recall, the Brood Mother's eggs (their enemy kind and cap come from enemy_id and max_alive, as a brood's), and the
## late part's death line. burst_phase is 1-based in data, a phase index here (99 = never).
static func _compile_signature(def: BossAttackDefinition, t: BossAttackTable) -> void:
	var sp := def.shape_params
	t.late_cause_key = def.late_cause_key
	t.pillar_ticks = SimTick.seconds_to_ticks(float(sp.get("pillar_seconds", 0.0)))
	t.pillar_m = float(sp.get("pillar_m", 0.0))
	t.pillar_step_m = float(sp.get("pillar_step_m", 0.0))
	t.recall_ticks = SimTick.seconds_to_ticks(float(sp.get("recall_seconds", 0.0)))
	t.egg_ticks = SimTick.seconds_to_ticks(float(sp.get("egg_seconds", 0.0)))
	t.egg_hp = int(sp.get("egg_hp", 0))
	t.burst_phase = int(sp["burst_phase"]) - 1 if sp.has("burst_phase") else 99
	# v0.8.0 BS2 (S4-S6): the Hive Lens's gaze, the Siege Engine's ricochets, the Foundry's lava and melt.
	t.quarter_ticks = SimTick.seconds_to_ticks(float(sp.get("quarter_seconds", 0.0)))
	t.reverse_ticks = SimTick.seconds_to_ticks(float(sp.get("reverse_seconds", 0.0)))
	t.orb_every_ticks = SimTick.seconds_to_ticks(float(sp.get("orb_every_seconds", 0.0)))
	t.bounces = int(sp.get("bounces", 0))
	t.bounce_phase = int(sp["bounce_phase"]) - 1 if sp.has("bounce_phase") else 99
	t.lava_ticks = SimTick.seconds_to_ticks(float(sp.get("lava_seconds", 0.0)))
	t.lava_damage = int(sp.get("lava_damage", 0))
	t.lava_burn_ticks = maxi(1, SimTick.seconds_to_ticks(float(sp.get("lava_burn_seconds", 0.0))))
	t.ford_m = float(sp.get("ford_m", 0.0))
	t.melt_ring_m = float(sp.get("ring_m", 0.0))
	t.melt_min_m = float(sp.get("min_radius_m", 0.0))
	t.melt_step_m = float(sp.get("step_m", 0.0))
	t.melt_step_ticks = SimTick.seconds_to_ticks(float(sp.get("step_seconds", 0.0)))
	t.melt_warn_ticks = SimTick.seconds_to_ticks(float(sp.get("warn_seconds", 0.0)))


## v0.7.5 EF (owner N16): an enemy's patterns, one per attack in order (null where an attack names none): the Arc
## Caster's bolt and spread fans, the Lens Drone's ring, the Bomb Drone's lobbed burst. A pattern attack is active
## until its last wave (its pattern's duration; the data's active_seconds is a floor).
static func compile_enemy_patterns(
	def: EnemyDefinition, repo: ContentRepository, t: EnemyTable
) -> void:
	t.patterns.clear()
	var any := false
	for atk in def.attacks:
		var pat: BulletPatternTable = null
		if atk != null and atk.shape_params.has("pattern_id"):
			var pd: BulletPatternDefinition = repo.get_def(
				&"bullet_patterns", StringName(atk.shape_params["pattern_id"])
			)
			if pd != null:
				pat = compile_pattern(pd)
				any = true
		t.patterns.append(pat)
	if not any:
		t.patterns.clear()


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
	if def.kind == BulletPatternDefinition.Kind.FLOWER and def.rain_seconds > 0.0:  # v0.7.5 BF3
		t.rain_ticks = maxi(1, SimTick.seconds_to_ticks(def.rain_seconds))
		t.lob_ticks = t.rain_ticks
		t.rain_m = def.rain_m
	return t
