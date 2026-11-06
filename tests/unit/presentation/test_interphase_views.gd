extends GutTest
## v0.9.5 BH6 (BOSSES_HARD.md HC4, HC5): the Fallen's interphase as the view draws it. It reads WorldReader
## .final_interphase and boss_light only (EI-07): a burst of violet runes where the body vanishes, thin violet beams
## (aim lines through the telegraph), rune rings on the floor for the eruptions with spikes thrown up, spike lines
## walking across the floor, marks at the rain's four points, the return ring and its falling streak, and the slam's
## flash. Shaders are unshaded, fog_disabled and edge-masked; Low density thins the spikes and drops the rune glyphs.

const R := preload("res://src/sim/ai/boss_interphase.gd")


func after_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


func _world() -> World:
	var w := NemesisLab.world(851, &"blade", [], true, false)
	return w


func _vanished(pick: int) -> World:
	var w := _world()
	var i := FinalLab.body(w)
	w.actors.hp[i] = w.actors.max_hp[i] * 600 / 1000
	for k in 240:
		w.step(InputFrame.new())
		if w.final_fight.ip_stage >= R.STAGE_VANISHED:
			break
	var t := BossAi.table_of(w, i)
	R.set_up(w, t, t.interphase, w.final_fight, pick)
	w.actors.set_pos(0, w.final_fight.home + Vector2(1.0, 1.0))
	return w


func _view() -> InterphaseViews:
	var v := InterphaseViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func test_the_shader_has_no_fog_and_an_edge_mask() -> void:
	var code := InterphaseViews.FLOOR_SHADER
	assert_true(code.contains("fog_disabled"))
	assert_true(code.contains("unshaded"))
	assert_true(code.contains("smoothstep(1.0, 0.94, r)"), "the ring is edge-masked")
	assert_true(code.contains("smoothstep(0.0, 0.08, b)"), "and the rectangle")
	assert_true(
		BossSignatureShaders.BEAM.contains("fog_disabled"), "the beams reuse the Prism's shader"
	)


func test_rays_are_aim_lines_then_beams() -> void:
	var w := _vanished(R.SET_RAYS)
	var v := _view()
	v.sync(WorldReader.new(w))
	assert_eq(v.beams_drawn(), 3, "three beams")
	var core_visible := 0
	for arm in v._arms:
		core_visible += 1 if (arm["core"] as Node3D).visible else 0
	assert_eq(core_visible, 0, "only thin aim lines through the telegraph")
	for k in 50:
		w.step(InputFrame.new())
	v.sync(WorldReader.new(w))
	core_visible = 0
	for arm in v._arms:
		core_visible += 1 if (arm["core"] as Node3D).visible else 0
	assert_eq(core_visible, 3, "then three beams")


func test_it_bursts_where_it_vanishes_and_where_it_slams_back() -> void:
	var w := _world()
	var i := FinalLab.body(w)
	var v := _view()
	v.sync(WorldReader.new(w))
	assert_eq(v.bursts_alive(), 0)
	w.actors.hp[i] = w.actors.max_hp[i] * 600 / 1000
	for k in 240:
		w.step(InputFrame.new())
		v.sync(WorldReader.new(w))
		if w.final_fight.ip_stage >= R.STAGE_VANISHED:
			break
	assert_eq(v.bursts_alive(), 1, "the runes rise as it goes")
	v._process(0.1)
	assert_eq(v.bursts_alive(), 1)
	v._process(1.0)
	assert_eq(v.bursts_alive(), 0, "and fade")
	w.final_fight.ip_t = 900 - 2
	var seen_ring := false
	for k in 70:
		w.step(InputFrame.new())
		v.sync(WorldReader.new(w))
		seen_ring = seen_ring or v.return_drawn()
	assert_true(seen_ring, "the return ring shows")
	assert_eq(w.final_fight.ip_stage, R.STAGE_NONE)
	assert_eq(v.bursts_alive(), 1, "the slam's flash")
	assert_false(v.return_drawn(), "the ring is gone")


func test_eruptions_show_a_ring_and_throw_up_spikes() -> void:
	var w := _vanished(R.SET_RAYS)
	var v := _view()
	var drawn := 0
	var spikes := 0
	for k in 120:
		w.step(InputFrame.new())
		v.sync(WorldReader.new(w))
		v._process(1.0 / 60.0)
		drawn = maxi(drawn, v.discs_drawn())
		spikes = maxi(spikes, v.spikes_drawn())
	assert_gte(drawn, 1, "a rune ring for the eruption")
	assert_gte(spikes, 4, "and its spikes")
	ViewPrefs.effects_density = "low"
	var low := _vanished(R.SET_RAYS)
	var v2 := _view()
	var spikes_low := 0
	for k in 120:
		low.step(InputFrame.new())
		v2.sync(WorldReader.new(low))
		v2._process(1.0 / 60.0)
		spikes_low = maxi(spikes_low, v2.spikes_drawn())
	assert_lt(spikes_low, spikes, "Low density thins the spikes")


func test_rain_marks_its_points_and_walks_spike_lines() -> void:
	var w := _vanished(R.SET_RAIN)
	var v := _view()
	var points := 0
	var lines := 0
	var spikes := 0
	for k in 330:
		w.step(InputFrame.new())
		v.sync(WorldReader.new(w))
		points = maxi(points, v.points_drawn())
		lines = maxi(lines, v.lines_drawn())
		spikes = maxi(spikes, v.spikes_drawn())
	assert_eq(points, 2, "the pair about to fire pulses")
	assert_gte(lines, 1, "a line walks")
	assert_gt(spikes, 10, "with a row of spikes")


func test_lights_out_eruptions_glow_only_where_the_light_reaches() -> void:
	var w := _vanished(R.SET_DARK)
	var v := _view()
	v.sync(WorldReader.new(w))
	assert_true(bool(WorldReader.new(w).boss_light()["dark"]))
	v._hero_at = w.player_pos()
	assert_eq(v._lit_factor(w.player_pos()), 1.0, "lit round the hero")
	assert_eq(
		v._lit_factor(w.final_fight.home + Vector2(9.0, 0.0)), 0.0, "dark away from every light"
	)
	var lamp: Vector2 = WorldReader.new(w).boss_light()["lamps"][0]["pos"]
	v.sync(WorldReader.new(w))
	assert_eq(v._lit_factor(lamp), 1.0, "and at a lit lantern")


func test_reduced_motion_holds_the_pulse_still() -> void:
	ViewPrefs.reduced_motion = true
	var w := _vanished(R.SET_RAYS)
	var v := _view()
	v.sync(WorldReader.new(w))
	v._process(0.5)
	assert_eq(v._clock, 0.0, "the glow clock does not run")
