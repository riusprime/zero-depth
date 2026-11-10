extends GutTest
## v0.11.1 Step 2: the long seed loops of test_five_floors.gd (v0.9.0 FV, owner Q24: a run is five floors of about
## 10, 13, 15, 17 and 19 rooms plus the boss room; altars and chests by the floor's rooms), moved here so the seams
## run keeps only test_five_floors.gd's roster seam. The GitHub full suite runs this file (shard sim_c).

const FULL_SEEDS := 1000
const ROOMS_MIN := [9, 12, 14, 16, 18]
const ROOMS_MAX := [11, 14, 16, 18, 19]

var _seeds := Seeds.count(FULL_SEEDS)  # v0.11.1 Step 4: 200 here, 1,000 in the GitHub full suite
var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table(id: StringName = RunSaver.RUN_ID) -> RunTable:
	return ContentCompiler.compile_run(_repo.get_def(&"run", id))


## Generation over 1,000 seeds for every floor: the room count in the floor's range, a whole tree of doorways from
## the hall (one exit), no overlaps, inside the span, and the 4 x 4 boss room attached to the farthest room by one
## door. The first seeds of each floor also walk it: every room, the boss door and the boss's spot reachable from
## the start at the player's radius.
func test_generation_holds_for_every_floor_over_a_thousand_seeds() -> void:
	var map_def: MapDefinition = _repo.get_def(&"map", &"floor")
	var map := RunContentCompiler.compile_map(map_def)
	var r := RunState.start(1, _table())
	var counts := {}
	for f in range(1, 6):
		var lo := 99
		var hi := 0
		# v0.11.1 Step 3: the floor's map is compiled once per floor, not once per seed (FloorGenerator only reads it)
		var p := FloorShape.size_floor(r, RunContentCompiler.compile_map(map_def), f)
		for s in _seeds:
			var seed_value := 7 + s * 7919 + f * 104729
			var layout := FloorGenerator.generate(seed_value, p)
			var n := layout.room_count()
			lo = mini(lo, n)
			hi = maxi(hi, n)
			var tag := "floor %d seed %d" % [f, seed_value]
			if not _check_layout(layout, ROOMS_MIN[f - 1], ROOMS_MAX[f - 1], map.max_span, tag):
				return
			BossRoomBuilder.attach(
				layout, BossArenaSpec.make(Vector2i(4, 4), FloorLayout.Template.OPEN)
			)
			if not _check_boss_room(layout, tag):
				return
			if s < 15 and not _walk(layout, tag, s < 3):
				return
		counts[f] = [lo, hi]
		gut.p("floor %d: %d-%d rooms over %d seeds" % [f, lo, hi, _seeds])
	assert_eq(counts.size(), 5)


func _check_layout(f: FloorLayout, lo: int, hi: int, span: int, tag: String) -> bool:
	var why := _layout_fault(f, lo, hi, span)
	if why != "":
		assert_true(false, "%s: %s" % [tag, why])
	return why == ""


## What is wrong with the plain floor `f` ("" when nothing).
func _layout_fault(f: FloorLayout, lo: int, hi: int, span: int) -> String:
	var n := f.room_count()
	var why := ""
	if n < lo or n > hi:
		why = "%d rooms, outside %d-%d" % [n, lo, hi]
	elif f.room_cells[0].size != Vector2i(3, 3) or f.neighbours(0).size() != 1:
		why = "the hall is not 3 x 3 cells with one exit"
	elif f.cols > span or f.rows > span:
		why = "wider than the span"
	var far := 0
	for h in f.hops:
		if h < 0:
			why = "a room without a doorway path"
		far = maxi(far, h)
	if why == "" and f.hops[f.portal_room] != far:
		why = "the portal room is not the farthest"
	for a in n:
		for b in range(a + 1, n):
			if f.room_cells[a].intersects(f.room_cells[b]):
				why = "rooms overlap"
	return why


func _check_boss_room(f: FloorLayout, tag: String) -> bool:
	var boss := f.boss_room
	var ok := boss == f.room_count() - 1 and f.portal_room == boss
	ok = ok and f.hops[boss] == f.hops[f.boss_host_room] + 1
	ok = ok and f.neighbours(boss) == PackedInt32Array([f.boss_host_room])
	ok = ok and f.room_of(f.boss_spawn) == boss
	if not ok:
		assert_true(false, tag + ": the boss room is not attached by one door to its host")
	return ok


## The boss door and the boss's spot are reachable from the start at the player's radius; with `rooms`, every room
## has open floor in the start's region too.
func _walk(f: FloorLayout, tag: String, rooms: bool) -> bool:
	var reach := FloorReach.new()
	reach.build(f.bounds.grow(1.0), f.walls, 0.35)
	var home := reach.region_at(f.start_pos)
	var ok := home >= 0
	ok = ok and reach.region_at(f.boss_door_outside(1.6)) == home
	ok = ok and reach.region_at(f.boss_spawn) == home
	if not ok:
		assert_true(false, tag + ": the boss room is not reachable from the start")
		return false
	if not rooms:
		return true
	var open := PackedByteArray()
	open.resize(f.room_count())
	for k in reach.size.x * reach.size.y:
		if reach.region[k] == home:
			var room := f.room_of(reach.center(Vector2i(k % reach.size.x, k / reach.size.x)))
			if room >= 0:
				open[room] = 1
	for room in f.room_count():
		if open[room] == 0:
			assert_true(false, "%s: room %d is cut off from the start" % [tag, room])
			return false
	return true


## Altars and chests by the floor's rooms (data/rewards: up to 11 rooms 2 altars and 1-2 chests, up to 14 rooms 2
## and 2, more rooms 2-3 and 2-3 as in v0.8.0; at most 2 altars stand, S1; v0.10.5 S7: plus up to one extra of each)
func test_loot_follows_the_floor_size() -> void:
	var t := ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	assert_eq(t.counts_for(10), PackedInt32Array([2, 2, 1, 2]))
	assert_eq(t.counts_for(13), PackedInt32Array([2, 2, 2, 2]))
	assert_eq(t.counts_for(15), PackedInt32Array([2, 3, 2, 3]), "v0.8.0's counts from 15 rooms")
	assert_eq(t.counts_for(19), PackedInt32Array([2, 3, 2, 3]))
	var totals := {}
	for f in range(1, 6):
		var sum := 0
		for s in 12:
			var r := RunState.start(300 + s, _table())
			r.floor_index = f
			var w := _floor_world(r)
			var rooms := w.floor_layout.room_count() - 1
			var c := t.counts_for(rooms)
			var n := w.rewards.size()
			# v0.10.5 S7: up to one extra chest and one extra altar (Rewards._place_extras)
			assert_between(n, c[0] + c[2], c[1] + c[3] + 2, "floor %d (%d rooms)" % [f, rooms])
			var altars := w.rewards.kind.count(RewardStore.Kind.ALTAR)
			assert_lte(altars, t.altars_cap + 1, "at most two altars and the extra one")
			sum += n
		totals[f] = sum
	assert_lt(totals[1], totals[5], "the small first floor holds less than the long last one")


func _floor_world(r: RunState) -> World:
	var enemies := ContentCompiler.compile_enemies(_repo)
	r.scale_enemies(enemies)
	return FloorScenario.build(
		r.floor_seed(),
		PlayerTable.starting_values(),
		enemies,
		ContentCompiler.compile_spawning(_repo.get_def(&"spawning", &"floor_1"), _repo),
		ContentCompiler.compile_items(_repo),
		ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor")),
		r.floor_index,
		null,
		r
	)
