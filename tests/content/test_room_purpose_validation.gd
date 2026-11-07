extends GutTest
## v0.11.0 O15 (PLAN P1): the large rooms' purposes (data/rooms/purposes) are found by the scanner, valid, cover every
## biome and name only installed kit pieces; each validation rule catches its mistake (RoomPurposeDefinition).

const BIOMES: Array[StringName] = [
	&"ruins", &"frozen_shore", &"starfall", &"red_canyon", &"night_rocks"
]


func _codes(d: RoomPurposeDefinition) -> Array:
	var out := []
	for i in d.validate():
		out.append(String(i.code))
	return out


## A good purpose: one focal group, one choice, one biome.
func _good() -> RoomPurposeDefinition:
	var d := RoomPurposeDefinition.new()
	d.id = &"test_purpose"
	d.biomes = [&"ruins"]
	var c := RoomPurposeChoice.new()
	c.id = &"pick"
	c.weights = PackedInt32Array([1, 1])
	d.choices = [c]
	var g := RoomPurposeGroup.new()
	g.focal = true
	var p := RoomPurposePart.new()
	p.token = &"fire"
	g.parts.append(p)
	d.groups.append(g)
	var h := RoomPurposeGroup.new()
	h.anchor = Vector2(0.5, 0.5)
	h.choice = &"pick"
	h.options = PackedInt32Array([1])
	var q := RoomPurposePart.new()
	q.token = &"grass"
	h.parts.append(q)
	d.groups.append(h)
	var pal := RoomPurposePalette.new()
	pal.biome = &"ruins"
	for row: Array in [[&"fire", &"fire_barrel", true], [&"grass", &"grass_tuft", false]]:
		var piece := RoomPurposePiece.new()
		piece.token = row[0]
		piece.piece = row[1]
		piece.solid = row[2]
		pal.pieces.append(piece)
	d.palettes = [pal]
	return d


func test_the_shipped_purposes_are_valid_and_cover_every_biome() -> void:
	var repo := ContentRepository.load_all()
	var defs: Array = repo.all_of(&"room_purpose")
	assert_eq(defs.size(), 3, "camp, hall, quarry")
	var biomes := {}
	for d: RoomPurposeDefinition in defs:
		assert_eq(d.validate(), [] as Array[ValidationIssue], "%s is valid" % d.id)
		assert_true(d.resource_path.begins_with("res://data/rooms/purposes/"), d.resource_path)
		for b in d.biomes:
			biomes[b] = true
	for b in BIOMES:
		assert_true(biomes.has(b), "%s has a purpose" % b)


func test_every_piece_a_palette_may_name_is_installed() -> void:
	for piece in RoomPurposeDefinition.PIECES:
		assert_true(KitModels.SPECS.has(piece), "%s is a kit piece" % piece)
	for piece in RoomPurposeDefinition.DECOR:
		assert_true(RoomPurposeDefinition.PIECES.has(piece), "%s may be named" % piece)


func test_a_good_purpose_passes() -> void:
	assert_eq(_codes(_good()), [])


func test_each_rule_catches_its_mistake() -> void:
	var d := _good()
	d.shift_m = 1.0
	assert_has(_codes(d), "range", "a shift of 1 m is too much")
	d = _good()
	d.turn_deg = 15.0
	assert_has(_codes(d), "range", "a turn of 15 degrees is too much")
	d = _good()
	d.groups[0].focal = false
	assert_has(_codes(d), "focal", "no focal group")
	d = _good()
	d.groups[1].options = PackedInt32Array([2])
	assert_has(_codes(d), "choice", "an option out of range")
	d = _good()
	d.groups[1].choice = &"nope"
	assert_has(_codes(d), "choice", "an unknown choice")
	d = _good()
	d.biomes.append(&"starfall")
	assert_has(_codes(d), "palette", "a biome without a palette")
	d = _good()
	d.palettes[0].pieces[1].token = &"other"
	assert_has(_codes(d), "palette", "a token without a piece")
	d = _good()
	d.palettes[0].pieces[0].piece = &"teapot"
	assert_has(_codes(d), "unknown_piece")
	d = _good()
	d.palettes[0].pieces[1].solid = true
	assert_has(_codes(d), "solid_decor")
	d = _good()
	d.palettes[0].pieces[0].solid = false
	assert_has(_codes(d), "floating_tall", "a tall drawn piece on open floor")
	d = _good()
	d.palettes[0].pieces[0].solid = false
	d.palettes[0].pieces[0].lift = 2.5
	assert_does_not_have(_codes(d), "floating_tall", "a lintel rests on its stones")
	d = _good()
	d.min_cells = Vector2i(2, 2)
	assert_has(_codes(d), "range", "a purpose is for large rooms")
