extends GutTest
## v0.5.5 Step DS (owner S5): a Deep floor looks different: its biome's mood (v0.5.9) stays and a violet haze is
## layered on it (violet fog, the ambient, sun and void pulled toward violet); a normal floor keeps the mood as it is.
## The boss's phase gate shows itself (a shell around the boss, PHASE SHIFT on the boss bar). Presentation only.

const LONG := 1 << 24


func _view(w: World, mood: bool) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood if mood else null
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func _floor(route: int) -> World:
	return SaveLab.build_floor(SaveLab.run_state(81, 2, &"blade", route))


func test_a_deep_floor_layers_a_violet_haze_on_the_biomes_mood() -> void:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var normal := _view(_floor(Routes.Route.NORMAL), true)
	var deep := _view(_floor(Routes.Route.DEEP), true)
	assert_false(normal.stage.deep)
	assert_true(deep.stage.deep)
	var ne := normal.stage.environment
	var de := deep.stage.environment
	assert_eq(ne.ambient_light_color, biome.mood.ambient_color, "a normal floor keeps the mood")
	assert_eq(de.tonemap_mode, ne.tonemap_mode, "the mood stays under the haze")
	assert_true(de.fog_enabled, "violet fog")
	assert_gte(de.fog_density, StageView.DEEP_FOG_DENSITY)
	assert_gte(de.fog_density, ne.fog_density)
	assert_gt(de.fog_light_color.b, de.fog_light_color.g, "the fog is violet")
	assert_gt(
		de.ambient_light_color.b - de.ambient_light_color.g,
		ne.ambient_light_color.b - ne.ambient_light_color.g
	)
	var ns := normal.stage.sun.light_color
	var ds := deep.stage.sun.light_color
	assert_gt(ds.b - ds.g, ns.b - ns.g, "the sun turns violet")
	assert_ne(de.background_color, ne.background_color, "a darker, violet void")


func test_the_haze_also_works_without_a_mood() -> void:
	var deep := _view(_floor(Routes.Route.DEEP), false)
	assert_true(deep.stage.environment.fog_enabled)
	assert_eq(deep.stage.environment.fog_light_color, StageView.DEEP_VIOLET)


func test_the_phase_gate_shows_a_shell_and_phase_shift() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(6, 0))
	var v := BossChallengeView.new()
	add_child_autofree(v)
	var hud := Hud.new()
	add_child_autofree(hud)
	var reader := WorldReader.new(w)
	Damage.hit(w, i, 999999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
	w.step(InputFrame.new())
	v.sync(reader)
	v._process(0.016)
	hud.sync(reader)
	assert_gte(v.gate_progress(), 0.0, "the shell is up")
	assert_true(v.gate_shell.visible)
	assert_eq(hud.boss_bar.status_text(), tr("HUD_BOSS_PHASE_SHIFT"))
	assert_eq(tr("HUD_BOSS_PHASE_SHIFT"), "PHASE SHIFT")
	BossLab.through_gate(w, aid)
	v.sync(reader)
	v._process(0.016)
	hud.sync(reader)
	assert_eq(v.gate_progress(), -1.0, "gone with the gate")
	assert_ne(hud.boss_bar.status_text(), tr("HUD_BOSS_PHASE_SHIFT"))
