# gdlint: disable=max-public-methods
extends GutTest
## The Twin Wardens, floor 4's second boss. Two bodies (two linked actors, BossTwin), one shared HP, one bar, one
## defeat, and nothing joining them: no chain, no burn, no pull. A hit on one angers the other (+40 % speed, 3 s, at
## most one angry); Crossfire: the violet fires a fan whose gap faces away from the amber Warden; the Sword Lane: the
## line tracks, locks and cuts, at most 9 m long. Phases at 66.7 % and 33.3 % on both bodies at once, determinism, a
## mid-fight save, the death lines. The roles: test_twin_wardens_roles.gd (a hit on the body standing back does
## nothing, so these tests hit the leader); the new attacks, the wards and the set piece: test_twins_apart.gd.

const S := EnemyAi.State
const LONG := 1 << 20


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
	w.actors.set_pos(0, player_at)
	var i := BossLab.ready_boss(w, &"twin_wardens", boss_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i], w.actors.ids[BossTwin.partner_of(w, i)]]


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## The bosses pick nothing on their own (no phase list, no punish, no gap-closer).
func _hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, _i(w, aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0


## Hushed and standing still (both bodies share the table: speed 0).
func _still(w: World, aid: int) -> void:
	_hush(w, aid)
	BossAi.table_of(w, _i(w, aid)).speed = 0.0


func _hit(w: World, target_id: int, amount: int) -> int:
	var me := w.actors.ids[0]
	var i := _i(w, target_id)
	return Damage.hit(
		w, i, amount, me, me, w.take_root(), 0, w.actors.pos(i) + Vector2(-1, 0), w.actors.pos(i)
	)


func _gap(w: World, s: Array) -> float:
	return w.actors.pos(_i(w, s[1])).distance_to(w.actors.pos(_i(w, s[2])))


## Drops the pair onto phase `phase`'s gate (its HP at that threshold), then steps through the gate.
func _to_phase(w: World, boss_id: int, phase: int) -> void:
	var i := _i(w, boss_id)
	var hp := BossAi.table_of(w, i).phase_threshold[phase] * w.actors.max_hp[i] / 1000
	w.actors.hp[i] = hp
	w.actors.hp[BossTwin.partner_of(w, i)] = hp
	w.step(InputFrame.new())
	BossLab.through_gate(w, boss_id)


func test_the_data_is_the_approved_row() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"twin_wardens")
	assert_not_null(def)
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_eq(t.kind, ActorStore.Kind.TWIN_WARDEN)
	assert_eq(t.twin_kind, ActorStore.Kind.TWIN_WARDEN_VIOLET, "two bodies")
	assert_eq([t.anger_permille, t.anger_ticks], [1400, 180], "angry +40 % for 3 s")
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 667, 333]), "three full bars")
	var cross := t.attacks[t.attack_index(&"crossfire")]
	assert_eq(cross.move, BossAttackTable.Move.CROSSFIRE)
	assert_false(cross.shielded, "no shield; its caster is the one to hit")
	assert_not_null(cross.pattern)
	assert_eq(cross.twin_look, &"warden_violet_ember", "the twin's embers are violet")
	var sweep := t.attacks[t.attack_index(&"chain_sweep")]
	assert_eq(sweep.move, BossAttackTable.Move.CHAIN_SWEEP)
	assert_eq(sweep.lock_ticks, 48, "tracked, then locked 0.8 s")
	assert_false(sweep.shielded)
	assert_eq(sweep.late_cause_key, &"", "no chain: no burn's death line")
	assert_eq(t.phase_entry[1], t.attack_index(&"crossfire"), "phase 2 opens with Crossfire")
	assert_eq(t.phase_entry[2], t.attack_index(&"crossfire_3"))
	var pool := ContentCompiler.compile_boss_pool(repo, 4)
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	assert_eq(pool.size(), 2, "floor 4 draws the Tidecaller or the Wardens")
	assert_has(Array(pool).map(func(k: int) -> StringName: return ids[k]), &"twin_wardens")
	assert_eq(ids.find(&"twin_wardens"), 7, "after the six and the Tidecaller: saved indices stay")


func test_bad_twin_numbers_are_errors() -> void:
	var repo := ContentRepository.load_all()
	var fresh := func() -> BossDefinition:
		return (repo.get_def(&"bosses", &"twin_wardens") as BossDefinition).duplicate(true)
	var codes := func(d: BossDefinition) -> Array:
		return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	var def: BossDefinition = fresh.call()
	def.twin_distance_m = 0.0
	assert_has(codes.call(def), &"not_positive", "the twin rises a real distance away")
	def = fresh.call()
	def.anger_speed_permille = 900
	assert_has(codes.call(def), &"range", "anger speeds a body up")
	def = fresh.call()
	def.twin_kind_id = &""
	assert_has(codes.call(def), &"attacks", "Crossfire and the Sword Lane need a twin")


func test_two_bodies_share_one_hp_and_one_bar() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	assert_eq(w.actors.kinds[j], ActorStore.Kind.TWIN_WARDEN_VIOLET, "the violet twin")
	assert_true(BossAi.is_boss_kind(w.actors.kinds[j]), "a boss body (immune as a boss)")
	assert_eq(w.bosses.size(), 2, "each runs the boss framework")
	assert_eq(w.boss_id, s[1], "the amber Warden is the boss")
	assert_eq(WorldReader.new(w).boss_index(), i, "the bar shows the boss")
	assert_almost_eq(_gap(w, s), 5.0, 0.01, "risen 5 m apart")
	assert_eq(w.actors.hp[j], w.actors.hp[i])
	assert_eq(w.actors.max_hp[j], w.actors.max_hp[i])
	var hp0 := w.actors.hp[j]
	assert_gt(_hit(w, s[1], 100), 0)
	assert_eq(w.actors.hp[j], w.actors.hp[i], "one HP")
	assert_lt(w.actors.hp[j], hp0, "a hit on the boss is the twin's")
	_to_phase(w, s[1], 1)  # v0.11.0 O5: the violet leads now (the amber stands back)
	i = _i(w, s[1])
	j = _i(w, s[2])
	var hp1 := w.actors.hp[i]
	assert_gt(_hit(w, s[2], 100), 0)
	assert_eq(w.actors.hp[i], w.actors.hp[j], "and the other way")
	assert_lt(w.actors.hp[i], hp1)


func test_they_fall_together_one_defeat_one_reward() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	var shards0 := w.shards
	var kills0 := w.kills
	var seq := 0
	if not w.events_since(0).is_empty():
		seq = w.events_since(0).back().seq
	w.actors.hp[_i(w, s[1])] = 5
	w.actors.hp[_i(w, s[2])] = 5
	BossAi.table_of(w, _i(w, s[1])).phase_threshold = PackedInt32Array([1000])  # no gate in the way
	_hit(w, s[1], 50)  # v0.11.0 O5: the leader (a hit on the one standing back does nothing)
	assert_true(w.actors.dead[_i(w, s[1])] == 1 and w.actors.dead[_i(w, s[2])] == 1, "both fall")
	w.step(InputFrame.new())
	var defeats := []
	var killed := []
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.BOSS_DEFEATED:
			defeats.append(e.target_id)
		if e.kind == SimEvent.Kind.KILL:
			killed.append(e.target_id)
	assert_eq(defeats, [s[1]], "one defeat, the boss's")
	assert_has(killed, s[1])
	assert_has(killed, s[2], "the twin's own KILL (its death in the views)")
	assert_false(w.boss_alive(), "the door opens")
	assert_eq(w.bosses.size(), 0)
	assert_true(w.bosses.twin_lead.is_empty(), "the pair is gone")
	assert_eq(w.kills - kills0, 1, "one kill")
	assert_eq(
		w.shards - shards0, Rewards.shards_for_kill(w, ActorStore.Kind.TWIN_WARDEN), "one reward"
	)


func test_the_phases_turn_on_both_at_once() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	var i := _i(w, s[1])
	w.actors.hp[i] = w.actors.max_hp[i] * 670 / 1000
	w.actors.hp[_i(w, s[2])] = w.actors.hp[i]
	_hit(w, s[1], w.actors.max_hp[i] * 20 / 1000)
	w.step(InputFrame.new())
	assert_eq(w.actors.state[_i(w, s[1])], BossAi.GATE, "the boss's gate")
	assert_eq(w.actors.state[_i(w, s[2])], BossAi.GATE, "the twin's, the same tick")
	BossLab.through_gate(w, s[1])
	CombatLab.idle(w, 2)
	for aid in [s[1], s[2]]:
		var b := BossAi.entry_of(w, _i(w, aid))
		assert_eq(w.bosses.phase[b], 1)
	# v0.11.0 O5: phase 2 is the violet's: it opens with Crossfire, the amber stands back
	assert_eq(BossAi.attack_of(w, _i(w, s[2])).id, &"crossfire", "phase 2 opens with Crossfire")
	assert_null(BossAi.attack_of(w, _i(w, s[1])), "the amber stands back")


func test_nothing_joins_the_two_bodies() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	_still(w, s[1])
	# Far apart and close together: nothing draws the twin in or pushes it out
	w.actors.set_pos(_i(w, s[1]), Vector2(-9, 6))
	w.actors.set_pos(_i(w, s[2]), Vector2(9, -6))
	CombatLab.idle(w, 30)
	assert_almost_eq(_gap(w, s), Vector2(18, -12).length(), 0.01, "21 m apart, and it stays")
	w.actors.set_pos(_i(w, s[1]), Vector2(-3, 0))
	w.actors.set_pos(_i(w, s[2]), Vector2(3, 0))
	# Standing on the line between them costs nothing
	var hp := w.actors.hp[0]
	w.actors.invuln[0] = 0
	for k in 120:
		w.actors.set_pos(0, Vector2(0, 0.2))
		w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], hp, "no chain burns between them")
	var tw := WorldReader.new(w).boss_twin(_i(w, s[1]))
	for key: String in ["chain", "hot", "lifted", "burned"]:
		assert_false(tw.has(key), "the reader has no %s" % key)
	var names := []
	for p: Dictionary in w.bosses.get_property_list():
		names.append(String(p["name"]))
	for p: Dictionary in BossAi.table_of(w, _i(w, s[1])).get_property_list():
		names.append(String(p["name"]))
	for n: String in names:
		assert_false(n.begins_with("chain_") or n == "twin_burn_cd", "no chain state: %s" % n)


func test_a_hit_on_one_angers_the_other_one_at_a_time() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	_hush(w, s[1])
	_to_phase(w, s[1], 1)  # phase 3, and no ward on the violet one: both can be hit
	_to_phase(w, s[1], 2)
	BossAi.table_of(w, _i(w, s[1])).wardens.ward_phase = 9
	for b in w.bosses.twin_anger_t.size():
		w.bosses.twin_anger_t[b] = 0
		w.bosses.twin_angry[b] = 0
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	assert_false(BossTwin.angry(w, i) or BossTwin.angry(w, j), "calm at first")
	_hit(w, s[1], 10)
	assert_true(BossTwin.angry(w, j), "hit the boss: the twin is angry")
	assert_false(BossTwin.angry(w, i))
	_hit(w, s[2], 10)
	assert_true(BossTwin.angry(w, i), "hit the twin: the boss is angry")
	assert_false(BossTwin.angry(w, j), "at most one angry")
	CombatLab.idle(w, 179)
	assert_true(BossTwin.angry(w, _i(w, s[1])), "for 3 s")
	CombatLab.idle(w, 1)
	assert_false(BossTwin.angry(w, _i(w, s[1])), "then calm")
	# +40 % speed: the twin walking to its flank, calm then angry.
	var t := BossAi.table_of(w, i)
	var steps := []
	for mad in [false, true]:
		var s2 := _fight(Vector2(-8, 0))
		var w2: World = s2[0]
		_hush(w2, s2[1])
		w2.actors.set_pos(_i(w2, s2[2]), Vector2(0, 8.5))
		if mad:
			_hit(w2, s2[1], 10)
		var from := w2.actors.pos(_i(w2, s2[2]))
		w2.step(InputFrame.new())
		steps.append(from.distance_to(w2.actors.pos(_i(w2, s2[2]))))
	assert_almost_eq(steps[0], t.speed, 0.0005, "its own pace")
	assert_almost_eq(steps[1] / steps[0], 1.4, 0.01, "+40 % angry")


## Crossfire is the violet Warden's (phase 2 on): its fan flies at the player and its gap faces directly away from the
## amber Warden, through the safe spot on the far side of her from him; he stands back and fires none.
func test_crossfire_s_gap_faces_away_from_the_other_warden() -> void:
	var run := func(at: Vector2, steps: int) -> Array:
		var s2 := _fight(Vector2(6, -4))
		var w2: World = s2[0]
		_to_phase(w2, s2[1], 1)
		_still(w2, s2[1])
		BossAi.table_of(w2, _i(w2, s2[1])).twin_bolt = -1  # no bolt from the amber meanwhile
		w2.actors.set_pos(_i(w2, s2[1]), Vector2(-3, 0))
		w2.actors.set_pos(_i(w2, s2[2]), Vector2(3, 0))
		w2.actors.set_pos(0, Vector2(6, -4))
		w2.step(InputFrame.new())
		BossLab.start(w2, _i(w2, s2[2]), &"crossfire")
		var safe := w2.bosses.pt(BossAi.entry_of(w2, _i(w2, s2[2])), 0)
		var hp := w2.actors.hp[0]
		for k in steps:
			w2.actors.set_pos(0, safe if at == Vector2.INF else at)
			w2.step(InputFrame.new())
		return [w2, s2, safe, hp - w2.actors.hp[0]]
	var r: Array = run.call(Vector2.INF, 1)
	var w: World = r[0]
	var s: Array = r[1]
	var safe: Vector2 = r[2]
	assert_null(BossAi.attack_of(w, _i(w, s[1])), "the amber fires none")
	assert_false(BossDodge.shielded(w, _i(w, s[2])), "not shielded")
	# The hero stood 5 m from her: the spot is 5 m out on the far side from the amber Warden (straight along +x)
	assert_almost_eq(safe, Vector2(8, 0), Vector2(0.001, 0.001), "on the far side of her from him")
	assert_eq(run.call(Vector2.INF, 360)[3], 0, "on the safe spot no shot lands")
	assert_gt(run.call(Vector2(6, -4), 360)[3], 0, "off it the fan finds you")
	CombatLab.until(w, func(x: World) -> bool: return x.projectiles.size() > 5, 200)
	assert_gt(w.projectiles.size(), 5, "the fan flies")
	for k in w.projectiles.size():
		assert_eq(w.projectiles.owner[k], s[2], "the violet's shots")
		assert_eq(w.projectiles.look[k], "warden_violet_ember", "in its colour")
		var heading := Kin.angle_of(Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k]))
		var to_safe := Kin.angle_of(safe - w.actors.pos(_i(w, s[2])))
		assert_gt(Kin.angle_diff(heading, to_safe), 0, "no shot down the gap")


func test_the_sword_lane_tracks_locks_and_cuts() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	_hush(w, s[1])
	w.actors.set_pos(_i(w, s[2]), Vector2(-3, 4))
	BossLab.start(w, _i(w, s[1]), &"chain_sweep")
	var i := _i(w, s[1])
	var atk := BossAi.attack_of(w, i)
	assert_false(BossDodge.shielded(w, i), "not shielded")
	w.actors.set_pos(0, Vector2(-4, -3))
	w.step(InputFrame.new())
	var to := Vector2(-4, -3) - w.actors.pos(i)
	assert_lte(
		Kin.angle_diff(w.actors.lock_a[i], Kin.angle_of(to)), 2, "the line follows the player"
	)
	var len := w.actors.lock_len[i]
	assert_almost_eq(len, to.length() + 2.5, 0.05, "through them and 2.5 m on")
	CombatLab.until(
		w,
		func(x: World) -> bool: return x.actors.state_t[i] >= atk.windup_ticks - atk.lock_ticks,
		200
	)
	var locked := w.actors.lock_a[i]
	var tel := BossAi.telegraph(w, i)
	assert_eq(tel.get("shape"), &"lane")
	assert_true(tel.get("locked", false), "locked and flashing")
	assert_eq(BossAi.telegraph(w, _i(w, s[2])), {}, "one lane, the boss's")
	w.actors.set_pos(0, Vector2(4, 3))
	w.step(InputFrame.new())
	assert_eq(w.actors.lock_a[i], locked, "it holds once locked")
	# Back onto the locked line for the strike.
	var on := Vector2(-4, -3)
	var hp := w.actors.hp[0]
	CombatLab.until(
		w,
		func(x: World) -> bool:
			x.actors.set_pos(0, on)
			return x.actors.state[i] == S.RECOVER,
		200
	)
	assert_eq(hp - w.actors.hp[0], BossAi.powered(w, i, atk.damage), "the sword lands on the line")
	assert_null(BossAi.attack_of(w, _i(w, s[2])), "the amber's alone (the twin copies nothing)")


func test_the_sword_lane_is_at_most_9_m_long_wherever_the_twin_stands() -> void:
	for twin_at: Vector2 in [Vector2(2, 3), Vector2(9, -9)]:
		var s := _fight(Vector2(-11, 0), Vector2(8, 0))
		var w: World = s[0]
		_still(w, s[1])
		w.actors.set_pos(_i(w, s[2]), twin_at)
		BossLab.start(w, _i(w, s[1]), &"chain_sweep")
		w.step(InputFrame.new())
		assert_almost_eq(
			w.actors.lock_len[_i(w, s[1])], 9.0, 0.001, "19 m to the hero: 9 m of lane"
		)


func test_the_sword_lane_misses_off_the_line() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	_still(w, s[1])
	BossLab.start(w, _i(w, s[1]), &"chain_sweep")
	var i := _i(w, s[1])
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[i] == S.ACTIVE, 200)
	var hp := w.actors.hp[0]
	w.actors.set_pos(0, Vector2(-5, 3))
	CombatLab.idle(w, 3)
	assert_eq(w.actors.hp[0], hp, "dodged off the line")


func test_deterministic_and_a_mid_fight_save_restores() -> void:
	var make := func() -> World:
		var s := _fight(Vector2(-7, 2), Vector2.ZERO, 10.0)
		var w: World = s[0]
		CombatLab.idle(w, 240)
		_hit(w, s[1], 5)  # the twin angry: the pair's state is live
		return w
	var a: World = make.call()
	var b: World = make.call()
	for k in 120:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree mid-fight")
	assert_false(a.bosses.twin_lead.is_empty(), "the pair is in the state")
	var before := a.state_hash()
	a.bosses.twin_anger_t[0] += 1
	assert_ne(a.state_hash(), before, "and in the hash")
	a.bosses.twin_anger_t[0] -= 1
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), make.call())
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	assert_eq(restored.bosses.twin_lead, a.bosses.twin_lead)
	for k in 360:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		a.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 360 ticks on")


func test_the_death_lines_name_the_wardens() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var t := BossAi.table_of(w, _i(w, s[1]))
	w.killer_kind = ActorStore.Kind.TWIN_WARDEN_VIOLET
	w.killer_attack = t.attack_index(&"crossfire")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_CROSSFIRE", "the twin's shots name the pair")
	w.killer_attack = BossWard.MIRROR_CAUSE
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_MIRROR", "the hero's own shot, sent back")
	w.killer_attack = BossHazard.ATTACK
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_RIFT", "a sword's rift")
	w.killer_kind = ActorStore.Kind.TWIN_WARDEN
	w.killer_attack = t.attack_index(&"chain_sweep")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_SWEEP")
	for id: StringName in [&"warden_charge", &"warden_charge_long"]:
		w.killer_attack = t.attack_index(id)
		assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_CHARGE", "%s and its burst" % id)
	w.killer_attack = t.attack_index(&"rift_charge")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_RIFT_CHARGE", "the charge out of the rift")
	var en := TranslationServer.get_translation_object("en")
	assert_eq(String(en.get_message(&"BOSS_TWIN_WARDENS")), "The Twin Wardens")
