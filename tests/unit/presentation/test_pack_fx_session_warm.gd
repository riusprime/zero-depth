extends GutTest
## v0.10.0 VX-W: the pack's warm-up once a session at the main menu (PackFxSessionWarm): one id every few frames, in an
## off-screen viewport, from scenes the loader threads read; a floor load then only warms what is left.


func before_each() -> void:
	PackFx._warmed.clear()


func after_each() -> void:
	PackFx._warmed.clear()


func test_it_is_not_wanted_without_a_renderer() -> void:
	assert_eq(PackFxSessionWarm.wanted(), DisplayServer.get_name() != "headless")


func test_it_warms_the_table_one_id_at_a_time() -> void:
	var w := PackFxSessionWarm.new()
	add_child_autofree(w)
	var all := w.fx.warm_ids().size()
	assert_gte(all, 4)
	assert_false(PackFx.is_warmed(w.fx.warm_ids()[0]))
	var n := 0
	for k in 600:  # the scenes load on a thread first; a busy machine takes longer
		await wait_frames(1)
		n = 0
		for id in w.fx.warm_ids():
			n += 1 if PackFx.is_warmed(id) else 0
		if n > 0:
			break
	assert_gt(n, 0, "some ids are warmed")
	assert_lt(n, all, "one id every STEP_FRAMES, not all at once")
	assert_false(w.done())


func test_a_scene_kept_for_the_session_is_the_same_resource() -> void:
	PackFx.request_scenes()
	var fx := PackFx.new()
	add_child_autofree(fx)
	var id := fx.warm_ids()[0]
	for i in 600:
		if PackFx.scenes_ready(id):
			break
		await wait_frames(1)
	assert_true(PackFx.scenes_ready(id))
	assert_not_null(fx.spawn(id, Vector3.ZERO))
	var def := PackFx.shared_def()
	var path: String = def.scenes[def.row(id)]
	assert_same(PackFx._scene(path), PackFx._scene(path), "read once")
