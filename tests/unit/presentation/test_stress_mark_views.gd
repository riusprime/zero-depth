extends GutTest
## v0.9.5 SM: the Stress Mark's arcs (StressMarkViews): one on the side the sim marked, at the enemy, additive with
## no lit square (the texture's alpha is zero outside the arc), flashing when the side breaks and then freed.

const W := preload("res://tests/support/mx4_world.gd")


func _fight() -> World:
	var w := W.world(&"blade", [&"shared_stress_mark"], [[Vector2(3.0, 0.0), 100000]])
	W.run(w, 2)
	return w


func _side(w: World) -> int:
	var m := StressMarks.mask_of(w, 1)
	for s in 4:
		if m & (1 << s):
			return s
	return -1


func test_an_arc_is_drawn_on_the_marked_side() -> void:
	var w := _fight()
	var reader := WorldReader.new(w)
	var v := StressMarkViews.new()
	add_child_autofree(v)
	v.sync(reader)
	var side := _side(w)
	var q := v.quad_of(w.actors.ids[1], side)
	assert_not_null(q, "its arc")
	assert_eq(v.drawn, 1)
	var want := SimPlane.to_3d(StressMarks.side_dir(side)).normalized()
	assert_gt(q.global_transform.basis.x.normalized().dot(want), 0.99, "pointing out of that side")
	assert_almost_eq(q.position.x, 3.0, 0.001, "at the enemy")
	var m := q.material_override as ShaderMaterial
	assert_true(m.shader.code.contains("blend_add"), "additive")
	assert_true(m.shader.code.contains("fog_disabled"), "fog off")


func test_the_texture_is_an_arc_with_no_lit_square() -> void:
	var img := StressMarkViews.arc_texture().get_image()
	var n := img.get_width()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "a corner is clear")
	assert_eq(img.get_pixel(n - 1, n - 1).a, 0.0)
	assert_eq(img.get_pixel(n / 2, n / 2).a, 0.0, "and the middle")
	assert_eq(img.get_pixel(n / 8, n / 2).a, 0.0, "the other side of the ring")
	var lit := 0
	for y in n:
		for x in n:
			lit += 1 if img.get_pixel(x, y).a > 0.05 else 0
	assert_between(lit, 200, n * n / 4, "a thin band, not a square")
	assert_same(StressMarkViews.arc_texture(), StressMarkViews.arc_texture(), "made once")


func test_a_break_flashes_then_the_arc_is_freed() -> void:
	var w := _fight()
	var reader := WorldReader.new(w)
	var v := StressMarkViews.new()
	add_child_autofree(v)
	v.sync(reader)
	var side := _side(w)
	var a := w.actors
	var from := a.pos(1) + StressMarks.side_dir(side) * 2.0
	Damage.hit(
		w, 1, 100, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_PROJECTILE, from, a.pos(1)
	)
	v.sync(reader)
	assert_eq(v.flashing(), 1, "the broken side flashes")
	assert_eq(v.bursts.size(), 1, "and asks for sparks")
	for k in StressMarkViews.FLASH_FRAMES + 1:
		v.sync(reader)
	assert_eq(v.flashing(), 0)
	assert_eq(v.drawn, 0, "freed")


func test_an_enemy_out_of_range_shows_none() -> void:
	var w := W.world(&"blade", [&"shared_stress_mark"], [[Vector2(8.0, 0.0), 100000]])
	W.run(w, 2)
	var v := StressMarkViews.new()
	add_child_autofree(v)
	v.sync(WorldReader.new(w))
	assert_eq(v.drawn, 0)
