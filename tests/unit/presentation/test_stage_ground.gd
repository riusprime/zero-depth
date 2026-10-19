extends GutTest
## v0.8.0 Step FS (owner O86; perf review Part 2 item 4): the stage's ground is one MultiMeshInstance3D per material
## (the checker's two colours; one for the textured ground), each instance a unit plane scaled to its tile, clipped to
## the room, at the same place and with the same colour as the old one-node-per-tile ground. No shadow cast.
## (Headless, the RenderingServer doesn't keep a MultiMesh's transforms, so the tiles' geometry is read from
## StageView.room_ground_cells, the function the build uses, and the nodes are checked by count and colour.)

const PALETTE := {"ground": Color(0.2, 0.2, 0.2), "ground_alt": Color(0.3, 0.3, 0.3)}


func _stage() -> StageView:
	var stage := StageView.new()
	stage.palette = PALETTE
	add_child_autofree(stage)
	return stage


## The ground nodes: [colour, instance count] each.
func _grounds(stage: StageView) -> Array:
	var out: Array = []
	for c in stage.get_children():
		assert_false(c is MeshInstance3D, "no node per tile")
		if c is MultiMeshInstance3D:
			var g := c as MultiMeshInstance3D
			assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			var col: Color = (g.material_override as StandardMaterial3D).albedo_color
			out.append([col, g.multimesh.instance_count])
	return out


func test_room_ground_is_the_clipped_checker_in_two_multimeshes() -> void:
	var room := Rect2(1.0, -3.0, 9.0, 6.5)  # not on the tile grid: clipped edge tiles
	var rects: Array[Rect2] = [room]
	var cells := StageView.room_ground_cells(rects)
	var tm := StageView.TILE_M
	var area := 0.0
	for k in 2:
		for x: Transform3D in cells[k]:
			var size := Vector2(x.basis.x.length(), x.basis.z.length())
			var r := Rect2(SimPlane.to_sim(x.origin) - size * 0.5, size)
			assert_true(room.grow(0.001).encloses(r), "clipped to the room")
			area += r.get_area()
			var i := int(floor((r.position.x + 0.001) / tm))
			var j := int(floor((r.position.y + 0.001) / tm))
			assert_eq(posmod(i + j, 2), k, "in its grid cell's checker colour")
	assert_almost_eq(area, room.get_area(), 0.01, "the tiles cover the room exactly")
	var stage := _stage()
	stage._ground_rects = rects
	stage._build_room_ground()
	var grounds := _grounds(stage)
	assert_eq(grounds.size(), 2, "one per checker colour")
	assert_eq(grounds[0], [PALETTE["ground"], cells[0].size()])
	assert_eq(grounds[1], [PALETTE["ground_alt"], cells[1].size()])


func test_arena_ground_is_the_square_checker() -> void:
	var stage := _stage()
	stage._build_ground(15.0)
	var tiles := int(ceil(30.0 / StageView.TILE_M)) + 2
	var grounds := _grounds(stage)
	assert_eq(grounds.size(), 2)
	assert_eq(grounds[0][1] + grounds[1][1], tiles * tiles, "every tile kept")
