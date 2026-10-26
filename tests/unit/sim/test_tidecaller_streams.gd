# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 BH4 (owner, 2026-10-25: "tidescaller tides shouuld be stronger and keep the ball patter all times, we should
## add spawning waves crossing the room, small like 2-4 meters that the player has to dodge during all fight";
## docs/roadmap/v0.9.5/BOSSES_HARD.md T2, T3; BossStream): the Tidecaller's ring stream (a ring of bubbles every 2.2 s,
## 1.9 s in phase 2, 1.6 s in phase 3, none while it rises or kneels) and its crossing waves (every 3.5 s, 2 / 3 / 4 m
## long, a 0.7 s foam line then 4.5 m/s across the room, 15 damage once and a 1.5 m shove, never within 3 m of
## the hero's projection on the wall, two at once from phase 2), and their saves, determinism and death line.

const LONG := 1 << 20
const PERIODS := [132, 114, 96]  # 2.2 s, 1.9 s, 1.6 s in ticks


func _fight(player_at := Vector2(-9, 0), seed_value := 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"tidecaller", Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	_hush(w, w.actors.ids[i])
	return [w, w.actors.ids[i]]


## The boss picks nothing on its own: only its streams run.
func _hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, w.actors.index_of(aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0


func _table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


func _phase(w: World, aid: int, ph: int) -> void:
	w.bosses.phase[BossAi.entry_of(w, w.actors.index_of(aid))] = ph


## The ticks (world ticks) each ring left on over `ticks` steps.
func _ring_ticks(w: World, ticks: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var last := 0
	for k in ticks:
		w.step(InputFrame.new())
		var n := 0 if w.bosses.str_ring_n.is_empty() else w.bosses.str_ring_n[0]
		if n > last:
			out.append(w.tick)
		last = n
	return out


func test_the_data_is_the_approved_rows() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"tidecaller")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_true(t.streams)
	assert_eq(t.phase_ring_ticks, PackedInt32Array(PERIODS), "rings every 2.2 / 1.9 / 1.6 s")
	assert_eq(t.phase_wave_ticks, PackedInt32Array([210, 210, 210]), "a wave every 3.5 s")
	assert_eq(t.phase_wave_n, PackedInt32Array([1, 2, 2]), "two at once from phase 2")
	var ring1 := t.attacks[t.phase_ring_atk[0]].pattern
	assert_eq(ring1.kind, BulletPatternTable.Kind.RING)
	assert_eq(
		[ring1.count, ring1.gap_count, ring1.gap_width], [16, 2, 3], "16 bubbles, 2 gaps of 3"
	)
	assert_almost_eq(ring1.speed * 60.0, 3.0, 0.0001, "3.0 m/s")
	assert_eq(
		ring1.turn_per_wave, ContentCompiler.degrees_to_units(20.0), "turned 20 degrees a ring"
	)
	assert_false(ring1.alternate)
	assert_eq(t.phase_ring_atk[0], t.phase_ring_atk[1], "phase 2 keeps the ring")
	var ring3 := t.attacks[t.phase_ring_atk[2]].pattern
	assert_true(ring3.alternate, "phase 3's gaps alternate sides")
	assert_eq(ring3.turn_per_wave, 1024, "a quarter turn between the two sets of gaps")
	var wave := t.attacks[t.phase_wave_atk[0]]
	assert_eq(wave.move, BossAttackTable.Move.WAVE)
	assert_eq(wave.wave_lengths, PackedFloat32Array([2.0, 3.0, 4.0]), "2, 3 or 4 m long")
	assert_eq(wave.windup_ticks, 42, "a 0.7 s foam line")
	assert_almost_eq(wave.wave_speed * 60.0, 4.5, 0.0001, "4.5 m/s")
	assert_almost_eq(wave.wave_thick_m, 0.5, 0.0001)
	assert_eq(wave.damage, 15)
	assert_almost_eq(wave.wave_shove_m, 1.5, 0.0001)
	assert_almost_eq(wave.wave_clear_m, 3.0, 0.0001)
	for ph in 3:
		assert_eq(t.phase_wave_atk[ph], t.attack_index(&"crossing_wave"), "a wave in every phase")
		assert_false(
			t.phase_attacks[ph].has(t.attack_index(&"ring_stream")), "the stream isn't in the pick"
		)
	for id: StringName in [&"tide_rings", &"tide_rings_fast"]:
		assert_eq(t.attack_index(id), -1, "no ring attack in the rotation: %s" % id)


func test_bad_stream_and_wave_numbers_are_errors() -> void:
	var repo := ContentRepository.load_all()
	var base: BossDefinition = repo.get_def(&"bosses", &"tidecaller")
	var codes := func(d: BossDefinition) -> Array:
		return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	var def := base.duplicate(true) as BossDefinition
	def.attack(&"crossing_wave").shape_params["lengths_m"] = [2.0, 9.0]
	assert_has(codes.call(def), &"range", "a wave over 6 m")
	def = base.duplicate(true) as BossDefinition
	def.attack(&"crossing_wave").telegraph_seconds = 0.5
	assert_has(codes.call(def), &"telegraph_short", "a wave telegraph under 0.55 s")
	def = base.duplicate(true) as BossDefinition
	def.phases[1].wave_count = 3
	assert_has(codes.call(def), &"range", "three waves at once")
	def = base.duplicate(true) as BossDefinition
	def.phases[0].stream_attack = &"undertow"
	assert_has(codes.call(def), &"attacks", "a ring stream fires a pattern")
	def = base.duplicate(true) as BossDefinition
	def.phases[2].stream_every_seconds = 0.2
	assert_has(codes.call(def), &"range", "a ring every 1..6 s")
	def = base.duplicate(true) as BossDefinition
	def.attack(&"the_pull").shape_params["max_mps"] = 2.6
	assert_has(codes.call(def), &"range", "a drift cap over 2.2 m/s")


func test_a_ring_is_16_bubbles_less_two_gaps_of_three() -> void:
	var s := _fight()
	var w: World = s[0]
	var t := _table(w, s[1])
	var rk := t.phase_ring_atk[0]
	var i := w.actors.index_of(s[1])
	assert_eq(BossStream.ring(w, i, t.attacks[rk], rk, 0), 10, "16 - 2 x 3 bubbles")
	assert_eq(w.pending_projectiles(), 10)


func test_rings_leave_every_2_2_1_9_and_1_6_seconds_per_phase() -> void:
	for ph in 3:
		var s := _fight()
		var w: World = s[0]
		_phase(w, s[1], ph)
		var ticks := _ring_ticks(w, PERIODS[ph] * 6 + 5)
		assert_gte(ticks.size(), 6, "phase %d: rings" % (ph + 1))
		for k in range(1, ticks.size()):
			assert_eq(
				ticks[k] - ticks[k - 1], PERIODS[ph], "phase %d: a ring every period" % (ph + 1)
			)


func test_each_ring_turns_20_degrees_and_phase_3_alternates() -> void:
	var s := _fight()
	var w: World = s[0]
	var t := _table(w, s[1])
	var pat := t.attacks[t.phase_ring_atk[0]].pattern
	var a := BulletPatterns.base_angle(pat, 0, 0)
	var b := BulletPatterns.base_angle(pat, 1, 0)
	assert_eq(
		b - a, ContentCompiler.degrees_to_units(20.0), "ring 1 is turned 20 degrees on ring 0"
	)
	var pat3 := t.attacks[t.phase_ring_atk[2]].pattern
	assert_eq(
		[
			BulletPatterns.base_angle(pat3, 0, 0),
			BulletPatterns.base_angle(pat3, 1, 0),
			BulletPatterns.base_angle(pat3, 2, 0)
		],
		[0, 1024, 0],
		"phase 3: the gaps alternate between two sets"
	)


func test_no_ring_while_it_rises_or_kneels() -> void:
	var s := _fight()
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	for k in 300:  # still rising: no clocks run
		w.actors.state[i] = EnemyAi.State.SPAWN
		w.actors.state_t[i] = 0
		w.step(InputFrame.new())
	assert_true(w.bosses.str_boss.is_empty(), "no stream until it has risen")
	var risen := w.tick
	w.actors.state[i] = EnemyAi.State.MOVE
	var first := _ring_ticks(w, 200)
	assert_eq(first.size(), 1, "the first ring a full period after the rise")
	assert_between(first[0] - risen, PERIODS[0], PERIODS[0] + 2, "2.2 s on")
	# A phase change: the boss kneels (the gate); the stream rests, and the next ring is a full period after it ends.
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	var in_gate := 0
	var rung := 0
	var gate_end := -1
	var last := w.bosses.str_ring_n[0]
	for k in 600:
		w.step(InputFrame.new())
		var n: int = w.bosses.str_ring_n[0]
		var st := w.actors.state[w.actors.index_of(aid)]
		if st == BossAi.GATE:
			in_gate += 1
			assert_eq(n, last, "no ring while it kneels")
		elif in_gate > 0 and gate_end < 0:
			gate_end = w.tick
		if n > last and gate_end >= 0:
			rung = w.tick
			break
		last = n
	assert_gt(in_gate, 50, "it knelt about a second")
	assert_gt(rung - gate_end, PERIODS[1] - 10, "the next ring a period after the kneel")


func test_a_wave_forms_every_3_5_seconds_with_a_drawn_length() -> void:
	var s := _fight()
	var w: World = s[0]
	_table(w, s[1]).phase_ring_atk[0] = -1  # no rings in the way
	var seen := {}
	var formed := PackedInt32Array()
	var lengths := {}
	for k in 210 * 12 + 5:
		w.step(InputFrame.new())
		for j in w.bosses.wv_from.size():
			var f := w.bosses.wv_from[j]
			if not seen.has(f):
				seen[f] = true
				formed.append(f)
				lengths[snappedf(w.bosses.wv_len[j], 0.01)] = true
	assert_gte(formed.size(), 12, "a wave every 3.5 s")
	for k in range(1, formed.size()):
		assert_eq(formed[k] - formed[k - 1], 210, "3.5 s apart")
	for ln: float in lengths:
		assert_has([2.0, 3.0, 4.0], ln, "2, 3 or 4 m")
	assert_gte(lengths.size(), 2, "the length is drawn")


func test_a_wave_is_a_foam_line_for_0_7_s_then_crosses_at_4_5_mps() -> void:
	var s := _fight()
	var w: World = s[0]
	var t := _table(w, s[1])
	t.streams = false
	var i := w.actors.index_of(s[1])
	var b := BossAi.entry_of(w, i)
	assert_eq(BossStream.form(w, i, b, t.phase_wave_atk[0], 1), 1)
	var formed := w.tick
	var mid0: Vector2 = Vector2(w.bosses.wv_x[0], w.bosses.wv_y[0])
	for k in 41:
		w.step(InputFrame.new())
	assert_eq(BossStream.travelled(w, 0), -1.0, "still only a foam line after 41 ticks")
	assert_eq(int(BossStream.state(w)[0]["telegraph"]), 41 * 1000 / 42, "its telegraph fills")
	w.step(InputFrame.new())  # tick 42: it moves
	assert_eq(BossStream.travelled(w, 0), 0.0, "it starts to move on the 42nd tick")
	var d0 := BossStream.travelled(w, 0)
	CombatLab.idle(w, 60)
	assert_almost_eq(BossStream.travelled(w, 0) - d0, 4.5, 0.0001, "4.5 m in the next second")
	var at := BossStream.state(w)[0]
	assert_almost_eq((at["pos"] as Vector2).distance_to(mid0), 0.25 + 4.5, 0.0001)
	var run: float = w.bosses.wv_run[0]
	assert_almost_eq(
		run, 14.0 - 0.5, 0.0001, "it crosses the room (14 m here) to the opposite wall"
	)
	CombatLab.idle(w, int(run / 0.075) + 5)
	assert_eq(w.bosses.wv_boss.size(), 0, "gone at the far wall")
	assert_gt(w.tick - formed, 42 + int(run / 0.075), "after its run")


func test_a_wave_hits_once_for_15_and_shoves_1_5_m_along_its_travel() -> void:
	var s := _fight(Vector2(-9, -9))
	var w: World = s[0]
	var t := _table(w, s[1])
	t.streams = false
	var i := w.actors.index_of(s[1])
	var b := BossAi.entry_of(w, i)
	BossStream.form(w, i, b, t.phase_wave_atk[0], 1)
	var dir := Kin.dir(w.bosses.wv_dir[0])
	CombatLab.until(w, func(x: World) -> bool: return BossStream.travelled(x, 0) >= 0.0, 100)
	var d := BossStream.travelled(w, 0)
	var box := BossStream.box_of(w, 0, d)
	w.actors.set_pos(0, box.center)
	var hp0: int = w.actors.hp[0]
	var before := w.player_pos()
	w.step(InputFrame.new())
	assert_eq(hp0 - w.actors.hp[0], 15, "15 damage")
	assert_almost_eq(
		(w.player_pos() - before).dot(dir), 1.5, 0.001, "shoved 1.5 m along its travel"
	)
	assert_almost_eq((w.player_pos() - before).cross(dir), 0.0, 0.001, "and no sideways")
	var hp1: int = w.actors.hp[0]
	w.actors.set_pos(0, BossStream.box_of(w, 0, BossStream.travelled(w, 0)).center)
	CombatLab.idle(w, 3)
	assert_eq(w.actors.hp[0], hp1, "once per wave: the same wave doesn't hit again")
	assert_eq(w.bosses.wv_hit[0], 1)


func test_a_dash_goes_through_a_wave() -> void:
	var s := _fight(Vector2(-9, -9))
	var w: World = s[0]
	var t := _table(w, s[1])
	t.streams = false
	var i := w.actors.index_of(s[1])
	BossStream.form(w, i, BossAi.entry_of(w, i), t.phase_wave_atk[0], 1)
	CombatLab.until(w, func(x: World) -> bool: return BossStream.travelled(x, 0) >= 0.0, 100)
	w.actors.set_pos(0, BossStream.box_of(w, 0, BossStream.travelled(w, 0)).center)
	var hp0: int = w.actors.hp[0]
	w.dash_ticks_left = 6
	w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], hp0, "a dash isn't hit")
	assert_eq(w.bosses.wv_hit[0], 0)


func test_a_wave_never_forms_within_3_m_of_the_hero_on_its_wall() -> void:
	var w := BossLab.world(21)
	var i := BossLab.ready_boss(w, &"tidecaller", Vector2.ZERO)
	var t := BossAi.table_of(w, i)
	var b := BossAi.entry_of(w, i)
	var wk := t.phase_wave_atk[0]
	var made := 0
	for k in 400:
		var p := Vector2(float(k % 14) - 6.5, float((k * 7) % 14) - 6.5)  # all over the 14 m room
		w.actors.set_pos(0, p)
		var n := w.bosses.wv_boss.size()
		made += BossStream.form(w, i, b, wk, 2)
		for j in range(n, w.bosses.wv_boss.size()):
			var wall: int = BossStream.WALL_DIR.find(w.bosses.wv_dir[j])
			var along_x := wall == BossStream.NORTH or wall == BossStream.SOUTH
			var c := w.bosses.wv_x[j] if along_x else w.bosses.wv_y[j]
			var proj := p.x if along_x else p.y
			var half: float = w.bosses.wv_len[j] * 0.5
			var gap := absf(c - proj) - half
			assert_gte(
				gap, 3.0 - 0.001, "wave %d: %.2f m of clear wall from the hero's line" % [k, gap]
			)
			assert_gte(c - half, -7.0 - 0.001, "inside the wall")
			assert_lte(c + half, 7.0 + 0.001)
	assert_gt(made, 700, "nearly every try finds a place")


func test_from_phase_2_two_waves_form_at_once_from_different_walls() -> void:
	var s := _fight()
	var w: World = s[0]
	var t := _table(w, s[1])
	var i := w.actors.index_of(s[1])
	var b := BossAi.entry_of(w, i)
	var opposite := 0
	var adjacent := 0
	for k in 80:
		var n := w.bosses.wv_boss.size()
		assert_eq(BossStream.form(w, i, b, t.phase_wave_atk[1], t.phase_wave_n[1]), 2)
		var a := BossStream.WALL_DIR.find(w.bosses.wv_dir[n])
		var c := BossStream.WALL_DIR.find(w.bosses.wv_dir[n + 1])
		assert_ne(a, c, "different walls")
		if (a + 2) % 4 == c:
			opposite += 1
		else:
			adjacent += 1
	assert_gt(opposite, 0, "sometimes opposite walls")
	assert_gt(adjacent, 0, "sometimes adjacent ones")
	var s2 := _fight()
	var w2: World = s2[0]
	_phase(w2, s2[1], 1)
	_table(w2, s2[1]).phase_ring_atk[1] = -1
	CombatLab.idle(w2, 215)
	assert_eq(w2.bosses.wv_boss.size(), 2, "live: phase 2 forms two at the 3.5 s mark")


func test_waves_ignore_bodies_props_and_shots() -> void:
	var s := _fight(Vector2(-9, -9))
	var w: World = s[0]
	var t := _table(w, s[1])
	t.streams = false
	var i := w.actors.index_of(s[1])
	BossStream.form(w, i, BossAi.entry_of(w, i), t.phase_wave_atk[0], 1)
	var hp_boss: int = w.actors.hp[i]
	CombatLab.idle(w, 400)
	assert_eq(w.actors.hp[i], hp_boss, "the boss isn't hurt by its own wave")
	assert_eq(w.bosses.wv_boss.size(), 0, "it crossed whatever stood in its way")


func test_streams_are_deterministic_by_seed() -> void:
	var run := func(seed_value: int) -> Array:
		var s := _fight(Vector2(-6, 2), seed_value)
		var w: World = s[0]
		_phase(w, s[1], 1)
		var out: Array = []
		for k in 900:
			w.step(InputFrame.new())
			for j in w.bosses.wv_boss.size():
				if w.bosses.wv_from[j] == w.tick - 1:
					out.append(
						[w.bosses.wv_dir[j], w.bosses.wv_x[j], w.bosses.wv_y[j], w.bosses.wv_len[j]]
					)
		return [out, w.state_hash()]
	var a: Array = run.call(5)
	var b: Array = run.call(5)
	var c: Array = run.call(6)
	assert_gt((a[0] as Array).size(), 6, "waves formed")
	assert_eq(a, b, "the same seed: the same waves, the same state")
	assert_ne(a[0], c[0], "another seed: other walls and places")


func test_the_streams_are_in_the_state_and_a_save_restores() -> void:
	var make := func() -> World:
		var s := _fight(Vector2(-6, 2))
		var w: World = s[0]
		_phase(w, s[1], 2)
		CombatLab.idle(w, 380)  # rings fired, waves in flight
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_false(a.bosses.str_boss.is_empty(), "the stream's clocks are in the state")
	assert_false(a.bosses.wv_boss.is_empty(), "and the waves")
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	var before := a.state_hash()
	a.bosses.wv_hit[0] = 1 - a.bosses.wv_hit[0]
	assert_ne(a.state_hash(), before, "a wave is in the hash")
	a.bosses.wv_hit[0] = 1 - a.bosses.wv_hit[0]
	a.bosses.str_ring_due[0] += 1
	assert_ne(a.state_hash(), before, "and the ring clock")
	a.bosses.str_ring_due[0] -= 1
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), make.call())
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	for k in 300:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		a.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 300 ticks on")


func test_an_older_snapshot_without_the_streams_loads() -> void:
	var s := _fight()
	var w: World = s[0]
	CombatLab.idle(w, 300)
	var snap := WorldSnapshot.take(w)
	var bosses: Dictionary = snap["world"][&"bosses"]
	assert_true(bosses.has(&"str_boss"), "the streams are saved")
	for f: StringName in BossStore.new().get_property_list().map(
		func(p: Dictionary) -> StringName: return p["name"]
	):
		if f.begins_with("str_") or f.begins_with("wv_"):
			bosses.erase(f)
	var base := BossLab.world()
	BossLab.ready_boss(base, &"tidecaller")
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save from before BH4 loads")
	assert_true(base.bosses.str_boss.is_empty(), "with no stream yet (it starts at its next think)")


func test_the_boss_gone_takes_its_waves_with_it() -> void:
	var s := _fight()
	var w: World = s[0]
	var t := _table(w, s[1])
	var i := w.actors.index_of(s[1])
	BossStream.form(w, i, BossAi.entry_of(w, i), t.phase_wave_atk[0], 1)
	CombatLab.idle(w, 100)
	assert_false(w.bosses.wv_boss.is_empty())
	BossStream.on_boss_gone(w, s[1])
	assert_true(w.bosses.wv_boss.is_empty())
	assert_true(w.bosses.str_boss.is_empty())


func test_the_wave_death_line_is_readable() -> void:
	var s := _fight()
	var w: World = s[0]
	var t := _table(w, s[1])
	w.killer_kind = ActorStore.Kind.TIDECALLER
	w.killer_attack = t.attack_index(&"crossing_wave")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TIDECALLER_WAVE")
	assert_eq(
		String(
			TranslationServer.get_translation_object("en").get_message(&"CAUSE_TIDECALLER_WAVE")
		),
		"The Tidecaller's wave swept you off your feet."
	)
	assert_ne(
		String(
			TranslationServer.get_translation_object("es").get_message(&"CAUSE_TIDECALLER_WAVE")
		),
		"",
		"in Spanish too"
	)


func test_a_player_killed_by_a_wave_names_it() -> void:
	var s := _fight(Vector2(-9, -9))
	var w: World = s[0]
	w.actors.hp[0] = 10
	var t := _table(w, s[1])
	t.streams = false
	var i := w.actors.index_of(s[1])
	BossStream.form(w, i, BossAi.entry_of(w, i), t.phase_wave_atk[0], 1)
	CombatLab.until(w, func(x: World) -> bool: return BossStream.travelled(x, 0) >= 0.0, 100)
	w.actors.set_pos(0, BossStream.box_of(w, 0, BossStream.travelled(w, 0)).center)
	w.step(InputFrame.new())
	assert_true(w.player_dead(), "15 damage kills a hero on 10 HP")
	assert_eq(w.killer_attack, t.attack_index(&"crossing_wave"), "the wave is the killer")
