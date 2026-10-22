extends GutTest
## v0.8.0 SR (owner O13): the shop rooms (data/shop_rooms), one per biome, are found by the scanner, valid and dressed;
## each validation rule catches its mistake (ShopRoomDefinition.validate); the shop's own pieces are not kit pieces a
## designed room may name.


func _codes(d: RoomLayoutDefinition) -> Array:
	var out := []
	for i in d.validate():
		out.append(String(i.code))
	return out


func _piece(piece: StringName, at: Vector2, size: Vector2, solid: bool) -> RoomLayoutPiece:
	var p := RoomLayoutPiece.new()
	p.piece = piece
	p.at = at
	p.size = size
	p.solid = solid
	return p


## A good shop room: the owner's stall's footprint, goods on its counter, one crate cluster.
func _shop() -> ShopRoomDefinition:
	var d := ShopRoomDefinition.new()
	d.id = &"shop_test"
	d.biome = &"ruins"
	d.stall = RoomLayoutGroup.new()
	d.stall.pieces.append(_piece(&"shop_counter", Vector2(0, -1.25), Vector2(4.0, 0.9), true))
	d.stall.pieces.append(_piece(&"shop_tent", Vector2(0, 0.45), Vector2(4.0, 2.5), true))
	d.stall.pieces.append(_piece(&"shop_wares", Vector2(0.5, -1.25), Vector2(1.0, 0.6), false))
	var g := RoomLayoutGroup.new()
	g.anchor = Vector2(0.0, 1.0)
	g.pieces.append(_piece(&"crate_stack", Vector2(0.6, -0.6), Vector2(1.2, 1.2), true))
	g.pieces.append(_piece(&"shop_sack", Vector2(0.6, -0.6), Vector2(0.5, 0.5), false))
	d.groups.append(g)
	return d


func test_every_biome_ships_its_valid_shop_room() -> void:
	var repo := ContentRepository.load_all()
	var run: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	var biomes := []
	for d: ShopRoomDefinition in repo.all_of(&"shop_room"):
		assert_eq(d.validate().size(), 0, "%s validates: %s" % [d.id, d.validate()])
		assert_true(
			d.resource_path.begins_with("res://data/shop_rooms/"), "%s in its folder" % d.id
		)
		assert_eq(d.id, StringName("shop_%s" % d.biome), "named for its biome")
		assert_not_null(repo.get_def(&"biomes", d.biome), "%s names a real biome" % d.id)
		biomes.append(d.biome)
		var solids := 0
		var drawn := 0
		var lights := 0
		for g in d.groups:
			for p in g.pieces:
				solids += 1 if p.solid else 0
				drawn += 0 if p.solid else 1
				lights += 1 if p.piece in [&"shop_lantern", &"fire_barrel", &"brazier_pole"] else 0
		assert_gt(d.groups.size(), 3, "%s: groups round the stall" % d.id)
		assert_gt(solids, 10, "%s: dressed with %d blockers" % [d.id, solids])
		assert_gt(drawn, solids, "%s: %d drawn pieces" % [d.id, drawn])
		assert_gte(lights, 3, "%s: warm lights" % d.id)
	for b in run.biomes:
		assert_has(biomes, b, "the run's biome %s has a shop room" % b)
	assert_eq(biomes.size(), run.biomes.size(), "one per biome")
	assert_eq(
		repo.all_of(&"room_layout").filter(
			func(d: ContentDef) -> bool: return d is ShopRoomDefinition
		),
		[],
		"not among the designed rooms"
	)


func test_a_good_shop_room_passes() -> void:
	assert_eq(_codes(_shop()), [])


func test_each_rule_catches_its_mistake() -> void:
	var no_biome := _shop()
	no_biome.biome = &""
	assert_has(_codes(no_biome), "empty", "a biome")
	var no_stall := _shop()
	no_stall.stall = null
	assert_has(_codes(no_stall), "empty", "a stall")
	var no_counter := _shop()
	no_counter.stall.pieces.remove_at(0)
	assert_has(_codes(no_counter), "stall", "a counter")
	var behind := _shop()
	behind.stall.pieces[0].at = Vector2(0, 1.25)
	behind.stall.pieces[1].at = Vector2(0, -0.45)
	assert_has(_codes(behind), "stall", "the counter in front")
	var small := _shop()
	small.stall.pieces[1].size = Vector2(4.0, 2.0)
	assert_has(_codes(small), "stall", "the art list's size")
	var spot := _shop()
	spot.stall_spots = [Vector2(1.2, 0.5)]
	assert_has(_codes(spot), "range", "a spot in the room")
	var narrow := _shop()
	narrow.approach = Vector2(2.0, 3.0)
	assert_has(_codes(narrow), "range", "an approach as wide as the stall")
	var stray := _shop()
	stray.groups[0].pieces.append(_piece(&"shop_tent", Vector2(4, -4), Vector2(1, 1), true))
	assert_has(_codes(stray), "stall_piece", "the tent goes in the stall")
	var unknown := _shop()
	unknown.groups[0].pieces.append(_piece(&"shop_tank", Vector2(4, -4), Vector2(1, 1), true))
	assert_has(_codes(unknown), "unknown_piece")
	var floating := _shop()
	floating.groups[0].pieces.append(_piece(&"shop_wares", Vector2(5, -5), Vector2(1, 0.6), false))
	assert_has(_codes(floating), "floating_tall", "goods stand on a solid")


func test_a_designed_room_cannot_name_the_shops_pieces() -> void:
	var d := RoomLayoutDefinition.new()
	d.id = &"room_test"
	var g := RoomLayoutGroup.new()
	g.pieces.append(_piece(&"shop_tent", Vector2.ZERO, Vector2(3, 2.2), true))
	d.groups.append(g)
	assert_has(_codes(d), "unknown_piece")
