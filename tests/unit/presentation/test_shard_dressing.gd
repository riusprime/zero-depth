extends GutTest
## v0.6.1 Step SD (owner R4): crystal-shard clusters dress the start room (a hero cluster) and the generated rooms
## (small clusters), presentation only. Properties over generated floors: the same seed gives the same clusters;
## looks solid = is solid (a crystal taller than the decoration limit grows out of a structural wall); clusters
## hug the back walls and keep the v0.5.9 spacing (doorways, rewards and gates, spawn spots, the start, the slab gap,
## each other); none in a boss arena; the start room's hero cluster with its cold light; the meshes build; the sim
## is untouched.

const SEEDS := 60


## ShardDressing's input for a generated floor (as StageView builds it, without the dresser's light props).
func _floor(seed_value: int) -> Dictionary:
	var layout := FloorGenerator.generate(seed_value)
	return _from_layout(layout, seed_value)


func _from_layout(layout: FloorLayout, seed_value: int) -> Dictionary:
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
	var spawns: Array = []
	for pts in layout.spawn_points:
		for p in pts:
			spawns.append(p)
	return {
		"walls": walls,
		"rooms": layout.rooms.duplicate(),
		"themes":
		Array(layout.room_template).map(
			func(t: int) -> StringName: return StringName(FloorLayout.TEMPLATE_NAMES[t])
		),
		"start_room": layout.start_room,
		"boss_room": layout.boss_room,
		"doors": doors,
		"keep_clear": keep,
		"spawns": spawns,
		"start": layout.start_pos,
		"seed": seed_value,
	}


func _in_structure(f: Dictionary, p: Vector2) -> bool:
	for d: Rect2 in f["doors"]:
		if d.has_point(p):
			return false
	for w: Array in f["walls"]:
		if w[3] != 0:
			continue
		var local := (p - (w[0] as Vector2)).rotated(-(w[2] as float))
		var half: Vector2 = w[1]
		if absf(local.x) <= half.x + 0.01 and absf(local.y) <= half.y + 0.01:
			return true
	return false


func test_the_same_seed_gives_the_same_clusters() -> void:
	var a := ShardDressing.place(_floor(31))
	var b := ShardDressing.place(_floor(31))
	assert_eq(a.size(), b.size())
	assert_gt(a.size(), 0, "a floor gets clusters")
	for k in a.size():
		assert_eq(a[k]["room"], b[k]["room"])
		assert_eq(a[k]["crystals"].size(), b[k]["crystals"].size())
		for j in a[k]["crystals"].size():
			assert_eq(a[k]["crystals"][j]["xform"], b[k]["crystals"][j]["xform"])
		assert_eq(a[k]["fragments"], b[k]["fragments"])
	var c := ShardDressing.place(_floor(32))
	assert_true(
		c.size() != a.size() or c[0]["foot"] != a[0]["foot"], "another seed, other clusters"
	)


func test_tall_crystals_grow_from_walls_and_the_rest_stays_low() -> void:
	for s in SEEDS:
		var f := _floor(300 + s)
		var rooms: Array = f["rooms"]
		for c: Dictionary in ShardDressing.place(f):
			var room: Rect2 = rooms[c["room"]]
			for x: Dictionary in c["crystals"]:
				var base: Vector2 = x["base"]
				var rad: float = x["radius"]
				var xform: Transform3D = x["xform"]
				# The unit crystal's top (y = 1) under the transform: the crystal's real height.
				var top := (xform * Vector3(0, 1, 0)).y
				if not x["tall"]:
					assert_lte(
						top,
						StageDresser.DECOR_MAX_HEIGHT + 0.0001,
						"seed %d: low shards stay low" % (300 + s)
					)
					assert_true(
						room.has_point(base), "seed %d: a low shard on the room's floor" % (300 + s)
					)
					continue
				for p in [
					base, base + Vector2(rad, 0), base - Vector2(rad, 0), base + Vector2(0, rad)
				]:
					if not _in_structure(f, p):
						fail_test(
							"seed %d: a tall crystal's base leaves the wall at %s" % [300 + s, p]
						)
						return
			for fr: Transform3D in c["fragments"]:
				assert_gte(
					fr.origin.y, ShardDressing.FRAGMENT_MIN_Y, "fragments float above the hero"
				)


func test_clusters_keep_the_spacing_rules() -> void:
	var seen := 0
	for s in SEEDS:
		var f := _floor(700 + s)
		var placed := ShardDressing.place(f)
		seen += placed.size()
		for k in placed.size():
			var c: Dictionary = placed[k]
			var foot: Vector2 = c["foot"]
			var rad: float = c["radius"]
			var room: Rect2 = f["rooms"][c["room"]]
			# Hugs a back wall: the cluster's foot is within reach of the -X or the +Y face.
			var to_back := minf(foot.x - room.position.x, room.end.y - foot.y)
			assert_lte(to_back, ShardDressing.HERO_REACH * 1.5 + 0.01, "hugs a back wall")
			for d: Rect2 in f["doors"]:
				assert_false(
					d.grow(ShardDressing.DOOR_CLEAR + rad - 0.01).has_point(foot), "out of doorways"
				)
			for q: Vector2 in f["keep_clear"]:
				assert_gte(
					foot.distance_to(q), ShardDressing.KEEP_CLEAR + rad - 0.01, "off rewards"
				)
			for q: Vector2 in f["spawns"]:
				assert_gte(
					foot.distance_to(q), ShardDressing.SPAWN_CLEAR + rad - 0.01, "off spawns"
				)
			assert_gte(foot.distance_to(f["start"]), ShardDressing.START_CLEAR + rad - 0.01)
			for w: Array in f["walls"]:
				if w[3] == 1:
					assert_gte(
						ShardDressing._dist_to_box(foot, w),
						ShardDressing.SLAB_GAP + rad - 0.01,
						"the slab gap from cover"
					)
			for j in range(k + 1, placed.size()):
				var o: Dictionary = placed[j]
				assert_gte(
					foot.distance_to(o["foot"]),
					ShardDressing.CLUSTER_SPACING + rad + float(o["radius"]) - 0.01,
					"clusters keep apart"
				)
	assert_gt(seen, SEEDS, "the rooms get clusters")


func test_density_follows_the_theme_and_the_start_room_gets_its_hero() -> void:
	var per_theme := {}
	var rooms_of := {}
	var heroes := 0
	for s in SEEDS:
		var f := _floor(1100 + s)
		var counts := {}
		for c: Dictionary in ShardDressing.place(f):
			var r: int = c["room"]
			counts[r] = counts.get(r, 0) + 1
			if c["hero"]:
				assert_eq(r, f["start_room"], "the hero cluster is the start room's")
				heroes += 1
				assert_true((c["light"] as Vector3).is_finite(), "the hero's cold light")
				var tallest := 0.0
				for x: Dictionary in c["crystals"]:
					tallest = maxf(tallest, (x["xform"] as Transform3D).basis.y.length())
				assert_gte(tallest, 1.6, "a centrepiece crystal")
			else:
				assert_ne(r, f["start_room"], "no small cluster in the start room")
				assert_false((c["light"] as Vector3).is_finite(), "small clusters carry no light")
		for r in f["rooms"].size():
			if r == f["start_room"]:
				continue
			var t: StringName = f["themes"][r]
			var cap := 2
			if t == &"ruined_hall" or t == &"overgrown":
				cap = 3
			elif t == &"camp":
				cap = 1
			assert_lte(counts.get(r, 0), cap, "the theme's cap")
			per_theme[t] = per_theme.get(t, 0) + counts.get(r, 0)
			rooms_of[t] = rooms_of.get(t, 0) + 1
	assert_gte(
		heroes,
		int(SEEDS * 0.9),
		"the start room nearly always fits its hero (%d/%d)" % [heroes, SEEDS]
	)
	var rich := float(per_theme.get(&"ruined_hall", 0)) / maxf(rooms_of.get(&"ruined_hall", 0), 1.0)
	var camp := float(per_theme.get(&"camp", 0)) / maxf(rooms_of.get(&"camp", 0), 1.0)
	gut.p("clusters per room: ruined hall %.2f, camp %.2f" % [rich, camp])
	assert_gt(rich, camp, "Ruined hall holds more than Camp")


func test_no_cluster_in_a_boss_arena_and_the_sim_is_untouched() -> void:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	for s in 4:
		var w := SaveLab.floor_world(40 + s, 2)
		var reader := WorldReader.new(w)
		var before := reader.state_hash()
		var v := WorldViewRoot.new()
		v.stage.mood = biome.mood
		v.stage.prop_style = biome.id
		add_child_autofree(v)
		v.setup(reader, biome.palette, 60.0)
		assert_eq(reader.state_hash(), before, "building the dressing never touches the sim")
		var shards := v.stage.shards
		assert_not_null(shards, "the floor is dressed with shards")
		assert_gte(reader.boss_room(), 0, "this floor has a boss room")
		for c: Dictionary in shards.clusters:
			assert_ne(c["room"], reader.boss_room(), "no cluster in the boss arena")
		assert_false(shards.room_meshes.has(reader.boss_room()))
		v.queue_free()


func test_the_view_builds_the_clusters_with_outline_glow_and_bobbing_fragments() -> void:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"night_rocks")
	var w := SaveLab.floor_world(7, 1)
	var reader := WorldReader.new(w)
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	v.stage.prop_style = biome.id
	add_child_autofree(v)
	v.setup(reader, biome.palette, 60.0)
	var shards := v.stage.shards
	assert_not_null(shards)
	assert_gt(shards.room_meshes.size(), 0)
	for r: int in shards.room_meshes:
		var node: MeshInstance3D = shards.room_meshes[r]
		assert_gt(node.mesh.get_surface_count(), 0, "a baked mesh")
		var m := node.material_override as ShaderMaterial
		assert_not_null(m.next_pass, "an outline pass")
		var tint: Array = ShardCluster.TINTS[&"night_rocks"]
		assert_eq(m.get_shader_parameter(&"body"), tint[0], "the biome's tint")
		assert_gt(float(m.get_shader_parameter(&"glow_energy")), 0.0, "a soft inner glow")
	for r: int in shards.room_fragments:
		var mmi: MultiMeshInstance3D = shards.room_fragments[r]
		assert_gt(mmi.multimesh.instance_count, 0)
		var fm := mmi.material_override as ShaderMaterial
		var want := 0.0 if ViewPrefs.reduced_motion else ShardCluster.BOB_AMPLITUDE
		assert_almost_eq(float(fm.get_shader_parameter(&"bob")), want, 0.0001, "fragments bob")
	var hero_room := reader.floor_start_room()
	var hero := shards.clusters.filter(func(c: Dictionary) -> bool: return c["hero"])
	if hero.is_empty():
		pending("seed 7's start room had no spot for the hero")
		return
	assert_true(shards.room_meshes.has(hero_room), "the start room is dressed")
	assert_not_null(shards.hero_light, "the hero cluster's cold light")
	assert_false(shards.hero_light.shadow_enabled, "no shadow: it costs little")
	assert_lte(shards.hero_light.light_energy, ShardCluster.HERO_LIGHT_ENERGY + 0.0001)


func test_tints_and_the_deep_violet() -> void:
	assert_eq(ShardCluster.tint_key(&"ruins", false), &"ruins")
	assert_eq(ShardCluster.tint_key(&"night_rocks", true), &"deep", "Deep floors turn violet")
	assert_eq(ShardCluster.tint_key(&"unknown", false), &"default")
	var deep: Color = ShardCluster.TINTS[&"deep"][1]
	assert_gt(deep.b, deep.g, "the Deep glow is violet")
	var teal: Color = ShardCluster.TINTS[&"default"][1]
	assert_ne(teal, Color("#2BC4E2"), "off the reserved player-core cyan (ART_DIRECTION §2)")


func test_a_deep_floor_tints_its_shards_violet() -> void:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var w := SaveLab.build_floor(SaveLab.run_state(81, 2, &"blade", Routes.Route.DEEP))
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	v.stage.prop_style = biome.id
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	assert_true(v.stage.deep)
	assert_gt(v.stage.shards.room_meshes.size(), 0)
	for r: int in v.stage.shards.room_meshes:
		var m := (
			(v.stage.shards.room_meshes[r] as MeshInstance3D).material_override as ShaderMaterial
		)
		assert_eq(
			m.get_shader_parameter(&"glow"), ShardCluster.TINTS[&"deep"][1], "the Deep violet"
		)


func test_the_unit_crystal_is_closed_and_faces_out() -> void:
	for variant in ShardCluster.VARIANT_SIDES.size():
		var mesh := ShardCluster.crystal_mesh(variant)
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var sides := ShardCluster.VARIANT_SIDES[variant]
		assert_eq(verts.size(), sides * 4 * 3, "sides, point and foot: four triangles per side")
		for i in range(0, verts.size(), 3):
			var mid := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
			var out := mid - Vector3(0, ShardCluster.CORE_Y, 0)
			assert_gt(normals[i].dot(out), 0.0, "every facet faces out")
			# Godot's front faces wind clockwise seen from outside: the winding's normal points in.
			var wn := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
			assert_lt(wn.dot(normals[i]), 0.0, "wound for the front face")
		assert_same(ShardCluster.crystal_mesh(variant), mesh, "built once and shared")
