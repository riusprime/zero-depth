extends GutTest
## v0.8.0 N1 (owner O46/O55, the fire sprites flashing across the screen): the effect layer's pools, pooled lights
## and floor marks are laid out on frame time and their slots change hands between frames, so the renderer must not
## interpolate them between physics ticks (it drew a flame halfway between two fires). The same for the boss
## signature and final-boss views, laid out in _process. scripts/checks/fire_flash_probe.gd counts the pixels.


func _interpolated(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "Node3D", true, false):
		if (n is MultiMeshInstance3D or n is Light3D or n is Decal) and n.is_physics_interpolated():
			out.append(String(root.get_path_to(n)))
	return out


func test_the_effect_layer_is_never_interpolated() -> void:
	assert_true(
		ProjectSettings.get_setting("physics/common/physics_interpolation"), "the game interpolates"
	)
	var parent := Node3D.new()  # an interpolated parent, as WorldViewRoot
	add_child_autofree(parent)
	var layer := VfxLayer.new()
	parent.add_child(layer)
	assert_true(parent.is_physics_interpolated(), "the parent is")
	assert_eq(layer.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)
	assert_eq(_interpolated(layer), [] as Array[String], "no pool, light or mark is interpolated")
	assert_eq(layer.pools.size(), VfxCore.POOLS.size() + 1, "every pool was checked (the ice too)")


func test_the_frame_time_boss_views_are_never_interpolated() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	for v: Node3D in [BossSignatureViews.new(), FinalBossViews.new()]:
		parent.add_child(v)
		assert_false(v.is_physics_interpolated(), "%s" % v.name)
		assert_eq(_interpolated(v), [] as Array[String], "%s: none of its pieces" % v.name)


func test_a_flame_is_placed_at_its_fire() -> void:
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.record = true
	layer.begin(10.0)
	layer.prop_fire(Vector3(4, 1, -3), 13)
	layer.finish()
	assert_eq(layer.placed_flames.size(), 3, "three tongues")
	for p in layer.placed_flames:
		assert_lt(Vector2(p.x - 4.0, p.z + 3.0).length(), 0.5, "at the fire (%s)" % str(p))
