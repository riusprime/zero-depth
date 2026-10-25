extends GutTest
## v0.9.0 TD (owner W17 "Ensure completion is possible at normal movement speed"; W18 "Reset safely without trapping
## the player"; W19 "Make rewards or secret areas optional"): the generator side of the timed doors, over 1,000 floor
## seeds built as the run builds them (TimedDoorRooms.mark after the boss room, the Overrun room and the arenas). On
## every seed (the chance forced to 1,000 so each floor is tried): the secret room is a dead end off the way, its door
## its one doorway, every other room stays reachable from the start hall without it (the main path never needs it),
## both switches stand in the room before it, apart, and the walk from either to the door is at most 60 % of the timer
## at base move speed. At the data's 35 % the share of floors holding one is near it.

const SEEDS := 1000
const TIMER := 900


func _layout(seed_value: int, map: FloorParams, spec: BossArenaSpec, arenas: int) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value, map)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ArenaRooms.mark(f, arenas)
	return f


func test_every_timed_door_is_completable_and_never_on_the_way() -> void:
	var repo := ContentRepository.load_all()
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	var arenas := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var spec := BossArenaSpec.new()
	var speed := PlayerTable.starting_values().move_speed
	var budget := TIMER * speed * TimedDoorRooms.PATH_SHARE_PERMILLE / 1000.0
	var placed := 0
	var natural := 0
	var worst := 0.0
	var bad := 0
	for s in SEEDS:
		var seed_value := 7001 + s * 7919
		var f := _layout(seed_value, map, spec, arenas.share_permille)
		if RngStream.derive(seed_value, TimedDoorRooms.STREAM).chance_permille(
			map.timed_door_permille
		):
			natural += 1
		var room := TimedDoorRooms.mark(
			f, 1000, TIMER, speed, PackedInt32Array(), PackedVector2Array()
		)
		if room < 0:
			continue
		placed += 1
		var ok := true
		ok = ok and TimedDoorRooms.only_door(f, room) == f.timed_door
		ok = ok and f.neighbours(room).size() == 1 and f.neighbours(room)[0] == f.timed_host
		ok = ok and not room in [f.start_room, f.boss_room, f.boss_host_room, f.portal_room]
		ok = ok and ArenaRooms.all_reachable(f, PackedInt32Array([room]))
		ok = ok and f.timed_switches.size() == 2
		ok = (
			ok
			and Kin.length(f.timed_switches[0] - f.timed_switches[1]) >= TimedDoorRooms.SWITCH_GAP_M
		)
		var reach := FloorReach.new()
		reach.build(
			f.rooms[f.timed_host].merge(f.door_rect(f.timed_door)),
			f.room_walls(f.timed_host),
			TimedDoorRooms.PATH_CLEARANCE_M
		)
		var goal := TimedDoorRooms.door_goal(f, f.timed_host, f.timed_door)
		for q in f.timed_switches:
			ok = ok and f.room_of(q) == f.timed_host
			var m := TimedDoorRooms.walk_m(reach, q, goal)
			ok = ok and m > 0.0 and m <= budget
			worst = maxf(worst, m)
		if not ok:
			bad += 1
			gut.p(
				"seed %d: room %d host %d door %d" % [seed_value, room, f.timed_host, f.timed_door]
			)
	(
		gut
		. p(
			(
				"TIMED_DOORS| seeds=%d placed_when_tried=%d natural_35pct=%d bad=%d worst_walk_m=%.1f budget_m=%.1f"
				% [SEEDS, placed, natural, bad, worst, budget]
			)
		)
	)
	assert_eq(bad, 0, "every timed door completable, off the way")
	assert_gt(placed, SEEDS * 8 / 10, "most floors have a dead end that fits one")
	assert_between(natural, SEEDS * 30 / 100, SEEDS * 40 / 100, "about 35 % of floors are tried")


func test_the_same_seed_marks_the_same_door() -> void:
	var a := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var b := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var walls := a.walls.size()
	var ra := TimedDoorRooms.mark(a, 1000, TIMER, 0.1, PackedInt32Array(), PackedVector2Array())
	var rb := TimedDoorRooms.mark(b, 1000, TIMER, 0.1, PackedInt32Array(), PackedVector2Array())
	assert_eq(ra, rb)
	assert_eq(a.timed_switches, b.timed_switches)
	assert_eq(a.walls.size(), walls, "the floor's walls are untouched")
	var none := TimedDoorRooms.mark(a, 0, TIMER, 0.1, PackedInt32Array(), PackedVector2Array())
	assert_eq(none, -1, "a floor not drawn has none")
	assert_eq(a.timed_room, -1)
