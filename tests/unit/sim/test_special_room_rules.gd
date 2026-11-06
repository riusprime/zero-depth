extends GutTest
## v0.9.0 RG (PLAN W17 "ensure completion is possible at normal movement speed", W18 "reset safely without trapping
## the player", W20-W26 the Lockdowns, W73 the special-room schema): the no-softlock property tests, over RUNS run
## seeds x floors 1-5 (1,000 floors), each run's floors built in order as Main builds them (SaveLab.build_floor:
## FloorScenario, the shop, the events, FloorPlan.add_secrets; the run's purple-rune history carried, as
## RunState.finish_floor). The flow field is not built for them (NavField.skip_build: no placement reads it; the first
## test proves the rooms are the same with it built). Every rule a file of data/special_rooms states is checked on
## every floor (RoomCensus reads the rooms):
## - (d) no special room in a room its `avoid` names, no host in a room its `host_avoid` names, so none overlaps another
##   it must avoid or sits in the start hall, the boss room or its host, the shop, the curse room, the portal or an
##   event's room where its rule says so; its floors, its cap a floor, dead ends, spawn spots, a sealed kind's least
##   grid cells (v0.9.0 CF: never a 1 x 1), never side by side, off the critical path;
## - (c) the boss room and the exit (the portal room) are reached from the start hall with every sealed thing shut
##   (the arenas, the Overrun room, the Lockdowns, the timed door's, rune puzzle's and cracked wall's rooms), and a
##   kind that keeps every room (arenas, Lockdowns) cuts none off;
## - (a) a timed door is completable at the base move speed: on the floor's final walls (the shrine, the fountain, the
##   shop, the containers, every interior piece) at the hero's radius, both switches stand in the host's open floor
##   reached from its doorways, and the walk from either (the second) to the doorway takes at most the timer at the
##   base move speed (the worst share printed);
## - (b) every Lockdown opens: its table has the 90 s cap and the stuck-enemy rule, it is skippable (never the only
##   way to the boss: (c)); and on one real floor (flow field built) of each floor 1-5 holding one, nobody fighting, it
##   opens at the cap with the bars gone, and cleared it opens before the cap.
## A failure names the seed and floor: report it as a bug rather than loosening the rule.

const RUNS := 200
const FLOORS := 5

var _repo: ContentRepository
var _defs := {}


func before_all() -> void:
	_repo = ContentRepository.load_all()
	for k in RoomCensus.KINDS:
		_defs[k] = _repo.get_def(&"special_rooms", k)


func after_each() -> void:
	NavField.skip_build = false


## Floor `floor_index` of run `s`, the run's purple history `purple` (updated).
func _floor(s: int, floor_index: int, purple: PackedInt32Array) -> World:
	var run := SaveLab.run_state(s, floor_index, &"blade", 0, _repo)
	run.purple_floors = purple.duplicate()
	var w := SaveLab.build_floor(run, &"", _repo)
	if w.purple != null and not purple.has(run.run_floor()):
		purple.append(run.run_floor())
	return w


func test_the_rooms_are_the_same_without_the_flow_field() -> void:
	for s in range(1, 3):
		var purple_on := PackedInt32Array()
		var purple_off := PackedInt32Array()
		for floor_index in range(1, FLOORS + 1):
			NavField.skip_build = false
			var on := _floor(s, floor_index, purple_on)
			NavField.skip_build = true
			var off := _floor(s, floor_index, purple_off)
			NavField.skip_build = false
			var where := "seed %d floor %d" % [s, floor_index]
			assert_eq(RoomCensus.of(off), RoomCensus.of(on), "%s: the same rooms" % where)
			assert_eq(off.walls.size(), on.walls.size(), "%s: the same walls" % where)
			assert_eq(off.spawn_points, on.spawn_points, "%s: the same spawn spots" % where)
			assert_eq(off.floor_layout.timed_switches, on.floor_layout.timed_switches, where)
			assert_eq(off.floor_layout.rune_pillars, on.floor_layout.rune_pillars, where)
			assert_eq(off.floor_layout.purple_pos, on.floor_layout.purple_pos, where)


func test_1000_floors_keep_every_rule() -> void:
	NavField.skip_build = true
	var bad := {}
	for rule in ["avoid", "host", "floors", "cap", "room", "reach", "timed"]:
		bad[rule] = PackedStringArray()
	var timed := 0
	var worst := 0
	var lockdowns := 0
	var floors := 0
	for s in range(1, RUNS + 1):
		var purple := PackedInt32Array()
		for floor_index in range(1, FLOORS + 1):
			var w := _floor(s, floor_index, purple)
			var where := "seed %d floor %d" % [s, floor_index]
			var census := RoomCensus.of(w)
			floors += 1
			_check_kinds(w, census, floor_index, where, bad)
			_check_reach(w, census, where, bad)
			lockdowns += (census[&"lockdown"] as PackedInt32Array).size()
			if w.timed != null:
				timed += 1
				worst = maxi(worst, _check_timed(w, where, bad))
	gut.p(
		(
			"RG_RULES| floors=%d timed_doors=%d worst_walk_permille_of_timer=%d lockdowns=%d"
			% [floors, timed, worst, lockdowns]
		)
	)
	assert_eq(floors, RUNS * FLOORS, "1,000 floors")
	assert_gt(timed, 0, "timed doors to check")
	assert_gt(lockdowns, 0, "Lockdowns to check")
	for rule: String in bad:
		var lines: PackedStringArray = bad[rule]
		assert_eq(lines.size(), 0, "%s: %s" % [rule, "; ".join(lines.slice(0, 12))])


## (d): each kind's floors, cap, room needs and avoid lists (its file in data/special_rooms).
func _check_kinds(
	w: World, census: Dictionary, floor_index: int, where: String, bad: Dictionary
) -> void:
	var f := w.floor_layout
	for k: StringName in RoomCensus.KINDS:
		var d: SpecialRoomDefinition = _defs[k]
		var rooms: PackedInt32Array = census[k]
		if rooms.is_empty():
			continue
		if not _floor_allowed(d, floor_index):
			_bad(bad, "floors", "%s: %s on floor %d" % [where, k, floor_index])
		if d.count_max > 0 and rooms.size() > d.count_max:
			_bad(bad, "cap", "%s: %d %s" % [where, rooms.size(), k])
		var hosts: PackedInt32Array = census.get(
			StringName(String(k) + "_host"), PackedInt32Array()
		)
		for r in rooms:
			for a: StringName in d.avoid:
				if (census[a] as PackedInt32Array).has(r):
					_bad(bad, "avoid", "%s: %s in room %d, a %s" % [where, k, r, a])
			if d.dead_end and _doors(f, r) != 1:
				_bad(bad, "room", "%s: %s room %d has %d doorways" % [where, k, r, _doors(f, r)])
			if d.min_spawn_spots > 0 and f.spawn_points[r].size() < d.min_spawn_spots:
				_bad(bad, "room", "%s: %s room %d has too few spawn spots" % [where, k, r])
			if d.seals and d.min_cells > 0 and f.room_cell_count(r) < d.min_cells:  # v0.9.0 CF
				_bad(
					bad, "room", "%s: %s room %d has %d cells" % [where, k, r, f.room_cell_count(r)]
				)
			if d.never_adjacent_to_same:
				for nb in f.neighbours(r):
					if rooms.has(nb):
						_bad(bad, "room", "%s: two %s side by side (%d, %d)" % [where, k, r, nb])
			if d.off_critical_path:
				var path := OverrunRooms.shortest_path(f, f.start_room, f.boss_host_room, -1)
				if path.has(r):
					_bad(bad, "room", "%s: %s room %d on the critical path" % [where, k, r])
		for h in hosts:
			if d.uses_host and not f.neighbours(rooms[0]).has(h):
				_bad(bad, "host", "%s: %s host %d is not its neighbour" % [where, k, h])
			for a: StringName in d.host_avoid:
				if (census[a] as PackedInt32Array).has(h):
					_bad(bad, "host", "%s: %s host %d, a %s" % [where, k, h, a])


func _floor_allowed(d: SpecialRoomDefinition, floor_index: int) -> bool:
	if floor_index < d.floor_min or (d.floor_max > 0 and floor_index > d.floor_max):
		return false
	match d.placement:
		SpecialRoomDefinition.Placement.EVERY_FLOORS:
			return (floor_index - d.floor_min) % d.every_floors == 0
		SpecialRoomDefinition.Placement.FLOOR_CHANCE:
			var i := floor_index - 1
			return i < d.floor_chance_permille.size() and d.floor_chance_permille[i] > 0
	return true


## (c): the boss room and the exit with every sealed thing shut; the kinds that keep every room cut none off.
func _check_reach(w: World, census: Dictionary, where: String, bad: Dictionary) -> void:
	var f := w.floor_layout
	var shut := PackedInt32Array()
	for k: StringName in [&"overrun"]:
		shut.append_array(census[k])
	var before := RoomCensus.hops_from(f, f.start_room, shut)
	for k: StringName in RoomCensus.KINDS:
		var d: SpecialRoomDefinition = _defs[k]
		if not d.keeps_every_room or (census[k] as PackedInt32Array).is_empty():
			continue
		var more := shut.duplicate()
		more.append_array(census[k])
		if k == &"lockdown":
			more.append_array(census[&"arena"])
			before = RoomCensus.hops_from(f, f.start_room, _with(shut, census[&"arena"]))
		var now := RoomCensus.hops_from(f, f.start_room, more)
		for r in f.room_count():
			if before[r] >= 0 and now[r] < 0 and not more.has(r):
				_bad(bad, "reach", "%s: shutting the %s rooms cuts room %d off" % [where, k, r])
	var all := shut.duplicate()
	for k: StringName in RoomCensus.KINDS:
		var d: SpecialRoomDefinition = _defs[k]
		if d.seals or d.entry in [&"timed_door", &"rune_slab", &"cracked_wall"]:
			all.append_array(census[k])
	if all.has(f.start_room) or all.has(f.boss_room) or all.has(f.portal_room):
		_bad(bad, "reach", "%s: the start, boss or exit room is sealed" % where)
	var d_all := RoomCensus.hops_from(f, f.start_room, all)
	if f.boss_room < 0 or d_all[f.boss_room] < 0 or d_all[f.portal_room] < 0:
		_bad(bad, "reach", "%s: the boss room or the exit is cut off with every seal shut" % where)


## v0.9.5 TS: the same walk when the switches are in other rooms: from each switch (either may be the second) through
## the rooms between to the door, every leg on the final walls at the hero's radius.
func _check_spread(w: World, where: String, bad: Dictionary) -> int:
	var f := w.floor_layout
	var found := TimedDoorRooms._rooms_within(f, f.timed_host, f.timed_room, 2)
	var goal := TimedDoorRooms.door_goal(f, f.timed_host, f.timed_door)
	var reaches := {}
	var budget := float(w.timed.timer_ticks) * w.player.move_speed
	var worst := 0
	for k in f.timed_switches.size():
		var room := f.timed_switch_rooms[k]
		if not found.has(room):
			_bad(bad, "timed", "%s: switch %d is not 1-2 steps from the door's host" % [where, k])
			continue
		for r: int in found[room]["rooms"]:
			if not reaches.has(r):
				var area := f.rooms[r]
				for d in f.door_rooms.size():
					if f.door_rooms[d].x == r or f.door_rooms[d].y == r:
						area = area.merge(f.door_rect(d))
				var near: Array[Obb] = []
				for o in w.walls:
					if o.bounds().intersects(area.grow(1.0)):
						near.append(o)
				var reach := FloorReach.new()
				reach.build(area, near, w.player.radius_m)
				reaches[r] = reach
		var at := _open_near(reaches[room], f.timed_switches[k], TimedDoor.SWITCH_REACH_M)
		var walk := -1.0
		if at.is_finite():
			walk = TimedDoorRooms.path_m(f, found[room], at, goal, reaches)
		if walk < 0.0 or walk > budget:
			_bad(
				bad,
				"timed",
				(
					"%s: the walk from %s is %.1f m, the timer reaches %.1f m"
					% [where, f.timed_switches[k], walk, budget]
				)
			)
			continue
		worst = maxi(worst, int(walk * 1000.0 / budget))
	return worst


## (a): the timed door's walk on the final walls at the hero's radius. Returns the worst walk as per mille of the
## timer's reach at the base move speed.
func _check_timed(w: World, where: String, bad: Dictionary) -> int:
	var f := w.floor_layout
	if not f.timed_switch_rooms.is_empty():  # v0.9.5 TS: the switches are in other rooms
		return _check_spread(w, where, bad)
	var host := f.timed_host
	var door := f.timed_door
	var area := f.rooms[host].merge(f.door_rect(door))
	var near: Array[Obb] = []
	for o in w.walls:
		if o.bounds().intersects(area.grow(1.0)):
			near.append(o)
	var reach := FloorReach.new()
	reach.build(area, near, w.player.radius_m)
	var region := -1
	for a in f.door_approaches(host, 1.0):
		if region < 0:
			region = reach.region_at(a)
	var budget := float(w.timed.timer_ticks) * w.player.move_speed
	var worst := 0
	for q in f.timed_switches:
		var at := _open_near(reach, q, TimedDoor.SWITCH_REACH_M)
		if not at.is_finite() or reach.region_at(at) != region:
			_bad(bad, "timed", "%s: a switch at %s out of reach" % [where, q])
			continue
		var walk := TimedDoorRooms.walk_m(reach, at, f.door_centers[door])
		if walk < 0.0:
			walk = TimedDoorRooms.walk_m(reach, at, TimedDoorRooms.door_goal(f, host, door))
		if walk < 0.0 or walk > budget:
			_bad(
				bad,
				"timed",
				(
					"%s: the walk from %s is %.1f m, the timer reaches %.1f m"
					% [where, q, walk, budget]
				)
			)
			continue
		worst = maxi(worst, int(walk * 1000.0 / budget))
	return worst


## The open cell nearest `q` within `r` m (its centre), or (INF, INF) when none is (floor coordinates go negative).
func _open_near(reach: FloorReach, q: Vector2, r: float) -> Vector2:
	if reach.region_at(q) >= 0:
		return q
	var best := Vector2(INF, INF)
	var best_d := r
	var c := reach.cell_of(q)
	var span := int(ceil(r / FloorReach.CELL))
	for y in range(c.y - span, c.y + span + 1):
		for x in range(c.x - span, c.x + span + 1):
			var cell := Vector2i(x, y)
			if not reach.inside(cell) or reach.blocked[y * reach.size.x + x] == 1:
				continue
			var p := reach.center(cell)
			if Kin.length(p - q) <= best_d:
				best_d = Kin.length(p - q)
				best = p
	return best


func test_every_lockdown_opens() -> void:
	var t := RunContentCompiler.compile_lockdown(_repo.get_def(&"lockdown", &"lockdown"))
	assert_eq(t.cap_ticks, 90 * 60, "the 90 s cap")
	assert_gt(t.stuck_ticks, 0, "the stuck-enemy rule")
	for floor_index in range(1, FLOORS + 1):
		var s := _lockdown_seed(floor_index)
		if s < 0:
			fail_test("floor %d: no seed of 30 with a Lockdown" % floor_index)
			continue
		var w := SaveLab.floor_world(s, floor_index)
		LockLab.calm(w)
		var r := LockLab.room(w)
		var walls := w.walls.size()
		LockLab.enter(w, r)
		var st := w.lockdown
		assert_true(st.sealed(), "floor %d: sealed on entry" % floor_index)
		var t0 := st.sealed_tick
		while st.sealed() and w.tick - t0 < st.table.cap_ticks + 5:
			w.step(InputFrame.new())  # nobody fights
		assert_false(st.sealed(), "floor %d seed %d: open" % [floor_index, s])
		assert_eq(st.clear_tick - t0, st.table.cap_ticks, "floor %d: at the cap" % floor_index)
		assert_eq(w.walls.size(), walls, "floor %d: the bars are gone" % floor_index)
		var c := SaveLab.floor_world(s, floor_index)
		LockLab.calm(c)
		LockLab.enter(c, r)
		assert_true(c.lockdown.sealed(), "floor %d: sealed again" % floor_index)
		var took := LockLab.clear(c, st.table.cap_ticks)
		assert_false(c.lockdown.sealed(), "floor %d seed %d: cleared, open" % [floor_index, s])
		assert_lt(took, st.table.cap_ticks, "floor %d: before the cap" % floor_index)
		gut.p(
			(
				"RG_LOCKDOWN| floor=%d seed=%d cap_open_tick=%d clear_ticks=%d"
				% [floor_index, s, st.clear_tick - t0, took]
			)
		)


## The first run seed (1-30) whose floor `floor_index` holds a Lockdown, or -1 (the placement alone: no flow field).
func _lockdown_seed(floor_index: int) -> int:
	NavField.skip_build = true
	for s in range(1, 31):
		if not SaveLab.floor_world(s, floor_index).floor_layout.lockdown_rooms.is_empty():
			NavField.skip_build = false
			return s
	NavField.skip_build = false
	return -1


func _doors(f: FloorLayout, room: int) -> int:
	var n := 0
	for d in f.door_rooms:
		if d.x == room or d.y == room:
			n += 1
	return n


func _with(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	var out := a.duplicate()
	out.append_array(b)
	return out


func _bad(bad: Dictionary, rule: String, line: String) -> void:
	var lines: PackedStringArray = bad[rule]
	lines.append(line)
	bad[rule] = lines
