extends GutTest
## The boss room in the layout (v0.3.0 PLAN L4, B): BossRoomBuilder.attach over 200+ seeds keeps every layout
## invariant: the room sits on free cells off the farthest room, is walled all round but at its one door, holds the
## gate, is reachable through the door and cut off once the door's collider is in, and leaves the rest of the floor
## as generated. Other sizes and templates (C's BossDefinition.arena) keep the room whole.

const SEEDS := 200


func _seed(s: int) -> int:
	return 5000 + s * 7919


func _floor(seed_value: int, spec: BossArenaSpec = null) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(f, spec)
	return f


func test_same_seed_same_boss_room() -> void:
	var a := _floor(77)
	var b := _floor(77)
	assert_eq(a.room_cells, b.room_cells)
	assert_eq(a.boss_door_center, b.boss_door_center)
	assert_eq(a.portal_pos, b.portal_pos)
	assert_eq(a.walls.size(), b.walls.size())


func test_the_rest_of_the_floor_is_as_generated() -> void:
	for s in 20:
		var plain := FloorGenerator.generate(_seed(s))
		var f := _floor(_seed(s))
		var tag := "seed %d" % _seed(s)
		assert_eq(f.room_count(), plain.room_count() + 1, tag + ": one room more")
		for room in plain.room_count():
			assert_eq(f.room_cells[room], plain.room_cells[room], tag)
			assert_eq(f.rooms[room], plain.rooms[room], tag)
		assert_eq(f.item_spots, plain.item_spots, tag + ": the item spots are untouched")
		assert_eq(f.boss_host_room, plain.portal_room, tag + ": it opens off the farthest room")


func test_two_hundred_boss_rooms_keep_the_layout_whole() -> void:
	var hosts_moved := 0
	var sides := {}
	var t0 := Time.get_ticks_usec()
	for s in SEEDS:
		var f := _floor(_seed(s))
		if f.boss_host_room != _old_portal_room(f):
			hosts_moved += 1
		sides[f.boss_door_angle] = true
		_check(f, "seed %d" % _seed(s))
		if is_failing():
			return
	(
		gut
		. p(
			(
				"boss rooms: %d seeds, %.1f ms per floor (generate + attach + checks), %d hosted off another room"
				% [SEEDS, (Time.get_ticks_usec() - t0) / 1000.0 / SEEDS, hosts_moved]
			)
		)
	)
	assert_eq(sides.size(), 4, "the boss door faces every way across the seeds")


func test_other_sizes_and_templates() -> void:
	var specs: Array[BossArenaSpec] = [
		BossArenaSpec.make(Vector2i(3, 1), FloorLayout.Template.LINES),
		BossArenaSpec.make(Vector2i(2, 2), FloorLayout.Template.PILLARS),
		BossArenaSpec.make(Vector2i(3, 3), FloorLayout.Template.PILLARS),
		BossArenaSpec.make(Vector2i(1, 1), FloorLayout.Template.OPEN),
	]
	var pieces := 0
	for k in specs.size():
		for s in 30:
			var f := _floor(_seed(s), specs[k])
			var cells := f.room_cells[f.boss_room].size
			assert_true(
				cells == specs[k].cells or cells == Vector2i(specs[k].cells.y, specs[k].cells.x),
				"the room has the spec's size (or turned)"
			)
			assert_eq(f.room_template[f.boss_room], specs[k].template)
			for w in f.walls.slice(f.slab_first):
				if f.rooms[f.boss_room].encloses(w.bounds()):
					pieces += 1
			_check(f, "spec %d seed %d" % [k, _seed(s)])
			if is_failing():
				return
	assert_gt(pieces, 0, "pillar templates put pieces in the boss room")


func _check(f: FloorLayout, tag: String) -> void:
	var boss := f.boss_room
	assert_eq(boss, f.room_count() - 1, tag + ": the boss room is the last room")
	assert_eq(f.portal_room, boss, tag + ": the gate is in the boss room")
	assert_eq(f.room_template.size(), f.room_count(), tag)
	assert_eq(f.spawn_points.size(), f.room_count(), tag)
	assert_eq(f.spawn_points[boss].size(), 0, tag + ": no normal spawns in the boss room")
	assert_eq(f.hops[boss], f.hops[f.boss_host_room] + 1, tag)
	assert_eq(
		f.neighbours(boss), PackedInt32Array([f.boss_host_room]), tag + ": one door, to the host"
	)
	for a in f.room_count():
		for b in range(a + 1, f.room_count()):
			assert_false(f.room_cells[a].intersects(f.room_cells[b]), tag + ": rooms overlap")
	assert_true(f.bounds.encloses(f.rooms[boss]), tag + ": the bounds hold the boss room")
	_check_enclosed(f, [f.boss_host_room, boss], tag)
	var gate := _gate(f)
	var all: Array[Obb] = f.walls.duplicate()
	all.append(gate)
	# The host and the boss room (the generator's own tests cover the host's link to the start): the host's first
	# other doorway stands for "the rest of the floor".
	var host := f.boss_host_room
	var area := f.rooms[host].merge(f.rooms[boss]).grow(1.0)
	var reach := FloorReach.new()
	reach.build(area, all, 0.6)
	var home := reach.region_at(_other_door_approach(f, host))
	assert_gte(home, 0, tag)
	var into := Kin.dir(f.boss_door_angle)
	var approach := f.boss_door_center - into * 1.6
	var inside := f.boss_door_center + into * 1.6
	assert_eq(
		reach.region_at(approach), home, tag + ": the boss door is reachable from the host's doors"
	)
	assert_eq(reach.region_at(inside), home, tag + ": the door is open before you enter")
	assert_eq(reach.region_at(f.portal_front_point()), home, tag + ": the gate is reachable")
	assert_eq(reach.region_at(f.boss_spawn), home, tag + ": the boss stands on open floor")
	assert_eq(f.room_of(f.boss_spawn), boss, tag)
	for w in all:
		assert_eq(
			Collide.circle_vs_obb(f.boss_spawn, 1.5, w), Vector2.ZERO, tag + ": the boss has room"
		)
	for w in f.walls:
		assert_false(w.bounds().intersects(f.portal_front()), tag + ": the gate's front is clear")
	assert_true(f.rooms[boss].grow(0.01).encloses(gate.bounds()), tag + ": the gate fits its wall")
	var back := f.portal_pos - f.portal_facing() * (FloorLayout.GATE_HALF_DEPTH + 0.05)
	assert_eq(f.room_of(back), -1, tag + ": the gate's back is against a wall")
	assert_lt(f.portal_facing().dot(into), -0.9, tag + ": the gate faces the door across the room")
	# Sealed: with the door's collider in, the boss room is cut off from the rest of the floor.
	all.append(f.boss_door_wall)
	var sealed := FloorReach.new()
	sealed.build(area, all, 0.35)
	assert_ne(
		sealed.region_at(inside),
		sealed.region_at(approach),
		tag + ": the sealed door shuts the boss room"
	)
	assert_eq(sealed.region_at(f.boss_spawn), sealed.region_at(inside), tag)
	assert_eq(sealed.region_at(f.portal_front_point()), sealed.region_at(inside), tag)


## Every room's wall band is solid but at its doorways (the boss door is wider).
func _check_enclosed(f: FloorLayout, rooms: Array, tag: String) -> void:
	var hw := FloorParams.defaults().wall_half
	for room: int in rooms:
		var band := f.rooms[room].grow(hw)
		var near: Array[Obb] = []
		for i in f.slab_first:
			if f.walls[i].bounds().intersects(band.grow(0.1)):
				near.append(f.walls[i])
		var pts := PackedVector2Array()
		var nx := int(band.size.x / 0.25)
		var ny := int(band.size.y / 0.25)
		for i in nx + 1:
			var x := band.position.x + band.size.x * i / nx
			pts.append(Vector2(x, band.position.y))
			pts.append(Vector2(x, band.end.y))
		for j in ny + 1:
			var y := band.position.y + band.size.y * j / ny
			pts.append(Vector2(band.position.x, y))
			pts.append(Vector2(band.end.x, y))
		for q in pts:
			var in_door := false
			for d in f.door_centers.size():
				var c := f.door_centers[d]
				var half := (
					BossRoomBuilder.DOOR_WIDTH * 0.5
					if d == f.door_centers.size() - 1
					else FloorParams.defaults().door_width * 0.5
				)
				if absf(q.x - c.x) <= half + 0.01 and absf(q.y - c.y) <= half + 0.01:
					in_door = true
			if in_door:
				continue
			var walled := false
			for w in near:
				if Collide.circle_vs_obb(q, 0.01, w) != Vector2.ZERO:
					walled = true
					break
			if not walled:
				assert_true(false, "%s: room %d is open at %s" % [tag, room, q])
				return


func _gate(f: FloorLayout) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(f.portal_pos, half, f.portal_angle)


## The farthest room of the plain floor (the generator's portal room): the most hops, lowest index on a tie.
func _old_portal_room(f: FloorLayout) -> int:
	var best := 0
	for i in f.boss_room:
		if f.hops[i] > f.hops[best]:
			best = i
	return best


## A point just inside `room` at its first doorway that isn't the boss door.
func _other_door_approach(f: FloorLayout, room: int) -> Vector2:
	for d in f.door_rooms.size() - 1:
		var dr := f.door_rooms[d]
		if dr.x != room and dr.y != room:
			continue
		var into := Kin.dir(f.door_angles[d])  # from dr.x into dr.y
		var sign := 1.0 if dr.y == room else -1.0
		return f.door_centers[d] + into * sign * 1.6
	return f.rooms[room].get_center()
