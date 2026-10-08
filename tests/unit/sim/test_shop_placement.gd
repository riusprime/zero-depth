extends GutTest
## v0.5.0 SH (PLAN R1): one shop per floor, in a side room, reachable. A property test over 1,000 seeds, each with a
## real boss's arena (in turn), as the game builds a floor: FloorGenerator.generate, BossRoomBuilder.attach, then
## ShopPlacement.pick. The shop is never in the start hall, the boss room or the room before the boss door; its
## terminal stands in its room clear of walls; its room stays one region with the terminal in it; and (every 25th
## seed, on the whole floor) its front is reachable from the start at the player's radius.

const SEEDS := 1000
const PLAYER_RADIUS := 0.35

var _specs: Array[BossArenaSpec] = []


func before_all() -> void:
	var bosses := ContentCompiler.compile_bosses(ContentRepository.load_all())
	for b in bosses.size():
		_specs.append(BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b))


func _floor(seed_value: int, spec: BossArenaSpec) -> FloorLayout:
	var f := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(f, spec)
	ShopPlacement.pick(f)
	return f


func test_same_seed_same_shop() -> void:
	for s in [3, 77, 20261006]:
		var a := _floor(s, _specs[0])
		var b := _floor(s, _specs[0])
		assert_eq([a.shop_room, a.shop_pos, a.shop_angle], [b.shop_room, b.shop_pos, b.shop_angle])


func test_the_pick_draws_no_map_numbers() -> void:
	var a := FloorGenerator.generate(41)
	BossRoomBuilder.attach(a, _specs[0])
	var walls := a.walls.size()
	var spots := a.item_spots.duplicate()
	ShopPlacement.pick(a)
	assert_eq(a.walls.size(), walls, "the pick adds no wall to the layout")
	assert_eq(a.item_spots, spots, "the item spots are untouched")


func test_one_reachable_shop_in_a_side_room_over_1000_seeds() -> void:
	var dead_ends := 0
	var rooms_seen := {}
	var failures := 0
	var t0 := Time.get_ticks_msec()
	for s in SEEDS:
		var seed_value := 7000 + s * 7919
		var f := _floor(seed_value, _specs[s % _specs.size()])
		var tag := "seed %d" % seed_value
		if f.shop_room < 0:
			failures += 1
			assert_true(false, tag + ": no shop")
			continue
		var room := f.shop_room
		rooms_seen[f.room_cells[room].size] = true
		assert_ne(room, f.start_room, tag + ": not the start hall")
		assert_ne(room, f.boss_room, tag + ": not the boss room")
		assert_ne(room, f.boss_host_room, tag + ": not the room before the boss door")
		assert_gt(f.hops[room], 0, tag + ": joined to the start by doorways")
		if f.neighbours(room).size() == 1:
			dead_ends += 1
		assert_eq(f.room_of(f.shop_pos), room, tag + ": the terminal stands in its room")
		var box := ShopPlacement.collider(f.shop_pos, f.shop_angle)
		for k in f.walls.size():
			if (
				Collide.circle_vs_obb(f.shop_pos, ShopPlacement.FOOTPRINT_HALF_M, f.walls[k])
				!= Vector2.ZERO
			):
				assert_true(false, tag + ": the terminal overlaps a wall")
				break
		# The room at the player's radius, with the terminal: one region holding its doorways and the front.
		var walls: Array[Obb] = f.walls.duplicate()
		walls.append(box)
		var reach := FloorReach.new()
		reach.build(f.rooms[room], walls, PLAYER_RADIUS)
		var front_region := reach.region_at(ShopPlacement.front(f))
		assert_gte(front_region, 0, tag + ": the front is open")
		for a in ShopPlacement.door_approaches(f, room):
			assert_eq(reach.region_at(a), front_region, tag + ": a doorway reaches the terminal")
		if s % 25 == 0:
			_check_floor_reach(f, walls, tag)
	var ms := Time.get_ticks_msec() - t0
	assert_eq(failures, 0, "every floor has a shop")
	gut.p(
		(
			"shops: %d floors, %d with a shop, %d in a dead end, %d room footprints, %d ms"
			% [SEEDS, SEEDS - failures, dead_ends, rooms_seen.size(), ms]
		)
	)
	assert_gt(dead_ends, SEEDS / 2, "mostly in a dead end (a side room)")


## The whole floor (gate and terminal as walls) at the player's radius: the front is in the start's region.
func _check_floor_reach(f: FloorLayout, walls: Array[Obb], tag: String) -> void:
	var all: Array[Obb] = walls.duplicate()
	all.append(FloorScenario.gate_collider(f))
	var reach := FloorReach.new()
	reach.build(f.bounds, all, PLAYER_RADIUS)
	var home := reach.region_at(f.start_pos)
	assert_gte(home, 0, tag)
	assert_eq(
		reach.region_at(ShopPlacement.front(f)),
		home,
		tag + ": the shop is reachable from the start"
	)
