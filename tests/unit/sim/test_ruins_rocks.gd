extends GutTest
## v0.11.0 O13b (ENEMIES.md R1-R4, approved 2026-11-07): the Ruins' and the Night Rocks' signature enemies (RuinsRocks),
## each its behaviour, its tell and its answer: the Wire Weaver's posts and live cable (it hurts and blocks; breaking a
## post drops it); the Scrap Hound circling and darting only from behind while you attack (a hit stops it); the Rock
## Lurker waiting as cover for both sides and bursting out with a slam within 2 m; the Stone Thrower's rock landing on
## its marked ring and standing as cover for 15 s (a cap per floor). Then the same seed gives the same fight, and a
## snapshot of it round-trips.

const KIND := ActorStore.Kind
const ST := EnemyAi.State
const LONG := 1 << 24

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


## A wall-less world, the hero at the origin (invulnerable unless `hurt`; then with HP to spare).
func _world(hurt := false) -> World:
	var w := World.new(11, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	if not hurt:
		w.actors.invuln[0] = LONG
	else:
		w.actors.hp[0] = 100000
		w.actors.max_hp[0] = 100000
	return w


func _enemy(w: World, kind: int, at: Vector2) -> int:
	var id := w.add_enemy(kind, at)
	w.actors.invuln[w.actors.index_of(id)] = 0
	return id


func _i(w: World, id: int) -> int:
	return w.actors.index_of(id)


func _steps(w: World, n: int, f: InputFrame = InputFrame.new()) -> void:
	for _k in n:
		w.step(f)


func _until_state(w: World, id: int, state: int, limit: int, f := InputFrame.new()) -> int:
	for k in limit:
		var i := _i(w, id)
		if i >= 0 and w.actors.state[i] == state:
			return k
		w.step(f)
	return -1


## The hero's damage events since `after` (seq), by effect id ("" for an actor's hit) and source id.
func _hits(w: World, after: int) -> Array:
	var out := []
	for e in w.events_since(after):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
			out.append([String(e.effect_id), e.source_id, e.tick])
	return out


# --- R1 Wire Weaver ---------------------------------------------------------------------------------------------
func test_the_weaver_marks_its_cable_then_plants_two_posts_and_a_live_cable() -> void:
	var w := _world()
	var id := _enemy(w, KIND.WIRE_WEAVER, Vector2(6, 0))
	var t := w.enemy_table(KIND.WIRE_WEAVER)
	assert_eq(
		[t.hp, t.post_hp, t.max_cables],
		[40, 10, 2],
		"40 HP, posts 10, two cables (starting values)"
	)
	assert_gte(_until_state(w, id, ST.WINDUP, 240), 0, "it winds up")
	var i := _i(w, id)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg.get("shape"), &"lane")
	assert_true(tg.get("ground", true), "the cable's line is marked on the ground")
	assert_gte(
		t.windup_ticks,
		SimTick.MIN_TELEGRAPH_TICKS,
		"the posts spark at least the telegraph minimum"
	)
	var lane: Obb = tg["obb"]
	assert_eq(w.ruins_rocks.cable_count(), 0, "nothing is live yet")
	_steps(w, t.windup_ticks + 1)
	assert_eq(w.ruins_rocks.cable_count(), 1, "the cable is live")
	var ends := RuinsRocks.cable_ends(w, 0)
	assert_eq(ends.size(), 2)
	assert_lte(ends[0].distance_to(ends[1]), 6.001, "the posts stand up to 6 m apart")
	assert_almost_eq(
		(ends[0] + ends[1]) * 0.5, lane.center, Vector2(0.05, 0.05), "where it was marked"
	)
	for k in 2:
		var j := _i(w, [w.ruins_rocks.cable_a[0], w.ruins_rocks.cable_b[0]][k])
		assert_eq(w.actors.kinds[j], KIND.WIRE_POST)
		assert_eq(w.actors.hp[j], 10, "a post has 10 HP")
	# the cable crosses the line from the Weaver to the hero (it cuts the way)
	var weaver := w.actors.pos(_i(w, id))
	assert_lt(signf(ends[0].y) * signf(ends[1].y), 0.0, "one post either side of the line")
	assert_between(
		(ends[0].x + ends[1].x) * 0.5, 0.5, weaver.x - 0.5, "between the Weaver and the hero"
	)


## A Weaver's cable standing across the hero's way at x = 3 (planted for real), the Weaver pinned far off.
func _cable_world() -> Array:
	var w := _world(true)
	var id := _enemy(w, KIND.WIRE_WEAVER, Vector2(6, 0))
	_until_state(w, id, ST.ACTIVE, 400)
	_steps(w, 1)
	return [w, id]


func test_the_cable_hurts_on_touch_and_blocks_the_heros_way() -> void:
	var lab := _cable_world()
	var w: World = lab[0]
	assert_eq(w.ruins_rocks.cable_count(), 1)
	var ends := RuinsRocks.cable_ends(w, 0)
	var cable_x := (ends[0].x + ends[1].x) * 0.5
	var seq := w.last_event_seq()
	var f := InputFrame.new()
	f.move = Vector2i(SimTick.MOVE_MAX, 0)
	var most := -INF
	for _k in 120:
		w.step(f)
		most = maxf(most, w.player_pos().x)
	var reach := w.player.radius_m + w.enemy_table(KIND.WIRE_WEAVER).lane_half_m
	assert_lt(most, cable_x - reach + 0.06, "the hero cannot walk through the cable")
	var cable := _hits(w, seq).filter(func(h: Array) -> bool: return h[0] == "wire_cable")
	assert_gt(cable.size(), 1, "pressing on it, the hero is hurt")
	var period := w.enemy_table(KIND.WIRE_WEAVER).cable_period_ticks
	for k in range(1, cable.size()):
		assert_gte(int(cable[k][2]) - int(cable[k - 1][2]), period, "at most one touch a period")


func test_breaking_a_post_drops_its_cable_and_its_other_post() -> void:
	var lab := _cable_world()
	var w: World = lab[0]
	var a_id := w.ruins_rocks.cable_a[0]
	var b_id := w.ruins_rocks.cable_b[0]
	var kills := w.kills
	var j := _i(w, a_id)
	Damage.hit(w, j, 10, 1, 1, w.take_root(), 0, w.actors.pos(j), w.actors.pos(j))
	_steps(w, 2)
	assert_eq(w.ruins_rocks.cable_count(), 0, "a broken post drops its cable")
	assert_eq(_i(w, a_id), -1)
	assert_eq(_i(w, b_id), -1, "its other post goes with it")
	assert_eq(w.kills, kills, "posts are no kills")
	var seq := w.last_event_seq()
	var f := InputFrame.new()
	f.move = Vector2i(SimTick.MOVE_MAX, 0)
	_steps(w, 40, f)
	assert_gt(w.player_pos().x, 3.5, "the way is open")
	assert_eq(_hits(w, seq).filter(func(h: Array) -> bool: return h[0] == "wire_cable").size(), 0)


func test_killing_the_weaver_drops_its_cables() -> void:
	var lab := _cable_world()
	var w: World = lab[0]
	var i := _i(w, lab[1])
	Damage.hit(w, i, 9999, 1, 1, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i))
	_steps(w, 3)
	assert_eq(w.ruins_rocks.cable_count(), 0)
	for k in range(1, w.actors.size()):
		assert_ne(w.actors.kinds[k], KIND.WIRE_POST, "no post is left")


func test_a_weaver_keeps_making_cables_up_to_its_cap() -> void:
	var w := _world()
	var id := _enemy(w, KIND.WIRE_WEAVER, Vector2(6, 0))
	var most := 0
	for _k in 60 * 20:
		w.step(InputFrame.new())
		most = maxi(most, w.ruins_rocks.cables_of(id))
	assert_eq(most, 2, "a new cable while alive, two at most")
	assert_eq(w.ruins_rocks.cable_count(), 2)


func test_a_death_by_the_cable_names_it() -> void:
	var lab := _cable_world()
	var w: World = lab[0]
	w.actors.hp[0] = 1
	var f := InputFrame.new()
	f.move = Vector2i(SimTick.MOVE_MAX, 0)
	_steps(w, 90, f)
	assert_true(w.player_dead())
	assert_eq(w.killer_attack, RuinsRocks.KILL_CAUSE)
	assert_eq(BossCauses.key(w), RuinsRocks.CAUSE_KEY)
	assert_ne(tr(RuinsRocks.CAUSE_KEY), String(RuinsRocks.CAUSE_KEY), "its recap line exists")


# --- R2 Scrap Hound ---------------------------------------------------------------------------------------------
func test_the_hound_circles_at_5_m_and_never_comes_in_while_you_hold_off() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.SCRAP_HOUND, Vector2(9, 0))
	var t := w.enemy_table(KIND.SCRAP_HOUND)
	assert_eq(t.hp, 30)
	assert_gt(t.speed * 60.0, 6.0, "fast")
	var seq := w.last_event_seq()
	_steps(w, 180)
	var far := []
	for _k in 120:
		w.step(InputFrame.new())
		far.append(w.actors.pos(_i(w, id)).length())
		assert_ne(w.actors.state[_i(w, id)], ST.WINDUP, "no attack while the hero holds off")
	assert_between(far.min(), 4.0, 6.0, "it keeps to its circle")
	assert_between(far.max(), 4.0, 6.0)
	assert_eq(_hits(w, seq).size(), 0)


## Steps the hero holding its attack and aiming `toward` (true: at the hound, false: away from it), until the hound
## winds up or `limit` ticks; returns the ticks used (-1: never).
func _attack_watch(w: World, id: int, toward: bool, limit: int) -> int:
	for k in limit:
		var i := _i(w, id)
		if w.actors.state[i] == ST.WINDUP:
			return k
		var f := InputFrame.new()
		f.held = InputFrame.PRIMARY
		var at := Kin.angle_of(w.actors.pos(i) - w.player_pos())
		f.aim_angle = at if toward else (at + 2048) & 4095
		w.step(f)
	return -1


func test_the_hound_darts_in_only_from_behind_while_you_attack() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.SCRAP_HOUND, Vector2(5, 0))
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	assert_eq(_attack_watch(w, id, true, 300), -1, "facing it while attacking: it never turns in")
	var w2 := _world(true)
	var id2 := _enemy(w2, KIND.SCRAP_HOUND, Vector2(5, 0))
	_steps(w2, SimTick.SPAWN_IN_TICKS + 2)
	assert_gte(_attack_watch(w2, id2, false, 120), 0, "its back turned, attacking: it turns in")
	var i := _i(w2, id2)
	assert_true(RuinsRocks.behind_hero(w2, i))
	var tg := EnemyAi.telegraph(w2, i)
	assert_eq(tg.get("shape"), &"lane", "its dart's line is its tell (the eyes; no ground mark)")
	assert_false(tg.get("ground", true))
	var seq := w2.last_event_seq()
	var f := InputFrame.new()
	f.held = InputFrame.PRIMARY
	f.aim_angle = (Kin.angle_of(w2.actors.pos(i) - w2.player_pos()) + 2048) & 4095
	_steps(w2, 60, f)
	var bites := _hits(w2, seq).filter(func(h: Array) -> bool: return h[1] == id2)
	assert_eq(bites.size(), 1, "the dart bites once")
	var w3 := _world(true)
	var id3 := _enemy(w3, KIND.SCRAP_HOUND, Vector2(5, 0))
	_steps(w3, SimTick.SPAWN_IN_TICKS + 2)
	for k in 200:
		var j := _i(w3, id3)
		var g := InputFrame.new()
		g.aim_angle = (Kin.angle_of(w3.actors.pos(j) - w3.player_pos()) + 2048) & 4095
		w3.step(g)
		assert_ne(
			w3.actors.state[_i(w3, id3)], ST.WINDUP, "behind, but the hero not attacking: no dart"
		)


func test_a_hit_stops_the_hound_with_a_yelp() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.SCRAP_HOUND, Vector2(5, 0))
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	assert_gte(_attack_watch(w, id, false, 120), 0)
	var i := _i(w, id)
	Damage.hit(w, i, 5, 1, 1, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
	var seq := w.last_event_seq()
	_steps(w, 1)
	i = _i(w, id)
	assert_eq(w.actors.state[i], ST.RECOVER, "a hit stops it")
	assert_true(RuinsRocks.yelped(w, i), "it yelps")
	var t := w.enemy_table(KIND.SCRAP_HOUND)
	_steps(w, t.stagger_ticks - 2)
	assert_eq(_hits(w, seq).filter(func(h: Array) -> bool: return h[1] == id).size(), 0, "no bite")
	assert_eq(w.actors.state[_i(w, id)], ST.RECOVER, "staggered its stagger time")


# --- R3 Rock Lurker ---------------------------------------------------------------------------------------------
func test_the_lurker_waits_as_cover_for_both_sides() -> void:
	var w := _world(true)
	var walls := w.walls.size()
	var id := _enemy(w, KIND.ROCK_LURKER, Vector2(6, 0))
	var t := w.enemy_table(KIND.ROCK_LURKER)
	assert_eq(t.hp, 70)
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	var i := _i(w, id)
	assert_true(RuinsRocks.hidden(w, i), "it waits as a boulder")
	assert_eq(w.walls.size(), walls + 1, "the boulder is a wall")
	assert_true(EnemyAi.telegraph(w, i).is_empty(), "no attack shown while it waits")
	assert_false(EnemyAi.sees_player(w, Vector2(10, 0)), "it blocks sight from behind it")
	# an enemy's shot from behind it stops on it
	var seq := w.last_event_seq()
	w.queue_projectile(999, ActorStore.TEAM_ENEMY, Vector2(9, 0), Vector2(-0.2, 0), 7, 0.1, 120, 0)
	_steps(w, 60)
	assert_eq(_hits(w, seq).size(), 0, "the boulder took the enemy's shot")
	assert_true(RuinsRocks.hidden(w, _i(w, id)), "still waiting")
	_steps(w, 300)
	assert_eq(w.actors.pos(_i(w, id)), Vector2(6, 0), "it holds still while it waits")
	# the hero's shot meets its body (and wakes it)
	var pid := w.actors.ids[0]
	w.queue_projectile(pid, ActorStore.TEAM_PLAYER, Vector2(1, 0), Vector2(0.3, 0), 9, 0.1, 120, 0)
	_steps(w, 30)
	i = _i(w, id)
	assert_lt(w.actors.hp[i], w.actors.max_hp[i], "the hero's shot hurts it")
	assert_false(RuinsRocks.hidden(w, i), "a hit wakes it")
	assert_eq(w.walls.size(), walls, "its boulder is gone")


func test_the_lurker_bursts_out_with_a_slam_within_2_m() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.ROCK_LURKER, Vector2(6, 0))
	var t := w.enemy_table(KIND.ROCK_LURKER)
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	w.actors.set_pos(0, Vector2(2.6, 0))  # 2.4 m from its body
	_steps(w, 120)
	var i := _i(w, id)
	assert_true(RuinsRocks.hidden(w, i), "beyond 2 m it keeps waiting")
	assert_true(RuinsRocks.rumbling(w, i), "but it rumbles (within 4 m)")
	var seq := w.last_event_seq()
	w.actors.set_pos(0, Vector2(3.6, 0))  # 1.4 m from its body
	_steps(w, 1)
	i = _i(w, id)
	assert_false(RuinsRocks.hidden(w, i), "within 2 m it bursts out")
	assert_eq(w.actors.state[i], ST.WINDUP, "with its slam")
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg.get("shape"), &"disc")
	assert_true(tg.get("ground", true), "the slam's circle is on the ground")
	assert_gte(t.windup_ticks, SimTick.MIN_TELEGRAPH_TICKS)
	assert_true(
		AttackShapes.disc_touches(tg["center"], tg["radius"], w.player_pos(), w.player.radius_m)
	)
	_steps(w, t.windup_ticks + 1)
	var slams := _hits(w, seq).filter(func(h: Array) -> bool: return h[1] == id)
	assert_eq(slams.size(), 1, "the slam lands on the hero still in it")


func test_stepping_out_of_the_slam_circle_dodges_it() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.ROCK_LURKER, Vector2(6, 0))
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	w.actors.set_pos(0, Vector2(3.6, 0))
	_steps(w, 1)
	var seq := w.last_event_seq()
	w.actors.set_pos(0, Vector2(0, 0))
	_steps(w, 30)
	assert_eq(_hits(w, seq).filter(func(h: Array) -> bool: return h[1] == id).size(), 0)


# --- R4 Stone Thrower -------------------------------------------------------------------------------------------
func test_the_rock_lands_on_the_marked_ring_and_stays_15_s() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.STONE_THROWER, Vector2(8, 0))
	var t := w.enemy_table(KIND.STONE_THROWER)
	assert_eq(t.hp, 90)
	assert_eq(t.windup_ticks, 48, "it lifts the rock 0.8 s")
	assert_gte(_until_state(w, id, ST.WINDUP, 300), 0)
	var i := _i(w, id)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg.get("shape"), &"disc", "a ring marks the landing")
	assert_true(tg.get("ground", true))
	var ring: Vector2 = tg["center"]
	assert_almost_eq(ring, w.player_pos(), Vector2(0.01, 0.01), "at where the hero stands")
	w.actors.set_pos(0, Vector2(0, 3))  # the hero moves out
	var walls := w.walls.size()
	var seq := w.last_event_seq()
	for _k in t.windup_ticks + t.flight_ticks + 2:
		w.step(InputFrame.new())
		if w.ruins_rocks.rock_count() == 0:
			assert_false(
				EnemyAi.telegraph(w, _i(w, id)).is_empty(), "the ring shows until it lands"
			)
	assert_eq(w.ruins_rocks.rock_count(), 1, "the rock stays")
	assert_almost_eq(
		Vector2(w.ruins_rocks.rock_x[0], w.ruins_rocks.rock_y[0]), ring, Vector2(0.001, 0.001)
	)
	assert_eq(w.walls.size(), walls + 1, "as cover")
	assert_eq(_hits(w, seq).filter(func(h: Array) -> bool: return h[1] == id).size(), 0, "dodged")
	var landed := w.tick
	while w.ruins_rocks.rock_count() > 0 and w.tick < landed + 60 * 20:
		w.step(InputFrame.new())
		if w.ruins_rocks.rock_count() > 0 and w.ruins_rocks.rock_x[0] != ring.x:
			break  # (a later throw went first: the cap)
	assert_between(w.tick - landed, t.rock_ticks - 2, t.rock_ticks + 2, "it goes after 15 s")


func test_standing_in_the_ring_is_hit_and_shatters_the_rock() -> void:
	var w := _world(true)
	var id := _enemy(w, KIND.STONE_THROWER, Vector2(8, 0))
	var t := w.enemy_table(KIND.STONE_THROWER)
	_until_state(w, id, ST.WINDUP, 300)
	var seq := w.last_event_seq()
	_steps(w, t.windup_ticks + t.flight_ticks + 2)
	assert_eq(_hits(w, seq).filter(func(h: Array) -> bool: return h[1] == id).size(), 1)
	assert_eq(w.ruins_rocks.rock_count(), 0, "no rock on the hero")


func test_the_rocks_are_capped_per_floor() -> void:
	var w := _world()
	var id := _enemy(w, KIND.STONE_THROWER, Vector2(20, 0))
	var i := _i(w, id)
	var t := w.enemy_table(KIND.STONE_THROWER)
	var walls := w.walls.size()
	for k in t.max_rocks + 3:
		w.actors.lock_x[i] = 4.0 + 1.5 * (k % 6)
		w.actors.lock_y[i] = 3.0 + 1.5 * (k / 6)
		RuinsRocks._land(w, i, t)
	assert_eq(w.ruins_rocks.rock_count(), t.max_rocks, "at most max_rocks")
	assert_eq(w.walls.size(), walls + t.max_rocks, "the oldest went, wall and all")


# --- Determinism ------------------------------------------------------------------------------------------------
func _fight(seed: int) -> World:
	var w := World.new(seed, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	_enemy(w, KIND.WIRE_WEAVER, Vector2(7, 0))
	_enemy(w, KIND.SCRAP_HOUND, Vector2(-6, 2))
	_enemy(w, KIND.ROCK_LURKER, Vector2(0, 6))
	_enemy(w, KIND.STONE_THROWER, Vector2(-8, -4))
	for k in 900:
		var f := InputFrame.new()
		f.move = Vector2i(0, SimTick.MOVE_MAX if (k / 120) % 2 == 0 else -SimTick.MOVE_MAX)
		f.held = InputFrame.PRIMARY if k % 90 < 45 else 0
		f.aim_angle = (k * 37) & 4095
		w.step(f)
	return w


func test_the_same_seed_gives_the_same_fight_and_it_round_trips() -> void:
	var a := _fight(5)
	var b := _fight(5)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	assert_true(a.ruins_rocks.touched, "the fight used them")
	var snap := WorldSnapshot.take(a)
	var copy := World.new(5, PlayerTable.starting_values())
	copy.set_enemy_tables(_tables)
	assert_eq(WorldSnapshot.apply(copy, snap), "")
	assert_eq(copy.state_hash(), a.state_hash(), "the same world after a snapshot")
	for k in 120:
		var f := InputFrame.new()
		f.aim_angle = k * 11
		a.step(f)
		copy.step(f)
	assert_eq(copy.state_hash(), a.state_hash(), "and it runs on the same")
