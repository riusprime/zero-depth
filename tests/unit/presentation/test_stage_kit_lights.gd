extends GutTest
## v0.8.0 P3: StageKit's fire-prop lights fade instead of switching (owner O30): a light out of the view's reach
## fades out and hides, and back in on the way in; a light joining or leaving the shadow-casting few fades its shadow
## (shadow_opacity) instead of switching it. The decoration is drawn in chunks of the floor (owner O29), the same
## pieces at the same places.

var _cam: Camera3D


func before_each() -> void:
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 17.0
	add_child_autofree(_cam)
	_look_at(Vector3.ZERO)
	_cam.make_current()


## The camera looking straight down at `p` (its focus on the ground is p).
func _look_at(p: Vector3) -> void:
	_cam.global_transform = Transform3D(
		Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), p + Vector3(0, 30, 0)
	)


func _light(at: Vector3) -> Dictionary:
	return {
		"piece": &"fire_barrel", "xform": Transform3D(Basis(), at), "wall": -1, "kind": &"light"
	}


func _kit(placements: Array) -> StageKit:
	var kit := StageKit.new()
	kit.build(placements, 0, Color.GRAY, BiomeMood.new())
	add_child_autofree(kit)
	kit.set_process(false)  # stepped by hand
	return kit


func _run(kit: StageKit, frames: int) -> void:
	for k in frames:
		kit._process(1.0 / 60.0)


## Steps `kit` through the next shadow re-pick (v0.8.0 Step FS: every SHADOW_PICK_EVERY frames).
func _run_to_shadow_pick(kit: StageKit) -> void:
	_run(kit, 1)
	while kit._frame % StageKit.SHADOW_PICK_EVERY != 1:
		_run(kit, 1)


func test_a_far_light_fades_out_and_back_in() -> void:
	if KitModels.get_piece(&"fire_barrel").is_empty():
		pass_test("no kit in this checkout")
		return
	var kit := _kit([_light(Vector3(2, 0, 0)), _light(Vector3(200, 0, 0))])
	assert_eq(kit.lights.size(), 2)
	_run(kit, 2)
	var near := kit.lights[0]
	var far := kit.lights[1]
	var e1 := far.light_energy
	_run(kit, 6)
	assert_lt(far.light_energy, e1, "the far light dims over frames, not at once")
	assert_true(far.visible, "still on while it fades")
	_run(kit, 40)
	assert_false(far.visible, "hidden once faded out")
	assert_true(near.visible, "the near light stays")
	_look_at(Vector3(200, 0, 0))
	_run(kit, 16)  # the next pick
	assert_true(far.visible, "it comes back on the way in")
	var e2 := far.light_energy
	_run(kit, 30)
	assert_gt(far.light_energy, e2, "and brightens over frames")


func test_shadows_fade_in_and_out_instead_of_switching() -> void:
	if KitModels.get_piece(&"fire_barrel").is_empty():
		pass_test("no kit in this checkout")
		return
	var placements: Array = []
	for k in StageKit.SHADOW_LIGHTS + 1:
		placements.append(_light(Vector3(k * 3.0, 0, 0)))
	var kit := _kit(placements)
	kit.set_shadows(true)
	_run(kit, 2)
	var first := kit.lights[0]
	assert_true(first.shadow_enabled, "the nearest light casts a shadow")
	assert_lt(first.shadow_opacity, 0.5, "faded in, not switched on")
	_run(kit, 40)
	assert_almost_eq(first.shadow_opacity, 1.0, 0.001, "fully in after the fade")
	var last := kit.lights[StageKit.SHADOW_LIGHTS]
	assert_false(last.shadow_enabled, "only SHADOW_LIGHTS cast shadows")
	_look_at(Vector3(StageKit.SHADOW_LIGHTS * 3.0 + 3.0, 0, 0))  # the focus moves past the last light
	_run(kit, 16)
	assert_true(first.shadow_enabled, "no swap before the shadow re-pick (Step FS: a stable set)")
	assert_almost_eq(first.shadow_opacity, 1.0, 0.001, "still fully in")
	_run_to_shadow_pick(kit)
	assert_true(first.shadow_enabled, "the light leaving the few still has its shadow, fading")
	assert_lt(first.shadow_opacity, 1.0)
	assert_false(last.shadow_enabled, "the light joining waits for the leaving one's slot")
	var most := 0
	for f in 40:
		_run(kit, 1)
		var on := 0
		for l in kit.lights:
			on += 1 if l.shadow_enabled else 0
		most = maxi(most, on)
	assert_false(first.shadow_enabled, "off once faded out")
	assert_true(last.shadow_enabled, "then the joining light fades in")
	assert_lt(last.shadow_opacity, 1.0, "still fading in")
	assert_lte(most, StageKit.SHADOW_LIGHTS, "never more than the budget cast at once")
	_run(kit, 40)
	assert_almost_eq(last.shadow_opacity, 1.0, 0.001, "fully in")


func test_a_caster_keeps_its_shadow_until_a_challenger_is_meaningfully_nearer() -> void:
	if KitModels.get_piece(&"fire_barrel").is_empty():
		pass_test("no kit in this checkout")
		return
	var placements: Array = []
	for k in StageKit.SHADOW_LIGHTS:
		placements.append(_light(Vector3(k, 0, 0)))
	placements.append(_light(Vector3(-StageKit.SHADOW_LIGHTS, 0, 0)))  # the challenger
	var kit := _kit(placements)
	kit.set_shadows(true)
	_run(kit, 40)
	var keeper := kit.lights[StageKit.SHADOW_LIGHTS - 1]
	var challenger := kit.lights[StageKit.SHADOW_LIGHTS]
	assert_true(keeper.shadow_enabled)
	assert_false(challenger.shadow_enabled)
	_look_at(Vector3(-0.6, 0, 0))  # the challenger is now a little nearer than the keeper
	_run_to_shadow_pick(kit)
	_run(kit, 40)
	assert_true(keeper.shadow_enabled, "a little nearer is not enough to swap")
	assert_false(challenger.shadow_enabled)
	_look_at(Vector3(-6, 0, 0))  # now much nearer
	_run_to_shadow_pick(kit)
	_run(kit, 80)
	assert_false(keeper.shadow_enabled, "the keeper hands its shadow over")
	assert_true(challenger.shadow_enabled, "to the much nearer light")


func test_decoration_is_chunked_with_every_piece_kept() -> void:
	var placements: Array = []
	for k in 30:
		var at := Vector3(k * 1.7 - 25.0, 0, (k % 5) * 4.0 - 10.0)
		placements.append(
			{
				"piece": &"snow_drift",
				"xform": Transform3D(Basis(), at),
				"wall": -1,
				"kind": &"decor"
			}
		)
	var kit := _kit(placements)
	var group := kit.get_node_or_null("Decor_snow_drift")
	assert_not_null(group, "the piece kind's node, as before")
	assert_gt(group.get_child_count(), 1, "in more than one chunk")
	var seen := 0
	for c in group.get_children():
		var mm := (c as MultiMeshInstance3D).multimesh
		var aabb := AABB()
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			aabb = AABB(o, Vector3.ZERO) if i == 0 else aabb.expand(o)
		assert_lte(aabb.size.x, StageKit.DECOR_CHUNK_M, "a chunk spans at most one cell")
		assert_lte(aabb.size.z, StageKit.DECOR_CHUNK_M)
		seen += mm.instance_count
	assert_eq(seen, 30, "every piece drawn once")
	assert_eq(kit.decor_nodes, group.get_child_count())


## v0.8.0 HR (O89; RenderSwitches): the torches' shadows are dual-paraboloid, and the small floor scatter casts none
## (a tall piece keeps its shadow).
func test_torches_use_dual_paraboloid_shadows_under_the_switch() -> void:
	if KitModels.get_piece(&"fire_barrel").is_empty():
		pass_test("no kit in this checkout")
		return
	var kit := _kit([_light(Vector3(2, 0, 0))])
	var want := (
		OmniLight3D.SHADOW_DUAL_PARABOLOID
		if RenderSwitches.TORCH_DUAL_PARABOLOID
		else OmniLight3D.SHADOW_CUBE
	)
	assert_eq(kit.lights[0].omni_shadow_mode, want)


func test_small_scatter_casts_no_shadow_under_the_switch() -> void:
	var low := Transform3D(Basis.from_scale(Vector3(0.9, 0.28, 0.6)), Vector3(1, 0, 1))
	var tall := Transform3D(Basis.from_scale(Vector3(0.9, 0.9, 0.6)), Vector3(40, 0, 40))
	var placements: Array = []
	for xf: Transform3D in [low, tall]:
		placements.append({"piece": &"snow_drift", "xform": xf, "wall": -1, "kind": &"decor"})
	var kit := _kit(placements)
	var group := kit.get_node_or_null("Decor_snow_drift")
	assert_eq(group.get_child_count(), 2, "two chunks")
	for c in group.get_children():
		var mmi := c as MultiMeshInstance3D
		var small := mmi.multimesh.get_instance_transform(0).basis.y.length() < 0.6
		var off := RenderSwitches.SCATTER_NO_SHADOW and small
		assert_eq(
			mmi.cast_shadow,
			(
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if off
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			),
			"%s: a small piece casts none" % mmi.name
		)
