extends GutTest
## v0.7.5 NB2 (owner N3): Starfall's starglow pools. The biome's surface compiles to a starglow field (only Starfall
## has one; Frozen Shore keeps its ice, unchanged); IcePatches lays the pools from their own `map:starglow` sub-stream
## (not `map:ice`, never the floor's own streams), the same for the same seed; over 1,000 seeds (each with a real
## boss's arena, as the game builds a floor) no pool is in the start hall, the boss room, the portal's room or the
## shop's room, and every pool lies inside its room clear of doorways, walls, item spots, the start and the gates; on a
## pool the hero runs faster (speed_scale) and stops within a short drift; the dash is unchanged; the pools are not
## hashed themselves (laid from the seed), the faster step is.

const SEEDS := 1000

var _repo: ContentRepository
var _specs: Array[BossArenaSpec] = []
var _field: IceField


func before_all() -> void:
	_repo = ContentRepository.load_all()
	var bosses := ContentCompiler.compile_bosses(_repo)
	for b in bosses.size():
		_specs.append(BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b))
	_field = _fresh()


func _fresh() -> IceField:
	return BiomeCompiler.compile_surface(_repo.get_def(&"biomes", &"starfall"))


func test_only_starfall_has_starglow_and_ice_is_unchanged() -> void:
	assert_not_null(_field, "Starfall's surface compiles")
	assert_eq(_field.kind, &"starglow")
	assert_eq(_field.speed_permille, 1250, "a quarter faster on a pool")
	assert_null(
		BiomeCompiler.compile_ice(_repo.get_def(&"biomes", &"starfall")), "starglow is not ice"
	)
	var ice := BiomeCompiler.compile_surface(_repo.get_def(&"biomes", &"frozen_shore"))
	assert_eq(ice.kind, &"ice", "Frozen Shore keeps its ice")
	assert_eq(ice.speed_permille, 1000, "ice never changes the top speed")
	assert_eq(IcePatches.stream_of(&"ice"), "map:ice", "the ice stream is the same as in NB1")
	assert_eq(IcePatches.stream_of(&"starglow"), "map:starglow")
	for id: StringName in [&"ruins", &"night_rocks", &"red_canyon"]:
		assert_null(BiomeCompiler.compile_surface(_repo.get_def(&"biomes", id)), "%s: none" % id)


## A floor as FloorScenario.build lays it (boss room, Overrun room, shop), with the player and its walls.
func _world(seed_value: int, spec: BossArenaSpec) -> World:
	var lw := _layout(seed_value, spec)
	var f: FloorLayout = lw[0]
	var w := World.new(seed_value, PlayerTable.starting_values(), f.start_pos)
	w.set_walls(lw[1])
	w.floor_layout = f
	return w


func _layout(seed_value: int, spec: BossArenaSpec) -> Array:
	var f := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ShopPlacement.pick(f)
	var walls: Array[Obb] = f.walls.duplicate()
	walls.append(FloorScenario.gate_collider(f))
	return [f, walls]


func test_same_seed_same_pools_on_their_own_stream() -> void:
	var differs := 0
	for s in [3, 77, 20261006, 20261009, 555]:
		var a := _world(s, _specs[0])
		var b := _world(s, _specs[0])
		var map_state := a.rng_map.state
		IcePatches.place(a, _fresh())
		IcePatches.place(b, _fresh())
		assert_eq(a.ice.rects, b.ice.rects, "seed %d: the same pools" % s)
		assert_eq(a.rng_map.state, map_state, "the map stream is untouched")
		# The same numbers drawn as ice (the `map:ice` stream) land elsewhere: the streams are apart.
		var as_ice := _fresh()
		as_ice.kind = &"ice"
		IcePatches.lay(a.floor_layout, a.walls, s, as_ice)
		if as_ice.rects != a.ice.rects:
			differs += 1
	assert_gt(differs, 2, "map:starglow is not map:ice")


## The rules one floor's pools break, as short strings (empty: none).
func _broken(f: FloorLayout, walls: Array[Obb], rects: Array[Rect2]) -> PackedStringArray:
	var out := PackedStringArray()
	var c := _field.clearance_m - 0.001
	for r in rects:
		var room := f.room_of(r.get_center())
		if room < 0:
			out.append("outside every room")
			continue
		if room in [f.start_room, f.boss_room, f.portal_room, f.shop_room]:
			out.append("in the start, boss, portal or shop room")
		if not f.rooms[room].grow(-c).encloses(r):
			out.append("too close to its room's walls")
		var grown := r.grow(c)
		for i in f.door_centers.size():
			if grown.intersects(f.door_rect(i)):
				out.append("on a doorway")
		for o in walls:
			if grown.intersects(o.bounds()):
				out.append("on a wall or cover")
		for p in [f.start_pos, f.portal_pos]:
			if grown.has_point(p):
				out.append("on the start or the gate")
		for p in f.item_spots:
			if grown.has_point(p):
				out.append("on an item spot")
		if minf(r.size.x, r.size.y) < _field.size_min_dm / 10.0 - 0.001:
			out.append("too small")
		if maxf(r.size.x, r.size.y) > _field.size_max_dm / 10.0 + 0.001:
			out.append("too big")
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				out.append("overlapping")
	return out


func test_pools_keep_their_rules_over_1000_seeds() -> void:
	var total := 0
	var floors_with := 0
	var broken := {}
	var t0 := Time.get_ticks_msec()
	for s in SEEDS:
		var seed_value := 7300 + s * 7919
		var lw := _layout(seed_value, _specs[s % _specs.size()])
		var field := _fresh()
		IcePatches.lay(lw[0], lw[1], seed_value, field)
		total += field.rects.size()
		floors_with += 1 if not field.rects.is_empty() else 0
		for why in _broken(lw[0], lw[1], field.rects):
			if not broken.has(why):
				broken[why] = "seed %d" % seed_value
	gut.p(
		(
			"starglow over %d floors: %d pools, %d floors with pools (%d ms)"
			% [SEEDS, total, floors_with, Time.get_ticks_msec() - t0]
		)
	)
	assert_eq(broken, {}, "no rule broken (rule -> first seed)")
	assert_gt(floors_with, SEEDS * 7 / 10, "most Starfall floors have pools")
	assert_lt(total, SEEDS * 12, "a few pools a floor, not a carpet")


## A world with one pool under the hero (or none): [top speed per tick after 30 ticks running right, how far the
## hero goes after letting go].
func _run(on_pool: bool) -> Array:
	var w := World.new(1, PlayerTable.starting_values())
	if on_pool:
		var field := _fresh()
		field.rects.append(Rect2(-30, -30, 60, 60))
		w.ice = field
	for i in 30:
		w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var p := w.player_pos()
	w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var top := (w.player_pos() - p).length()
	var released := w.player_pos()
	for i in 60:
		w.step(InputFrame.new())
	return [top, (w.player_pos() - released).length()]


func test_on_a_pool_the_hero_runs_faster_and_still_stops() -> void:
	var dry := _run(false)
	var pool := _run(true)
	assert_almost_eq(pool[0], dry[0] * 1.25, dry[0] * 0.02, "a quarter faster at full run")
	assert_gt(pool[1], dry[1], "a short drift when letting go")
	assert_lt(pool[1], 1.5, "but it stops within a step or two (not a slide)")


func test_the_dash_is_the_same_on_a_pool() -> void:
	var dashes: Array[float] = []
	for on_pool in [false, true]:
		var w := World.new(1, PlayerTable.starting_values())
		if on_pool:
			var field := _fresh()
			field.rects.append(Rect2(-20, -20, 40, 40))
			w.ice = field
		var p := w.player_pos()
		var f := InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0)
		f.pressed = InputFrame.DASH
		f.held = InputFrame.DASH
		w.step(f)
		for i in w.player.dash_ticks - 1:
			w.step(InputFrame.new())
		dashes.append((w.player_pos() - p).length())
	assert_almost_eq(dashes[1], dashes[0], 0.05, "the dash covers the same ground")


func test_pools_move_the_hash_only_through_the_step() -> void:
	var a := World.new(5, PlayerTable.starting_values())
	var b := World.new(5, PlayerTable.starting_values())
	var field := _fresh()
	field.rects.append(Rect2(-20, -20, 40, 40))
	b.ice = field
	assert_eq(a.state_hash(), b.state_hash(), "laid from the seed like the layout: not hashed")
	for i in 10:
		var go := InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0)
		a.step(go)
		b.step(go)
	assert_ne(a.state_hash(), b.state_hash(), "the faster step shows in the hashed position")
