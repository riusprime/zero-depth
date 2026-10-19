extends GutTest
## v0.8.0 P1 (owner O23, playtest 2: "Enemies don't consistently find the shortest valid path toward the player,
## sometimes getting stuck behind walls or in adjacent rooms instead of pursuing"): the shared flow field (NavField)
## is a shortest-path field in octile steps, it still floods when the player stands against a wall or in a doorway,
## and the world's flood stops a margin past the enemies (O32), flooding again when one is out of it.

const K := ActorStore.Kind
## The two rooms: a 40 x 24 m box split along y = 0 by a 0.4 m partition with doorways (centre x, width).
const HALF := Vector2(20.0, 12.0)
const PARTITION_HALF := 0.2


## A world of two rooms joined by `doors` ([centre x, width] in the partition), the player at `hero`.
static func _rooms(doors: Array, hero: Vector2) -> World:
	var w := CombatLab.world()
	var walls: Array[Obb] = [
		Obb.make(Vector2(0, -HALF.y - 0.5), Vector2(HALF.x + 1.0, 0.5), 0),
		Obb.make(Vector2(0, HALF.y + 0.5), Vector2(HALF.x + 1.0, 0.5), 0),
		Obb.make(Vector2(-HALF.x - 0.5, 0), Vector2(0.5, HALF.y), 0),
		Obb.make(Vector2(HALF.x + 0.5, 0), Vector2(0.5, HALF.y), 0),
	]
	var edges := [-HALF.x]
	for d: Array in doors:
		edges.append(float(d[0]) - float(d[1]) * 0.5)
		edges.append(float(d[0]) + float(d[1]) * 0.5)
	edges.append(HALF.x)
	for k in range(0, edges.size(), 2):
		var a: float = edges[k]
		var b: float = edges[k + 1]
		walls.append(Obb.make(Vector2((a + b) * 0.5, 0), Vector2((b - a) * 0.5, PARTITION_HALF), 0))
	w.set_walls(walls)
	w.actors.set_pos(0, hero)
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	return w


## Steps until enemy `id` is within `near` of the player (or `limit` ticks): [ticks (-1: never), metres walked,
## the x where it crossed y = 0 (NAN: never)].
static func _chase(w: World, id: int, near: float, limit: int) -> Array:
	var walked := 0.0
	var cross := NAN
	var last := w.actors.pos(w.actors.index_of(id))
	for t in limit:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		var p := w.actors.pos(w.actors.index_of(id))
		walked += Kin.length(p - last)
		if is_nan(cross) and signf(p.y) != signf(last.y):
			cross = p.x
		last = p
		if Kin.length(p - w.player_pos()) <= near:
			return [t, walked, cross]
	return [-1, walked, cross]


func test_an_enemy_in_the_next_room_takes_the_nearer_door() -> void:
	# The enemy and the player stand one above the other, the partition between them (no line of sight). Door A
	# (x -11) is 4 m to the side of them, door B (x +1) 6 m: in 8-way steps both ways cost the same 16 cells a side,
	# so the old field could take either; by length A is 17.9 m and B 20.0 m.
	var w := _rooms([[-11.0, 2.4], [1.0, 2.4]], Vector2(-6, 8))
	var id := w.add_enemy(K.SPLITTER, Vector2(-6, -8))
	var got := _chase(w, id, 2.0, 1800)
	assert_gte(int(got[0]), 0, "it reaches the player")
	assert_lt(
		float(got[2]),
		-8.5,
		"through the nearer doorway (A, x -11), not B (x +1): crossed at %s" % got[2]
	)
	# The shortest way through A, to 2 m short of the player, with the body's clearance at the door: ~17 m.
	assert_lt(float(got[1]), 19.0, "about the shortest way: walked %.2f m" % got[1])


func test_an_enemy_behind_a_wall_reaches_a_player_standing_against_it() -> void:
	# The player stands pressed to the partition, in a cell the field blocks (within its 0.6 m clearance). The old
	# flood started from that blocked cell, reached nothing, and every enemy out of sight walked into the wall.
	var y := PARTITION_HALF + 0.36
	var w := _rooms([[6.0, 2.4]], Vector2(-6, y))
	var c := w.nav.cell_of(w.player_pos())
	assert_eq(
		w.nav.blocked[c.y * w.nav.size.x + c.x], 1, "precondition: the player's cell is blocked"
	)
	var id := w.add_enemy(K.SPLITTER, Vector2(-6, -6))
	var got := _chase(w, id, 2.0, 1800)
	assert_gte(int(got[0]), 0, "it goes round through the doorway and reaches the player")
	assert_gt(float(got[2]), 4.0, "through the doorway (x 6)")
	var i := w.actors.index_of(id)
	assert_gt(w.actors.pos(i).y, 0.0, "on the player's side")


func test_a_blocked_goal_seeds_only_its_own_side_of_a_wall() -> void:
	var y := PARTITION_HALF + 0.36
	var w := _rooms([[6.0, 2.4]], Vector2(-6, y))
	w.nav.flood(w.player_pos())
	var here := w.nav.cell_of(Vector2(-6, 1.2))
	var across := w.nav.cell_of(Vector2(-6, -1.2))
	var d_here := w.nav.dist[here.y * w.nav.size.x + here.x]
	var d_across := w.nav.dist[across.y * w.nav.size.x + across.x]
	assert_lt(d_here, 4 * NavField.ORTHO, "the player's side is a step or two away")
	# Across the 0.4 m partition: round through the doorway 12 m away, there and back (> 20 m = 40 sides).
	assert_gt(d_across, 40 * NavField.ORTHO, "the far side of the wall is only reached round it")


func test_the_field_is_the_shortest_octile_path() -> void:
	# Open floor: a cell 6 across and 3 down costs 3 diagonals and 3 sides, not 6 steps.
	var w := _rooms([[0.0, 2.4]], Vector2(-10.25, 6.25))
	w.nav.flood(w.player_pos())
	var g := w.nav.cell_of(w.player_pos())
	var c := g + Vector2i(6, -3)
	assert_eq(w.nav.dist[c.y * w.nav.size.x + c.x], 3 * NavField.DIAG + 3 * NavField.ORTHO)
	var reference := NavField.new()
	reference.build(w.walls)
	reference.flood_reference(w.player_pos())
	assert_eq(w.nav.dist, reference.dist, "the bucketed flood gives the reference's distances")


func test_the_world_flood_stops_past_the_enemies_and_floods_again_for_a_new_one() -> void:
	var w := _rooms([[0.0, 2.4]], Vector2(-14, 6))
	var near := w.add_enemy(K.WARDEN, Vector2(-11, 6))
	w.flood_nav()
	var nav := w.nav
	var far_cell := nav.cell_of(Vector2(14, -6))
	var far_k := far_cell.y * nav.size.x + far_cell.x
	var near_k := nav.target_cell(w.actors.pos(w.actors.index_of(near)))
	assert_lt(nav.dist[near_k], NavField.UNREACHED, "the enemy stands in the field")
	assert_eq(
		nav.dist[far_k],
		NavField.UNREACHED,
		"the far room isn't flooded: the flood stopped past the enemy"
	)
	# The player keeps its cell, but a new enemy stands outside the field: the next flood reaches it.
	w.add_enemy(K.WARDEN, Vector2(14, -6))
	w.flood_nav()
	assert_lt(nav.dist[far_k], NavField.UNREACHED, "flooded again out to the new enemy")
	var planted := nav.dist.duplicate()
	planted[0] = 12345
	nav.dist = planted
	w.flood_nav()
	assert_eq(nav.dist[0], 12345, "same cell and every enemy in the field: not flooded again")


func test_floods_and_chases_are_deterministic() -> void:
	var a := _rooms([[-11.0, 2.4], [1.0, 2.4]], Vector2(-6, 8))
	var b := _rooms([[-11.0, 2.4], [1.0, 2.4]], Vector2(-6, 8))
	for w: World in [a, b]:
		w.add_enemy(K.SPLITTER, Vector2(-6, -8))
		w.add_enemy(K.CHARGER, Vector2(10, -8))
		w.add_enemy(K.SWARMER, Vector2(15, -3))
		for t in 400:
			w.step(InputFrame.new())
			w.actors.hp[0] = w.actors.max_hp[0]
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.nav.dist, b.nav.dist)


## v0.8.0 NF (owner O90, "A then"): a build over NavField.SLICES ticks (begin_build, then advance once a tick) leaves
## the live field alone until it is done, then holds exactly what flood() gives from the same goal, bound and targets
## (and, unbounded with no targets, what flood_reference gives).
func test_a_build_over_slices_equals_the_flood_at_once() -> void:
	var w := _rooms([[-11.0, 2.4], [1.0, 2.4], [13.0, 1.6]], Vector2(-17, 9))
	for at: Vector2 in [Vector2(-6, -8), Vector2(10, -8), Vector2(17, -10), Vector2(16, 9)]:
		w.add_enemy(K.SWARMER, at)
	var targets := PackedInt32Array()
	for i in range(1, w.actors.size()):
		targets.append(w.nav.target_cell(w.actors.pos(i)))
	var cases := [[NavField.WORLD_FLOOD_STEPS, targets], [NavField.UNREACHED, PackedInt32Array()]]
	for c: Array in cases:
		var built := NavField.new()
		built.build(w.walls)
		built.last_work = 150  # small slices: the build takes every one of its ticks
		var at_once := NavField.new()
		at_once.build(w.walls)
		at_once.flood(w.player_pos(), c[0], c[1])
		var live := built.dist.duplicate()
		built.begin_build(w.player_pos(), c[0], c[1])
		var ticks := 0
		while built.building():
			assert_eq(built.dist, live, "the live field is untouched while the build runs")
			built.advance()
			ticks += 1
		assert_eq(ticks, NavField.SLICES, "built over %d ticks" % NavField.SLICES)
		assert_eq(built.dist, at_once.dist, "the build's field is the flood's")
		assert_eq(built.get(&"_flooded"), at_once.get(&"_flooded"), "and its key")
		assert_eq(built.last_work, at_once.last_work, "and its work")
		if (c[1] as PackedInt32Array).is_empty():
			var reference := NavField.new()
			reference.build(w.walls)
			reference.flood_reference(w.player_pos())
			assert_eq(built.dist, reference.dist, "unbounded: the reference's distances")
		# The same goal again: skipped as flood() would skip it.
		built.begin_build(w.player_pos(), c[0], c[1])
		assert_false(built.building(), "same cell and every target reached: no build")


## v0.8.0 NF: the world starts the build on its flood ticks and swaps it in within NavField.SLICES ticks; a wall added
## in play (and every other immediate flood) floods at once and drops the build in progress.
func test_the_world_builds_its_flood_over_ticks_and_a_new_wall_floods_at_once() -> void:
	var w := _rooms([[-11.0, 2.4], [1.0, 2.4]], Vector2(-6, 8))
	w.add_enemy(K.WARDEN, Vector2(10, -8))
	w.add_enemy(K.WARDEN, Vector2(15, -3))
	while w.tick % NavField.PERIOD != 0 or w.nav.never_flooded():
		w.step(InputFrame.new())
	w.nav.last_work = 150  # small slices
	w.actors.set_pos(0, Vector2(-14, 6))  # a new cell: the next flood tick starts a build
	while w.tick % NavField.PERIOD != 0:
		w.step(InputFrame.new())
	w.step(InputFrame.new())
	assert_true(w.nav.building(), "a build in progress after its first slice")
	var key: Vector3i = w.nav.get(&"_flooded")
	var goal := w.nav.cell_of(Vector2(-14, 6))
	assert_ne(Vector2i(key.x, key.y), goal, "the live field is still the old one")
	for t in NavField.SLICES - 1:
		w.step(InputFrame.new())
	assert_false(w.nav.building(), "swapped in within %d ticks" % NavField.SLICES)
	key = w.nav.get(&"_flooded")
	assert_eq(Vector2i(key.x, key.y), goal, "the live field is the new one")
	# A build in progress, then a wall added in play: the field floods at once and the build is dropped.
	w.actors.set_pos(0, Vector2(-6, 8))
	while w.tick % NavField.PERIOD != 0:
		w.step(InputFrame.new())
	w.nav.last_work = 150
	w.step(InputFrame.new())
	assert_true(w.nav.building(), "a build in progress")
	w.add_wall_now(Obb.make(Vector2(-11, 0), Vector2(1.2, PARTITION_HALF), 0))
	assert_false(w.nav.building(), "the new wall drops the build")
	key = w.nav.get(&"_flooded")
	assert_eq(Vector2i(key.x, key.y), w.nav.cell_of(w.player_pos()), "and floods at once")
