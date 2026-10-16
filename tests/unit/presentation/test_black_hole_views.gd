extends GutTest
## v0.8.0 P2 (owner O24): Void's black holes drawn (BlackHoleViews): one pooled hole for each the sim keeps, where it
## stands, growing in and shrinking out with its life, hidden when it closes; the pool is made once (no node made per
## hole); reduced motion slows the swirl.

const W := preload("res://tests/support/mx4_world.gd")


func test_each_standing_hole_is_drawn_where_it_stands_from_the_pool() -> void:
	var w := W.world(&"gun", [&"gravity_well"])
	var reader := WorldReader.new(w)
	var v := BlackHoleViews.new()
	add_child_autofree(v)
	var nodes := v.get_child_count()
	v.sync(reader)
	assert_eq(v.drawn, 0, "nothing without a hole")
	BlackHoles.open(w, Vector2(4.0, -2.0), 3)
	BlackHoles.open(w, Vector2(-3.0, 1.0), 3)
	W.run(w, 1)
	v.sync(reader)
	assert_eq(v.drawn, 2)
	assert_eq(v.get_child_count(), nodes, "pooled: no node made for a hole")
	var swirl := v.get_node("Swirl0") as MeshInstance3D
	assert_true(swirl.visible)
	var at := SimPlane.to_3d(Vector2(4.0, -2.0))
	assert_almost_eq(swirl.position.x, at.x, 1e-4, "where the sim's hole stands")
	assert_almost_eq(swirl.position.z, at.z, 1e-4)
	var small := swirl.scale.x
	W.run(w, 20)
	v.sync(reader)
	assert_gt(swirl.scale.x, small, "it opens")
	var open := swirl.scale.x
	W.run(w, 95)
	v.sync(reader)
	assert_lt(swirl.scale.x, open, "it closes at the end of its life")
	W.run(w, 10)
	v.sync(reader)
	assert_eq(v.drawn, 0, "gone with the sim's")
	assert_false(swirl.visible)


func test_reduced_motion_slows_the_swirl() -> void:
	var w := W.world(&"gun", [&"gravity_well"])
	var reader := WorldReader.new(w)
	var v := BlackHoleViews.new()
	add_child_autofree(v)
	BlackHoles.open(w, Vector2.ZERO, 3)
	var was := ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = true
	v.sync(reader)
	var m := (v.get_node("Swirl0") as MeshInstance3D).material_override as ShaderMaterial
	assert_almost_eq(float(m.get_shader_parameter("speed")), 0.25, 1e-6)
	ViewPrefs.reduced_motion = false
	v.sync(reader)
	assert_almost_eq(float(m.get_shader_parameter("speed")), 1.0, 1e-6)
	ViewPrefs.reduced_motion = was
