extends GutTest
## v0.6.0 MX3 (MODIFIER_ENGINE §4): the eight forms drawn from a spec (the right pool, count and scale, a halo of 12
## shots as 12 darts evenly round), the layers' materials, the per-frame budget and the Effects density option.
## Looks (elements, heat, cues) and the live wiring: test_attack_form_looks.gd.

const AT := Vector2(2, 3)

var _view: AttackFormView


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())


func _spec(form: int, extra: Dictionary = {}) -> Dictionary:
	var s := {"form": form, "elements": PackedStringArray(["ember"])}
	s.merge(extra, true)
	return s


func _used(id: StringName) -> int:
	return _view.pool(id).used


## The flat (XZ) length of an instance's local X axis: its drawn radius or length.
func _sx(id: StringName, i: int = 0) -> float:
	return _view.pool(id).instance_transform(i).basis.x.length()


func _origin(id: StringName, i: int) -> Vector2:
	return SimPlane.to_sim(_view.pool(id).instance_transform(i).origin)


func test_the_form_numbers_are_the_sims() -> void:
	assert_eq(
		[
			AttackFormLooks.ARC,
			AttackFormLooks.BOLT,
			AttackFormLooks.RING,
			AttackFormLooks.BEAM,
			AttackFormLooks.ZONE,
			AttackFormLooks.ORBITER,
			AttackFormLooks.LOB,
			AttackFormLooks.BURST,
		],
		[
			WorldReader.FORM_ARC,
			WorldReader.FORM_BOLT,
			WorldReader.FORM_RING,
			WorldReader.FORM_BEAM,
			WorldReader.FORM_ZONE,
			WorldReader.FORM_ORBITER,
			WorldReader.FORM_LOB,
			WorldReader.FORM_BURST,
		]
	)
	assert_eq(AttackFormView.TRIGGER_ON_HIT, AttackSpec.Trigger.ON_HIT)
	assert_eq(AttackFormView.TRIGGER_ON_NTH, AttackSpec.Trigger.ON_NTH)


func test_every_layer_is_light_or_lit_matter() -> void:
	for id: StringName in _view.pools:
		var m := _view.pool(id).material_override as StandardMaterial3D
		if id == &"lob_body":
			assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL, "the bomb is lit")
			continue
		assert_eq(m.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "%s is additive light" % id)
		assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
		assert_true(m.vertex_color_use_as_albedo, "%s: per-instance colour" % id)
	assert_eq(
		_view.pool(&"arc_core").multimesh.mesh, AttackFormMeshes.mesh(&"quad"), "pools share meshes"
	)


func test_arc_sweeps_its_segments_on_the_pattern() -> void:
	var e := _view.spawn(
		_spec(WorldReader.FORM_ARC, {"half_arc": 1024, "reach_m": 2.0}), AT, 0.0, {"start": 0}
	)
	_view.draw_at(float(e["life"]) * 0.5)
	assert_eq(_used(&"arc_core"), AttackFormView.ARC_SEGMENTS, "the whole arc is drawn once swept")
	assert_eq(_used(&"arc_edge"), AttackFormView.ARC_SEGMENTS)
	var tip_r := (_origin(&"arc_edge", 0) - AT).length()
	assert_almost_eq(
		tip_r, AttackFormView.PLAYER_RADIUS + 2.0 - 0.08, 0.02, "the edge sits at the reach"
	)
	_view.clear()
	_view.spawn(
		_spec(WorldReader.FORM_ARC, {"count": 3, "directions": "circle"}), AT, 0.0, {"start": 0}
	)
	_view.draw_at(6.0)
	assert_eq(_used(&"arc_core"), 3 * AttackFormView.ARC_SEGMENTS, "three arcs round the hero")


func test_a_halo_of_twelve_shots_looks_like_a_halo() -> void:
	var spec := _spec(WorldReader.FORM_BOLT, {"count": 12, "directions": "circle", "speed": 0.25})
	_view.spawn(spec, AT, 0.0, {"start": 0})
	_view.draw_at(10.0)
	assert_eq(_used(&"bolt_core"), 12, "12 darts")
	var dist := (_origin(&"bolt_core", 0) - AT).length()
	for k in 12:
		var d := _origin(&"bolt_core", k) - AT
		assert_almost_eq(d.length(), dist, 0.001, "all at the same distance")
		assert_almost_eq(wrapf(d.angle() - TAU * k / 12.0, -PI, PI), 0.0, 0.001, "evenly round")
	assert_gt(_used(&"bolt_edge"), 0, "each leaves a tail")


func test_a_fan_spreads_over_its_spread() -> void:
	var spec := _spec(WorldReader.FORM_BOLT, {"count": 3, "spread": 512})
	var look := AttackFormLooks.compose(spec)
	var want := [-TAU / 16.0, 0.0, TAU / 16.0]
	assert_eq(look["angles"].size(), 3)
	for k in 3:
		assert_almost_eq(look["angles"][k], want[k], 0.0001)
	var back := AttackFormLooks.angles_of({"count": 1, "directions": AttackFormLooks.DIR_BACK})
	assert_eq(back.size(), 2, "back adds the mirror")
	assert_almost_eq(absf(back[1]), PI, 0.0001)


func test_a_faster_bolt_is_a_longer_dart() -> void:
	var slow := AttackFormLooks.compose(_spec(WorldReader.FORM_BOLT, {"speed": 0.2}))
	var fast := AttackFormLooks.compose(_spec(WorldReader.FORM_BOLT, {"speed": 0.6}))
	assert_gt(fast["length"], slow["length"])


func test_ring_expands_to_its_radius() -> void:
	var e := _view.spawn(_spec(WorldReader.FORM_RING, {"radius_m": 3.0}), AT, 0.0, {"start": 0})
	_view.draw_at(float(e["life"]) * 0.5)
	assert_lt(_sx(&"ring_fill"), 3.0, "still growing")
	_view.draw_at(float(e["life"]))
	assert_almost_eq(_sx(&"ring_fill"), 3.0, 0.001, "at its radius at the end")
	assert_eq(_used(&"ring_front"), 1, "a raised front")
	_view.clear()
	_view.spawn(_spec(WorldReader.FORM_RING, {"count": 3}), AT, 0.0, {"start": 0})
	_view.draw_at(9.0)
	assert_eq(_used(&"ring_fill"), 3, "three staggered rings")


func test_beam_runs_to_its_end() -> void:
	_view.spawn(_spec(WorldReader.FORM_BEAM), AT, 0.0, {"start": 0, "to": AT + Vector2(0, 5)})
	_view.draw_at(1.0)
	assert_almost_eq(_sx(&"beam_core"), 5.0, 0.001, "from the origin to the enemy hit")
	assert_almost_eq(_origin(&"beam_core", 0), AT + Vector2(0, 2.5), Vector2.ONE * 0.001)
	assert_gt(
		_view.pool(&"beam_edge").instance_transform(0).basis.z.length(),
		_view.pool(&"beam_core").instance_transform(0).basis.z.length(),
		"a wider edge glow"
	)


func test_zone_lingers_for_its_life() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, {"radius_m": 2.0, "life_ticks": 120}), AT, 0.0, {"start": 0}
	)
	_view.draw_at(60.0)
	assert_almost_eq(_sx(&"zone_fill"), 2.0, 0.001)
	assert_eq(_used(&"zone_rim"), 1)
	_view.draw_at(130.0)
	assert_eq(_used(&"zone_fill"), 0, "gone after its life")
	assert_eq(_view.effect_count(), 0)


func test_orbiters_circle_the_hero() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ORBITER, {"count": 5, "reach_m": 1.5}), AT, 0.0, {"start": 0}
	)
	_view.draw_at(30.0)
	assert_eq(_used(&"orbiter_core"), 5)
	for k in 5:
		assert_almost_eq((_origin(&"orbiter_core", k) - AT).length(), 1.5, 0.001)


func test_lob_arcs_over_its_ground_circle_then_lands() -> void:
	var e := _view.spawn(
		_spec(WorldReader.FORM_LOB, {"reach_m": 5.0, "radius_m": 1.8}), AT, 0.0, {"start": 0}
	)
	var flight := float(e["life"]) * 0.75
	_view.draw_at(flight * 0.5)
	assert_eq(_used(&"lob_body"), 1)
	assert_gt(
		_view.pool(&"lob_body").instance_transform(0).origin.y,
		AttackFormView.BODY_H + 1.0,
		"high mid-arc"
	)
	assert_almost_eq(_sx(&"lob_ground"), 1.8, 0.001, "the ground circle is the blast")
	assert_almost_eq(_origin(&"lob_ground", 0), AT + Vector2(5, 0), Vector2.ONE * 0.001)
	_view.draw_at(flight + 2.0)
	assert_eq(_used(&"lob_body"), 0, "landed")
	assert_eq(_used(&"burst_fill"), 1, "the landing flash")


func test_burst_flashes_at_its_radius() -> void:
	_view.spawn(_spec(WorldReader.FORM_BURST, {"radius_m": 2.5}), AT, 0.0, {"start": 0})
	_view.draw_at(3.0)
	assert_almost_eq(_sx(&"burst_rim"), 2.5, 0.001)
	assert_eq(_used(&"burst_fill"), 1)
	assert_eq(_used(&"burst_front"), 1)


func test_the_budget_caps_meshes_and_particles() -> void:
	var halo := _spec(
		1, {"count": 12, "directions": "circle", "elements": PackedStringArray(["ember", "storm"])}
	)
	var burst := _spec(7, {"count": 4})
	for k in 120:
		_view.spawn(halo, AT, 0.0, {"start": 0})
		_view.spawn(burst, AT, 0.0, {"start": 0})
	_view.draw_at(10.0)
	assert_eq(_view.meshes_drawn(), _view.mesh_cap(), "capped (more asked than any one pool holds)")
	var sum := 0
	for id: StringName in _view.pools:
		sum += _used(id)
	assert_eq(sum, _view.mesh_cap(), "the pools hold exactly the cap")
	assert_lte(_view.mesh_cap(), AttackFormView.MAX_ATTACK_MESHES)
	assert_lte(_view.particles_drawn(), _view.particle_cap())
	assert_eq(_view.particles_drawn(), _view.particle_cap(), "particles capped too")
	for k in 100:
		_view.spawn(halo, AT, 0.0, {"start": 0})
	assert_eq(_view.effect_count(), AttackFormView.MAX_EFFECTS, "the oldest effects drop")


func test_effects_density_lowers_particles_and_the_cap() -> void:
	var spec := _spec(7, {"elements": PackedStringArray(["ember"])})
	var drawn := {}
	for d in AttackFormView.DENSITIES:
		_view.clear()
		_view.set_density(d)
		_view.spawn(spec, AT, 0.0, {"start": 0})
		_view.draw_at(3.0)
		drawn[d] = _view.particles_drawn()
		assert_eq(_used(&"burst_fill"), 1, "%s still draws the form" % d)
	assert_lt(drawn["low"], drawn["medium"])
	assert_lt(drawn["medium"], drawn["high"])
	_view.set_density("low")
	assert_lt(_view.mesh_cap(), AttackFormView.MAX_ATTACK_MESHES)
	_view.set_density("nonsense")
	assert_eq(_view.density, "high", "an unknown value falls back")


func test_the_density_option_is_saved_and_applied() -> void:
	var profile := ProfileStore.new("")
	assert_eq(
		GameSettings.get_value(profile, "effects_density"),
		"high",
		"the shipped look is the default"
	)
	var menu: OptionsMenu = add_child_autofree(OptionsMenu.new(profile))
	var row := menu.find_child("effects_density", true, false) as OptionCycler
	assert_not_null(row, "Options > Display has the row")
	GameSettings.set_value(profile, "effects_density", "low")
	ViewPrefs.apply_settings(profile)
	assert_eq(ViewPrefs.effects_density, "low")
	ViewPrefs.effects_density = "high"
	for key in ["UI_EFFECTS_DENSITY", "UI_OPT_LOW", "UI_OPT_MEDIUM", "UI_OPT_HIGH"]:
		for locale in ["en", "es"]:
			TranslationServer.set_locale(locale)
			assert_ne(TranslationServer.translate(key), StringName(key), "%s in %s" % [key, locale])
	TranslationServer.set_locale("en")
