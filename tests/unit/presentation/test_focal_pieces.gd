extends GutTest
## The collapsed hall's centrepieces are the owner's grand arch (Ruins, Night Rocks) and great monolith (Starfall)
## (scripts/assets/focal_v0120_prep.py), and the other focal pieces stand half again as tall or as wide as they did.
## Each is drawn on the blocker the sim already had (the hall's focal 3 x 1 m and 2.6 m square, the quarry's face, the
## fire's barrel): on the floor, inside that footprint, matte, in the biome's tint. A piece taller than a slab sets
## how far its cutaway reaches (StageDresser.cover_top), so a hero behind the 6 m monolith still shows.

const HALL := "res://data/rooms/purposes/hall.tres"
const CAMP := "res://data/rooms/purposes/camp.tres"
const QUARRY := "res://data/rooms/purposes/quarry.tres"
## Per hall biome: its centrepiece, its blocker's footprint (the sim's, unchanged) and its drawn height.
const CENTRE := {
	&"ruins": [&"grand_arch", Vector2(3.0, 1.0), 2.5],
	&"night_rocks": [&"grand_arch", Vector2(3.0, 1.0), 2.5],
	&"starfall": [&"great_monolith", Vector2(2.6, 2.6), 6.0],
}
## The camp's fire-pit stones before (footprint) and the quarry face's first height.
const STONES_BEFORE := {
	&"ruins": Vector2(0.6, 0.5),
	&"frozen_shore": Vector2(0.5, 0.5),
	&"red_canyon": Vector2(0.6, 0.6)
}
const FACE_BEFORE_H := 3.2
## Run seeds whose second floor lays a hall in that biome (SaveLab.build_floor with the biome).
const HALL_SEED := {&"ruins": 5, &"night_rocks": 1, &"starfall": 1}
const OBSERVATORY_BEFORE_H := 2.6


func after_each() -> void:
	KitModels.clear_cache()


func _piece(path: String, biome: StringName, token: StringName) -> RoomPurposePiece:
	for pal: RoomPurposePalette in (load(path) as RoomPurposeDefinition).palettes:
		if pal.biome == biome:
			for p: RoomPurposePiece in pal.pieces:
				if p.token == token:
					return p
	return null


func test_the_centrepieces_load_at_their_natural_size_matte() -> void:
	for id: StringName in [&"grand_arch", &"great_monolith"]:
		var spec: Dictionary = KitModels.SPECS[id]
		assert_eq(spec["role"], &"room", "%s: a purpose room's piece" % id)
		assert_false(
			spec.has("tint"), "%s takes the biome's whole tint, as the room pieces do" % id
		)
		assert_has(RoomPurposeDefinition.PIECES, id)
		var piece := KitModels.get_piece(id)
		assert_false(piece.is_empty(), "%s is installed" % id)
		if piece.is_empty():
			continue
		var size: Vector3 = piece["size"]
		assert_almost_eq(size.x, (spec["foot"] as Vector2).x, 0.02, "%s: its own length" % id)
		assert_almost_eq(size.z, (spec["foot"] as Vector2).y, 0.02, "%s: its own depth" % id)
		assert_almost_eq(size.y, float(spec["height"]), 0.02, "%s: its own height" % id)
		var mat := piece["material"] as BaseMaterial3D
		assert_almost_eq(mat.metallic, 0.0, 0.001, "%s is matte" % id)
		assert_gt(mat.roughness, 0.85, "%s is matte" % id)
	assert_almost_eq(
		float(KitModels.SPECS[&"grand_arch"]["foot"].x), 6.0, 0.01, "the arch's asked width"
	)
	assert_almost_eq(
		float(KitModels.SPECS[&"great_monolith"]["height"]), 6.0, 0.01, "the monolith's height"
	)


func test_each_hall_names_its_centrepiece_on_the_same_blocker() -> void:
	for biome: StringName in CENTRE:
		var want: Array = CENTRE[biome]
		var p := _piece(HALL, biome, &"focal")
		assert_not_null(p, "the %s hall has a focal piece" % biome)
		if p == null:
			continue
		assert_eq(p.piece, want[0], "the %s hall's centrepiece" % biome)
		assert_true(p.solid, "a blocker, as before")
		assert_eq(p.size, want[1], "the %s hall's blocker keeps the sim's footprint" % biome)
		assert_almost_eq(p.height, float(want[2]), 0.001, "drawn at its height for that width")
		assert_almost_eq(p.lift, 0.0, 0.001, "on the floor")


func test_the_other_focal_pieces_stand_larger_on_their_footprints() -> void:
	for biome: StringName in STONES_BEFORE:
		var s := _piece(CAMP, biome, &"stone")
		assert_false(s.solid, "the pit's stones stay decoration")
		assert_almost_eq(
			s.size.x, STONES_BEFORE[biome].x * 1.5, 0.001, "%s pit stones 1.5x long" % biome
		)
		assert_almost_eq(
			s.size.y, STONES_BEFORE[biome].y * 1.5, 0.001, "%s pit stones 1.5x deep" % biome
		)
		assert_lte(s.height, StageDresser.DECOR_MAX_HEIGHT, "and low enough to read as floor")
		var fire := _piece(CAMP, biome, &"fire")
		assert_eq(fire.size, Vector2(1.0, 1.0), "the fire's blocker is the sim's, unchanged")
	for biome: StringName in [&"red_canyon", &"night_rocks"]:
		var face := _piece(QUARRY, biome, &"face")
		assert_eq(face.size, Vector2(3.6, 3.0), "the %s face's blocker is the sim's" % biome)
		assert_almost_eq(face.height, FACE_BEFORE_H * 1.5, 0.001, "the %s face 1.5x tall" % biome)
	assert_almost_eq(
		float(KitModels.SPECS[&"ruined_observatory"]["height"]),
		OBSERVATORY_BEFORE_H * 1.5,
		0.001,
		"the observatory 1.5x tall on whatever footprint it fills"
	)


func test_a_tall_piece_reaches_further_in_the_cutaway() -> void:
	var slab := StageView.SLAB_HEIGHT
	assert_almost_eq(StageDresser.cover_top(&"great_monolith", 6.0, slab), 6.0, 0.001)
	assert_almost_eq(StageDresser.cover_top(&"grand_arch", 2.5, slab), 2.5, 0.001)
	assert_almost_eq(
		StageDresser.cover_top(&"rock_large", 4.8, slab), 4.8, 0.001, "the quarry face"
	)
	assert_almost_eq(
		StageDresser.cover_top(&"ruined_observatory", 0.0, slab), 3.9, 0.001, "its own height"
	)
	assert_almost_eq(
		StageDresser.cover_top(&"stone_arch", 9.0, slab), 2.4, 0.001, "a biome piece keeps its own"
	)
	assert_almost_eq(StageDresser.cover_top(&"crate_stack", 1.3, slab), slab, 0.001, "never lower")
	assert_almost_eq(StageDresser.cover_top(&"", -1.0, slab), slab, 0.001, "a plain slab")
	# The hero 4 m behind the monolith (toward the camera's far side): a slab's reach misses it, the monolith's not.
	var to_cam := Vector2(1, 0)
	var hero: Array[Vector2] = [Vector2(-5.0, 0.0)]
	var low := [[Vector2.ZERO, Vector2(1.3, 1.3), 0.0, slab]]
	var tall := [[Vector2.ZERO, Vector2(1.3, 1.3), 0.0, 6.0]]
	assert_eq(Occlusion.select(to_cam, 35.26, hero, low).size(), 0, "a slab's height: not hidden")
	assert_eq(
		Occlusion.select(to_cam, 35.26, hero, tall), PackedInt32Array([0]), "the monolith fades"
	)


## A hall floor of each biome, dressed as StageView dresses it: the centrepiece is drawn once on its blocker, on the
## floor, inside the blocker's footprint, at its drawn height, as cover (tinted, fading with its blocker).
func test_the_dressed_hall_draws_its_centrepiece_on_its_blocker() -> void:
	for biome: StringName in CENTRE:
		var w := SaveLab.build_floor(SaveLab.run_state(HALL_SEED[biome], 2), biome)
		var r := WorldReader.new(w)
		assert_true(w.floor_layout.room_purpose.has(&"hall"), "%s: the seed lays a hall" % biome)
		var walls: Array = []
		for i in r.wall_count():
			var o := r.wall(i)
			var lh := r.wall_layout_height(i)
			walls.append(
				[o.center, o.half, SimPlane.yaw_of(o.angle), r.wall_class(i), r.wall_piece(i), lh]
			)
		var props: Array = []
		for i in r.layout_prop_count():
			props.append(r.layout_prop(i))
		var f := {
			"walls": walls,
			"rooms": [],
			"doors": [],
			"keep_clear": [],
			"biome": biome,
			"seed": 5,
			"props": props,
			"named_rooms": r.floor_purpose_rects(),
		}
		var want: Array = CENTRE[biome]
		var seen := 0
		for p: Dictionary in StageDresser.dress(f):
			if p["piece"] != want[0]:
				continue
			seen += 1
			var xf: Transform3D = p["xform"]
			var wall: Array = walls[p["wall"]]
			assert_eq(p["kind"], &"cover", "tinted and fading with its blocker")
			assert_almost_eq(xf.origin.y, 0.0, 0.001, "on the floor")
			assert_almost_eq(xf.basis.y.length(), float(want[2]), 0.001, "at its drawn height")
			assert_almost_eq(
				xf.basis.x.length(), (wall[1] as Vector2).x * 2.0, 0.01, "as long as its blocker"
			)
			assert_almost_eq(xf.basis.z.length(), (wall[1] as Vector2).y * 2.0, 0.01, "as deep")
			assert_eq(wall[4], want[0], "its blocker names it")
			var foot: Vector2 = (wall[1] as Vector2) * 2.0
			assert_almost_eq(
				foot.x, (want[1] as Vector2).x, 0.01, "the blocker is the hall's focal footprint"
			)
			assert_almost_eq(foot.y, (want[1] as Vector2).y, 0.01, "both ways")
		assert_eq(seen, 1, "%s: one centrepiece" % biome)
