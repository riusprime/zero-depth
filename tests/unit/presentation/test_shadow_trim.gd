extends GutTest
## v0.9.5 PF4: an enemy's small rig pieces stop casting shadows; the largest `keep` pieces by box volume keep theirs.


func _box(parent: Node3D, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	parent.add_child(mi)
	return mi


func test_only_the_largest_pieces_keep_casting() -> void:
	var top := Node3D.new()
	add_child_autofree(top)
	var big := _box(top, Vector3(1, 1, 1))
	var mid := _box(top, Vector3(0.6, 0.6, 0.6))
	var small := _box(top, Vector3(0.2, 0.2, 0.2))
	var off := _box(top, Vector3(2, 2, 2))
	off.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := ShadowTrim.trim(top, 2)
	assert_eq(
		r,
		[3, 2] as Array[int],
		"three casters before, two after (the one already off is not counted)"
	)
	assert_eq(big.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(mid.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(small.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_a_nodes_scale_counts_toward_its_pieces_size() -> void:
	var top := Node3D.new()
	add_child_autofree(top)
	var arm := Node3D.new()
	arm.scale = Vector3(3, 3, 3)
	top.add_child(arm)
	var scaled := _box(arm, Vector3(0.5, 0.5, 0.5))  # 1.5 m in the avatar
	var plain := _box(top, Vector3(1, 1, 1))
	ShadowTrim.trim(top, 1)
	assert_eq(scaled.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(plain.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_the_half_rate_views_are_the_decorative_ones() -> void:
	assert_eq(ViewSchedule.HALF_RATE.keys().size(), 2)
	assert_true(ViewSchedule.HALF_RATE.has(&"status_fx"))
	assert_true(ViewSchedule.HALF_RATE.has(&"modifier_marks"))
	assert_ne(
		ViewSchedule.HALF_RATE[&"status_fx"], ViewSchedule.HALF_RATE[&"modifier_marks"], "staggered"
	)
