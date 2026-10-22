extends GutTest
## v0.9.0 RA (owner W §4 A, Q22; W3 "solved in under 30 s"; W19 "Make rewards or secret areas optional"): the generator
## side of the rune puzzle, over 1,000 floor seeds built as the run builds them (after the boss room, the Overrun room,
## the arenas and the timed door at the data's 35 %). On every seed where one fits (the
## chance forced to 1,000): the hidden room is a dead end off the way, its door its one doorway, every other room stays
## reachable from the start hall without it (the main path never needs it; the pillars are not solid), it is never the
## timed door's room or host and its host is neither, the three pillars stand in the host apart (but within 10 m of
## each other and 12 m of the carved doorway) and clear of its doorways, no pillar starts solved and each is solved
## in 1-3 presses. At the data's 30 % the share tried is near it.

const SEEDS := 1000


func _layout(seed_value: int, map: FloorParams, spec: BossArenaSpec, arenas: int) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value, map)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ArenaRooms.mark(f, arenas)
	return f


func test_every_rune_puzzle_is_solvable_and_never_on_the_way() -> void:
	var repo := ContentRepository.load_all()
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	var arenas := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var secrets: SecretsDefinition = repo.get_def(&"secrets", &"secrets")
	var spec := BossArenaSpec.new()
	var speed := PlayerTable.starting_values().move_speed
	var placed := 0
	var natural := 0
	var both := 0
	var bad := 0
	var worst := 0
	for s in SEEDS:
		var seed_value := 7001 + s * 7919
		var f := _layout(seed_value, map, spec, arenas.share_permille)
		if RngStream.derive(seed_value, RuneRooms.STREAM).chance_permille(secrets.rune_permille):
			natural += 1
		TimedDoorRooms.mark(
			f, map.timed_door_permille, 900, speed, PackedInt32Array(), PackedVector2Array()
		)
		var room := RuneRooms.mark(f, 1000, PackedInt32Array(), PackedVector2Array())
		if room < 0:
			continue
		placed += 1
		if f.timed_room >= 0:
			both += 1
		var host := f.rune_host
		var ok := TimedDoorRooms.only_door(f, room) == f.rune_door
		ok = ok and f.neighbours(room).size() == 1 and f.neighbours(room)[0] == host
		ok = ok and not room in [f.start_room, f.boss_room, f.boss_host_room, f.portal_room]
		ok = ok and ArenaRooms.all_reachable(f, PackedInt32Array([room]))
		ok = ok and not room in [f.timed_room, f.timed_host]
		ok = ok and not host in [f.timed_room, f.timed_host]
		ok = ok and f.rune_pillars.size() == RuneRooms.PILLARS
		ok = ok and f.rune_door_wall != null
		var approaches := f.door_approaches(host, 1.0)
		for k in f.rune_pillars.size():
			var q := f.rune_pillars[k]
			ok = ok and f.room_of(q) == host
			for a in approaches:
				ok = ok and Kin.length(a - q) >= RuneRooms.DOOR_GAP_M
			ok = ok and Kin.length(f.door_centers[f.rune_door] - q) <= RuneRooms.CARVING_M
			for j in range(k + 1, f.rune_pillars.size()):
				var gap := Kin.length(f.rune_pillars[j] - q)
				ok = ok and gap >= RuneRooms.PILLAR_GAP_M and gap <= RuneRooms.PILLAR_SPAN_M
			var need := RuneRooms.presses_needed(f.rune_start[k], f.rune_target[k])
			ok = ok and need >= 1 and need <= RuneRooms.FACES - 1
			worst = maxi(worst, need)
		if not ok:
			bad += 1
			gut.p("seed %d: room %d host %d door %d" % [seed_value, room, host, f.rune_door])
	(
		gut
		. p(
			(
				"RUNE_ROOMS| seeds=%d placed_when_tried=%d with_timed_door=%d natural_30pct=%d bad=%d worst_presses=%d"
				% [SEEDS, placed, both, natural, bad, worst]
			)
		)
	)
	assert_eq(bad, 0, "every rune puzzle solvable in at most 3 presses a pillar, off the way")
	assert_gt(placed, SEEDS * 5 / 10, "most floors have a dead end that fits one")
	assert_gt(both, 0, "some floors hold both puzzles")
	assert_between(natural, SEEDS * 25 / 100, SEEDS * 35 / 100, "about 30 % of floors are tried")


func test_the_same_seed_marks_the_same_puzzle() -> void:
	var a := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var b := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var walls := a.walls.size()
	var ra := RuneRooms.mark(a, 1000, PackedInt32Array(), PackedVector2Array())
	var rb := RuneRooms.mark(b, 1000, PackedInt32Array(), PackedVector2Array())
	assert_eq(ra, rb)
	assert_eq(a.rune_pillars, b.rune_pillars)
	assert_eq(a.rune_target, b.rune_target)
	assert_eq(a.rune_start, b.rune_start)
	assert_eq(a.walls.size(), walls, "the floor's walls are untouched")
	assert_eq(RuneRooms.mark(a, 0, PackedInt32Array(), PackedVector2Array()), -1, "not drawn: none")
	assert_eq(a.rune_room, -1)
