extends GutTest
## v0.11.0 F9 (owner: "The Warlord throws a javelin into the arena ... embedded ... earthquake-like ... vibrates ... the
## boss recalls it. On its return path toward the boss, the javelin can damage the player."): BossGreatJavelin: the
## throw hurts on its way and embeds at the point or the first wall; 5 s embedded with a ring pulse every 1.25 s; the
## recall line then the flight back, which hits a hero on the line and misses one off it; one out at a time; gone with
## its boss; its state survives a save and is deterministic; the real attack sequence reaches it in every phase.

const HP := 100000
const OFF_M := 3.0
## Where the pace test's hero stands (the AI's picks, away from the gap-closer's and punish rules' distances).
const STAND := Vector2(4, 0)


func _fight(player_at: Vector2, seed_value: int = 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"warlord", Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	_keep_alive(w)
	return [w, w.actors.ids[i]]


## The hero stays up and i-frame free: the tests read this attack's hits (filtered by effect) only.
func _keep_alive(w: World) -> void:
	w.actors.hp[0] = HP
	w.actors.max_hp[0] = HP
	w.actors.invuln[0] = 0


func _step(w: World, at: Vector2 = Vector2.INF) -> void:
	if at != Vector2.INF:
		w.actors.set_pos(0, at)
	_keep_alive(w)
	w.step(InputFrame.new())


func _atk(w: World, aid: int) -> BossAttackTable:
	var t := BossAi.table_of(w, w.actors.index_of(aid))
	return t.attacks[t.attack_index(&"great_javelin")]


func _hits(w: World, effect: StringName) -> Array:
	var out := []
	for e in w.events_since(0):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.target_id == w.actors.ids[0]
			and e.effect_id == effect
		):
			out.append(e)
	return out


func _throw_and_land(w: World, aid: int, stand: Vector2) -> int:
	BossLab.start(w, w.actors.index_of(aid), &"great_javelin")
	for t in 240:
		_step(w, stand)
		if w.bosses.gj_phase.size() > 0 and w.bosses.gj_phase[0] == BossGreatJavelin.EMBEDDED:
			return w.tick
	return -1


func _at_phase(w: World, stand: Vector2, phase: int, limit: int = 900) -> void:
	for t in limit:
		if w.bosses.gj_phase.size() > 0 and w.bosses.gj_phase[0] == phase:
			return
		_step(w, stand)


func test_the_warlords_attack_sequence_carries_it_from_the_first_phase_on() -> void:
	var def: BossDefinition = load("res://data/bosses/warlord.tres")
	assert_eq(def.validate(), [] as Array[ValidationIssue], "valid")
	for ph: BossPhaseDefinition in def.phases:
		assert_true(ph.attack_ids.has("great_javelin"), "in every phase")
	var bad := def.duplicate(true) as BossDefinition
	for a: BossAttackDefinition in bad.attacks:
		if a.id == &"great_javelin":
			a.shape_params["pulse_permille"] = 200
	assert_gt(bad.validate().size(), 0, "the quake's cap holds")


func test_the_throw_hurts_on_its_way_and_embeds_where_it_was_aimed() -> void:
	var at := Vector2(9, 0)
	var s := _fight(at)
	var w: World = s[0]
	var aid: int = s[1]
	var landed := _throw_and_land(w, aid, at)
	assert_gt(landed, 0, "it landed")
	assert_almost_eq(w.bosses.gj_x[0], at.x, 0.1, "at the hero's point")
	assert_almost_eq(w.bosses.gj_y[0], at.y, 0.1)
	var hits := _hits(w, BossGreatJavelin.THROW_EFFECT)
	assert_eq(hits.size(), 1, "the throw hit once")
	assert_eq(hits[0].amount_applied, _atk(w, aid).damage, "at the boss's tier")


func test_a_hero_off_the_line_after_the_lock_is_not_hit() -> void:
	var aim := Vector2(9, 0)
	var s := _fight(aim)
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"great_javelin")
	var atk := _atk(w, aid)
	for t in atk.windup_ticks - atk.lock_ticks:
		_step(w, aim)  # the line follows until it locks
	for t in 80:
		_step(w, aim + Vector2(0, OFF_M))
		if w.bosses.gj_phase.size() > 0 and w.bosses.gj_phase[0] == BossGreatJavelin.EMBEDDED:
			break
	assert_eq(_hits(w, BossGreatJavelin.THROW_EFFECT).size(), 0, "missed")
	assert_almost_eq(w.bosses.gj_x[0], aim.x, 0.1, "it embeds where it locked")


func test_it_embeds_at_the_first_wall() -> void:
	var at := Vector2(9, 0)
	var s := _fight(at)
	var w: World = s[0]
	var aid: int = s[1]
	var wall_x := 5.0
	w.add_barrier(Obb.make(Vector2(wall_x, 0), Vector2(0.4, 3.0), 0))
	_throw_and_land(w, aid, at)
	assert_lt(w.bosses.gj_x[0], wall_x, "stopped by the wall")
	assert_gt(w.bosses.gj_x[0], wall_x - 1.2, "against it")
	assert_eq(_hits(w, BossGreatJavelin.THROW_EFFECT).size(), 0, "the wall took it")


func test_it_stays_embedded_for_its_time_then_warns_then_flies() -> void:
	var at := Vector2(8, 3)
	var s := _fight(Vector2(30, 30))
	var w: World = s[0]
	var aid: int = s[1]
	var atk := _atk(w, aid)
	assert_eq(atk.great_embed_ticks, 300, "5.0 s")
	assert_eq(atk.great_recall_warn_ticks, 36, "0.6 s")
	var landed := _throw_and_land(w, aid, at)
	_at_phase(w, Vector2(30, 30), BossGreatJavelin.RECALL_WARN)
	assert_eq(w.tick - landed, atk.great_embed_ticks, "embedded for its whole time")
	assert_true(w.bosses.gj_boss.has(aid))
	var warned := w.tick
	_at_phase(w, Vector2(30, 30), BossGreatJavelin.RETURN)
	assert_eq(w.tick - warned, atk.great_recall_warn_ticks, "the recall line is shown that long")


func test_the_ring_pulses_at_its_rate_and_range() -> void:
	var at := Vector2(9, 0)
	var s := _fight(at)
	var w: World = s[0]
	var aid: int = s[1]
	var atk := _atk(w, aid)
	assert_eq(atk.great_pulse_ticks, 75, "1.25 s")
	assert_eq(atk.great_warn_ticks, 30, "0.5 s")
	var landed := _throw_and_land(w, aid, at)
	var c := Vector2(w.bosses.gj_x[0], w.bosses.gj_y[0])
	var edge := atk.great_ring_m + w.player.radius_m
	for t in atk.great_embed_ticks:
		_step(w, c + Vector2(0, edge - 0.05))
	var hits := _hits(w, BossGreatJavelin.QUAKE_EFFECT)
	assert_eq(hits.size(), 4, "a pulse every 1.25 s for 5 s")
	var ticks := []
	for e in hits:
		ticks.append(e.tick - (landed - 1))  # (w.tick is the next one to run; a tick's events carry its own)
		assert_eq(
			e.amount_applied, HP * atk.great_pulse_permille / 1000, "4 % of the hero's max HP"
		)
	assert_eq(ticks, [75, 150, 225, 300])
	var far := _fight(at, 12)
	var w2: World = far[0]
	_throw_and_land(w2, far[1], at)
	var bi2 := w2.actors.index_of(far[1])
	w2.actors.state[bi2] = BossAi.STAGGERED  # held still: its walk must not shove the hero into the ring
	w2.bosses.stagger_t[BossAi.entry_of(w2, bi2)] = 1 << 20
	var c2 := Vector2(w2.bosses.gj_x[0], w2.bosses.gj_y[0])
	for t in atk.great_embed_ticks:
		_step(w2, c2 + Vector2(0, edge + 0.05))
	assert_eq(_hits(w2, BossGreatJavelin.QUAKE_EFFECT).size(), 0, "just outside the ring")


func _to_return(w: World, aid: int, throw_at: Vector2, stand: Vector2) -> void:
	_throw_and_land(w, aid, throw_at)
	_at_phase(w, stand, BossGreatJavelin.RECALL_WARN)


func test_the_recall_hits_a_hero_on_its_line_and_misses_one_off_it() -> void:
	var cases := [[0.0, 1], [OFF_M, 0]]
	for row: Array in cases:
		var at := Vector2(11, 4)
		var s := _fight(Vector2(30, 30))
		var w: World = s[0]
		var aid: int = s[1]
		_to_return(w, aid, at, Vector2(30, 30))
		var from := Vector2(w.bosses.gj_x[0], w.bosses.gj_y[0])
		var to := Vector2(w.bosses.gj_tox[0], w.bosses.gj_toy[0])
		var mid := from.lerp(to, 0.5)
		var off := (to - from).normalized().orthogonal() * float(row[0])
		var stand: Vector2 = mid + off
		for t in 200:
			_step(w, stand)
			if w.bosses.gj_boss.is_empty():
				break
		assert_true(w.bosses.gj_boss.is_empty(), "it flew back and is gone (it never crumbles)")
		var hits := _hits(w, BossGreatJavelin.RETURN_EFFECT)
		assert_eq(hits.size(), int(row[1]), "%.1f m off the line" % float(row[0]))
		if hits.size() > 0:
			assert_eq(hits[0].amount_applied, _atk(w, aid).damage, "at the boss's tier")


func test_a_hero_on_the_embedded_point_is_hit_by_the_recall_and_it_does_not_crumble() -> void:
	var at := Vector2(10, 2)
	var s := _fight(Vector2(30, 30))
	var w: World = s[0]
	var aid: int = s[1]
	_to_return(w, aid, at, Vector2(30, 30))
	var c := Vector2(w.bosses.gj_x[0], w.bosses.gj_y[0])
	for t in 200:
		_step(w, c)
		if w.bosses.gj_boss.is_empty():
			break
	assert_eq(_hits(w, BossGreatJavelin.RETURN_EFFECT).size(), 1, "it flies through the hero")


func test_only_one_is_out_at_a_time() -> void:
	var at := Vector2(9, 0)
	var s := _fight(at)
	var w: World = s[0]
	var aid: int = s[1]
	var bi := w.actors.index_of(aid)
	_throw_and_land(w, aid, at)
	assert_eq(w.bosses.gj_boss.size(), 1, "one out")
	var atk := _atk(w, aid)
	assert_false(BossGreatJavelin.may_use(w, bi, atk), "the boss won't pick it")
	var other: BossAttackTable = BossAi.table_of(w, bi).attacks[0]
	assert_true(BossGreatJavelin.may_use(w, bi, other), "it can use its others")
	BossLab.start(w, w.actors.index_of(aid), &"great_javelin")
	for t in atk.windup_ticks + 4:
		_step(w, at)
	assert_eq(w.bosses.gj_boss.size(), 1, "even started by hand, a second never leaves")


func test_it_goes_with_its_boss() -> void:
	var at := Vector2(9, 0)
	var s := _fight(at)
	var w: World = s[0]
	var aid: int = s[1]
	_throw_and_land(w, aid, at)
	assert_eq(w.bosses.gj_boss.size(), 1)
	var bi := w.actors.index_of(aid)
	w.actors.hp[bi] = 0
	w.actors.dead[bi] = 1
	for t in 6:
		_step(w, at)
	assert_true(w.bosses.gj_boss.is_empty(), "gone")


func test_it_is_deterministic_and_survives_a_save() -> void:
	var make := func() -> World:
		var s := _fight(Vector2(9, 0))
		var w: World = s[0]
		_throw_and_land(w, s[1], Vector2(9, 0))
		for t in 60:
			_step(w, Vector2(9, 0))
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_eq(a.bosses.gj_boss.size(), 1)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	var base := BossLab.world()
	BossLab.ready_boss(base, &"warlord")
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "restores (%s)" % WorldSnapshot.apply(base, snap))
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "a save keeps it")
	assert_eq(restored.bosses.gj_boss.size(), 1, "and it is back")
	assert_eq(restored.bosses.gj_phase[0], BossGreatJavelin.EMBEDDED)
	for t in 400:
		_step(restored, Vector2(9, 0))
		_step(a, Vector2(9, 0))
	assert_eq(restored.state_hash(), a.state_hash(), "and it runs on the same")


func test_the_recap_lines_and_readability() -> void:
	var at := Vector2(9, 0)
	var s := _fight(at)
	var w: World = s[0]
	var aid: int = s[1]
	var rc := ReadableCause.new(w)
	BossLab.start(w, w.actors.index_of(aid), &"great_javelin")
	for t in 900:
		_step(w, at)
		rc.observe(w)
		if w.bosses.gj_boss.is_empty() and t > 100:
			break
	var keep := []
	for v in rc.violations:
		if (
			"great javelin" in String(v.get("problems", ""))
			or String(v.get("cause", "")).contains("GREAT")
		):
			keep.append(v)
	assert_eq(keep, [], "readable")
	assert_gt(
		int(rc.by_cause.get("CAUSE_WARLORD_GREAT", 0)), 0, "the throw and the quake have a line"
	)
	assert_gt(int(rc.by_cause.get("CAUSE_WARLORD_RECALL", 0)), 0, "the way back has its line")


## The real attack loop (AI picks), per phase; prints the pace for the evidence.
func test_the_real_attack_sequence_reaches_it_in_every_phase() -> void:
	for phase_hp: Array in [[1000, 0], [640, 1], [320, 2]]:
		var counts := []
		for sd in [5, 6, 7]:
			var s := _fight(STAND, sd)
			var w: World = s[0]
			var aid: int = s[1]
			var bi := w.actors.index_of(aid)
			w.actors.hp[bi] = w.actors.max_hp[bi] * int(phase_hp[0]) / 1000
			var seen := 0
			var was := false
			for t in 3600:  # 60 s of fight against a hero in melee range (BossChallenge's gap-closer and punish keep off)
				_step(w, STAND)
				var out := w.bosses.gj_boss.has(aid)
				if out and not was:
					seen += 1
				was = out
			assert_eq(w.bosses.phase[BossAi.entry_of(w, bi)], int(phase_hp[1]), "phase held")
			counts.append(seen)
			assert_gt(seen, 0, "thrown in phase %d (seed %d)" % [int(phase_hp[1]) + 1, sd])
		gut.p("great javelin throws in 60 s at phase %d: %s" % [int(phase_hp[1]) + 1, str(counts)])
