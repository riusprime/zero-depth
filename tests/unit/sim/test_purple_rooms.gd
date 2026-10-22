extends GutTest
## v0.9.0 DP (owner Q26b: "one of the event rooms, in a big room, has activation purple runes"): the generator side of
## the purple-rune room, over 1,000 floor seeds of floors 2 and 3 (the floors that may hold it), built as the run
## builds them (sized for the floor, the boss room, the Overrun room, the arenas, the Deep gate's spot, the timed door,
## the rune puzzle and the cracked wall at the data's chances), the chance forced to 1,000: the room is never the start
## hall, the boss room, the portal room, the Overrun room, an arena, a secret room or a secret's host; the main path
## never needs it (the boss room is reached from the start hall without crossing it); its dais is always reached from
## the start hall on the floor's open ground and keeps clear of every wall; it is a big room (2 x 2 cells or more)
## whenever the floor has a big room that fits, and it is placed on (nearly) every floor, so floor 3's warranty holds.

const SEEDS := 1000

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _layout(seed_value: int, run: RunState, floor_index: int) -> FloorLayout:
	var map := RunContentCompiler.compile_map(_repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(_repo)
	var arenas := RunContentCompiler.compile_arena(_repo.get_def(&"arena", &"arena"))
	var secrets: SecretsDefinition = _repo.get_def(&"secrets", &"secrets")
	var p := FloorShape.size_floor(run, map, floor_index)
	var f := FloorGenerator.generate(seed_value, p)
	BossRoomBuilder.attach(f, BossArenaSpec.make(Vector2i(4, 4), FloorLayout.Template.OPEN))
	OverrunRooms.mark(f)
	ArenaRooms.mark(f, arenas.share_permille)
	Routes.place_deep_gate(f)
	var speed := PlayerTable.starting_values().move_speed
	var none := PackedInt32Array()
	TimedDoorRooms.mark(f, map.timed_door_permille, 900, speed, none, PackedVector2Array())
	RuneRooms.mark(f, secrets.rune_permille, none, PackedVector2Array())
	CrackedRooms.mark(f, secrets.crack_permille, none)
	return f


## Whether the boss room is reached from the start hall without crossing `shut` (an independent BFS).
func _main_path_without(f: FloorLayout, shut: int) -> bool:
	var seen := {f.start_room: true}
	var queue := [f.start_room]
	while not queue.is_empty():
		var r: int = queue.pop_front()
		if r == f.boss_room:
			return true
		for d in f.door_rooms:
			var other := d.y if d.x == r else (d.x if d.y == r else -1)
			if other >= 0 and other != shut and not seen.has(other):
				seen[other] = true
				queue.append(other)
	return false


func test_the_purple_room_is_big_off_the_main_path_and_always_reached() -> void:
	var run := RunState.start(
		1, ContentCompiler.compile_run(_repo.get_def(&"run", RunSaver.RUN_ID))
	)
	var placed := 0
	var big := 0
	var could_be_big := 0
	var bad := 0
	var tried := 0
	for s in SEEDS:
		var floor_index := 2 + s % 2
		var seed_value := 9001 + s * 7919
		var f := _layout(seed_value, run, floor_index)
		tried += 1
		var room := PurpleRooms.mark(f, 1000, PackedInt32Array(), PackedVector2Array())
		if room < 0:
			continue
		placed += 1
		var cells := f.room_cell_count(room)
		if cells >= PurpleRooms.MIN_CELLS:
			big += 1
		for c in PurpleRooms.candidates(f, PackedInt32Array()):
			if f.room_cell_count(c) >= PurpleRooms.MIN_CELLS:
				could_be_big += 1
				break
		var never := [f.start_room, f.boss_room, f.portal_room, f.overrun_room]
		never.append_array(
			[f.timed_room, f.timed_host, f.rune_room, f.rune_host, f.crack_room, f.crack_host]
		)
		var ok := not room in never and not f.arena_rooms.has(room)
		ok = ok and _main_path_without(f, room)
		ok = ok and f.room_of(f.purple_pos) == room
		for w in f.walls:
			ok = (
				ok
				and Collide.circle_vs_obb(f.purple_pos, PurpleRooms.DAIS_CLEAR_M, w) == Vector2.ZERO
			)
		if s < 200:  # the whole floor's open ground (slow): the dais is reached from the start hall
			var reach := FloorReach.new()
			reach.build(f.bounds, f.walls, 0.5)
			ok = ok and reach.region_at(f.purple_pos) >= 0
			ok = ok and reach.region_at(f.purple_pos) == reach.region_at(f.start_pos)
		if not ok:
			bad += 1
			gut.p(
				(
					"seed %d floor %d: room %d at %s"
					% [seed_value, floor_index, room, str(f.purple_pos)]
				)
			)
	gut.p(
		(
			"PURPLE_ROOMS| seeds=%d placed=%d big=%d big_possible=%d bad=%d"
			% [tried, placed, big, could_be_big, bad]
		)
	)
	assert_eq(bad, 0, "never a special room, off the main path, its dais reached and clear")
	assert_gte(placed, SEEDS * 99 / 100, "placed on (nearly) every floor: floor 3's warranty holds")
	assert_gte(
		big,
		could_be_big * 9 / 10,
		"a big room whenever the floor has one that fits (almost always)"
	)


func test_the_same_seed_marks_the_same_room_and_no_draw_none() -> void:
	var run := RunState.start(
		1, ContentCompiler.compile_run(_repo.get_def(&"run", RunSaver.RUN_ID))
	)
	var a := _layout(4242, run, 2)
	var b := _layout(4242, run, 2)
	var walls := a.walls.size()
	var ra := PurpleRooms.mark(a, 1000, PackedInt32Array(), PackedVector2Array())
	assert_eq(ra, PurpleRooms.mark(b, 1000, PackedInt32Array(), PackedVector2Array()))
	assert_eq(a.purple_pos, b.purple_pos)
	assert_eq(a.walls.size(), walls, "the floor's walls are untouched")
	assert_eq(
		PurpleRooms.mark(a, 0, PackedInt32Array(), PackedVector2Array()), -1, "not drawn: none"
	)
	assert_eq(a.purple_room, -1)
