extends GutTest
## v0.8.0 TX1 (docs/art/requests/v0.8.0_textures.md): the owner's orb, trail, beam, impact, aim-line and sigil textures
## go on the meshes that drew the code looks (a uniform swap: no new MultiMesh or node per instance), keep the code's
## colours, and when a texture isn't installed the code look stays.

const IDS := [
	"fx_orb_cores",
	"fx_orb_cores_2",
	"fx_orb_cores_final",
	"fx_trails",
	"fx_beam",
	"fx_beam_impact",
	"fx_aim_lines",
	"fx_cast_sigils",
]


func after_each() -> void:
	FxTextures.dir = FxTextures.DIR


func test_the_textures_are_installed_as_greyscale_masks() -> void:
	for id: String in IDS:
		var t := FxTextures.get_tex(id)
		assert_not_null(t, "%s is installed" % id)
		if t != null:
			assert_eq(t.get_width(), t.get_height(), "%s is square" % id)
			assert_true(t.get_width() == 512 or t.get_width() == 1024, "%s is 512 or 1024" % id)


func test_every_listed_look_gets_its_core_cell_and_keeps_its_colours() -> void:
	for key: StringName in FireballViews.TEX_CORES:
		var look := FireballViews.look_of(key).duplicate()
		look["key"] = key
		var m := FireballViews.core_material(look)
		assert_eq(m.get_shader_parameter("tex_on"), 1.0, "%s draws the owner's core" % key)
		assert_eq(m.get_shader_parameter("core_color"), look["core"], "%s keeps its colour" % key)
		var cell: int = FireballViews.TEX_CORES[key][1]
		assert_eq(m.get_shader_parameter("tex_cell"), Vector2(cell % 2, cell / 2))


func test_an_unlisted_look_keeps_the_code_noise() -> void:
	var look := FireballViews.look_of(&"lens_orb").duplicate()
	look["key"] = &"lens_orb"
	var m := FireballViews.core_material(look)
	assert_ne(m.get_shader_parameter("tex_on"), 1.0, "the Lens Drone's orb keeps its code look")


func test_trails_pick_their_row_by_style() -> void:
	assert_eq(FireballViews.trail_row(FireballViews.look_of(&"cannon_ember")), 1, "smoke")
	assert_eq(FireballViews.trail_row(FireballViews.look_of(&"acid_glob")), 2, "drips")
	assert_eq(FireballViews.trail_row(FireballViews.look_of(&"prism_orb")), 3, "crystal")
	assert_eq(FireballViews.trail_row(FireballViews.look_of(&"ember_stone")), 0, "flame")
	var m := FireballViews.trail_material(FireballViews.look_of(&"acid_glob"))
	assert_eq(m.get_shader_parameter("tex_on"), 1.0)
	assert_eq(m.get_shader_parameter("tex_row"), 2.0)


func test_without_the_textures_the_code_looks_stay() -> void:
	FxTextures.dir = "res://tests/fixtures/no_such_dir/"
	var look := FireballViews.look_of(&"ember_stone").duplicate()
	look["key"] = &"ember_stone"
	assert_ne(FireballViews.core_material(look).get_shader_parameter("tex_on"), 1.0)
	assert_ne(FireballViews.trail_material(look).get_shader_parameter("tex_on"), 1.0, "code trail")
	assert_null(FxTextures.flare_material(Color.RED, Color.WHITE, 0))
	assert_null(FxTextures.sigil_material(Color.RED, 0))
	var v := PrismViews.new()
	add_child_autofree(v)
	var arm: Dictionary = v._arms[0]
	var core := (arm["core"] as MeshInstance3D).material_override as ShaderMaterial
	assert_ne(core.get_shader_parameter("tex_on"), 1.0, "the code beam")
	assert_true((arm["impact"] as MeshInstance3D).mesh is SphereMesh, "the code flare")


func test_the_beams_aim_lines_impacts_and_sigils_take_the_owner_art() -> void:
	var v := PrismViews.new()
	add_child_autofree(v)
	var arm: Dictionary = v._arms[0]
	for key in ["core", "glow", "aim"]:
		var m := (arm[key] as MeshInstance3D).material_override as ShaderMaterial
		assert_eq(m.get_shader_parameter("tex_on"), 1.0, "the Cross's %s" % key)
		assert_eq(m.get_shader_parameter("color"), PrismViews.BEAM, "in her colour")
	var bolt := v._bolt_line.material_override as ShaderMaterial
	assert_eq(bolt.get_shader_parameter("tex_row"), float(FxTextures.AIM_LASER), "the bolt's laser")
	var imp := arm["impact"] as MeshInstance3D
	assert_true(imp.mesh is QuadMesh, "the impact flare is the owner's quad")
	var g := BossSignatureViews.new()
	add_child_autofree(g)
	var beam := g._beam.material_override as ShaderMaterial
	assert_eq(beam.get_shader_parameter("tex_on"), 1.0, "the Gaze's beam")
	assert_eq(beam.get_shader_parameter("color"), BossSignatureViews.GAZE)
	var n := NemesisViews.new()
	add_child_autofree(n)
	assert_true(n._sigil.material_override is ShaderMaterial, "the Nemesis's sigil")
	assert_eq(
		(n._sigil.material_override as ShaderMaterial).get_shader_parameter("color"),
		NemesisViews.SIGIL
	)


func test_the_focus_beam_pool_has_the_owner_strip() -> void:
	var v := BossStrikeViews.new()
	add_child_autofree(v)
	var node := v.get_node("Strike_beam") as MultiMeshInstance3D
	var m := node.material_override as ShaderMaterial
	assert_eq(m.get_shader_parameter("tex_on"), 1.0, "the beam pool has the owner's strip")


func test_the_arc_casters_rune_is_the_owner_sigil() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 100000
	w.add_enemy(ActorStore.Kind.ARC_CASTER, Vector2(-8, 0))
	var view := TelegraphViews.new()
	add_child_autofree(view)
	var reader := WorldReader.new(w)
	var sigils := 0
	for k in 1800:
		w.step(InputFrame.new())
		w.actors.hp[0] = 100000
		view.sync(reader)
		for n: Node in view.get_children():
			if n.get_meta(&"style", &"") != &"rune":
				continue
			var sigil := n.get_node_or_null("Sigil") as MeshInstance3D
			assert_not_null(sigil, "the rune draws the owner's sigil")
			if sigil != null:
				sigils += 1
				var deco := (n.get_node("Deco") as MeshInstance3D).mesh as ImmediateMesh
				assert_eq(deco.get_surface_count(), 0, "in place of the code ring and spokes")
		if sigils > 0:
			break
	assert_gt(sigils, 0, "a rune was cast within 30 s")
