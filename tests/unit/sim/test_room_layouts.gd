extends GutTest
## v0.8.0 RT (owner O12, "3 hand-designed layouts per room size … turned and mirrored, so every floor differs"): the
## generator places the designed layouts (data/room_layouts) on the run's floors. Turns and mirrors map a layout onto
## its room; every group of every layout fits a bare room of a typical size in every turn and mirror, its blockers out
## of the layout's open lanes; and over many run floors with the layouts in use every floor stays whole: every room
## reachable at an enemy's clearance and the player's, doorways open and their approach boxes free of blockers, the
## start, the gate, item spots and spawn points clear; all 24 layouts (v0.8.0 RT2: three of every room size), all four
## turns and both mirrors show up; the same seed gives the same floor. A room whose doorways leave little of its layout
## standing is checked like any other (the per-size kept shares are printed).

const SEEDS := 60
const PLAYER_RADIUS := 0.35

var _params: FloorParams


func before_all() -> void:
	_params = RunSaver.floor_tables(null, ContentRepository.load_all())[&"map"]


func test_turns_and_mirrors_map_the_frame_onto_the_room() -> void:
	var r := Rect2(10, 20, 30, 20)
	assert_eq(RoomLayouts.frame_size(r, 0), Vector2(30, 20))
	assert_eq(RoomLayouts.frame_size(r, 1), Vector2(20, 30))
	# The frame's corner (0, 0) and its +x end, in each turn: a quarter turn is (x, y) -> (-y, x).
	var corner := [Vector2(10, 20), Vector2(40, 20), Vector2(40, 40), Vector2(10, 40)]
	var along := [Vector2(40, 20), Vector2(40, 40), Vector2(10, 40), Vector2(10, 20)]
	for t in 4:
		var s := RoomLayouts.frame_size(r, t)
		assert_eq(RoomLayouts.to_room(Vector2.ZERO, r, t), corner[t], "turn %d: the corner" % t)
		assert_eq(RoomLayouts.to_room(Vector2(s.x, 0), r, t), along[t], "turn %d: +x" % t)
		assert_eq(RoomLayouts.angle_in_room(0, t, false), t * 1024, "turn %d: a piece's angle" % t)
	assert_eq(RoomLayouts.angle_in_room(0, 0, true), 2048, "a mirror flips +x")
	assert_eq(RoomLayouts.angle_in_room(1024, 0, true), 1024, "and keeps +y")
	assert_eq(RoomLayouts.angle_in_room(512, 1, true), 2560)
	assert_eq(RoomLayouts.turns_for(Vector2i(2, 2)), PackedInt32Array([0, 1, 2, 3]))
	assert_eq(RoomLayouts.turns_for(Vector2i(3, 2)), PackedInt32Array([0, 2]))
	assert_eq(RoomLayouts.turns_for(Vector2i(2, 3)), PackedInt32Array([1, 3]))
	assert_eq(RoomLayouts.key(Vector2i(2, 3)), Vector2i(3, 2))
	# A mirrored group's anchor and pieces flip along the frame's x.
	var g := RoomLayoutTable.Group.new()
	g.anchor = Vector2i(250, 500)
	var p := RoomLayoutTable.Piece.new()
	p.piece = &"crate_stack"
	p.at = Vector2i(100, 0)
	p.size = Vector2i(100, 100)
	p.solid = true
	g.pieces.append(p)
	var plain: Array[Obb] = RoomLayouts.place_group(g, r, 0, false)["solids"]
	var flipped: Array[Obb] = RoomLayouts.place_group(g, r, 0, true)["solids"]
	assert_eq(plain[0].center, Vector2(10 + 7.5 + 1.0, 30))
	assert_eq(flipped[0].center, Vector2(10 + 22.5 - 1.0, 30))


## A bare room of `size` (interior at the origin) framed by four walls, no doorway, no start or gate.
func _bare_room(cells: Vector2i, size: Vector2) -> FloorLayout:
	var f := FloorLayout.new()
	var r := Rect2(Vector2.ZERO, size)
	f.rooms.append(r)
	f.room_cells.append(Rect2i(Vector2i.ZERO, cells))
	f.start_room = -1
	f.portal_room = -1
	for w: Rect2 in [
		Rect2(-1, -1, size.x + 2, 1),
		Rect2(-1, size.y, size.x + 2, 1),
		Rect2(-1, 0, 1, size.y),
		Rect2(size.x, 0, 1, size.y)
	]:
		f.walls.append(Obb.make(w.get_center(), w.size * 0.5, 0))
	f.slab_first = f.walls.size()
	return f


func test_every_group_fits_a_typical_room_in_every_turn_and_mirror() -> void:
	# A typical room: the middle of the drawn cell sizes and wall halves (FloorParams), per axis.
	var p := FloorParams.defaults()
	var pitch := (
		(p.cell_size_min + p.cell_size_max) * 0.5
		+ Vector2.ONE * (p.wall_half_min + p.wall_half_max)
	)
	var halves := p.wall_half_min + p.wall_half_max
	for key: Vector2i in _params.room_layouts:
		for t: RoomLayoutTable in _params.room_layouts[key]:
			var solids := 0
			for g in t.groups:
				for piece in g.pieces:
					solids += 1 if piece.solid else 0
			for turn in RoomLayouts.turns_for(key) if key.x == key.y else PackedInt32Array([0, 1]):
				var cells := key if turn % 2 == 0 else Vector2i(key.y, key.x)
				var size := Vector2(cells) * pitch - Vector2.ONE * halves
				for mirror in 2:
					var f := _bare_room(cells, size)
					f.room_layout.append(t.id)
					f.room_turn.append(turn)
					f.room_mirror.append(mirror)
					FloorGenerator._furnish_layout(f, _params, 0, f.room_walls(0))
					var tag := (
						"%s turn %d mirror %d in %.1f x %.1f m"
						% [t.id, turn, mirror, size.x, size.y]
					)
					assert_eq(f.walls.size() - f.slab_first, solids, tag + ": every blocker kept")
					_assert_lanes_open(f, t, turn, mirror == 1, tag)
					assert_true(
						FloorReach.whole(
							f.rooms[0], f.walls, p.nav_clearance, PackedVector2Array()
						),
						tag + ": one region"
					)
					if turn == 0 and mirror == 0:
						var area := 0.0
						for i in range(f.slab_first, f.walls.size()):
							area += f.walls[i].half.x * f.walls[i].half.y * 4.0
						gut.p(
							(
								"%s: %d groups, %d blockers (%.1f%% of the floor), %d drawn pieces"
								% [
									tag,
									t.groups.size(),
									solids,
									area * 100.0 / f.rooms[0].get_area(),
									f.layout_props.size()
								]
							)
						)


func _assert_lanes_open(
	f: FloorLayout, t: RoomLayoutTable, turn: int, mirror: bool, tag: String
) -> void:
	var r := f.rooms[0]
	var s := RoomLayouts.frame_size(r, turn)
	for k in t.keep_clear:
		var a := Vector2(k.position) / 1000.0 * s
		var b := Vector2(k.end) / 1000.0 * s
		if mirror:
			a.x = s.x - a.x
			b.x = s.x - b.x
		var p := RoomLayouts.to_room(a, r, turn)
		var q := RoomLayouts.to_room(b, r, turn)
		var lane := Rect2(p, Vector2.ZERO).expand(q)
		for i in range(f.slab_first, f.walls.size()):
			assert_false(f.walls[i].bounds().intersects(lane), tag + ": the open lane is open")


func test_run_floors_with_designed_rooms_are_whole() -> void:
	var seen := {}
	var turns := {}
	var mirrors := {}
	var designed := 0
	var rooms := 0
	var kept := 0
	var drawn := 0
	var by_size := {}  # layout key -> [rooms, blockers kept, blockers drawn, rooms keeping under half]
	for s in SEEDS:
		var seed_value := 7000 + s * 7919
		var f := FloorGenerator.generate(seed_value, _params)
		var tag := "seed %d" % seed_value
		rooms += f.room_count()
		for room in f.room_count():
			var id := f.layout_of(room)
			if id == &"":
				continue
			designed += 1
			seen[id] = true
			var cells := f.room_cells[room].size
			assert_ne(room, f.start_room, tag)
			assert_ne(room, f.portal_room, tag)
			assert_eq(
				RoomLayouts.key(cells), _table(id).cells, tag + ": a layout of the room's size"
			)
			assert_true(
				f.room_turn[room] in RoomLayouts.turns_for(cells), tag + ": a turn that fits"
			)
			if cells.x == cells.y:
				turns[f.room_turn[room]] = true
			mirrors[f.room_mirror[room]] = true
			_assert_door_boxes_free(f, room, tag)
			var room_drawn := 0
			var room_kept := 0
			for g in _table(id).groups:
				for piece in g.pieces:
					room_drawn += 1 if piece.solid else 0
			for i in range(f.slab_first, f.walls.size()):
				if (
					f.room_of(f.walls[i].bounds().get_center()) == room
					and f.piece_height(f.walls[i]) >= 0.0
				):
					room_kept += 1
			drawn += room_drawn
			kept += room_kept
			var k := RoomLayouts.key(cells)
			var row: Array = by_size.get(k, [0, 0, 0, 0])
			by_size[k] = [
				row[0] + 1,
				row[1] + room_kept,
				row[2] + room_drawn,
				row[3] + (1 if room_kept * 2 < room_drawn else 0)
			]
		_check_whole(f, tag)
	assert_eq(seen.size(), 24, "all 24 layouts show up")
	assert_eq(turns.size(), 4, "a square layout in all four turns")
	assert_eq(mirrors.size(), 2, "mirrored and not")
	assert_gt(kept * 100, drawn * 60, "most of a layout survives its room's doorways")
	gut.p(
		(
			"designed rooms: %d of %d rooms over %d floors; %d of %d layout blockers kept (%.0f%%)"
			% [designed, rooms, SEEDS, kept, drawn, kept * 100.0 / maxi(drawn, 1)]
		)
	)
	var keys := by_size.keys()
	keys.sort()
	assert_eq(keys.size(), 8, "designed rooms of every size")
	for k: Vector2i in keys:
		var row: Array = by_size[k]
		gut.p(
			(
				"  %d x %d: %d rooms, %d of %d blockers kept (%.0f%%); %d rooms kept under half"
				% [k.x, k.y, row[0], row[1], row[2], row[1] * 100.0 / maxi(row[2], 1), row[3]]
			)
		)


func _table(id: StringName) -> RoomLayoutTable:
	for key: Vector2i in _params.room_layouts:
		for t: RoomLayoutTable in _params.room_layouts[key]:
			if t.id == id:
				return t
	return null


func _assert_door_boxes_free(f: FloorLayout, room: int, tag: String) -> void:
	for box in FloorGenerator._door_boxes(f, _params, room):
		for i in range(f.slab_first, f.walls.size()):
			if f.room_of(f.walls[i].bounds().get_center()) == room:
				assert_false(
					f.walls[i].bounds().intersects(box), tag + ": a doorway's approach is free"
				)


## The floor checks of test_floor_generator, at an enemy's clearance and the player's radius.
func _check_whole(f: FloorLayout, tag: String) -> void:
	for w in f.walls:
		assert_eq(Collide.circle_vs_obb(f.start_pos, 1.0, w), Vector2.ZERO, tag + ": start clear")
	for i in f.door_centers.size():
		for w in f.walls:
			assert_eq(
				Collide.circle_vs_obb(f.door_centers[i], PLAYER_RADIUS, w),
				Vector2.ZERO,
				tag + ": doorway %d open" % i
			)
	for i in range(f.slab_first, f.walls.size()):
		var b := f.walls[i].bounds()
		var room := f.room_of(b.get_center())
		assert_ne(room, -1, tag + ": a piece stands in a room")
		assert_true(f.rooms[room].grow(0.01).encloses(b), tag + ": inside its room")
	for clearance: float in [_params.nav_clearance, PLAYER_RADIUS]:
		var reach := FloorReach.new()
		reach.build(f.bounds, f.walls, clearance)
		var home := reach.region_at(f.start_pos)
		assert_gte(home, 0, tag)
		var open := PackedInt32Array()
		open.resize(f.room_count())
		for k in reach.size.x * reach.size.y:
			if reach.region[k] < 0:
				continue
			var room := f.room_of(reach.center(Vector2i(k % reach.size.x, k / reach.size.x)))
			if room < 0:
				continue
			open[room] += 1
			if reach.region[k] != home:
				assert_true(
					false, "%s: room %d has floor cut off at %.2f m" % [tag, room, clearance]
				)
				return
		for room in f.room_count():
			assert_gt(open[room], 0, tag + ": room %d has open floor" % room)
		for q in f.item_spots:
			assert_eq(reach.region_at(q), home, tag + ": item spot reachable")
		for pts in f.spawn_points:
			for q in pts:
				assert_eq(reach.region_at(q), home, tag + ": spawn point reachable")
		assert_eq(reach.region_at(f.portal_front_point()), home, tag + ": the gate reachable")
	for q in f.item_spots:
		for w in f.walls:
			assert_eq(Collide.circle_vs_obb(q, 1.0, w), Vector2.ZERO, tag + ": item spot clear")
	for w in f.walls:
		assert_false(w.bounds().intersects(f.portal_front()), tag + ": the gate's front clear")


func test_the_same_seed_gives_the_same_designed_floor() -> void:
	for s in [5, 2026]:
		var a := FloorGenerator.generate(s, _params)
		var b := FloorGenerator.generate(s, _params)
		var wa := []
		var wb := []
		for w in a.walls:
			wa.append([w.center, w.half, w.angle])
		for w in b.walls:
			wb.append([w.center, w.half, w.angle])
		assert_eq(wa, wb, "seed %d: the same walls" % s)
		assert_eq(a.room_layout, b.room_layout)
		assert_eq(a.room_turn, b.room_turn)
		assert_eq(a.room_mirror, b.room_mirror)
		assert_eq(a.layout_props, b.layout_props)
		assert_eq(a.piece_tags, b.piece_tags)
		assert_eq(a.piece_heights, b.piece_heights)
		assert_eq(a.item_spots, b.item_spots)


func test_without_layouts_the_floor_is_the_rule_built_one() -> void:
	# A floor built without layouts (a save from before RT) makes no layout draw: the same as before RT.
	var bare := FloorParams.defaults()
	assert_true(bare.room_layouts.is_empty(), "no layouts by default")
	for s in [11, 3003]:
		var f := FloorGenerator.generate(s, bare)
		for room in f.room_count():
			assert_eq(f.layout_of(room), &"", "seed %d: rule-built" % s)
		assert_eq(f.layout_props.size(), 0)
		assert_eq(f.piece_heights.size(), 0)
		var with := FloorGenerator.generate(s, _params)
		assert_eq(with.door_centers, f.door_centers, "seed %d: the same rooms and doorways" % s)
		assert_eq(with.room_template, f.room_template, "and the same templates drawn")
