extends GutTest
## v0.8.0 HV (owner O89: "if something is not going to be loaded when far make sure it is far enough so it does not
## happen in the screen it should be for outside of the screen"): ScreenCull reads the camera's own view, and the
## enemy models' animation, the status effects and the attack forms are skipped only when wholly out of the picture:
## at the screen's edge, and at the edge + their reach + the margin - 0.1 m, they still animate and draw. Also the
## unchanged glow writes ActorViews now skips (a tint or a flash already shown).

var _rig: IsoRig
var _cull: ScreenCull


func before_each() -> void:
	_rig = add_child_autofree(IsoRig.new())
	_rig.snap_to(Vector3(3.0, 0.0, -2.0))  # off the origin: the view is round the camera, wherever it is
	_cull = ScreenCull.new()
	_cull.refresh(_rig.camera)


## The ground point at the middle of the screen.
func _centre() -> Vector3:
	var t := _rig.camera.global_transform
	var fwd := -t.basis.z
	return t.origin + fwd * (-t.origin.y / fwd.y)


func _right() -> Vector3:
	return _rig.camera.global_transform.basis.x.normalized()


## The ground direction that goes up the screen.
func _up_ground() -> Vector3:
	var f := -_rig.camera.global_transform.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


## The ground point on the screen's right edge, level with the middle.
func _right_edge() -> Vector3:
	return _centre() + _right() * _cull.half_extents().x


func _top_edge() -> Vector3:
	var up := _cull.half_extents().y / sin(deg_to_rad(_rig.pitch_deg))
	return _centre() + _up_ground() * up


func test_the_view_is_the_cameras_own_rectangle() -> void:
	assert_true(_cull.active, "an orthographic camera in the tree")
	var vp := _rig.camera.get_viewport().get_visible_rect().size
	assert_almost_eq(_rig.camera.unproject_position(_right_edge()).x, vp.x, 1.0, "the right edge")
	assert_almost_eq(_rig.camera.unproject_position(_top_edge()).y, 0.0, 1.0, "the top edge")
	assert_almost_eq(_cull.gap(_right_edge()), 0.0, 0.01)
	assert_almost_eq(_cull.gap(_top_edge()), 0.0, 0.01)
	assert_lt(_cull.gap(_centre()), 0.0, "inside")


func test_at_the_edge_plus_reach_plus_margin_it_still_shows() -> void:
	var r := ScreenCull.AVATAR_RADIUS_M
	var m := ScreenCull.MARGIN_M
	for edge: Array in [[_right_edge(), _right()], [_top_edge(), _up_ground()]]:
		var e: Vector3 = edge[0]
		var out: Vector3 = edge[1]
		assert_true(_cull.shows(e, r), "on the edge")
		assert_true(
			_cull.shows(e + out * (r + m - 0.1), r), "edge + reach + margin - 0.1 m (ground)"
		)
		assert_true(_cull.keeps(e + out * (r + m - 0.1), r, false), "turning on there too")
	assert_false(_cull.shows(_right_edge() + _right() * (r + m + 0.1), r), "past it: skipped")
	var h := ScreenCull.HYSTERESIS_M
	var band := _right_edge() + _right() * (r + m + h - 0.1)
	assert_true(_cull.keeps(band, r, true), "on, it stays on through the hysteresis")
	assert_false(_cull.keeps(band, r, false), "off, it waits until it is nearer")
	var down := _top_edge() + _up_ground() * ((r + m + 0.1) / sin(deg_to_rad(_rig.pitch_deg)))
	assert_false(_cull.shows(down, r), "up the screen the ground is stretched: farther in metres")


func test_no_camera_shows_everything() -> void:
	var c := ScreenCull.new()
	c.refresh(null)
	assert_false(c.active)
	assert_true(c.shows(Vector3(900, 0, 900), 0.0))


func test_enemy_models_animate_until_wholly_off_screen() -> void:
	var w := CombatLab.world()
	var reader := WorldReader.new(w)
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.cull = _cull
	var r := ScreenCull.AVATAR_RADIUS_M
	var m := ScreenCull.MARGIN_M
	var edge := w.add_enemy(ActorStore.Kind.NEEDLE, SimPlane.to_sim(_right_edge()))
	var near := w.add_enemy(
		ActorStore.Kind.NEEDLE, SimPlane.to_sim(_right_edge() + _right() * (r + m - 0.1))
	)
	var far := w.add_enemy(
		ActorStore.Kind.NEEDLE, SimPlane.to_sim(_right_edge() + _right() * (r + m + 5.0))
	)
	views.sync(reader)
	var avatar := func(id: int) -> Node: return views.actor_node(id).get_meta(&"enemy_avatar")
	assert_true((avatar.call(edge) as Node).is_processing(), "on the screen's edge: animated")
	assert_true(
		(avatar.call(near) as Node).is_processing(), "edge + reach + margin - 0.1 m: animated"
	)
	assert_false((avatar.call(far) as Node).is_processing(), "wholly off screen: still")
	w.actors.set_pos(
		w.actors.index_of(far), SimPlane.to_sim(_right_edge() + _right() * (r + m - 0.5))
	)
	views.sync(reader)
	assert_true((avatar.call(far) as Node).is_processing(), "coming back: animated before it shows")


func test_status_effects_draw_until_wholly_off_screen() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	var reach := 0.35 + StatusVisuals.STATUS_REACH_M + ScreenCull.MARGIN_M
	w.add_dummy(SimPlane.to_sim(_right_edge()), 0.35, 500)
	w.add_dummy(SimPlane.to_sim(_right_edge() + _right() * (reach - 0.1)), 0.35, 500)
	w.add_dummy(SimPlane.to_sim(_right_edge() + _right() * (reach + 5.0)), 0.35, 500)
	var reader := WorldReader.new(w)
	var vfx: VfxLayer = add_child_autofree(VfxLayer.new())
	var actors: ActorViews = add_child_autofree(ActorViews.new())
	var fx: StatusVisuals = add_child_autofree(StatusVisuals.new(actors))
	fx.use_vfx(vfx)
	fx.cull = _cull
	actors.sync(reader)
	for i in range(1, 4):
		w.actors.burn_stacks[i] = 4
	fx.sync(reader)
	vfx.begin(10.0)
	vfx.finish()
	assert_eq(fx.statuses_drawn, 2, "on the edge and at edge + reach + margin - 0.1 m: drawn")
	assert_eq(fx.statuses_culled, 1, "wholly off screen: skipped")


func test_attack_forms_draw_until_wholly_off_screen() -> void:
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	view.set_process(false)
	view.cull = _cull
	var size := 0.5
	var reach := size + AttackFormCanvas.CULL_PAD_M + ScreenCull.MARGIN_M
	view.flash(SimPlane.to_sim(_right_edge()), Color.WHITE, size, 0.0)
	view.flash(SimPlane.to_sim(_right_edge() + _right() * (reach - 0.1)), Color.WHITE, size, 0.0)
	view.flash(SimPlane.to_sim(_right_edge() + _right() * (reach + 5.0)), Color.WHITE, size, 0.0)
	view.draw_at(1.0)
	assert_eq(
		view.pool(&"flash").used, 2, "on the edge and at edge + reach + margin - 0.1 m: drawn"
	)
	assert_eq(view.effect_count(), 3, "the skipped one is still alive, only not laid out")
	view.cull = null
	view.draw_at(1.0)
	assert_eq(view.pool(&"flash").used, 3, "without a camera every one draws")


func test_an_unchanged_tint_or_a_flash_already_lit_is_not_written_again() -> void:
	var w := CombatLab.world()
	var reader := WorldReader.new(w)
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(reader)
	var id := w.actors.ids[0]
	var mats: Array = views.actor_node(id).get_meta(&"mats")
	var m: StandardMaterial3D = mats[0]
	views.set_tint(id, Color.ORANGE, 0.55)
	assert_almost_eq(m.emission_energy_multiplier, 0.55, 1e-6, "the tint is written")
	m.emission_energy_multiplier = 9.0  # a marker: a write would change it
	views.set_tint(id, Color.ORANGE, 0.55)
	assert_eq(m.emission_energy_multiplier, 9.0, "the same tint: not written again")
	views.set_tint(id, Color.ORANGE, 0.7)
	assert_almost_eq(m.emission_energy_multiplier, 0.7, 1e-6, "a new tint is written")
	views.flash(id)
	assert_almost_eq(m.emission_energy_multiplier, 1.6, 1e-6, "the flash lights it")
	m.emission_energy_multiplier = 9.0
	views.flash(id, 7)
	assert_eq(m.emission_energy_multiplier, 9.0, "already lit: not written again")
	assert_eq(views._flash[id], 7, "only its frames grow")
	views.set_tint(id, Color.BLACK, 0.0)
	assert_eq(m.emission_energy_multiplier, 9.0, "a tint under a flash waits for the flash to end")
