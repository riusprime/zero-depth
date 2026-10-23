# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 NB2 (owner Q24 "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N2): The Twin Wardens, floor 4's
## second boss. Two bodies (two linked actors, BossTwin), one shared HP, one bar, one defeat; a chain between them held
## between 3 m and 9 m that burns 12 every 0.5 s on touch (never while dashing, never against a wall, not solid); a hit
## on one angers the other (+40 % speed, 3 s, at most one angry); Crossfire (shielded): each fires a fan whose gap
## crosses the other's only at the safe spot between them; Chain Sweep: the line tracks, locks and lashes. Phases at
## 66 % and 33 % on both bodies at once, determinism, a mid-fight save, an older save, the death lines.

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


func _chain_len(w: World, s: Array) -> float:
	return w.actors.pos(_i(w, s[1])).distance_to(w.actors.pos(_i(w, s[2])))


func test_the_data_is_the_approved_row() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"twin_wardens")
	assert_not_null(def)
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_eq(t.kind, ActorStore.Kind.TWIN_WARDEN)
	assert_eq(t.twin_kind, ActorStore.Kind.TWIN_WARDEN_VIOLET, "two bodies")
	assert_eq([t.chain_min_m, t.chain_max_m], [3.0, 9.0], "the chain 3..9 m")
	assert_eq([t.chain_burn, t.chain_burn_ticks], [12, 30], "12 a tick at 0.5 s")
	assert_eq([t.anger_permille, t.anger_ticks], [1400, 180], "angry +40 % for 3 s")
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]), "phases at 66 % and 33 %")
	var cross := t.attacks[t.attack_index(&"crossfire")]
	assert_eq(cross.move, BossAttackTable.Move.CROSSFIRE)
	assert_true(cross.shielded, "shielded during the signature pattern")
	assert_not_null(cross.pattern)
	assert_eq(cross.twin_look, &"warden_violet_ember", "the twin's embers are violet")
	var sweep := t.attacks[t.attack_index(&"chain_sweep")]
	assert_eq(sweep.move, BossAttackTable.Move.CHAIN_SWEEP)
	assert_eq(sweep.lock_ticks, 48, "tracked, then locked 0.8 s")
	assert_false(sweep.shielded)
	assert_eq(sweep.late_cause_key, &"CAUSE_TWIN_CHAIN", "the burn's death line")
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
	def.chain_max_m = 10.0
	assert_has(codes.call(def), &"range", "never longer than 9 m")
	def = fresh.call()
	def.chain_min_m = 2.0
	assert_has(codes.call(def), &"range", "never shorter than 3 m")
	def = fresh.call()
	def.anger_speed_permille = 900
	assert_has(codes.call(def), &"range", "anger speeds a body up")
	def = fresh.call()
	def.attack(&"crossfire").shielded = false
	assert_has(codes.call(def), &"missing", "Crossfire is shielded")
	def = fresh.call()
	def.attack(&"chain_sweep").late_cause_key = &""
	def.attack(&"chain_sweep_fast").late_cause_key = &""
	assert_has(codes.call(def), &"missing", "the burn needs its death line")
	def = fresh.call()
	def.twin_kind_id = &""
	assert_has(codes.call(def), &"attacks", "Crossfire and Chain Sweep need a twin")


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
	assert_between(_chain_len(w, s), 3.0, 9.0, "risen within the chain's lengths")
	assert_eq(w.actors.hp[j], w.actors.hp[i])
	assert_eq(w.actors.max_hp[j], w.actors.max_hp[i])
	var hp0 := w.actors.hp[i]
	assert_gt(_hit(w, s[2], 100), 0)
	assert_eq(w.actors.hp[i], w.actors.hp[j], "one HP")
	assert_lt(w.actors.hp[i], hp0, "a hit on the twin is the boss's")
	var hp1 := w.actors.hp[i]
	assert_gt(_hit(w, s[1], 100), 0)
	assert_eq(w.actors.hp[j], w.actors.hp[i], "and the other way")
	assert_lt(w.actors.hp[j], hp1)


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
	_hit(w, s[2], 50)
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
	_hit(w, s[2], w.actors.max_hp[i] * 20 / 1000)
	w.step(InputFrame.new())
	assert_eq(w.actors.state[_i(w, s[1])], BossAi.GATE, "the boss's gate")
	assert_eq(w.actors.state[_i(w, s[2])], BossAi.GATE, "the twin's, the same tick")
	BossLab.through_gate(w, s[1])
	CombatLab.idle(w, 2)
	for aid in [s[1], s[2]]:
		var b := BossAi.entry_of(w, _i(w, aid))
		assert_eq(w.bosses.phase[b], 1)
		assert_eq(BossAi.attack_of(w, _i(w, aid)).id, &"crossfire", "phase 2 opens with Crossfire")


func test_the_chain_stays_3_to_9_m() -> void:
	for room in [0.0, 9.0]:
		var s := _fight(Vector2(-6, 3), Vector2.ZERO, room)
		var w: World = s[0]
		var lo := 99.0
		var hi := 0.0
		for k in 60 * 40:
			var f := InputFrame.new()
			if k % 240 < 120:
				f = InputFrame.make(Vector2i(70, -40 if k % 480 < 240 else 40), 0, 300, 0, 0)
			w.step(f)
			if w.actors.index_of(s[2]) < 0:
				break
			lo = minf(lo, _chain_len(w, s))
			hi = maxf(hi, _chain_len(w, s))
		assert_gte(lo, 3.0 - 0.01, "never shorter than 3 m (room %s)" % room)
		assert_lte(hi, 9.0 + 0.01, "never longer than 9 m (room %s)" % room)
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	w.actors.set_pos(_i(w, s[2]), Vector2(20, 0))
	w.step(InputFrame.new())
	assert_almost_eq(_chain_len(w, s), 9.0, 0.05, "drawn in to 9 m")
	w.actors.set_pos(_i(w, s[2]), Vector2(0.5, 0))
	w.step(InputFrame.new())
	assert_almost_eq(_chain_len(w, s), 3.0, 0.05, "pushed out to 3 m")


func test_the_chain_burns_12_every_half_second_on_touch() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	_still(w, s[1])
	w.actors.set_pos(_i(w, s[1]), Vector2(-3, 0))
	w.actors.set_pos(_i(w, s[2]), Vector2(3, 0))
	var on := Vector2(0, 0.3)
	w.actors.set_pos(0, on)
	w.actors.invuln[0] = 0
	var hp := w.actors.hp[0]
	var burns := PackedInt32Array()
	# Every 0.5 s of fight: the hurt's hit-stop (hurt_freeze_ticks) holds the fight's clocks, the chain's too.
	var period := 30 + w.player.hurt_freeze_ticks
	for k in 2 * period + 1:
		w.actors.set_pos(0, on)
		w.step(InputFrame.new())
		if w.actors.hp[0] < hp:
			burns.append(w.tick)
			assert_eq(hp - w.actors.hp[0], 12, "12 a burn")
			hp = w.actors.hp[0]
	assert_eq(burns.size(), 3, "at once, then twice more: %s" % burns)
	if burns.size() >= 3:
		assert_eq(burns[1] - burns[0], period, "every 0.5 s (plus the hit-stop)")
		assert_eq(burns[2] - burns[1], period)
	assert_almost_eq(w.player_pos().y, on.y, 0.001, "not solid: it never pushes")
	# Clear of the chain: nothing.
	w.actors.set_pos(0, Vector2(0, 2.0))
	hp = w.actors.hp[0]
	CombatLab.idle(w, 60)
	assert_eq(w.actors.hp[0], hp, "off the chain")


func test_the_chain_spares_a_dash_a_wall_and_a_rise() -> void:
	var s := _fight(Vector2(-8, 0), Vector2.ZERO, 6.0)
	var w: World = s[0]
	_still(w, s[1])
	# Along the wall's foot: the chain runs by the bottom wall (y = -6), the player against it.
	w.actors.set_pos(_i(w, s[1]), Vector2(-3, -5.2))
	w.actors.set_pos(_i(w, s[2]), Vector2(3, -5.2))
	var hp := w.actors.hp[0]
	for k in 60:
		w.actors.set_pos(0, Vector2(0, -5.55))
		w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], hp, "never pinned against a wall")
	w.actors.set_pos(_i(w, s[1]), Vector2(-3, 0))
	w.actors.set_pos(_i(w, s[2]), Vector2(3, 0))
	for k in 30:
		w.actors.set_pos(0, Vector2(0, 0.2))
		w.dash_ticks_left = 5
		w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], hp, "a dash crosses it")
	w.dash_ticks_left = 0
	w.actors.state[_i(w, s[2])] = S.SPAWN
	w.actors.state_t[_i(w, s[2])] = 0
	w.actors.set_pos(0, Vector2(0, 0.2))
	w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], hp, "not while a body rises")


func test_a_hit_on_one_angers_the_other_one_at_a_time() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	_hush(w, s[1])
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


func test_crossfire_gaps_meet_only_between_them() -> void:
	var s := _fight(Vector2(0, -5))
	var w: World = s[0]
	_still(w, s[1])
	w.actors.set_pos(_i(w, s[1]), Vector2(-3, 0))
	w.actors.set_pos(_i(w, s[2]), Vector2(3, 0))
	w.step(InputFrame.new())
	BossLab.start(w, _i(w, s[1]), &"crossfire")
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	assert_eq(BossAi.attack_of(w, j).id, &"crossfire", "the twin fires it too")
	assert_true(BossDodge.shielded(w, i) and BossDodge.shielded(w, j), "both shielded")
	var safe := w.bosses.pt(BossAi.entry_of(w, i), 0)
	assert_eq(w.bosses.pt(BossAi.entry_of(w, j), 0), safe, "one safe spot")
	assert_almost_eq(
		safe, Vector2(0, -2), Vector2(0.001, 0.001), "2 m off the chain, the player's side"
	)
	# Standing on the spot: no shot lands; one step aside: hit.
	var hurt := func(at: Vector2) -> int:
		var s2 := _fight(Vector2(0, -5))
		var w2: World = s2[0]
		_still(w2, s2[1])
		w2.actors.set_pos(_i(w2, s2[1]), Vector2(-3, 0))
		w2.actors.set_pos(_i(w2, s2[2]), Vector2(3, 0))
		w2.step(InputFrame.new())
		BossLab.start(w2, _i(w2, s2[1]), &"crossfire")
		var hp := w2.actors.hp[0]
		for k in 360:
			w2.actors.set_pos(0, at)
			w2.step(InputFrame.new())
		return hp - w2.actors.hp[0]
	assert_eq(hurt.call(safe), 0, "the gaps cross at the safe spot")
	assert_gt(hurt.call(safe + Vector2(2.2, -1.0)), 0, "off it, a fan finds you")
	assert_gt(hurt.call(Vector2(0, -6)), 0, "behind it too")
	# The twin's embers are violet, the boss's amber; each fan leaves its gap toward the spot.
	CombatLab.until(w, func(x: World) -> bool: return x.projectiles.size() > 10, 200)
	var seen := {}
	for k in w.projectiles.size():
		var owner := w.projectiles.owner[k]
		var look := w.projectiles.look[k] if k < w.projectiles.look.size() else ""
		seen[owner] = look
		var body := _i(w, owner)
		var heading := Kin.angle_of(Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k]))
		var to_safe := Kin.angle_of(safe - w.actors.pos(body))
		assert_gt(Kin.angle_diff(heading, to_safe), 0, "no shot down the gap")
	assert_eq(seen.get(s[1], ""), "warden_amber_ember")
	assert_eq(seen.get(s[2], ""), "warden_violet_ember")


func test_the_chain_sweep_tracks_locks_and_lashes() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	_hush(w, s[1])
	w.actors.set_pos(_i(w, s[2]), Vector2(-3, 4))
	BossLab.start(w, _i(w, s[1]), &"chain_sweep")
	var i := _i(w, s[1])
	var atk := BossAi.attack_of(w, i)
	assert_false(BossDodge.shielded(w, i), "not shielded")
	assert_true(BossTwin.lifted(w, i), "the sweep has the chain: no burn")
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
	assert_eq(hp - w.actors.hp[0], BossAi.powered(w, i, atk.damage), "the lash lands on the line")
	var end := BossTwin.sweep_end(w, i)
	assert_lt(w.actors.pos(_i(w, s[2])).distance_to(end), 1.5, "the twin swung to the line's end")


func test_the_chain_sweep_misses_off_the_line() -> void:
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


func test_the_twin_never_picks_it_follows() -> void:
	var s := _fight(Vector2(-6, 2), Vector2.ZERO, 10.0)
	var w: World = s[0]
	var last := {s[1]: -1, s[2]: -1}
	var starts := {s[1]: [], s[2]: []}
	for k in 60 * 40:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		w.step(f)
		if _i(w, s[1]) < 0 or _i(w, s[2]) < 0:
			break
		for aid in [s[1], s[2]]:
			var b := BossAi.entry_of(w, _i(w, aid))
			var now := w.bosses.attack[b]
			if now >= 0 and now != last[aid]:
				starts[aid].append([w.tick, now])
			last[aid] = now
	assert_gte(starts[s[2]].size(), 4, "the twin attacked")
	for st: Array in starts[s[2]]:
		assert_has(starts[s[1]], st, "each twin attack began with its boss's, the same tick")


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


func test_an_older_snapshot_without_the_pair_loads() -> void:
	var w := BossLab.world()
	BossLab.ready_boss(w, &"tidecaller")
	var snap := WorldSnapshot.take(w)
	var bosses: Dictionary = snap["world"][&"bosses"]
	assert_true(bosses.has(&"twin_lead"), "the pair is saved")
	for f in BossStore.TWIN_FIELDS:
		bosses.erase(f)
	var base := BossLab.world()
	BossLab.ready_boss(base, &"tidecaller")
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save from before NB2 loads")
	assert_true(base.bosses.twin_lead.is_empty(), "with no pair")


func test_the_death_lines_name_the_wardens() -> void:
	var s := _fight(Vector2(-7, 0))
	var w: World = s[0]
	var t := BossAi.table_of(w, _i(w, s[1]))
	w.killer_kind = ActorStore.Kind.TWIN_WARDEN_VIOLET
	w.killer_attack = t.attack_index(&"crossfire")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_CROSSFIRE", "the twin's shots name the pair")
	w.killer_kind = ActorStore.Kind.TWIN_WARDEN
	w.killer_attack = BossSignatures.LATE_CAUSE + BossTwin.sweep_index(t)
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_CHAIN", "the chain's burn")
	w.killer_attack = t.attack_index(&"chain_sweep")
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_SWEEP")
	var en := TranslationServer.get_translation_object("en")
	var es := TranslationServer.get_translation_object("es")
	assert_eq(
		String(en.get_message(&"CAUSE_TWIN_CHAIN")), "The Twin Wardens' burning chain seared you."
	)
	assert_eq(
		String(es.get_message(&"CAUSE_TWIN_CHAIN")),
		"La cadena ardiente de The Twin Wardens te abrasó."
	)
	assert_eq(String(en.get_message(&"BOSS_TWIN_WARDENS")), "The Twin Wardens")


func test_a_chain_burn_that_kills_names_the_chain() -> void:
	var s := _fight(Vector2(-8, 0))
	var w: World = s[0]
	_still(w, s[1])
	w.actors.set_pos(_i(w, s[1]), Vector2(-3, 0))
	w.actors.set_pos(_i(w, s[2]), Vector2(3, 0))
	w.actors.hp[0] = 5
	w.actors.invuln[0] = 0
	for k in 5:
		w.actors.set_pos(0, Vector2(0, 0.2))
		w.step(InputFrame.new())
	assert_true(w.player_dead())
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_CHAIN")
