extends GutTest
## Occlusion.select is pure (PRESENTATION_CONTRACTS §5): which walls hide a focus point from the camera.

const TO_CAM := Vector2(0.70710678, -0.70710678)  # yaw +45°: the camera sits toward sim (+x, -y)


func _wall(center: Vector2, half: Vector2, angle: float, height: float) -> Array:
	return [center, half, angle, height]


func test_wall_between_point_and_camera_is_selected() -> void:
	var walls := [_wall(Vector2(1, -1), Vector2(1.5, 0.2), PI / 4.0, 2.4)]
	assert_eq(
		Occlusion.select(TO_CAM, 35.26, [Vector2.ZERO] as Array[Vector2], walls),
		PackedInt32Array([0])
	)


func test_wall_behind_point_is_not_selected() -> void:
	var walls := [_wall(Vector2(-1, 1), Vector2(1.5, 0.2), PI / 4.0, 2.4)]
	assert_eq(Occlusion.select(TO_CAM, 35.26, [Vector2.ZERO] as Array[Vector2], walls).size(), 0)


func test_wall_off_axis_is_not_selected() -> void:
	var walls := [_wall(Vector2(3, 3), Vector2(1.0, 0.2), 0.0, 2.4)]
	assert_eq(Occlusion.select(TO_CAM, 35.26, [Vector2.ZERO] as Array[Vector2], walls).size(), 0)


func test_low_wall_far_away_does_not_hide() -> void:
	# A 1 m wall 4 m away: the sight line has risen above it (reach = 0.5 / tan 35° ≈ 0.7 m).
	var walls := [_wall(TO_CAM * 4.0, Vector2(1.5, 0.2), PI / 4.0, 1.0)]
	assert_eq(Occlusion.select(TO_CAM, 35.26, [Vector2.ZERO] as Array[Vector2], walls).size(), 0)


func test_two_focus_points_one_hidden() -> void:
	var walls := [_wall(Vector2(6, -1), Vector2(1.5, 0.2), PI / 4.0, 2.4)]
	var focus: Array[Vector2] = [Vector2.ZERO, Vector2(5, 0)]
	assert_eq(Occlusion.select(TO_CAM, 35.26, focus, walls), PackedInt32Array([0]))
	focus = [Vector2.ZERO]
	assert_eq(Occlusion.select(TO_CAM, 35.26, focus, walls).size(), 0)


## v0.8.0 P3 (owner O32): select_in through build_index answers exactly what select answers, over a scattered floor of
## walls (long and short, every height) and focus groups anywhere on it, one point or many.
func test_the_index_selects_the_same_walls() -> void:
	var rng := RngStream.derive(7, "occ_index")
	var walls := []
	for k in 300:
		var c := Vector2(rng.range_int(-6000, 6000), rng.range_int(-6000, 6000)) / 100.0
		var half := Vector2(rng.range_int(20, 1600), rng.range_int(10, 80)) / 100.0
		walls.append([c, half, rng.range_int(0, 628) / 100.0, rng.range_int(50, 400) / 100.0])
	var index := Occlusion.build_index(35.26, walls)
	assert_eq(index["count"], 300)
	var hits := 0
	for trial in 40:
		var centre := Vector2(rng.range_int(-6000, 6000), rng.range_int(-6000, 6000)) / 100.0
		var focus: Array[Vector2] = []
		for k in 1 + trial % 25:
			focus.append(
				centre + Vector2(rng.range_int(-1000, 1000), rng.range_int(-1000, 1000)) / 100.0
			)
		var want := Occlusion.select(TO_CAM, 35.26, focus, walls)
		assert_eq(Occlusion.select_in(TO_CAM, index, focus, walls), want, "trial %d" % trial)
		hits += want.size()
	assert_gt(hits, 0, "some walls hide some points")
	var none: Array[Vector2] = []
	assert_eq(Occlusion.select_in(TO_CAM, index, none, walls).size(), 0, "no focus, no walls")
