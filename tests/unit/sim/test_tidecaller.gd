# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 NB1 (owner Q24 "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N1): The Tidecaller, floor 4's boss.
## The Pull (shielded): after the bell's windup the room pulls the player toward it for 3 s at 75 % of the hero's
## own run speed, then throws them 4 m out in 0.5 s, on its rhythm (one big mechanic at a time: its dance,
## tests/unit/sim/test_tide_dance.gd and test_tide_beats.gd; a boss without a dance keeps its attack's own speeds under
## its data's 2.2 m/s cap); never pressing the player into a wall or a corner; its ring stream stops for the Pull and
## the rings already flying bend toward it in the pull. The Undertow: a tracked circle that drags the player 1 m
## toward its centre when it strikes. Phases at 66 % and 33 %, determinism, a mid-pull save, and the death lines.

const S := EnemyAi.State
const LONG := 1 << 20
const TICK := 1.0 / 60.0


func _fight(player_at: Vector2, boss_at := Vector2.ZERO, room := 0.0) -> Array:
	var w := BossLab.world()
	if room > 0.0:
		var t := 0.5
		var walls: Array[Obb] = [
			Obb.make(Vector2(room + t, 0), Vector2(t, room + 2.0 * t), 0),
			Obb.make(Vector2(-room - t, 0), Vector2(t, room + 2.0 * t), 0),
			Obb.make(Vector2(0, room + t), Vector2(room + 2.0 * t, t), 0),
			Obb.make(Vector2(0, -room - t), Vector2(room + 2.0 * t, t), 0),
		]
		w.set_walls(walls)
		w.bosses.arena = Rect2(-room, -room, room * 2.0, room * 2.0)
	var i := BossLab.ready_boss(w, &"tidecaller", boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## The boss picks nothing on its own (no phase list, no cadence, no punish): only what a test starts.
func _hush(w: World, aid: int, keep_streams := false) -> void:
	var t := BossAi.table_of(w, _i(w, aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	t.streams = t.streams and keep_streams  # v0.9.5 BH4: no rings or waves unless a test wants them


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _until_active(w: World, aid: int, limit: int = 200) -> void:
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == S.ACTIVE, limit)


func _start_pull(w: World, aid: int, attack := &"the_pull", streams := false) -> void:
	_hush(w, aid, streams)
	BossLab.start(w, _i(w, aid), attack)
	_until_active(w, aid)


func test_the_data_is_the_approved_row() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"tidecaller")
	assert_not_null(def)
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_eq(t.kind, ActorStore.Kind.TIDECALLER)
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]), "phases at 66 % and 33 %")
	assert_eq(t.sig_every_ticks, 0, "no fixed cadence: its rhythm brings the Pull")
	assert_eq(t.dance.gap_ticks(0), 720, "12 s of ordinary fighting after a Pull and its calm")
	var pull := t.attacks[t.attack_index(&"the_pull")]
	assert_eq(pull.move, BossAttackTable.Move.TIDE)
	assert_true(pull.shielded, "shielded during the signature")
	assert_almost_eq(pull.tide_pull * 60.0, 1.7, 0.0001, "pull 1.7 m/s")
	assert_almost_eq(pull.tide_push * 60.0, 1.4, 0.0001, "push 1.4 m/s")
	assert_eq([pull.tide_pull_ticks, pull.tide_push_ticks], [180, 30], "3 s, then a 0.5 s throw")
	assert_eq(pull.active_ticks, 210)
	assert_null(pull.pattern, "the Pull has no rings of its own (they run all fight)")
	assert_almost_eq(BossTide.cap_of(pull) * 60.0, 2.2, 0.0001, "the drift cap is data: 2.2 m/s")
	var late := t.attacks[t.attack_index(&"the_pull_3")]
	assert_almost_eq(late.tide_pull * 60.0, 2.0, 0.0001, "phase 3 pull 2.0")
	assert_almost_eq(late.tide_push * 60.0, 1.7, 0.0001, "phase 3 push 1.7")
	assert_null(late.pattern)
	assert_eq(BossTide.signature_of(t, 2), t.attack_index(&"the_pull_3"), "phase 3's signature")
	assert_eq(t.phase_entry[1], -1, "phase 2 opens with its Riptide (the rhythm), not a Pull")
	assert_eq(t.phase_entry[2], -1, "the last phase is the Maelstrom: it opens with no Pull")
	var under := t.attacks[t.attack_index(&"undertow")]
	assert_almost_eq(under.drag_m, 1.0, 0.0001, "the Undertow drags 1 m")
	assert_gt(under.lock_ticks, 0, "tracked, then locked")
	var pool := ContentCompiler.compile_boss_pool(repo, 4)
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	assert_eq(pool.size(), 2, "floor 4's pool (v0.9.0 NB2: with the Twin Wardens)")
	assert_eq(ids[pool[0]], &"tidecaller")


func test_bad_tide_numbers_are_errors() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = (repo.get_def(&"bosses", &"tidecaller") as BossDefinition).duplicate(
		true
	)
	var pull := def.attack(&"the_pull")
	pull.shape_params["pull_mps"] = 2.3
	pull.shielded = false
	var codes := def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"range", "over the 2.2 m/s cap")
	assert_has(codes, &"missing", "a tide is shielded")
	def = (repo.get_def(&"bosses", &"tidecaller") as BossDefinition).duplicate(true)
	def.signature_every_seconds = 4.0
	codes = def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"duration", "the cadence outlasts its tide")


func test_the_pull_draws_you_in_then_the_push_drives_you_out() -> void:
	var s := _fight(Vector2(-9, 0))
	var w: World = s[0]
	_start_pull(w, s[1])
	var i := _i(w, s[1])
	var d0 := w.player_pos().distance_to(w.actors.pos(i))
	CombatLab.idle(w, 60)
	var d1 := w.player_pos().distance_to(w.actors.pos(i))
	assert_almost_eq(d0 - d1, 4.5, 0.05, "75 % of the hero's 6 m/s in the pull's first second")
	assert_eq(BossTide.phase_of(w, i), BossTide.PULL)
	CombatLab.idle(w, 119)
	assert_eq(BossTide.phase_of(w, i), BossTide.PULL, "the pull lasts 3 s")
	CombatLab.idle(w, 1)
	assert_eq(BossTide.phase_of(w, i), BossTide.PUSH, "then the push")
	var d2 := w.player_pos().distance_to(w.actors.pos(i))
	CombatLab.idle(w, 29)
	assert_eq(BossTide.phase_of(w, i), BossTide.PUSH, "the throw lasts 0.5 s")
	CombatLab.idle(w, 1)
	var d3 := w.player_pos().distance_to(w.actors.pos(i))
	assert_almost_eq(d3 - d2, 4.0, 0.25, "thrown 4 m out")
	assert_eq(BossTide.phase_of(w, i), BossTide.NONE, "over after 0.5 s")
	var d4 := w.player_pos().distance_to(w.actors.pos(i))
	CombatLab.idle(w, 30)
	assert_almost_eq(w.player_pos().distance_to(w.actors.pos(i)), d4, 0.0001, "no drift after")


func test_the_drift_is_capped_and_stops_at_the_body_and_for_a_dash() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	_start_pull(w, s[1])
	var i := _i(w, s[1])
	var atk := BossAi.attack_of(w, i)
	BossAi.table_of(w, i).dance = null  # The attack's own speeds: what a boss without a dance pulls with
	atk.tide_pull = 5.0 / 60.0  # a mistuned 5 m/s
	assert_almost_eq(Kin.length(BossTide.drift_of(w, i)), 2.2 / 60.0, 0.00001, "capped at 2.2 m/s")
	w.actors.set_pos(
		0, w.actors.pos(i) + Vector2(-(w.actors.radius[i] + w.player.radius_m + 0.2), 0)
	)
	assert_eq(BossTide.drift_of(w, i), Vector2.ZERO, "never into its body")
	w.actors.set_pos(0, Vector2(-6, 0))
	w.dash_ticks_left = 4
	assert_eq(BossTide.drift_of(w, i), Vector2.ZERO, "a dash isn't dragged")


func test_the_push_never_drives_you_into_a_corner_or_onto_a_wall() -> void:
	for start: Vector2 in [Vector2(5.0, 5.0), Vector2(5.4, 1.0), Vector2(-5.3, -5.3)]:
		var s := _fight(start, Vector2.ZERO, 6.0)
		var w: World = s[0]
		_start_pull(w, s[1], &"the_pull_3")
		var i := _i(w, s[1])
		CombatLab.idle(w, BossAi.attack_of(w, i).tide_pull_ticks)
		w.actors.set_pos(0, start)  # the push starts with the player in the corner (or by the wall)
		var before := BossTide.press(w, w.player_pos())
		var worst := before
		for k in 120:
			w.step(InputFrame.new())
			worst = maxf(worst, BossTide.press(w, w.player_pos()))
		assert_lte(worst, before + 0.0001, "%s: never pressed closer to a wall" % start)


func test_the_stream_stops_for_the_pull_and_the_rings_in_flight_bend_toward_it() -> void:
	var s := _fight(Vector2(-9, 0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid, true)
	CombatLab.idle(w, 200)  # The stream runs: rings in flight
	var i := _i(w, aid)
	var id := w.actors.ids[i]
	assert_gt(_shots_of(w, id), 0, "rings in flight before the bell")
	BossLab.start(w, i, &"the_pull")
	var atk := BossAi.attack_of(w, i)
	var span := atk.windup_ticks + atk.tide_pull_ticks + atk.tide_push_ticks
	var fired_in_pull := 0
	var fired_after := 0
	var turned := 0
	var headings := {}
	var resume := BossAi.table_of(w, i).dance.resume_ticks
	for k in span + resume + 240:
		var before := w.bosses.str_ring_n[0]
		w.step(InputFrame.new())
		var born := w.bosses.str_ring_n[0] - before
		if k < span - 1 + resume:  # The bell rang a tick before the first step
			fired_in_pull += born
		else:
			fired_after += born
		if k >= atk.windup_ticks and k < atk.windup_ticks + atk.tide_pull_ticks:
			for j in w.projectiles.size():
				if w.projectiles.owner[j] != id:
					continue
				var key := w.projectiles.ids[j]
				var a := Kin.angle_of(Vector2(w.projectiles.vel_x[j], w.projectiles.vel_y[j]))
				if headings.has(key) and headings[key] != a:
					turned += 1
				headings[key] = a
	assert_eq(fired_in_pull, 0, "no ring leaves from the bell to 1.5 s after the push")
	assert_gt(fired_after, 0, "then the stream resumes")
	assert_gt(turned, 0, "the rings already flying bend toward it in the pull")


func _shots_of(w: World, id: int) -> int:
	var n := 0
	for j in w.projectiles.size():
		if w.projectiles.owner[j] == id:
			n += 1
	return n


func test_a_bent_shot_turns_toward_the_boss() -> void:
	var s := _fight(Vector2(-9, 0))
	var w: World = s[0]
	var i := _i(w, s[1])
	w.queue_projectile(
		w.actors.ids[i], ActorStore.TEAM_ENEMY, Vector2(4, 0), Vector2(0, 0.05), 1, 0.2, 600, 0
	)
	w.step(InputFrame.new())
	var k := w.projectiles.size() - 1
	BossTide.bend(w, i, 10)
	var v := Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])
	assert_lt(v.x, 0.0, "the shot heading +y turns toward the boss at -x")
	assert_almost_eq(v.length(), 0.05, 0.001, "at the same speed")


func test_the_undertow_drags_you_toward_its_circle() -> void:
	var s := _fight(Vector2(-5, 0))
	var w: World = s[0]
	var atk := BossAi.table_of(w, _i(w, s[1])).attacks[BossAi.table_of(w, _i(w, s[1])).attack_index(
		&"undertow"
	)]
	w.actors.set_pos(0, Vector2(2.5, 0))
	BossTide.undertow(w, atk, Vector2(0, 0))
	assert_almost_eq(w.player_pos().x, 1.5, 0.0001, "1 m toward its centre")
	w.actors.set_pos(0, Vector2(0.4, 0))
	BossTide.undertow(w, atk, Vector2(0, 0))
	assert_almost_eq(w.player_pos().x, 0.0, 0.0001, "never past it")
	w.actors.set_pos(0, Vector2(3.5, 0))
	BossTide.undertow(w, atk, Vector2(0, 0))
	assert_almost_eq(w.player_pos().x, 3.5, 0.0001, "beyond its reach: no drag")


func test_the_undertow_strikes_on_its_locked_circle_and_drags() -> void:
	var s := _fight(Vector2(-4, 0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	BossLab.start(w, _i(w, aid), &"undertow")
	var atk := BossAi.attack_of(w, _i(w, aid))
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks + 2)
	var c := BossDodge.mark_of(w, _i(w, aid), 0)
	w.actors.set_pos(0, c + Vector2(0, 2.4))  # out of the circle, within its reach (clear of the boss)
	CombatLab.idle(w, atk.lock_ticks + 2)
	assert_almost_eq(w.player_pos().distance_to(c), 1.4, 0.05, "dragged 1 m in when it struck")


func test_shielded_through_the_pull() -> void:
	var s := _fight(Vector2(-9, 0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	BossLab.start(w, _i(w, aid), &"the_pull")
	assert_true(BossDodge.shielded(w, _i(w, aid)), "the bell's windup")
	_until_active(w, aid)
	CombatLab.idle(w, 200)
	assert_true(BossDodge.shielded(w, _i(w, aid)), "the push")
	CombatLab.idle(w, 110)
	assert_false(BossDodge.shielded(w, _i(w, aid)), "open after")


func test_the_pull_comes_on_its_rhythm_and_never_by_the_pick() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var t := BossAi.table_of(w, _i(w, aid))
	t.punish_ticks = 0
	var starts := PackedInt32Array()
	var ends := PackedInt32Array()
	var was := false
	for k in 60 * 60:
		w.step(InputFrame.new())
		var now := BossTideBeats.pulling(w, _i(w, aid))
		if now and not was:
			starts.append(w.tick)
		elif was and not now:
			ends.append(w.tick)
		was = now
	assert_gte(starts.size(), 3, "three Pulls in 60 s")
	# Due 6 s in, then 3 s of calm and 12 s after each one ends; it starts at the boss's first free moment.
	assert_between(starts[0], 361, 480, "the first about 6 s in")
	for k in range(1, starts.size()):
		assert_between(starts[k] - ends[k - 1], 900, 1020, "15 s after the last one ended")
	for k in t.attacks.size():
		if t.attacks[k].move == BossAttackTable.Move.TIDE:
			assert_true(BossTide.on_cadence(t, t.attacks[k]), "the pick leaves it out")


func test_phase_2_opens_with_its_riptide_and_phase_3_with_no_pull() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	w.step(InputFrame.new())
	BossLab.through_gate(w, aid)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, _i(w, aid))], 1)
	var opens := BossAi.attack_of(w, _i(w, aid))
	assert_true(opens == null or opens.move != BossAttackTable.Move.TIDE, "no Pull opens phase 2")
	CombatLab.idle(w, 1)
	assert_eq(w.boss_fight.dance_beat_phase, 1)
	assert_eq(
		BossTideBeats.next_of(
			w, BossAi.table_of(w, _i(w, aid)), BossAi.table_of(w, _i(w, aid)).dance, 1
		),
		BossTideBeats.RIPTIDE,
		"its first beat is the Riptide it brings"
	)
	w.actors.hp[_i(w, aid)] = w.actors.max_hp[_i(w, aid)] * 320 / 1000
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == BossAi.GATE, 700
	)
	BossLab.through_gate(w, aid)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, _i(w, aid))], 2)
	var opening := BossAi.attack_of(w, _i(w, aid))
	assert_true(
		opening == null or opening.move != BossAttackTable.Move.TIDE,
		"phase 3 is the Maelstrom: it opens with no Pull"
	)


func test_deterministic_and_a_mid_pull_save_restores() -> void:
	var make := func() -> World:
		var s := _fight(Vector2(-7, 2), Vector2.ZERO, 10.0)
		var w: World = s[0]
		CombatLab.idle(w, 460)  # into the first Pull
		return w
	var a: World = make.call()
	var b: World = make.call()
	for k in 120:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree mid-fight")
	assert_gte(a.boss_fight.dance_beat_k, 1, "the rhythm is in the state")
	var before := a.state_hash()
	a.boss_fight.dance_beat_end += 1
	assert_ne(a.state_hash(), before, "and in the hash")
	a.boss_fight.dance_beat_end -= 1
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), make.call())
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	for k in 360:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		a.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 360 ticks on")


func test_the_death_lines_name_the_tide() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var t := BossAi.table_of(w, _i(w, s[1]))
	w.killer_kind = ActorStore.Kind.TIDECALLER
	w.killer_attack = t.attack_index(&"the_pull")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TIDECALLER_PULL")
	assert_eq(
		String(
			TranslationServer.get_translation_object("en").get_message(&"CAUSE_TIDECALLER_PULL")
		),
		"The Tidecaller's tide dragged you into its rings."
	)
	w.killer_attack = t.attack_index(&"undertow")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TIDECALLER_UNDERTOW")
