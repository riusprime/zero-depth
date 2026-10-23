extends GutTest
## v0.9.0 RG (PLAN W73, W74): the special-room schema (data/special_rooms, SpecialRoomDefinition).
## - Every kind the floor places has one file, found by the scanner (ContentRepository), valid, its ids the census's
##   kinds (RoomCensus.KINDS), its orders 1..12 once each.
## - The numbers it repeats equal their sources (ContentValidator's cross_check finds none differing), and a changed
##   number or a missing source is caught.
## - What it says of the code is the code's own: each `code` names a static function of a class, each stream is the
##   string that function's class draws from, the spawn spots and cells are the code's constants.
## - Each validation rule catches its mistake.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _defs() -> Array[SpecialRoomDefinition]:
	var out: Array[SpecialRoomDefinition] = []
	for k in RoomCensus.KINDS:
		out.append(_repo.get_def(&"special_rooms", k) as SpecialRoomDefinition)
	return out


func _all() -> Array[ContentDef]:
	var out: Array[ContentDef] = []
	for p in _repo.paths:
		var d := load(p) as ContentDef
		if d != null:
			out.append(d)
	return out


func _codes(issues: Array[ValidationIssue]) -> Array:
	var out := []
	for i in issues:
		out.append(String(i.code))
	return out


func test_every_kind_has_one_valid_file() -> void:
	var orders := []
	for d in _defs():
		assert_not_null(d, "a file for each kind")
		if d == null:
			continue
		assert_eq(d.validate().size(), 0, "%s is valid: %s" % [d.id, _codes(d.validate())])
		orders.append(d.order)
	orders.sort()
	assert_eq(orders, range(1, RoomCensus.KINDS.size() + 1), "orders 1..12 once each")
	var n := 0
	for p in _repo.paths:
		if p.begins_with("res://data/special_rooms/"):
			n += 1
	assert_eq(n, RoomCensus.KINDS.size(), "no file for a kind the floor doesn't place")


func test_the_repeated_numbers_equal_their_sources() -> void:
	var all := _all()
	var issues := SpecialRoomDefinition.cross_check(all)
	assert_eq(issues.size(), 0, "no number differs: %s" % [issues.map(func(i): return i.message)])
	var n := 0
	for d in _defs():
		n += d.sources.size()
	assert_gt(n, 10, "the chances, counts and floors are tied to their sources")


func test_a_changed_number_or_a_missing_source_is_caught() -> void:
	var all := _all()
	var timed := (
		(_repo.get_def(&"special_rooms", &"timed_door") as SpecialRoomDefinition).duplicate()
	)
	timed.chance_permille += 1
	var lost := (_repo.get_def(&"special_rooms", &"lockdown") as SpecialRoomDefinition).duplicate()
	lost.sources = {"count_max": "lockdown/nowhere:rooms_max"}
	var arena := (_repo.get_def(&"special_rooms", &"arena") as SpecialRoomDefinition).duplicate()
	arena.share_permille = 330
	var defs: Array[ContentDef] = []
	for d in all:
		if not d is SpecialRoomDefinition:
			defs.append(d)
	defs.append_array([timed, lost, arena])
	assert_eq(SpecialRoomDefinition.cross_check(defs).size(), 3, "each caught")


func test_the_code_says_what_the_files_say() -> void:
	var scripts := {}
	for c in ProjectSettings.get_global_class_list():
		scripts[String(c["class"])] = String(c["path"])
	for d in _defs():
		var cls := d.code.get_slice(".", 0)
		var fn := d.code.get_slice(".", 1)
		assert_true(scripts.has(cls), "%s: class %s" % [d.id, cls])
		if not scripts.has(cls):
			continue
		var raw := GdSource.read(scripts[cls])
		var text := GdSource.code_only(raw)
		assert_true(
			text.contains("static func %s(" % fn), "%s: %s is a static function" % [d.id, d.code]
		)
		if d.stream != &"":  # the string literal in the class's code
			assert_true(raw.contains('"%s"' % d.stream), "%s draws from %s" % [d.id, d.stream])
	_eq(&"arena", "min_spawn_spots", ArenaRooms.MIN_SPOTS)
	_eq(&"lockdown", "min_spawn_spots", LockdownRooms.MIN_SPOTS)
	_eq(&"purple_runes", "min_cells", PurpleRooms.MIN_CELLS)
	assert_eq(
		[
			TimedDoorRooms.STREAM,
			RuneRooms.STREAM,
			CrackedRooms.STREAM,
			PurpleRooms.STREAM,
			LockdownRooms.STREAM,
			Shrines.FOUNTAIN_STREAM,
			Gamble.STREAM,
			Events.CURSE_STREAM,
		],
		[
			_stream(&"timed_door"),
			_stream(&"rune_puzzle"),
			_stream(&"cracked_wall"),
			_stream(&"purple_runes"),
			_stream(&"lockdown"),
			_stream(&"fountain"),
			_stream(&"shrine"),
			_stream(&"curse"),
		],
		"the streams are the code's constants"
	)
	assert_eq(_stream(&"arena"), "", "the arenas: a pure function of the layout, no stream")


func _stream(id: StringName) -> String:
	return String((_repo.get_def(&"special_rooms", id) as SpecialRoomDefinition).stream)


func _eq(id: StringName, field: String, value: int) -> void:
	var d := _repo.get_def(&"special_rooms", id) as SpecialRoomDefinition
	assert_eq(int(d.get(field)), value, "%s.%s is the code's" % [id, field])


func test_each_rule_catches_its_mistake() -> void:
	var cases := [
		["band", &"loud", "enum"],
		["entry", &"window", "enum"],
		["code", "", "range"],
		["floor_min", 0, "range"],
		["floor_max", 0, ""],
		["count_min", 3, "range"],
		["chance_permille", 1001, "placement"],
		["avoid", [&"attic"] as Array[StringName], "unknown_room"],
		["host_avoid", [&"start"] as Array[StringName], "range"],
		["sources", {"nope": "map/floor:x"}, "unknown_field"],
		["sources", {"chance_permille": "map floor"}, "source_format"],
	]
	for c: Array in cases:
		var d := SpecialRoomDefinition.new()
		d.id = &"case"
		d.code = "X.y"
		d.chance_permille = 100
		d.set(c[0], c[1])
		var got := _codes(d.validate())
		if c[2] == "":
			assert_eq(got, [], "%s = %s is fine" % [c[0], c[1]])
		else:
			assert_has(got, c[2], "%s = %s" % [c[0], c[1]])
