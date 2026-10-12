extends GutTest
## v0.7.5 NB1 (owner N2): Biome 4, Frozen Shore, as data plus its look. Its content validates (the palette from
## ART_DIRECTION §2, a cold mood, the ice surface, the look); it is in the run's biome draw; its dressing swaps the
## kit's grass and rubble for code-made snow drifts and ice shards and draws square cover as slate rocks and dead
## trees, with the dresser's rules kept (same seed same floor, decoration low, cover on its footprint); the code-made
## pieces fit the unit box and face out; a floor of it draws its ice patches exactly where the sim has them and a
## frozen sea with floes past its edge; its enemies take a cold cast on their grey parts only; its crystals take an
## icy tint; and the first three biomes draw nothing of it.

const SEEDS := 40

var _repo: ContentRepository
var _biome: BiomeDefinition


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_biome = _repo.get_def(&"biomes", &"frozen_shore")


func test_the_biome_is_valid_and_in_the_run_draw() -> void:
	assert_not_null(_biome, "data/biomes/frozen_shore.tres loads")
	assert_eq(_biome.validate().size(), 0, "it validates")
	assert_eq(_biome.palette["ground"], Color("#D1DAE4"), "ART_DIRECTION §2's sampled snow")
	assert_eq(_biome.palette["edge"], Color("#436C8E"), "and its water")
	assert_gte(BiomeDefinition.contrast(_biome.palette["ground"], _biome.palette["outline"]), 3.0)
	assert_eq(_biome.mood.problems().size(), 0)
	assert_lt(_biome.mood.sun_color.r, _biome.mood.sun_color.b, "a cold, pale moon")
	assert_gt(_biome.mood.fog_density, 0.0, "icy fog")
	var run: RunDefinition = _repo.get_def(&"run", &"three_floors")
	assert_has(run.biomes, &"frozen_shore", "it enters the run's biome draw")
	assert_eq(tr(_biome.name_key), "Frozen Shore")


func test_every_look_piece_resolves() -> void:
	var look := _biome.look
	assert_not_null(look)
	for id: Variant in look.square_cover:
		assert_true(KitModels.SPECS.has(StringName(str(id))), "%s is a kit piece" % id)
	for id: Variant in look.decor_swap:
		var to := StringName(str(look.decor_swap[id]))
		assert_true(KitModels.SPECS.has(to) or CodeProps.has(to), "%s draws as %s" % [id, to])
		assert_false(StageKit.piece_of(to).is_empty(), "%s has a mesh" % to)
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
	var f := {
		"walls": walls,
		"rooms": layout.rooms.duplicate(),
		"start_room": layout.start_room,
		"doors": doors,
		"keep_clear": [layout.portal_pos],
		"biome": &"frozen_shore",
		"seed": seed_value,
	}
	if look != null:
		f["square_cover"] = StageView._names(look.square_cover)
		f["decor_swap"] = StageView._names(look.decor_swap)
	return f


func test_the_dressing_takes_the_look_and_keeps_the_rules() -> void:
	var a := StageDresser.dress(_floor(77, _biome.look))
	var b := StageDresser.dress(_floor(77, _biome.look))
	assert_eq(a.size(), b.size(), "same seed, same floor")
	for k in a.size():
		assert_eq(a[k]["xform"], b[k]["xform"])
	var seen := {}
	for s in SEEDS:
		var f := _floor(900 + s, _biome.look)
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
						p["piece"] in [&"rock_large", &"dead_tree"], "square cover: rocks and trees"
					)
				var c: Vector2 = SimPlane.to_sim(xform.origin)
				var local := (c - (w[0] as Vector2)).rotated(-(w[2] as float))
				assert_lte(absf(local.x), half.x + 0.05, "a cover piece sits on its footprint")
				assert_lte(absf(local.y), half.y + 0.05)
	for id: StringName in [&"snow_drift", &"ice_shard", &"rock_large"]:
		assert_true(seen.has(id), "%s appears" % id)


func test_the_code_made_pieces_fit_the_unit_box_and_face_out() -> void:
	for id: StringName in CodeProps.SPECS:
		var piece := CodeProps.get_piece(id)
		assert_false(piece.is_empty(), "%s builds" % id)
		var mesh: ArrayMesh = piece["mesh"]
		var box := mesh.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.001, "%s stands on y = 0" % id)
		assert_almost_eq(box.end.y, 1.0, 0.001, "%s reaches y = 1" % id)
		assert_almost_eq(box.position.x, -0.5, 0.001)
		assert_almost_eq(box.end.z, 0.5, 0.001)
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		assert_lt(verts.size(), 200, "%s stays low-poly" % id)
		var out := 0
		for k in range(0, verts.size(), 3):
			var c := (verts[k] + verts[k + 1] + verts[k + 2]) / 3.0
			var face := (verts[k + 1] - verts[k]).cross(verts[k + 2] - verts[k])
			if normals[k].dot(c - Vector3(0, 0.35, 0)) > -0.05:
				out += 1
			assert_lt(face.dot(normals[k]), 0.0001, "%s: wound clockwise seen from outside" % id)
		if id == &"snow_drift":  # one mound: every facet looks away from its middle (the spikes lean apart)
			assert_gt(float(out), verts.size() / 3.0 * 0.85, "%s faces out" % id)


## A Frozen Shore floor as Main builds one (its ice laid), and its view.
func _frozen_view(run_seed: int) -> Array:
	var w := SaveLab.floor_world(run_seed, 1)
	IcePatches.place(w, BiomeCompiler.compile_ice(_biome))
	var reader := WorldReader.new(w)
	var v := WorldViewRoot.new()
	v.stage.mood = _biome.mood
	v.stage.prop_style = _biome.id
	v.stage.look = _biome.look
	v.actors.enemy_tint = _biome.look.enemy_tint
	add_child_autofree(v)
	v.setup(reader, _biome.palette, 60.0)
	return [v, reader]


func test_a_floor_draws_its_ice_where_the_sim_has_it_and_the_frozen_sea() -> void:
	var drawn := 0
	for s in 3:
		var r: Array = _frozen_view(300 + s)
		var v: WorldViewRoot = r[0]
		var reader: WorldReader = r[1]
		var before := reader.state_hash()
		if reader.ice_patch_count() > 0:
			assert_not_null(v.stage.ice, "the ice is drawn")
			assert_eq(v.stage.ice.patch_count, reader.ice_patch_count(), "every patch, no more")
			var sheet := v.stage.ice.get_node("IceSheet") as MeshInstance3D
			var box := sheet.get_aabb()
			var lo := Vector2.INF
			var hi := -Vector2.INF
			for i in reader.ice_patch_count():
				lo = lo.min(reader.ice_patch(i).position)
				hi = hi.max(reader.ice_patch(i).end)
			assert_almost_eq(
				box.position.x, lo.x, 0.01, "the sheet starts where the sim's ice does"
			)
			assert_almost_eq(box.end.x, hi.x, 0.01, "and ends there")
			drawn += 1
		assert_not_null(v.stage.edge, "the frozen sea")
		assert_not_null(v.stage.edge.water)
		assert_lt(v.stage.edge.water.position.y, 0.0, "below the ground")
		assert_gt(v.stage.edge.floe_count, 10, "ice floes on the water")
		assert_not_null(v.stage.edge.bank, "the snow bank under the floor")
		assert_eq(reader.state_hash(), before, "drawing it never touches the sim")
		v.queue_free()
	assert_gt(drawn, 0, "at least one of these floors has ice")


func test_the_first_three_biomes_draw_none_of_it() -> void:
	for id: StringName in [&"ruins", &"night_rocks", &"red_canyon"]:
		var b: BiomeDefinition = _repo.get_def(&"biomes", id)
		assert_null(b.look, "%s keeps its hand-written look" % id)
		assert_null(b.surface, "%s has no ice" % id)
		var w := SaveLab.floor_world(11, 1)
		w.ice = null
		var v := WorldViewRoot.new()
		v.stage.mood = b.mood
		v.stage.prop_style = b.id
		add_child_autofree(v)
		v.setup(WorldReader.new(w), b.palette, 60.0)
		assert_null(v.stage.ice, "%s: no ice drawn" % id)
		assert_null(v.stage.edge, "%s: the void stays" % id)
		v.queue_free()


func test_enemies_take_a_cold_cast_on_grey_parts_only() -> void:
	var node := Node3D.new()
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("#5F5551")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#E25A4C")
	var textured := StandardMaterial3D.new()
	textured.albedo_color = Color.WHITE
	textured.albedo_texture = PlaceholderTexture2D.new()
	node.set_meta(&"mats", [grey, red, textured])
	ActorViews.tint_greys(node, _biome.look.enemy_tint)
	assert_gt(grey.albedo_color.b, grey.albedo_color.r, "the grey turns cold")
	assert_eq(red.albedo_color, Color("#E25A4C"), "the enemy red never changes")
	assert_eq(textured.albedo_color, Color.WHITE, "a textured model is left alone")
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color("#5F5551")
	node.set_meta(&"mats", [plain])
	ActorViews.tint_greys(node, Color(0, 0, 0, 0))
	assert_eq(plain.albedo_color, Color("#5F5551"), "no tint, no change")
	node.free()


func test_the_crystals_are_icy_and_off_the_player_cyan() -> void:
	assert_eq(ShardCluster.tint_key(&"frozen_shore", false), &"frozen_shore")
	assert_eq(
		ShardCluster.tint_key(&"frozen_shore", true), &"deep", "a Deep floor still turns violet"
	)
	for c: Color in ShardCluster.TINTS[&"frozen_shore"]:
		assert_ne(c, Color("#2BC4E2"))
		assert_gt(c.b, c.r, "cold")
