extends GutTest
## v0.10.0 VX8 (VFX_PACK N3): the Blade's existing swings in the pack's style. The swing ribbon wears the beam pack's
## scrolling-noise material (UV along the ribbon, held with the hit-stop, in the blade's or its element's colour), the
## cut strikes vfx_hit_04 on the tip, the forms use the pack (eruption, parry spark, counter and finisher rings, the
## crescents' rim material), the Lunge Cleave's sweep takes the ribbon and the flash; a full family or no pack keeps the
## old looks. Presentation only: nothing here reads or writes the sim.


## A stand-in for WorldViewRoot: the views find the pack on an ancestor's `pack_fx`.
class Host:
	extends Node3D
	var pack_fx: PackFx = null


var _host: Host
var _fx: PackFx
var _repo: ContentRepository
var _most := {}
var _most_baked := 0


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_host = add_child_autofree(Host.new())
	_fx = PackFx.new()
	_host.add_child(_fx)
	_host.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = "medium"


func _swing_world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, InputFrame.PRIMARY, InputFrame.PRIMARY))
	return w


func _kit_swinging(parent: Node) -> Array:
	var w := _swing_world()
	var r := WorldReader.new(w)
	var kit := KitView.new()
	parent.add_child(kit)
	kit.sync(r)
	for k in 4:
		w.step(InputFrame.new())
		kit.sync(r)
	return [kit, w, r]


func test_every_vx8_row_exists() -> void:
	for id in [
		&"vx8_cut", &"vx8_parry", &"vx8_erupt", &"vx8_counter", &"vx8_finisher", &"vx8_cleave_flash"
	]:
		assert_true(_fx.has_id(id), String(id))


func test_the_swing_ribbon_wears_the_pack_material_with_uvs_along_it() -> void:
	var kit: KitView = _kit_swinging(_host)[0]
	assert_true(kit.ribbon_material() != null, "a slot was free")
	var mat := kit.ribbon_material()
	assert_not_null(mat)
	assert_true(mat.shader.code.contains("noise_texture"), "the beam's scrolling noise")
	assert_not_null(mat.get_shader_parameter(&"noise_texture"))
	var mesh: ImmediateMesh = (kit.get_node("BladeTrail") as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 4, "the ribbon carries UVs")
	assert_eq(uvs[uvs.size() - 1].x, 1.0, "the newest end is u = 1")
	assert_eq(uvs[0].x, 0.0, "the oldest is u = 0")
	assert_eq(uvs[0].y, 0.0, "the inner edge")
	assert_eq(uvs[1].y, 1.0, "the tip edge")
	assert_gt(BladePack.ribbons(), 0)
	kit.free()
	assert_eq(BladePack.ribbons(), 0, "the slot goes back with the view")


func test_the_ribbon_takes_the_blades_colour_and_the_heat_tiers() -> void:
	var kit: KitView = _kit_swinging(_host)[0]
	var mat := kit.ribbon_material()
	assert_eq(Color(mat.get_shader_parameter(&"secondary_color")), Color(kit.hue(), 1.0))
	kit.set_heat_tier(HeatLooks.TIER_OVERCLOCK)
	kit.sync(_kit_world_reader())
	assert_eq(
		Color(kit.ribbon_material().get_shader_parameter(&"secondary_color")),
		Color(kit.hue(), 1.0),
		"the hot tier's colour"
	)


func _kit_world_reader() -> WorldReader:
	return WorldReader.new(_swing_world())


func test_the_noise_runs_with_time_and_holds_with_the_hit_stop() -> void:
	var kit: KitView = _kit_swinging(_host)[0]
	var mat := kit.ribbon_material()
	var before := float(mat.get_shader_parameter(&"phase"))
	kit._process(0.1)
	var running := float(mat.get_shader_parameter(&"phase"))
	assert_gt(running, before, "it scrolls along the swing")
	kit.hold(0.5)
	kit._process(0.1)
	assert_eq(float(mat.get_shader_parameter(&"phase")), running, "held: the noise holds too")


func test_no_pack_and_a_full_family_keep_the_old_ribbon() -> void:
	var bare: Node3D = add_child_autofree(Node3D.new())
	var kit: KitView = _kit_swinging(bare)[0]
	assert_false(kit.ribbon_material() != null, "no pack above: the old ribbon")
	assert_true(
		(kit.get_node("BladeTrail") as MeshInstance3D).material_override is StandardMaterial3D
	)
	var taken := 0
	while BladePack.claim_ribbon(_fx):
		taken += 1
	assert_eq(taken, _fx.cap_for(&"trail"), "the trail family's cap")
	var full: KitView = _kit_swinging(_host)[0]
	assert_false(full.ribbon_material() != null, "past the cap: the old ribbon for this view")
	for k in taken:
		BladePack.free_ribbon()
	assert_eq(BladePack.ribbons(), 0)


func test_the_cut_strikes_a_pack_spark_on_the_tip() -> void:
	var w := _swing_world()
	var r := WorldReader.new(w)
	var kit := KitView.new()
	_host.add_child(kit)
	var fx := BladeSwingFx.new(kit)
	_host.add_child(fx)
	for t in 40:
		kit.sync(r)
		fx.sync(r)
		w.step(InputFrame.new())
	assert_gt(fx.cuts, 0, "the swing cut")
	assert_eq(fx.pack_cuts, fx.cuts, "each cut struck the pack spark")
	assert_gt(_fx.pooled(&"vx8_cut"), 0)
	# a full hit family keeps the old flare alone
	var bare := Node3D.new()
	add_child_autofree(bare)
	var kit2 := KitView.new()
	bare.add_child(kit2)
	var fx2 := BladeSwingFx.new(kit2)
	bare.add_child(fx2)
	var w2 := _swing_world()
	var r2 := WorldReader.new(w2)
	for t in 40:
		kit2.sync(r2)
		fx2.sync(r2)
		w2.step(InputFrame.new())
	assert_gt(fx2.cuts, 0)
	assert_eq(fx2.pack_cuts, 0, "no pack: only the old flare")


func _forms(cards: Array, ticks: int, parent: Node) -> BladeFormView:
	_most = {}
	_most_baked = 0
	var w := WandLab.fight(&"blade", cards)
	var r := WorldReader.new(w)
	var view := BladeFormView.new()
	parent.add_child(view)
	for t in ticks:
		w.step(AttackScenario.frame(t))
		view.sync(r)
		for k: StringName in view.drawn:
			_most[k] = maxi(int(_most.get(k, 0)), int(view.drawn[k]))
		_most_baked = maxi(_most_baked, view.baked_drawn())
	return view


func test_the_eruption_the_parry_spark_and_the_rings_use_the_pack() -> void:
	_forms([&"fissure"], 420, _host)
	assert_gt(_fx.pooled(&"vx8_erupt"), 0, "the eruption is vfx_impact_02")
	_forms([&"parry_edge"], 900, _host)
	assert_gt(_fx.pooled(&"vx8_parry"), 0, "the parry spark is vfx_hit_04")
	_forms([&"counter"], 420, _host)
	assert_gt(_fx.pooled(&"vx8_counter"), 0, "the counter's ring is a pulse area")


func test_each_form_starts_its_pack_effect_once() -> void:
	var view := _forms([&"fissure"], 420, _host)
	var made := _fx.spawned
	assert_gt(made, 0)
	# the eruptions are at most ERUPT_MAX a fissure: spawned counts stay far below one per frame
	assert_lt(made, 60, "once per eruption, not once per frame")


func test_the_forms_keep_their_old_looks_without_the_pack() -> void:
	var bare: Node3D = add_child_autofree(Node3D.new())
	var view := _forms([&"fissure"], 420, bare)
	assert_gt(int(_most.get(&"line", 0)), 0, "the eruption still counts and draws")
	assert_eq(_fx.spawned, 0, "nothing spawned in the pack")


func test_the_crescents_wear_the_rim_material_with_the_pack() -> void:
	var view := _forms([&"echo_slash"], 420, _host)
	assert_gt(_most_baked, 0)
	var mm: MultiMeshInstance3D = null
	for n in view.get_node("Baked").get_children():
		mm = n as MultiMeshInstance3D
		if mm != null:
			break
	assert_not_null(mm, "a baked pool")
	var m := mm.multimesh.mesh.surface_get_material(0)
	assert_true(m is ShaderMaterial, "rim_area_04's copy")
	assert_true(mm.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size() > 0, "with UVs")


func test_the_cleave_sweep_takes_the_ribbon_and_the_flash() -> void:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.add_dummy(Vector2(5.5, 0), 0.35, 5000)
	var r := WorldReader.new(w)
	var fx := SkillVisuals.new()
	_host.add_child(fx)
	var sweeping := false
	for k in 40:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.SKILL if k == 0 else 0))
		fx.sync(r)
		sweeping = sweeping or fx.ribbon_active()
	assert_true(sweeping, "the sweep drew with the pack's ribbon")
	assert_gt(_fx.pooled(&"vx8_cleave_flash"), 0, "the hit flashed big_flash_02")
	assert_false(fx.ribbon_active(), "the slot is back when the sweep is over")
	assert_eq(BladePack.ribbons(), 0)
