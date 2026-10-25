# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 EL (G1 docs/roadmap/v0.9.0/ELITES.md E1-E3, "ok go for those"): the three archetypes in a bare world (the
## real compiled tables, no floor scaling, no tier): each ability's telegraph timing, damage and punish window, the
## plain attacks, contact, the clear-line rule and the death lines.

const S := EnemyAi.State
const K := ActorStore.Kind
const A := EliteAi.Attack


func _i(w: World, id: int) -> int:
	return w.actors.index_of(id)


func _world() -> World:
	var w := CombatLab.world()
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	w.actors.set_pos(0, Vector2.ZERO)
	return w


## Elite `kind` at `at`, its ability due at once (`ability`) or its plain attack (the other held off).
func _elite(w: World, kind: int, at: Vector2, ability := true) -> int:
	var id := Elites.spawn(w, kind, at, Elites.Source.DEV)
	var i := _i(w, id)
	w.actors.cd[i] = 0 if ability else 1 << 20
	w.actors.fire_cd[i] = 1 << 20 if ability else 0
	return id


## Steps (the hero held at `hero` each tick) until elite `id` is in `state` with pick `pick`; returns ticks or -1.
func _until(w: World, id: int, state: int, pick := -1, limit := 900, hero := Vector2.INF) -> int:
	for t in limit:
		var i := _i(w, id)
		if i >= 0 and w.actors.state[i] == state and (pick < 0 or w.actors.pick[i] == pick):
			return t
		if hero != Vector2.INF:
			w.actors.set_pos(0, hero)
		w.step(InputFrame.new())
	return -1


func _hurt(w: World) -> int:
	var n := 0
	for d in CombatLab.player_damage(w):
		n += int(d)
	return n


func _hit_elite(w: World, id: int, amount: int) -> int:
	var i := _i(w, id)
	var p := w.actors.pos(i)
	return Damage.hit(w, i, amount, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, p, p)


func _table(kind: int) -> EliteTable:
	for t in CombatLab.tables():
		if t.kind == kind:
			return t.elite
	return null


# --- the data the G1 set ------------------------------------------------------------------------------------------
func test_the_numbers_are_the_approved_rows() -> void:
	var by := {}
	for t in CombatLab.tables():
		if EliteAi.is_elite_kind(t.kind):
			by[t.kind] = t
	assert_eq(by.size(), 3, "three archetypes")
	var b: EnemyTable = by[K.BREAKER]
	assert_eq(
		[b.hp, b.elite.contact_damage, b.elite.damage, b.elite.basic_damage], [600, 0, 32, 25]
	)
	assert_eq([b.elite.windup_ticks, b.elite.recover_ticks, b.elite.every_ticks], [60, 90, 360])
	assert_eq([b.elite.radius_m, b.elite.vulnerable_permille], [3.0, 1500])
	assert_almost_eq(b.speed * 60.0, 1.3, 0.001)
	var r: EnemyTable = by[K.RIFT_HUNTER]
	assert_eq([r.hp, r.elite.contact_damage, r.elite.damage], [450, 0, 30])  # owner: no contact damage
	assert_eq(
		[r.elite.windup_ticks, r.elite.track_ticks, r.elite.recover_ticks, r.elite.every_ticks],
		[54, 30, 60, 270]
	)
	assert_eq([r.keep_min_m, r.keep_distance_m, r.elite.radius_m], [4.0, 6.0, 2.2])
	assert_almost_eq(r.speed * 60.0, 2.6, 0.001)
	var c: EnemyTable = by[K.CONDUIT]
	assert_eq(
		[c.hp, c.elite.contact_damage, c.elite.damage, c.elite.basic_damage], [400, 0, 40, 12]
	)
	assert_eq(
		[c.elite.windup_ticks, c.elite.track_ticks, c.elite.recover_ticks, c.elite.every_ticks],
		[84, 54, 120, 420]
	)
	assert_eq([c.keep_min_m, c.keep_distance_m, c.elite.half_width_m * 2.0], [7.0, 10.0, 0.7])
	assert_eq(c.elite.basic_every_ticks, 150, "the orb fan every 2.5 s")
	assert_eq(c.elite.basic_pattern.count, 3, "a fan of 3 orbs")


func test_every_telegraph_shows_at_least_0_8_s() -> void:
	for kind in Elites.KINDS:
		var e := _table(kind)
		assert_gte(e.windup_ticks, 48, "kind %d's ability" % kind)
		if e.basic_damage > 0:
			assert_gte(e.basic_windup_ticks, 48, "kind %d's plain attack" % kind)


# --- E1 the Breaker -----------------------------------------------------------------------------------------------
func test_breaker_ground_slam_fills_a_3_m_circle_for_1_s_then_hits_32() -> void:
	var w := _world()
	var id := _elite(w, K.BREAKER, Vector2(2.8, 0))
	assert_gte(_until(w, id, S.WINDUP, A.ABILITY), 0, "it raises the fist")
	var i := _i(w, id)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg["shape"], &"disc")
	assert_true(tg["ground"], "the circle is on the ground")
	assert_eq(tg["radius"], 3.0)
	assert_eq(tg["center"], w.actors.pos(i), "round the Breaker")
	assert_false(tg.get("tracked", false), "it fills in (no tracking)")
	var hurt := _hurt(w)
	assert_eq(_until(w, id, S.ACTIVE), 60, "the slam lands 1.0 s later")
	w.step(InputFrame.new())
	assert_eq(_hurt(w) - hurt, 32, "32 in the circle")


func test_breaker_stays_stuck_1_5_s_taking_half_again() -> void:
	var w := _world()
	var id := _elite(w, K.BREAKER, Vector2(2.8, 0))
	_until(w, id, S.RECOVER, A.ABILITY)
	var i := _i(w, id)
	assert_true(EliteAi.vulnerable(w, i), "stuck: the punish window")
	assert_eq(_hit_elite(w, id, 100), 150, "+50 % while stuck")
	var at := w.actors.pos(i)
	assert_eq(_until(w, id, S.MOVE, -1, 200), 90, "stuck 1.5 s")
	assert_lt(
		w.actors.pos(_i(w, id)).distance_to(at),
		0.03,
		"it never walked while stuck (its first walking tick only)"
	)
	assert_false(EliteAi.vulnerable(w, _i(w, id)), "free again")
	assert_eq(_hit_elite(w, id, 100), 100, "and hits land normally")


func test_stepping_out_of_the_circle_dodges_the_slam() -> void:
	var w := _world()
	var id := _elite(w, K.BREAKER, Vector2(2.8, 0))
	_until(w, id, S.WINDUP, A.ABILITY)
	var hurt := _hurt(w)
	_until(w, id, S.RECOVER, A.ABILITY, 200, Vector2(-1.5, 0))
	assert_eq(_hurt(w), hurt, "out of the 3 m circle: no damage")


func test_breaker_punch_reaches_1_5_m_for_25() -> void:
	var w := _world()
	var id := _elite(w, K.BREAKER, Vector2(2.0, 0), false)
	assert_gte(_until(w, id, S.WINDUP, A.BASIC), 0, "a punch at you")
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_false(tg["ground"], "the punch is a body cue")
	var hurt := _hurt(w)
	assert_eq(_until(w, id, S.ACTIVE, A.BASIC, 200, Vector2.ZERO), 48, "0.8 s windup")
	w.step(InputFrame.new())
	assert_eq(_hurt(w) - hurt, 25)


## v0.9.0 EL (owner 2026-10-23: "Drop contact damage"): touching an elite never hurts; only its telegraphed attacks do.
func test_touching_an_elite_never_hurts() -> void:
	var w := _world()
	var id := _elite(w, K.BREAKER, Vector2(1.2, 0), false)
	var i := _i(w, id)
	w.actors.fire_cd[i] = 1 << 20
	w.actors.cd[i] = 1 << 20
	var hurt := _hurt(w)
	var touch := w.actors.radius[i] + w.player.radius_m
	for t in 120:
		var e := w.actors.pos(_i(w, id))
		w.actors.set_pos(0, e - Vector2(touch, 0))
		w.actors.invuln[0] = 0
		w.step(InputFrame.new())
	assert_eq(_hurt(w) - hurt, 0, "two seconds of touching: no damage")


# --- E2 the Rift Hunter ---------------------------------------------------------------------------------------------
func test_rift_mark_tracks_0_5_s_then_locks_vanishes_and_reappears_on_it() -> void:
	var w := _world()
	var id := _elite(w, K.RIFT_HUNTER, Vector2(5, 0))
	assert_gte(_until(w, id, S.WINDUP, A.ABILITY), 0, "it marks a spot")
	var i := _i(w, id)
	assert_eq(EnemyAi.telegraph(w, i)["center"], Vector2.ZERO, "the mark starts on you")
	var hero := Vector2(0, 0)
	var locked_at := Vector2.INF
	for t in 54:
		hero += Vector2(0, 0.05)
		w.actors.set_pos(0, hero)
		w.step(InputFrame.new())
		i = _i(w, id)
		var tg := EnemyAi.telegraph(w, i)
		if tg.is_empty():
			break
		if w.actors.state_t[i] < 30:
			assert_false(tg["locked"], "tracking until 0.5 s")
			assert_almost_eq(tg["center"].y, hero.y, 0.001, "it follows you")
		else:
			assert_true(tg["locked"], "locked after 0.5 s")
			if locked_at == Vector2.INF:
				locked_at = tg["center"]
			assert_eq(tg["center"], locked_at, "the mark stays")
		assert_eq(EliteAi.vanished(w, i), w.actors.state_t[i] >= 36, "gone for the last 0.3 s")
		if EliteAi.vanished(w, i):
			assert_eq(_hit_elite(w, id, 50), 0, "nothing hits it while gone")
	i = _i(w, id)
	assert_eq(w.actors.state[i], S.ACTIVE, "it strikes 0.9 s after the mark")
	assert_eq(w.actors.pos(i), locked_at, "on the mark")


func test_rift_slash_hits_30_on_the_mark_and_misses_if_you_moved() -> void:
	var w := _world()
	var id := _elite(w, K.RIFT_HUNTER, Vector2(5, 0))
	_until(w, id, S.WINDUP, A.ABILITY)
	var hurt := _hurt(w)
	_until(w, id, S.RECOVER, A.ABILITY, 200, Vector2.ZERO)
	assert_eq(_hurt(w) - hurt, 30, "standing on the mark: 30")
	var w2 := _world()
	var id2 := _elite(w2, K.RIFT_HUNTER, Vector2(5, 0))
	_until(w2, id2, S.WINDUP, A.ABILITY)
	for t in 31:  # held still while it tracks, so the mark locks on the spot
		w2.actors.set_pos(0, Vector2.ZERO)
		w2.step(InputFrame.new())
	var hurt2 := _hurt(w2)
	_until(w2, id2, S.RECOVER, A.ABILITY, 200, Vector2(0, -3.0))
	assert_eq(_hurt(w2), hurt2, "moved 3 m after the lock: missed")


func test_rift_hunter_stands_still_1_s_after_the_slash() -> void:
	var w := _world()
	var id := _elite(w, K.RIFT_HUNTER, Vector2(5, 0))
	_until(w, id, S.WINDUP, A.ABILITY, 900, Vector2.ZERO)
	for t in 31:  # the mark locks on the spot
		w.actors.set_pos(0, Vector2.ZERO)
		w.step(InputFrame.new())
	_until(w, id, S.RECOVER, A.ABILITY, 200, Vector2(0, 3))  # out of the mark: no hit, no hit-stop
	var at := w.actors.pos(_i(w, id))
	assert_false(EliteAi.vulnerable(w, _i(w, id)), "no damage bonus: its window is the pause")
	assert_eq(_until(w, id, S.MOVE, -1, 200, Vector2(0, 3)), 60, "1.0 s pause")
	assert_lt(
		w.actors.pos(_i(w, id)).distance_to(at), 0.05, "stood still (its first walking tick only)"
	)


func test_rift_hunter_keeps_4_to_6_m_away() -> void:
	var w := _world()
	var id := Elites.spawn(w, K.RIFT_HUNTER, Vector2(12, 0), Elites.Source.DEV)
	w.actors.cd[_i(w, id)] = 1 << 20
	for t in 600:
		w.actors.set_pos(0, Vector2.ZERO)
		w.step(InputFrame.new())
	var d := w.actors.pos(_i(w, id)).length()
	assert_between(d, 3.6, 6.6, "it circles in its band (%.2f m)" % d)


# --- E3 the Conduit -----------------------------------------------------------------------------------------------
func test_conduit_beam_charges_1_4_s_tracking_0_9_s_then_hits_40() -> void:
	var w := _world()
	var id := _elite(w, K.CONDUIT, Vector2(8, 0))
	assert_gte(_until(w, id, S.WINDUP, A.ABILITY), 0, "it plants its staff")
	var i := _i(w, id)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg["shape"], &"lane")
	assert_true(tg["ground"] and tg["tracked"], "a line on the ground that follows you")
	assert_almost_eq((tg["obb"] as Obb).half.y, 0.35, 0.001, "0.7 m wide")
	var hurt := _hurt(w)
	assert_eq(_until(w, id, S.ACTIVE, A.ABILITY, 200, Vector2.ZERO), 84, "fires 1.4 s later")
	w.step(InputFrame.new())
	assert_eq(_hurt(w) - hurt, 40, "40, once")
	assert_not_null(EliteAi.beam_now(w, _i(w, id)), "the beam shows")


func test_conduit_line_locks_after_0_9_s_and_a_sidestep_dodges() -> void:
	var w := _world()
	var id := _elite(w, K.CONDUIT, Vector2(8, 0))
	_until(w, id, S.WINDUP, A.ABILITY)
	for t in 55:
		w.actors.set_pos(0, Vector2.ZERO)
		w.step(InputFrame.new())
	var i := _i(w, id)
	assert_true(EnemyAi.telegraph(w, i)["locked"], "locked and brightening")
	var a0 := w.actors.lock_a[i]
	var hurt := _hurt(w)
	_until(w, id, S.RECOVER, A.ABILITY, 200, Vector2(0, 1.5))
	assert_eq(w.actors.lock_a[_i(w, id)], a0, "the line never moved after the lock")
	assert_eq(_hurt(w), hurt, "a 1.5 m sidestep: missed")


func test_conduit_overloads_2_s_taking_half_again() -> void:
	var w := _world()
	var id := _elite(w, K.CONDUIT, Vector2(8, 0))
	_until(w, id, S.RECOVER, A.ABILITY, 900, Vector2(0, 2))
	assert_true(EliteAi.vulnerable(w, _i(w, id)), "overloaded")
	assert_eq(_hit_elite(w, id, 100), 150)
	assert_eq(_until(w, id, S.MOVE, -1, 300, Vector2(0, 2)), 120, "2.0 s down")


func test_the_beam_stops_at_the_wall() -> void:
	var w := _world()
	w.set_walls([Obb.make(Vector2(-4.0, 0.0), Vector2(0.5, 6.0), 0)])
	var id := _elite(w, K.CONDUIT, Vector2(8, 0))
	_until(w, id, S.WINDUP, A.ABILITY, 900, Vector2.ZERO)
	var o: Obb = EnemyAi.telegraph(w, _i(w, id))["obb"]
	var far_x := o.center.x - o.half.x
	assert_almost_eq(far_x, -3.5, 0.15, "the line ends at the wall's face, not 30 m on")


func test_conduit_orb_fan_fires_3_orbs_of_12_every_2_5_s() -> void:
	var w := _world()
	var id := _elite(w, K.CONDUIT, Vector2(8, 0), false)
	assert_gte(_until(w, id, S.WINDUP, A.BASIC), 0, "a cast")
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_false(tg["ground"], "the fan draws nothing on the ground")
	assert_eq(_until(w, id, S.ACTIVE, A.BASIC, 200, Vector2.ZERO), 48, "0.8 s windup")
	w.step(InputFrame.new())
	var n := 0
	var dmg := -1
	for k in w.projectiles.size():
		if w.projectiles.team[k] == ActorStore.TEAM_ENEMY:
			n += 1
			dmg = w.projectiles.damage[k]
	assert_eq(n, 3, "3 orbs")
	assert_eq(dmg, 12)


func test_conduit_never_hurts_by_contact() -> void:
	var w := _world()
	var id := _elite(w, K.CONDUIT, Vector2(1.0, 0), false)
	w.actors.fire_cd[_i(w, id)] = 1 << 20
	w.actors.cd[_i(w, id)] = 1 << 20
	var hurt := _hurt(w)
	for t in 120:
		var e := w.actors.pos(_i(w, id))
		w.actors.set_pos(0, e - Vector2(w.actors.radius[_i(w, id)] + w.player.radius_m, 0))
		w.step(InputFrame.new())
	assert_eq(_hurt(w), hurt)


# --- fair: a clear line (owner 2026-10-23), never frozen -------------------------------------------------------
func test_no_elite_attacks_through_a_sealed_doorway() -> void:
	for c: Array in [
		[K.BREAKER, Vector2(2.0, 0)], [K.RIFT_HUNTER, Vector2(5, 0)], [K.CONDUIT, Vector2(8, 0)]
	]:
		var w := _world()
		w.add_barrier(Obb.make(Vector2(c[1].x * 0.5, 0.0), Vector2(0.05, 60.0), 0))
		var id := Elites.spawn(w, c[0], c[1], Elites.Source.DEV)
		w.actors.cd[_i(w, id)] = 0
		w.actors.fire_cd[_i(w, id)] = 0
		var hurt := _hurt(w)
		assert_eq(
			_until(w, id, S.WINDUP, -1, 600, Vector2.ZERO), -1, "kind %d starts nothing" % c[0]
		)
		assert_eq(_hurt(w), hurt, "and never hurts the hero")


func test_the_same_elites_attack_in_the_open() -> void:
	for c: Array in [
		[K.BREAKER, Vector2(2.0, 0)], [K.RIFT_HUNTER, Vector2(5, 0)], [K.CONDUIT, Vector2(8, 0)]
	]:
		var w := _world()
		var id := _elite(w, c[0], c[1])
		assert_gte(_until(w, id, S.WINDUP, -1, 600, Vector2.ZERO), 0, "kind %d attacks" % c[0])


func test_an_elite_never_freezes() -> void:
	var w := _world()
	var id := Elites.spawn(w, K.BREAKER, Vector2(5, 0), Elites.Source.DEV)
	assert_eq(w.actors.freeze_immune[_i(w, id)], 1)


# --- the death lines ------------------------------------------------------------------------------------------------
func test_deaths_name_the_elite_and_its_attack() -> void:
	var w := _world()
	w.actors.hp[0] = 10
	var id := _elite(w, K.BREAKER, Vector2(2.8, 0))
	_until(w, id, S.RECOVER, A.ABILITY, 900, Vector2.ZERO)
	assert_true(w.player_dead(), "the slam killed")
	assert_eq(BossCauses.key(w), &"CAUSE_ELITE_BREAKER_SLAM")
	var w2 := _world()
	w2.actors.hp[0] = 10
	var id2 := _elite(w2, K.CONDUIT, Vector2(8, 0))
	_until(w2, id2, S.RECOVER, A.ABILITY, 900, Vector2.ZERO)
	assert_eq(BossCauses.key(w2), &"CAUSE_ELITE_CONDUIT_BEAM")
	var w3 := _world()
	w3.actors.hp[0] = 10
	var id3 := _elite(w3, K.RIFT_HUNTER, Vector2(5, 0))
	_until(w3, id3, S.RECOVER, A.ABILITY, 900, Vector2.ZERO)
	assert_eq(BossCauses.key(w3), &"CAUSE_ELITE_RIFT_HUNTER_SLASH")
	for key in [
		&"CAUSE_ELITE_BREAKER_SLAM", &"CAUSE_ELITE_CONDUIT_BEAM", &"CAUSE_ELITE_RIFT_HUNTER_SLASH"
	]:
		TranslationServer.set_locale("en")
		assert_ne(tr(key), String(key), "%s has its English line" % key)
