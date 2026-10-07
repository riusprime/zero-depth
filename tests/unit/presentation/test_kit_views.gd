extends GutTest
## The Vent and Skill buttons' views (v0.3.5 K): the HUD's skill pip and vent hint (the bound keys, the cooldown,
## lit when ready), the skill visuals (the cleave's forecast fan with the hit's own numbers, the flash and streak,
## the pellet tracers to the sim's end points) and their sounds. Reads through WorldReader only.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()
	InputDefaults.apply()


func _world(build: StringName, enemies: Array = [], heat: bool = false) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	if heat:
		Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


func _f(pressed: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 300, 0, pressed)


func _hud() -> KitHud:
	var h := KitHud.new()
	add_child_autofree(h)
	return h


func test_the_hud_shows_the_skill_with_its_key_and_cooldown() -> void:
	var h := _hud()
	h.sync(WorldReader.new(World.new(5, PlayerTable.starting_values())))
	assert_false(h.skill_visible(), "no build skill, no pip")
	assert_false(h.vent_visible(), "no heat, no vent hint")
	var w := _world(&"blade")
	var r := WorldReader.new(w)
	h.sync(r)
	assert_true(h.skill_visible())
	assert_eq(h.skill_text(), tr("HUD_KEY_HINT") % ["Q", tr("SKILL_LUNGE_CLEAVE")])
	assert_almost_eq(h.skill_fill(), 1.0, 1e-6, "ready: full")
	w.step(_f(InputFrame.SKILL))
	h.sync(r)
	assert_lt(h.skill_fill(), 0.01, "just used: empty")
	for k in 120:
		w.step(_f())
	h.sync(r)
	assert_almost_eq(h.skill_fill(), 121.0 / 240.0, 0.01, "half way through the 4 s cooldown")
	var g := _world(&"gun")
	h.sync(WorldReader.new(g))
	assert_eq(h.skill_text(), tr("HUD_KEY_HINT") % ["Q", tr("SKILL_SCATTER_BLAST")])


func test_the_vent_hint_shows_the_key_and_lights_when_hot() -> void:
	var h := _hud()
	var w := _world(&"blade", [], true)
	var r := WorldReader.new(w)
	h.sync(r)
	assert_true(h.vent_visible())
	assert_eq(h.vent_text(), tr("HUD_KEY_HINT") % ["F", tr("HUD_VENT")])
	assert_false(h.vent_lit(), "cool: dim")
	w.heat.milli = 50 * HeatTable.MILLI
	h.sync(r)
	assert_true(h.vent_lit(), "Hot: lit")
	var p := ProfileStore.new("")
	InputRebind.rebind(p, &"vent", [&"key", KEY_G])
	h.sync(r)
	assert_eq(h.vent_text(), tr("HUD_KEY_HINT") % ["G", tr("HUD_VENT")], "a remap shows at once")
	InputDefaults.apply()


func test_the_cleave_forecast_uses_the_hits_numbers_then_flashes() -> void:
	var w := _world(&"blade", [Vector2(5.5, 0)])
	var r := WorldReader.new(w)
	var fx := SkillVisuals.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.sync(r)
	assert_false(fx.forecast_visible())
	w.step(_f(InputFrame.SKILL))
	fx.sync(r)
	assert_true(fx.forecast_visible(), "the fan rides with the lunge")
	var t := w.player.skill
	assert_eq(
		fx.forecast_shape(), Vector2(t.half_arc, t.reach_m), "the hit's own half arc and reach"
	)
	assert_true(
		r.skill_hits(1, Vector2(3.5, 0), 0), "the forecast says the enemy ahead will be hit"
	)
	for k in 12:
		w.step(_f())
	fx.sync(r)
	assert_false(fx.forecast_visible(), "done")
	assert_eq(fx.fx_count_of(&"cleave"), 1, "the cleave flashes")
	assert_eq(fx.fx_count_of(&"streak"), 1, "behind a lunge streak")
	var hit := false
	for e in w.events_since(0):
		hit = hit or (e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[1])
	assert_true(hit, "and the enemy ahead was hit")


func test_the_blast_draws_a_tracer_to_each_pellets_end() -> void:
	var w := _world(&"gun", [Vector2(2, 0)])
	var r := WorldReader.new(w)
	var fx := SkillVisuals.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.sync(r)
	w.step(_f(InputFrame.SKILL))
	fx.sync(r)
	assert_eq(fx.fx_count_of(&"tracer"), 7, "7 tracers")
	assert_eq(fx.fx_count_of(&"cone"), 1, "and the cone's flash")
	assert_eq(r.skill_pellet_angles(0).size(), 7)


func test_the_skills_and_the_cold_vent_have_sounds() -> void:
	for pair: Array in [[&"blade", &"skill_lunge_cleave"], [&"gun", &"skill_scatter_blast"]]:
		var w := _world(pair[0])
		var r := WorldReader.new(w)
		var ev := AudioEvents.new()
		ev.prime(r)
		w.step(_f(InputFrame.SKILL))
		var ids := ev.collect(r).map(func(c: Array) -> StringName: return c[0])
		assert_has(ids, pair[1])
	var c := _world(&"blade", [], true)
	var cr := WorldReader.new(c)
	var cev := AudioEvents.new()
	cev.prime(cr)
	c.step(_f(InputFrame.VENT))
	assert_eq(cr.vent_cold_tick(), 0)
	assert_has(cev.collect(cr).map(func(x: Array) -> StringName: return x[0]), &"vent_cold")
	var d := AudioDirector.new()
	add_child_autofree(d)
	for id: StringName in [&"skill_lunge_cleave", &"skill_scatter_blast", &"vent_cold"]:
		assert_not_null(d.stream_for(id), "%s ships a sound" % id)
