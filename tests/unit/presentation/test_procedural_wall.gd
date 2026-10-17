extends GutTest
## v0.8.0 N10 (owners O66, O67), the G2 prototype's two wall styles, as properties over generated floors:
## option A (ProceduralWall) is the same for a seed, stays inside the walls' footprints (only low fallen chunks lie
## on a room's floor), leaves doorways and light niches open, joins its walls without a gap or an overlap (one top
## over every point well inside the union, corners included), keeps its top within its bounds and its triangles
## per metre far under the kit's; the dresser puts far fewer kit pieces on the walls it draws, and crystals still
## find their wall spots. Option B (StageDresser.STYLE_FIT) lays whole pieces edge to edge, at their natural length,
## never the same piece the same way round twice in a row, from decimated copies.

const SEEDS := [77, 501, 1234]
## A point is well inside the union when all of these round it are wall (past a quoin's 0.3 m square).
const AROUND: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(0.33, 0),
	Vector2(-0.33, 0),
	Vector2(0, 0.33),
	Vector2(0, -0.33),
	Vector2(0.33, 0.33),
	Vector2(-0.33, -0.33),
	Vector2(0.33, -0.33),
	Vector2(-0.33, 0.33),
]


func _floor(seed_value: int) -> Dictionary:
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
	var keep: Array = [layout.portal_pos]
	for p in layout.item_spots:
		keep.append(p)
	return {
		"walls": walls,
		"rooms": layout.rooms.duplicate(),
		"start_room": layout.start_room,
		"doors": doors,
		"keep_clear": keep,
		"biome": &"ruins",
		"seed": seed_value,
	}


## The dresser's placements and the builder's result for a floor, as StageView builds option A.
func _option_a(f: Dictionary) -> Array:
	var g := f.duplicate()
	g["wall_style"] = StageDresser.STYLE_PROC
	var placements := StageDresser.dress(g)
	var built := (
		ProceduralWall
		. build(
			{
				"walls": f["walls"],
				"cuts": StageDresser.niches(placements),
				"rooms": f["rooms"],
				"doors": f["doors"],
				"seed": f["seed"],
			}
		)
	)
	return [placements, built]


func _footprints(f: Dictionary) -> Array:
	var out: Array = []
	for w: Array in f["walls"]:
		if ProceduralWall.handles(w):
			out.append(ProceduralWall.footprint(w))
	return out


func _in_any(p: Vector2, rects: Array, grow: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(grow).has_point(p):
			return true
	return false


## Every vertex of every surface, in 3D.
func _verts(built: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for owner: int in built["surfaces"]:
		for arr: Array in built["surfaces"][owner]:
			for v: Vector3 in arr[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(v)
	return out


func test_the_same_seed_gives_the_same_walls() -> void:
	var f := _floor(77)
	var a: Dictionary = _option_a(f)[1]
	var b: Dictionary = _option_a(f)[1]
	assert_gt(int(a["tris"]), 0)
	assert_eq(a["tris"], b["tris"])
	assert_eq(a["surfaces"].keys(), b["surfaces"].keys())
	for owner: int in a["surfaces"]:
		assert_eq(
			a["surfaces"][owner][0][Mesh.ARRAY_VERTEX], b["surfaces"][owner][0][Mesh.ARRAY_VERTEX]
		)
	var c: Dictionary = _option_a(_floor(78))[1]
	assert_ne(c["tris"], a["tris"], "another seed, other walls")


func test_it_stays_inside_the_footprints_and_leaves_doorways_and_niches_open() -> void:
	for s: int in SEEDS:
		var f := _floor(s)
		var both := _option_a(f)
		var built: Dictionary = both[1]
		var feet := _footprints(f)
		var niches := StageDresser.niches(both[0])
		assert_gt(niches.size(), 0, "seed %d has light niches" % s)
		var outside := 0
		var in_door := 0
		var in_niche := 0
		for v in _verts(built):
			var p := SimPlane.to_sim(v)
			if not _in_any(p, feet, 0.002):
				# Only the fallen chunks: low, on a room's floor.
				if v.y > ProceduralWall.CHUNK_MAX_H + 0.001 or not _in_any(p, f["rooms"], 0.0):
					outside += 1
			for d: Rect2 in f["doors"]:
				if d.grow(-0.02).has_point(p):
					in_door += 1
			for n: Rect2 in niches:
				if n.grow(-0.02).has_point(p) and _in_any(p, feet, -0.02):
					in_niche += 1
		assert_eq(outside, 0, "seed %d: nothing tall outside the walls' footprints" % s)
		assert_eq(in_door, 0, "seed %d: doorways open" % s)
		assert_eq(in_niche, 0, "seed %d: light niches open" % s)


## A point well inside the union (every point 0.33 m round it is wall) is under exactly one top: the joins at
## corners and T-junctions leave no gap and no overlap.
func test_one_top_over_every_point_inside_corners_included() -> void:
	var f := _floor(501)
	var both := _option_a(f)
	var built: Dictionary = both[1]
	var niches := StageDresser.niches(both[0])
	var feet := _footprints(f)
	var tops: Array = []
	for owner: int in built["surfaces"]:
		var arr: Array = built["surfaces"][owner][0]
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for k in range(0, vs.size(), 3):
			if cs[k].a < 0.5:
				continue  # a face, not a top
			tops.append(
				[SimPlane.to_sim(vs[k]), SimPlane.to_sim(vs[k + 1]), SimPlane.to_sim(vs[k + 2])]
			)
	var samples: Array[Vector2] = []
	for room: Rect2 in f["rooms"]:  # just outside every room corner: where walls meet
		for c: Vector2 in [
			room.position,
			room.end,
			Vector2(room.position.x, room.end.y),
			Vector2(room.end.x, room.position.y)
		]:
			var out := (c - room.get_center()).sign()
			samples.append(c + out * 0.36)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 200:
		var r: Rect2 = feet[rng.randi() % feet.size()]
		samples.append(r.position + Vector2(rng.randf(), rng.randf()) * r.size)
	var checked := 0
	for p in samples:
		var deep := true
		for d: Vector2 in AROUND:
			if not _in_any(p + d, feet, 0.0) or _in_any(p + d, niches, 0.0):
				deep = false
		if not deep:
			continue
		var n := 0
		for t: Array in tops:
			if Geometry2D.point_is_inside_triangle(p, t[0], t[1], t[2]):
				n += 1
		assert_eq(n, 1, "one top over %s" % p)
		checked += 1
	assert_gt(checked, 50, "enough points checked")


func test_the_top_stays_within_its_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 2000:
		var h := ProceduralWall.height_at(rng.randf_range(-80, 80), rng.randf_range(-80, 80), 1234)
		assert_between(h, ProceduralWall.MIN_H, ProceduralWall.MAX_H)
	var built: Dictionary = _option_a(_floor(1234))[1]
	var top := 0.0
	for v in _verts(built):
		top = maxf(top, v.y)
	# The tallest remnant plus a rebar end.
	assert_lte(top, ProceduralWall.MAX_H + 0.5, "nothing towers over the walls")


func test_triangles_per_metre_far_under_the_kit() -> void:
	for s: int in SEEDS:
		var built: Dictionary = _option_a(_floor(s))[1]
		var per_m := float(built["tris"]) / float(built["face_m"])
		gut.p(
			(
				"seed %d: %d triangles, %.0f m of face, %.1f per metre"
				% [s, built["tris"], built["face_m"], per_m]
			)
		)
		# The kit: 11-12.6k triangles per 1-2.3 m piece on each wall (two faces).
		assert_lt(per_m, 150.0, "seed %d: triangle budget per metre of face" % s)


func test_the_dresser_puts_far_fewer_kit_pieces_on_the_walls_it_builds() -> void:
	for s: int in SEEDS:
		var f := _floor(s)
		var walls: Array = f["walls"]
		var old := 0
		for p: Dictionary in StageDresser.dress(f):
			if p["kind"] == &"wall" and int(walls[p["wall"]][3]) == 0:
				old += 1
		var now := 0
		var lights := 0
		for p: Dictionary in _option_a(f)[0]:
			if p["kind"] == &"wall" and int(walls[p["wall"]][3]) == 0:
				now += 1
				assert_eq(p["piece"], &"wall_pillar", "only pillar accents")
			if p["kind"] == &"light":
				lights += 1
				assert_true(p.has("niche"), "a light prop gets its niche")
		gut.p("seed %d: kit wall pieces %d -> %d" % [s, old, now])
		assert_lt(now * 10, old, "seed %d: under a tenth of the kit pieces" % s)
		assert_gt(lights, 0)


func test_crystals_still_find_their_wall_spots() -> void:
	var f := _floor(77)
	var placements: Array = _option_a(f)[0]
	var placed := (
		ShardDressing
		. place(
			{
				"walls": f["walls"],
				"pieces": placements,
				"rooms": f["rooms"],
				"special": [],
				"start_room": f["start_room"],
				"boss_room": -1,
				"doors": f["doors"],
				"keep_clear": f["keep_clear"],
				"spawns": [],
				"start": (f["rooms"][f["start_room"]] as Rect2).get_center(),
				"seed": 77,
			}
		)
	)
	var walls := 0
	for c: Dictionary in placed:
		if c["kind"] == &"wall" or c["kind"] == &"corner":
			walls += 1
	assert_gt(walls, 0, "clusters along the walls")


func test_option_b_lays_whole_pieces_edge_to_edge() -> void:
	var within := 0
	var all := 0
	for s: int in SEEDS:
		var f := _floor(s)
		var g := f.duplicate()
		g["wall_style"] = StageDresser.STYLE_FIT
		var by_wall := {}
		for p: Dictionary in StageDresser.dress(g):
			if p["kind"] != &"wall" or int(f["walls"][p["wall"]][3]) != 0:
				continue
			assert_true(bool(p.get("lod", false)), "from the decimated copies")
			if not by_wall.has(p["wall"]):
				by_wall[p["wall"]] = []
			by_wall[p["wall"]].append(p)
		for wi: int in by_wall:
			var w: Array = f["walls"][wi]
			var fr := StageDresser._frame(w)
			var axis: Vector3 = fr["axis"]
			var rows := {}  # a thick wall is laid in rows across its depth: each row on its own
			for p: Dictionary in by_wall[wi]:
				var x: Transform3D = p["xform"]
				var length := x.basis.x.length()
				var along := (x.origin - (fr["center"] as Vector3)).dot(axis)
				var across := (x.origin - (fr["center"] as Vector3)).dot(
					fr["depth_axis"] as Vector3
				)
				if x.basis.y.length() < 0.6:
					continue  # the low broken wall behind a light prop
				var row := roundi(across * 100.0)
				if not rows.has(row):
					rows[row] = []
				rows[row].append([along - length * 0.5, along + length * 0.5, p])
				if StageDresser.FIT_LEN.has(p["piece"]):
					var ratio := length / float(StageDresser.FIT_LEN[p["piece"]])
					all += 1
					if absf(ratio - 1.0) <= StageDresser.FIT_STRETCH:
						within += 1
					assert_between(ratio, 0.5, 1.6, "never badly stretched")
			for row: int in rows:
				var spans: Array = rows[row]
				spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
				for k in range(1, spans.size()):
					assert_lte(spans[k - 1][1], spans[k][0] + 0.001, "no overlap on wall %d" % wi)
					var pa: Dictionary = spans[k - 1][2]
					var pb: Dictionary = spans[k][2]
					if pa["piece"] == pb["piece"] and spans[k][0] - spans[k - 1][1] < 0.01:  # touching
						var xa: Transform3D = pa["xform"]
						var xb: Transform3D = pb["xform"]
						assert_false(
							(
								xa.basis.x.normalized().is_equal_approx(xb.basis.x.normalized())
								and signf(xa.basis.determinant()) == signf(xb.basis.determinant())
							),
							"the same piece never twice the same way round"
						)
	gut.p(
		(
			"option B: %d of %d pieces within ±%d%% of their natural length"
			% [within, all, StageDresser.FIT_STRETCH * 100]
		)
	)
	assert_gt(within, all * 0.9, "nine in ten at their natural length")


func test_option_b_lengths_are_the_models_own() -> void:
	for id: StringName in StageDresser.FIT_LEN:
		var piece := KitModels.get_piece(id)
		assert_false(piece.is_empty(), "%s loads" % id)
		assert_almost_eq(
			(piece["size"] as Vector3).x, float(StageDresser.FIT_LEN[id]), 0.01, String(id)
		)
		assert_almost_eq((piece["size"] as Vector3).y, float(StageDresser.FIT_HEIGHT[id]), 0.001)


func test_the_decimated_copies_are_light() -> void:
	for id: StringName in StageDresser.FIT_LEN:
		var path := KitModels.LOD_DIR + String(id) + "_lod.res"
		assert_true(ResourceLoader.exists(path), path)
		var mesh := load(path) as ArrayMesh
		var tris := (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var full := KitModels.get_piece(id)["mesh"] as ArrayMesh
		var full_tris := (
			(full.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		)
		gut.p("%s: %d -> %d triangles" % [id, full_tris, tris])
		assert_lte(tris, 3000, "%s at most 3k triangles" % id)
		assert_lt(tris * 3, full_tris, "%s under a third" % id)
		assert_not_null(mesh.surface_get_material(0), "keeps its texture")
		var lod := KitModels.get_lod_piece(id)
		assert_almost_eq(
			(lod["size"] as Vector3).x, (KitModels.get_piece(id)["size"] as Vector3).x, 0.02
		)


func test_a_procedural_wall_fades_with_its_wall() -> void:
	var f := _floor(77)
	var both := _option_a(f)
	var kit := StageKit.new()
	add_child_autofree(kit)
	kit.build(
		both[0],
		f["walls"].size(),
		Color(0.5, 0.5, 0.5),
		BiomeMood.new(),
		both[1],
		StageView.wall_textures(&"ruins")
	)
	assert_gt(kit.proc_nodes, 0)
	var wi: int = (both[1]["surfaces"] as Dictionary).keys()[0]
	var node: MeshInstance3D = null
	for n: MeshInstance3D in kit.wall_pieces[wi]:
		if n.get_meta(&"piece") == &"proc_wall":
			node = n
	assert_not_null(node)
	var solid := node.get_surface_override_material(0) as ShaderMaterial
	assert_not_null(solid.get_shader_parameter(&"face_tex"), "the owner's wall texture")
	assert_not_null(solid.get_shader_parameter(&"top_tex"), "and its top texture")
	kit.set_faded(PackedInt32Array([wi]))
	var faded := node.get_surface_override_material(0) as ShaderMaterial
	assert_ne(faded, solid)
	assert_string_contains(faded.shader.code, "ALPHA_HASH_SCALE", "dithered see-through")
	kit.set_faded(PackedInt32Array())
	assert_eq(node.get_surface_override_material(0), solid, "restored")


func test_the_wall_style_follows_the_dev_toggle() -> void:
	var stage := StageView.new()
	autofree(stage)
	var before := ViewPrefs.wall_style
	ViewPrefs.wall_style = &"auto"
	stage.prop_style = &"ruins"
	assert_eq(
		stage.resolved_wall_style(), StageDresser.STYLE_PROC, "Ruins draws option A by default"
	)
	stage.prop_style = &"night_rocks"
	assert_eq(stage.resolved_wall_style(), StageDresser.STYLE_KIT, "the other biomes keep the kit")
	ViewPrefs.wall_style = &"a"
	assert_eq(stage.resolved_wall_style(), StageDresser.STYLE_PROC, "A in any biome")
	ViewPrefs.wall_style = &"b"
	assert_eq(stage.resolved_wall_style(), StageDresser.STYLE_FIT)
	ViewPrefs.wall_style = &"old"
	stage.prop_style = &"ruins"
	assert_eq(stage.resolved_wall_style(), StageDresser.STYLE_KIT)
	ViewPrefs.wall_style = before
	for b: StringName in [&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"]:
		var tex := StageView.wall_textures(b)
		assert_not_null(tex["face"], "%s face" % b)
		assert_not_null(tex["top"], "%s top" % b)
		assert_true((tex["face"] as Texture2D).resource_path.ends_with("tex_wall_%s.png" % b))


func test_the_dev_panel_walls_button_cycles_the_style() -> void:
	var before := ViewPrefs.wall_style
	ViewPrefs.wall_style = &"auto"
	var panel := DevPanel.new(DebugApi.new(SaveLab.floor_world(20261008, 1)))
	add_child_autofree(panel)
	DevWalls.wire(panel)
	var label := panel.find_child("WallStyleChoice", true, false) as Label
	assert_eq(label.text, "walls: auto")
	var b := panel.find_child("WallStyle", true, false) as Button
	assert_not_null(b, "the Walls button")
	assert_eq(b.text, "UI_DEV_WALL_STYLE")
	var seen: Array[StringName] = []
	for k in 4:
		b.pressed.emit()
		seen.append(ViewPrefs.wall_style)
	assert_eq(seen, [&"old", &"a", &"b", &"auto"] as Array[StringName], "auto, old, A, B and round")
	assert_eq(label.text, "walls: auto")
	ViewPrefs.wall_style = before
