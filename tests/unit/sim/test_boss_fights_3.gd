extends GutTest
## v0.7.5 BF3 (owner N15; BOSS_FIGHTS.md "Each boss"): the Siege Engine's and the Foundry's dodge-first fights. Their
## phase scripts and HP; the shielded signatures (the Turret Cross, the Slag Fountain); the Mortar Grid (a tracked
## checkerboard struck in alternating colours, with a safe square each time); the Barrage (three circles in turn) and
## the Rail (a tracked lane), each tracked then locked; the Molten Flood's rows (tracked, locked, a gap between
## them); the Slag Fountain's rain (drops land in a flower, never on the player, and hurt only once landed); the
## Furnace Waves' alternating rings with shifting gaps; their fireball looks; determinism.

const S := EnemyAi.State
const LONG := 1 << 20


func _fight(id: StringName, player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _ppos(w: World, k: int) -> Vector2:
	return Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])


func _pvel(w: World, k: int) -> Vector2:
	return Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])


func _ids(t: BossTable, k: int) -> Array:
	return Array(t.phase_attacks[k]).map(func(a: int) -> StringName: return t.attacks[a].id)


func _hurt(w: World, seq: int) -> bool:
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0] and e.amount > 0:
			return true
	return false


## Steps one tick with the player held at `at`; true when the boss hurt the player that tick.
func _step_at(w: World, at: Vector2) -> bool:
	w.actors.set_pos(0, at)
	var seq := w.last_event_seq()
	w.step(InputFrame.new())
	return _hurt(w, seq)


func test_the_siege_engines_phase_script() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"siege_engine")]
	assert_eq(t.hp, 2250, "1800 x 1.25")
	assert_eq(_ids(t, 0), [&"turret_cross", &"mortar_grid", &"barrage", &"rail"])
	assert_eq(_ids(t, 1), [&"turret_cross_fast", &"mortar_grid", &"barrage", &"rail"])
	assert_eq(
		_ids(t, 2),
		[&"turret_cross_reversing", &"mortar_grid_3", &"barrage_fast", &"rail_3", &"shockwave"]
	)
	assert_eq(t.attacks[t.phase_entry[1]].id, &"deploy", "phase 2 still deploys its turrets")
	assert_eq(t.attacks[t.phase_entry[2]].id, &"turret_cross_reversing")
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]), "the 66 / 33 % gates")
	var cross := t.attacks[t.attack_index(&"turret_cross")]
	assert_true(cross.shielded, "the Turret Cross is the shielded signature")
	assert_eq(cross.pattern.kind, BulletPatternTable.Kind.CROSS)
	assert_eq(cross.pattern.arms, 4, "a 4-arm cross")
	assert_eq(cross.pattern.look, &"cannon_ember")
	var fast := t.attacks[t.attack_index(&"turret_cross_fast")].pattern
	assert_gt(absi(fast.spin_milli), absi(cross.pattern.spin_milli), "phase 2 turns faster")
	assert_gt(fast.waves, cross.pattern.waves)
	var rev := t.attacks[t.attack_index(&"turret_cross_reversing")].pattern
	assert_gt(rev.reverse_ticks, 0, "phase 3's cross turns back halfway")
	assert_eq(rev.arms, 4)
	assert_eq(t.attacks[t.attack_index(&"mortar_grid")].volleys, 2, "alternating twice")
	assert_eq(t.attacks[t.attack_index(&"mortar_grid_3")].volleys, 3, "phase 3: once more")
	assert_eq(t.attacks[t.attack_index(&"barrage")].count, 3, "three circles in turn")
	assert_eq(t.attacks[t.attack_index(&"rail_3")].count, 3)
	for a in t.attacks:
		if (
			a.move
			in [BossAttackTable.Move.GRID, BossAttackTable.Move.MARKS, BossAttackTable.Move.LANES]
		):
			assert_eq(a.lock_ticks, 48, "%s locks for 0.8 s" % a.id)
	assert_eq(t.attacks[t.attack_index(&"shockwave")].radius_m, 50.0, "BF1's 50 m outer edge")
	assert_eq(t.radius_m, 1.8, "BF1's body (N18)")
	assert_eq(t.attacks[t.gap_attack].id, &"barrage", "a gap-closer: the tracked barrage")


func test_the_foundrys_phase_script() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"foundry")]
	assert_eq(t.hp, 2375, "1900 x 1.25")
	assert_eq(
		_ids(t, 0),
		[&"slag_fountain", &"furnace_waves", &"molten_flood", &"vent_blast", &"bomb_launch"]
	)
	assert_eq(
		_ids(t, 1),
		[&"slag_fountain_2", &"furnace_waves", &"molten_flood_5", &"vent_blast", &"bomb_launch_3"]
	)
	assert_eq(
		_ids(t, 2),
		[
			&"slag_fountain_2",
			&"furnace_waves_fast",
			&"molten_flood_5",
			&"vent_blast",
			&"bomb_launch_3",
			&"firestorm"
		]
	)
	assert_eq(t.attacks[t.phase_entry[1]].id, &"slag_fountain_2")
	assert_eq(t.attacks[t.phase_entry[2]].id, &"furnace_waves_fast")
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]))
	var fountain := t.attacks[t.attack_index(&"slag_fountain")]
	assert_true(fountain.shielded, "the Slag Fountain is the shielded signature (door shut)")
	assert_eq(fountain.pattern.kind, BulletPatternTable.Kind.FLOWER)
	assert_gt(fountain.pattern.rain_ticks, 0, "it rains")
	assert_eq(fountain.pattern.look, &"molten_drop")
	assert_gt(t.attacks[t.attack_index(&"slag_fountain_2")].pattern.waves, fountain.pattern.waves)
	var waves := t.attacks[t.attack_index(&"furnace_waves")].pattern
	var waves_fast := t.attacks[t.attack_index(&"furnace_waves_fast")].pattern
	assert_gt(waves_fast.waves, waves.waves, "phase 3 adds rings")
	assert_gt(waves_fast.speed, waves.speed, "and speeds them up")
	assert_eq(t.attacks[t.attack_index(&"molten_flood")].count, 3)
	assert_eq(t.attacks[t.attack_index(&"molten_flood_5")].count, 5, "phase 2: five rows")
	for id: StringName in [&"molten_flood", &"molten_flood_5", &"firestorm"]:
		assert_eq(t.attacks[t.attack_index(id)].lock_ticks, 48, "%s locks for 0.8 s" % id)
	var launch := t.attacks[t.attack_index(&"bomb_launch")]
	assert_eq(launch.enemy_kind, ActorStore.Kind.BOMB_DRONE, "its Bomb Drones keep launching")
	assert_eq(t.radius_m, 1.95, "BF1's body (N18)")
	assert_eq(t.attacks[t.attack_index(&"vent_blast")].radius_m, 4.65, "BF1's vent ring")


func test_both_signatures_shield_the_boss_and_open_after() -> void:
	for spec in [[&"siege_engine", &"turret_cross"], [&"foundry", &"slag_fountain"]]:
		var s := _fight(spec[0], Vector2(0, 5))
		var w: World = s[0]
		var aid: int = s[1]
		var i := w.actors.index_of(aid)
		var hp := w.actors.hp[i]
		BossLab.start(w, i, spec[1])
		assert_true(WorldReader.new(w).boss_shielded(i), "%s: shielded as it braces" % spec[0])
		CombatLab.idle(w, 70)
		i = w.actors.index_of(aid)
		assert_eq(w.actors.state[i], S.ACTIVE)
		assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)
		assert_eq(w.actors.hp[i], hp, "%s: no damage while shielded" % spec[0])
		CombatLab.until(
			w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
		)
		i = w.actors.index_of(aid)
		assert_false(BossDodge.shielded(w, i), "%s: open between patterns" % spec[0])
		assert_gt(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 0)


func test_the_mortar_grid_tracks_then_locks_on_the_players_square() -> void:
	var s := _fight(&"siege_engine", Vector2(7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"mortar_grid")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var track := atk.windup_ticks - atk.lock_ticks
	var at := Vector2(7, 0)
	var locked := Vector2.INF
	for t in atk.windup_ticks:
		var i := w.actors.index_of(aid)
		var tg := BossAi.telegraph(w, i)
		var c := BossDodge.mark_of(w, i, 0)
		var discs := BossDodge.grid_discs(w, i, 0)
		assert_eq(tg["items"].size(), discs.size(), "tick %d: one colour drawn at a time" % t)
		assert_true(discs.has(c), "the first colour holds the player's square")
		if t < track:
			assert_eq(c, at, "tick %d: the board follows the player" % t)
			assert_false(tg["locked"])
		else:
			if locked == Vector2.INF:
				locked = c
			assert_eq(c, locked, "tick %d: locked" % t)
			assert_true(tg["locked"], "the lock flash")
		at = Vector2(7, 0) + Vector2(0.03, 0.04) * t
		_step_at(w, at)
	assert_ne(locked, Vector2.INF)


func test_the_mortar_grid_alternates_and_each_volley_leaves_safe_squares() -> void:
	var cell := 2.4
	# [where the player stands for volley 0, then for volley 1] (from the board's centre) -> [hit by 0, by 1]
	var cases := [
		[Vector2.ZERO, Vector2.ZERO, [true, false]],  # the centre square: struck first, safe second
		[Vector2(cell, 0), Vector2(cell, 0), [false, true]],  # the next square: safe first, struck second
		[Vector2(cell, 0), Vector2.ZERO, [false, false]],  # step out, then back: never hit
		[Vector2(cell * 0.5, cell * 0.5), Vector2(cell * 0.5, cell * 0.5), [false, false]],  # a corner
	]
	for c in cases:
		var s := _fight(&"siege_engine", Vector2(7, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, w.actors.index_of(aid), &"mortar_grid")
		var atk := BossAi.attack_of(w, w.actors.index_of(aid))
		var centre := Vector2(7, 0)
		var got := [false, false]
		for t in atk.windup_ticks + atk.active_ticks + 2:
			var i := w.actors.index_of(aid)
			if w.actors.state[i] == S.RECOVER:
				break
			var k := 0 if BossDodge.attack_ticks(w, i, atk) <= atk.windup_ticks else 1
			var stand: Vector2 = centre if t < atk.windup_ticks - atk.lock_ticks else centre + c[k]
			if _step_at(w, stand):
				got[k] = true
		assert_eq(got, c[2], "standing %s then %s" % [c[0], c[1]])


func test_the_barrage_tracks_three_circles_in_turn() -> void:
	var s := _fight(&"siege_engine", Vector2(7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"barrage")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var path := func(t: int) -> Vector2: return Vector2(7, 0) + Vector2(0, 0.06) * t
	var locks := []
	for t in atk.windup_ticks + atk.active_ticks:
		var i := w.actors.index_of(aid)
		for k in atk.count:
			var start := k * atk.mark_gap_ticks + atk.windup_ticks - atk.lock_ticks
			if BossAi.attack_of(w, i) != null and BossDodge.attack_ticks(w, i, atk) == start:
				locks.append([k, BossDodge.mark_of(w, i, k), path.call(t)])
		_step_at(w, path.call(t))
	assert_eq(locks.size(), 3, "three circles, each locking in turn")
	for l in locks:
		assert_lt(
			(l[1] as Vector2).distance_to(l[2]),
			0.13,  # where the player stood on its last tracking tick (two of these steps back)
			"circle %d locked on the player %s" % [l[0], l]
		)
	assert_ne(locks[0][1], locks[2][1], "each locked where the player was then")


func test_the_rail_tracks_your_exact_position_then_locks() -> void:
	for stay: bool in [true, false]:
		var s := _fight(&"siege_engine", Vector2(8, 0))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, w.actors.index_of(aid), &"rail")
		var atk := BossAi.attack_of(w, w.actors.index_of(aid))
		var hit := false
		var aim_locked := -1
		for t in atk.windup_ticks + atk.active_ticks + 3:
			var i := w.actors.index_of(aid)
			var tracking := t < atk.windup_ticks - atk.lock_ticks
			var y := 0.04 * mini(t, atk.windup_ticks - atk.lock_ticks)
			var at := Vector2(8, y) if tracking or stay else Vector2(8, y + 2.5)
			if tracking:
				assert_almost_eq(
					w.actors.lock_a[i], Kin.angle_of(w.player_pos() - w.actors.pos(i)), 3, "exact"
				)
			elif aim_locked < 0:
				aim_locked = w.actors.lock_a[i]
			else:
				assert_eq(w.actors.lock_a[i], aim_locked, "locked")
			if _step_at(w, at):
				hit = true
		assert_eq(hit, stay, "stay=%s: hit iff still on the locked lane" % stay)


func test_the_molten_flood_tracks_your_row_and_leaves_room_between_its_lanes() -> void:
	for spec in [[0.0, true], [1.5, false], [3.0, true]]:  # on the middle lane, between two, on the next
		var s := _fight(&"foundry", Vector2(6, 2))
		var w: World = s[0]
		var aid: int = s[1]
		BossLab.start(w, w.actors.index_of(aid), &"molten_flood")
		var atk := BossAi.attack_of(w, w.actors.index_of(aid))
		var hit := false
		for t in atk.windup_ticks + atk.active_ticks + 2:
			var i := w.actors.index_of(aid)
			if t == atk.windup_ticks - atk.lock_ticks + 1:
				var mid: Obb = BossAi.telegraph(w, i)["obbs"][1]
				assert_almost_eq(mid.center.y, 2.0 + 0.02 * (t - 2), 0.03, "on the player's row")
			var tracking := t < atk.windup_ticks - atk.lock_ticks
			var y := 2.0 + 0.02 * mini(t, atk.windup_ticks - atk.lock_ticks - 1)
			var at: Vector2 = Vector2(6, y) if tracking else Vector2(6, y + spec[0])
			if _step_at(w, at):
				hit = true
		assert_eq(hit, spec[1], "%.1f m off the locked row: hit=%s" % spec)


func test_the_slag_fountain_rains_in_a_flower_and_only_landed_drops_hurt() -> void:
	var s := _fight(&"foundry", Vector2(0, 6))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"slag_fountain")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var pat := atk.pattern
	CombatLab.idle(w, atk.windup_ticks + 1)
	var i := w.actors.index_of(aid)
	var reader := WorldReader.new(w)
	var drops := reader.boss_rain(i)
	assert_gt(drops.size(), 10, "drops in the air")
	assert_eq(w.projectiles.size(), 0, "none has landed: the air holds no shots")
	var body := w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	var far := 0.0
	var near := 99.0
	for d: Array in drops:
		var r := (d[1] as Vector2).distance_to(w.actors.pos(i)) - body
		far = maxf(far, r)
		near = minf(near, r)
	assert_almost_eq(far, pat.rain_m, 0.05, "a petal's tip lands rain_m out")
	assert_lt(near, far * 0.8, "the valleys land nearer: a flower")
	CombatLab.idle(w, pat.rain_ticks)
	assert_gt(w.projectiles.size(), 10, "landed: the first wave's drops roll on as shots")
	for k in w.projectiles.size():
		assert_gt(_ppos(w, k).distance_to(w.player_pos()), pat.safe_radius_m, "none on you")
		assert_eq(w.projectiles.look_of(k), "molten_drop")
		assert_lte(_pvel(w, k).length() * SimTick.TICKS_PER_SECOND, 5.0, "slow")


func test_a_drop_never_lands_on_the_player() -> void:
	var s := _fight(&"foundry", Vector2(0, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	var atk := w.boss_tables[BossLab.table_index(w, &"foundry")].attacks[
		BossAi.table_of(w, i).attack_index(&"slag_fountain")
	]
	# Stand where a petal's tip lands at the windup's lock: those drops are left out.
	var tip := w.actors.pos(i) + Vector2(w.actors.radius[i] + atk.pattern.rain_m + 0.3, 0)
	w.actors.set_pos(0, tip)
	BossLab.start(w, i, &"slag_fountain")
	var hurt := false
	for t in atk.windup_ticks + atk.pattern.rain_ticks + 2:
		if _step_at(w, tip):
			hurt = true
	for k in w.projectiles.size():
		assert_gt(_ppos(w, k).distance_to(tip), atk.pattern.safe_radius_m, "no drop lands on you")
	assert_false(hurt, "nothing hit on landing")


func test_the_furnace_waves_alternate_and_their_gaps_shift() -> void:
	var w := BossLab.world()
	var t := w.boss_tables[BossLab.table_index(w, &"foundry")]
	var p := t.attacks[t.attack_index(&"furnace_waves")].pattern
	var step := 4096 / p.count
	var a0 := BulletPatterns.base_angle(p, 0, 0)
	var a1 := BulletPatterns.base_angle(p, 1, 0)
	var turn := (a1 - a0 + 4096) % 4096
	assert_almost_eq(
		turn % step, step / 2, 2, "each ring sits half a step off the last: they alternate"
	)
	assert_ne(turn, 0, "and the gaps shift")
	var shots0: PackedVector2Array = BulletPatterns.wave_shots(p, 0, Vector2.ZERO, 0, 1.0)[1]
	assert_eq(shots0.size(), p.count - p.gap_count * p.gap_width, "two gaps of three")


func test_both_fights_are_deterministic() -> void:
	for id: StringName in [&"siege_engine", &"foundry"]:
		var hashes := []
		for run in 2:
			var w := BossLab.world(57)
			w.spawn_boss(BossLab.table_index(w, id), Vector2(6, 3))
			w.actors.hp[0] = LONG
			w.actors.max_hp[0] = LONG
			for t in 1500:
				w.step(
					InputFrame.make(Vector2i(60 if (t / 70) % 2 == 0 else -60, 30), 0, 500, 0, 0)
				)
			hashes.append(w.state_hash())
		assert_eq(hashes[0], hashes[1], "%s replays the same" % id)


func test_the_cannon_embers_fly_slowly_in_their_look() -> void:
	var s := _fight(&"siege_engine", Vector2(9, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"turret_cross")
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	assert_gt(w.projectiles.size(), 40, "many embers")
	for k in w.projectiles.size():
		assert_eq(w.projectiles.look_of(k), "cannon_ember")
		var v := _pvel(w, k).length() * SimTick.TICKS_PER_SECOND
		assert_between(v, 3.0, 5.0, "slow (about 3-5 m/s)")
