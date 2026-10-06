extends GutTest


func test_cardinal_directions() -> void:
	assert_eq(Kin.dir(0), Vector2(1, 0))
	assert_eq(Kin.dir(1024), Vector2(0, 1))
	assert_eq(Kin.dir(2048), Vector2(-1, 0))
	assert_eq(Kin.dir(3072), Vector2(0, -1))
	assert_eq(Kin.dir(4096), Kin.dir(0), "angles wrap")


func test_unit_length_everywhere() -> void:
	for a in range(0, 4096, 37):
		assert_almost_eq(Kin.length(Kin.dir(a)), 1.0, 1e-6, "angle %d" % a)


func test_angle_of_round_trips_every_angle() -> void:
	var bad := 0
	for a in 4096:
		if Kin.angle_of(Kin.dir(a)) != a:
			bad += 1
	assert_eq(bad, 0, "angles whose round trip failed")


func test_angle_of_scaled_vectors_and_zero() -> void:
	assert_eq(Kin.angle_of(Vector2(5, 5)), 512)
	assert_eq(Kin.angle_of(Vector2(-3, 3)), 1536)
	assert_eq(Kin.angle_of(Vector2.ZERO), 0)
