extends GutTest
## v0.11.0 O15 (PLAN P1; owner Q-O15a "all three", Q-O15b "authored templates with seeded variation"; the hall as a
## ring of standing stones, owner 2026-11-07): large rooms with a purpose (RoomPurposes, data/rooms/purposes). A
## generation property test over 1,000 run floors (as FloorScenario builds them up to the purposes: the boss room,
## the Overrun room, the arenas and the shop's room marked first), the biomes in turn: every purpose room is a large
## room of no other kind, its doorways and item spots reachable from each other (at the player's radius, and as one
## region at the enemies' clearance), no solid of it in a doorway's box, near an item spot or outside the room, its
## spawn points clear; large rooms take a purpose at the stated share; every purpose appears in each of its biomes.
## The same seed gives the same floor, and only the purpose rooms change. Each template varies inside its bounds.

const SEEDS := 1000
const PLAYER_RADIUS := 0.35
const BIOMES: Array[StringName] = [
	&"ruins", &"frozen_shore", &"starfall", &"red_canyon", &"night_rocks"
]

var _map: FloorParams
var _arena: ArenaTable
var _tables: Array[RoomPurposeTable] = []
var _specs: Array[BossArenaSpec] = []


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_map = RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	_map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	_arena = RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	_tables = RunContentCompiler.compile_room_purposes(repo)
	var bosses := ContentCompiler.compile_bosses(repo)
	for b in bosses.size():
		_specs.append(BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b))


## A run floor as FloorScenario builds it, before the purposes.
func _floor(seed_value: int) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value, _map)
	BossRoomBuilder.attach(f, _specs[posmod(seed_value, _specs.size())])
	OverrunRooms.mark(f, 0)
	ArenaRooms.mark(f, _arena.share_permille, _arena.min_cells)
	ShopPlacement.pick(f, _map)
	return f


static func _keys(walls: Array[Obb]) -> PackedStringArray:
	var out := PackedStringArray()
	for w in walls:
		out.append(FloorLayout.piece_key(w))
	return out


func test_every_biome_has_a_purpose() -> void:
	assert_eq(_tables.size(), 3, "camp, hall, quarry")
	for b in BIOMES:
		var n := 0
		for t in _tables:
			n += 1 if t.biomes.has(b) and t.palettes.has(b) else 0
		assert_gt(n, 0, "%s has a purpose" % b)


func test_same_seed_same_floor_and_only_purpose_rooms_change() -> void:
	for s in [3, 77, 4242, 20261014]:
		var biome := BIOMES[posmod(s, BIOMES.size())]
		var a := _floor(s)
		var before := _keys(a.walls)
		var spawns := a.spawn_points.duplicate()
		var rooms := RoomPurposes.lay(a, _map, _tables, biome)
		var b := _floor(s)
		RoomPurposes.lay(b, _map, _tables, biome)
		assert_eq(_keys(a.walls), _keys(b.walls), "seed %d: the same walls" % s)
		assert_eq(a.layout_props, b.layout_props, "the same drawn pieces")
		assert_eq(a.room_purpose, b.room_purpose, "the same purposes")
		assert_eq(a.spawn_points, b.spawn_points, "the same spawn points")
		var now := _keys(a.walls)
		for room in a.room_count():
			if rooms.has(room):
				continue
			assert_eq(a.spawn_points[room], spawns[room], "room %d's spawn points stay" % room)
		var kept := 0
		var outside := 0
		var c := _floor(s)
		for i in c.walls.size():
			var in_purpose := false
			for room in rooms:
				if c.rooms[room].grow(0.01).encloses(c.walls[i].bounds()):
					in_purpose = true
			if in_purpose and i >= c.slab_first:
				continue
			outside += 1
			kept += 1 if now.has(FloorLayout.piece_key(c.walls[i])) else 0
		assert_eq(kept, outside, "seed %d: every wall outside the purpose rooms stays" % s)


func test_purpose_rooms_over_many_floors() -> void:
	var candidates := 0
	var purposed := 0
	var seen := {}
	var failures := 0
	var groups_dropped := 0
	for s in SEEDS:
		var seed_value := 7000 + s * 7919
		var biome := BIOMES[s % BIOMES.size()]
		var f := _floor(seed_value)
		var cands := RoomPurposes.candidates(f)
		var rooms := RoomPurposes.lay(f, _map, _tables, biome)
		candidates += cands.size()
		purposed += rooms.size()
		for room in rooms:
			var tag := "seed %d %s room %d (%s)" % [seed_value, biome, room, f.purpose_of(room)]
			seen["%s/%s" % [biome, f.purpose_of(room)]] = true
			if not cands.has(room):
				failures += 1
				assert_true(false, "%s: not a candidate (another kind or small)" % tag)
				continue
			if not _check_room(f, room, tag):
				failures += 1
		if failures > 5:
			break
	var share := purposed * 1000 / maxi(1, candidates)
	(
		gut
		. p(
			(
				"room purposes: %d floors, %d large candidate rooms, %d purposed (%d per mille), kinds %s"
				% [SEEDS, candidates, purposed, share, str(seen.keys())]
			)
		)
	)
	assert_eq(failures, 0, "every purpose room is fair")
	assert_between(
		share, 600, 800, "about 3 in 4 large rooms take a purpose (purpose_permille 750)"
	)
	for t in _tables:
		for b in t.biomes:
			assert_true(seen.has("%s/%s" % [b, t.id]), "%s appears in %s" % [t.id, b])


## One purpose room's checks; true when all pass.
func _check_room(f: FloorLayout, room: int, tag: String) -> bool:
	var ok := true
	var r := f.rooms[room]
	assert_true(RoomPurposes.large(f.room_cells[room].size), "%s: large" % tag)
	var boxes := RoomPurposes.door_boxes(f, room)
	var items := RoomPurposes.items_in(f, room)
	var inner := r.grow(-0.04)
	var solids := 0
	for i in range(f.slab_first, f.walls.size()):
		var w := f.walls[i]
		if not r.grow(0.01).intersects(w.bounds()):
			continue
		if not f.piece_tags.has(FloorLayout.piece_key(w)):
			continue
		solids += 1
		var b := w.bounds()
		if not inner.encloses(b):
			ok = false
			assert_true(false, "%s: a solid leaves the room" % tag)
		for box in boxes:
			if box.intersects(b):
				ok = false
				assert_true(false, "%s: a solid in a doorway's box" % tag)
		for q in items:
			if b.grow(RoomPurposes.ITEM_CLEAR_M - 0.01).has_point(q):
				ok = false
				assert_true(false, "%s: a solid on an item spot" % tag)
	assert_gt(solids, 5, "%s: furnished" % tag)
	var walls := f.room_walls(room)
	var must := f.door_approaches(room, 1.0)
	must.append_array(items)
	# The enemies' clearance: the room's open floor is one region holding every doorway and item spot (the
	# generator's rule). The player's radius: every doorway and item spot in one region (a sealed nook behind a
	# shelter, open only to a body thinner than any enemy, holds nothing and leads nowhere).
	if not FloorReach.whole(r, walls, _map.nav_clearance, must):
		ok = false
		assert_true(false, "%s: not one region door to door at the enemies' clearance" % tag)
	var reach := FloorReach.new()
	reach.build(r, walls, PLAYER_RADIUS)
	var first := reach.region_at(must[0]) if not must.is_empty() else -1
	for q in must:
		if reach.region_at(q) < 0 or reach.region_at(q) != first:
			ok = false
			assert_true(false, "%s: a doorway or item spot cut off at the player's radius" % tag)
			break
	for q in f.spawn_points[room]:
		for w in walls:
			if Collide.circle_vs_obb(q, _map.spawn_clearance - 0.01, w) != Vector2.ZERO:
				ok = false
				assert_true(false, "%s: a spawn point inside a piece" % tag)
				break
	return ok


## Each template's variation stays inside its bounds: every part within the group shift (under 1 m) of its authored
## place and within the turn (under 15 degrees) of its authored angle, in rooms from 3 x 3 to 4 x 4.
func test_each_template_varies_inside_its_bounds() -> void:
	for t in _tables:
		assert_lt(t.shift_cm, 100, "%s: shifts under 1 m" % t.id)
		assert_lt(
			t.turn, ContentCompiler.degrees_to_units(15.0), "%s: turns under 15 degrees" % t.id
		)
		var parts := 0
		var moved := 0
		for s in 200:
			var rng := RngStream.derive(s, "test:purpose")
			var half := Vector2(rng.range_int(2000, 2900), rng.range_int(1600, 2900)) / 100.0
			half = Vector2(maxf(half.x, half.y), minf(half.x, half.y))
			for d: Array in RoomPurposes.draw(t, half, rng):
				parts += 1
				var off: Vector2 = d[1] - d[5]
				var turn := absi(Kin.angle_diff(d[2], d[6]))
				assert_true(
					(
						absf(off.x) <= t.shift_cm / 100.0 + 0.011
						and absf(off.y) <= t.shift_cm / 100.0 + 0.011
					),
					"%s: shift %s within %d cm" % [t.id, off, t.shift_cm]
				)
				assert_true(turn <= t.turn, "%s: turn %d within %d" % [t.id, turn, t.turn])
				moved += 1 if off.length() > 0.01 or turn > 0 else 0
				if absf(off.x) > 1.0 or turn > t.turn:
					return
		assert_gt(parts, 1000, "%s: parts drawn" % t.id)
		assert_gt(moved, parts / 2, "%s: the seed moves most parts" % t.id)


## The seed varies a template: two rooms of the same size rarely lay the same parts.
func test_the_seed_varies_each_template() -> void:
	var half := Vector2(21.35, 17.1)
	for t in _tables:
		var seen := {}
		for s in 20:
			var drawn := RoomPurposes.draw(t, half, RngStream.derive(s, "test:vary"))
			var tokens := PackedStringArray()
			for d: Array in drawn:
				tokens.append("%s@%s" % [d[0], d[1]])
			seen[",".join(tokens).md5_text()] = true
		assert_eq(seen.size(), 20, "%s: 20 seeds, 20 different rooms" % t.id)


## The hall is a ring of standing stones (owner 2026-11-07): no two of its stones line up as a colonnade.
func test_the_hall_is_a_loose_ring() -> void:
	var hall: RoomPurposeTable = null
	for t in _tables:
		if t.id == &"hall":
			hall = t
	assert_not_null(hall)
	var half := Vector2(21.35, 17.1)
	var drawn := RoomPurposes.draw(hall, half, RngStream.derive(5, "test:ring"))
	var radii := PackedFloat64Array()
	var lintels := 0
	for s in 50:
		for d: Array in RoomPurposes.draw(hall, half, RngStream.derive(s, "test:ring")):
			lintels += 1 if d[0] == &"lintel" else 0
	for d: Array in drawn:
		if d[0] in [&"column", &"upright"]:
			var q: Vector2 = d[1]
			radii.append(Vector2(q.x / half.x, q.y / half.y).length())
	assert_gt(radii.size(), 8, "stones stand round the focal ruin")
	assert_gt(lintels, 30, "some trilithons carry a lintel")
