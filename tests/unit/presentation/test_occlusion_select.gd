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
