extends GutTest
## Smarter normal enemies and the two new kinds (PLAN v0.3.5 AI; owner lines F4, F5, F6). Every world is seeded, so
## each behaviour is the same on every run.

const S := EnemyAi.State
const K := ActorStore.Kind


func _i(w: World, id: int) -> int:
	return w.actors.index_of(id)


func _state(w: World, id: int) -> int:
	return w.actors.state[_i(w, id)]


func _tough(w: World) -> void:
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000


## Steps with `frame` until enemy `id` enters `state` (or `limit` ticks); returns the ticks used or -1.
func _until_state(w: World, id: int, state: int, frame := InputFrame.new(), limit := 900) -> int:
	for t in limit:
		if _i(w, id) >= 0 and _state(w, id) == state:
			return t
		w.step(frame)
	return -1


# --- F4: normal enemies ------------------------------------------------------------------------------------------


func test_windups_are_drawn_per_attack_between_24_and_40_ticks() -> void:
	var seen := {}
	for kind in [K.CHARGER, K.WARDEN, K.NEEDLE]:
		var w := CombatLab.world()
		_tough(w)
		var at := Vector2(5, 0) if kind != K.WARDEN else Vector2(1.6, 0)
		var id := w.add_enemy(kind, at)
		for n in 6:
			assert_gte(_until_state(w, id, S.WINDUP), 0, "attack %d of %d" % [n, kind])
			var wu := w.actors.windup[_i(w, id)]
			assert_between(wu, 24, 40, "windup of kind %d" % kind)
			seen[wu] = true
			w.actors.set_pos(0, Vector2.ZERO)
			_until_state(w, id, S.MOVE)
	assert_gt(seen.size(), 3, "the lengths vary: %s" % [seen.keys()])


func test_the_same_seed_draws_the_same_windups() -> void:
	var runs := []
	for r in 2:
		var w := CombatLab.world()
		_tough(w)
		var id := w.add_enemy(K.CHARGER, Vector2(5, 0))
		var got := []
		for n in 4:
			_until_state(w, id, S.WINDUP)
			got.append(w.actors.windup[_i(w, id)])
			_until_state(w, id, S.MOVE)
		runs.append(got)
	assert_eq(runs[0], runs[1])


func test_a_needle_leads_a_moving_player_and_commits_before_it_fires() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.NEEDLE, Vector2(9, 0))
	var run := InputFrame.make(Vector2i(0, 127), 0, 0, 0, 0)  # the player runs along +y
	assert_gte(_until_state(w, id, S.WINDUP, run), 0)
	var i := _i(w, id)
	# Where the aim line crosses the player's x: above the player (+y), the way it runs.
	var d := Kin.dir(w.actors.lock_a[i])
	var from := w.actors.pos(i)
	var cross_y := from.y + d.y * (w.player_pos().x - from.x) / d.x
	assert_gt(
		cross_y, w.player_pos().y + 0.2, "it aims ahead of the player, on the side it runs to"
	)
	var commit := w.actors.windup[i] - EnemyAi.COMMIT_TICKS
	var angles := []
	while _state(w, id) == S.WINDUP:
		angles.append([w.actors.state_t[i], w.actors.lock_a[i]])
		w.step(run)
		i = _i(w, id)
	var before := -1
	for pair: Array in angles:
		if pair[0] > commit:
			if before < 0:
				before = pair[1]
			assert_eq(
				pair[1], before, "no more tracking in the last %d ticks" % EnemyAi.COMMIT_TICKS
			)
	assert_ne(angles[0][1], angles[angles.size() - 1][1], "it tracked before committing")


func test_a_needle_burst_fans_three_bolts_ten_degrees_apart() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.NEEDLE, Vector2(9, 0))
	var t := w.enemy_table(K.NEEDLE)
	assert_eq(t.burst_spread, ContentCompiler.degrees_to_units(10.0))
	_until_state(w, id, S.ACTIVE)
	var angles := {}
	for k in 30:
		w.step(InputFrame.new())
		for p in w.projectiles.size():
			if w.projectiles.team[p] == ActorStore.TEAM_ENEMY:
				angles[Kin.angle_of(Vector2(w.projectiles.vel_x[p], w.projectiles.vel_y[p]))] = true
	var sorted := angles.keys()
	sorted.sort()
	assert_eq(sorted.size(), 3, "three directions: %s" % [sorted])
	if sorted.size() == 3:
		assert_almost_eq(int(sorted[1]) - int(sorted[0]), t.burst_spread, 2)
		assert_almost_eq(int(sorted[2]) - int(sorted[1]), t.burst_spread, 2)


func test_the_needle_telegraph_shows_one_lane_per_shot() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(K.NEEDLE, Vector2(9, 0))
	_until_state(w, id, S.WINDUP)
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_eq(tg["shape"], &"lanes")
	assert_eq((tg["obbs"] as Array).size(), 3)


func test_a_charge_bends_toward_the_player_at_a_limited_rate() -> void:
	var w := CombatLab.world()
	_tough(w)
	var t := w.enemy_table(K.CHARGER)
	assert_eq(t.charge_turn, ContentCompiler.degrees_to_units(1.0), "60 degrees a second")
	var id := w.add_enemy(K.CHARGER, Vector2(5, 0))
	var side := InputFrame.make(Vector2i(0, 127), 0, 0, 0, 0)
	_until_state(w, id, S.ACTIVE, side)
	var last := w.actors.lock_a[_i(w, id)]
	var start := last
	while _i(w, id) >= 0 and _state(w, id) == S.ACTIVE:
		w.step(side)
		var now := w.actors.lock_a[_i(w, id)]
		assert_lte(Kin.angle_diff(now, last), t.charge_turn, "never faster than the turn rate")
		last = now
	assert_gt(Kin.angle_diff(last, start), 0, "it bent toward the dodging player")


func test_a_pack_spreads_around_the_player_instead_of_stacking() -> void:
	var w := CombatLab.world()
	_tough(w)
	var ids := []
	for k in 4:
		ids.append(w.add_enemy(K.WARDEN, Vector2(9.0 + k * 0.6, 0.05 * (k % 2))))
	CombatLab.idle(w, 420)
	var angles := []
	for id: int in ids:
		var i := _i(w, id)
		angles.append(Kin.angle_of(w.actors.pos(i) - w.player_pos()))
	var widest := 0
	for a: int in angles:
		for b: int in angles:
			widest = maxi(widest, Kin.angle_diff(a, b))
	assert_gt(widest, ContentCompiler.degrees_to_units(60.0), "they came at you from several sides")


func test_the_spread_push_is_zero_alone_and_apart_when_close() -> void:
	var w := CombatLab.world()
	var a := w.add_enemy(K.CHARGER, Vector2(5, 0))
	assert_eq(EnemyAi.spread_push(w, _i(w, a)), Vector2.ZERO)
	var b := w.add_enemy(K.CHARGER, Vector2(5.5, 0))
	assert_lt(EnemyAi.spread_push(w, _i(w, a)).x, 0.0, "pushed away from its neighbour")
	assert_gt(EnemyAi.spread_push(w, _i(w, b)).x, 0.0)


# --- F5: the Arc Caster ------------------------------------------------------------------------------------------


func test_the_arc_caster_keeps_six_to_nine_metres_away() -> void:
	for spec in [[Vector2(3, 0), 5.5, 99.0], [Vector2(15, 0), 0.0, 9.6]]:
		var w := CombatLab.world()
		_tough(w)
		var id := w.add_enemy(K.ARC_CASTER, spec[0])
		w.actors.cd[_i(w, id)] = 9999
		for k in 240:
			w.actors.cd[_i(w, id)] = 9999  # walking only
			w.step(InputFrame.new())
		var d := Kin.length(w.actors.pos(_i(w, id)) - w.player_pos())
		assert_between(d, float(spec[1]), float(spec[2]), "from %s: %.2f m" % [spec[0], d])


func test_the_arc_caster_casts_all_three_spells_with_their_telegraphs() -> void:
	var w := CombatLab.world()
	_tough(w)
	var t := w.enemy_table(K.ARC_CASTER)
	var id := w.add_enemy(K.ARC_CASTER, Vector2(8, 0))
	var seen := {}
	for n in 20:
		if _until_state(w, id, S.WINDUP) < 0:
			break
		var i := _i(w, id)
		var tg := EnemyAi.telegraph(w, i)
		match w.actors.pick[i]:
			EnemyAi.Spell.BOLT:
				assert_eq([tg["shape"], tg["style"]], [&"lane", &"bolt"])
				assert_eq(w.actors.windup[i], 30, "a 30-tick line first")
			EnemyAi.Spell.SPREAD:
				assert_eq([tg["shape"], (tg["obbs"] as Array).size()], [&"lanes", 3])
				assert_eq(w.actors.windup[i], 30)
			EnemyAi.Spell.RUNE:
				assert_eq(
					[tg["shape"], tg["style"], tg["radius"]], [&"disc", &"rune", t.rune_radius_m]
				)
				assert_eq(tg["center"], w.player_pos(), "under the player")
				assert_eq(w.actors.windup[i], 36, "it erupts after 36 ticks")
		seen[w.actors.pick[i]] = true
		_until_state(w, id, S.MOVE)
		w.actors.set_pos(0, Vector2.ZERO)
	assert_eq(seen.size(), 3, "bolt, spread and rune all came up")


func test_the_arc_bolt_flies_at_22_metres_a_second() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.ARC_CASTER, Vector2(8, 0))
	for n in 20:
		_until_state(w, id, S.WINDUP)
		if w.actors.pick[_i(w, id)] == EnemyAi.Spell.BOLT:
			break
		_until_state(w, id, S.MOVE)
	assert_eq(w.actors.pick[_i(w, id)], EnemyAi.Spell.BOLT)
	_until_state(w, id, S.RECOVER)
	assert_eq(w.projectiles.size(), 1)
	var v := Vector2(w.projectiles.vel_x[0], w.projectiles.vel_y[0])
	assert_almost_eq(Kin.length(v) * 60.0, 22.0, 0.01)


func test_the_rune_hits_a_player_who_stays_and_misses_one_who_walks_out() -> void:
	for walk in [false, true]:
		var w := CombatLab.world()
		_tough(w)
		var id := w.add_enemy(K.ARC_CASTER, Vector2(8, 0))
		for n in 30:
			_until_state(w, id, S.WINDUP)
			if w.actors.pick[_i(w, id)] == EnemyAi.Spell.RUNE:
				break
			_until_state(w, id, S.MOVE)
			w.actors.set_pos(0, Vector2.ZERO)
			w.projectiles = ProjectileStore.new()
		assert_eq(w.actors.pick[_i(w, id)], EnemyAi.Spell.RUNE)
		var before := CombatLab.player_damage(w).size()
		var frame := InputFrame.make(Vector2i(0, 127) if walk else Vector2i.ZERO, 0, 0, 0, 0)
		_until_state(w, id, S.RECOVER, frame)
		var hit := CombatLab.player_damage(w).size() > before
		assert_eq(hit, not walk, "walking out of the rune dodges it" if walk else "standing in it")


# --- F6: the Bomb Drone ------------------------------------------------------------------------------------------


func test_the_bomb_circle_fills_for_48_ticks_then_explodes_for_16() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.BOMB_DRONE, Vector2(7, 0))
	_until_state(w, id, S.WINDUP)
	var i := _i(w, id)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq([tg["shape"], tg["style"], tg["radius"]], [&"disc", &"bomb", 1.8])
	assert_eq(tg["center"], w.player_pos(), "lobbed at where the player stands")
	assert_eq(w.actors.windup[i], 48)
	var progress := []
	while _state(w, id) == S.WINDUP:
		progress.append(EnemyAi.telegraph(w, _i(w, id))["progress"])
		w.step(InputFrame.new())
	assert_eq(progress.size(), 48, "the circle shows for its whole fuse")
	assert_eq(progress[0], 0)
	assert_gt(progress[-1], 950, "full just before it lands")
	for k in range(1, progress.size()):
		assert_gte(progress[k], progress[k - 1], "it only fills")
	assert_eq(CombatLab.player_damage(w), [16])


func test_the_drone_keeps_hovering_while_its_bomb_is_in_the_air() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.BOMB_DRONE, Vector2(6, 0))
	_until_state(w, id, S.WINDUP)
	var at := w.actors.pos(_i(w, id))
	CombatLab.idle(w, 20)
	assert_ne(w.actors.pos(_i(w, id)), at, "it drifts sideways meanwhile")


func test_the_drone_is_hit_by_melee_and_shots_on_the_ground() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(K.BOMB_DRONE, Vector2(3, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var i := _i(w, id)
	var at := w.actors.pos(i)
	var got := Damage.hit(w, i, 5, 1, 1, w.take_root(), SimEvent.TAG_MELEE, w.player_pos(), at)
	assert_eq(got, 5, "a swing on the ground lands")
	w.queue_projectile(
		1,
		ActorStore.TEAM_PLAYER,
		w.player_pos(),
		(at - w.player_pos()).normalized() * 0.3,
		4,
		0.1,
		60,
		SimEvent.TAG_PROJECTILE
	)
	var hp := w.actors.hp[_i(w, id)]
	CombatLab.idle(w, 12)
	assert_lt(w.actors.hp[_i(w, id)], hp, "a bolt along the ground lands")


# --- determinism and the readable-cause rule -----------------------------------------------------------------------


func _mixed(seed_value: int) -> World:
	var t := PlayerTable.starting_values()
	var w := World.new(seed_value, t)
	w.set_enemy_tables(CombatLab.tables())
	for spec in [
		[K.ARC_CASTER, Vector2(8, 2)],
		[K.BOMB_DRONE, Vector2(-7, 3)],
		[K.NEEDLE, Vector2(0, 9)],
		[K.CHARGER, Vector2(6, -5)],
		[K.WARDEN, Vector2(-5, -5)],
		[K.ARC_CASTER, Vector2(-8, 0)],
		[K.BOMB_DRONE, Vector2(4, 7)],
	]:
		w.add_enemy(spec[0], spec[1])
	return w


func test_the_new_ai_is_deterministic() -> void:
	var hashes := []
	for r in 2:
		var w := _mixed(77)
		var bot := FightBot.new(5)
		for k in 900:
			w.step(bot.frame(w))
			w.actors.hp[0] = w.actors.max_hp[0]
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_every_hit_from_the_new_kinds_has_a_readable_cause() -> void:
	var damage := 0
	var causes := {}
	for s in [3, 4, 5, 6]:
		var w := _mixed(s)
		var bot := FightBot.new(s)
		var check := ReadableCause.new(w)
		for k in 1500:
			w.step(bot.frame(w))
			check.observe(w)
			w.actors.hp[0] = w.actors.max_hp[0]
			if w.actors.size() < 4:
				w.add_enemy(K.ARC_CASTER if k % 2 == 0 else K.BOMB_DRONE, Vector2(9, 0))
		damage += check.damage_count
		causes.merge(check.by_cause)
		for v: Dictionary in check.violations:
			fail_test("unreadable hit: %s" % JSON.stringify(v))
	assert_gt(damage, 20, "hit often enough to mean something (%d)" % damage)
	assert_true(causes.has("CAUSE_ARC_CASTER"), "the Arc Caster landed hits: %s" % [causes])
	assert_true(causes.has("CAUSE_BOMB_DRONE"), "the Bomb Drone landed hits: %s" % [causes])
