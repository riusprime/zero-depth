extends GutTest


func test_snaps_inside_the_cone_only() -> void:
	var aim := Vector2(1, 0)
	var near := Vector2(5, 0.5)  # about 5.7° off
	var far := Vector2(5, 3)  # about 31° off
	assert_almost_eq(AimAssist.apply(aim, [near] as Array[Vector2]).angle(), near.angle(), 1e-5)
	assert_eq(AimAssist.apply(aim, [far] as Array[Vector2]), aim)
	assert_eq(AimAssist.apply(aim, [] as Array[Vector2]), aim, "no targets in v0.0.1: unchanged")
