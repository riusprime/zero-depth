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
## v0.9.5 TS: the spread placement.
const TS_SEEDS := 200
const TS_TIMER := 1200
const TS_STEPS := 2


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


## Doorway steps from room `a` to room `b` over the floor's doorways (-1 when unreachable).
func _steps(f: FloorLayout, a: int, b: int) -> int:
	var dist := {a: 0}
	var queue := [a]
	while not queue.is_empty():
		var room: int = queue.pop_front()
		if room == b:
			return dist[room]
		for n in f.neighbours(room):
			if not dist.has(n):
				dist[n] = dist[room] + 1
				queue.append(n)
	return -1


func test_spread_switches_sit_in_two_rooms_one_or_two_steps_away_and_are_completable() -> void:
	var repo := ContentRepository.load_all()
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	var arenas := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var spec := BossArenaSpec.new()
	var speed := PlayerTable.starting_values().move_speed
	var budget := TS_TIMER * speed * TimedDoorRooms.PATH_SHARE_PERMILLE / 1000.0
	assert_eq(map.timed_door_ticks, TS_TIMER, "the data's timer is 20 s")
	assert_eq(map.timed_switch_steps_max, TS_STEPS)
	assert_eq(map.timed_lever_ticks, 300, "the lever opens the door for 5 s")
	var before := 0
	var after := 0
	var sides := 0
	var same_side := 0
	var worst := 0.0
	var bad := 0
	for s in TS_SEEDS:
		var seed_value := 7001 + s * 7919
		var f := _layout(seed_value, map, spec, arenas.share_permille)
		if TimedDoorRooms.mark(f, 1000, 900, speed, PackedInt32Array(), PackedVector2Array()) >= 0:
			before += 1
		var room := TimedDoorRooms.mark(
			f, 1000, TS_TIMER, speed, PackedInt32Array(), PackedVector2Array(), TS_STEPS
		)
		if room < 0:
			continue
		after += 1
		var ok := f.timed_switches.size() == 2 and f.timed_switch_rooms.size() == 2
		ok = ok and f.timed_switch_rooms[0] != f.timed_switch_rooms[1]
		var never := [f.start_room, f.boss_room, f.shop_room, f.overrun_room, f.curse_room, room]
		for k in f.timed_switch_rooms.size():
			var r := f.timed_switch_rooms[k]
			var n := _steps(f, f.timed_host, r)
			ok = ok and n >= 1 and n <= TS_STEPS
			ok = ok and not r in never and not f.arena_rooms.has(r) and not f.lockdown_rooms.has(r)
			ok = ok and f.room_of(f.timed_switches[k]) == r
			var near_door := not TimedDoorRooms._far(
				f.timed_switches[k], f.door_approaches(r, 1.0), TimedDoorRooms.DOOR_GAP_M
			)
			var near_item := not TimedDoorRooms._far(
				f.timed_switches[k], f.item_spots, TimedDoorRooms.AVOID_M
			)
			ok = ok and not near_door and not near_item
		ok = ok and f.rooms[room].has_point(f.timed_lever) and f.timed_lever != Vector2.ZERO
		# either switch may be the second: its walk to the door fits 60 % of the timer
		var found := TimedDoorRooms._rooms_within(f, f.timed_host, room, TS_STEPS)
		var goal := TimedDoorRooms.door_goal(f, f.timed_host, f.timed_door)
		var reaches := {}
		var firsts := []
		for k in 2:
			var r := f.timed_switch_rooms[k]
			ok = ok and found.has(r)
			if not found.has(r):
				continue
			firsts.append(found[r]["first"])
			var m := TimedDoorRooms.path_m(f, found[r], f.timed_switches[k], goal, reaches)
			ok = ok and m > 0.0 and m <= budget
			worst = maxf(worst, m / (TS_TIMER * speed))
		if firsts.size() == 2:
			if firsts[0] != firsts[1]:
				sides += 1
			else:
				same_side += 1
		if not ok:
			bad += 1
			gut.p("seed %d: room %d host %d" % [seed_value, room, f.timed_host])
	(
		gut
		. p(
			(
				"TS_PLACEMENT| seeds=%d doors_before=%d doors_after=%d different_sides=%d same_side=%d bad=%d worst_path_share=%.3f"
				% [TS_SEEDS, before, after, sides, same_side, bad, worst]
			)
		)
	)
	assert_eq(bad, 0, "every spread door is valid and completable in either order")
	assert_gt(after, 0, "some floors still get a timed door")
	assert_lte(worst, TimedDoorRooms.PATH_SHARE_PERMILLE / 1000.0, "within 60 % of the timer")
	assert_gt(sides, same_side, "the two switches usually sit behind different doorways")


func test_the_spread_placement_is_deterministic_and_leaves_the_legacy_one_alone() -> void:
	var a := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var b := _layout(4242, FloorParams.defaults(), BossArenaSpec.new(), 0)
	var ra := TimedDoorRooms.mark(
		a, 1000, TS_TIMER, 0.1, PackedInt32Array(), PackedVector2Array(), TS_STEPS
	)
	var rb := TimedDoorRooms.mark(
		b, 1000, TS_TIMER, 0.1, PackedInt32Array(), PackedVector2Array(), TS_STEPS
	)
	assert_eq(ra, rb)
	assert_eq(a.timed_switches, b.timed_switches)
	assert_eq(a.timed_switch_rooms, b.timed_switch_rooms)
	var old := TimedDoorRooms.mark(a, 1000, 900, 0.1, PackedInt32Array(), PackedVector2Array())
	if old >= 0:
		assert_true(a.timed_switch_rooms.is_empty(), "the old placement holds both in the host")
		assert_eq(a.timed_lever, Vector2.ZERO, "and no lever")
