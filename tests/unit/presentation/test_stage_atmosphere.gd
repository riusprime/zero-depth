extends GutTest
## v0.8.0 GX (owner O86, graphics feedback §1, §3, §5): the floor's air on the "high" lighting tier. StageAtmosphere
## puts one bounded ember emitter on each light prop (hidden with its light, frozen under reduced motion), one dust
## emitter and a fog layer; off, it hides and stops emitting. Owner crystal models glint at load.

var _calm := false


func before_each() -> void:
	_calm = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.reduced_motion = _calm


func _atmosphere(lights: Array[OmniLight3D], on := true) -> StageAtmosphere:
	var mood: BiomeMood = ContentRepository.load_all().get_def(&"biomes", &"ruins").mood
	var root := Node3D.new()
	add_child_autofree(root)
	for l in lights:
		root.add_child(l)
	var a := StageAtmosphere.new()
	a.enabled = on
	root.add_child(a)
	a.setup(mood, lights)
	return a


func _lights(n: int) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for k in n:
		var l := OmniLight3D.new()
		l.position = Vector3(k * 6.0, 1.2, 0)
		out.append(l)
	return out


func test_each_light_prop_gets_a_bounded_ember_emitter_and_the_view_one_dust() -> void:
	var lights := _lights(3)
	var a := _atmosphere(lights)
	assert_eq(a.embers.size(), 3, "one emitter per light prop")
	for k in 3:
		assert_eq(a.embers[k].get_parent(), lights[k], "parented to its light (hides with it)")
		assert_eq(a.embers[k].amount, StageAtmosphere.EMBERS_PER_LIGHT)
		assert_true(a.embers[k].emitting)
	assert_eq(a.dust.amount, StageAtmosphere.DUST_COUNT)
	assert_true(a.dust.emitting)
	assert_not_null(a.fog_layer.material, "the fog layer has its material")
	var mood: BiomeMood = ContentRepository.load_all().get_def(&"biomes", &"ruins").mood
	assert_almost_eq(lights[0].light_volumetric_fog_energy, mood.volumetric_light_energy, 0.0001)


func test_off_hides_everything_and_a_hidden_light_stops_its_embers() -> void:
	var lights := _lights(2)
	var a := _atmosphere(lights)
	lights[1].visible = false  # StageKit hides a light out of the view's reach
	a._sync()
	assert_true(a.embers[0].emitting)
	assert_false(a.embers[1].emitting, "no embers round a hidden light")
	a.set_enabled(false)
	assert_false(a.visible)
	assert_false(a.embers[0].emitting or a.dust.emitting, "off: nothing emits")
	a.set_enabled(true)
	assert_true(a.embers[0].emitting and a.dust.emitting)


func test_reduced_motion_freezes_the_motes() -> void:
	var a := _atmosphere(_lights(1))
	ViewPrefs.reduced_motion = true
	a._sync()
	assert_almost_eq(a.embers[0].speed_scale, 0.0, 0.0001)
	assert_almost_eq(a.dust.speed_scale, 0.0, 0.0001)
	ViewPrefs.reduced_motion = false
	a._sync()
	assert_almost_eq(a.dust.speed_scale, 1.0, 0.0001)


func test_owner_crystal_materials_glint_and_the_original_is_untouched() -> void:
	var src := StandardMaterial3D.new()
	src.roughness = 1.0
	var g := KitModels.glossed(src, 0.25, 0.2) as StandardMaterial3D
	assert_almost_eq(g.roughness, 0.25, 0.0001)
	assert_almost_eq(g.metallic, 0.2, 0.0001)
	assert_almost_eq(src.roughness, 1.0, 0.0001, "a copy: the cached original stays")
	var shader := ShaderMaterial.new()
	assert_eq(KitModels.glossed(shader, 0.25, 0.2), shader, "a shader material is left as it is")
