# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 NB3 (owner Q24 "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N3): The Clockwork Judge, floor 5's
## boss. Your echo (shielded): it keeps where you walked over the last 3 s (a point every 0.25 s); every 10 s the path
## locks, shows whole for 0.8 s, then a ghost trail of strikes (20 each) replays along it in the order walked, one
## every 0.25 s, so looping is punished; it never strikes where you stand as it starts; one echo at a time. Gear
## Spiral: two arms of gear-sparks turning, reversing at each phase. Verdict: a tracked square that locks and drops a
## pendulum strike. Phases at 66 % and 33 %, determinism, a mid-echo save, an older save, the death lines.

const S := EnemyAi.State
const LONG := 1 << 20


func _fight(player_at: Vector2, boss_at := Vector2.ZERO) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"clockwork_judge", boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## The boss picks nothing on its own (no phase list, no cadence, no punish): only what a test starts.
func _hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, _i(w, aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## Steps once with the player placed at p first (the boss never moves them); returns the HP the step cost them, with
## their hurt iframes cleared so every strike counts.
func _step_at(w: World, p: Vector2) -> int:
	w.actors.set_pos(0, p)
	w.actors.invuln[0] = 0
	var hp := w.actors.hp[0]
	w.step(InputFrame.new())
	var lost := maxi(0, hp - w.actors.hp[0])
	w.actors.hp[0] = LONG
	return lost


## Walks the player along `path` (a position per tick, from tick 0) for n ticks.
func _walk(w: World, n: int, at: Callable) -> void:
	for k in n:
		w.actors.set_pos(0, at.call(k))
		w.step(InputFrame.new())


func _line(k: int) -> Vector2:
	return Vector2(-8.0 + 0.05 * k, 4.0)  # 3 m/s along +x


func test_the_data_is_the_approved_row() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"clockwork_judge")
	assert_not_null(def)
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_eq(t.kind, ActorStore.Kind.CLOCKWORK_JUDGE)
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]), "phases at 66 % and 33 %")
	assert_eq(t.sig_every_ticks, 600, "an echo every 10 s")
	assert_eq([t.echo_points, t.echo_gap_ticks], [12, 15], "3 s recorded, a point per 0.25 s")
	var echo := t.attacks[t.attack_index(&"the_echo")]
	assert_eq(echo.move, BossAttackTable.Move.ECHO)
	assert_true(echo.shielded, "shielded during the signature")
	assert_eq(echo.damage, 20, "20 each")
	assert_eq(echo.windup_ticks, 48, "the whole path shows 0.8 s before the first strike")
	assert_eq([echo.echo_points, echo.echo_gap_ticks], [12, 15], "1 strike per 0.25 s of path")
	assert_eq(echo.active_ticks, 11 * 15 + 1, "active until the last point strikes")
	for p in 3:
		assert_eq(
			BossTide.signature_of(t, p), t.attack_index(&"the_echo"), "the echo in phase %d" % p
		)
	var verdict := t.attacks[t.attack_index(&"verdict")]
	assert_eq(verdict.move, BossAttackTable.Move.VERDICT)
	assert_eq(verdict.lock_ticks, 48, "tracked, then locked 0.8 s")
	assert_almost_eq(verdict.square_half_m, 1.5, 0.0001, "a 3 m square")
	var spins := []
	for id: StringName in [&"gear_spiral", &"gear_spiral_2", &"gear_spiral_3"]:
		var sp := t.attacks[t.attack_index(id)]
		assert_eq(sp.pattern.kind, BulletPatternTable.Kind.SPIRAL, "%s: a spiral" % id)
		assert_eq(sp.pattern.arms, 2, "%s: two arms" % id)
		spins.append(signi(sp.pattern.spin_milli))
	assert_eq(spins, [1, -1, 1], "the Gear Spiral reverses at each phase")
	assert_eq(t.phase_entry[1], t.attack_index(&"gear_spiral_2"), "phase 2 opens reversed")
	assert_eq(t.phase_entry[2], t.attack_index(&"gear_spiral_3"), "phase 3 reverses again")
	var pool := ContentCompiler.compile_boss_pool(repo, 5)
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	assert_eq(pool.size(), 2, "floor 5 draws the Judge or (v0.9.0 NB4) the Lantern Shade")
	assert_eq(ids[pool[0]], &"clockwork_judge")


func _codes_with(change: Callable) -> Array:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = (
		(repo.get_def(&"bosses", &"clockwork_judge") as BossDefinition).duplicate(true)
	)
	change.call(def)
	return def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_bad_echo_and_verdict_numbers_are_errors() -> void:
	var unshielded := func(d: BossDefinition) -> void: d.attack(&"the_echo").shielded = false
	assert_has(_codes_with(unshielded), &"missing", "an echo is shielded")
	var no_step := func(d: BossDefinition) -> void:
		d.attack(&"the_echo").shape_params["step_seconds"] = 0.0
	assert_has(_codes_with(no_step), &"range", "a step of at least a tick")
	var many := func(d: BossDefinition) -> void:
		d.attack(&"the_echo").shape_params["step_seconds"] = 0.05
	assert_has(_codes_with(many), &"range", "at most 24 points")
	var flat := func(d: BossDefinition) -> void: d.attack(&"verdict").shape_params["half_m"] = 0.0
	assert_has(_codes_with(flat), &"not_positive", "a real square")
	var short := func(d: BossDefinition) -> void: d.signature_every_seconds = 3.5
	assert_has(_codes_with(short), &"duration", "the cadence outlasts its echo")


func test_it_records_your_last_3_s_a_point_every_quarter_second() -> void:
	var s := _fight(Vector2(-8, 4))
	var w: World = s[0]
	_hush(w, s[1])
	var t0 := w.tick
	_walk(w, 240, _line)
	var bs := w.bosses
	assert_eq(bs.echo_boss, s[1], "the Judge records")
	assert_eq(bs.echo_x.size(), 12, "the last 12 points")
	var expect := PackedFloat32Array()
	for k in 240:
		if (t0 + k) % 15 == 0:  # the boss thinks on the tick being stepped
			expect.append(_line(k).x)
	expect = expect.slice(expect.size() - 12)
	for k in 12:
		assert_almost_eq(bs.echo_x[k], expect[k], 0.001, "point %d, oldest first" % k)
		assert_almost_eq(bs.echo_y[k], 4.0, 0.001)


func test_the_replay_strikes_along_the_path_a_quarter_second_apart_after_0_8_s() -> void:
	var s := _fight(Vector2(-8, 4))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	_walk(w, 240, _line)
	var start := w.player_pos()
	var keep := 0.9 + w.player.radius_m + 0.3
	BossLab.start(w, _i(w, aid), &"the_echo")
	var e := WorldReader.new(w).boss_echo(_i(w, aid))
	assert_eq(int(e["phase"]), WorldReader.ECHO_SHOW, "the path shows first")
	var path: Array = e["path"]
	assert_between(path.size(), 9, 11, "the points by the start left out")
	for m in path.size():
		var p: Dictionary = path[m]
		assert_gte(Kin.length(p["pos"] - start), keep, "never where you stand at its start")
		assert_eq(int(p["at"]), 48 + int(p["k"]) * 15, "point %d: 0.8 s, then every 0.25 s" % m)
		assert_false(bool(p["struck"]))
		if m > 0:
			assert_eq(int(p["k"]), int(path[m - 1]["k"]) + 1, "in the order walked")
	for k in w.bosses.echo_x.size():
		var c := Vector2(w.bosses.echo_x[k], w.bosses.echo_y[k])
		if Kin.length(c - start) >= keep:
			assert_true(path.any(func(p: Dictionary) -> bool: return p["k"] == k), "kept %d" % k)
	# Standing on point m the whole replay: hurt exactly on the ticks a point touching it strikes (20 each).
	var m := 3
	var here: Vector2 = path[m]["pos"]
	var hits := []
	var due := []
	for p: Dictionary in path:
		if Kin.length(p["pos"] - here) <= 0.9 + w.player.radius_m:
			due.append(int(p["at"]))
	var reader := WorldReader.new(w)
	for k in 48 + 12 * 15 + 40:  # (a hurt's hit-stop holds the sim's clock a few ticks)
		var hurt := _step_at(w, here)
		var now := reader.boss_echo(_i(w, aid))
		if int(now["phase"]) == WorldReader.ECHO_NONE:
			break
		var into := int(now["t"])  # the echo's own clock
		if hurt > 0:
			assert_eq(hurt, 20, "20 a strike")
			hits.append(into)
	assert_eq(hits, due, "each strike on its tick, where it was walked")
	assert_true(due.has(int(path[m]["at"])))


func test_standing_still_through_its_start_is_never_struck() -> void:
	var s := _fight(Vector2(-6, 3))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	CombatLab.idle(w, 240)
	BossLab.start(w, _i(w, aid), &"the_echo")
	assert_eq(w.bosses.path_k.size(), 0, "every point is where you stand: none strikes")
	var hurt := 0
	for k in 260:
		hurt += _step_at(w, Vector2(-6, 3))
	assert_eq(hurt, 0, "never struck where you stood")


func test_looping_is_punished_and_crossing_away_is_not() -> void:
	# A loop of 2 m radius once every 3.8 s (the echo's lag): the ghosts land where you come round again.
	var loop := func(k: int) -> Vector2:
		var a := TAU * float(k) / 228.0
		return Vector2(-6.0, 0.0) + Vector2(cos(a), sin(a)) * 2.0
	var s := _fight(loop.call(0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	_walk(w, 240, loop)
	BossLab.start(w, _i(w, aid), &"the_echo")
	var hurt := 0
	for k in 48 + 12 * 15:
		hurt += _step_at(w, loop.call(240 + k))
	assert_gt(hurt, 0, "looping is hit by your own echo")
	var s2 := _fight(_line(0))
	var w2: World = s2[0]
	_hush(w2, s2[1])
	_walk(w2, 240, _line)
	BossLab.start(w2, _i(w2, s2[1]), &"the_echo")
	var hurt2 := 0
	for k in 48 + 12 * 15:
		hurt2 += _step_at(w2, Vector2(_line(240).x + 2.0, -2.0))
	assert_eq(hurt2, 0, "stepping off your path is safe")


func test_shielded_through_the_echo() -> void:
	var s := _fight(Vector2(-8, 4))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	_walk(w, 200, _line)
	BossLab.start(w, _i(w, aid), &"the_echo")
	assert_true(BossDodge.shielded(w, _i(w, aid)), "while the path shows")
	CombatLab.idle(w, 48 + 100)
	assert_true(BossDodge.shielded(w, _i(w, aid)), "while the ghosts strike")
	CombatLab.idle(w, 70)
	assert_false(BossDodge.shielded(w, _i(w, aid)), "open after")


func test_the_echo_comes_every_10_s_one_at_a_time_never_by_the_pick() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var t := BossAi.table_of(w, _i(w, aid))
	t.punish_ticks = 0
	var starts := PackedInt32Array()
	var was := false
	for k in 60 * 40:
		var a := TAU * float(k) / 300.0
		w.actors.set_pos(0, Vector2(cos(a), sin(a)) * 7.0)
		w.actors.hp[0] = LONG
		w.step(InputFrame.new())
		var atk := BossAi.attack_of(w, _i(w, aid))
		var now := atk != null and atk.move == BossAttackTable.Move.ECHO
		if now and not was:
			starts.append(w.tick)
		was = now
	assert_gte(starts.size(), 3, "three echoes in 40 s")
	# Due 4 s in, then 10 s after the last start; it starts at the boss's first free moment (another attack may run).
	assert_between(starts[0], 230, 480, "the first about 4 s in")
	for k in range(1, starts.size()):
		assert_between(starts[k] - starts[k - 1], 600, 860, "every 10 s, start to start")
	for k in t.attacks.size():
		if t.attacks[k].move == BossAttackTable.Move.ECHO:
			assert_true(BossTide.on_cadence(t, t.attacks[k]), "the pick leaves it out")


func test_a_far_player_cannot_starve_the_echo() -> void:
	# The punish and the gap-closer (both the Verdict) would chain while the player keeps away: once the echo is due
	# they wait for it (BossTide.HOLD), so it still comes on its cadence.
	var s := _fight(Vector2(12, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var starts := PackedInt32Array()
	var was := false
	for k in 60 * 30:
		var i := _i(w, aid)
		var a := TAU * float(k) / 240.0
		w.actors.set_pos(0, w.actors.pos(i) + Vector2(cos(a), sin(a)) * 12.0)
		w.actors.hp[0] = LONG
		w.step(InputFrame.new())
		var atk := BossAi.attack_of(w, _i(w, aid))
		var now := atk != null and atk.move == BossAttackTable.Move.ECHO
		if now and not was:
			starts.append(w.tick)
		was = now
	assert_gte(starts.size(), 2, "the echo keeps coming with the player far away")
	for k in range(1, starts.size()):
		assert_between(starts[k] - starts[k - 1], 600, 860, "every 10 s, start to start")


func test_the_verdict_tracks_a_square_then_locks_and_drops() -> void:
	var s := _fight(Vector2(5, 0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	BossLab.start(w, _i(w, aid), &"verdict")
	var reader := WorldReader.new(w)
	for k in 20:
		w.actors.set_pos(0, Vector2(5, 0.1 * k))
		w.step(InputFrame.new())
	var v: Dictionary = reader.boss_echo(_i(w, aid))["verdict"]
	assert_false(bool(v["locked"]), "it tracks")
	assert_almost_eq((v["center"] as Vector2).y, w.player_pos().y, 0.11, "on you")
	var tg := reader.telegraph(_i(w, aid))
	assert_eq(tg["shape"], &"lanes", "a square on the ground")
	var o: Obb = tg["obbs"][0]
	assert_almost_eq(o.half.x, 1.5, 0.0001)
	assert_almost_eq(o.half.y, 1.5, 0.0001, "square, not a circle")
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state_t[_i(x, aid)] >= 96 - 48, 100)
	var locked_at: Vector2 = reader.boss_echo(_i(w, aid))["verdict"]["center"]
	w.actors.set_pos(0, Vector2(9, 9))
	CombatLab.idle(w, 10)
	assert_eq(reader.boss_echo(_i(w, aid))["verdict"]["center"], locked_at, "locked")
	assert_true(bool(reader.boss_echo(_i(w, aid))["verdict"]["locked"]))
	# A corner of the square (outside a circle of its half-width) is struck; a step past its edge is not.
	var corner := locked_at + Vector2(1.45, 1.45)
	var hurt := 0
	while w.actors.state[_i(w, aid)] == S.WINDUP:
		hurt += _step_at(w, corner)
	assert_eq(hurt, 30, "the pendulum drops on the square's corner")
	var s2 := _fight(Vector2(5, 0))
	var w2: World = s2[0]
	_hush(w2, s2[1])
	BossLab.start(w2, _i(w2, s2[1]), &"verdict")
	CombatLab.idle(w2, 50)
	var c2: Vector2 = WorldReader.new(w2).boss_echo(_i(w2, s2[1]))["verdict"]["center"]
	var miss := 0
	for k in 60:
		miss += _step_at(w2, c2 + Vector2(1.5 + w2.player.radius_m + 0.1, 0))
	assert_eq(miss, 0, "past its edge you are safe")


func test_the_phases_open_with_the_reversed_spiral() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	w.step(InputFrame.new())
	BossLab.through_gate(w, aid)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, _i(w, aid))], 1)
	assert_eq(BossAi.attack_of(w, _i(w, aid)).id, &"gear_spiral_2", "phase 2 reverses the spiral")
	w.actors.hp[_i(w, aid)] = w.actors.max_hp[_i(w, aid)] * 320 / 1000
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == BossAi.GATE, 900
	)
	BossLab.through_gate(w, aid)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, _i(w, aid))], 2)
	assert_eq(BossAi.attack_of(w, _i(w, aid)).id, &"gear_spiral_3", "phase 3 reverses it again")


func test_deterministic_and_a_mid_echo_save_restores() -> void:
	var make := func() -> World:
		var s := _fight(Vector2(-8, 4))
		var w: World = s[0]
		_hush(w, s[1])
		_walk(w, 240, _line)
		BossLab.start(w, w.actors.index_of(s[1]), &"the_echo")
		CombatLab.idle(w, 48 + 40)  # mid-replay
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree mid-echo")
	assert_false(a.bosses.path_k.is_empty(), "the path is in the state")
	var before := a.state_hash()
	a.bosses.path_x[0] += 0.5
	assert_ne(a.state_hash(), before, "and in the hash")
	a.bosses.path_x[0] -= 0.5
	a.bosses.echo_x[0] += 0.5
	assert_ne(a.state_hash(), before, "the recording too")
	a.bosses.echo_x[0] -= 0.5
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


func test_an_older_snapshot_without_the_echo_loads() -> void:
	var s := _fight(Vector2(-7, 2))
	var w: World = s[0]
	CombatLab.idle(w, 60)
	var snap := WorldSnapshot.take(w)
	var bosses: Dictionary = snap["world"][&"bosses"]
	assert_true(bosses.has(&"echo_x"), "the echo is saved")
	for f: StringName in [&"echo_boss", &"echo_x", &"echo_y", &"path_x", &"path_y", &"path_k"]:
		bosses.erase(f)
	var base := BossLab.world()
	BossLab.ready_boss(base, &"clockwork_judge")
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save from before NB3 loads")
	assert_true(base.bosses.echo_x.is_empty(), "with no recording yet")
	CombatLab.idle(base, 31)
	assert_gt(base.bosses.echo_x.size(), 0, "it records again from its next think")


func test_a_world_without_a_judge_hashes_as_before() -> void:
	var w := BossLab.world()
	BossLab.ready_boss(w, &"tidecaller")
	CombatLab.idle(w, 40)
	assert_eq(w.bosses.echo_boss, -1, "no Judge, no echo state")


func test_the_echo_goes_with_the_judge() -> void:
	var s := _fight(Vector2(-7, 2))
	var w: World = s[0]
	CombatLab.idle(w, 40)
	assert_eq(w.bosses.echo_boss, s[1])
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(w.bosses.echo_boss, -1)
	assert_true(w.bosses.echo_x.is_empty())


func test_the_death_lines_name_the_echo() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var t := BossAi.table_of(w, _i(w, s[1]))
	w.killer_kind = ActorStore.Kind.CLOCKWORK_JUDGE
	w.killer_attack = t.attack_index(&"the_echo")
	assert_eq(BossAi.cause_key(w), &"CAUSE_JUDGE_ECHO")
	var en := TranslationServer.get_translation_object("en")
	assert_eq(
		String(en.get_message(&"CAUSE_JUDGE_ECHO")),
		"The Clockwork Judge's verdict caught your old steps."
	)
	var es := TranslationServer.get_translation_object("es")
	assert_ne(String(es.get_message(&"CAUSE_JUDGE_ECHO")), "", "in Spanish too")
	w.killer_attack = t.attack_index(&"verdict")
	assert_eq(BossAi.cause_key(w), &"CAUSE_JUDGE_VERDICT")
	w.killer_attack = t.attack_index(&"gear_spiral_2")
	assert_eq(BossAi.cause_key(w), &"CAUSE_JUDGE_SPIRAL")
	w.killer_attack = t.attack_index(&"gavel_slam")
	assert_eq(BossAi.cause_key(w), &"CAUSE_JUDGE_GAVEL")
