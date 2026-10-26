extends GutTest
## v0.8.0 RM (owner O91): the remnants drawn (RemnantViews): a pooled bar for each segment where the sim keeps it,
## a ring for each anchor, a gem for each mark or fragment, a flash for each activation and Thermal Break, the
## imprint's ring; no node made per remnant; gone with the sim's.

const W := preload("res://tests/support/mx4_world.gd")


func _ctx(w: World, at: Vector2) -> AttackContext:
	return AttackContext.make(at, 0, 10, w.take_root(), SimEvent.TAG_MELEE, &"")


func test_segments_anchors_and_marks_are_drawn_from_the_pool() -> void:
	var w := W.world(
		&"blade", [&"shared_faultline", &"shared_gravity_stitch"], [[Vector2(2.0, 0.0), 100000]]
	)
	var reader := WorldReader.new(w)
	var v := RemnantViews.new()
	add_child_autofree(v)
	var nodes := v.get_child_count()
	v.sync(reader)
	assert_eq([v.drawn_segments, v.drawn_anchors, v.drawn_marks], [0, 0, 0], "nothing without one")
	var s := Modifiers.step(w, 0)
	for id: StringName in [&"shared_faultline", &"shared_gravity_stitch"]:
		Remnants.on_hook(w, W.hook_of(s, id), _ctx(w, Vector2.ZERO), Vector2(2.0, 0.0), 1)
	v.sync(reader)
	assert_eq([v.drawn_segments, v.drawn_anchors, v.drawn_marks], [1, 1, 0])
	assert_eq(v.get_child_count(), nodes, "pooled: no node made for a remnant")
	var bar := v.get_node("Bar0") as MeshInstance3D
	var mid := SimPlane.to_3d((w.mx.rem_a[0] + w.mx.rem_b[0]) * 0.5)
	assert_almost_eq(bar.position.x, mid.x, 1e-4, "where the sim's crack lies")
	assert_almost_eq(bar.position.z, mid.z, 1e-4)
	assert_almost_eq(bar.scale.x, 1.6, 0.01, "its length")
	W.run(w, 200)
	v.sync(reader)
	assert_eq([v.drawn_segments, v.drawn_anchors, v.drawn_marks], [0, 0, 0], "gone with the sim's")
	assert_false(bar.visible)


func test_activations_and_thermal_breaks_flash() -> void:
	var w := W.world(&"blade", [&"ember_core", &"frost_core"], [[Vector2(2.0, 0.0), 100000]])
	var reader := WorldReader.new(w)
	var v := RemnantViews.new()
	add_child_autofree(v)
	v.sync(reader)
	var root := w.take_root()
	Engines.add_burn(w, 1, 2, root, &"test")
	Engines.add_frost(w, 1, 1, root, &"test")
	v.sync(reader)
	assert_eq(v.flashes_live, 1, "Thermal Break's shatter")
	for f in RemnantViews.FLASH_FRAMES + 1:
		v.sync(reader)
	assert_eq(v.flashes_live, 0, "flashes fade")


func test_the_imprint_shows_where_the_dash_began() -> void:
	var w := W.world(&"blade", [&"long_shadow"])
	var reader := WorldReader.new(w)
	var v := RemnantViews.new()
	add_child_autofree(v)
	W.run(w, 1, W.D, 0, 0, Vector2i(SimTick.MOVE_MAX, 0))
	v.sync(reader)
	assert_true(v.imprint_drawn, "a ring where the dash began")
	W.run(w, 120)
	v.sync(reader)
	assert_false(v.imprint_drawn, "gone when it lapses")
