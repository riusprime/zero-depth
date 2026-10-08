extends GutTest
## Crowds (v0.4.0 SC, owner F7): enemies re-plan their walk every 4 ticks on the phase their id gives and move every
## tick; the same seed gives the same crowd; the flow field is flooded once for everyone, bounded, and not again from
## the same cell; a horde of 120 enemies and 200 projectiles steps well inside a generous time bound.

const LONG := 1 << 24
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE
]


## A wall-less world with `n` enemies on rings around the player, who is invulnerable.
func _crowd(n: int, seed_value: int = 7) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	w.actors.invuln[0] = LONG
	for k in n:
		var ring := 6.0 + (k % 4) * 2.0
		w.add_enemy(KINDS[k % KINDS.size()], Kin.dir(k * 4096 / n) * ring)
	return w


func _walk(w: World, ticks: int) -> void:
	for t in ticks:
		var f := InputFrame.make(Vector2i(127 if (t / 60) % 2 == 0 else -127, 40), 0, 0, 0, 0)
		w.step(f)
		w.actors.invuln[0] = LONG


func test_each_enemy_replans_only_on_its_own_phase() -> void:
	var w := _crowd(24)
	_walk(w, SimTick.SPAWN_IN_TICKS + 8)
	var last := {}
	var changed_off_phase := 0
	var changed := 0
	for t in 240:
		var tick := w.tick  # the tick think() sees this step
		_walk(w, 1)
		for i in range(1, w.actors.size()):
			var id := w.actors.ids[i]
			var plan := Vector2(w.actors.plan_x[i], w.actors.plan_y[i])
			if last.has(id) and last[id] != plan:
				changed += 1
				if posmod(tick, EnemyAi.PLAN_PERIOD) != posmod(id, EnemyAi.PLAN_PERIOD):
					changed_off_phase += 1
			last[id] = plan
	assert_gt(changed, 100, "plans change as the player moves")
	assert_eq(
		changed_off_phase, 0, "an enemy's plan changes only on ticks where tick % 4 == id % 4"
	)


func test_plans_are_spread_evenly_over_the_ticks() -> void:
	var w := _crowd(40)
	var per_phase := [0, 0, 0, 0]
	for i in range(1, w.actors.size()):
		for t in EnemyAi.PLAN_PERIOD:
			w.tick = t
			if EnemyAi.plans_now(w, i):
				per_phase[t] += 1
	assert_eq(per_phase, [10, 10, 10, 10], "a quarter of the crowd plans each tick")


func test_enemies_still_move_every_tick() -> void:
	var w := _crowd(12)
	_walk(w, SimTick.SPAWN_IN_TICKS + 8)
	var i := 1
	for k in range(1, w.actors.size()):
		if w.actors.kinds[k] == ActorStore.Kind.CHARGER and w.actors.state[k] == EnemyAi.State.MOVE:
			i = k
			break
	var moved := 0
	for t in 8:
		var before := w.actors.pos(i)
		_walk(w, 1)
		if w.actors.state[i] == EnemyAi.State.MOVE and w.actors.pos(i) != before:
			moved += 1
	assert_gte(moved, 6, "a walker moves on (nearly) every tick, not only on its plan ticks")


func test_the_same_seed_gives_the_same_crowd() -> void:
	var a := _crowd(60, 3)
	var b := _crowd(60, 3)
	for k in 6:
		_walk(a, 100)
		_walk(b, 100)
		assert_eq(a.state_hash(), b.state_hash(), "after %d ticks" % ((k + 1) * 100))
	var c := _crowd(60, 3)
	_walk(c, 300)
	c.actors.plan_x[1] += 0.25  # the plan is state: it is hashed
	_walk(c, 1)
	var d := _crowd(60, 3)
	_walk(d, 301)
	assert_ne(c.state_hash(), d.state_hash(), "a different plan, a different hash")


func test_the_flow_field_is_bounded_and_not_reflooded_from_the_same_cell() -> void:
	var w := FightLab.floor_world(20261007, 1)
	var nav := w.nav
	nav.flood(w.player_pos(), NavField.WORLD_FLOOD_STEPS)
	var reached := 0
	var max_d := 0
	for d in nav.dist:
		if d != NavField.UNREACHED:
			reached += 1
			max_d = maxi(max_d, d)
	assert_lte(max_d, NavField.WORLD_FLOOD_STEPS, "no cell past the bound")
	var full := NavField.new()
	full.build(w.walls)
	full.flood(w.player_pos())
	var all := 0
	for k in full.dist.size():
		if full.dist[k] != NavField.UNREACHED:
			all += 1
			if full.dist[k] <= NavField.WORLD_FLOOD_STEPS:
				assert_eq(nav.dist[k], full.dist[k], "inside the bound, the same distances")
	assert_lt(reached, all, "the bound leaves the far side of floor 1 out")
	var planted := nav.dist.duplicate()
	planted[0] = 12345  # a flood from the same cell is skipped: the planted value stays
	nav.dist = planted
	nav.flood(w.player_pos(), NavField.WORLD_FLOOD_STEPS)
	assert_eq(nav.dist[0], 12345)
	nav.flood(w.player_pos() + Vector2(3.0, 0.0), NavField.WORLD_FLOOD_STEPS)
	assert_ne(nav.dist[0], 12345, "another cell floods again")


## A CI-safe regression bound, far above the measured cost (BENCH and HORDES evidence): it catches a return to
## O(n^2) or to sweeping every wall, not a few per cent.
func test_a_horde_steps_inside_a_generous_bound() -> void:
	var w := FightLab.floor_world(20261007, 3)
	w.spawner = null
	w.actors.invuln[0] = LONG
	var f := w.floor_layout
	var spots := PackedVector2Array()
	for r in [f.start_room] + Array(f.neighbours(f.start_room)):
		for q in f.spawn_points[r]:
			if Kin.length(q - w.player_pos()) >= 6.0:
				spots.append(q)
	assert_gt(spots.size(), 10)
	for k in 120:
		w.add_enemy(KINDS[k % KINDS.size()], spots[k % spots.size()])
	var bot := FightBot.new(5)
	var shot := 0
	var spent := 0
	var ticks := 240
	for t in ticks:
		var from := w.player_pos()
		for k in maxi(0, 200 - w.projectiles.size()):
			var dir := Kin.dir((shot * 397) & 4095)
			shot += 1
			w.queue_projectile(
				w.actors.ids[0],
				0,
				from + dir * 0.6,
				dir * 0.2,
				0,
				0.12,
				150,
				SimEvent.TAG_PROJECTILE
			)
		var frame := bot.frame(w)
		var t0 := Time.get_ticks_usec()
		w.step(frame)
		spent += Time.get_ticks_usec() - t0
		w.actors.invuln[0] = LONG
	var mean_ms := spent / 1000.0 / ticks
	gut.p(
		(
			"horde mean step: %.3f ms (%d actors, %d projectiles)"
			% [mean_ms, w.actors.size(), w.projectiles.size()]
		)
	)
	assert_gte(WaveDirector.enemies_alive(w), 100, "the crowd is still there")
	assert_gte(w.projectiles.size(), 150)
	assert_lt(mean_ms, 25.0, "120 enemies + 200 projectiles: far under 25 ms a tick")
