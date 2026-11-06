extends GutTest
## v0.7.5 NB2 (owner N3): Biome 5, Starfall, as data plus its look. Its content validates (a cosmic palette with the
## outline and the white hero readable on its ground, a dark starry mood, the starglow surface, the look); it is in the
## run's biome draw; its dressing swaps the kit's grass and rubble for code-made star crystals and meteorites and
## draws square cover as rocks and star monoliths, with the dresser's rules kept; the code-made pieces fit the unit
## box; a floor of it draws its starglow pools exactly where the sim has them and a starry void past its edge (the
## floor's rock and spikes, stars, nebula clouds, drifting rock and crystal islands), all of it below the ground and
## clear of the floor; its enemies take a violet cast on their grey parts only; its crystals take a nebula tint; and
## no other biome draws any of it (Frozen Shore keeps its ice and sea).

const SEEDS := 40

var _repo: ContentRepository
var _biome: BiomeDefinition


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_biome = _repo.get_def(&"biomes", &"starfall")


func test_the_biome_is_valid_readable_and_in_the_run_draw() -> void:
	assert_not_null(_biome, "data/biomes/starfall.tres loads")
	assert_eq(_biome.validate().size(), 0, "it validates")
	assert_eq(_biome.palette["ground"], Color("#7E779C"), "ART_DIRECTION §2's Starfall column")
	assert_eq(_biome.palette["edge"], Color("#2B1F55"))
	assert_gte(BiomeDefinition.contrast(_biome.palette["ground"], _biome.palette["outline"]), 3.0)
	assert_gte(
		BiomeDefinition.contrast(_biome.palette["ground"], Color("#F2F2F2")),
		3.0,
		"the white hero reads on the ground"
	)
	assert_eq(_biome.mood.problems().size(), 0)
	assert_lt(_biome.mood.void_color.get_luminance(), 0.05, "a dark void for the stars")
	assert_gt(_biome.mood.void_color.b, _biome.mood.void_color.g, "night-violet, not grey")
	assert_eq(_biome.surface.kind, &"starglow")
	var run: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	assert_eq(run.biomes[run.biomes.size() - 1], &"starfall", "appended last (saves keep indices)")
	assert_eq(run.biomes.find(&"frozen_shore"), 3, "Frozen Shore keeps its index")
	assert_eq(tr(_biome.name_key), "Starfall")
	assert_ne(tr(_biome.desc_key), String(_biome.desc_key), "its Codex line is in the locale")


func test_every_look_piece_resolves() -> void:
	var look := _biome.look
	assert_not_null(look)
	for id: Variant in look.square_cover:
		var p := StringName(str(id))
		assert_true(KitModels.SPECS.has(p) or CodeProps.has(p), "%s is a kit or code piece" % p)
		assert_false(StageKit.piece_of(p).is_empty(), "%s has a mesh" % p)
	for id: Variant in look.decor_swap:
		var to := StringName(str(look.decor_swap[id]))
		assert_true(KitModels.SPECS.has(to) or CodeProps.has(to), "%s draws as %s" % [id, to])
		assert_false(StageKit.piece_of(to).is_empty(), "%s has a mesh" % to)
	assert_eq(look.edge, &"stars")
	assert_true(BiomeEdge.has_style(look.edge))


func _floor(seed_value: int, look: BiomeLook) -> Dictionary:
	var layout := FloorGenerator.generate(seed_value)
	var walls: Array = []
	for i in layout.walls.size():
		var w := layout.walls[i]
		walls.append(
			[w.center, w.half, SimPlane.yaw_of(w.angle), 0 if i < layout.slab_first else 1]
		)
	var doors: Array = []
	for i in layout.door_rooms.size():
		doors.append(layout.door_rect(i))
	return {
		"walls": walls,
		"rooms": layout.rooms.duplicate(),
		"start_room": layout.start_room,
		"doors": doors,
		"keep_clear": [layout.portal_pos],
		"biome": &"starfall",
		"seed": seed_value,
		"square_cover": StageView._names(look.square_cover),
		"decor_swap": StageView._names(look.decor_swap),
	}


func test_the_dressing_takes_the_look_and_keeps_the_rules() -> void:
	var a := StageDresser.dress(_floor(78, _biome.look))
	var b := StageDresser.dress(_floor(78, _biome.look))
	assert_eq(a.size(), b.size(), "same seed, same floor")
	for k in a.size():
		assert_eq(a[k]["xform"], b[k]["xform"])
	var seen := {}
	for s in SEEDS:
		var f := _floor(1900 + s, _biome.look)
		var walls: Array = f["walls"]
		for p: Dictionary in StageDresser.dress(f):
			seen[p["piece"]] = true
			var xform: Transform3D = p["xform"]
			if p["kind"] == &"decor":
				assert_lte(xform.basis.y.length(), StageDresser.DECOR_MAX_HEIGHT + 0.0001)
				assert_false(
					p["piece"] in [&"grass_tuft", &"rubble_small", &"debris_low"],
					"the kit's grass and rubble are swapped"
				)
				continue
			if p["kind"] == &"cover" and walls[p["wall"]][3] == 1:
				var w: Array = walls[p["wall"]]
				var half: Vector2 = w[1]
				if maxf(half.x, half.y) / minf(half.x, half.y) < 1.6 and w.size() < 5:
					assert_true(
						p["piece"] in [&"rock_large", &"star_monolith"],
						"square cover: rocks and monoliths"
					)
				var c: Vector2 = SimPlane.to_sim(xform.origin)
				var local := (c - (w[0] as Vector2)).rotated(-(w[2] as float))
				assert_lte(absf(local.x), half.x + 0.05, "a cover piece sits on its footprint")
				assert_lte(absf(local.y), half.y + 0.05)
	for id: StringName in [&"star_crystal", &"meteorite", &"star_monolith", &"rock_large"]:
		assert_true(seen.has(id), "%s appears" % id)


func test_the_code_made_pieces_fit_the_unit_box() -> void:
	for id: StringName in [&"star_crystal", &"meteorite", &"star_monolith"]:
		var piece := CodeProps.get_piece(id)
		assert_false(piece.is_empty(), "%s builds" % id)
		var box := (piece["mesh"] as ArrayMesh).get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.001, "%s stands on y = 0" % id)
		assert_almost_eq(box.end.y, 1.0, 0.001, "%s reaches y = 1" % id)
		assert_almost_eq(box.position.x, -0.5, 0.001)
		assert_almost_eq(box.end.z, 0.5, 0.001)
	assert_eq(CodeProps.SPECS[&"star_monolith"]["role"], &"cover")
	for id: StringName in [&"star_crystal", &"meteorite"]:
		assert_lte(
			float(CodeProps.SPECS[id]["height"]), StageDresser.DECOR_MAX_HEIGHT, "%s low" % id
		)


## A Starfall floor as Main builds one (its pools laid), and its view.
func _starfall_view(run_seed: int) -> Array:
	var w := SaveLab.floor_world(run_seed, 1)
	IcePatches.place(w, BiomeCompiler.compile_surface(_biome))
	var reader := WorldReader.new(w)
	var v := WorldViewRoot.new()
	v.stage.mood = _biome.mood
	v.stage.prop_style = _biome.id
	v.stage.look = _biome.look
	v.actors.enemy_tint = _biome.look.enemy_tint
	add_child_autofree(v)
	v.setup(reader, _biome.palette, 60.0)
	return [v, reader]


func test_a_floor_draws_its_pools_where_the_sim_has_them_and_the_starry_void() -> void:
	var drawn := 0
	for s in 3:
		var r: Array = _starfall_view(400 + s)
		var v: WorldViewRoot = r[0]
		var reader: WorldReader = r[1]
		var before := reader.state_hash()
		assert_null(v.stage.ice, "no ice on Starfall")
		if reader.ice_patch_count() > 0:
			assert_eq(reader.surface_kind(), &"starglow")
			assert_not_null(v.stage.glow, "the pools are drawn")
			assert_eq(v.stage.glow.patch_count, reader.ice_patch_count(), "every pool, no more")
			var box := v.stage.glow.sheet.get_aabb()
			var lo := Vector2.INF
			var hi := -Vector2.INF
			for i in reader.ice_patch_count():
				lo = lo.min(reader.ice_patch(i).position)
				hi = hi.max(reader.ice_patch(i).end)
			assert_almost_eq(
				box.position.x, lo.x, 0.01, "the sheet starts where the sim's pools do"
			)
			assert_almost_eq(box.end.x, hi.x, 0.01, "and ends there")
			drawn += 1
		var e := v.stage.edge
		assert_not_null(e, "the starry void")
		assert_eq(e.style, &"stars")
		assert_null(e.water, "no sea")
		assert_not_null(e.underside, "the floor's rock underneath")
		assert_lt(e.underside.get_aabb().end.y, 0.0, "below the ground")
		assert_gt(e.star_count, 500, "a field of stars")
		assert_gt(e.spike_count, 20, "spikes hang from the rim")
		assert_gt(e.island_count, 5, "rock islands drift around")
		# v0.8.0 MI: the owner's island carries its own crystals (the code-made clusters only with the code islands).
		if StageKit.has_piece(&"floating_island_starfall"):
			assert_eq(e.crystal_count, 0, "the owner's islands bring their own crystals")
		else:
			assert_gt(e.crystal_count, 0, "some carry crystals")
		# v0.9.5 BG: the nebula clouds are off (the Deep image carries the nebulae); the const switch puts them back.
		if BiomeEdge.NEBULA_CLOUDS:
			assert_gte(e.nebula_count, StarVoid.NEBULA_MIN, "nebula clouds")
		else:
			assert_eq(e.nebula_count, 0, "no code-made nebula clouds under the backdrop")
		_assert_void_rules(reader.floor_ground(), reader.floor_bounds(), 400 + s)
		assert_eq(reader.state_hash(), before, "drawing it never touches the sim")
		v.queue_free()
	assert_gt(drawn, 0, "at least one of these floors has pools")


## The void's placements (StarVoid's own functions: a headless MultiMesh keeps no transforms to read back): stars
## below the ground and never hidden under the floor, islands and their crystals under the ground's level at the top
## of their bob and clear of the floor's edge.
func _assert_void_rules(ground: Array, bounds: Rect2, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sky: Array = StarVoid.star_xforms(ground, bounds, rng)
	assert_gt(sky[0].size(), 500)
	var hidden := 0
	for t: Transform3D in sky[0]:
		assert_lt(t.origin.y, 0.0)
		hidden += 1 if StarVoid._in_any(SimPlane.to_sim(t.origin), ground, 0.5) else 0
	assert_eq(hidden, 0, "no star hidden under the floor")
	var isles: Array = StarVoid.island_xforms(ground, bounds, rng)
	assert_gt(isles[0].size(), 5)
	for k in 2:
		for t: Transform3D in isles[k]:
			var top := t.origin.y + (t.basis.y.length() if k == 1 else 0.0)
			assert_lt(top + StarVoid.DRIFT_M, 0.0, "under the ground's level, bob included")
			assert_false(
				StarVoid._in_any(SimPlane.to_sim(t.origin), ground, StarVoid.ISLAND_KEEP),
				"clear of the floor"
			)
	for t: Transform3D in StarVoid.spike_xforms(ground, rng):
		assert_lt(t.origin.y, 0.0, "spikes hang under the floor")


func test_reduced_motion_stills_the_twinkle_and_the_drift() -> void:
	var was := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = true
	assert_eq(StarVoid.star_material().get_shader_parameter("motion"), 0.0)
	assert_eq(StarVoid.drift_material(Color.BLACK, false).get_shader_parameter("motion"), 0.0)
	assert_eq(StarglowViews.pool_material().get_shader_parameter("motion"), 0.0)
	ViewPrefs.reduced_motion = false
	assert_eq(StarVoid.star_material().get_shader_parameter("motion"), 1.0)
	ViewPrefs.reduced_motion = was


func test_the_other_biomes_draw_none_of_it() -> void:
	for id: StringName in [&"ruins", &"night_rocks", &"red_canyon"]:
		var b: BiomeDefinition = _repo.get_def(&"biomes", id)
		var w := SaveLab.floor_world(12, 1)
		w.ice = null
		var v := WorldViewRoot.new()
		v.stage.mood = b.mood
		v.stage.prop_style = b.id
		add_child_autofree(v)
		v.setup(WorldReader.new(w), b.palette, 60.0)
		assert_null(v.stage.glow, "%s: no pools" % id)
		assert_null(v.stage.edge, "%s: the void stays" % id)
		v.queue_free()
	var frozen: BiomeDefinition = _repo.get_def(&"biomes", &"frozen_shore")
	var fw := SaveLab.floor_world(300, 1)
	IcePatches.place(fw, BiomeCompiler.compile_surface(frozen))
	var fv := WorldViewRoot.new()
	fv.stage.mood = frozen.mood
	fv.stage.prop_style = frozen.id
	fv.stage.look = frozen.look
	add_child_autofree(fv)
	fv.setup(WorldReader.new(fw), frozen.palette, 60.0)
	assert_null(fv.stage.glow, "Frozen Shore: no pools")
	assert_not_null(fv.stage.edge.water, "Frozen Shore keeps its sea")
	assert_eq(fv.stage.edge.star_count, 0, "and no stars")
	fv.queue_free()


func test_enemies_take_a_violet_cast_on_grey_parts_only() -> void:
	var node := Node3D.new()
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("#5F5551")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#E25A4C")
	node.set_meta(&"mats", [grey, red])
	ActorViews.tint_greys(node, _biome.look.enemy_tint)
	assert_gt(grey.albedo_color.b, grey.albedo_color.g, "the grey turns violet")
	assert_eq(red.albedo_color, Color("#E25A4C"), "the enemy red never changes")
	node.free()


func test_the_crystals_take_a_nebula_tint_off_the_reserved_hues() -> void:
	assert_eq(ShardCluster.tint_key(&"starfall", false), &"starfall")
	assert_eq(ShardCluster.tint_key(&"starfall", true), &"deep", "a Deep floor still turns violet")
	for k in 2:
		var c: Color = ShardCluster.TINTS[&"starfall"][k]
		assert_ne(c, Color("#2BC4E2"), "off the player-core cyan")
		assert_ne(c, ShardCluster.TINTS[&"deep"][k], "off the Deep violet")
		assert_gt(c.r, c.g, "magenta-pink")
