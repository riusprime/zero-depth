extends GutTest
## v0.7.5 EF (owner N16; docs/design/BOSS_FIGHTS.md "Normal enemies"): the Arc Caster, the Lens Drone and the Bomb
## Drone fire slow fireball patterns (a fan of 3 plasma balls, a ring of 6 red orbs, a lobbed fireball that bursts
## into an X of 4) and draw nothing on the ground; the Needle, the Sniper and the melee kinds keep their ground
## telegraphs. Every world is seeded.

const S := EnemyAi.State
const K := ActorStore.Kind


func _i(w: World, id: int) -> int:
	return w.actors.index_of(id)


func _state(w: World, id: int) -> int:
	return w.actors.state[_i(w, id)]


func _tough(w: World) -> void:
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000


func _until_state(w: World, id: int, state: int, frame := InputFrame.new(), limit := 900) -> int:
	for t in limit:
		if _i(w, id) >= 0 and _state(w, id) == state:
			return t
		w.step(frame)
	return -1


## Steps the Arc Caster `id` through its casts until it winds up `spell` (the player put back at the origin and the
## shots cleared between casts).
func _until_spell(w: World, id: int, spell: int) -> bool:
	for n in 40:
		_until_state(w, id, S.WINDUP)
		if w.actors.pick[_i(w, id)] == spell:
			return true
		_until_state(w, id, S.MOVE)
		w.actors.set_pos(0, Vector2.ZERO)
		w.projectiles = ProjectileStore.new()
	return false


## The live hostile shots: [speed m/s, angle (1/4096 turns), look] each.
func _shots(w: World) -> Array:
	var out := []
	var p := w.projectiles
	for k in p.size():
		if p.team[k] != ActorStore.TEAM_ENEMY:
			continue
		var v := Vector2(p.vel_x[k], p.vel_y[k])
		out.append([Kin.length(v) * 60.0, Kin.angle_of(v), p.look_of(k)])
	return out


func _no_ground(tg: Dictionary, what: String) -> void:
	assert_false(tg.is_empty(), "%s: its body winds up (a cue the recap check counts)" % what)
	assert_eq(tg.get("ground", true), false, "%s draws nothing on the ground" % what)
	for key in ["obb", "obbs", "center", "radius"]:
		assert_false(tg.has(key), "%s: no ground %s" % [what, key])


# --- Arc Caster ----------------------------------------------------------------------------------------------------


func test_the_arc_casters_bolt_is_a_fan_of_three_slow_plasma_balls_with_no_ground_line() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.ARC_CASTER, Vector2(8, 0))
	assert_true(_until_spell(w, id, EnemyAi.Spell.BOLT))
	var i := _i(w, id)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg["shape"], &"cast")
	assert_eq(tg["look"], &"arc_plasma")
	_no_ground(tg, "the bolt")
	var shots := []
	while shots.is_empty() and _i(w, id) >= 0:
		w.step(InputFrame.new())
		shots = _shots(w)
	assert_eq(shots.size(), 3, "a fan of 3")
	var aim := w.actors.lock_a[_i(w, id)]
	var angles := []
	for s: Array in shots:
		assert_almost_eq(float(s[0]), 4.0, 0.01, "slow: 4 m/s (the bolt was 22)")
		assert_eq(s[2], "arc_plasma", "blue-white plasma")
		angles.append(Kin.angle_diff(int(s[1]), aim))
	angles.sort()
	assert_lte(angles[0], 1, "one down the aim")
	for k in [1, 2]:
		assert_almost_eq(float(angles[k]), 170.0, 1.5, "one 15 degrees to each side")


func test_the_arc_casters_spread_is_a_wider_slow_fan_of_three() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.ARC_CASTER, Vector2(8, 0))
	assert_true(_until_spell(w, id, EnemyAi.Spell.SPREAD))
	_no_ground(EnemyAi.telegraph(w, _i(w, id)), "the spread")
	_until_state(w, id, S.RECOVER)
	var shots := _shots(w)
	assert_eq(shots.size(), 3)
	for s: Array in shots:
		assert_almost_eq(float(s[0]), 3.5, 0.01)
		assert_eq(s[2], "arc_plasma")


func test_the_arc_casters_rune_keeps_its_ground_circle() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.ARC_CASTER, Vector2(8, 0))
	assert_true(_until_spell(w, id, EnemyAi.Spell.RUNE))
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_eq([tg["shape"], tg["style"], tg.get("ground", true)], [&"disc", &"rune", true])


# --- Lens Drone ----------------------------------------------------------------------------------------------------


func test_the_lens_drone_fires_a_slow_ring_of_six_red_orbs_with_no_ground_line() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.LENS_DRONE, Vector2(7, 0))
	assert_gte(_until_state(w, id, S.WINDUP), 0)
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_eq([tg["shape"], tg["look"]], [&"cast", &"lens_orb"])
	_no_ground(tg, "the Lens Drone")
	_until_state(w, id, S.RECOVER)
	var shots := _shots(w)
	assert_eq(shots.size(), 6, "a ring of 6")
	var aim := w.actors.lock_a[_i(w, id)]
	var off := []
	for s: Array in shots:
		assert_almost_eq(float(s[0]), 3.5, 0.01, "slow: 3.5 m/s (the burst was 10)")
		assert_eq(s[2], "lens_orb")
		off.append(posmod(int(s[1]) - aim + 2, 4096) - 2)
	off.sort()
	for k in 6:
		assert_almost_eq(float(off[k]), k * 4096.0 / 6.0, 2.0, "evenly round, one at the player")


# --- Bomb Drone ----------------------------------------------------------------------------------------------------


## The drone winds up, then lobs; returns its index once the fireball is in the air (ACTIVE, tick 0).
func _lobbed(w: World, id: int) -> int:
	assert_gte(_until_state(w, id, S.WINDUP), 0)
	var tg := EnemyAi.telegraph(w, _i(w, id))
	assert_eq([tg["shape"], tg["look"]], [&"cast", &"bomb_cinder"])
	_no_ground(tg, "the Bomb Drone's windup")
	assert_gte(_until_state(w, id, S.ACTIVE), 0)
	return _i(w, id)


func test_the_bomb_drone_lobs_a_fireball_that_lands_on_you_with_no_ground_circle() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.BOMB_DRONE, Vector2(7, 0))
	var i := _lobbed(w, id)
	var pat := EnemyAi.pattern_of(w, i)
	assert_eq(pat.lob_ticks, 36, "0.6 s in the air")
	var to := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	assert_eq(to, w.player_pos(), "it lands where the player stood when it committed")
	var progress := []
	while _state(w, id) == S.ACTIVE:
		var tg := EnemyAi.telegraph(w, _i(w, id))
		if tg.is_empty():
			break
		assert_eq([tg["shape"], tg["to"], tg["look"]], [&"lob", to, &"bomb_cinder"])
		_no_ground(tg, "the fireball in the air")
		if progress.is_empty() or progress[-1] < 1000:
			progress.append(tg["progress"])
		w.step(InputFrame.new())
	assert_eq(progress.size(), 37, "drawn in the air for its whole flight, 0 to landed")
	assert_eq([progress[0], progress[-1]], [0, 1000])
	for k in range(1, progress.size()):
		assert_gt(progress[k], progress[k - 1], "it only flies on")
	assert_eq(CombatLab.player_damage(w), [16], "the landing fireball hits a player who stayed")
	assert_eq(_shots(w).size(), 0, "no small fireball spawns on the player")


func test_a_player_who_steps_away_dodges_the_landing_and_meets_the_x_of_four() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.BOMB_DRONE, Vector2(7, 0))
	var i := _lobbed(w, id)
	var to := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	var aim := w.actors.lock_a[i]
	w.actors.set_pos(0, to + Vector2(0, 2.5))  # out of the landing after the lock
	_until_state(w, id, S.RECOVER)
	assert_eq(CombatLab.player_damage(w), [], "the landing missed")
	var shots := _shots(w)
	assert_eq(shots.size(), 4, "an X of 4")
	var off := []
	for s: Array in shots:
		assert_almost_eq(float(s[0]), 4.0, 0.01)
		assert_eq(s[2], "bomb_cinder", "violet cinders")
		off.append(posmod(int(s[1]) - aim, 4096))
	off.sort()
	for k in 4:
		assert_almost_eq(float(off[k]), 512.0 + 1024.0 * k, 1.5, "diagonal to the throw: an X")
	for k in w.projectiles.size():
		var p := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
		assert_lt(Kin.length(p - to), 0.5, "they burst from where it landed")


# --- unchanged kinds -----------------------------------------------------------------------------------------------


func test_the_needle_the_sniper_and_the_melee_kinds_keep_their_ground_telegraphs() -> void:
	var specs := [
		[K.NEEDLE, Vector2(8, 0), [&"lanes"]],
		[K.SNIPER, Vector2(12, 0), [&"lane"]],
		[K.CHARGER, Vector2(3, 0), [&"lane"]],
		[K.HATCHLING, Vector2(3, 0), [&"lane"]],
		[K.SWARMER, Vector2(2, 0), [&"lane"]],
		[K.WARDEN, Vector2(1.5, 0), [&"disc"]],
		[K.SPLITTER, Vector2(1.2, 0), [&"disc"]],
		[K.SPLITLING, Vector2(1.0, 0), [&"disc"]],
		[K.SHIELD_BEARER, Vector2(1.8, 0), [&"lane"]],
	]
	for spec: Array in specs:
		var w := CombatLab.world()
		_tough(w)
		var id := w.add_enemy(spec[0], spec[1])
		assert_gte(_until_state(w, id, S.WINDUP), 0, "kind %d winds up" % spec[0])
		var tg := EnemyAi.telegraph(w, _i(w, id))
		assert_true((spec[2] as Array).has(tg.get("shape")), "kind %d: %s" % [spec[0], tg])
		assert_true(tg.get("ground", true), "kind %d draws on the ground" % spec[0])
		assert_null(EnemyAi.pattern_of(w, _i(w, id)), "kind %d fires no pattern" % spec[0])


# --- fairness, scaling, determinism --------------------------------------------------------------------------------


func test_enemy_fireballs_take_the_danger_tier_and_catch_up_power() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.LENS_DRONE, Vector2(7, 0))
	w.actors.power[_i(w, id)] = 1500
	_until_state(w, id, S.RECOVER)
	var t := w.enemy_table(K.LENS_DRONE)
	assert_eq(w.projectiles.size(), 6)
	for k in w.projectiles.size():
		assert_eq(w.projectiles.damage[k], SpawnTable.scale(t.damage, 1500))


func test_no_enemy_fireball_spawns_inside_a_wall() -> void:
	var w := CombatLab.world()
	_tough(w)
	var id := w.add_enemy(K.LENS_DRONE, Vector2(7, 0))
	_until_state(w, id, S.WINDUP)
	var at := w.actors.pos(_i(w, id))  # it stands while it winds up
	var wall: Array[Obb] = [Obb.make(at + Vector2(0, 0.62), Vector2(1.5, 0.2), 0)]
	w.set_walls(wall)
	_until_state(w, id, S.RECOVER)
	assert_lt(w.projectiles.size(), 6, "the orb that would start in the wall is left out")


func _mixed(seed_value: int) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for spec in [
		[K.ARC_CASTER, Vector2(8, 2)],
		[K.LENS_DRONE, Vector2(-7, 3)],
		[K.BOMB_DRONE, Vector2(4, 7)],
		[K.NEEDLE, Vector2(0, 9)],
		[K.ARC_CASTER, Vector2(-8, 0)],
		[K.BOMB_DRONE, Vector2(-4, -7)],
	]:
		w.add_enemy(spec[0], spec[1])
	return w


func test_the_three_patterns_are_deterministic_and_slow() -> void:
	var hashes := []
	var looks := {}
	for r in 2:
		var w := _mixed(91)
		var bot := FightBot.new(3)
		for k in 900:
			w.step(bot.frame(w))
			w.actors.hp[0] = w.actors.max_hp[0]
			for s: Array in _shots(w):
				if s[2] != "":
					looks[s[2]] = true
					assert_lte(float(s[0]), 5.0, "every enemy fireball is slow")
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
	assert_eq(looks.keys().size(), 3, "all three looks flew: %s" % [looks.keys()])
