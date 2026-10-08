extends GutTest
## Themed rooms (v0.5.9 L8), as properties over generated floors: every themed piece names a kit piece the game
## has; car wrecks stay within the cap (2 per 352 m² of floor, at least 1); every piece either touches a structural
## wall exactly or keeps the slab gap from it (no slits); bigger rooms get more vignettes; the same seed gives the
## same tags.

const SEEDS := 200


func _room_walls(f: FloorLayout) -> Array[Obb]:
	var out: Array[Obb] = []
	for i in f.slab_first:
		out.append(f.walls[i])
	return out


## Clusters of themed pieces in a room that touch each other (a vignette's pieces touch), as footprint rects.
func _clusters(rects: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var used := {}
	for i in rects.size():
		if used.has(i):
			continue
		var foot := rects[i]
		var grew := true
		used[i] = true
		while grew:
			grew = false
			for j in rects.size():
				if not used.has(j) and FloorGenerator._rect_gap(foot, rects[j]) <= 0.005:
					foot = foot.merge(rects[j])
					used[j] = true
					grew = true
		out.append(foot)
	return out


func test_pieces_are_tagged_capped_and_flush_or_spaced() -> void:
	var p := FloorParams.defaults()
	var small_pieces := 0.0
	var small_rooms := 0
	var big_pieces := 0.0
	var big_rooms := 0
	for s in SEEDS:
		var seed_value := 3000 + s * 13
		var f := FloorGenerator.generate(seed_value)
		var structural := _room_walls(f)
		var per_room := {}
		var cars := {}
		var rects := {}
		for i in range(f.slab_first, f.walls.size()):
			var w := f.walls[i]
			var tag := f.piece_tag(w)
			var room := f.room_of(w.center)
			if room < 0 or not RoomThemes.is_themed(f.room_template[room]):
				continue
			assert_true(
				KitModels.SPECS.has(tag),
				"seed %d: piece tagged %s is a kit piece" % [seed_value, tag]
			)
			per_room[room] = int(per_room.get(room, 0)) + 1
			if not rects.has(room):
				rects[room] = [] as Array[Rect2]
			rects[room].append(w.bounds())
			if tag == RoomThemes.CAR:
				cars[room] = int(cars.get(room, 0)) + 1
		for room: int in rects:
			# A footprint either touches a wall lining the room or keeps the slab gap from it: no slit.
			for foot in _clusters(rects[room]):
				for sw in structural:
					var wb := sw.bounds()
					if FloorGenerator._rect_gap(wb, f.rooms[room]) > 0.005:
						continue
					var d := FloorGenerator._rect_gap(foot, wb)
					if d > 0.005 and d < p.slab_gap - 0.005:
						fail_test(
							(
								"seed %d room %d: a footprint sits %.2f m from a wall (a slit)"
								% [seed_value, room, d]
							)
						)
						return
		for room: int in cars:
			assert_lte(cars[room], RoomThemes.car_cap(f.rooms[room].get_area()), "car cap")
		for room in f.room_count():
			if not RoomThemes.is_themed(f.room_template[room]):
				continue
			var area := f.rooms[room].get_area()
			if area < 200.0:
				small_pieces += per_room.get(room, 0)
				small_rooms += 1
			elif area > 500.0:
				big_pieces += per_room.get(room, 0)
				big_rooms += 1
	assert_gt(small_rooms, 0)
	assert_gt(big_rooms, 0)
	assert_gt(small_pieces / small_rooms, 1.0, "small rooms are furnished too")
	assert_gt(big_pieces / big_rooms, small_pieces / small_rooms, "bigger rooms hold more")
	gut.p(
		(
			"pieces per themed room: small %.1f, big %.1f"
			% [small_pieces / small_rooms, big_pieces / big_rooms]
		)
	)


func test_the_same_seed_gives_the_same_tags() -> void:
	var a := FloorGenerator.generate(4242)
	var b := FloorGenerator.generate(4242)
	assert_eq(a.piece_tags, b.piece_tags)
	assert_gt(a.piece_tags.size(), 0, "a floor has themed pieces")


func test_counts_scale_with_area() -> void:
	assert_eq(RoomThemes.count_for(352.0), 8, "the mockup rooms' size")
	assert_eq(RoomThemes.car_cap(352.0), 2, "2 cars in a room of the mockups' size")
	assert_eq(RoomThemes.car_cap(120.0), 1, "at least 1")
	assert_eq(RoomThemes.car_cap(704.0), 4, "twice the floor, twice the cars")
	assert_eq(RoomThemes.count_for(10.0), RoomThemes.MIN_VIGNETTES)
