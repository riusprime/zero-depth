extends GutTest
## The Gravity Node draws the hero gently toward it (StarfallKinds.hero_drift): within its 5 m reach the walking hero
## drifts toward it, hero_pull at its centre falling to nothing at the reach, none outside; two nodes' drifts are held
## to one node's; walking out always works; the dash, a spawning or dead node and a dead hero give no drift.

const KIND := ActorStore.Kind
const LONG := 1 << 24

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


## A wall-less world, the hero invulnerable at the origin.
func _world(seed_value := 11) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = LONG
	return w


## A node at `at`, harmless to hit at once (it still spawns in: _awake).
func _node(w: World, at: Vector2) -> int:
	w.add_enemy(KIND.GRAVITY_NODE, at)
	var i := w.actors.size() - 1
	w.actors.invuln[i] = 0
	return i


## Steps the nodes through their spawn-in, then puts the hero back at the origin, standing.
func _awake(w: World) -> void:
	for _k in w.tuning.spawn_in_ticks + 2:
		w.step(InputFrame.new())
	w.actors.set_pos(0, Vector2.ZERO)
	w.vel = Vector2.ZERO


func _table(w: World) -> EnemyTable:
	return w.enemy_table(KIND.GRAVITY_NODE)


func _move(x: int, y: int) -> InputFrame:
	var f := InputFrame.new()
	f.move = Vector2i(x, y)
	return f


func test_the_rows_numbers() -> void:
	var t := ContentCompiler.compile_enemy(
		ContentRepository.load_all().get_def(&"enemies", &"gravity_node")
	)
	assert_eq(t.hero_pull_radius_m, 5.0, "it reaches the hero within 5 m")
	assert_almost_eq(t.hero_pull * SimTick.TICKS_PER_SECOND, 2.1, 0.0001, "2.1 m/s at its centre")
	var walk := PlayerTable.starting_values().move_speed
	assert_almost_eq(t.hero_pull / walk, 0.35, 0.0001, "35 % of the hero's base walk")


func test_the_drift_points_at_the_node_and_falls_to_nothing_at_the_reach() -> void:
	for d: float in [1.5, 2.5, 4.0, 4.9]:
		var w := _world()
		var i := _node(w, Vector2(d, 0))
		_awake(w)
		var t := _table(w)
		var got := StarfallKinds.hero_drift(w)
		var want := t.hero_pull * (1.0 - d / t.hero_pull_radius_m)
		assert_almost_eq(got.length(), want, 0.00001, "%.1f m: hero_pull × (1 − d / reach)" % d)
		assert_gt(got.x, 0.0, "%.1f m: toward the node" % d)
		assert_almost_eq(got.y, 0.0, 0.00001, "%.1f m: straight at it" % d)
		assert_almost_eq(
			WorldReader.new(w).gravity_hero_pull(i),
			got.length() / t.hero_pull,
			0.00001,
			"the view's read is the same share"
		)
	var near := _world()
	_node(near, Vector2(1.5, 0))
	_awake(near)
	var mid := _world()
	_node(mid, Vector2(3.0, 0))
	_awake(mid)
	assert_gt(
		StarfallKinds.hero_drift(near).length(),
		StarfallKinds.hero_drift(mid).length(),
		"stronger nearer the centre"
	)


func test_no_drift_outside_the_reach() -> void:
	for d: float in [5.0, 5.5, 9.0]:
		var w := _world()
		_node(w, Vector2(0, d))
		_awake(w)
		assert_eq(StarfallKinds.hero_drift(w), Vector2.ZERO, "%.1f m: outside its reach" % d)
		for _k in 60:
			w.step(InputFrame.new())
		assert_eq(w.player_pos(), Vector2.ZERO, "%.1f m: the hero stays put" % d)


func test_the_hero_drifts_toward_it_with_no_input_and_stops_short_of_its_body() -> void:
	var w := _world()
	var i := _node(w, Vector2(4, 0))
	_awake(w)
	var last := 4.0
	for _k in 600:
		w.step(InputFrame.new())
		var d := w.player_pos().distance_to(w.actors.pos(i))
		assert_true(d <= last + 0.00001, "never pushed away")
		last = d
	assert_lt(last, 1.5, "drawn in")
	var touch := w.actors.radius[i] + w.player.radius_m
	assert_gt(last, touch, "it stops short of the node's body")
	assert_almost_eq(w.player_pos().y, 0.0, 0.0001, "straight toward it")


func test_two_nodes_together_pull_no_harder_than_one_at_its_centre() -> void:
	var w := _world()
	_node(w, Vector2(1.5, 0.3))
	_node(w, Vector2(1.5, -0.3))
	_awake(w)
	var t := _table(w)
	var cap := minf(t.hero_pull, BossTide.run_speed(w) * StarfallKinds.HERO_WALK_SHARE / 1000.0)
	var each := t.hero_pull * (1.0 - Vector2(1.5, 0.3).length() / t.hero_pull_radius_m)
	assert_gt(each * 2.0, cap, "their sum would pass the cap")
	assert_almost_eq(StarfallKinds.hero_drift(w).length(), cap, 0.00001, "held to the cap")
	assert_lt(cap, BossTide.run_speed(w) * 0.5, "well under the hero's walk")


func test_walking_out_always_works() -> void:
	for slow: bool in [false, true]:
		var w := _world()
		var a := _node(w, Vector2(1.2, 0.2))
		var b := _node(w, Vector2(1.2, -0.2))
		_awake(w)
		if slow:  # a hero slowed to 40 % still walks out (the cap follows the run speed)
			w.player.move_speed *= 0.4
		var start := w.player_pos().distance_to(w.actors.pos(a))
		for _k in 300:
			w.step(_move(-SimTick.MOVE_MAX, 0))
		var d := minf(
			w.player_pos().distance_to(w.actors.pos(a)), w.player_pos().distance_to(w.actors.pos(b))
		)
		assert_gt(d, start, "slow %s: walking away gains ground" % slow)
		assert_gt(d, _table(w).hero_pull_radius_m, "slow %s: out of its reach" % slow)


func test_the_dash_is_not_bent_by_it() -> void:
	var with_node := _world()
	_node(with_node, Vector2(2, 2))
	_awake(with_node)
	var without := _world()
	_awake(without)
	for w: World in [with_node, without]:
		w.dash_dir = Vector2(1, 0)
		w.dash_ticks_left = w.player.dash_ticks + 1
		for _k in w.player.dash_ticks:
			w.step(InputFrame.new())
	assert_eq(with_node.player_pos(), without.player_pos(), "the dash flies the same line")


func test_a_spawning_or_dead_node_or_a_dead_hero_pulls_nothing() -> void:
	var w := _world()
	w.add_enemy(KIND.GRAVITY_NODE, Vector2(2, 0))  # still spawning in
	var i := w.actors.size() - 1
	assert_eq(w.actors.state[i], EnemyAi.State.SPAWN)
	assert_eq(StarfallKinds.hero_drift(w), Vector2.ZERO, "spawning: no pull")
	w.actors.invuln[i] = 0
	_awake(w)
	assert_ne(StarfallKinds.hero_drift(w), Vector2.ZERO, "awake: it pulls")
	Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
	w.step(InputFrame.new())
	assert_eq(StarfallKinds.hero_drift(w), Vector2.ZERO, "dead: no pull")
	var h := _world()
	_node(h, Vector2(2, 0))
	_awake(h)
	h.actors.dead[0] = 1
	assert_eq(StarfallKinds.hero_drift(h), Vector2.ZERO, "a dead hero is not pulled")


func test_the_pull_is_deterministic() -> void:
	var hashes := []
	for _r in 2:
		var w := _world(7)
		_node(w, Vector2(3, 1))
		_node(w, Vector2(-2, 2.5))
		for k in 240:
			w.step(_move(40 if k % 60 < 30 else -40, 0))
		hashes.append([w.player_pos(), w.state_hash()])
	assert_eq(hashes[0], hashes[1], "the same run, the same drift")


func test_a_pull_too_strong_to_walk_out_of_fails_validation() -> void:
	var good: EnemyDefinition = ContentRepository.load_all().get_def(&"enemies", &"gravity_node")
	assert_eq(good.validate(), [], "the shipped node is valid")
	var strong := good.duplicate(true) as EnemyDefinition
	strong.behaviour_params["hero_pull_mps"] = 3.5
	var codes := strong.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"hero_pull")
	var missing := good.duplicate(true) as EnemyDefinition
	missing.behaviour_params.erase("hero_pull_radius_m")
	codes = missing.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"param_missing")
	var zero := good.duplicate(true) as EnemyDefinition
	zero.behaviour_params["hero_pull_mps"] = 0.0
	codes = zero.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"not_positive")
