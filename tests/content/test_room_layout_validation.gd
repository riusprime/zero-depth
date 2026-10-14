extends GutTest
## v0.8.0 RT (owner O12): the designed room layouts (data/room_layouts) are found by the scanner, valid, and three of
## every room size (RT1's first three for the owner's G2, RT2's other 21); each validation rule catches its mistake
## (RoomLayoutDefinition.validate).


func _codes(d: RoomLayoutDefinition) -> Array:
	var out := []
	for i in d.validate():
		out.append(String(i.code))
	return out


func _piece(
	piece: StringName, at: Vector2, size: Vector2, solid: bool, yaw: float = 0.0
) -> RoomLayoutPiece:
	var p := RoomLayoutPiece.new()
	p.piece = piece
	p.at = at
	p.size = size
	p.solid = solid
	p.yaw = yaw
	return p


func _layout(pieces: Array) -> RoomLayoutDefinition:
	var d := RoomLayoutDefinition.new()
	d.id = &"room_test"
	d.cells = Vector2i(2, 2)
	var g := RoomLayoutGroup.new()
	g.anchor = Vector2(0.5, 0.5)
	for p: RoomLayoutPiece in pieces:
		g.pieces.append(p)
	d.groups.append(g)
	return d


func test_every_room_size_has_three_valid_layouts() -> void:
	# v0.8.0 RT2 (G2 RT): 3 layouts for each of the 8 sizes (24), each valid, dense and dressed. The small rooms (1 x 1,
	# 2 x 1, 3 x 1) stay fightable with fewer, smaller groups: at least 6 blockers per cell there, 8 elsewhere.
	var repo := ContentRepository.load_all()
	var by_size := {}
	for d: RoomLayoutDefinition in repo.all_of(&"room_layout"):
		assert_eq(d.validate().size(), 0, "%s validates" % d.id)
		assert_true(
			d.resource_path.begins_with("res://data/room_layouts/"), "%s in its folder" % d.id
		)
		assert_eq(
			d.resource_path.get_file(),
			"%dx%d_%s.tres" % [d.cells.x, d.cells.y, String(d.id).get_slice("_", 2)],
			"%s: its file is named by its size" % d.id
		)
		var solids := 0
		var drawn := 0
		for g in d.groups:
			for p in g.pieces:
				if p.solid:
					solids += 1
				else:
					drawn += 1
		var per_cell := 6 if d.cells.y == 1 else 8
		assert_gte(
			solids, per_cell * d.cells.x * d.cells.y, "%s is dense: %d blockers" % [d.id, solids]
		)
		assert_gt(drawn, solids, "%s is dressed: %d drawn pieces" % [d.id, drawn])
		assert_gt(d.keep_clear.size(), 0, "%s keeps an open lane" % d.id)
		if not by_size.has(d.cells):
			by_size[d.cells] = []
		(by_size[d.cells] as Array).append(String(d.id))
	var sizes := [
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(3, 1),
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(3, 3),
		Vector2i(4, 3),
		Vector2i(4, 4)
	]
	assert_eq(by_size.size(), sizes.size(), "every room size and no other")
	for c: Vector2i in sizes:
		var ids: Array = by_size.get(c, [])
		ids.sort()
		var want := []
		for n in 3:
			want.append("room_%dx%d_%d" % [c.x, c.y, n + 1])
		assert_eq(ids, want, "three layouts of %d x %d" % [c.x, c.y])


func test_a_good_cluster_passes() -> void:
	var d := _layout(
		[
			_piece(&"slab_concrete", Vector2.ZERO, Vector2(2, 2), true),
			_piece(&"crate_stack", Vector2(1.6, 0), Vector2(1.2, 1.2), true),  # touching
			_piece(&"rock_large", Vector2(-4.0, 0), Vector2(1.2, 1.2), true),  # a 2.4 m lane
			_piece(&"wall_pillar", Vector2(0, 0.3), Vector2(0.8, 0.8), false, 30.0),  # on the slab
			_piece(&"grass_tuft", Vector2(4, 4), Vector2(0.5, 0.5), false),  # decoration anywhere
		]
	)
	assert_eq(_codes(d), [])


func test_each_rule_catches_its_mistake() -> void:
	var cases := {
		"unknown_piece": [_piece(&"tank", Vector2.ZERO, Vector2.ONE, true)],
		"floating_tall": [_piece(&"dead_tree", Vector2.ZERO, Vector2.ONE, false)],
		"solid_decor": [_piece(&"grass_tuft", Vector2.ZERO, Vector2.ONE, true)],
		"solid_turned": [_piece(&"crate_stack", Vector2.ZERO, Vector2.ONE, true, 45.0)],
		"slit":
		[
			_piece(&"crate_stack", Vector2.ZERO, Vector2(1, 1), true),
			_piece(&"crate_stack", Vector2(2.0, 0), Vector2(1, 1), true),  # a 1.0 m slit
		],
	}
	for code: String in cases:
		assert_has(_codes(_layout(cases[code])), code, code)
	# A slit the group's other solids fill is no slit; a 0.5 m gap is shut to the player.
	var filled := _layout(
		[
			_piece(&"crate_stack", Vector2.ZERO, Vector2(1, 1), true),
			_piece(&"crate_stack", Vector2(2.0, 0), Vector2(1, 1), true),
			_piece(&"crate_stack", Vector2(1.0, 0), Vector2(1, 1), true),
		]
	)
	assert_eq(_codes(filled), [])
	var shut := _layout(
		[
			_piece(&"crate_stack", Vector2.ZERO, Vector2(1, 1), true),
			_piece(&"crate_stack", Vector2(1.5, 0), Vector2(1, 1), true),
		]
	)
	assert_eq(_codes(shut), [])
	var wide := _layout([_piece(&"crate_stack", Vector2.ZERO, Vector2.ONE, true)])
	wide.cells = Vector2i(2, 3)
	assert_has(_codes(wide), "range", "the long side comes first")
	var off := _layout([_piece(&"crate_stack", Vector2.ZERO, Vector2.ONE, true)])
	off.groups[0].anchor = Vector2(1.2, 0.5)
	off.keep_clear.append(Rect2i(500, 500, 700, 200))
	assert_eq(_codes(off).count("range"), 2, "the anchor and the lane stay inside the room")
	var empty := RoomLayoutDefinition.new()
	empty.id = &"room_empty"
	assert_has(_codes(empty), "empty")
