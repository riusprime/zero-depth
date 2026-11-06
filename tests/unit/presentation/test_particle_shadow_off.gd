extends GutTest
## v0.10.5 PB (owner, perf wave 2: "yes particles should not draw shadows"): no particle system under a floor's view
## casts a shadow, the pack's effects included, whether it was there when the view was built or joined it later.
## Particles outside the view are left alone.


func _particles(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	out.append_array(root.find_children("*", "GPUParticles3D", true, false))
	out.append_array(root.find_children("*", "CPUParticles3D", true, false))
	return out


func test_no_particle_in_a_built_floor_with_effects_running_casts_a_shadow() -> void:
	var w := CombatLab.world()
	w.step(InputFrame.new())
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	assert_not_null(v.pack_fx, "the pack's effects are part of the view")
	if v.pack_fx == null:
		return
	var spawned := 0
	for id: StringName in [&"explosion_fire_a", &"explosion_fire_b", &"fumes_cloud"]:
		if v.pack_fx.spawn(id, Vector3(spawned * 2.0, 0, 0)) != null:
			spawned += 1
	assert_eq(spawned, 3, "three pack effects running")
	for k in 20:
		w.step(InputFrame.new())
		v.sync()
		await wait_frames(1)
	var all := _particles(v)
	var running := 0
	var casting: Array[String] = []
	for n in all:
		if (n as GeometryInstance3D).is_visible_in_tree():
			running += 1
		if ParticleShadowOff.casts(n):
			casting.append(str(v.get_path_to(n)))
	gut.p("particle systems under the view: %d (shown: %d)" % [all.size(), running])
	assert_gt(running, 0, "some particle systems are shown")
	assert_eq(casting, [] as Array[String], "no particle system casts a shadow")


func test_a_particle_joining_later_is_turned_off_and_one_elsewhere_is_left() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var early := GPUParticles3D.new()
	early.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(early)
	root.add_child(ParticleShadowOff.new())
	var holder := Node3D.new()
	root.add_child(holder)
	var late := CPUParticles3D.new()
	late.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(late)
	var mesh := MeshInstance3D.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mesh)
	var elsewhere := GPUParticles3D.new()
	elsewhere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child_autofree(elsewhere)
	assert_false(ParticleShadowOff.casts(early), "there before the node: set as it enters")
	assert_false(ParticleShadowOff.casts(late), "joined after: set as it joins")
	assert_eq(
		mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "a mesh keeps its shadow"
	)
	assert_true(ParticleShadowOff.casts(elsewhere), "not under the view: left alone")


## Switch 8 (the cheaper sun): off by default; on, the sun's shadow covers the iso view's depth only.
func test_the_cheaper_sun_is_off_by_default_and_narrows_the_shadow_when_on() -> void:
	assert_false(bool(ProjectSettings.get_setting(RenderSwitches.CHEAP_SUN_SETTING, false)))
	var saved := RenderSwitches.cheap_sun
	RenderSwitches.cheap_sun = false
	var sun := DirectionalLight3D.new()
	RenderSwitches.apply_sun(sun)
	assert_eq(sun.directional_shadow_max_distance, RenderSwitches.SUN_MAX_M)
	assert_eq(RenderSwitches.camera_near(), RenderSwitches.CAMERA_NEAR_M)
	RenderSwitches.cheap_sun = true
	RenderSwitches.apply_sun(sun)
	assert_eq(sun.directional_shadow_max_distance, RenderSwitches.CHEAP_SUN_MAX_M)
	assert_eq(RenderSwitches.camera_near(), RenderSwitches.CHEAP_SUN_NEAR_M)
	RenderSwitches.cheap_sun = saved
	sun.free()
