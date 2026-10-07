extends GutTest
## v0.2.0 B, floor v2 (PLAN L14-L15): the seeded floor generator is deterministic, and every floor is whole. A floor
## has 10-12 rooms: a 3 x 3-cell start hall with no partitions and one exit, then rooms with footprints from the
## allowed set, without overlaps, joined by doorways. Every room, item spot, spawn point and the gate's front is
## reachable from the start; spots keep their clearance; item counts follow the rule (none in the hall, 1 in a
## 1 x 1 room, 1-2 in bigger rooms); the portal room is the farthest.

const SEEDS := 50
const PLAYER_RADIUS := 0.35
const ALLOWED: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(1, 2),
	Vector2i(3, 1),
	Vector2i(1, 3),
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(2, 3),
	Vector2i(3, 3),
]


func _signature(f: FloorLayout) -> Array:
	var walls := []
	for w in f.walls:
		walls.append([w.center, w.half, w.angle])
	return [
		walls,
		f.slab_first,
		f.rooms,
		f.room_cells,
		f.room_template,
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
	return f.bounds


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


func test_shape_of_a_floor() -> void:
	var f := FloorGenerator.generate(5)
	var n := f.room_count()
	assert_between(n, 10, 12)
	assert_eq(f.room_cells.size(), n)
	assert_eq(f.room_template.size(), n)
	assert_eq(f.spawn_points.size(), n)
	assert_eq(f.hops.size(), n)
	assert_eq(f.start_room, 0)
	assert_eq(f.room_cells[0].size, Vector2i(3, 3), "the start hall is 3 x 3 cells")
	# A tree (n - 1 doorways) plus up to 2 extra.
	assert_between(f.door_rooms.size(), n - 1, n + 1)
	# The grid pitch is the drawn cell size plus the mean wall (0.3 + 1.5 m); each room side is pulled in from
	# its grid line by its own drawn half.
	var p := FloorParams.defaults()
	var pitch := f.cell_size + Vector2(1.8, 1.8)
	assert_eq(f.cell_pitch, pitch)
	assert_eq(f.room_halves.size(), n * 4)
	for room in n:
		var cells := Vector2(f.room_cells[room].size)
		var h := f.room_halves.slice(room * 4, room * 4 + 4)
		for half in h:
			assert_between(half, p.wall_half_min, p.wall_half_max)
		assert_almost_eq(f.rooms[room].size.x, cells.x * pitch.x - h[0] - h[2], 0.001)
		assert_almost_eq(f.rooms[room].size.y, cells.y * pitch.y - h[1] - h[3], 0.001)
	assert_almost_eq(f.bounds.get_center().x, 0.0, 0.001, "the floor is centred on the origin")
	assert_almost_eq(f.bounds.get_center().y, 0.0, 0.001)
	for i in range(f.slab_first, f.walls.size()):
		assert_eq(f.walls[i].angle % 512, 0)


func test_fifty_floors_are_whole() -> void:
	var total_us := 0
	var max_us := 0
	var pieces := 0
	var rooms := 0
	var spots := 0
	var templates := {}
	var hall_sides := {}
	var footprints := {}
	for s in SEEDS:
		var seed_value := 1000 + s * 7919
		var t0 := Time.get_ticks_usec()
		var f := FloorGenerator.generate(seed_value)
		var us := Time.get_ticks_usec() - t0
		total_us += us
		max_us = maxi(max_us, us)
		pieces += f.walls.size() - f.slab_first
		rooms += f.room_count()
		spots += f.item_spots.size()
		for t in f.room_template:
			templates[t] = true
		for room in range(1, f.room_count()):
			footprints[f.room_cells[room].size] = true
		hall_sides[_hall_exit_side(f)] = true
		_check_floor(f, "seed %d" % seed_value)
	assert_gte(templates.size(), 7, "at least 7 of the 9 interior templates across 50 floors")
	assert_true(templates.has(FloorLayout.Template.COLONNADE), "the colonnade shows up")
	assert_true(templates.has(FloorLayout.Template.DIAGONALS), "the diagonals show up")
	assert_eq(hall_sides.size(), 4, "the hall's exit is on every side across 50 floors")
	assert_gte(footprints.size(), 6, "the footprints vary")
	var names := PackedStringArray()
	for t in templates:
		names.append(FloorLayout.TEMPLATE_NAMES[t])
	names.sort()
	(
		gut
		. p(
			(
				(
					"floor generation: %d floors, mean %.1f ms, max %.1f ms, %.2f rooms, %.2f item spots, %.1f interior"
					+ " pieces per floor; templates seen: %s; footprints seen: %d"
				)
				% [
					SEEDS,
					total_us / 1000.0 / SEEDS,
					max_us / 1000.0,
					float(rooms) / SEEDS,
					float(spots) / SEEDS,
					float(pieces) / SEEDS,
					", ".join(names),
					footprints.size()
				]
			)
		)
	)


## The side (0 +X, 1 +Y, 2 -X, 3 -Y) of the hall its one doorway is on.
func _hall_exit_side(f: FloorLayout) -> int:
	for d in f.door_rooms.size():
		if f.door_rooms[d].x == 0:
			return f.door_angles[d] / 1024
	return -1


func _check_floor(f: FloorLayout, tag: String) -> void:
	var n := f.room_count()
	assert_between(n, 10, 12, tag + ": 10-12 rooms")
	_check_grid(f, tag)
	_check_enclosed(f, tag)
	assert_ne(f.start_room, f.portal_room, tag)
	assert_eq(f.start_room, 0, tag)
	assert_eq(f.neighbours(0).size(), 1, tag + ": the hall has one exit")
	var far := 0
	for h in f.hops:
		assert_gte(h, 0, tag + ": every room has a doorway path")
		far = maxi(far, h)
	assert_eq(f.hops[f.portal_room], far, tag + ": the portal room is the farthest")
	for w in f.walls:
		assert_eq(
			Collide.circle_vs_obb(f.start_pos, 1.0, w), Vector2.ZERO, tag + ": the start is clear"
		)
	for i in f.door_centers.size():
		for w in f.walls:
			assert_eq(
				Collide.circle_vs_obb(f.door_centers[i], PLAYER_RADIUS, w),
				Vector2.ZERO,
				tag + ": doorway %d is open" % i
			)
	for i in range(f.slab_first, f.walls.size()):
		var b := f.walls[i].bounds()
		assert_ne(f.room_of(b.get_center()), -1, tag + ": an interior piece stands in a room")
		assert_true(f.rooms[f.room_of(b.get_center())].encloses(b), tag)
	# Walkable at an enemy's clearance (stricter than the player's) and at the player's radius: every room's open
	# floor is the start's region, so every room is reachable and nothing is cut off.
	var nav := FloorReach.new()
	nav.build(_interior(f), f.walls, FloorParams.defaults().nav_clearance)
	_check_rooms_reachable(f, nav, tag + " (enemy)")
	for i in f.door_centers.size():
		assert_eq(nav.region_at(f.door_centers[i]), nav.region_at(f.start_pos), tag)
	var reach := FloorReach.new()
	reach.build(_interior(f), f.walls, PLAYER_RADIUS)
	_check_rooms_reachable(f, reach, tag + " (player)")
	_check_spots(f, reach, tag)
	_check_portal(f, reach, tag)


func _check_grid(f: FloorLayout, tag: String) -> void:
	assert_eq(f.room_cells[0].size, Vector2i(3, 3), tag + ": the hall is 3 x 3 cells")
	assert_lte(f.cols, 8, tag)
	assert_lte(f.rows, 8, tag)
	for room in range(1, f.room_count()):
		assert_true(f.room_cells[room].size in ALLOWED, tag + ": footprint %s" % f.room_cells[room])
	for a in f.room_count():
		for b in range(a + 1, f.room_count()):
			assert_false(f.room_cells[a].intersects(f.room_cells[b]), tag + ": rooms overlap")
			assert_false(f.rooms[a].intersects(f.rooms[b]), tag)
	# No partition inside the hall: no structural wall reaches into its interior.
	var hall := f.rooms[0].grow(-0.01)
	for i in f.slab_first:
		assert_false(f.walls[i].bounds().intersects(hall), tag + ": a wall inside the hall")


## Every room is walled all round, but at its doorways: points every 0.25 m around the room just outside its wall
## faces, and along each side as deep as that side's drawn half, lie inside a structural wall unless they are in a
## doorway's passage.
func _check_enclosed(f: FloorLayout, tag: String) -> void:
	for room in f.room_count():
		var r := f.rooms[room]
		var pts := PackedVector2Array()
		for depth in 2:
			for side in 4:
				var d := 0.15 if depth == 0 else f.room_halves[room * 4 + side] - 0.02
				# Just outside the faces the band runs round the corners; deep in the wall it runs along the face.
				var band := r.grow(d)
				var span := band if depth == 0 else r
				var along_x := side % 2 == 1
				var n := int((span.size.x if along_x else span.size.y) / 0.25)
				for i in n + 1:
					var t := float(i) / n
					var x := span.position.x + span.size.x * t
					var y := span.position.y + span.size.y * t
					match side:
						0:
							pts.append(Vector2(band.end.x, y))
						1:
							pts.append(Vector2(x, band.end.y))
						2:
							pts.append(Vector2(band.position.x, y))
						3:
							pts.append(Vector2(x, band.position.y))
		for q in pts:
			var in_door := false
			for i in f.door_centers.size():
				if f.door_rect(i).grow(0.01).has_point(q):
					in_door = true
			if in_door:
				continue
			var walled := false
			for i in f.slab_first:
				if Collide.circle_vs_obb(q, 0.01, f.walls[i]) != Vector2.ZERO:
					walled = true
					break
			if not walled:
				assert_true(false, "%s: room %d is open at %s" % [tag, room, q])
				return


func _check_rooms_reachable(f: FloorLayout, reach: FloorReach, tag: String) -> void:
	var home := reach.region_at(f.start_pos)
	assert_gte(home, 0, tag)
	var free := PackedInt32Array()
	free.resize(f.room_count())
	for k in reach.size.x * reach.size.y:
		if reach.region[k] < 0:
			continue
		var room := f.room_of(reach.center(Vector2i(k % reach.size.x, k / reach.size.x)))
		if room < 0:
			continue
		free[room] += 1
		if reach.region[k] != home:
			assert_true(false, "%s: room %d has a cell cut off from the start" % [tag, room])
			return
	for room in f.room_count():
		assert_gt(free[room], 0, tag + ": room %d has open floor" % room)


func _check_spots(f: FloorLayout, reach: FloorReach, tag: String) -> void:
	var home := reach.region_at(f.start_pos)
	var per_room := PackedInt32Array()
	per_room.resize(f.room_count())
	for i in f.item_spots.size():
		var q := f.item_spots[i]
		per_room[f.item_rooms[i]] += 1
		assert_eq(reach.region_at(q), home, tag + ": item spot reachable")
		assert_eq(f.room_of(q), f.item_rooms[i], tag + ": item spot in its room")
		_assert_clear(f, q, 1.0, tag + ": item spot clear")
		if i > 0 and f.item_rooms[i - 1] == f.item_rooms[i]:
			assert_gte(q.distance_to(f.item_spots[i - 1]), 4.0, tag + ": a room's two spots apart")
		if i > 0:
			assert_lte(f.item_rooms[i - 1], f.item_rooms[i], tag + ": spots grouped in room order")
	assert_eq(per_room[0], 0, tag + ": no item in the start hall")
	for room in range(1, f.room_count()):
		if f.room_cell_count(room) == 1:
			assert_eq(per_room[room], 1, tag + ": a 1 x 1 room has 1 item spot")
		else:
			assert_between(per_room[room], 1, 2, tag + ": a bigger room has 1-2 item spots")
	var p := FloorParams.defaults()
	for room in f.room_count():
		var pts := f.spawn_points[room]
		var cells := f.room_cell_count(room)
		var lo := mini(p.spawn_cap, p.spawn_min + p.spawn_min_per_extra_cell * (cells - 1))
		var hi := mini(p.spawn_cap, p.spawn_max + p.spawn_max_per_extra_cell * (cells - 1))
		assert_between(pts.size(), lo, hi, tag + ": spawn points in room %d" % room)
		for q in pts:
			assert_eq(reach.region_at(q), home, tag + ": spawn point reachable")
			assert_eq(f.room_of(q), room, tag)
			_assert_clear(f, q, 0.9, tag + ": spawn point clear")


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
	var gate := FloorScenario.gate_collider(f)
	assert_true(
		f.rooms[f.portal_room].grow(0.01).encloses(gate.bounds()), tag + ": the gate fits its wall"
	)
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
	# Cross-check with the enemies' own NavField (8-way regions, 0.6 m clearance, the gate included) on a few
	# seeds, and time its build and flood on these bigger floors.
	var build_us := 0
	var flood_us := 0
	var cells := 0
	var seeds := [3, 41, 2026, 7, 99]
	for s: int in seeds:
		var f := FloorGenerator.generate(s)
		var walls: Array[Obb] = f.walls.duplicate()
		walls.append(FloorScenario.gate_collider(f))
		var nav := NavField.new()
		var t0 := Time.get_ticks_usec()
		nav.build(walls)
		build_us += Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		nav.flood(f.start_pos)
		flood_us += Time.get_ticks_usec() - t0
		cells += nav.size.x * nav.size.y
		var home := nav.region_near(f.start_pos)
		assert_gte(home, 0)
		for room in f.room_count():
			for q in f.spawn_points[room]:
				assert_eq(nav.region_near(q), home, "seed %d room %d" % [s, room])
				assert_lt(
					nav.dist[nav.cell_of(q).y * nav.size.x + nav.cell_of(q).x], NavField.UNREACHED
				)
		for q in f.item_spots:
			assert_eq(nav.region_near(q), home, "seed %d item" % s)
		assert_eq(nav.region_near(f.portal_front_point()), home, "seed %d gate" % s)
	gut.p(
		(
			"nav field on %d floors: mean %d cells, build %.1f ms, flood %.1f ms"
			% [
				seeds.size(),
				cells / seeds.size(),
				build_us / 1000.0 / seeds.size(),
				flood_us / 1000.0 / seeds.size()
			]
		)
	)


func test_fast_nav_field_matches_the_reference() -> void:
	# The bounded build and the adjacency flood give exactly what the every-wall-every-cell build and the original
	# flood give: on a generated floor, and on an arena with rotated slabs.
	var f := FloorGenerator.generate(11)
	var floor_walls: Array[Obb] = f.walls.duplicate()
	floor_walls.append(FloorScenario.gate_collider(f))
	var arena: Array[Obb] = [
		Obb.make(Vector2(0, -12), Vector2(12, 0.5), 0),
		Obb.make(Vector2(0, 12), Vector2(12, 0.5), 0),
		Obb.make(Vector2(-12, 0), Vector2(0.5, 12), 0),
		Obb.make(Vector2(12, 0), Vector2(0.5, 12), 0),
		Obb.make(Vector2(3.1, 2.2), Vector2(2.0, 0.25), 512),
		Obb.make(Vector2(-4.0, -3.3), Vector2(1.6, 0.3), 1536),
		Obb.make(Vector2(-1.0, 5.5), Vector2(0.6, 0.6), 300),
		Obb.make(Vector2(6.0, -6.0), Vector2(3.0, 0.25), 1024),
	]
	for case: Array in [
		[floor_walls, [f.start_pos, f.portal_front_point()]], [arena, [Vector2(0.2, 0.1)]]
	]:
		var walls: Array[Obb] = case[0]
		var fast := NavField.new()
		fast.build(walls)
		var ref := NavField.new()
		ref.build_reference(walls)
		assert_eq(fast.size, ref.size)
		assert_eq(fast.origin, ref.origin)
		assert_eq(fast.blocked, ref.blocked, "blocked cells match")
		assert_eq(fast.region, ref.region, "regions match")
		for goal: Vector2 in case[1]:
			fast.flood(goal)
			ref.flood_reference(goal)
			assert_eq(fast.dist, ref.dist, "distances match")


func test_layout_helpers() -> void:
	var f := FloorGenerator.generate(9)
	assert_eq(f.room_of(f.start_pos), f.start_room)
	assert_eq(f.room_of(Vector2(1.0e6, 0.0)), -1)
	for i in f.door_rooms.size():
		var d := f.door_rooms[i]
		assert_lt(d.x, d.y)
		assert_true(d.y in f.neighbours(d.x))
		assert_true(d.x in f.neighbours(d.y))
		assert_eq(f.door_angles[i] % 1024, 0)
		# The doorway joins the two rooms: a step either way from its centre, out of its passage, lands in each.
		var step := Kin.dir(f.door_angles[i]) * (f.door_depths[i] * 0.5 + 0.5)
		assert_eq(f.room_of(f.door_centers[i] - step), d.x)
		assert_eq(f.room_of(f.door_centers[i] + step), d.y)


func test_fill_order_puts_first_spots_first() -> void:
	var f := FloorLayout.new()
	f.item_spots = PackedVector2Array([Vector2(1, 0), Vector2(2, 0), Vector2(3, 0), Vector2(4, 0)])
	f.item_rooms = PackedInt32Array([1, 1, 2, 3])
	assert_eq(FloorScenario.spot_order(f), PackedInt32Array([0, 2, 3, 1]))


## v0.3.0 L1-L2: walls are 0.6-3.0 m thick (a doorway's depth is the wall's thickness there), doorways are
## 2.2-3.4 m wide and lie anywhere along the stretch both rooms share, clear of their corners, and the cell size
## is drawn per floor. Across 50 floors every one of these varies over most of its range.
func test_walls_and_doorways_vary_within_their_ranges() -> void:
	var p := FloorParams.defaults()
	var depth := Vector2(INF, -INF)
	var width := Vector2(INF, -INF)
	var cell_x := Vector2(INF, -INF)
	var cell_y := Vector2(INF, -INF)
	var off_centre := 0
	var doors := 0
	for s in SEEDS:
		var f := FloorGenerator.generate(1000 + s * 7919)
		var tag := "seed %d" % (1000 + s * 7919)
		cell_x = Vector2(minf(cell_x.x, f.cell_size.x), maxf(cell_x.y, f.cell_size.x))
		cell_y = Vector2(minf(cell_y.x, f.cell_size.y), maxf(cell_y.y, f.cell_size.y))
		assert_between(f.cell_size.x, p.cell_size_min.x, p.cell_size_max.x, tag)
		assert_between(f.cell_size.y, p.cell_size_min.y, p.cell_size_max.y, tag)
		for i in f.door_rooms.size():
			doors += 1
			var d := f.door_rooms[i]
			assert_between(f.door_depths[i], 0.6 - 0.001, 3.0 + 0.001, tag + ": wall thickness")
			assert_between(
				f.door_widths[i], p.door_width_min, p.door_width_max, tag + ": door width"
			)
			depth = Vector2(minf(depth.x, f.door_depths[i]), maxf(depth.y, f.door_depths[i]))
			width = Vector2(minf(width.x, f.door_widths[i]), maxf(width.y, f.door_widths[i]))
			# The passage lies within both rooms' faces along the wall, door_corner_margin in from their ends.
			var g := f.door_rect(i)
			var along_x := f.door_angles[i] % 2048 == 1024
			for room in [d.x, d.y]:
				var r := f.rooms[room]
				var lo := (r.position.x if along_x else r.position.y) + p.door_corner_margin - 0.006
				var hi := (r.end.x if along_x else r.end.y) - p.door_corner_margin + 0.006
				assert_gte(
					g.position.x if along_x else g.position.y, lo, tag + ": door clear of a corner"
				)
				assert_lte(g.end.x if along_x else g.end.y, hi, tag + ": door clear of a corner")
			# The passage runs from one room's face to the other's.
			assert_true(f.rooms[d.x].grow(0.01).intersects(g), tag)
			assert_true(f.rooms[d.y].grow(0.01).intersects(g), tag)
			var shared := f.rooms[d.x].intersection(f.rooms[d.y].grow(4.0))
			var mid := shared.get_center().x if along_x else shared.get_center().y
			if absf((g.get_center().x if along_x else g.get_center().y) - mid) > 1.0:
				off_centre += 1
		# Every structural wall is a box in a room's frame or skin: never thicker than one half.
		for i in f.slab_first:
			var thin := minf(f.walls[i].half.x, f.walls[i].half.y) * 2.0
			assert_between(thin, p.wall_half_min - 0.001, p.wall_half_max + 0.001, tag)
	(
		gut
		. p(
			(
				(
					"walls and doorways over %d floors (%d doorways): wall thickness at doorways %.2f-%.2f m, door width"
					+ " %.2f-%.2f m, %d doorways more than 1 m off the middle of the shared stretch; cell size x %.2f-%.2f m,"
					+ " y %.2f-%.2f m"
				)
				% [
					SEEDS,
					doors,
					depth.x,
					depth.y,
					width.x,
					width.y,
					off_centre,
					cell_x.x,
					cell_x.y,
					cell_y.x,
					cell_y.y
				]
			)
		)
	)
	assert_lt(depth.x, 1.2, "some walls are thin")
	assert_gt(depth.y, 2.4, "some walls are thick")
	assert_lt(width.x, 2.5)
	assert_gt(width.y, 3.1)
	assert_gt(off_centre, doors / 4, "doorways are not all centred")
	assert_gt(cell_x.y - cell_x.x, 2.0, "the cell size varies per floor")
	assert_gt(cell_y.y - cell_y.x, 1.2)
