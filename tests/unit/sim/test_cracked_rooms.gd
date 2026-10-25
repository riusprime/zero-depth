extends GutTest
## v0.9.0 DX (owner W §4 C; Q23; W19 "Make rewards or secret areas optional"): the generator side of the cracked wall,
## over 1,000 floor seeds built as the run builds them (after the boss room, the Overrun room, the arenas, the timed
## door and the rune puzzle, both tried at 1,000 so they meet as often as they can). On every seed where one fits (the
## chance forced to 1,000): the hidden room is a dead end off the way, the cracked wall fills its one doorway, every
## other room stays reachable from the start hall without it (the wall never blocks the main path), it is never the
## timed door's or the rune puzzle's room or host and its host is none of them, and once the wall is gone the room is
## reachable on foot from its host through the doorway (the reach grid at 0.5 m clearance). At the data's 25 % the
## share tried is near it.

const SEEDS := 1000


func _layout(seed_value: int, map: FloorParams, spec: BossArenaSpec, arenas: int) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value, map)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ArenaRooms.mark(f, arenas)
	return f


func test_every_cracked_wall_is_off_the_way_and_opens_onto_its_room() -> void:
	var repo := ContentRepository.load_all()
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	var arenas := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var secrets: SecretsDefinition = repo.get_def(&"secrets", &"secrets")
	var spec := BossArenaSpec.new()
	var speed := PlayerTable.starting_values().move_speed
	var placed := 0
	var natural := 0
	var with_both := 0
	var bad := 0
	for s in SEEDS:
		var seed_value := 7001 + s * 7919
		var f := _layout(seed_value, map, spec, arenas.share_permille)
		if RngStream.derive(seed_value, CrackedRooms.STREAM).chance_permille(
			secrets.crack_permille
		):
			natural += 1
		TimedDoorRooms.mark(f, 1000, 900, speed, PackedInt32Array(), PackedVector2Array())
		RuneRooms.mark(f, 1000, PackedInt32Array(), PackedVector2Array())
		var room := CrackedRooms.mark(f, 1000, PackedInt32Array())
		if room < 0:
			continue
		placed += 1
		if f.timed_room >= 0 and f.rune_room >= 0:
			with_both += 1
		var host := f.crack_host
		var busy := [f.timed_room, f.timed_host, f.rune_room, f.rune_host]
		var ok := TimedDoorRooms.only_door(f, room) == f.crack_door
		ok = ok and f.neighbours(room).size() == 1 and f.neighbours(room)[0] == host
		ok = ok and not room in [f.start_room, f.boss_room, f.boss_host_room, f.portal_room]
		ok = ok and ArenaRooms.all_reachable(f, PackedInt32Array([room]))
		ok = ok and not room in busy and not host in busy
		ok = ok and f.crack_wall != null
		ok = ok and f.crack_wall.bounds().intersects(f.door_rect(f.crack_door))
		ok = ok and _walkable(f, host, room)
		if not ok:
			bad += 1
			gut.p("seed %d: room %d host %d door %d" % [seed_value, room, host, f.crack_door])
	(
		gut
		. p(
			(
				"CRACKED_WALLS| seeds=%d placed_when_tried=%d with_timed_and_runes=%d natural_25pct=%d bad=%d"
				% [SEEDS, placed, with_both, natural, bad]
			)
		)
	)
	assert_eq(bad, 0, "every cracked wall off the way, its room reachable once broken")
	assert_gt(placed, SEEDS * 5 / 10, "most floors have a dead end that fits one")
	assert_between(natural, SEEDS * 20 / 100, SEEDS * 30 / 100, "about 25 % of floors are tried")


## The walk from the host's side of the doorway into the room's centre exists once the wall is gone.
func _walkable(f: FloorLayout, host: int, room: int) -> bool:
	var reach := FloorReach.new()
	var area := f.rooms[host].merge(f.door_rect(f.crack_door)).merge(f.rooms[room])
	var walls: Array[Obb] = f.room_walls(host)
	for o in f.room_walls(room):
		if not walls.has(o):
			walls.append(o)
	reach.build(area, walls, TimedDoorRooms.PATH_CLEARANCE_M)
	var from := TimedDoorRooms.door_goal(f, host, f.crack_door)
	var to := f.rooms[room].get_center()  # its open spot nearest the centre (a spawn spot), else the centre
	var best := -1.0
	for q in f.spawn_points[room]:
		var d := Kin.length(q - f.rooms[room].get_center())
		if best < 0.0 or d < best:
			best = d
			to = q
	return TimedDoorRooms.walk_m(reach, from, to) > 0.0


func test_the_same_seed_marks_the_same_wall() -> void:
	var a := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var b := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var walls := a.walls.size()
	assert_eq(
		CrackedRooms.mark(a, 1000, PackedInt32Array()),
		CrackedRooms.mark(b, 1000, PackedInt32Array())
	)
	assert_eq(a.crack_door, b.crack_door)
	assert_eq(a.walls.size(), walls, "the floor's walls are untouched")
	assert_eq(CrackedRooms.mark(a, 0, PackedInt32Array()), -1, "not drawn: none")
	assert_eq(a.crack_room, -1)
