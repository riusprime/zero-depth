extends GutTest
## v0.9.5 BH2 (owner: "we have to modify 1 spell for each that will be hard to dodge"; BOSSES_HARD.md B1-B5):
## the Gatekeeper's Shock Lanes, the Warlord's Javelin Fan, the Brood Mother's Leap Chain, the Hive Lens's Focus Beam
## and the Siege Engine's Mortar Grid. Each test pins the spell's new numbers (telegraph, timing, lead, turn rate, safe
## cells, the swap) and plays the answer to it. Every telegraph is at least 0.55 s (33 ticks); no damage changed.

const S := EnemyAi.State
const LONG := 1 << 20
const MIN_TICKS := 33


func _fight(id: StringName, player_at: Vector2, boss_at := Vector2.ZERO, seed_value := 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, id, boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _table(id: StringName) -> BossTable:
	var w := BossLab.world()
	return w.boss_tables[BossLab.table_index(w, id)]


func _atk(t: BossTable, id: StringName) -> BossAttackTable:
	return t.attacks[t.attack_index(id)]


func _step_at(w: World, at: Vector2) -> void:
	w.actors.set_pos(0, at)
	w.step(InputFrame.new())


## B4 ---------------------------------------------------------------------------------------------------------------


func test_the_focus_beam_burns_for_1_2_s_and_turns_at_40_degrees_a_second() -> void:
	var t := _table(&"hive_lens")
	for id: StringName in [&"focus_beam", &"focus_beam_3"]:
		var atk := _atk(t, id)
		assert_eq(atk.active_ticks, 72, "%s: burns 1.2 s (was one 0.3 s sweep)" % id)
		assert_eq(
			atk.beam_turn_milli, 7585, "%s: 40 degrees a second, in 1/4096 turns x 1000 a tick" % id
		)
		assert_eq(atk.windup_ticks, 66, "%s: the 1.1 s telegraph" % id)
		assert_eq(atk.lock_ticks, 48, "%s: and its 0.8 s lock stay" % id)
	assert_eq(_atk(t, &"focus_beam").damage, 50)
	assert_eq(_atk(t, &"focus_beam_3").damage, 34)


## Runs a Focus Beam with the hero at `from` until it locks, then at `path.call(tick)`; returns [beam angles, damage].
func _beam(from: Vector2, path: Callable, id: StringName = &"focus_beam") -> Array:
	var s := _fight(&"hive_lens", from)
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), id)
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var angles: Array[int] = []
	for t in atk.windup_ticks - atk.lock_ticks:
		_step_at(w, from)
	for t in atk.lock_ticks:  # the hero moves as soon as the beam locks, as in play
		_step_at(w, path.call(t))
	for t in atk.active_ticks + 2:
		var i := w.actors.index_of(aid)
		if i < 0 or w.actors.state[i] != S.ACTIVE:
			break
		angles.append(w.actors.lock_a[i])
		_step_at(w, path.call(atk.lock_ticks + t))
	return [angles, LONG - w.actors.hp[0], w, aid]


func test_the_beam_turns_toward_the_hero_never_faster_than_the_rate() -> void:
	var r := _beam(Vector2(6, 0), func(_t: int) -> Vector2: return Vector2(0, 6))
	var angles: Array = r[0]
	assert_gte(angles.size(), 60, "it burns")
	var a0: int = angles[0]
	assert_lte(Kin.angle_diff(a0, 0), 8, "it starts where it locked (at the hero)")
	var worst := 0
	for k in range(1, angles.size()):
		worst = maxi(worst, Kin.angle_diff(angles[k], angles[k - 1]))
	assert_lte(worst, 8, "at most 8 units (45 degrees a second at a tick's rounding) a tick")
	var total := Kin.angle_diff(angles[angles.size() - 1], a0)
	assert_between(total, 400, 560, "about 40 degrees a second over its 1.2 s: 0.89 x 546")
	assert_eq(
		(angles[angles.size() - 1] - a0 + 4096) & 4095 < 2048,
		true,
		"turning toward +y, where the hero is"
	)


func test_stepping_aside_is_not_enough_but_circling_close_is() -> void:
	var stepped := _beam(Vector2(6, 0), func(_t: int) -> Vector2: return Vector2(6, 2.0))
	assert_gt(stepped[1], 0, "2 m to the side and standing there: the beam turns onto the hero")
	var circler := func(t: int) -> Vector2:
		# 6 m/s round the boss at 4 m (86 degrees a second): twice the beam's turn
		var a := 6.0 / 4.0 / 60.0 * t
		return Vector2(cos(a), sin(a)) * 4.0
	var circled := _beam(Vector2(4, 0), circler)
	assert_eq(circled[1], 0, "circling it at 4 m is never hit")
	var far := func(t: int) -> Vector2:
		var a := 3.0 / 11.0 / 60.0 * t  # 3 m/s round it at 11 m: 16 degrees a second, a stroll
		return Vector2(cos(a), sin(a)) * 11.0
	var far_run := _beam(Vector2(11, 0), far)
	assert_gt(
		far_run[1], 0, "a stroll round it is caught: the beam turns faster than a slow walker"
	)


func test_a_burning_beam_hits_each_attack_once_for_its_damage() -> void:
	var r := _beam(Vector2(6, 0), func(_t: int) -> Vector2: return Vector2(6, 0))
	assert_eq(r[1], 50, "standing in it costs one hit of 50, as before")


func test_the_three_beams_of_phase_3_turn_together() -> void:
	var r := _beam(Vector2(6, 0), func(_t: int) -> Vector2: return Vector2(0, 6), &"focus_beam_3")
	var w: World = r[2]
	var i := w.actors.index_of(r[3])
	var atk := BossAi.attack_of(w, i)
	assert_eq(atk.count, 3)
	var gaps := []
	for k in 3:
		gaps.append(BossAi.lane_angle(atk, w.actors.lock_a[i], k))
	assert_eq((gaps[1] - gaps[0]) & 4095, atk.spread, "still a fan 28 degrees apart")


## B5 ---------------------------------------------------------------------------------------------------------------


func test_the_mortar_grid_leaves_two_safe_cells_and_warns_the_swap_0_6_s() -> void:
	var t := _table(&"siege_engine")
	for id: StringName in [&"mortar_grid", &"mortar_grid_3"]:
		var atk := _atk(t, id)
		assert_eq(atk.safe_cells, 2, "%s: two safe cells" % id)
		assert_eq(atk.lock_ticks, 36, "%s: the later volley (the swap) shows 0.6 s ahead" % id)
		assert_gte(atk.lock_ticks, MIN_TICKS)
		assert_eq(atk.damage, 30, "%s: damage unchanged" % id)
		assert_lt(atk.lock_ticks, atk.mark_gap_ticks, "%s: shown after the last volley struck" % id)
	assert_eq(_atk(t, &"mortar_grid").volleys, 2)
	assert_eq(_atk(t, &"mortar_grid_3").volleys, 3)


func _grid(seed_value := 11, player_at := Vector2(7, 0), id := &"mortar_grid") -> Array:
	var s := _fight(&"siege_engine", player_at, Vector2.ZERO, seed_value)
	var w: World = s[0]
	var i := w.actors.index_of(s[1])
	BossLab.start(w, i, id)
	return [w, s[1]]


## The board's cell offsets (in cells) volley k does NOT strike.
func _safe(w: World, aid: int, k: int) -> Array:
	var i := w.actors.index_of(aid)
	var atk := BossAi.attack_of(w, i)
	var c := BossDodge.mark_of(w, i, 0)
	var struck := BossDodge.grid_discs(w, i, k)
	var out := []
	for y in range(-2, 3):
		for x in range(-2, 3):
			if not struck.has(c + Vector2(x, y) * atk.cell_m):
				out.append(Vector2i(x, y))
	return out


func test_every_volley_strikes_all_but_two_inner_cells_and_the_swap_picks_two_others() -> void:
	for sd in range(1, 25):
		var g := _grid(sd)
		var w: World = g[0]
		var a := _safe(w, g[1], 0)
		var b := _safe(w, g[1], 1)
		assert_eq(a.size(), 2, "seed %d: two safe cells" % sd)
		assert_eq(b.size(), 2, "seed %d: two safe cells after the swap" % sd)
		for o: Vector2i in a + b:
			assert_lte(
				maxi(absi(o.x), absi(o.y)), 1, "seed %d: never on the outer ring: %s" % [sd, o]
			)
		for o: Vector2i in a:
			assert_does_not_have(b, o, "seed %d: the swap goes to two other cells" % sd)
			assert_ne(
				o, Vector2i.ZERO, "seed %d: the first safe cells are never the hero's own cell" % sd
			)
		var beside := false
		for p: Vector2i in a:
			for q: Vector2i in b:
				beside = beside or maxi(absi(p.x - q.x), absi(p.y - q.y)) <= 1
		assert_true(
			beside, "seed %d: one new cell is within a cell of an old one (a way across)" % sd
		)


func test_a_three_volley_grid_swaps_halfway_through() -> void:
	var g := _grid(11, Vector2(7, 0), &"mortar_grid_3")
	var w: World = g[0]
	var v0 := _safe(w, g[1], 0)
	var v1 := _safe(w, g[1], 1)
	var v2 := _safe(w, g[1], 2)
	assert_eq(v0, v1, "volleys 1 and 2 hold the first cells")
	assert_ne(v1, v2, "volley 3 has swapped to the others")


func test_the_safe_cells_are_the_boss_streams_and_vary_with_the_seed() -> void:
	var seen := {}
	for sd in range(1, 41):
		var g := _grid(sd)
		seen[_safe(g[0], g[1], 0)] = true
	assert_gt(seen.size(), 3, "the draw varies")
	var one := _grid(5)
	var two := _grid(5)
	assert_eq(
		_safe(one[0], one[1], 0), _safe(two[0], two[1], 0), "and is the same for the same seed"
	)
	assert_eq(_safe(one[0], one[1], 1), _safe(two[0], two[1], 1))


func test_the_safe_cells_keep_off_the_wall() -> void:
	for sd in range(1, 25):
		var h := _grid(sd)
		var w2: World = h[0]
		w2.add_barrier(Obb.make(Vector2(7, 3.2), Vector2(6.0, 0.4), 0))
		for k in 2:
			for o: Vector2i in _safe(w2, h[1], k):
				var i := w2.actors.index_of(h[1])
				var at := BossDodge.mark_of(w2, i, 0) + Vector2(o) * 2.4
				assert_true(
					EnemyAi.clear_of_walls(w2, at, BossHard.WALL_MARGIN_M),
					"seed %d volley %d: %s keeps a metre off the wall" % [sd, k, o]
				)


## Runs a grid with the hero going to `at(k)` for each volley's strike; returns the hits taken at each strike.
func _grid_hits(sd: int, offsets: Array, id := &"mortar_grid") -> Array:
	var g := _grid(sd, Vector2(7, 0), id)
	var w: World = g[0]
	var i := w.actors.index_of(g[1])
	var atk := BossAi.attack_of(w, i)
	var c := Vector2(7, 0)
	var hits := []
	for k in offsets.size():
		hits.append(0)
	var strike_t := atk.windup_ticks
	for t in atk.windup_ticks + atk.mark_gap_ticks * (atk.volleys - 1) + 6:
		var k := 0
		for v in atk.volleys:
			if t >= atk.windup_ticks + atk.mark_gap_ticks * v - atk.lock_ticks:
				k = v
		var at: Vector2 = c + Vector2(offsets[mini(k, offsets.size() - 1)]) * atk.cell_m
		if t <= atk.windup_ticks - atk.lock_ticks:
			at = c  # the board follows the hero until it locks
		w.actors.set_pos(0, at)
		var before := w.actors.hp[0]
		w.step(InputFrame.new())
		if w.actors.hp[0] < before:
			hits[mini(k, hits.size() - 1)] += 1
		w.actors.invuln[0] = 0
	assert_gt(strike_t, 0)
	return hits


func test_standing_in_a_safe_cell_is_safe_until_the_swap_and_the_old_cell_is_not() -> void:
	var g := _grid(3)
	var a := _safe(g[0], g[1], 0)
	var b := _safe(g[0], g[1], 1)
	var stay := _grid_hits(3, [a[0], a[0]])
	assert_eq(stay, [0, 1], "staying in the first cell: safe, then struck by the swap")
	var swap := _grid_hits(3, [a[0], b[0]])
	assert_eq(swap, [0, 0], "moving to a new cell in time: never hit")
	var centre := _grid_hits(3, [Vector2i.ZERO, Vector2i.ZERO])
	assert_gte(centre[0], 1, "the hero's own cell is struck first")


func test_the_pockets_between_cells_are_not_safe() -> void:
	var g := _grid(3)
	var w: World = g[0]
	var i := w.actors.index_of(g[1])
	var c := BossDodge.mark_of(w, i, 0)
	var pocket := c + Vector2(1.5, 1.5) * 2.4  # between four outer-ring cells
	var struck := false
	for d in BossDodge.grid_discs(w, i, 0):
		struck = struck or AttackShapes.disc_touches(d, 1.45, pocket, w.player.radius_m)
	assert_true(struck, "a hero standing between four cells is touched by one of them")


## The loop ease numbers are data (BH1 cleanup) ---------------------------------------------------------------------


func test_the_loop_ease_numbers_are_the_sim_tuning_data() -> void:
	var repo := ContentRepository.load_all()
	var def: SimTuningDefinition = repo.get_def(&"tuning", &"sim")
	assert_eq(
		[def.loop_ease_max, def.loop_time_ease_permille, def.loop_damage_ease_permille],
		[3, 120, 80]
	)
	var w := World.new(1, PlayerTable.starting_values())
	w.tuning = RunContentCompiler.compile_sim_tuning(def)
	w.loop = 9
	assert_eq(FinalPace.loops_eased(w), 3)
	assert_eq(FinalPace.ease_permille(w), 640)
	assert_eq(FinalPace.damage_ease_permille(w), 760)
	w.tuning.loop_ease_max = 1
	w.tuning.loop_time_ease_permille = 200
	w.tuning.loop_damage_ease_permille = 50
	assert_eq(
		[FinalPace.ease_permille(w), FinalPace.damage_ease_permille(w)],
		[800, 950],
		"the data decides"
	)


func test_the_loop_ease_data_is_validated() -> void:
	var def := (load("res://data/tuning/sim.tres") as SimTuningDefinition).duplicate(true)
	assert_eq(def.validate(), [])
	def.loop_time_ease_permille = 400  # 3 loops x 400 = the whole fight
	assert_eq(def.validate().size(), 1)
	def.loop_time_ease_permille = 10
	def.loop_damage_ease_permille = 10
	def.loop_ease_max = 11
	assert_eq(def.validate().size(), 1)
	def.loop_damage_ease_permille = 80
	def.loop_ease_max = 3
	def.loop_damage_ease_permille = -1
	assert_eq(def.validate().size(), 1)


## The content rules of the hard spells -----------------------------------------------------------------------------


func _codes(d: BossDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func _def(id: String) -> BossDefinition:
	return (load("res://data/bosses/%s.tres" % id) as BossDefinition).duplicate(true)


func test_a_hard_spells_telegraph_and_lock_are_at_least_0_55_s() -> void:
	for id in ["gatekeeper", "warlord", "brood_mother", "hive_lens", "siege_engine"]:
		assert_eq(_codes(_def(id)), [], "%s ships valid" % id)
	var g := _def("gatekeeper")
	g.attack(&"shock_lanes_follow").lock_seconds = 0.5
	assert_has(_codes(g), &"telegraph_short", "a 0.5 s lock is under the rule")
	var w := _def("warlord")
	w.attack(&"javelin_fan").telegraph_seconds = 0.5
	assert_has(
		_codes(w), &"telegraph_short", "0.5 s is over the old 0.4 s minimum but under the hard rule"
	)
	var s := _def("siege_engine")
	s.attack(&"mortar_grid").lock_seconds = 0.5
	assert_has(_codes(s), &"telegraph_short", "the swap's warning is at least 0.55 s")


func test_the_hard_params_are_checked() -> void:
	var h := _def("hive_lens")
	h.attack(&"focus_beam").shape_params["turn_dps"] = 0.0
	assert_has(_codes(h), &"range")
	h = _def("hive_lens")
	h.attack(&"focus_beam").active_seconds = 0.3
	assert_has(_codes(h), &"duration", "a turning beam burns")
	h = _def("hive_lens")
	h.attack(&"gaze").shape_params["turn_dps"] = 40.0
	assert_has(_codes(h), &"param_unknown", "turn_dps belongs to a lanes beam")
	var b := _def("brood_mother")
	b.attack(&"leap_chain").shape_params["chain"] = 1
	assert_has(_codes(b), &"range", "a last leap needs a chain")
	var s := _def("siege_engine")
	s.attack(&"mortar_grid").shape_params["radius_m"] = 1.1
	assert_has(_codes(s), &"no_gap", "circles that leave a pocket the hero fits in")
	s = _def("siege_engine")
	s.attack(&"mortar_grid").shape_params["safe_cells"] = 9
	assert_has(_codes(s), &"range")
	var g := _def("gatekeeper")
	g.attack(&"shock_lanes_follow").shape_params.erase("second_offset_m")
	assert_has(_codes(g), &"missing")


func test_the_content_rules_use_the_stores_point_count() -> void:
	assert_eq(HardRules.MAX_POINTS, BossStore.MAX_PTS)
