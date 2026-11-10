extends GutTest
## v0.7.5 NB1 (owner N2): Frozen Shore's ice. The biome's surface compiles to an IceField (the other biomes have
## none); IcePatches lays its patches from the `map:ice` sub-stream, the same for the same seed, drawing nothing from
## the floor's own streams; over 1,000 seeds (each with a real boss's arena, as the game builds a floor) no patch is in
## the start hall, the boss room, the portal's room or the shop's room, every patch lies inside its room clear of
## doorways, walls, item spots, the start and the gates; on ice the hero speeds up and stops slowly (a slide), the
## dash is unchanged; ice is not hashed itself (laid from the seed), its slide is.

const FULL_SEEDS := 1000

var _seeds := Seeds.count(FULL_SEEDS)  # v0.11.1 Step 4: 200 here, 1,000 in the GitHub full suite
var _repo: ContentRepository
var _specs: Array[BossArenaSpec] = []
var _field: IceField


func before_all() -> void:
	_repo = ContentRepository.load_all()
	var bosses := ContentCompiler.compile_bosses(_repo)
	for b in bosses.size():
		_specs.append(BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b))
	_field = BiomeCompiler.compile_ice(_repo.get_def(&"biomes", &"frozen_shore"))


func _fresh() -> IceField:
	return BiomeCompiler.compile_ice(_repo.get_def(&"biomes", &"frozen_shore"))


## A floor as FloorScenario.build lays it (boss room, Overrun room, shop), with the player and its walls.
func _world(seed_value: int, spec: BossArenaSpec) -> World:
	var f := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ShopPlacement.pick(f)
	var w := World.new(seed_value, PlayerTable.starting_values(), f.start_pos)
	var walls: Array[Obb] = f.walls.duplicate()
	walls.append(FloorScenario.gate_collider(f))
	w.set_walls(walls)
	w.floor_layout = f
	return w


func test_only_frozen_shore_has_ice() -> void:
	assert_not_null(_field, "Frozen Shore's surface compiles")
	assert_gt(_field.accel_permille, 0)
	assert_lt(_field.accel_permille, 319, "slower to speed up than the hero's own 319")
	assert_lt(_field.decel_permille, 369, "slower to stop than the hero's own 369")
	for id: StringName in [&"ruins", &"night_rocks", &"red_canyon"]:
		assert_null(BiomeCompiler.compile_ice(_repo.get_def(&"biomes", id)), "%s: no ice" % id)


func test_same_seed_same_patches_and_no_floor_stream_moves() -> void:
	for s in [3, 77, 20261006]:
		var a := _world(s, _specs[0])
		var b := _world(s, _specs[0])
		var map_state := a.rng_map.state
		IcePatches.place(a, _fresh())
		IcePatches.place(b, _fresh())
		assert_eq(a.ice.rects, b.ice.rects, "seed %d: the same patches" % s)
		assert_eq(a.rng_map.state, map_state, "the map stream is untouched")


## v0.11.1 Step 4: the loop is SurfaceSoak's, shared with test_starglow_patches.gd.
func test_patches_keep_their_rules_over_1000_seeds() -> void:
	var out := SurfaceSoak.soak(_seeds, 9100, _specs, _fresh, _field)
	gut.p(
		(
			"ice over %d floors: %d patches, %d floors with ice (%d ms)"
			% [_seeds, out.total, out.floors_with, out.ms]
		)
	)
	assert_eq(out.broken, {}, "no rule broken (rule -> first seed)")
	assert_gt(out.floors_with, _seeds * 8 / 10, "most Frozen Shore floors have ice")
	assert_lt(out.total, _seeds * 12, "ice stays a few patches a floor, not a rink")


## A world with one patch under the hero (or none), the hero run right for 30 ticks and then released.
func _slide(on_ice: bool) -> Array:
	var w := World.new(1, PlayerTable.starting_values())
	if on_ice:
		var field := _fresh()
		field.rects.append(Rect2(-20, -20, 40, 40))
		w.ice = field
	var top := w.player.move_speed
	var p := w.player_pos()
	w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var first := (w.player_pos() - p).length() / top
	for i in 29:
		w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	var released := w.player_pos()
	for i in 60:
		w.step(InputFrame.new())
	return [first, (w.player_pos() - released).length()]


func test_on_ice_the_hero_slides() -> void:
	var dry := _slide(false)
	var ice := _slide(true)
	assert_lt(ice[0], dry[0] * 0.6, "a slower start on ice")
	assert_gt(ice[1], dry[1] * 3.0, "a much longer stop on ice")
	assert_lt(ice[1], 3.5, "but it still stops within a few metres")
	assert_true(IcePatches.on_ice(_world_on_ice()), "the reader's question answers true on a patch")


func _world_on_ice() -> World:
	var w := World.new(1, PlayerTable.starting_values())
	var field := _fresh()
	field.rects.append(Rect2(-1, -1, 2, 2))
	w.ice = field
	return w


func test_the_dash_is_the_same_on_ice() -> void:
	var dashes: Array[float] = []
	for on_ice in [false, true]:
		var w := World.new(1, PlayerTable.starting_values())
		if on_ice:
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
	assert_almost_eq(dashes[1], dashes[0], 0.05, "the dash covers the same ground (a fair escape)")


func test_ice_moves_the_hash_only_through_the_slide() -> void:
	var a := World.new(5, PlayerTable.starting_values())
	var b := World.new(5, PlayerTable.starting_values())
	var field := _fresh()
	field.rects.append(Rect2(-20, -20, 40, 40))
	b.ice = field
	assert_eq(
		a.state_hash(), b.state_hash(), "laid from the seed like the layout: not hashed itself"
	)
	for i in 10:
		var go := InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0)
		a.step(go)
		b.step(go)
	assert_ne(a.state_hash(), b.state_hash(), "the slide shows in the hashed position and velocity")
