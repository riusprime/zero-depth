extends GutTest
## v0.8.0 N3 (owner O45): the loading cover's phases (covered at once for a load, a portal's iris closing with the
## hero's way in and never opening on its own, the unveil after the loaded frame), each portal's palette, the corner
## mark only while covered, and reduced motion's plain fade. Presentation only: its own clock.

var _was_calm := false


func before_each() -> void:
	_was_calm = ViewPrefs.reduced_motion


func after_each() -> void:
	ViewPrefs.reduced_motion = _was_calm


func _cover() -> LoadingCover:
	var c := LoadingCover.new()
	add_child_autofree(c)
	return c


func test_a_load_covers_at_once_with_the_mark_and_unveils_after_the_loaded_frame() -> void:
	var c := _cover()
	assert_false(c.showing(), "hidden at first")
	assert_false(c.visible)
	c.cover_now()
	assert_true(c.is_covered())
	assert_true(c.visible)
	assert_true(c.mark.visible, "the loading mark in the corner")
	assert_eq(c.amount, 1.0)
	c.unveil(0.2)
	assert_false(c.mark.visible or c.is_covered(), "the mark goes with the load")
	c._process(0.05)
	assert_eq(c.amount, 1.0, "the loaded frame is drawn covered first")
	c._process(0.1)
	assert_almost_eq(c.amount, 0.5, 1e-4, "then it opens")
	c._process(0.2)
	assert_false(c.showing(), "and is gone")
	assert_false(c.visible)


func test_a_portals_iris_closes_with_the_way_in_and_holds() -> void:
	var c := _cover()
	c.set_closing(LoadingCover.Style.DEEP, 0.3)
	assert_eq(c.phase, LoadingCover.Phase.COVERING)
	assert_almost_eq(c.amount, 0.3, 1e-6)
	assert_false(c.mark.visible, "no mark while it closes")
	c.set_closing(LoadingCover.Style.DEEP, 0.1)
	assert_almost_eq(c.amount, 0.3, 1e-6, "it never opens on its own")
	c.set_closing(LoadingCover.Style.DEEP, 1.4)
	assert_true(c.is_covered(), "closed")
	assert_true(c.mark.visible, "the mark while the next floor loads")
	assert_eq(c.style, LoadingCover.Style.DEEP)


func test_each_portal_has_its_own_colours() -> void:
	var seen := {}
	for s: int in [
		LoadingCover.Style.BLACK,
		LoadingCover.Style.GATE,
		LoadingCover.Style.DEEP,
		LoadingCover.Style.ASCENSION,
		LoadingCover.Style.LOOP
	]:
		var p := LoadingCover.palette(s)
		assert_eq(p.size(), 3)
		assert_false(seen.has(p[1]), "style %d: its own main colour" % s)
		seen[p[1]] = true
	assert_eq(LoadingCover.palette(LoadingCover.Style.GATE)[1], PortalGate.visor_blue())
	assert_eq(LoadingCover.palette(LoadingCover.Style.DEEP)[1], PortalGate.DEEP_VIOLET)
	assert_eq(LoadingCover.palette(LoadingCover.Style.ASCENSION)[1], AscensionPortal.GOLD)
	assert_eq(LoadingCover.palette(LoadingCover.Style.LOOP)[1], LoopDevice.GREEN)


func test_reduced_motion_is_a_plain_fade() -> void:
	ViewPrefs.reduced_motion = true
	var c := _cover()
	c.set_closing(LoadingCover.Style.GATE, 0.5)
	assert_true(c.calm, "a plain fade")
	var m := c.fill.material as ShaderMaterial
	assert_eq(float(m.get_shader_parameter("calm")), 1.0)
	c._process(0.5)
	assert_eq(float(m.get_shader_parameter("spin")), 0.0, "nothing turns")
