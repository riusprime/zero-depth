extends GutTest
## v0.8.0 SR (owner O13): the shop room per biome. The floor's shop room (ShopPlacement's pick, unchanged) is furnished
## with its biome's tent stall (ShopRoom): the same seed gives the same room; the rest of the floor is untouched; and,
## a property test over many run floors in every biome, the stall stands in at least 97 % of the shop rooms (else the
## room is untouched and the terminal stands, as before SR), its counter faces the room's first
## doorway, the box in front of the counter is clear, the counter's front is reachable from every doorway, every item
## spot of the room and (every 10th floor, on the whole floor) from the start at the player's radius, and no enemy
## spawns inside the stall. As Main builds a floor, the shop's interaction point is the counter.

const SEEDS := 120
const PLAYER_RADIUS := 0.35
const BIOMES: Array[StringName] = [
	&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"
]

var _map: FloorParams
var _shops := {}
var _specs: Array[BossArenaSpec] = []


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_map = RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	_map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	_shops = RunContentCompiler.compile_shop_rooms(repo)
	var bosses := ContentCompiler.compile_bosses(repo)
	for b in bosses.size():
		_specs.append(BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b))


## A run floor as FloorScenario builds it, up to the shop's room (not furnished yet).
func _floor(seed_value: int, spec: BossArenaSpec) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value, _map)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ShopPlacement.pick(f, _map)
	return f


func _shop_floor(seed_value: int, biome: StringName, spec: BossArenaSpec) -> FloorLayout:
	var f := _floor(seed_value, spec)
	assert_true(
		ShopRoom.furnish(f, _map, f.shop_room, _shops[biome]), "seed %d: furnished" % seed_value
	)
	return f


static func _keys(walls: Array[Obb]) -> PackedStringArray:
	var out := PackedStringArray()
	for w in walls:
		out.append(FloorLayout.piece_key(w))
	return out


static func _piece(f: FloorLayout, name: StringName) -> Array:
	for p: Array in f.shop_props:
		if p[0] == name:
			return p
	return []


func test_every_biome_has_its_shop_room() -> void:
	assert_eq(_shops.size(), BIOMES.size(), "five shop rooms")
	for b in BIOMES:
		assert_true(_shops.has(b), "%s has a shop room" % b)
		var t: ShopRoomTable = _shops[b]
		assert_eq(t.id, StringName("shop_%s" % b))
		assert_gt(t.layout.groups.size(), 3, "%s: dressed round the stall" % b)


func test_same_seed_same_shop_room() -> void:
	for s in [3, 77, 20261014]:
		var a := _shop_floor(s, &"ruins", _specs[0])
		var b := _shop_floor(s, &"ruins", _specs[0])
		assert_eq(_keys(a.walls), _keys(b.walls), "the same walls")
		assert_eq(_keys(a.shop_solids), _keys(b.shop_solids), "the same stall")
		assert_eq([a.shop_room, a.shop_pos, a.shop_angle], [b.shop_room, b.shop_pos, b.shop_angle])
		assert_eq(a.shop_props, b.shop_props)
		assert_eq(a.spawn_points, b.spawn_points)


## The room is the one ShopPlacement picked; the other rooms, the item spots and the map stream are untouched.
func test_only_the_shop_room_changes() -> void:
	for s in [5, 41, 909]:
		var f := _floor(s, _specs[1])
		var room := f.shop_room
		var r := f.rooms[room].grow(0.01)
		var outside := PackedStringArray()
		for i in f.walls.size():
			if i < f.slab_first or not r.encloses(f.walls[i].bounds()):
				outside.append(FloorLayout.piece_key(f.walls[i]))
		var props_out := []
		for p: Array in f.layout_props:
			if not f.rooms[room].has_point(p[1]):
				props_out.append(p)
		var items := f.item_spots.duplicate()
		var other_spawns := f.spawn_points.duplicate()
		assert_true(ShopRoom.furnish(f, _map, room, _shops[&"night_rocks"]))
		assert_eq(f.shop_room, room, "the room ShopPlacement picked")
		assert_eq(f.layout_of(room), &"shop_night_rocks", "the room holds the shop layout")
		var kept := 0
		var keys := _keys(f.walls)
		for k in outside:
			kept += 1 if keys.has(k) else 0
		assert_eq(kept, outside.size(), "every wall outside the shop room stays")
		var props_now := 0
		for p: Array in f.layout_props:
			if not f.rooms[room].has_point(p[1]):
				props_now += 1
		assert_eq(props_now, props_out.size(), "the other rooms' drawn pieces stay")
		assert_eq(f.item_spots, items, "the item spots stay")
		for k in f.room_count():
			if k != room:
				assert_eq(f.spawn_points[k], other_spawns[k], "room %d's spawn points stay" % k)


func test_the_stall_stands_and_is_reachable_over_many_floors() -> void:
	var failures := 0
	var dressing := 0
	var groups := 0
	var sizes := {}
	var t0 := Time.get_ticks_msec()
	for s in SEEDS:
		var seed_value := 8100 + s * 7919
		var biome := BIOMES[s % BIOMES.size()]
		var f := _floor(seed_value, _specs[s % _specs.size()])
		var tag := "seed %d %s" % [seed_value, biome]
		var room := f.shop_room
		if room < 0:
			assert_true(false, tag + ": no shop room")
			continue
		var t: ShopRoomTable = _shops[biome]
		var before := _keys(f.walls)
		if not ShopRoom.furnish(f, _map, room, t):
			# The fallback: nothing changes, the terminal stands where ShopPlacement put it (reachable,
			# test_shop_placement.gd). Printed, and counted against the bound below.
			failures += 1
			gut.p(tag + ": no spot for the stall in %s m; the terminal stands" % f.rooms[room].size)
			assert_eq(_keys(f.walls), before, tag + ": the room is untouched")
			assert_eq(f.shop_layout, &"", tag + ": no shop layout")
			continue
		sizes[f.room_cells[room].size] = true
		groups += t.layout.groups.size()
		dressing += f.shop_props.size()
		_check_room(f, tag)
		if s % 10 == 0:
			_check_floor_reach(f, tag)
	gut.p(
		(
			"shop rooms: %d floors, %d stalls failed, %d room footprints, %d shop pieces, %d ms"
			% [SEEDS, failures, sizes.size(), dressing, Time.get_ticks_msec() - t0]
		)
	)
	assert_lte(failures, SEEDS * 3 / 100, "the stall stands in at least 97 % of shop rooms")
	assert_gt(sizes.size(), 3, "rooms of several sizes")


func _check_room(f: FloorLayout, tag: String) -> void:
	var room := f.shop_room
	var r := f.rooms[room]
	var counter := _piece(f, &"shop_counter")
	var tent := _piece(f, &"shop_tent")
	assert_false(counter.is_empty() or tent.is_empty(), tag + ": a counter and a tent")
	assert_eq(f.shop_pos, counter[1] as Vector2, tag + ": the shop's spot is the counter")
	assert_eq(f.shop_angle % 1024, 0, tag + ": the stall faces a grid axis")
	var facing := Kin.dir(f.shop_angle)
	var door := f.door_approaches(room)[0]
	assert_gt(facing.dot(door - f.shop_pos), 0.0, tag + ": the counter faces the first doorway")
	assert_gt(facing.dot(f.shop_pos - (tent[1] as Vector2)), 0.0, tag + ": the tent is behind it")
	var walls: Array[Obb] = f.room_walls(room)
	for o in f.shop_solids:
		assert_true(r.grow(0.01).encloses(o.bounds()), tag + ": the stall stands in its room")
		for w in walls:
			var gap := _overlap(o.bounds(), w.bounds())
			assert_false(gap, tag + ": the stall overlaps nothing")
	# The box in front of the counter: its width, 3 m deep, clear of every wall and the stall.
	var c_box := ShopStallLike.bounds(counter)
	var depth := 3.0
	var box: Rect2
	match f.shop_angle:
		0:
			box = Rect2(c_box.end.x, c_box.position.y, depth, c_box.size.y)
		1024:
			box = Rect2(c_box.position.x, c_box.end.y, c_box.size.x, depth)
		2048:
			box = Rect2(c_box.position.x - depth, c_box.position.y, depth, c_box.size.y)
		_:
			box = Rect2(c_box.position.x, c_box.position.y - depth, c_box.size.x, depth)
	assert_true(r.grow(0.01).encloses(box), tag + ": the approach is in the room")
	var all: Array[Obb] = walls.duplicate()
	all.append_array(f.shop_solids)
	for w in all:
		assert_false(_overlap(box.grow(-0.02), w.bounds()), tag + ": the approach is clear")
	# At the player's radius: the counter's front, every doorway and every item spot are one region.
	var reach := FloorReach.new()
	reach.build(r, all, PLAYER_RADIUS)
	var front := reach.region_at(ShopPlacement.front(f))
	assert_gte(front, 0, tag + ": the counter's front is open")
	for a in f.door_approaches(room):
		assert_eq(reach.region_at(a), front, tag + ": a doorway reaches the counter")
	for i in f.item_spots.size():
		if f.item_rooms[i] == room:
			assert_eq(
				reach.region_at(f.item_spots[i]), front, tag + ": the room's reward is reachable"
			)
	for q in f.spawn_points[room]:
		for o in f.shop_solids:
			assert_eq(
				Collide.circle_vs_obb(q, 0.6, o), Vector2.ZERO, tag + ": no spawn in the stall"
			)


## The whole floor (gate and stall as walls) at the player's radius: the counter's front is in the start's region.
func _check_floor_reach(f: FloorLayout, tag: String) -> void:
	var all: Array[Obb] = f.walls.duplicate()
	all.append(FloorScenario.gate_collider(f))
	all.append_array(f.shop_solids)
	var reach := FloorReach.new()
	reach.build(f.bounds, all, PLAYER_RADIUS)
	var home := reach.region_at(f.start_pos)
	assert_gte(home, 0, tag)
	assert_eq(
		reach.region_at(ShopPlacement.front(f)),
		home,
		tag + ": the counter is reachable from the start"
	)


static func _overlap(a: Rect2, b: Rect2) -> bool:
	return a.intersection(b).get_area() > 0.0001


## As Main builds a floor: the stall's footprint is a wall of the world, the shop's spot is the counter, you can use
## it from its front and not from the tent's back, and no spawn point is left in the stall.
func test_as_main_builds_it_the_counter_is_the_shop() -> void:
	for s in [11, 12, 20261014]:
		var w := SaveLab.floor_world(s, 1)
		var f := w.floor_layout
		var reader := WorldReader.new(w)
		assert_true(reader.shop_stall(), "run %d: the shop is a stall" % s)
		assert_eq(w.shop.pos, f.shop_pos, "the shop stands at the counter")
		var keys := _keys(w.walls)
		for o in f.shop_solids:
			assert_true(keys.has(FloorLayout.piece_key(o)), "the stall is a wall")
		for i in f.walls.size():
			assert_eq(
				FloorLayout.piece_key(w.walls[i]),
				FloorLayout.piece_key(f.walls[i]),
				"layout walls first"
			)
		_put(w, ShopPlacement.front(f))
		assert_true(Shop.in_reach(w), "in reach at the counter's front")
		var tent := _piece(f, &"shop_tent")
		_put(w, (tent[1] as Vector2) - Kin.dir(f.shop_angle) * 2.4)
		assert_false(Shop.in_reach(w), "not from behind the tent")
		for q in w.spawn_points:
			for o in f.shop_solids:
				assert_eq(Collide.circle_vs_obb(q, 0.6, o), Vector2.ZERO, "no spawn in the stall")


## TEST HELPER (labelled): the player put at q (a reach check, not a walk; the e2e walks there by input).
static func _put(w: World, q: Vector2) -> void:
	w.actors.pos_x[0] = q.x
	w.actors.pos_y[0] = q.y


## Without shop rooms (a floor saved before SR; RunSaver.floor_tables leaves them out), the terminal stands.
func test_without_a_shop_room_the_terminal_stands() -> void:
	var run := SaveLab.run_state(11, 1)
	run.floor_rules = RunState.FLOOR_RULES_V080_RT1
	var w := SaveLab.build_floor(run)
	assert_true(w.shop.present())
	assert_false(WorldReader.new(w).shop_stall(), "the terminal")
	assert_eq(w.floor_layout.shop_layout, &"")
	var term := ShopPlacement.collider(w.floor_layout.shop_pos, w.floor_layout.shop_angle)
	assert_true(
		_keys(w.walls).has(FloorLayout.piece_key(term)), "the terminal's footprint is a wall"
	)


class ShopStallLike:
	## A shop_props entry's footprint on the sim plane (its size turned by its axis-aligned angle).
	static func bounds(p: Array) -> Rect2:
		var size: Vector2 = p[3]
		if (int(p[2]) & 4095) % 2048 != 0:
			size = Vector2(size.y, size.x)
		var c: Vector2 = p[1]
		return Rect2(c - size * 0.5, size)
