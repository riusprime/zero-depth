extends GutTest
## v0.3.5 F14 (owner: "the map is bugged and is not oriented the same way as the actual map it is inverted"): the
## minimap must show the floor the way the iso camera does. Known points and a real floor's rooms are projected
## through the game's own IsoRig camera (Camera3D.unproject_position) and drawn by the minimap; for each one the
## screen offset from the player and the map offset from the player must point the same way on both axes, so a
## mirror (either axis) or a rotation fails.

## Offsets shorter than this on an axis (px) are too close to the axis to call a side.
const AXIS_PX := 4.0


func _rig() -> IsoRig:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.own_world_3d = true
	add_child_autofree(vp)
	var rig := IsoRig.new()
	vp.add_child(rig)
	rig.camera.current = true
	return rig


## Where sim point p lands on screen (px) with the camera centred on `at`.
func _screen(rig: IsoRig, p: Vector2) -> Vector2:
	return rig.camera.unproject_position(SimPlane.to_3d(p))


func _same_side(a: float, b: float) -> bool:
	if absf(a) < AXIS_PX or absf(b) < AXIS_PX:
		return true
	return signf(a) == signf(b)


func test_the_turn_matches_the_camera_in_every_direction() -> void:
	var rig := _rig()
	rig.snap_to(Vector3.ZERO)
	var o := _screen(rig, Vector2.ZERO)
	var checked := 0
	for k in 16:
		var a := TAU * k / 16.0 + 0.1
		var d := Vector2(cos(a), sin(a)) * 10.0
		var s := _screen(rig, d) - o
		var m := MinimapView.turn(d)
		assert_true(
			_same_side(s.x, m.x * 40.0), "dir %d: left/right agree (screen %s, map %s)" % [k, s, m]
		)
		assert_true(
			_same_side(s.y, m.y * 40.0), "dir %d: up/down agree (screen %s, map %s)" % [k, s, m]
		)
		assert_gt(s.normalized().dot(m.normalized()), 0.95, "dir %d: the same direction" % k)
		checked += 1
	assert_eq(checked, 16)


func test_screen_up_and_right_are_the_same_sim_directions_on_both() -> void:
	var rig := _rig()
	rig.snap_to(Vector3.ZERO)
	var o := _screen(rig, Vector2.ZERO)
	# Screen right is sim (+1, +1); screen up (away from the camera) is sim (-1, +1).
	var right := _screen(rig, Vector2(5, 5)) - o
	var up := _screen(rig, Vector2(-5, 5)) - o
	assert_gt(right.x, 0.0, "camera: sim (+1, +1) is to the right")
	assert_almost_eq(right.y, 0.0, 0.5)
	assert_lt(up.y, 0.0, "camera: sim (-1, +1) is up")
	assert_almost_eq(up.x, 0.0, 0.5)
	assert_gt(MinimapView.turn(Vector2(5, 5)).x, 0.0, "map: sim (+1, +1) is to the right")
	assert_lt(MinimapView.turn(Vector2(-5, 5)).y, 0.0, "map: sim (-1, +1) is up, not down")


func test_a_real_floors_rooms_sit_in_the_same_screen_quadrants_on_the_map() -> void:
	var repo := ContentRepository.load_all()
	var w := FloorScenario.build(
		11,
		PlayerTable.starting_values(),
		ContentCompiler.compile_enemies(repo),
		SpawnTable.new(),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		1
	)
	var r := WorldReader.new(w)
	var rig := _rig()
	var player := r.player_pos()
	rig.snap_to(SimPlane.to_3d(player))
	var map := Minimap.new()
	add_child_autofree(map)
	map.sync(r)
	await get_tree().process_frame
	await get_tree().process_frame
	var o_screen := _screen(rig, player)
	var o_map := map.corner.to_map(player)
	var lefts := 0
	var rights := 0
	var ups := 0
	var downs := 0
	for k in r.floor_room_count():
		var c := r.floor_room(k).get_center()
		var s := _screen(rig, c) - o_screen
		var m := map.corner.to_map(c) - o_map
		assert_true(
			_same_side(s.x, m.x), "room %d: left/right agree (screen %s, map %s)" % [k, s, m]
		)
		assert_true(_same_side(s.y, m.y), "room %d: up/down agree (screen %s, map %s)" % [k, s, m])
		lefts += 1 if s.x < -AXIS_PX else 0
		rights += 1 if s.x > AXIS_PX else 0
		ups += 1 if s.y < -AXIS_PX else 0
		downs += 1 if s.y > AXIS_PX else 0
	gut.p("rooms: %d left, %d right, %d up, %d down" % [lefts, rights, ups, downs])
	assert_gt(r.floor_room_count(), 3, "a real floor")
	assert_gt(lefts + rights, 0, "some rooms off to the side")
	assert_gt(ups + downs, 0, "some rooms above or below")
