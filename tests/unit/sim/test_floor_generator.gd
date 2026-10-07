extends GutTest
## v0.2.0 B (PLAN L5): the seeded floor generator is deterministic, and every floor is whole: every room, item
## spot, spawn point and the gate's front is reachable from the start, and spots keep their clearance.

const SEEDS := 50
const PLAYER_RADIUS := 0.35


func _signature(f: FloorLayout) -> Array:
	var walls := []
	for w in f.walls:
		walls.append([w.center, w.half, w.angle])
	return [
		walls,
		f.slab_first,
		f.rooms,
		f.door_rooms,
		f.door_centers,
		f.door_angles,
		f.start_room,
		f.portal_room,
		f.start_pos,
		f.portal_pos,
		f.portal_angle,
		f.item_spots,
		f.item_rooms,
		f.spawn_points,
		f.bounds,
	]


func _interior(f: FloorLayout) -> Rect2:
	var hw := FloorParams.defaults().wall_half
	return f.bounds.grow(-hw)


func test_same_seed_same_floor() -> void:
	for s in [1, 77, 123456]:
		var a := FloorGenerator.generate(s, FloorParams.defaults())
		var b := FloorGenerator.generate(s)
		assert_eq(_signature(a), _signature(b), "seed %d" % s)


func test_different_seeds_differ() -> void:
	var seen := {}
	for s in 10:
		seen[str(_signature(FloorGenerator.generate(s + 1)))] = true
	assert_eq(seen.size(), 10, "10 seeds gave 10 different floors")


func test_shape_of_the_default_floor() -> void:
	var f := FloorGenerator.generate(5)
	assert_eq(f.room_count(), 9)
	assert_eq(f.spawn_points.size(), 9)
	assert_eq(f.hops.size(), 9)
	# A spanning tree (8 links) plus 1-2 extra.
	assert_between(f.door_rooms.size(), 9, 10)
	for r in f.rooms:
		assert_almost_eq(r.size.x, 14.0, 0.001)
		assert_almost_eq(r.size.y, 12.0, 0.001)
	for i in range(f.slab_first, f.walls.size()):
		var w := f.walls[i]
		assert_almost_eq(w.half.y, 0.25, 0.001)
		assert_between(w.half.x, 1.2, 2.0)
		assert_eq(w.angle % 512, 0)


func test_fifty_floors_are_whole() -> void:
	var total_us := 0
	var slabs := 0
	for s in SEEDS:
		var seed_value := 1000 + s * 7919
		var t0 := Time.get_ticks_usec()
		var f := FloorGenerator.generate(seed_value)
		total_us += Time.get_ticks_usec() - t0
		slabs += f.walls.size() - f.slab_first
		_check_floor(f, "seed %d" % seed_value)
	gut.p(
		(
			"floor generation: %d floors, mean %.1f ms, %d slabs (%.2f per room)"
			% [SEEDS, total_us / 1000.0 / SEEDS, slabs, slabs / (SEEDS * 9.0)]
		)
	)


func _check_floor(f: FloorLayout, tag: String) -> void:
	var n := f.room_count()
	assert_ne(f.start_room, f.portal_room, tag)
	assert_true(f.start_room in [0, f.cols - 1, n - f.cols, n - 1], tag + ": start is a corner")
	var far := 0
	for h in f.hops:
		assert_gte(h, 0, tag + ": every room has a doorway path")
		far = maxi(far, h)
	assert_eq(f.hops[f.portal_room], far, tag + ": the portal room is the farthest")
	assert_eq(f.item_spots.size(), n - 1, tag + ": one item spot per room but the start")
	assert_false(f.start_room in f.item_rooms, tag)
	for w in f.walls:
		assert_eq(
			Collide.circle_vs_obb(f.start_pos, 1.0, w), Vector2.ZERO, tag + ": the start is clear"
		)
	# One walkable region over the whole floor, at an enemy's clearance (stricter than the player's).
	var nav := FloorReach.new()
	nav.build(_interior(f), f.walls, FloorParams.defaults().nav_clearance)
	assert_eq(nav.region_count, 1, tag + ": the floor is one region for an enemy")
	# And at the player's radius, where every spot's own cell is free.
	var reach := FloorReach.new()
	reach.build(_interior(f), f.walls, PLAYER_RADIUS)
	assert_eq(reach.region_count, 1, tag + ": the floor is one region for the player")
	var home := reach.region_at(f.start_pos)
	assert_eq(home, 0, tag)
	for i in f.item_spots.size():
		var q := f.item_spots[i]
		assert_eq(reach.region_at(q), home, tag + ": item spot reachable")
		assert_eq(f.room_of(q), f.item_rooms[i], tag + ": item spot in its room")
		_assert_clear(f, q, 1.0, tag + ": item spot clear")
	for room in n:
		var spots := f.spawn_points[room]
		assert_between(spots.size(), 6, 10, tag + ": spawn points in room %d" % room)
		for q in spots:
			assert_eq(reach.region_at(q), home, tag + ": spawn point reachable")
			assert_eq(f.room_of(q), room, tag)
			_assert_clear(f, q, 0.9, tag + ": spawn point clear")
	_check_portal(f, reach, tag)


func _assert_clear(f: FloorLayout, q: Vector2, radius: float, msg: String) -> void:
	for w in f.walls:
		if Collide.circle_vs_obb(q, radius, w) != Vector2.ZERO:
			assert_true(false, "%s at %s" % [msg, q])
			return


func _check_portal(f: FloorLayout, reach: FloorReach, tag: String) -> void:
	assert_eq(f.room_of(f.portal_pos), f.portal_room, tag + ": the gate stands in the portal room")
	assert_eq(f.portal_angle % 1024, 0, tag + ": the gate faces a grid axis")
	var front := f.portal_front()
	assert_true(
		f.rooms[f.portal_room].encloses(front), tag + ": the front square is inside the room"
	)
	for w in f.walls:
		assert_false(w.bounds().intersects(front), tag + ": nothing stands in front of the gate")
	assert_eq(
		reach.region_at(f.portal_front_point()),
		reach.region_at(f.start_pos),
		tag + ": gate reachable"
	)
	# The gate's back is against a wall face.
	var back := f.portal_pos - f.portal_facing() * (FloorLayout.GATE_HALF_DEPTH + 0.05)
	assert_eq(f.room_of(back), -1, tag + ": the gate is against a wall")
	# No item or spawn spot under the gate or in front of it.
	for q in f.item_spots:
		assert_false(front.has_point(q), tag)
	for q in f.spawn_points[f.portal_room]:
		assert_false(front.has_point(q), tag)


func test_every_room_is_reachable_with_the_nav_field() -> void:
	# Cross-check with the enemies' own NavField (8-way regions, 0.6 m clearance) on a few seeds.
	for s in [3, 41, 2026]:
		var f := FloorGenerator.generate(s)
		var nav := NavField.new()
		nav.build(f.walls)
		var home := nav.region_near(f.start_pos)
		assert_gte(home, 0)
		for room in f.room_count():
			for q in f.spawn_points[room]:
				assert_eq(nav.region_near(q), home, "seed %d room %d" % [s, room])
		for q in f.item_spots:
			assert_eq(nav.region_near(q), home, "seed %d item" % s)
		assert_eq(nav.region_near(f.portal_front_point()), home, "seed %d gate" % s)


func test_layout_helpers() -> void:
	var f := FloorGenerator.generate(9)
	assert_eq(f.room_of(f.start_pos), f.start_room)
	assert_eq(f.room_of(Vector2(1.0e6, 0.0)), -1)
	for i in f.door_rooms.size():
		var d := f.door_rooms[i]
		assert_lt(d.x, d.y)
		assert_true(d.y in f.neighbours(d.x))
		assert_true(d.x in f.neighbours(d.y))
		# The doorway is open: a player fits through its centre.
		for w in f.walls:
			assert_eq(Collide.circle_vs_obb(f.door_centers[i], PLAYER_RADIUS, w), Vector2.ZERO)
