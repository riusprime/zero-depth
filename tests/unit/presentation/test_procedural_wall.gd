extends GutTest
## v0.8.0 N10 (owners O66, O67), the procedural walls (option A, ProceduralWall) as properties over generated floors:
## the same for a seed, inside the walls' footprints (only low fallen chunks lie on a room's floor), doorways and
## light niches open, joined without a gap or an overlap (one top over every point well inside the union, corners
## included), the top within its bounds, triangles per metre far under the kit's; crystals still find their wall
## spots.
## v0.8.0 N13 (owner O71, D50 = A everywhere): no kit piece on a structural wall in any biome (its pillars are the
## builder's own: inside the footprint, standing over the wall round them, clear of the lights); a thick wall's top
## is a rim of laid stones round a sunken fill.
## v0.8.0 N15 (owner O73, D53): the one wall style (the old kit tiling, option B, its decimated copies and the dev
## toggle are gone); each biome's calming values (BiomeMood's wall_*) reach the builder and the shader, validated;
## at the defaults the walls are N13's; calmer walls never cost more triangles per metre.

const BIOMES: Array[StringName] = [
	&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"
]

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


## The dresser's placements and the builder's result for a floor, as StageView builds them (v0.8.0 N15: `calm`, a
## biome's calming values; none: N13's look).
func _option_a(f: Dictionary, calm: Dictionary = {}) -> Array:
	var placements := StageDresser.dress(f)
	var built := (
		ProceduralWall
		. build(
			{
				"walls": f["walls"],
				"cuts": StageDresser.niches(placements),
				"rooms": f["rooms"],
				"doors": f["doors"],
				"seed": f["seed"],
				"calm": calm,
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
## corners and T-junctions leave no gap and no overlap (v0.8.0 N13: away from the pillars, whose courses stack).
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
			if _in_any(p + d, built["pillar_rects"], 0.1):  # v0.8.0 N13: a pillar's courses stack
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


## v0.8.0 N13: "100% new": in every biome (its own cover and decoration swaps, as StageView passes them), the
## dresser puts no kit piece on a structural wall; the light props keep their niches; every cover slab is dressed
## (v0.8.0 N15: the kit's wall tiling is gone, so this is the only dressing).
func test_no_kit_pieces_on_the_exterior_walls_in_any_biome() -> void:
	var content := ContentRepository.load_all()
	for b: StringName in BIOMES:
		var biome: BiomeDefinition = content.get_def(&"biomes", b)
		assert_not_null(biome, String(b))
		for s: int in SEEDS:
			var f := _floor(s)
			f["biome"] = b
			if biome.look != null:
				f["square_cover"] = StageView._names(biome.look.square_cover)
				f["decor_swap"] = StageView._names(biome.look.decor_swap)
			var walls: Array = f["walls"]
			var now := 0
			var lights := 0
			var cover := {}
			for p: Dictionary in StageDresser.dress(f):
				if p["wall"] >= 0 and int(walls[p["wall"]][3]) == 0 and p["kind"] != &"light":
					now += 1
				if p["kind"] == &"light":
					lights += 1
					assert_true(p.has("niche"), "a light prop gets its niche")
				elif p["kind"] == &"cover":
					cover[p["wall"]] = true
			var slabs := {}
			for i in walls.size():
				assert_true(
					int(walls[i][3]) == 1 or ProceduralWall.handles(walls[i]),
					"%s seed %d: the builder draws structural wall %d" % [b, s, i]
				)
				if int(walls[i][3]) == 1:
					slabs[i] = true
			assert_eq(now, 0, "%s seed %d: no kit piece on a structural wall" % [b, s])
			assert_gt(lights, 0)
			assert_eq(cover.keys(), slabs.keys(), "%s seed %d: every cover slab dressed" % [b, s])


## v0.8.0 N13 (rule 3b): the builder's own pillars, where N10's kit accents stood: inside their wall's footprint,
## standing over the wall's own top under them, clear of the light niches.
func test_the_pillars_are_the_builders_own() -> void:
	var total := 0
	for s: int in SEEDS:
		var f := _floor(s)
		var both := _option_a(f)
		var built: Dictionary = both[1]
		total += int(built["pillars"])
		var feet := _footprints(f)
		var niches := StageDresser.niches(both[0])
		var verts := _verts(built)
		for r: Rect2 in built["pillar_rects"]:
			assert_true(_in_any(r.get_center(), feet, 0.0), "seed %d: a pillar on a wall" % s)
			var inside := false
			for ft: Rect2 in feet:
				if (
					ft.grow(0.002).encloses(r.grow_individual(0.06, 0.0, 0.06, 0.0))
					or (ft.grow(0.002).encloses(r.grow_individual(0.0, 0.06, 0.0, 0.06)))
				):
					inside = true
			assert_true(inside, "seed %d: a pillar (its lips too) inside its footprint" % s)
			assert_false(
				_in_any(r.get_center(), niches, WallPillars.CLEAR - 0.01),
				"seed %d: clear of a light" % s
			)
			var top := 0.0
			var hidden := 0.0
			for v in verts:
				var p := SimPlane.to_sim(v)
				if r.grow(0.07).has_point(p):  # its corners (the lips) included
					top = maxf(top, v.y)
				if r.grow(-0.02).has_point(p):  # the wall's own top under it
					hidden = maxf(hidden, v.y)
			assert_gte(top, WallPillars.H.x - 0.06, "seed %d: a pillar stands" % s)
			assert_lt(hidden, top, "seed %d: over the wall's top under it" % s)
	gut.p("pillars: %d on seeds %s" % [total, SEEDS])
	assert_gt(total, SEEDS.size() * 3, "pillars on the long thin walls")


## v0.8.0 N13 (rule 2, the N10 note "a ruined platform more than a wall"): a thick wall's top is a rim of laid
## stones round a fill sunk below it; thin walls are all rim.
func test_a_thick_walls_top_is_a_rim_round_a_sunken_fill() -> void:
	for s: int in SEEDS:
		var built: Dictionary = _option_a(_floor(s))[1]
		gut.p(
			(
				"seed %d: top rim %.0f m2 at %.2f m, fill %.0f m2 at %.2f m"
				% [
					s,
					built["top_rim_m2"],
					built["top_rim_h"],
					built["top_fill_m2"],
					built["top_fill_h"]
				]
			)
		)
		assert_gt(float(built["top_fill_m2"]), 50.0, "seed %d: thick walls have a fill" % s)
		assert_lt(
			float(built["top_fill_h"]),
			float(built["top_rim_h"]) - 0.15,
			"seed %d: the fill sits below the rim" % s
		)
		assert_gte(float(built["top_fill_h"]), ProceduralWall.FILL_MIN)
	var thin := (
		ProceduralWall
		. build(
			{
				"walls": [[Vector2.ZERO, Vector2(6.0, 0.6), 0.0, 0]],
				"rooms": [],
				"doors": [],
				"seed": 3,
			}
		)
	)
	assert_eq(float(thin["top_fill_m2"]), 0.0, "a 1.2 m wall is all rim")


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
	assert_eq(float(solid.get_shader_parameter(&"detail")), 1.0, "N13's look at the defaults")
	assert_not_null(solid.get_shader_parameter(&"top_tex"), "and its top texture")
	kit.set_faded(PackedInt32Array([wi]))
	var faded := node.get_surface_override_material(0) as ShaderMaterial
	assert_ne(faded, solid)
	assert_string_contains(faded.shader.code, "ALPHA_HASH_SCALE", "dithered see-through")
	kit.set_faded(PackedInt32Array())
	assert_eq(node.get_surface_override_material(0), solid, "restored")


## v0.8.0 N13 (D50), N15 (D53): one wall style in every biome, at its own tile size, from its own textures; the dev
## panel's Walls button is gone.
func test_every_biome_draws_its_own_procedural_walls() -> void:
	var content := ContentRepository.load_all()
	for b: StringName in BIOMES:
		var mood: BiomeMood = (content.get_def(&"biomes", b) as BiomeDefinition).mood
		gut.p(
			(
				"%s: face tile %.1f m, top tile %.1f m"
				% [b, mood.wall_texture_m, mood.wall_top_texture_m]
			)
		)
		assert_between(mood.wall_texture_m, 3.0, 8.0, "%s's own face scale" % b)
	for b: StringName in BIOMES:
		var tex := StageView.wall_textures(b)
		assert_not_null(tex["face"], "%s face" % b)
		assert_not_null(tex["top"], "%s top" % b)
		assert_true((tex["face"] as Texture2D).resource_path.ends_with("tex_wall_%s.png" % b))
	var panel := DevPanel.new(DebugApi.new(SaveLab.floor_world(20261008, 1)))
	add_child_autofree(panel)
	assert_null(panel.find_child("WallStyle", true, false), "no Walls button")
	assert_null(panel.find_child("WallStyleChoice", true, false), "no wall style readout")
	assert_false(
		ResourceLoader.exists("res://assets/models/kit_lod/wall_2m_lod.res"), "no decimated copies"
	)


## v0.8.0 N15 (rule 6): each biome's calming values come from its data and are validated; the defaults are N13's
## look (the same walls, vertex for vertex), and each biome's own values reach the builder and the shader.
func test_each_biome_calms_its_walls_from_its_data() -> void:
	var plain := BiomeMood.new()
	assert_eq(WallCalm.calm_of(plain), WallCalm.BUILDER, "the defaults: N13's builder")
	assert_eq(
		WallCalm.look_of(plain),
		{"detail": 1.0, "face_contrast": 1.0, "top_contrast": 1.0},
		"and N13's shader"
	)
	var f := _floor(77)
	var a: Dictionary = _option_a(f)[1]
	var b: Dictionary = _option_a(f, WallCalm.calm_of(plain))[1]
	assert_eq(a["tris"], b["tris"])
	for owner: int in a["surfaces"]:
		assert_eq(
			a["surfaces"][owner][0][Mesh.ARRAY_VERTEX],
			b["surfaces"][owner][0][Mesh.ARRAY_VERTEX],
			"wall %d as N13 drew it" % owner
		)
	var bad := BiomeMood.new()
	bad.wall_breakage = 3.0
	bad.wall_detail = 1.5
	var problems := bad.problems()
	assert_eq(problems.size(), 2, str(problems))
	var content := ContentRepository.load_all()
	for id: StringName in BIOMES:
		var mood: BiomeMood = (content.get_def(&"biomes", id) as BiomeDefinition).mood
		assert_eq(mood.problems().size(), 0, "%s's walls validate" % id)
		var look := WallCalm.look_of(mood)
		var m := ProceduralWall.material(null, null, false, look)
		for k: String in look:
			assert_almost_eq(float(m.get_shader_parameter(StringName(k))), float(look[k]), 0.0001)
		gut.p("%s: calm %s, look %s" % [id, WallCalm.calm_of(mood), look])


## v0.8.0 N15: a calmer biome never costs more triangles per metre than N13's walls on the same floor (bigger stones,
## fewer breaks), and it still has its rim, its fill and its pillars.
func test_calmer_walls_cost_no_more_triangles() -> void:
	var content := ContentRepository.load_all()
	for id: StringName in BIOMES:
		var mood: BiomeMood = (content.get_def(&"biomes", id) as BiomeDefinition).mood
		for s: int in SEEDS:
			var f := _floor(s)
			var n13: Dictionary = _option_a(f)[1]
			var now: Dictionary = _option_a(f, WallCalm.calm_of(mood))[1]
			var before := float(n13["tris"]) / float(n13["face_m"])
			var after := float(now["tris"]) / float(now["face_m"])
			(
				gut
				. p(
					(
						"%s seed %d: %.1f -> %.1f triangles per metre; pillars %d; fill %.0f m2 at %.2f m, rim at %.2f m"
						% [
							id,
							s,
							before,
							after,
							now["pillars"],
							now["top_fill_m2"],
							now["top_fill_h"],
							now["top_rim_h"]
						]
					)
				)
			)
			assert_lte(after, before + 0.05, "%s seed %d: no more triangles per metre" % [id, s])
			assert_gt(int(now["pillars"]), 0, "%s seed %d: the pillars stay" % [id, s])
			assert_lt(
				float(now["top_fill_h"]),
				float(now["top_rim_h"]) - 0.15,
				"%s: the fill sits low" % id
			)
