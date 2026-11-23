extends GutTest
## Every Foundry bullet pattern leaves the hero room to pass, measured from the compiled data: the widest hole
## between neighbouring shots' hit circles, where the hero stands 4 m (and so farther) from the boss, is at least the
## hero's width plus a margin; the crossing walls of the Furnace Waves leave one after the other, never together.

const HERO_RADIUS_M := 0.35
const MARGIN_M := 0.6
const NEED_M := 2.0 * HERO_RADIUS_M + MARGIN_M
## The nearest the hero crosses a pattern's shots, from the boss's centre (m).
const CROSS_M := 4.0
## A wall leaves this long (ticks) after the other one, and before the next wave's first (0.6 s).
const MIN_ALTERNATE_TICKS := 36
const BODY_R := 2.0


func _foundry() -> BossTable:
	var w := BossLab.world()
	return w.boss_tables[BossLab.table_index(w, &"foundry")]


func _patterns() -> Dictionary:
	var out := {}
	var t := _foundry()
	for a in t.attacks:
		if a.pattern != null:
			out[a.id] = a.pattern
	return out


## The widest hole (m) at CROSS_M between neighbouring rays (their angles), less the shots' own width.
func _widest_ray_gap_m(angles: Array, radius: float) -> float:
	angles.sort()
	var best := 0.0
	for k in angles.size():
		var next: float = angles[(k + 1) % angles.size()]
		var d: float = next - float(angles[k])
		if k == angles.size() - 1:
			d += TAU
		d = minf(d, PI)
		best = maxf(best, 2.0 * CROSS_M * sin(d * 0.5) - 2.0 * radius)
	return best


func _rays(p: BulletPatternTable, waves: Array) -> Array:
	var out: Array = []
	for k: int in waves:
		for v: Vector2 in BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, BODY_R)[1]:
			out.append(fposmod(v.angle(), TAU))
	return out


func test_every_foundry_pattern_is_found() -> void:
	var ps := _patterns()
	assert_has(ps, &"slag_fountain")
	assert_has(ps, &"slag_fountain_2")
	assert_has(ps, &"furnace_waves")


func test_the_slag_fountains_leave_a_lane_every_wave_and_between_neighbouring_waves() -> void:
	var ps := _patterns()
	for id: StringName in [&"slag_fountain", &"slag_fountain_2"]:
		var p: BulletPatternTable = ps[id]
		assert_eq(p.kind, BulletPatternTable.Kind.FLOWER)
		for k in p.waves:
			var one := _widest_ray_gap_m(_rays(p, [k]), p.radius_m)
			assert_gte(one, NEED_M, "%s wave %d: the widest gap is %.2f m" % [id, k, one])
		for k in p.waves - 1:
			# The lane the hero stands in while wave k passes must stay open through wave k + 1.
			var two := _widest_ray_gap_m(_rays(p, [k, k + 1]), p.radius_m)
			assert_gte(
				two, NEED_M, "%s waves %d+%d: the widest gap is %.2f m" % [id, k, k + 1, two]
			)


func test_each_furnace_wall_leaves_a_lane() -> void:
	var p: BulletPatternTable = _patterns()[&"furnace_waves"]
	assert_eq(p.kind, BulletPatternTable.Kind.WALL)
	for k in p.waves:
		for part in 2:
			var lateral: Array = []
			for q: Vector2 in BulletPatterns.wave_shots(p, k, Vector2.ZERO, 0, BODY_R, part)[0]:
				lateral.append(q.y if part == 0 else q.x)
			lateral.sort()
			var widest := 0.0
			for j in range(1, lateral.size()):
				widest = maxf(widest, float(lateral[j]) - float(lateral[j - 1]) - 2.0 * p.radius_m)
			assert_gte(
				widest, NEED_M, "wave %d wall %d: the widest gap is %.2f m" % [k, part, widest]
			)


func test_the_two_furnace_walls_leave_one_after_the_other() -> void:
	var p: BulletPatternTable = _patterns()[&"furnace_waves"]
	assert_true(p.crossing)
	assert_gte(p.cross_delay_ticks, MIN_ALTERNATE_TICKS, "the second wall waits")
	assert_gte(
		p.wave_gap_ticks - p.cross_delay_ticks,
		MIN_ALTERNATE_TICKS,
		"and the next wave's first wall waits for it"
	)
