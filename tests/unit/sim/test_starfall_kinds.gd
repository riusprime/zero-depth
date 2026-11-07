# gdlint: disable=max-public-methods
extends GutTest
## v0.11.0 O13d (ENEMIES.md R9, R10; owner: "approved as written"): the Starfall signature enemies (StarfallKinds).
## The Star Warper marks a star beside the hero, blinks onto it 1 s later and strikes round it; stepping off dodges it;
## the hero standing on the star cancels the blink and stuns it 1 s. The Gravity Node bends every projectile within
## 5 m toward itself (the hero's and the enemies'), none beyond; each Gun form's rule; the Needle's telegraph is the
## bent path its bolts fly (EI-07); determinism.

const KIND := ActorStore.Kind
const LONG := 1 << 24
const W := preload("res://tests/support/mx4_world.gd")

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


## A wall-less world, the hero at the origin (invulnerable unless `hurt`).
func _world(hurt := false, seed_value := 11) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	if not hurt:
		w.actors.invuln[0] = LONG
	return w


func _enemy(w: World, kind: int, at: Vector2) -> int:
	w.add_enemy(kind, at)
	var i := w.actors.size() - 1
	w.actors.invuln[i] = 0
	return i


func _steps(w: World, n: int, f: InputFrame = InputFrame.new()) -> void:
	for _k in n:
		w.step(f)


func _hero_hits(w: World) -> int:
	return CombatLab.player_damage(w).size()


## Steps until Warper i starts its windup (the star is down); returns the ticks it took (-1: never).
func _until_star(w: World, i: int) -> int:
	return CombatLab.until(
		w, func(_x: World) -> bool: return w.actors.state[i] == EnemyAi.State.WINDUP, 600
	)


# --- R9 Star Warper -----------------------------------------------------------------------------------------------
func test_the_warpers_numbers_are_the_rows() -> void:
	var t := ContentCompiler.compile_enemy(
		ContentRepository.load_all().get_def(&"enemies", &"star_warper")
	)
	assert_eq(t.kind, KIND.STAR_WARPER)
	assert_eq(t.hp, 45, "R9: 45 HP")
	assert_eq(t.windup_ticks, 60, "the star shows for 1 s")
	assert_eq(t.windup_max_ticks, 60, "never longer: the tell is the mark, not a timer")
	assert_eq(t.stun_ticks, 60, "a 1 s stun")
	assert_lt(t.mark_radius_m, t.mark_offset_m, "standing still is not standing on the star")
	assert_gt(t.strike_radius_m, t.mark_offset_m, "standing still is inside the strike")


func test_the_warper_marks_a_star_beside_the_hero_and_blinks_onto_it_1_s_later() -> void:
	var w := _world(true)
	var i := _enemy(w, KIND.STAR_WARPER, Vector2(5, 0))
	assert_gt(_until_star(w, i), 0, "it starts its windup in range")
	var t := w.enemy_table(KIND.STAR_WARPER)
	var star := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	var hero := w.player_pos()
	assert_almost_eq(star.distance_to(hero), t.mark_offset_m, 0.01, "beside the hero")
	var line := (hero - w.actors.pos(i)).normalized()
	assert_almost_eq(
		absf((star - hero).normalized().dot(line)), 0.0, 0.05, "square to its line: beside"
	)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg.get("shape"), &"disc")
	assert_eq(tg.get("style"), &"star")
	assert_eq(tg.get("center"), star, "the telegraph is the strike's disc")
	var before := _hero_hits(w)
	var from := w.actors.pos(i)
	_steps(w, 59)
	assert_eq(w.actors.state[i], EnemyAi.State.WINDUP, "still winding up at 59 ticks")
	assert_eq(w.actors.pos(i), from, "it stands while the star shows")
	_steps(w, 1)
	assert_eq(w.actors.pos(i), star, "at 60 ticks it is on the star")
	assert_eq(_hero_hits(w), before + 1, "and its strike hits the hero who stayed")


func test_stepping_off_the_star_dodges_the_strike() -> void:
	var w := _world(true)
	var i := _enemy(w, KIND.STAR_WARPER, Vector2(5, 0))
	_until_star(w, i)
	var star := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	var away := (w.player_pos() - star).normalized()
	var before := _hero_hits(w)
	var go := InputFrame.make(
		Vector2i(roundi(away.x * SimTick.MOVE_MAX), roundi(away.y * SimTick.MOVE_MAX)), 0, 0, 0, 0
	)
	_steps(w, 60, go)
	assert_eq(w.actors.pos(i), star, "it blinked")
	assert_eq(_hero_hits(w), before, "the hero who stepped off is not hit")
	var t := w.enemy_table(KIND.STAR_WARPER)
	assert_gt(w.player_pos().distance_to(star), t.strike_radius_m + w.player.radius_m)


func test_standing_on_the_star_cancels_the_blink_and_stuns_it_1_s() -> void:
	var w := _world(true)
	var i := _enemy(w, KIND.STAR_WARPER, Vector2(5, 0))
	_until_star(w, i)
	var star := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	var from := w.actors.pos(i)
	var before := _hero_hits(w)
	w.actors.set_pos(0, star)  # the hero steps onto the star
	_steps(w, 60)
	assert_eq(_hero_hits(w), before, "no strike")
	assert_eq(w.actors.pos(i), from, "no blink")
	assert_true(StarfallKinds.stunned(w, i), "stunned")
	var reader := WorldReader.new(w)
	assert_true(reader.warper_stunned(i), "the view reads the stun")
	var stun_t := 0
	while StarfallKinds.stunned(w, i) and stun_t < 200:
		var at := w.actors.pos(i)
		w.actors.set_pos(0, star + Vector2(3, 0))  # out of its way: it must not act while stunned
		_steps(w, 1)
		stun_t += 1
		if StarfallKinds.stunned(w, i):
			assert_eq(w.actors.pos(i), at, "a stunned Warper holds still")
	assert_eq(stun_t, 60, "for 1 s")
	assert_eq(w.actors.state[i], EnemyAi.State.MOVE, "then it walks again")
	assert_gt(w.actors.cd[i], 0, "and waits its cooldown before the next star")


func test_the_star_avoids_a_wall_beside_the_hero() -> void:
	var w := _world(true)
	var i := _enemy(w, KIND.STAR_WARPER, Vector2(5, 0))
	var side := 1 if w.actors.ids[i] % 2 == 0 else -1  # its preferred side: +y for an even id (+1024 turns)
	w.add_wall_now(Obb.make(Vector2(0, 0.8 * side), Vector2(3, 0.2), 0))
	_until_star(w, i)
	var star := Vector2(w.actors.lock_x[i], w.actors.lock_y[i])
	assert_lt(star.y * side, 0.0, "the other side of the hero")


# --- R10 Gravity Node ---------------------------------------------------------------------------------------------
func test_the_nodes_numbers_are_the_rows() -> void:
	var t := ContentCompiler.compile_enemy(
		ContentRepository.load_all().get_def(&"enemies", &"gravity_node")
	)
	assert_eq(t.kind, KIND.GRAVITY_NODE)
	assert_eq(t.hp, 50, "R10: 50 HP")
	assert_eq(t.pull_radius_m, 5.0, "within 5 m")
	assert_true(t.flies, "floating")
	assert_eq(t.attack_range_m, 0.0, "no attack")


func test_the_node_stays_put_and_never_attacks() -> void:
	var w := _world(true)
	var i := _enemy(w, KIND.GRAVITY_NODE, Vector2(3, 0))
	var before := _hero_hits(w)
	_steps(w, 600)
	assert_eq(w.actors.pos(i), Vector2(3, 0), "stationary")
	assert_eq(_hero_hits(w), before, "harmless itself")
	w.actors.set_pos(i, Vector2(3.4, 0.2))  # a shove
	_steps(w, 1)
	assert_eq(w.actors.pos(i), Vector2(3, 0), "back on its spot")


## A harmless hero-team bolt from `from` along +x at `speed` m/tick; returns its id.
func _bolt(w: World, from: Vector2, speed := 0.2, team := ActorStore.TEAM_PLAYER) -> int:
	var owner := w.actors.ids[0] if team == ActorStore.TEAM_PLAYER else 999999
	w.queue_projectile(owner, team, from, Vector2(speed, 0), 0, 0.1, 200, SimEvent.TAG_PROJECTILE)
	_steps(w, 1)
	return w.projectiles.ids[w.projectiles.size() - 1]


func _proj(w: World, id: int) -> int:
	return w.projectiles.ids.find(id)


func test_a_straight_bolt_within_5_m_bends_toward_the_node_and_keeps_its_speed() -> void:
	var w := _world()
	_enemy(w, KIND.GRAVITY_NODE, Vector2(6, -3))
	_steps(w, 2)
	var id := _bolt(w, Vector2(0, 0.0))
	var k := _proj(w, id)
	var v0 := Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])
	var closest := 99.0
	for _t in 40:
		_steps(w, 1)
		k = _proj(w, id)
		if k < 0:
			break
		var v := Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])
		assert_almost_eq(v.length(), v0.length(), 0.0005, "it turns, never speeds up or slows")
		closest = minf(
			closest,
			Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k]).distance_to(Vector2(6, -3))
		)
	k = _proj(w, id)
	assert_gt(k, -1)
	assert_lt(w.projectiles.vel_y[k], -0.01, "bent toward the node (−y)")
	assert_lt(w.projectiles.pos_y[k], -0.1, "and its path with it")


func test_no_bend_beyond_5_m() -> void:
	var w := _world()
	_enemy(w, KIND.GRAVITY_NODE, Vector2(6, -5.3))
	_steps(w, 2)
	var id := _bolt(w, Vector2(0, 0.0))
	_steps(w, 60)
	var k := _proj(w, id)
	assert_eq(w.projectiles.vel_y[k], 0.0, "5.3 m off its whole line: never pulled")
	assert_eq(w.projectiles.pos_y[k], 0.0)
	var ns := StarfallKinds.nodes(w)
	var v := Vector2(0.2, 0)
	assert_eq(StarfallKinds.bend(ns, Vector2(6, 0.0), v), v, "at 5.3 m: unchanged")
	assert_ne(StarfallKinds.bend(ns, Vector2(6, -0.4), v), v, "at 4.9 m: bent")


func test_enemy_shots_bend_too() -> void:
	var w := _world()
	_enemy(w, KIND.GRAVITY_NODE, Vector2(6, -3))
	_steps(w, 2)
	var id := _bolt(w, Vector2(1.0, 0.0), 0.2, ActorStore.TEAM_ENEMY)  # clear of the hero
	_steps(w, 30)
	var k := _proj(w, id)
	assert_lt(
		w.projectiles.vel_y[k], -0.01, "an enemy's shot bends toward the node as the hero's does"
	)


func test_a_dead_node_pulls_no_more() -> void:
	var w := _world()
	var i := _enemy(w, KIND.GRAVITY_NODE, Vector2(6, -3))
	_steps(w, 2)
	Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
	_steps(w, 2)
	var id := _bolt(w, Vector2(0, 0.0))
	_steps(w, 40)
	assert_eq(w.projectiles.vel_y[_proj(w, id)], 0.0, "kill it to straighten your shots")


func test_the_needles_telegraph_is_the_bent_path_its_bolts_fly() -> void:
	var w := _world()
	var n := _enemy(w, KIND.NEEDLE, Vector2(9, 0))
	_enemy(w, KIND.GRAVITY_NODE, Vector2(5, 2.5))
	assert_gt(
		CombatLab.until(
			w, func(_x: World) -> bool: return w.actors.state[n] == EnemyAi.State.WINDUP, 900
		),
		0
	)
	# the windup's last tick: the aim is locked; the lanes drawn now are the path
	CombatLab.until(
		w, func(_x: World) -> bool: return w.actors.state_t[n] >= w.actors.windup[n] - 1, 300
	)
	var lanes := EnemyAi.burst_lines(w, n)
	assert_gt(lanes.size(), 1, "a bent path is drawn as several lanes")
	var seen := 0
	var off_line := false
	for _t in 120:
		_steps(w, 1)
		for k in w.projectiles.size():
			if w.projectiles.team[k] != ActorStore.TEAM_ENEMY:
				continue
			var at := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
			var inside := false
			for o: Obb in lanes:
				if Collide.circle_vs_obb(at, 0.001, o) != Vector2.ZERO or _in_obb(at, o):
					inside = true
					break
			assert_true(inside, "bolt at %s lies on the drawn path" % at)
			seen += 1
			if absf(at.y) > 0.3:
				off_line = true
	assert_gt(seen, 20, "the bolts flew")
	assert_true(off_line, "and the path really bent")


func _in_obb(p: Vector2, o: Obb) -> bool:
	var d := p - o.center
	return absf(d.dot(o.axis_u)) <= o.half.x + 0.002 and absf(d.dot(o.axis_v)) <= o.half.y + 0.002


func test_no_node_keeps_the_needles_straight_lanes() -> void:
	var w := _world()
	var n := _enemy(w, KIND.NEEDLE, Vector2(9, 0))
	CombatLab.until(
		w, func(_x: World) -> bool: return w.actors.state[n] == EnemyAi.State.WINDUP, 900
	)
	var t := w.enemy_table(KIND.NEEDLE)
	assert_lte(
		EnemyAi.burst_lines(w, n).size(), t.burst_count, "one straight lane a shot, as before"
	)


# --- The Gun forms --------------------------------------------------------------------------------------------------
## The hero's first projectile's y after `ticks` firing along +x with `cards`, a node (or a dummy, same size, no pull)
## at (4, -2.5) and a far dummy ahead.
func _form_y(cards: Array, node: bool, ticks := 14, near := false) -> float:
	var w := W.world(&"gun", cards)
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = LONG
	if node:
		var i := _enemy(w, KIND.GRAVITY_NODE, Vector2(4, -2.5))
		w.actors.hp[i] = 1000000
		w.actors.max_hp[i] = 1000000
	else:
		w.add_dummy(Vector2(4, -2.5), 0.45, 1000000)
	w.add_dummy(Vector2(14, 0), 0.4, 1000000)
	if near:  # a target nearer the hero than the node, for the forms that pick one (both worlds pick it)
		w.add_dummy(Vector2(4.2, 1.6), 0.4, 1000000)
	W.run(w, 1, 0, W.S)
	if w.projectiles.size() == 0:
		return INF
	var id := w.projectiles.ids[0]
	for _k in ticks:
		W.run(w, 1, 0, W.S)
	var k := w.projectiles.ids.find(id)
	return w.projectiles.pos_y[k] if k >= 0 else INF


func test_every_flying_gun_form_bends() -> void:
	for cards: Array in [[], [&"gun_void"], [&"gun_wave"], [&"gun_glaive"]]:
		var plain := _form_y(cards, false)
		var bent := _form_y(cards, true)
		assert_ne(plain, INF, "%s fired" % [cards])
		assert_ne(bent, INF, "%s fired" % [cards])
		assert_lt(bent, plain - 0.05, "%s: pulled toward the node (−y)" % [cards])


func test_a_lance_ball_bends() -> void:
	var w := W.world(&"gun", [&"gun_lance"])
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = LONG
	_enemy(w, KIND.GRAVITY_NODE, Vector2(4, -2.5))
	W.run(w, 20, 0, W.S)
	W.run(w, 1, 0, 0)  # release: the ball flies
	W.run(w, 2, 0, 0)
	assert_gt(w.projectiles.size(), 0, "a ball")
	W.run(w, 12, 0, 0)
	assert_lt(w.projectiles.pos_y[0], -0.05, "pulled toward the node")


func test_an_orbiting_shot_is_not_bent_until_it_leaves() -> void:
	var w := W.world(&"gun", [&"orbit_rounds"])
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = LONG
	_enemy(w, KIND.GRAVITY_NODE, Vector2(2.5, 0))
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[0]
	for _k in 30:
		W.run(w, 1, 0, 0)
		var k := w.projectiles.ids.find(id)
		var at := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
		assert_almost_eq(at.length(), ProjectileMoves.ORBIT_R_M, 0.06, "on its lap round the hero")


func test_the_laser_lance_is_not_bent() -> void:
	var hits := []
	for node in [false, true]:
		var w := W.world(&"gun", [&"gun_laser"])
		w.set_enemy_tables(_tables)
		w.actors.invuln[0] = LONG
		if node:
			_enemy(w, KIND.GRAVITY_NODE, Vector2(3, -2.0))
		else:
			w.add_dummy(Vector2(3, -2.0), 0.45, 1000000)
		var target := w.add_dummy(Vector2(7, 0), 0.4, 1000000)
		W.run(w, 2, 0, W.S)
		var got := 0
		for e in W.events(w, SimEvent.Kind.DAMAGE):
			if e.target_id == target:
				got += 1
		hits.append(got)
	assert_gt(hits[0], 0, "the lance hits straight ahead")
	assert_eq(hits[1], hits[0], "a node beside the lance leaves it straight (an instant path)")


# --- Roster, determinism ------------------------------------------------------------------------------------------
func test_both_join_starfall_and_no_boss_adds_take_the_node() -> void:
	var repo := ContentRepository.load_all()
	var b: BiomeDefinition = repo.get_def(&"biomes", &"starfall")
	var kinds := VariantCompiler.roster_kinds(repo, b)
	assert_true(kinds.has(KIND.STAR_WARPER))
	assert_true(kinds.has(KIND.GRAVITY_NODE))
	assert_false(BiomeDefinition.PENDING_SIGNATURES.has(&"star_warper"))
	assert_false(BiomeDefinition.PENDING_SIGNATURES.has(&"gravity_node"))
	var w := _world()
	w.floor_index = 4
	w.spawner = ContentCompiler.compile_floor_spawning(repo, 4)
	w.roster_kinds = kinds
	w.run_ticks = 60 * 300
	var adds := BossGates.add_kinds(w)
	assert_true(adds.has(KIND.STAR_WARPER), "the Warper may come as an add")
	assert_false(adds.has(KIND.GRAVITY_NODE), "the Node only in regular rooms")


func _busy(seed_value: int) -> World:
	var w := _world(true, seed_value)
	_enemy(w, KIND.STAR_WARPER, Vector2(5, 1))
	_enemy(w, KIND.GRAVITY_NODE, Vector2(3, -3))
	_enemy(w, KIND.NEEDLE, Vector2(-8, 2))
	w.actors.invuln[0] = LONG
	return w


func test_determinism_and_snapshot() -> void:
	var a := _busy(5)
	var b := _busy(5)
	var f := InputFrame.make(Vector2i(40, 20), 0, 0, 0, 0)
	_steps(a, 300, f)
	_steps(b, 300, f)
	assert_eq(a.state_hash(), b.state_hash(), "the same seed, the same world")
	var snap := WorldSnapshot.take(a)
	var copy := _world(true, 5)
	assert_eq(WorldSnapshot.apply(copy, snap), "")
	assert_eq(copy.state_hash(), a.state_hash())
	_steps(a, 200, f)
	_steps(copy, 200, f)
	assert_eq(copy.state_hash(), a.state_hash(), "and the same after a round trip")


func test_seekers_and_wisps_shots_still_seek_and_bend_on_top() -> void:
	for cards: Array in [[&"gun_seekers"], [&"gun_wisps"]]:
		var plain := _form_y(cards, false, 8, true)
		var bent := _form_y(cards, true, 8, true)
		assert_ne(plain, INF, "%s fired" % [cards])
		assert_ne(bent, INF, "%s fired" % [cards])
		assert_lt(bent, plain - 0.02, "%s: the node tugs it toward itself (−y)" % [cards])


func test_a_star_that_cannot_be_dodged_or_cancelled_fails_validation() -> void:
	var repo := ContentRepository.load_all()
	var good: EnemyDefinition = repo.get_def(&"enemies", &"star_warper")
	assert_eq(good.validate(), [], "the shipped Warper is valid")
	var on := good.duplicate(true) as EnemyDefinition
	on.behaviour_params["mark_radius_m"] = 1.2  # standing still would count as on the star
	var codes := on.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"star")
	var short := good.duplicate(true) as EnemyDefinition
	short.attacks[0].shape_params["radius_m"] = 1.0  # the strike would miss a hero standing still
	codes = short.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"star")
