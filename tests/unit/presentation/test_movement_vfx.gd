extends GutTest
## Dash and blink effects (PLAN v0.2.0 L12): every dash leaves a white trail that fades; a blink flashes blue
## light at both ends. The views read the sim through WorldReader only.


func _view() -> UtilityView:
	var v := UtilityView.new()
	add_child_autofree(v)
	return v


func test_every_dash_leaves_a_white_trail_that_fades() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var v := _view()
	v.sync(r)
	assert_eq(v.dash_trail.point_count(), 0, "no trail while walking")
	w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, InputFrame.DASH))
	assert_true(r.is_dashing())
	while r.is_dashing():
		v.sync(r)
		w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0))
	v.sync(r)
	assert_gt(
		v.dash_trail.point_count(), 3, "the path is recorded (the start and each dashing tick)"
	)
	assert_gt(v.dash_trail.ghost_count(), 0, "white afterimages of the silhouette")
	v.dash_trail._process(1.0 / 60.0)
	var mesh := v.dash_trail.ribbon.mesh as ImmediateMesh
	assert_gt(mesh.get_surface_count(), 0, "the ribbon is drawn")
	var mat := v.dash_trail.ribbon.material_override as StandardMaterial3D
	assert_true(mat.vertex_color_use_as_albedo, "white comes from the vertex colours")
	for i in 30:
		v.dash_trail._process(1.0 / 30.0)
	assert_eq(v.dash_trail.point_count(), 0, "faded within a second")
	assert_eq(v.dash_trail.ghost_count(), 0)
	assert_eq(mesh.get_surface_count(), 0)


func test_the_kinetic_dash_afterimages_draw_over_the_white_trail() -> void:
	var w := CombatLab.world()
	var tables := ContentCompiler.compile_items(ContentRepository.load_all())
	w.set_item_tables(tables)
	for k in tables.size():
		if tables[k].kind == WorldReader.ITEM_KINETIC_DASH:
			w.add_item(k)
	var kit := KitView.new()
	add_child_autofree(kit)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := ItemVisuals.new(kit, actors)
	add_child_autofree(fx)
	var v := _view()
	w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, InputFrame.DASH))
	var r := WorldReader.new(w)
	fx.sync(r)
	v.sync(r)
	assert_eq(fx.fx_count(), 1, "a cyan afterimage")
	var cyan := (fx.get_child(fx.get_child_count() - 1) as MeshInstance3D).material_override
	assert_gt(
		cyan.render_priority, v.dash_trail.ribbon.material_override.render_priority, "cyan on top"
	)


func test_blink_flashes_blue_at_both_ends() -> void:
	var w := CombatLab.world(PlayerTable.Utility.BLINK)
	var r := WorldReader.new(w)
	var v := _view()
	v.sync(r)
	assert_false(v.vanish.visible)
	var from := r.player_pos()
	w.step(InputFrame.make(Vector2i(127, 0), 0, 300, 0, InputFrame.UTILITY))
	v.sync(r)
	assert_true(v.vanish.is_playing() and v.appear.is_playing())
	assert_almost_eq(
		v.vanish.position, SimPlane.to_3d(from), Vector3.ONE * 1e-4, "where it vanished"
	)
	assert_almost_eq(
		v.appear.position, SimPlane.to_3d(r.player_pos()), Vector3.ONE * 1e-4, "where it appeared"
	)
	for f: BlinkFlash in [v.vanish, v.appear]:
		assert_true(f.visible)
		assert_gt(f.light.light_energy, 0.0, "a light flash")
		var c := f.light.light_color
		assert_true(c.b > c.g and c.b > c.r, "blue light")
		assert_eq(f.sparks.size(), BlinkFlash.SPARKS)
		assert_true((f.column.material_override as ShaderMaterial).shader.code.contains("ALPHA"))
	var energy := v.appear.light.light_energy
	v.appear._process(0.1)
	assert_lt(v.appear.light.light_energy, energy, "fades")
	for i in 20:
		v.vanish._process(1.0 / 30.0)
		v.appear._process(1.0 / 30.0)
	assert_false(v.vanish.visible or v.appear.visible, "gone within ~0.4 s")
	v.sync(r)
	assert_false(v.appear.visible, "the same blink doesn't flash twice")
