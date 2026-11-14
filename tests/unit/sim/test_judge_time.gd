# gdlint: disable=max-public-methods
extends GutTest
## The Clockwork Judge fights with time (owner brief rows CJ1-CJ5 and the Rewind; docs/roadmap/v0.12.0/BOSS_BRIEF.md):
## the Time Wave on its cadence takes 75 % of the weapon's rate, undodgeable and without damage; three hour orbs of 25
## each, spread apart, with hint markers; from phase 2 stopped gears across the lines to the orbs that never seal one
## in, slow fields between the hero and the Judge, and the Judge's side-step; the Rewind (the pale copy, the Bell's
## throw, the Bell's own Verdict on the copy); phase 3's running orbs, double toll and the Judge's own return; the
## end of the fight; determinism and a save in the middle of it.

const S := EnemyAi.State
const WAVE_CAST := 90
const WAVE_FIRST := 480
const WAVE_EVERY := 1500


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _time(w: World, aid: int) -> BossTimeTable:
	return BossAi.table_of(w, _i(w, aid)).time


## A hushed fight in `phase` whose first Time Wave has just landed. Returns [world, the Judge's id].
func _after_wave(phase: int, hero_at := Vector2(-6, 0), seed_value: int = 11) -> Array:
	var s := JudgeLab.fight(hero_at, Vector2(6, 0), seed_value)
	var w: World = s[0]
	JudgeLab.hush(w, s[1])
	JudgeLab.set_phase(w, s[1], phase)
	BossAi.table_of(w, _i(w, s[1])).speed = 0.0
	w.step(InputFrame.new())
	BossLab.start(w, _i(w, s[1]), &"time_wave")
	assert_not_null(JudgeLab.until_effect(w, BossTime.WAVE, WAVE_CAST + 5), "the wave lands")
	return s


func _orbs(w: World) -> Array:
	return WorldReader.new(w).boss_pickups()


func test_the_data_is_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"clockwork_judge")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	var tt := t.time
	assert_not_null(tt, "the Judge has its time mechanics")
	assert_eq([tt.wave_first_ticks, tt.wave_every_ticks, tt.wave_cut], [480, 1500, 750])
	assert_eq([tt.orb_count, tt.orb.amount, tt.orb.life_ticks, tt.orb.max_count], [3, 250, 0, 3])
	assert_almost_eq(tt.orb.radius_m, 1.2, 0.0001)
	assert_almost_eq(tt.orb_gap_m, 8.0, 0.0001)
	assert_eq([tt.orb_late_phase, tt.orb_late.life_ticks], [2, 600], "phase 3: each lasts 10 s")
	assert_eq(
		[tt.gear_phase, tt.gear_count, tt.gear_ticks], [1, 4, 720], "gears from phase 2, 12 s"
	)
	assert_eq(tt.gear_half, Vector2(2.5, 0.4), "5 m long")
	assert_eq([tt.field_phase, tt.field_every_ticks], [1, 420], "a field every 7 s from phase 2")
	assert_eq([tt.field.life_ticks, tt.field.speed_permille, tt.field.max_count], [480, 200, 3])
	assert_almost_eq(tt.field.radius_m, 1.75, 0.0001)
	assert_eq([tt.rewind_phase, tt.trail_ticks, tt.step_ticks], [1, 240, 15], "the copy 4 s behind")
	assert_eq([tt.bell_first_ticks, tt.bell_every_ticks, tt.bell_cast_ticks], [900, 1200, 120])
	assert_eq(tt.bell_verdict_ticks, 27, "the Bell's Verdict drops 0.45 s after the toll")
	assert_eq(BossRewind.verdict_attack(t), t.attack_index(&"verdict"), "and it is the Verdict's")
	assert_eq(
		[tt.late_phase, tt.late_trail_ticks, tt.late_tolls, tt.toll_gap_ticks], [2, 360, 2, 180]
	)
	assert_eq([tt.return_phase, tt.return_hp_permille, tt.return_ticks], [2, 150, 300])
	assert_eq(tt.return_heal_permille, 50)
	assert_almost_eq(tt.return_near_m, 4.0, 0.0001)
	var wave := t.attacks[t.attack_index(&"time_wave")]
	assert_eq(wave.move, BossAttackTable.Move.TIME_WAVE)
	assert_eq([wave.windup_ticks, wave.damage], [WAVE_CAST, 0], "a 1.5 s cast, no damage")
	for p in 3:
		assert_eq(BossTime.wave_attack(t, p), t.attack_index(&"time_wave"), "phase %d" % p)
		assert_eq(BossTide.signature_of(t, p), t.attack_index(&"the_echo"), "the echo stays")
	for other: BossTable in BossLab.tables():
		if other.id != &"clockwork_judge":
			assert_null(other.time, "%s has none" % other.id)


func _codes_with(change: Callable) -> Array:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = (
		(repo.get_def(&"bosses", &"clockwork_judge") as BossDefinition).duplicate(true)
	)
	change.call(def)
	return def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_bad_time_numbers_are_errors() -> void:
	assert_has(_codes_with(func(d: BossDefinition) -> void: d.time["nope"] = 1), &"unknown_field")
	assert_has(
		_codes_with(func(d: BossDefinition) -> void: d.time["wave_cut_permille"] = 950), &"range"
	)
	assert_has(
		_codes_with(func(d: BossDefinition) -> void: d.time["late_trail_seconds"] = 2.0), &"range"
	)
	assert_has(
		_codes_with(func(d: BossDefinition) -> void: d.time["bell_every_seconds"] = 5.0),
		&"duration"
	)
	assert_has(
		_codes_with(func(d: BossDefinition) -> void: d.time["bell_verdict_delay_seconds"] = 2.5),
		&"duration",
		"the Bell's Verdict drops before the next toll"
	)
	assert_has(
		_codes_with(func(d: BossDefinition) -> void: d.attack(&"verdict").move = &"slam_ring"),
		&"attacks",
		"the Bell's Verdict needs a verdict attack"
	)
	var drop := func(d: BossDefinition) -> void: d.phases[1].attack_ids = ["the_echo", "verdict"]
	assert_has(_codes_with(drop), &"attacks", "a time_wave in every phase")
	assert_has(_codes_with(func(d: BossDefinition) -> void: d.time = {}), &"missing")
	assert_has(
		_codes_with(func(d: BossDefinition) -> void: d.attack(&"time_wave").damage = 5),
		&"range",
		"a cast deals no damage"
	)


func test_the_wave_is_cast_on_its_cadence_and_takes_75_percent() -> void:
	var s := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	JudgeLab.only_wave(w, aid)
	w.step(InputFrame.new())
	var first := w.bosses.time_wave_due
	assert_eq(first, w.tick - 1 + WAVE_FIRST, "the first one 8 s after it may first attack")
	var cast := JudgeLab.until_effect(w, BossTime.CAST, WAVE_FIRST + 5)
	assert_not_null(cast, "it casts")
	assert_eq(cast.tick, first, "on the tick it is due")
	assert_eq(cast.amount, WAVE_CAST, "a 1.5 s cast")
	assert_eq(BossSlow.cut(w), 0, "nothing taken during the cast")
	assert_eq(WorldReader.new(w).boss_time()["wave"], 0, "the view reads the cast's progress")
	w.actors.invuln[0] = 10000  # A dash's or a hit's i-frames do not stop it
	var hp := w.actors.hp[0]
	var wave := JudgeLab.until_effect(w, BossTime.WAVE, WAVE_CAST + 5)
	assert_not_null(wave, "the wave lands")
	assert_eq(wave.tick, cast.tick + WAVE_CAST, "as the cast ends")
	assert_eq(wave.amount, 750)
	assert_eq(BossSlow.cut(w), 750, "75 % of the weapon's rate")
	assert_eq(w.bosses.aslow_boss, aid)
	assert_eq(w.actors.hp[0], hp, "no damage")
	assert_eq(WorldReader.new(w).boss_time()["wave"], -1)
	var again := JudgeLab.until_effect(w, BossTime.CAST, WAVE_EVERY + 5, wave.seq)
	assert_not_null(again, "it casts again")
	assert_eq(again.tick, cast.tick + WAVE_EVERY, "every 25 s, start to start")


func test_the_wave_waits_for_the_echo_and_is_never_picked() -> void:
	var s := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var t := BossAi.table_of(w, _i(w, aid))
	var wave := t.attack_index(&"time_wave")
	var echo := t.attack_index(&"the_echo")
	var b := BossAi.entry_of(w, _i(w, aid))
	var casts := 0
	for k in 60 * 40:
		var was := w.bosses.attack[b]
		w.step(InputFrame.new())
		w.actors.hp[0] = JudgeLab.LONG
		var now := w.bosses.attack[b]
		if now == wave and was != wave:
			casts += 1
			assert_ne(was, echo, "never out of the echo")
			assert_gte(w.tick, WAVE_FIRST, "not before its first due tick")
	assert_eq(casts, 2, "8 s, then 25 s later: two in 40 s, none by the weighted pick")


func test_three_orbs_spread_apart_give_it_back() -> void:
	var s := _after_wave(0)
	var w: World = s[0]
	var orbs := _orbs(w)
	assert_eq(orbs.size(), 3, "three hour orbs")
	var hero := w.player_pos()
	for k in 3:
		var c: Vector2 = orbs[k]["centre"]
		assert_eq([orbs[k]["amount"], orbs[k]["left"]], [250, -1], "25 each, they stay")
		assert_almost_eq(float(orbs[k]["radius"]), 1.2, 0.0001)
		assert_gte(c.distance_to(hero), 8.0, "8 m from the hero")
		assert_true(w.bosses.arena.grow(-2.19).has_point(c), "inside the room, off its walls")
		for j in k:
			assert_gte(c.distance_to(orbs[j]["centre"]), 8.0, "8 m from each other")
	assert_eq(WorldReader.new(w).objectives().size(), 3, "a marker on each")
	assert_true(w.objectives.has(ObjectiveMarkers.JUDGE_ORB))
	assert_true(w.bosses.gear_x.is_empty(), "phase 1: in the open, no gears")
	var cut := 750
	for k in 3:
		w.actors.set_pos(0, _orbs(w)[0]["centre"])
		w.step(InputFrame.new())
		cut -= 250
		assert_eq(BossSlow.cut(w), cut, "an orb returns 25")
		assert_eq(w.objectives.reasons.count("judge_orb"), 2 - k, "its marker goes with it")
	assert_eq(w.bosses.aslow_boss, -1, "all of it back")


func test_the_next_wave_replaces_the_orbs() -> void:
	var s := _after_wave(0)
	var w: World = s[0]
	var before := _orbs(w).map(func(o: Dictionary) -> int: return o["id"])
	w.actors.set_pos(0, _orbs(w)[0]["centre"])
	w.step(InputFrame.new())
	assert_eq(BossSlow.cut(w), 500)
	CombatLab.idle(w, 120)
	var seq := JudgeLab.effects(w, BossTime.WAVE)[0].seq
	BossLab.start(w, _i(w, s[1]), &"time_wave")
	assert_not_null(JudgeLab.until_effect(w, BossTime.WAVE, WAVE_CAST + 5, seq))
	var after := _orbs(w).map(func(o: Dictionary) -> int: return o["id"])
	assert_eq(after.size(), 3, "three again")
	for id: int in after:
		assert_does_not_have(before, id, "all new")
	assert_eq(BossSlow.cut(w), 750, "and 75 % again")
	assert_eq(w.objectives.reasons.count("judge_orb"), 3)


func test_phase_3_orbs_run_out() -> void:
	var s := _after_wave(2)
	var w: World = s[0]
	var orbs := _orbs(w)
	assert_eq(orbs.size(), 3)
	assert_eq(orbs[0]["left"] + orbs[0]["age"], 600, "each lasts 10 s")
	w.bosses.time_bell_due = 1 << 29  # Not this test's
	w.bosses.time_field_due = 1 << 29
	CombatLab.idle(w, 599)
	assert_eq(_orbs(w).size(), 3, "still there a tick before")
	CombatLab.idle(w, 1)
	assert_eq(_orbs(w).size(), 0, "gone until the next wave")
	assert_false(w.objectives.has(ObjectiveMarkers.JUDGE_ORB), "the markers too")
	assert_eq(BossSlow.cut(w), 750, "the cut stays")


func test_gears_cross_the_lines_to_the_orbs_and_go_after_12_s() -> void:
	var s := _after_wave(1)
	var w: World = s[0]
	var hero := w.player_pos()
	var bs := w.bosses
	var orbs := _orbs(w)
	var n := bs.gear_x.size()
	assert_between(n, 3, 4, "3-4 gears")
	assert_eq(w.walls.size(), 4 + n, "each is a wall")
	var gears: Array = WorldReader.new(w).boss_time()["gears"]
	assert_eq(gears.size(), n, "the view reads them")
	for g in n:
		var c: Vector2 = gears[g]["centre"]
		var orb: Vector2 = orbs[g % 3]["centre"]
		assert_lt(
			BossGears.seg_dist(c, hero, orb), 0.01, "gear %d lies across the line to its orb" % g
		)
		assert_eq(gears[g]["half"], Vector2(2.5, 0.4), "5 m long")
		assert_eq(gears[g]["left"] + gears[g]["age"], 720, "12 s")
		assert_eq(gears[g]["angle"], (Kin.angle_of(orb - hero) + 1024) & 4095, "across it")
		assert_false(EnemyAi.clear_of_walls(w, c, 0.1), "solid")
		assert_gte(
			BossGears.seg_dist(hero, _end(gears[g], -1), _end(gears[g], 1)), 0.4 + 0.35 + 0.5
		)
		var judge := w.actors.pos(_i(w, s[1]))
		assert_gte(
			BossGears.seg_dist(judge, _end(gears[g], -1), _end(gears[g], 1)), 0.4 + 1.4 + 0.5
		)
	bs.time_bell_due = 1 << 29
	bs.time_field_due = 1 << 29
	CombatLab.idle(w, 719)
	assert_eq(bs.gear_x.size(), n, "standing a tick before")
	CombatLab.idle(w, 1)
	assert_eq(bs.gear_x.size(), 0, "gone after 12 s")
	assert_eq(w.walls.size(), 4, "the walls too")


func _end(gear: Dictionary, side: int) -> Vector2:
	return gear["centre"] + Kin.dir(gear["angle"]) * (gear["half"].x * side)


func test_a_gear_stops_the_hero_and_both_sides_shots() -> void:
	var s := _after_wave(1)
	var w: World = s[0]
	var gear: Dictionary = WorldReader.new(w).boss_time()["gears"][0]
	var c: Vector2 = gear["centre"]
	var n := Kin.dir(gear["angle"] + 1024)  # Across the gear
	w.actors.set_pos(0, c - n * 1.5)
	w.vel = Vector2.ZERO
	var push := Vector2i(roundi(n.x * 127.0), roundi(n.y * 127.0))
	for k in 60:
		w.step(InputFrame.make(push, 0, 300, 0, 0))
	assert_lt((w.player_pos() - c).dot(n), -0.7, "the hero does not walk through it")
	var me := w.actors.ids[0]
	w.actors.set_pos(0, c - n * 3.5)  # Out of the shots' way
	for team in [ActorStore.TEAM_PLAYER, ActorStore.TEAM_ENEMY]:
		var owner: int = me if team == ActorStore.TEAM_PLAYER else s[1]
		w.queue_projectile(owner, team, c - n * 1.2, n * 0.2, 1, 0.15, 120, SimEvent.TAG_PROJECTILE)
		CombatLab.idle(w, 30)
		var through := false
		for k in w.projectiles.size():
			var p := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
			through = through or (p - c).dot(n) > 0.4
		assert_false(through, "a shot of team %d does not pass it" % team)


func test_no_gears_before_phase_2_and_none_on_a_body() -> void:
	var s := _after_wave(0)
	assert_true((s[0] as World).bosses.gear_x.is_empty())
	var w := JudgeLab.world()
	var i := BossLab.ready_boss(w, &"clockwork_judge", Vector2(6, 0))
	w.actors.set_pos(0, Vector2(-6, 0))
	var half := Vector2(2.5, 0.4)
	var none := PackedVector2Array()
	assert_true(BossGears.fits(w, Vector2(0, 0), half, 1024, none), "open floor")
	assert_false(BossGears.fits(w, Vector2(-6, 0.5), half, 0, none), "not on the hero")
	assert_false(BossGears.fits(w, Vector2(6, 1.5), half, 0, none), "not on the Judge")
	assert_false(
		BossGears.fits(w, Vector2(0, 11.0), half, 0, none), "not closing the way along a wall"
	)
	assert_false(BossGears.fits(w, Vector2(11.0, 0), half, 0, none), "not out of the room")
	assert_false(
		BossGears.fits(w, Vector2(0, 0), half, 0, PackedVector2Array([Vector2(1, 0.9)])),
		"not on an orb"
	)
	w.add_barrier(Obb.make(Vector2(0, 0), half, 0))
	assert_false(
		BossGears.fits(w, Vector2(0, 1.4), half, 0, none), "the hero's width from another gear"
	)
	assert_true(BossGears.fits(w, Vector2(0, 2.0), half, 0, none), "a passable gap is fine")
	assert_gt(i, 0)


## The geometric rule (each gear an island the hero's width from every wall and gear) checked by a flood: a body a
## little thinner than the hero (0.12 m, so the 0.2 m grid finds the narrowest pass the rule leaves) walks from the
## hero's place to every orb, whatever the seed and wherever both stand.
func test_every_orb_stays_reachable_with_the_gears_up() -> void:
	var seeds := Seeds.count(400)
	var gears := 0
	var orbs_placed := 0
	for sv in seeds:
		var rng := RngStream.derive(sv, "judge_gears_test")
		var hero := Vector2(rng.range_int(-1100, 1100), rng.range_int(-1100, 1100)) * 0.01
		var judge := Vector2(rng.range_int(-1000, 1000), rng.range_int(-1000, 1000)) * 0.01
		if hero.distance_to(judge) < 3.0:
			judge = hero + Vector2(3.0, 0.0) * (1.0 if hero.x < 0.0 else -1.0)
		var s := JudgeLab.fight(hero, judge, sv + 1)
		var w: World = s[0]
		var i := _i(w, s[1])
		JudgeLab.hush(w, s[1])
		JudgeLab.set_phase(w, s[1], 1 + sv % 2)
		w.step(InputFrame.new())
		hero = w.player_pos()
		var b := BossAi.entry_of(w, i)
		var t := BossAi.table_of(w, i)
		BossTime.resolve_wave(w, i, b, t.attacks[t.attack_index(&"time_wave")])
		gears += w.bosses.gear_x.size()
		var orbs := _orbs(w)
		orbs_placed += orbs.size()
		var r := w.player.radius_m - 0.12
		for o: Dictionary in orbs:
			var c: Vector2 = o["centre"]
			if not JudgeLab.reachable(w, hero, c, r, 0.2, 0.5):
				assert_true(false, "seed %d: the orb at %s is sealed in" % [sv, c])
		for g in w.bosses.gear_x.size():
			var o := BossGears.obb(w.bosses, g)
			for j in w.actors.size():
				var hit := Collide.circle_vs_obb(w.actors.pos(j), w.actors.radius[j], o)
				if hit != Vector2.ZERO:
					assert_true(false, "seed %d: a gear rose on a body" % sv)
	gut.p("gears: %d seeds, %d orbs placed, %d gears raised" % [seeds, orbs_placed, gears])
	assert_eq(orbs_placed, seeds * 3, "three orbs every time")
	assert_gt(gears, seeds * 2, "and gears most of the time (more than two a wave on average)")


func test_slow_fields_are_laid_between_the_two_from_phase_2() -> void:
	var s := JudgeLab.fight(Vector2(-6, 2), Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	JudgeLab.hush(w, aid)
	BossAi.table_of(w, _i(w, aid)).speed = 0.0
	CombatLab.idle(w, 600)
	assert_eq(WorldReader.new(w).boss_shot_fields().size(), 0, "none in phase 1")
	JudgeLab.set_phase(w, aid, 1)
	w.bosses.time_bell_due = 1 << 29
	w.step(InputFrame.new())
	var due := w.bosses.time_field_due
	assert_eq(due, w.tick - 1 + 420, "the first 7 s into the phase")
	var laid := JudgeLab.until_effect(w, BossTime.FIELD, 425)
	assert_not_null(laid)
	assert_eq(laid.tick, due)
	var fields := WorldReader.new(w).boss_shot_fields()
	assert_eq(fields.size(), 1)
	assert_almost_eq(
		fields[0]["centre"], Vector2(0, 1), Vector2(0.01, 0.01), "half-way between them"
	)
	assert_almost_eq(float(fields[0]["radius"]), 1.75, 0.0001)
	assert_eq(
		[fields[0]["speed"], fields[0]["left"] + fields[0]["age"]], [200, 480], "20 % for 8 s"
	)
	CombatLab.idle(w, 420 * 3)
	assert_between(WorldReader.new(w).boss_shot_fields().size(), 1, 3, "never more than three")
	assert_eq(JudgeLab.effects(w, BossTime.FIELD).size(), 4, "one every 7 s")


func test_the_judge_steps_out_of_a_crawling_shots_line() -> void:
	for with_field in [true, false]:
		var s := JudgeLab.fight(Vector2(-8, 0), Vector2(6, 0))
		var w: World = s[0]
		var aid: int = s[1]
		JudgeLab.hush(w, aid)
		var t := BossAi.table_of(w, _i(w, aid))
		t.speed = 0.0
		JudgeLab.set_phase(w, aid, 1)
		w.bosses.time_bell_due = 1 << 29
		w.step(InputFrame.new())
		w.bosses.time_field_due = 1 << 29
		if with_field:
			BossShotFields.place(w, aid, t.time.field, Vector2(0, 0))
		var me := w.actors.ids[0]
		w.queue_projectile(
			me, ActorStore.TEAM_PLAYER, Vector2(-1, 0.2), Vector2(0.25, 0), 50, 0.2, 600, 0
		)
		var hp := w.actors.hp[_i(w, aid)]
		CombatLab.idle(w, 70)
		var at := w.actors.pos(_i(w, aid))
		if with_field:
			assert_almost_eq(at.x, 6.0, 0.001, "sideways only")
			assert_lt(at.y, -(1.4 + 0.2 + 0.3 - 0.2) + 0.05, "out of the line, away from it")
			assert_gt(at.y, -2.2, "and no farther than it needs")
			CombatLab.idle(w, 60)
			assert_eq(w.actors.hp[_i(w, aid)], hp, "the shot misses it")
		else:
			assert_eq(at, Vector2(6, 0), "a shot at full speed is not dodged")
			assert_lt(w.actors.hp[_i(w, aid)], hp, "and it lands")


func _walk_line(w: World, n: int) -> void:
	for k in n:
		w.actors.set_pos(0, _line(w.tick))
		w.step(InputFrame.new())


func _line(tick: int) -> Vector2:
	return Vector2(-10.0 + 0.01 * tick, -8.0)


func test_the_pale_copy_follows_4_s_behind_then_6() -> void:
	var s := JudgeLab.fight(Vector2(-10, -8), Vector2(6, 6))
	var w: World = s[0]
	var aid: int = s[1]
	JudgeLab.hush(w, aid)
	BossAi.table_of(w, _i(w, aid)).speed = 0.0
	_walk_line(w, 500)
	assert_false(bool(WorldReader.new(w).boss_time()["rewind"]), "no Rewind in phase 1")
	JudgeLab.set_phase(w, aid, 1)
	w.bosses.time_field_due = 1 << 29
	_walk_line(w, 100)
	var st := WorldReader.new(w).boss_time()
	assert_true(bool(st["rewind"]), "on from phase 2")
	assert_eq(st["trail"], 240)
	var newest := (w.tick - 1) / 15 * 15  # The last tick a point was kept (the walk sets the place before each step)
	assert_almost_eq(
		st["copy"], _line(newest - 240), Vector2(0.001, 0.001), "where you stood 4 s ago"
	)
	JudgeLab.set_phase(w, aid, 2)
	w.bosses.time_bell_due = 1 << 29
	_walk_line(w, 30)
	st = WorldReader.new(w).boss_time()
	newest = (w.tick - 1) / 15 * 15
	assert_eq(st["trail"], 360)
	assert_almost_eq(st["copy"], _line(newest - 360), Vector2(0.001, 0.001), "6 s in phase 3")


func test_the_bell_throws_you_to_the_copy() -> void:
	var s := JudgeLab.fight(Vector2(-10, -8), Vector2(6, 6))
	var w: World = s[0]
	var aid: int = s[1]
	JudgeLab.hush(w, aid)
	BossAi.table_of(w, _i(w, aid)).speed = 0.0
	_walk_line(w, 300)
	JudgeLab.set_phase(w, aid, 1)
	w.bosses.time_field_due = 1 << 29
	_walk_line(w, 1)
	var due := w.bosses.time_bell_due
	assert_eq(due, w.tick - 1 + 900, "the first cast 15 s into phase 2")
	var bell: SimEvent = null
	for k in 905:
		w.actors.set_pos(0, _line(w.tick))
		w.step(InputFrame.new())
		var found := JudgeLab.effects(w, BossRewind.BELL)
		if not found.is_empty():
			bell = found[0]
			break
	assert_not_null(bell, "the Bell is cast")
	assert_eq([bell.tick, bell.amount], [due, 120], "a 2 s cast")
	assert_eq(WorldReader.new(w).boss_time()["bell_left"], 119)
	w.actors.invuln[0] = 10000  # A dash does not prevent it
	_walk_line(w, 119)
	assert_true(JudgeLab.effects(w, BossRewind.SNAP).is_empty(), "not before the toll")
	var copy: Vector2 = WorldReader.new(w).boss_time()["copy"]
	var hp := w.actors.hp[0]
	w.actors.set_pos(0, _line(w.tick))
	w.step(InputFrame.new())
	var snaps := JudgeLab.effects(w, BossRewind.SNAP)
	assert_eq(snaps.size(), 1, "it tolls")
	assert_eq(snaps[0].tick, due + 120)
	assert_almost_eq(snaps[0].pos, copy, Vector2(0.151, 0.001), "to where the copy stands")
	assert_almost_eq(w.player_pos(), snaps[0].pos, Vector2(0.001, 0.001), "the hero is there")
	assert_almost_eq(
		float(snaps[0].amount), 240.0 * 0.01 * 1000.0, 160.0, "thrown back 4 s of walking"
	)
	assert_eq(w.actors.hp[0], hp, "no damage")
	assert_eq(WorldReader.new(w).boss_time()["bell"], -1, "one toll in phase 2")
	assert_eq(w.bosses.time_bell_due, due + 1200, "the next cast 20 s after this one began")


func test_phase_3_tolls_twice_3_s_apart() -> void:
	var s := JudgeLab.fight(Vector2(-10, -8), Vector2(6, 6))
	var w: World = s[0]
	var aid: int = s[1]
	JudgeLab.hush(w, aid)
	BossAi.table_of(w, _i(w, aid)).speed = 0.0
	JudgeLab.set_phase(w, aid, 2)
	w.step(InputFrame.new())
	w.bosses.time_back = 1  # Not this test's
	w.bosses.time_field_due = 1 << 29
	w.bosses.time_wave_due = 1 << 29
	var due := w.bosses.time_bell_due
	CombatLab.idle(w, 900 + 120 + 180 + 2)
	var bells := JudgeLab.effects(w, BossRewind.BELL)
	var snaps := JudgeLab.effects(w, BossRewind.SNAP)
	assert_eq(bells.map(func(e: SimEvent) -> int: return e.tick), [due, due + 120])
	assert_eq(bells.map(func(e: SimEvent) -> int: return e.amount), [120, 180], "2 s, then 3 s")
	assert_eq(snaps.map(func(e: SimEvent) -> int: return e.tick), [due + 120, due + 300], "twice")
	assert_eq(w.bosses.time_bell_at, -1, "and no third")


func test_the_throw_never_lands_in_a_wall_a_gear_or_the_judge() -> void:
	var seeds := Seeds.count(400)
	var moved := 0
	for sv in seeds:
		var rng := RngStream.derive(sv, "judge_snap_test")
		var s := JudgeLab.fight(Vector2(-9, -9), Vector2(3, 3), sv + 1)
		var w: World = s[0]
		var i := _i(w, s[1])
		for g in 6:
			var c := Vector2(rng.range_int(-900, 900), rng.range_int(-900, 900)) * 0.01
			if c.distance_to(w.player_pos()) > 4.0:
				w.add_barrier(Obb.make(c, Vector2(2.5, 0.4), rng.range_int(0, 4095)))
		var to := Vector2(rng.range_int(-1300, 1300), rng.range_int(-1300, 1300)) * 0.01
		if sv % 4 == 0:
			to = w.actors.pos(i) + Vector2(0.3, 0.2)  # Inside the Judge
		elif sv % 4 == 1:
			to = w.walls[w.walls.size() - 1].center  # Inside a gear
		var at := BossRewind.snap(w, i, to)
		moved += 1 if at.distance_to(Vector2(-9, -9)) > 0.01 else 0
		if not (
			EnemyAi.clear_of_walls(w, at, w.player.radius_m)
			and at.distance_to(w.actors.pos(i)) >= 1.4 + w.player.radius_m
			and w.bosses.arena.has_point(at)
		):
			assert_true(false, "seed %d: thrown to %s, not free" % [sv, at])
		elif BossRewind.is_free(w, i, to) and at != to:
			assert_true(false, "seed %d: a free spot is taken as it is" % sv)
		elif at.distance_to(to) > 6.01 and at.distance_to(Vector2(-9, -9)) > 0.01:
			assert_true(false, "seed %d: farther than the search reaches" % sv)
	gut.p("snaps: %d seeds, %d moved the hero" % [seeds, moved])
	assert_gt(moved, seeds * 9 / 10, "nearly every throw finds a free spot")


## A hushed, still Judge in `phase` with the hero 400 ticks along its line and the Bell's cast due on the next tick.
## Returns [world, the Judge's id, the tick the cast begins].
func _cast(phase: int) -> Array:
	var s := JudgeLab.fight(Vector2(-10, -8), Vector2(6, 6))
	var w: World = s[0]
	JudgeLab.hush(w, s[1])
	BossAi.table_of(w, _i(w, s[1])).speed = 0.0
	JudgeLab.set_phase(w, s[1], phase)
	w.bosses.time_field_due = 1 << 29
	w.bosses.time_back = 1  # Not these tests'
	_walk_line(w, 400)
	w.bosses.time_bell_due = w.tick
	w.actors.hp[0] = 100
	w.actors.max_hp[0] = 100
	return [w, s[1], w.tick]


func _squares(w: World) -> Array:
	return WorldReader.new(w).boss_time()["bell_squares"]


func _drops(w: World) -> Array[SimEvent]:
	return JudgeLab.effects(w, BossRewind.BELL_VERDICT)


func test_the_bells_verdict_follows_the_copy_locks_at_the_toll_and_drops_once() -> void:
	for busy: bool in [false, true]:
		var s := _cast(1)
		var w: World = s[0]
		var cast: int = s[2]
		var reader := WorldReader.new(w)
		assert_eq(_squares(w), [], "no square before the cast")
		_walk_line(w, 1)
		var sq := _squares(w)
		assert_eq(sq.size(), 1, "the cast brings its square")
		var first: Vector2 = sq[0]["center"]
		assert_eq(first, reader.boss_time()["copy"], "on the copy")
		assert_eq([sq[0]["locked"], sq[0]["left"]], [false, 119 + 27])
		assert_almost_eq(float(sq[0]["half"]), 1.5, 0.0001, "the Verdict's size")
		_walk_line(w, 60)
		sq = _squares(w)
		assert_eq(sq[0]["center"], reader.boss_time()["copy"], "it follows the copy")
		assert_gt((sq[0]["center"] as Vector2).distance_to(first), 0.5)
		_walk_line(w, 59)
		assert_eq([w.tick, _squares(w)[0]["left"]], [cast + 120, 27])
		if busy:  # The Judge is casting its Time Wave when the square drops
			BossLab.start(w, _i(w, s[1]), &"time_wave")
		_walk_line(w, 1)
		var snaps := JudgeLab.effects(w, BossRewind.SNAP)
		assert_eq(snaps.map(func(e: SimEvent) -> int: return e.tick), [cast + 120], "the toll")
		sq = _squares(w)
		assert_eq(sq.size(), 1)
		assert_eq(
			sq[0]["center"], snaps[0].pos, "locked where the copy stood: where the hero landed"
		)
		assert_eq([sq[0]["locked"], sq[0]["left"]], [true, 26])
		assert_eq(w.actors.hp[0], 100, "the throw deals no damage")
		CombatLab.idle(w, 26)
		assert_eq([w.actors.hp[0], _drops(w).size()], [100, 0], "0.45 s to leave it")
		assert_eq(_squares(w)[0]["left"], 0)
		w.step(InputFrame.new())
		var drops := _drops(w)
		assert_eq(drops.map(func(e: SimEvent) -> int: return e.tick), [cast + 147])
		assert_eq([drops[0].amount, drops[0].pos], [30, snaps[0].pos])
		assert_eq(w.actors.hp[0], 70, "one Verdict hit: 30 of 100, under the 40 % the brief allows")
		assert_false(w.player_dead(), "never a kill from full HP")
		assert_eq([_squares(w), w.bosses.time_bv_at], [[], -1], "the square is gone")
		if busy:
			assert_eq(w.actors.state[_i(w, s[1])], S.WINDUP, "beside the Judge's own attack")
		CombatLab.idle(w, 200)
		assert_eq([w.actors.hp[0], _drops(w).size()], [70, 1], "and only one")


func test_leaving_the_bells_square_in_time_costs_nothing() -> void:
	var s := _cast(1)
	var w: World = s[0]
	_walk_line(w, 121)
	var c: Vector2 = _squares(w)[0]["center"]
	assert_almost_eq(w.player_pos(), c, Vector2(0.001, 0.001), "thrown onto it")
	CombatLab.idle(w, 20)
	w.actors.set_pos(0, c + Vector2(0.0, 1.5 + w.player.radius_m + 0.05))  # Just past its edge
	CombatLab.idle(w, 10)
	var drops := _drops(w)
	assert_eq(drops.size(), 1, "it drops all the same")
	assert_eq([drops[0].amount, w.actors.hp[0]], [0, 100], "on nobody")


func test_a_bells_verdict_that_kills_names_the_verdict() -> void:
	var s := _cast(1)
	var w: World = s[0]
	_walk_line(w, 121)
	w.actors.hp[0] = 10
	CombatLab.idle(w, 30)
	assert_true(w.player_dead())
	var t := BossAi.table_of(w, _i(w, s[1]))
	assert_eq(w.killer_attack, t.attack_index(&"verdict"), "the death recap's cause is the Verdict")


func test_phase_3_each_toll_brings_its_own_verdict() -> void:
	var s := _cast(2)
	var w: World = s[0]
	var cast: int = s[2]
	_walk_line(w, 121)
	var sq := _squares(w)
	assert_eq(sq.size(), 2, "the first locked, the second already on the copy")
	assert_eq([sq[0]["locked"], sq[0]["left"]], [true, 26])
	assert_eq([sq[1]["locked"], sq[1]["left"]], [false, 179 + 27])
	assert_eq(sq[1]["center"], WorldReader.new(w).boss_time()["copy"])
	CombatLab.idle(w, 180 + 27 + 5)
	var drops := _drops(w)
	assert_eq(drops.map(func(e: SimEvent) -> int: return e.tick), [cast + 147, cast + 327])
	assert_eq(drops.map(func(e: SimEvent) -> int: return e.amount), [30, 30], "one hit each")
	assert_ne(drops[0].pos, drops[1].pos, "each where the copy stood at its toll")
	assert_eq(w.actors.hp[0], 40)
	assert_eq([_squares(w), w.bosses.time_bell_at, w.bosses.time_bv_at], [[], -1, -1])


func test_the_ordinary_verdict_follows_the_hero_in_every_phase() -> void:
	for phase in 3:
		var s := JudgeLab.fight(Vector2(-10, -8), Vector2(6, 6))
		var w: World = s[0]
		var aid: int = s[1]
		JudgeLab.hush(w, aid)
		BossAi.table_of(w, _i(w, aid)).speed = 0.0
		JudgeLab.set_phase(w, aid, phase)
		w.bosses.time_field_due = 1 << 29
		w.bosses.time_back = 1
		_walk_line(w, 400)
		w.bosses.time_bell_due = 1 << 29
		var reader := WorldReader.new(w)
		BossLab.start(w, _i(w, aid), &"verdict")
		_walk_line(w, 20)
		var v: Dictionary = reader.boss_echo(_i(w, aid))["verdict"]
		assert_false(bool(v["locked"]))
		assert_almost_eq(
			v["center"], w.player_pos(), Vector2(0.02, 0.001), "phase %d: on you" % (phase + 1)
		)
		if phase > 0:
			var copy: Vector2 = reader.boss_time()["copy"]
			assert_gt((v["center"] as Vector2).distance_to(copy), 2.0, "not on the copy")
		w.actors.hp[0] = 100
		w.actors.max_hp[0] = 100
		CombatLab.idle(w, 95 - 20 + 2)  # The hero stops; the windup ends
		assert_eq(
			w.actors.hp[0], 70, "phase %d: standing still under it costs its hit" % (phase + 1)
		)
		assert_eq(_drops(w).size(), 0, "and no Bell's Verdict fell")


func _return_fight(hero_at: Vector2) -> Array:
	var s := JudgeLab.fight(hero_at, Vector2(-6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	JudgeLab.hush(w, aid)
	var t := BossAi.table_of(w, _i(w, aid))
	t.speed = 0.0
	JudgeLab.set_phase(w, aid, 2)
	w.step(InputFrame.new())
	for f: StringName in [&"time_field_due", &"time_bell_due", &"time_wave_due"]:
		w.bosses.set(f, 1 << 29)
	CombatLab.idle(w, 100)
	w.actors.set_pos(_i(w, aid), Vector2(6, 0))  # It stood at (-6, 0) five seconds before the tick below
	CombatLab.idle(w, 200)
	return s


func test_the_judge_returns_once_and_recovers_unless_you_are_close() -> void:
	for near in [false, true]:
		var s := _return_fight(Vector2(9, 0) if near else Vector2(0, 9))
		var w: World = s[0]
		var aid: int = s[1]
		var i := _i(w, aid)
		var max_hp := w.actors.max_hp[i]
		var bar := 330 * max_hp / 1000
		w.actors.hp[i] = bar * 150 / 1000 + 1
		CombatLab.idle(w, 2)
		assert_true(JudgeLab.effects(w, BossRewind.RETURN).is_empty(), "not above 15 % of the bar")
		assert_eq(w.actors.pos(i), Vector2(6, 0))
		w.actors.hp[i] = bar * 150 / 1000
		var hp := w.actors.hp[i]
		w.step(InputFrame.new())
		var back := JudgeLab.effects(w, BossRewind.RETURN)
		assert_eq(back.size(), 1, "at 15 % of the last bar")
		assert_eq(w.actors.pos(i), Vector2(-6, 0), "back where it stood 5 s ago")
		var heal := 0 if near else 330 * 50 * max_hp / 1000000
		assert_eq(w.actors.hp[i], hp + heal, "5 % of the bar back, none with the hero within 4 m")
		assert_eq(back[0].amount, heal)
		assert_true(bool(WorldReader.new(w).boss_time()["returned"]))
		w.actors.hp[i] = 5
		CombatLab.idle(w, 30)
		assert_eq(JudgeLab.effects(w, BossRewind.RETURN).size(), 1, "once")
		assert_eq(w.actors.hp[i], 5)


func test_everything_goes_when_the_judge_dies() -> void:
	var s := _after_wave(1)
	var w: World = s[0]
	var aid: int = s[1]
	BossShotFields.place(w, aid, _time(w, aid).field, Vector2(0, 0))
	w.bosses.time_bell_at = w.tick + 50
	w.bosses.time_bv_at = w.tick + 50
	assert_gt(w.bosses.gear_x.size(), 0)
	assert_eq(BossSlow.cut(w), 750)
	var i := _i(w, aid)
	var me := w.actors.ids[0]
	for k in 1200:  # Through its gates: a hit never takes it past one
		i = _i(w, aid)
		if i < 0:
			break
		Damage.hit(w, i, 1 << 24, me, me, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
		w.step(InputFrame.new())
	assert_lt(_i(w, aid), 0, "it is gone")
	var bs := w.bosses
	assert_eq(bs.gear_x.size(), 0, "the gears")
	assert_eq(w.walls.size(), 4, "their walls")
	assert_eq(
		[bs.time_boss, bs.time_bell_at, bs.time_px.size()], [-1, -1, 0], "the clocks and the trail"
	)
	assert_eq(bs.time_bv_at, -1, "the Bell's Verdict")
	assert_eq(BossSlow.cut(w), 0, "the cut")
	assert_eq(_orbs(w).size(), 0, "the orbs")
	assert_eq(WorldReader.new(w).boss_shot_fields().size(), 0, "the fields")
	assert_false(w.objectives.has(ObjectiveMarkers.JUDGE_ORB), "the markers")
	assert_eq(WorldReader.new(w).boss_time(), {})
	var here := w.player_pos()
	CombatLab.idle(w, 60)
	assert_eq(w.player_pos(), here, "and no toll throws the hero afterwards")
	assert_eq(_drops(w).size(), 0, "and no Verdict drops")


func test_leaving_the_room_or_dying_drops_the_gears_and_the_toll() -> void:
	for dead in [false, true]:
		var s := _after_wave(1)
		var w: World = s[0]
		w.bosses.time_bell_at = w.tick + 50
		w.bosses.time_bell_from = w.tick
		w.bosses.time_bv_at = w.tick + 50
		assert_gt(w.bosses.gear_x.size(), 0)
		if dead:
			w.actors.hp[0] = 0
			w.actors.dead[0] = 1
		else:
			w.actors.set_pos(0, Vector2(0, 20))
		w.step(InputFrame.new())
		assert_eq(w.bosses.gear_x.size(), 0, "no gear stays")
		assert_eq(w.walls.size(), 4)
		assert_eq(w.bosses.time_bell_at, -1, "no toll pending")
		assert_eq(w.bosses.time_bv_at, -1, "no Bell's Verdict hanging")
		assert_eq(_orbs(w).size(), 0)
		assert_false(w.objectives.has(ObjectiveMarkers.JUDGE_ORB))
		CombatLab.idle(w, 80)
		assert_true(JudgeLab.effects(w, BossRewind.SNAP).is_empty(), "and none throws")
		assert_eq(_drops(w).size(), 0, "and none drops")


func _mid_fight(seed_value: int) -> World:
	var s := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0), seed_value)
	var w: World = s[0]
	JudgeLab.set_phase(w, s[1], 1)
	for k in 60 * 34:
		var f := InputFrame.make(Vector2i(90, 50), 0, 300, InputFrame.SHOOT, 0)
		w.step(f if k % 120 < 60 else InputFrame.make(Vector2i(-90, -50), 0, 300, 0, 0))
		w.actors.hp[0] = JudgeLab.LONG
		w.actors.hp[w.actors.index_of(s[1])] = 1200
	return w


func test_deterministic_and_a_save_mid_fight_restores() -> void:
	var a := _mid_fight(7)
	var b := _mid_fight(7)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	assert_ne(a.state_hash(), _mid_fight(8).state_hash(), "another seed, another fight")
	var bs := a.bosses
	assert_gt(bs.time_px.size(), 0, "the trail is in the state")
	assert_gt(JudgeLab.effects(a, BossTime.WAVE).size(), 0, "a wave landed")
	assert_gt(JudgeLab.effects(a, BossRewind.SNAP).size(), 0, "a toll threw the hero")
	var before := a.state_hash()
	bs.time_px[0] += 0.5
	assert_ne(a.state_hash(), before, "the trail is hashed")
	bs.time_px[0] -= 0.5
	bs.time_bell_due += 1
	assert_ne(a.state_hash(), before, "the clocks too")
	bs.time_bell_due -= 1
	bs.time_bv_x += 0.5
	assert_ne(a.state_hash(), before, "and the Bell's Verdict square")
	bs.time_bv_x -= 0.5
	assert_gt(_drops(a).size(), 0, "a Bell's Verdict dropped")
	# A save with gears standing, a toll pending and a Bell's Verdict locked
	var c := _mid_fight(7)
	var i := c.actors.index_of(c.bosses.time_boss)
	var t := BossAi.table_of(c, i)
	BossTime.resolve_wave(c, i, BossAi.entry_of(c, i), t.attacks[t.attack_index(&"time_wave")])
	c.bosses.time_bell_at = c.tick + 40
	c.bosses.time_bell_from = c.tick
	c.bosses.time_bv_at = c.tick + 20
	c.bosses.time_bv_x = c.player_pos().x
	c.bosses.time_bv_y = c.player_pos().y
	assert_gt(c.bosses.gear_x.size(), 0, "gears stand in the save")
	var snap := WorldSnapshot.take(c)
	var base := JudgeLab.world(7)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), c.state_hash(), "same hash restored")
	assert_eq(
		[restored.bosses.time_bv_at, restored.bosses.time_bv_x],
		[c.bosses.time_bv_at, c.bosses.time_bv_x],
		"the Bell's Verdict is in the save"
	)
	assert_eq(restored.walls.size(), c.walls.size(), "the gears are walls again")
	for k in 600:
		var f := InputFrame.make(Vector2i(60, -40), 0, 300, InputFrame.SHOOT, 0)
		c.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), c.state_hash(), "same hash 600 ticks on")
	assert_gt(JudgeLab.effects(c, BossRewind.SNAP).size(), 0)


func test_a_world_without_a_judge_keeps_no_time_state() -> void:
	var w := BossLab.world()
	BossLab.ready_boss(w, &"tidecaller")
	CombatLab.idle(w, 40)
	assert_eq(w.bosses.time_boss, -1)
	assert_true(w.bosses.time_px.is_empty())
	assert_eq(WorldReader.new(w).boss_time(), {})
