extends GutTest
## v0.8.0 HR (owner O89: no fps drops "during the fun part of the game"): the floor's effect, attack and enemy shaders
## are drawn once, tiny, behind the loading cover (ShaderWarmup): the view's hidden pool pieces, the first-use
## materials and one enemy of each horde kind, then the warm-up goes. And the MSAA switch touches the game's window
## only (RenderSwitches).


func _view() -> Array:
	var root := Node3D.new()
	add_child_autofree(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var quad := QuadMesh.new()
	var hidden := MeshInstance3D.new()  # a pool slot waiting for its first use
	hidden.mesh = quad
	hidden.material_override = StandardMaterial3D.new()
	hidden.visible = false
	root.add_child(hidden)
	var shown := MeshInstance3D.new()  # drawn already: no proxy
	shown.mesh = quad
	root.add_child(shown)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 8
	mm.visible_instance_count = 0  # an effects pool showing nothing yet
	var pool := MultiMeshInstance3D.new()
	pool.multimesh = mm
	pool.material_override = StandardMaterial3D.new()
	root.add_child(pool)
	var actors := ActorViews.new()
	root.add_child(actors)
	return [root, cam, actors]


func test_the_warmup_draws_hidden_pieces_first_use_materials_and_each_horde_kind() -> void:
	if not RenderSwitches.SHADER_WARMUP:
		pass_test("switched off")
		return
	var v := _view()
	var w := ShaderWarmup.build(v[0], v[1], v[2])
	assert_not_null(w)
	autofree(w)
	assert_eq(w.hidden_proxies, 2, "the hidden slot and the empty pool, not the drawn mesh")
	assert_gt(w.lazy_proxies, 5, "the hero pulse, fireball and boss strike shaders at least")
	assert_eq(w.enemies, ShaderWarmup.HORDE_KINDS.size() + 2, "and a Charger and a Hatchling")
	assert_lt(w.global_transform.basis.get_scale().x, 0.01, "well under a pixel")
	for c in w.get_children():
		if c is GeometryInstance3D:
			assert_eq(
				(c as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)


func test_the_warmup_goes_after_a_few_frames_with_its_camera() -> void:
	if not RenderSwitches.SHADER_WARMUP:
		pass_test("switched off")
		return
	var v := _view()
	var w := ShaderWarmup.build(v[0], v[1], v[2])
	for k in ShaderWarmup.FRAMES:
		w._process(1.0 / 60.0)
	assert_false(w.is_queued_for_deletion(), "still drawing")
	w._process(1.0 / 60.0)
	assert_true(w.is_queued_for_deletion(), "gone after its frames")


func test_the_msaa_switch_leaves_a_tools_own_viewport_alone() -> void:
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	add_child_autofree(vp)
	RenderSwitches.apply_viewport(vp)
	assert_eq(vp.msaa_3d, Viewport.MSAA_4X, "a tool's SubViewport keeps its MSAA")
	var before := get_tree().root.msaa_3d
	RenderSwitches.apply_viewport(get_tree().root)
	var want := Viewport.MSAA_DISABLED if RenderSwitches.MSAA_OFF else RenderSwitches.OLD_MSAA
	assert_eq(get_tree().root.msaa_3d, want, "the game's window")
	get_tree().root.msaa_3d = before
