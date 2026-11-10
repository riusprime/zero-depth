extends GutTest
## The wall-fade index (Occlusion.build_index) is rebuilt when the floor's walls change, not only when the camera tilts.
## It used to compare its count with the list it was built from, which can never differ.


func _wall(x: float) -> Array:
	return [Vector2(x, 0), Vector2(2.0, 0.3), 0.0, 3.0]


func test_no_index_yet_is_stale() -> void:
	assert_true(WorldViewRoot.occlusion_stale({}, 2, 35.26))


func test_the_same_walls_and_pitch_keep_the_index() -> void:
	var index := Occlusion.build_index(35.26, [_wall(0), _wall(5)])
	assert_false(WorldViewRoot.occlusion_stale(index, 2, 35.26))


func test_a_wall_added_after_the_first_sync_makes_it_stale() -> void:
	var index := Occlusion.build_index(35.26, [_wall(0), _wall(5)])
	assert_true(
		WorldViewRoot.occlusion_stale(index, 3, 35.26), "a late slab or wall joins the cutaway"
	)
	assert_true(WorldViewRoot.occlusion_stale(index, 1, 35.26), "and one that went leaves it")


func test_a_new_pitch_makes_it_stale() -> void:
	var index := Occlusion.build_index(35.26, [_wall(0), _wall(5)])
	assert_true(WorldViewRoot.occlusion_stale(index, 2, 50.0))
