extends GutTest
## The kit dressing rules (v0.5.9 Step 4), as properties over generated floors: the same seed gives the same
## placements; every slab is dressed and every structural wall is the procedural wall's (v0.8.0 N15: the only
## style); looks solid = is solid (a piece taller than the decoration limit
## stays inside its sim footprint); decoration stays low and out of doorways and away from rewards and the portal;
## the start hall gets its light, and no light sits in a doorway.

const SEEDS := 40


## The dresser's input for a generated floor, as StageView builds it (walls in the same order, gate footprint out).
func _floor(seed_value: int, biome := &"ruins") -> Dictionary:
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
		"biome": biome,
		"seed": seed_value,
	}


## The unit box's four bottom corners under a placement, on the sim plane.
func _corners(xform: Transform3D) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c: Vector3 in [
		Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)
	]:
		var p := xform * c
		out.append(Vector2(p.x, -p.z))
	return out


func _inside(p: Vector2, w: Array, slack: float) -> bool:
	var local := (p - (w[0] as Vector2)).rotated(-(w[2] as float))
	var half: Vector2 = w[1]
	return absf(local.x) <= half.x + slack and absf(local.y) <= half.y + slack


func test_the_same_seed_gives_the_same_floor() -> void:
	var a := StageDresser.dress(_floor(77))
	var b := StageDresser.dress(_floor(77))
	assert_eq(a.size(), b.size())
	for k in a.size():
		assert_eq(a[k]["piece"], b[k]["piece"])
		assert_eq(a[k]["xform"], b[k]["xform"])
	var c := StageDresser.dress(_floor(78))
	assert_ne(a.size(), 0)
	assert_true(
		c.size() != a.size() or c[0]["xform"] != a[0]["xform"], "another seed, another floor"
	)


func test_every_wall_and_slab_is_dressed_and_tall_pieces_stay_in_their_footprint() -> void:
	for s in SEEDS:
		var f := _floor(500 + s, [&"ruins", &"night_rocks", &"red_canyon"][s % 3])
		var walls: Array = f["walls"]
		var placements := StageDresser.dress(f)
		var dressed := {}
		for p: Dictionary in placements:
			var xform: Transform3D = p["xform"]
			var height := xform.basis.y.length()
			if p["kind"] == &"decor":
				assert_lte(height, StageDresser.DECOR_MAX_HEIGHT + 0.0001, "decoration stays low")
				continue
			dressed[p["wall"]] = true
			var w: Array = walls[p["wall"]]
			for c in _corners(xform):
				if not _inside(c, w, 0.1):
					fail_test(
						(
							"seed %d: %s leaves wall %d's footprint at %s"
							% [500 + s, p["piece"], p["wall"], c]
						)
					)
					return
		for i in walls.size():
			if int(walls[i][3]) == 0:
				assert_true(
					ProceduralWall.handles(walls[i]), "seed %d: wall %d is built" % [500 + s, i]
				)
			else:
				assert_true(dressed.has(i), "seed %d: wall %d is dressed" % [500 + s, i])


func test_decoration_keeps_clear_and_lights_avoid_doorways() -> void:
	for s in SEEDS:
		var f := _floor(900 + s)
		var lights_in_start := 0
		var start: Rect2 = f["rooms"][f["start_room"]]
		for p: Dictionary in StageDresser.dress(f):
			var o: Vector3 = (p["xform"] as Transform3D).origin
			var at := Vector2(o.x, -o.z)
			if p["kind"] == &"decor":
				for q: Vector2 in f["keep_clear"]:
					assert_gte(
						at.distance_to(q),
						StageDresser.KEEP_CLEAR,
						"decor away from rewards and the portal"
					)
				for d: Rect2 in f["doors"]:
					assert_false(
						d.grow(StageDresser.KEEP_CLEAR - 0.01).has_point(at),
						"decor out of doorways"
					)
			elif p["kind"] == &"light":
				for d: Rect2 in f["doors"]:
					assert_false(
						d.grow(StageDresser.DOOR_CLEAR - 0.8).has_point(at), "no light in a doorway"
					)
				if start.grow(3.5).has_point(at):
					lights_in_start += 1
		assert_gte(lights_in_start, 1, "seed %d: the start hall has its light" % (900 + s))


## v0.8.0 RT: the dresser's input for a run floor with the designed rooms, as StageView builds it from WorldReader
## (each interior wall's piece and designed-room height; the designed rooms' drawn-only pieces).
func _designed_floor(seed_value: int, biome: StringName) -> Dictionary:
	var repo := ContentRepository.load_all()
	var layout := FloorGenerator.generate(seed_value, RunSaver.floor_tables(null, repo)[&"map"])
	var f := _floor(seed_value, biome)
	var walls: Array = []
	var index := {}
	for i in layout.walls.size():
		var w := layout.walls[i]
		walls.append(
			[
				w.center,
				w.half,
				SimPlane.yaw_of(w.angle),
				0 if i < layout.slab_first else 1,
				layout.piece_tag(w),
				layout.piece_height(w)
			]
		)
		index[FloorLayout.piece_key(w)] = i
	var props: Array = []
	for p: Array in layout.layout_props:
		var key: String = p[5]
		props.append(
			{
				"piece": p[0],
				"pos": p[1],
				"angle": p[2],
				"size": p[3],
				"height": p[4],
				"wall": -1 if key.is_empty() else int(index.get(key, -2))
			}
		)
	var doors: Array = []
	for i in layout.door_rooms.size():
		doors.append(layout.door_rect(i))
	f["walls"] = walls
	f["rooms"] = layout.rooms.duplicate()
	f["doors"] = doors
	f["keep_clear"] = [layout.portal_pos]
	f["props"] = props
	var look: BiomeLook = (repo.get_def(&"biomes", biome) as BiomeDefinition).look
	if look != null:
		f["square_cover"] = StageView._names(look.square_cover)
		f["decor_swap"] = StageView._names(look.decor_swap)
	return f


func test_designed_rooms_are_drawn_solid_where_solid_and_restyled_by_the_biome() -> void:
	for biome: StringName in [&"ruins", &"frozen_shore"]:
		var f := _designed_floor(4242, biome)
		var walls: Array = f["walls"]
		var square: Dictionary = f.get("square_cover", {})
		var designed := 0
		for w: Array in walls:
			designed += 1 if float(w[5]) >= 0.0 else 0
		assert_gt(designed, 20, "%s: the floor has designed rooms" % biome)
		var crates := 0
		for p: Dictionary in StageDresser.dress(f):
			var xform: Transform3D = p["xform"]
			if p["kind"] == &"decor":
				assert_lte(xform.basis.y.length(), StageDresser.DECOR_MAX_HEIGHT + 0.0001)
				continue
			var wi: int = p["wall"]
			if wi < 0:
				fail_test("%s: a tall %s stands on no blocker" % [biome, p["piece"]])
				return
			var w: Array = walls[wi]
			for c in _corners(xform):
				if not _inside(c, w, 0.12):
					fail_test("%s: %s leaves wall %d at %s" % [biome, p["piece"], wi, c])
					return
			if w.size() > 5 and float(w[5]) >= 0.0:
				crates += 1 if p["piece"] == &"crate_stack" else 0
				if StringName(w[4]) in [&"crate_stack", &"rock_large"] and not square.is_empty():
					assert_has(square, p["piece"], "%s: square cover is the biome's" % biome)
				elif StringName(w[4]) != p["piece"] and square.is_empty():
					fail_test("%s: %s drawn as %s" % [biome, w[4], p["piece"]])
					return
		if square.is_empty():
			assert_gt(crates, 0, "%s: the layout's crates stand" % biome)
		else:
			assert_eq(crates, 0, "%s: no crate stack in a biome that swaps them" % biome)
	# A drawn piece whose blocker is gone (the boss door's way) is not drawn.
	var gone := {
		"piece": &"wall_pillar",
		"pos": Vector2.ZERO,
		"angle": 0,
		"size": Vector2.ONE,
		"height": 0.0,
		"wall": -2
	}
	assert_eq(StageDresser.dress({"props": [gone]}).size(), 0)
