extends GutTest
## v0.6.1 Step SD (owner R4): crystal-shard clusters dress the start room (a hero cluster) and the generated rooms,
## presentation only. Step SD2 (owner A3: "Very frequent on the starting room and be an element of all rooms, but
## disparity not all equally distributid some zones have more density than others, specially walls at smaller
## rooms"): every room but the boss arena has crystals, the start room is crystal-rich, density follows a vein field
## (uneven across a floor), smaller rooms get more per wall metre, bigger and brighter in the veins. Step SD3 (owner
## A3b: "not on top of the walls it should be floor closed to the walls, corners of some rooms, and other obstacle
## like they grow from the ground"): every crystal grows from the floor, hugging a wall, a corner or an obstacle;
## camera-side faces stay low. Step SD4 (owner A3c): about a fifth of a room's wall base, mostly corners, only
## against stone; 1-2 crystal rooms a floor with a far higher share and big crystals (the vein field is gone).
## Properties over generated floors: the same seed gives the same clusters; the
## clearances (doorways, rewards and gates, spawn spots, the start, the paths, each other); none in a boss arena;
## the start room's hero cluster with its cold light; the meshes build; the sim is untouched.

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
	# The dresser's pieces, as StageView passes them (SD4: stone or not).
	var pieces := (
		StageDresser
		. dress(
			{
				"walls": walls,
				"rooms": layout.rooms.duplicate(),
				"start_room": layout.start_room,
				"doors": doors,
				"keep_clear": keep,
				"biome": &"ruins",
				"seed": seed_value,
			}
		)
	)
	return {
		"walls": walls,
		"pieces": pieces,
		"rooms": layout.rooms.duplicate(),
		"special": [],
		"start_room": layout.start_room,
		"boss_room": layout.boss_room,
		"doors": doors,
		"keep_clear": keep,
		"spawns": spawns,
		"start": layout.start_pos,
		"seed": seed_value,
	}


func _in_structure(f: Dictionary, p: Vector2) -> bool:
	for w: Array in f["walls"]:
		var local := (p - (w[0] as Vector2)).rotated(-(w[2] as float))
		var half: Vector2 = w[1]
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
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


## SD3 (owner A3b): every crystal grows from open floor in its room, hugging a wall or an obstacle (its far edge
## within HUG, a tall one within TALL_HUG); nothing in or on a wall; camera-side faces stay under their cap with no
## fragments; low shards stay low; fragments float above the hero.
func test_crystals_grow_from_the_floor_hugging_walls_and_obstacles() -> void:
	var broken := {}
	var kinds := {}
	for s in SEEDS:
		var f := _floor(300 + s)
		var rooms: Array = f["rooms"]
		for c: Dictionary in ShardDressing.place(f):
			kinds[c["kind"]] = kinds.get(c["kind"], 0) + 1
			var room: Rect2 = rooms[c["room"]]
			for x: Dictionary in c["crystals"]:
				var base: Vector2 = x["base"]
				var rad: float = x["radius"]
				# The unit crystal's top (y = 1) under the transform: the crystal's real height.
				var top := ((x["xform"] as Transform3D) * Vector3(0, 1, 0)).y
				var d := ShardDressing.near_structure(f, base)
				_count(broken, "on the room's floor", not room.has_point(base))
				_count(broken, "not in a wall or an obstacle", _in_structure(f, base))
				_count(broken, "the base clear of structures", d < rad * 0.8 - 0.001)
				var hug := ShardDressing.TALL_HUG if x["tall"] else ShardDressing.HUG
				if x["big"]:
					hug = ShardDressing.BIG_HUG
				_count(broken, "hugs a wall or an obstacle", d + rad > hug + 0.001)
				if not x["tall"]:
					_count(
						broken, "low shards stay low", top > StageDresser.DECOR_MAX_HEIGHT + 0.0001
					)
				_count(broken, "under the face's cap", top > float(c["cap"]) + 0.0001)
			for fr: Transform3D in c["fragments"]:
				_count(broken, "fragments float", fr.origin.y < ShardDressing.FRAGMENT_MIN_Y)
			if c["front"]:
				_count(broken, "no fragments on a camera-side face", c["fragments"].size() > 0)
				_count(broken, "a camera-side cap", float(c["cap"]) > ShardDressing.MID_HEIGHT)
	for rule in [
		"on the room's floor",
		"not in a wall or an obstacle",
		"the base clear of structures",
		"hugs a wall or an obstacle",
		"low shards stay low",
		"under the face's cap",
		"fragments float",
		"no fragments on a camera-side face",
		"a camera-side cap"
	]:
		assert_eq(broken.get(rule, 0), 0, rule)
	gut.p("clusters by kind: %s" % kinds)
	assert_gt(kinds.get(&"wall", 0), 0, "along the walls")
	assert_gt(kinds.get(&"corner", 0), 0, "in some corners")
	assert_gt(kinds.get(&"obstacle", 0), 0, "round obstacles")


func test_camera_side_faces_get_the_low_cap() -> void:
	assert_eq(
		ShardDressing._cap(Vector2(1, 0)), INF, "the -X wall's base faces the camera: full height"
	)
	assert_eq(ShardDressing._cap(Vector2(0, -1)), INF, "the +Y wall's base faces the camera")
	assert_eq(ShardDressing._cap(Vector2(-1, 0)), ShardDressing.LOW_HEIGHT, "the +X wall: low")
	assert_eq(ShardDressing._cap(Vector2(0, 1)), ShardDressing.LOW_HEIGHT, "the -Y wall: low")
	assert_eq(ShardDressing._cap(Vector2(-1, -1)), ShardDressing.MID_HEIGHT, "side-on: medium")
	assert_lt(ShardDressing.LOW_HEIGHT, 1.0, "under the 1 m wall")


func test_clusters_keep_the_clearances_and_the_paths() -> void:
	# Broken rules are counted (one assert per rule, not one per crystal).
	var broken := {}
	var seen := 0
	for s in SEEDS:
		var f := _floor(700 + s)
		var placed := ShardDressing.place(f)
		seen += placed.size()
		for k in placed.size():
			var c: Dictionary = placed[k]
			for x: Dictionary in c["crystals"]:
				var base: Vector2 = x["base"]
				var rad: float = x["radius"]
				for d: Rect2 in f["doors"]:
					_count(
						broken,
						"out of doorways",
						d.grow(ShardDressing.DOOR_CLEAR + rad - 0.01).has_point(base)
					)
				for q: Vector2 in f["keep_clear"]:
					_count(
						broken,
						"off rewards",
						base.distance_to(q) < ShardDressing.KEEP_CLEAR + rad - 0.01
					)
				for q: Vector2 in f["spawns"]:
					_count(
						broken,
						"off spawns",
						base.distance_to(q) < ShardDressing.SPAWN_CLEAR + rad - 0.01
					)
				_count(
					broken,
					"off the start",
					base.distance_to(f["start"]) < ShardDressing.START_CLEAR + rad - 0.01
				)
			# The path: free floor straight out past the footprint (no structure).
			if c["kind"] != &"corner":
				var inward: Vector2 = c["inward"]
				var past: Vector2 = (
					(c["foot"] as Vector2)
					+ (
						inward
						* (
							ShardDressing.HUG
							- ShardDressing.FOOT_OFF
							+ ShardDressing.PATH_CLEAR * 0.5
						)
					)
				)
				_count(broken, "a path past it", _in_structure(f, past))
			for j in range(k + 1, placed.size()):
				var o: Dictionary = placed[j]
				_count(
					broken,
					"cluster feet keep apart",
					(
						(c["foot"] as Vector2).distance_to(o["foot"])
						< ShardDressing.FOOT_SPACING - 0.01
					)
				)
	for rule in [
		"out of doorways",
		"off rewards",
		"off spawns",
		"off the start",
		"a path past it",
		"cluster feet keep apart"
	]:
		assert_eq(broken.get(rule, 0), 0, rule)
	assert_gt(seen, SEEDS, "the rooms get clusters")


func _count(broken: Dictionary, rule: String, bad: bool) -> void:
	if bad:
		broken[rule] = broken.get(rule, 0) + 1


## The rooms' corners.
func _corners(room: Rect2) -> Array[Vector2]:
	return [
		room.position,
		room.end,
		Vector2(room.position.x, room.end.y),
		Vector2(room.end.x, room.position.y)
	]


## SD4 (owner A3c): about a fifth of an ordinary room's free wall base (the start room too: no longer crystal-rich),
## a clearly higher share in the crystal rooms; every room but the boss arena has crystals; the start room keeps its
## hero cluster.
func test_a_fifth_of_a_room_and_the_crystal_rooms_far_more() -> void:
	var heroes := 0
	var ordinary: Array[float] = []
	var start: Array[float] = []
	var crystal: Array[float] = []
	for s in 30:
		var f := _floor(1100 + s)
		var placed := ShardDressing.place(f)
		var picked := ShardDressing.floor_crystal_rooms(f)
		var by_room := {}
		for c: Dictionary in placed:
			by_room[c["room"]] = by_room.get(c["room"], []) + [c]
			if c["hero"]:
				assert_eq(c["room"], f["start_room"], "the hero cluster is the start room's")
				heroes += 1
				assert_true((c["light"] as Vector3).is_finite(), "the hero's cold light")
			else:
				assert_false((c["light"] as Vector3).is_finite(), "only the hero carries a light")
		var rooms: Array = f["rooms"]
		for r in rooms.size():
			if r == f["boss_room"]:
				continue
			var mine: Array = by_room.get(r, [])
			assert_gte(mine.size(), 1, "seed %d: room %d has crystals" % [1100 + s, r])
			var cov := ShardDressing.coverage(f, rooms[r], mine)
			if picked.has(r):
				crystal.append(cov)
			elif r == f["start_room"]:
				start.append(cov)
			else:
				ordinary.append(cov)
	assert_gte(heroes, 27, "the start room nearly always fits its hero (%d/30)" % heroes)
	var mean := func(xs: Array[float]) -> float:
		var t := 0.0
		for x in xs:
			t += x
		return t / maxf(xs.size(), 1)
	var o: float = mean.call(ordinary)
	var st: float = mean.call(start)
	var cr: float = mean.call(crystal)
	(
		gut
		. p(
			(
				"covered share of the free wall base: ordinary %.3f, start room %.3f, crystal rooms %.3f"
				% [o, st, cr]
			)
		)
	)
	assert_between(o, 0.15, 0.3, "about a fifth")
	assert_between(st, 0.12, 0.32, "the start room too (no longer crystal-rich)")
	assert_gt(cr, 0.55, "crystal rooms: a clearly higher share")
	assert_gt(cr, o * 2.5, "crystal rooms stand out")


## Mostly corners: the ordinary rooms' wall-base crystals sit near the rooms' corners (corners first, then short runs).
func test_mostly_in_the_corners() -> void:
	var near := 0
	var total := 0
	for s in SEEDS:
		var f := _floor(1100 + s)
		var picked := ShardDressing.floor_crystal_rooms(f)
		for c: Dictionary in ShardDressing.place(f):
			if picked.has(c["room"]) or c["kind"] == &"obstacle" or c["hero"]:
				continue
			var room: Rect2 = f["rooms"][c["room"]]
			for x: Dictionary in c["crystals"]:
				if not x["tall"]:
					continue
				total += 1
				var d := INF
				for q in _corners(room):
					d = minf(d, (x["base"] as Vector2).distance_to(q))
				if d <= 6.0:
					near += 1
	var share := float(near) / maxf(total, 1)
	gut.p("ordinary rooms' tall wall crystals within 6 m of a corner: %.3f of %d" % [share, total])
	assert_gt(share, 0.8, "mostly corners")


## Only stone (A3c): no crystal touches a crate, a wreck, a dead tree or a light prop.
func test_crystals_touch_only_stone() -> void:
	var touching := 0
	var seen := 0
	for s in SEEDS:
		var f := _floor(500 + s)
		var g := ShardDressing._with_stone(f)
		assert_gt((g["soft"] as Array).size(), 0, "the floor has wood or metal pieces")
		for c: Dictionary in ShardDressing.place(f):
			for x: Dictionary in c["crystals"]:
				seen += 1
				var rad: float = x["radius"]
				if (
					ShardDressing.near_soft(g, x["base"])
					< rad + ShardDressing.NON_STONE_CLEAR - 0.001
				):
					touching += 1
	assert_gt(seen, 0)
	assert_eq(touching, 0, "nothing grows against wood or metal")
	assert_true(&"rock_large" in ShardDressing.STONE and &"wall_1m" in ShardDressing.STONE)
	for piece in [&"crate_stack", &"car_wreck", &"dead_tree", &"fire_barrel", &"brazier_pole"]:
		assert_false(piece in ShardDressing.STONE, "%s is not stone" % piece)


## Crystal rooms (A3c): 1-2 a floor, never the start or the boss arena, smaller rooms more likely, the same per
## seed; big crystals (the 1 x 1 m blocks' size) only there.
func test_crystal_rooms_are_few_small_and_hold_the_big_crystals() -> void:
	var picked_area := 0.0
	var picked_n := 0
	var all_area := 0.0
	var all_n := 0
	var big_in := 0
	var big_out := 0
	for s in SEEDS:
		var f := _floor(1100 + s)
		var picked := ShardDressing.floor_crystal_rooms(f)
		assert_eq(picked, ShardDressing.floor_crystal_rooms(f), "the same seed, the same rooms")
		assert_between(picked.size(), 1, 2, "one or two a floor")
		for r in picked:
			assert_ne(r, f["start_room"])
			assert_ne(r, f["boss_room"])
			picked_area += (f["rooms"][r] as Rect2).get_area()
			picked_n += 1
		for r in (f["rooms"] as Array).size():
			if r != f["start_room"] and r != f["boss_room"]:
				all_area += (f["rooms"][r] as Rect2).get_area()
				all_n += 1
		for c: Dictionary in ShardDressing.place(f):
			assert_eq(c["crystal_room"], picked.has(c["room"]))
			for x: Dictionary in c["crystals"]:
				if x["big"]:
					if picked.has(c["room"]):
						big_in += 1
						assert_gte(float(x["radius"]), 0.3, "about the 1 x 1 m blocks' size")
					else:
						big_out += 1
	var pa := picked_area / maxf(picked_n, 1)
	var aa := all_area / maxf(all_n, 1)
	gut.p(
		(
			"mean room area: crystal rooms %.0f m², all rooms %.0f m²; big crystals %d"
			% [pa, aa, big_in]
		)
	)
	assert_lt(pa, aa, "smaller rooms first")
	assert_gt(big_in, 0, "crystal rooms hold big crystals")
	assert_eq(big_out, 0, "only crystal rooms do")


func test_a_crystal_room_is_never_the_shop_the_shrine_or_an_event_room() -> void:
	var f := _floor(1100)
	var rooms: Array = f["rooms"]
	var g := f.duplicate()
	var specials: Array = []
	for r in rooms.size():
		specials.append((rooms[r] as Rect2).get_center())
	g["special"] = specials
	assert_eq(ShardDressing.floor_crystal_rooms(g).size(), 0, "every room special: none picked")


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
		# SD4: a crystal room never holds the shop, the shrine or an event.
		var specials: Array[Vector2] = []
		if reader.has_shop():
			specials.append(reader.shop_pos())
		if reader.has_gamble():
			specials.append(reader.gamble_pos())
		for k in reader.event_count():
			specials.append(reader.event_pos(k))
		for c: Dictionary in shards.clusters:
			if c["crystal_room"]:
				assert_ne(c["room"], reader.floor_start_room(), "never the start room")
				for p in specials:
					assert_false(reader.floor_room(c["room"]).has_point(p), "never a special room")
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
