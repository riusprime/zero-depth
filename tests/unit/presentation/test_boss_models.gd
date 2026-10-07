extends GutTest
## The owner's boss models (PLAN v0.3.0 L13): installed, each boss avatar uses its model (one mesh, turned so +X is
## its front, at the boss's height, feet on the ground), with a flashable outlined material, a glow overlay and an
## X-ray twin; models are read once per type; without the file the code-built body draws.

const DT := 1.0 / 60.0

var classes := {
	&"stone_sentinel": GatekeeperAvatar,
	&"crawler_queen": BroodMotherAvatar,
	&"fortress_turret": SiegeEngineAvatar,
}


func after_each() -> void:
	BossModels.dir = BossModels.DIR


func _avatar(cls: Variant, technique: StringName = &"xray") -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"), technique)
	add_child_autofree(a)
	a.set_process(false)
	return a


func test_each_boss_uses_its_installed_model() -> void:
	for id: StringName in classes:
		var a := _avatar(classes[id])
		assert_eq(a.model_id(), id)
		assert_not_null(a.imported, "%s draws the owner's model" % id)
		var box: AABB = a.imported.mesh.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.01, "%s stands on the ground" % id)
		assert_almost_eq(box.size.y, BossModels.SPECS[id]["height"], 0.01, "%s at its height" % id)
		assert_eq(
			a.find_children("*", "MeshInstance3D", true, false).size(),
			2,
			"the mesh and its X-ray twin"
		)


func test_the_model_material_is_flashable_outlined_and_keeps_its_texture() -> void:
	for id: StringName in classes:
		var a := _avatar(classes[id])
		assert_eq(a.body_materials.size(), 1)
		var m := a.body_materials[0]
		assert_same(a.imported.material_override, m)
		assert_true(m.emission_enabled, "flashable: emission on")
		assert_eq(m.emission_energy_multiplier, 0.0, "dark until hit")
		assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE)
		assert_not_null(m.albedo_texture, "%s keeps its albedo texture" % id)
		assert_eq(a.imported.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		var o := _avatar(classes[id], &"outline")
		assert_eq(
			o.find_children("*", "MeshInstance3D", true, false).size(), 1, "no twin without xray"
		)


func test_whole_body_motion_and_glow_change_no_shader() -> void:
	var a := _avatar(GatekeeperAvatar)
	var before := DamageFlashKeys.of(a)
	var rest := a.pivot.transform
	for t in 40:
		a.apply_state(
			{
				"tick": t + 1,
				"pos": Vector2.ZERO,
				"state": WorldReader.STATE_WINDUP,
				"move": WorldReader.MOVE_SLAM_RING,
				"windup": float(t) / 40.0
			}
		)
		a.advance(DT)
	assert_gt(a.glow_amount(), 0.12, "the windup glows")
	assert_ne(a.pivot.transform, rest, "and leans")
	a.apply_state({"tick": 41, "pos": Vector2.ZERO, "state": WorldReader.STATE_ACTIVE, "move": 0})
	a.advance(DT)
	assert_gt(a.pivot.position.x, 0.1, "the slam lunges forward")
	assert_eq(DamageFlashKeys.of(a), before, "no shader changed")
	var s := _avatar(SiegeEngineAvatar)
	s.apply_state({"tick": 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_WINDUP, "move": 9})
	s.advance(DT)
	s.apply_state({"tick": 2, "pos": Vector2.ZERO, "state": WorldReader.STATE_ACTIVE, "move": 9})
	s.advance(DT)
	assert_lt(s.pivot.position.x, -0.1, "the turret kicks back")


func test_phase_two_glows_steadily() -> void:
	var a := _avatar(BroodMotherAvatar)
	for t in 90:
		a.apply_state(
			{"tick": t + 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE, "phase": 1}
		)
		a.advance(DT)
	assert_gt(a.glow_amount(), 0.04)


func test_models_are_read_once_per_type() -> void:
	BossModels.preload_all()
	var n := BossModels.loaded_count()
	assert_eq(n, 3)
	var m1 := BossModels.get_model(&"stone_sentinel")
	_avatar(GatekeeperAvatar)
	_avatar(GatekeeperAvatar)
	assert_same(BossModels.get_model(&"stone_sentinel")["mesh"], m1["mesh"], "cached, shared")
	assert_eq(BossModels.loaded_count(), n)


func test_without_the_file_the_code_body_draws() -> void:
	BossModels.dir = "res://tests/no_such_models/"
	var a := _avatar(GatekeeperAvatar) as GatekeeperAvatar
	assert_null(a.imported)
	assert_gt(a.body_materials.size(), 15, "the code-built pieces")
	assert_eq(a.fists.size(), 2)
