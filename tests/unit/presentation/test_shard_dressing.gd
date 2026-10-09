extends GutTest
## v0.6.1 Step SD (owner R4): crystal-shard clusters dress the start room (a hero cluster) and the generated rooms
## (small clusters), presentation only. Step SD2 (owner A3: "Very frequent on the starting room and be an element of
## all rooms, but disparity not all equally distributid some zones have more density than others, specially walls at
## smaller rooms"): every room but the boss arena has crystals, the start room is crystal-rich, density follows a
## vein field (uneven across a floor), smaller rooms get more per wall metre, bigger and brighter in the veins, low
## on the camera-side walls. Properties over generated floors: the same seed gives the same clusters; looks solid =
## is solid (a crystal taller than the decoration limit grows out of a structural wall); clusters hug a wall and
## keep the v0.5.9 spacing (doorways, rewards and gates, spawn spots, the start, the slab gap, each other); none in a
## boss arena; the start room's hero cluster with its cold light; the meshes build; the sim is untouched.

const SEEDS := 60

## Generated floors, built once per seed for the whole script (several tests walk the same 60 floors).
static var _floors := {}


## ShardDressing's input for a generated floor (as StageView builds it, without the dresser's light props).
func _floor(seed_value: int) -> Dictionary:
	if not _floors.has(seed_value):
		_floors[seed_value] = _from_layout(FloorGenerator.generate(seed_value), seed_value)
	return _floors[seed_value]


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
				if c["front"]:
					assert_lte(
						top,
						ShardDressing.FRONT_MAX_HEIGHT + 0.0001,
						"seed %d: low on a camera-side wall" % (300 + s)
					)
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
			if c["front"]:
				assert_eq(c["fragments"].size(), 0, "no fragments in front of the fight")


func test_clusters_keep_the_spacing_rules() -> void:
	# Broken rules are counted (one assert per rule, not one per pair: SD2 floors hold ~100 clusters).
	var broken := {}
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
			# Hugs a wall: the cluster's foot is within reach of one of the room's faces (the back ones for the
			# hero, any face for the rest).
			var to_back := minf(foot.x - room.position.x, room.end.y - foot.y)
			var to_front := minf(room.end.x - foot.x, foot.y - room.position.y)
			var to_wall := to_back if c["hero"] else minf(to_back, to_front)
			_count(broken, "hugs a wall", to_wall > ShardDressing.HERO_REACH * 1.5 + 0.01)
			for d: Rect2 in f["doors"]:
				_count(
					broken,
					"out of doorways",
					d.grow(ShardDressing.DOOR_CLEAR + rad - 0.01).has_point(foot)
				)
			for q: Vector2 in f["keep_clear"]:
				_count(
					broken,
					"off rewards",
					foot.distance_to(q) < ShardDressing.KEEP_CLEAR + rad - 0.01
				)
			for q: Vector2 in f["spawns"]:
				_count(
					broken,
					"off spawns",
					foot.distance_to(q) < ShardDressing.SPAWN_CLEAR + rad - 0.01
				)
			_count(
				broken,
				"off the start",
				foot.distance_to(f["start"]) < ShardDressing.START_CLEAR + rad - 0.01
			)
			for w: Array in f["walls"]:
				if w[3] == 1:
					_count(
						broken,
						"the slab gap from cover",
						ShardDressing._dist_to_box(foot, w) < ShardDressing.SLAB_GAP + rad - 0.01
					)
			for j in range(k + 1, placed.size()):
				var o: Dictionary = placed[j]
				_count(
					broken,
					"clusters' feet keep apart",
					(
						foot.distance_to(o["foot"])
						< ShardDressing.CLUSTER_GAP + rad + float(o["radius"]) - 0.01
					)
				)
	for rule in [
		"hugs a wall",
		"out of doorways",
		"off rewards",
		"off spawns",
		"off the start",
		"the slab gap from cover",
		"clusters' feet keep apart"
	]:
		assert_eq(broken.get(rule, 0), 0, rule)
	assert_gt(seen, SEEDS, "the rooms get clusters")


func _count(broken: Dictionary, rule: String, bad: bool) -> void:
	if bad:
		broken[rule] = broken.get(rule, 0) + 1


## The wall metres of a room (its perimeter).
func _wall_m(room: Rect2) -> float:
	return 2.0 * (room.size.x + room.size.y)


func test_every_room_has_crystals_and_the_start_room_is_rich() -> void:
	var heroes := 0
	var start_per_m := 0.0
	var other_n := 0
	var other_m := 0.0
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
				assert_false((c["light"] as Vector3).is_finite(), "only the hero carries a light")
		var rooms: Array = f["rooms"]
		for r in rooms.size():
			if r == f["boss_room"]:
				continue
			assert_gte(counts.get(r, 0), 1, "seed %d: room %d has crystals" % [1100 + s, r])
			if r == f["start_room"]:
				start_per_m += float(counts.get(r, 0)) / _wall_m(rooms[r]) / float(SEEDS)
			else:
				other_n += counts.get(r, 0)
				other_m += _wall_m(rooms[r])
	assert_gte(
		heroes,
		int(SEEDS * 0.9),
		"the start room nearly always fits its hero (%d/%d)" % [heroes, SEEDS]
	)
	var other := float(other_n) / other_m
	gut.p("clusters per wall metre: start room %.3f, other rooms %.3f" % [start_per_m, other])
	assert_gt(start_per_m, other * 2.0, "the start room is crystal-rich")


func test_smaller_rooms_get_more_per_wall_metre() -> void:
	var small_n := 0
	var small_m := 0.0
	var large_n := 0
	var large_m := 0.0
	for s in SEEDS:
		var f := _floor(1100 + s)
		var counts := {}
		for c: Dictionary in ShardDressing.place(f):
			counts[c["room"]] = counts.get(c["room"], 0) + 1
		var rooms: Array = f["rooms"]
		for r in rooms.size():
			if r == f["boss_room"] or r == f["start_room"]:
				continue
			var room: Rect2 = rooms[r]
			if room.get_area() < ShardDressing.REF_AREA:
				small_n += counts.get(r, 0)
				small_m += _wall_m(room)
			else:
				large_n += counts.get(r, 0)
				large_m += _wall_m(room)
	var small := float(small_n) / small_m
	var large := float(large_n) / large_m
	gut.p("clusters per wall metre: small rooms %.3f, large rooms %.3f" % [small, large])
	assert_gt(small, large * 1.3, "smaller rooms' walls are denser")


## The mean vein value along a wall side (sampled every metre) and the clusters whose foot is on it.
func _side(field: Array, placed: Array, r: int, side: Array) -> Array:
	var a: Vector2 = side[0]
	var length := (side[1] as Vector2).length()
	var d := (side[1] as Vector2).normalized()
	var steps := maxi(int(length), 1)
	var v := 0.0
	for k in steps:
		v += ShardDressing.vein_at(field, a + d * length * ((k + 0.5) / steps)) / steps
	var n := 0
	for c: Dictionary in placed:
		if c["room"] != r:
			continue
		var off: Vector2 = (c["foot"] as Vector2) - a
		var t := off.dot(d)
		if t >= 0.0 and t <= length and absf(off.cross(d)) <= 0.9:
			n += 1
	return [v, n, length]


## Density follows the vein field: wall sides deep in a vein hold more, sides out of every vein fewer; and the
## clusters in a vein are bigger and brighter than those out of one.
func test_density_follows_the_veins_unevenly() -> void:
	var dense := [0, 0.0]  # clusters, metres
	var sparse := [0, 0.0]
	var in_vein := [0.0, 0.0, 0]  # tallest sum, glow sum, count
	var out_vein := [0.0, 0.0, 0]
	for s in SEEDS:
		var f := _floor(1100 + s)
		var field := ShardDressing.floor_veins(f)
		var placed := ShardDressing.place(f)
		var rooms: Array = f["rooms"]
		for r in rooms.size():
			if r == f["boss_room"] or r == f["start_room"]:
				continue
			var room: Rect2 = rooms[r]
			for side: Array in [
				[room.position, Vector2(0, room.size.y)],
				[Vector2(room.position.x, room.end.y), Vector2(room.size.x, 0)],
				[Vector2(room.end.x, room.position.y), Vector2(0, room.size.y)],
				[room.position, Vector2(room.size.x, 0)],
			]:
				var got := _side(field, placed, r, side)
				var bucket: Array = dense if got[0] >= 0.5 else (sparse if got[0] <= 0.05 else [])
				if not bucket.is_empty():
					bucket[0] += got[1]
					bucket[1] += got[2]
		for c: Dictionary in placed:
			if c["room"] == f["start_room"]:
				continue
			var tallest := 0.0
			var glow := 0.0
			for x: Dictionary in c["crystals"]:
				tallest = maxf(tallest, float(x["height"]))
				glow = maxf(glow, float(x["glow"]))
			var bucket: Array = (
				in_vein if c["vein"] >= 0.6 else (out_vein if c["vein"] <= 0.1 else [])
			)
			if bucket.is_empty():
				continue
			bucket[0] += tallest
			bucket[1] += glow
			bucket[2] += 1
	var dense_m: float = dense[0] / maxf(dense[1], 1.0)
	var sparse_m: float = sparse[0] / maxf(sparse[1], 1.0)
	(
		gut
		. p(
			(
				"clusters per wall metre: in a vein %.3f (%.0f m of wall), out of every vein %.3f (%.0f m)"
				% [dense_m, dense[1], sparse_m, sparse[1]]
			)
		)
	)
	assert_gt(dense[1], 0.0, "the floors have dense stretches")
	assert_gt(sparse[1], 0.0, "the floors have sparse stretches")
	assert_gt(dense_m, sparse_m * 2.0, "uneven: the veins hold more")
	assert_gt(in_vein[2], 0)
	assert_gt(out_vein[2], 0)
	var in_h: float = in_vein[0] / in_vein[2]
	var out_h: float = out_vein[0] / out_vein[2]
	gut.p("tallest crystal per cluster: in a vein %.2f m, out of one %.2f m" % [in_h, out_h])
	assert_gt(in_h, out_h, "bigger in the veins")
	assert_gt(in_vein[1] / in_vein[2], out_vein[1] / out_vein[2], "brighter in the veins")


func test_the_vein_field_is_smooth_and_seeded() -> void:
	var f := _floor(31)
	var a := ShardDressing.floor_veins(f)
	assert_eq(a, ShardDressing.floor_veins(f), "the same seed, the same veins")
	assert_ne(a, ShardDressing.floor_veins(_floor(32)), "another seed, other veins")
	var majors := a.filter(func(v: Array) -> bool: return v[2] >= 1.0)
	assert_between(majors.size(), 3, 5, "a few dense zones per floor")
	var vein: Array = majors[0]
	var centre: Vector2 = vein[0]
	var radius: float = vein[1]
	assert_almost_eq(ShardDressing.vein_at([vein], centre), 1.0, 0.0001, "full at the centre")
	assert_eq(ShardDressing.vein_at([vein], centre + Vector2(radius + 0.1, 0)), 0.0, "none outside")
	for k in 40:
		var p := centre + Vector2(k * 0.25, 0)
		var dv := absf(
			ShardDressing.vein_at([vein], p) - ShardDressing.vein_at([vein], p + Vector2(0.25, 0))
		)
		assert_lt(dv, 0.2, "smooth: a small step never jumps")


func test_a_crystal_glow_bakes_into_the_vertex_colour() -> void:
	var xf := Transform3D.IDENTITY
	var mesh := ShardCluster.bake([{"xform": xf, "variant": 0, "glow": 1.3}])
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_eq(colors[0].g * ShardCluster.GLOW_SCALE, 1.3, 0.02, "the glow factor")
	var plain := ShardCluster.bake([{"xform": xf, "variant": 0}])
	var pc: PackedColorArray = plain.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_eq(pc[0].g * ShardCluster.GLOW_SCALE, 1.0, 0.02, "1 by default")


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
		for r in reader.floor_room_count():
			if r != reader.boss_room():
				assert_true(
					shards.room_meshes.has(r), "SD2: every other room has crystals (%d)" % r
				)
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
