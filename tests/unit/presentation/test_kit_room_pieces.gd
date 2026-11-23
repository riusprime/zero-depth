extends GutTest
## The owner's sixteen room pieces (OWNER_TODO §3.6; cut by scripts/assets/rooms_v0120_prep.py): each loads at its
## own proportions (its spec's footprint), and each stands where it was placed: the camp, the collapsed hall and the
## quarry name theirs in their palettes, the Ruins draws its four from its pools, and Frozen Shore's sea floats the ice
## floe.

const PLACED := {
	"res://data/rooms/purposes/camp.tres": [&"camp_tent", &"log_seat", &"cook_pot"],
	"res://data/rooms/purposes/hall.tres":
	[&"statue_whole", &"statue_broken", &"column_round", &"column_drum"],
	"res://data/rooms/purposes/quarry.tres":
	[&"quarry_crane", &"mine_cart", &"stone_block", &"tool_rack"],
}
const RUINS_POOLS := {
	&"cover_square": &"cable_spool",
	&"cover_long": &"dumpster",
	&"wall_prop": [&"metal_post", &"sign_frame"],
}


func after_each() -> void:
	KitModels.clear_cache()


func _all_ids() -> Array[StringName]:
	var out: Array[StringName] = [
		&"metal_post", &"dumpster", &"cable_spool", &"sign_frame", &"ice_floe"
	]
	for ids: Array in PLACED.values():
		for id: StringName in ids:
			out.append(id)
	return out


func test_every_piece_loads_at_its_own_footprint() -> void:
	var ids := _all_ids()
	assert_eq(ids.size(), 16)
	for id: StringName in ids:
		var spec: Dictionary = KitModels.SPECS.get(id, {})
		assert_true(spec.has("foot"), "%s has its footprint" % id)
		var piece := KitModels.get_piece(id)
		assert_false(piece.is_empty(), "%s loads" % id)
		if piece.is_empty() or not spec.has("foot"):
			continue
		var size: Vector3 = piece["size"]
		var foot: Vector2 = spec["foot"]
		# The footprint is the model's own (scaled evenly), so the spec's foot matches the loaded size.
		assert_almost_eq(size.x, foot.x, 0.02, "%s: its length is its footprint's" % id)
		assert_almost_eq(size.z, foot.y, 0.02, "%s: its depth is its footprint's" % id)
		assert_lt(size.y, 4.01, "%s: no taller than the tallest request row" % id)


func test_the_purpose_rooms_name_their_pieces() -> void:
	for path: String in PLACED:
		var d := load(path) as RoomPurposeDefinition
		var named := {}
		for pal: RoomPurposePalette in d.palettes:
			for p: RoomPurposePiece in pal.pieces:
				named[p.piece] = true
				if KitModels.SPECS.has(p.piece) and p.piece in PLACED[path]:
					assert_true(p.solid, "%s %s's %s is solid" % [path, pal.biome, p.token])
		for id: StringName in PLACED[path]:
			assert_true(named.has(id), "%s draws %s" % [path, id])
			assert_has(RoomPurposeDefinition.PIECES, id, "%s may be named by a palette" % id)


func test_the_stand_ins_are_gone_where_the_pieces_came() -> void:
	var hall := load("res://data/rooms/purposes/hall.tres") as RoomPurposeDefinition
	var quarry := load("res://data/rooms/purposes/quarry.tres") as RoomPurposeDefinition
	for pal: RoomPurposePalette in hall.palettes:
		for p: RoomPurposePiece in pal.pieces:
			assert_ne(
				p.piece, &"wall_pillar", "hall %s's %s: not the square pier" % [pal.biome, p.token]
			)
	for pal: RoomPurposePalette in quarry.palettes:
		for p: RoomPurposePiece in pal.pieces:
			assert_false(
				p.piece in [&"wagon_wreck", &"slab_concrete"],
				"quarry %s's %s: not a stand-in" % [pal.biome, p.token]
			)


func test_the_ruins_draws_its_four_from_its_pools() -> void:
	var look := (load("res://data/biomes/ruins.tres") as BiomeDefinition).look
	for role: StringName in RUINS_POOLS:
		var want: Variant = RUINS_POOLS[role]
		for id: StringName in want if want is Array else [want]:
			assert_true((look.pools[role] as Dictionary).has(id), "Ruins %s draws %s" % [role, id])
	assert_eq(look.problems(), PackedStringArray(), "the Ruins look stays valid")


func test_the_frozen_sea_floats_the_owners_floe() -> void:
	var edge := BiomeEdge.new()
	add_child_autofree(edge)
	edge.build(&"water", [Rect2(-10, -10, 20, 20)], Rect2(-10, -10, 20, 20), Color("#436C8E"), 3)
	assert_gt(edge.floe_count, 0)
	assert_same(
		edge.floes.multimesh.mesh, KitModels.get_piece(&"ice_floe")["mesh"], "the owner's slab"
	)
	assert_same(
		edge.floes.material_override,
		KitModels.get_piece(&"ice_floe")["material"],
		"in its own colours"
	)
