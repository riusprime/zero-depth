extends GutTest
## v0.9.5 BH4 (BOSSES_HARD.md T3): the Tidecaller's crossing waves. The view reads WorldReader.boss_waves only: a flat
## foam line on the floor at the wall for the 0.7 s telegraph, then a low curling band of water (0.5 m at the crest)
## crossing the room, spray motes thinned on Low density, all unshaded with fog_disabled and an edge mask, and a soft
## whoosh (the tide cue pitched up) as each wave leaves its wall. Presentation only: nothing here writes the sim.


func after_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


func _fight() -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"tidecaller", Vector2.ZERO)
	var t := BossAi.table_of(w, i)
	t.streams = false
	t.sig_every_ticks = 0
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	w.actors.set_pos(0, Vector2(-9, -9))
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	return [w, i, t]


func _view() -> TideWaveViews:
	var v := TideWaveViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func test_the_wave_mesh_is_half_a_metre_at_the_crest_and_curls_forward() -> void:
	var mesh := TideWaveViews.wave_mesh()
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top := 0.0
	var crest_x := 0.0
	var front := -1.0
	for v in verts:
		if v.y > top:
			top = v.y
			crest_x = v.x
		front = maxf(front, v.x)
	assert_almost_eq(top, 0.5, 0.0001, "0.5 m tall at the crest")
	assert_lt(crest_x, front, "the lip curls on past the crest")
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var hi := 0.0
	for uv in uvs:
		hi = maxf(hi, uv.y)
	assert_almost_eq(hi, 1.0, 0.0001, "the shader's height runs 0 to 1 over the crest")


func test_both_shaders_have_no_fog_and_an_edge_mask() -> void:
	for code: String in [TideWaveViews.BAND_SHADER, TideWaveViews.LINE_SHADER]:
		assert_true(code.contains("fog_disabled"), "no fog")
		assert_true(code.contains("unshaded"))
		assert_true(
			(
				code.contains("smoothstep(1.0, 0.86, u)")
				or code.contains("smoothstep(1.0, 0.45, abs(q.y))")
			),
			"an edge mask"
		)
	var v := _view()
	var m := (v.band_material(0) as ShaderMaterial).shader
	assert_not_null(m)
	assert_true(m.code.contains("edge"))


func test_a_foam_line_shows_at_the_wall_then_the_band_crosses() -> void:
	var s := _fight()
	var w: World = s[0]
	var t: BossTable = s[2]
	var reader := WorldReader.new(w)
	var v := _view()
	v.sync(reader)
	assert_eq([v.lines_shown(), v.bands_shown(), v.motes_drawn()], [0, 0, 0], "nothing at first")
	BossStream.form(w, s[1], BossAi.entry_of(w, s[1]), t.phase_wave_atk[0], 1)
	CombatLab.idle(w, 10)
	v.sync(reader)
	v.advance(0.016)
	assert_eq([v.lines_shown(), v.bands_shown()], [1, 0], "the foam line through the telegraph")
	var wv: Dictionary = reader.boss_waves()[0]
	var line := v.line(0)
	assert_true(line.visible)
	assert_almost_eq(line.scale.z, float(wv["length"]), 0.0001, "as long as the wave will be")
	var near0 := float(v.line_material(0).get_shader_parameter("near"))
	CombatLab.idle(w, 20)
	v.sync(reader)
	assert_gt(
		float(v.line_material(0).get_shader_parameter("near")),
		near0,
		"it brightens as the wave nears"
	)
	CombatLab.idle(w, 20)  # past the 42 ticks: it moves
	v.sync(reader)
	v.advance(0.016)
	assert_eq([v.lines_shown(), v.bands_shown()], [0, 1], "then the band")
	CombatLab.idle(w, 30)
	v.sync(reader)
	v.advance(0.016)
	var band := v.band(0)
	assert_true(band.visible)
	assert_almost_eq(band.scale.x, 0.5, 0.0001, "0.5 m thick")
	assert_almost_eq(band.scale.z, float(wv["length"]), 0.0001)
	var at: Vector2 = reader.boss_waves()[0]["pos"]
	assert_almost_eq(band.position.x, at.x, 0.0001, "drawn where the sim has it")
	assert_almost_eq(band.position.z, -at.y, 0.0001)
	assert_gt(v.motes_drawn(), 0, "spray")


func test_the_spray_thins_on_low_density_and_nothing_remains_after() -> void:
	var s := _fight()
	var w: World = s[0]
	var t: BossTable = s[2]
	var reader := WorldReader.new(w)
	var v := _view()
	BossStream.form(w, s[1], BossAi.entry_of(w, s[1]), t.phase_wave_atk[0], 1)
	CombatLab.idle(w, 80)
	v.sync(reader)
	v.advance(0.016)
	var high := v.motes_drawn()
	ViewPrefs.effects_density = "low"
	v.advance(0.016)
	assert_lt(v.motes_drawn(), high, "fewer motes on Low")
	assert_gt(v.motes_drawn(), 0, "but some")
	CombatLab.idle(w, 400)  # it has crossed and gone
	v.sync(reader)
	v.advance(0.016)
	assert_eq([v.lines_shown(), v.bands_shown(), v.motes_drawn()], [0, 0, 0], "gone with the wave")


func test_two_waves_make_two_bands() -> void:
	var s := _fight()
	var w: World = s[0]
	var t: BossTable = s[2]
	var reader := WorldReader.new(w)
	var v := _view()
	BossStream.form(w, s[1], BossAi.entry_of(w, s[1]), t.phase_wave_atk[1], 2)
	CombatLab.idle(w, 60)
	v.sync(reader)
	assert_eq(v.bands_shown(), 2, "two waves at once, two bands")


func test_a_wave_leaving_its_wall_whooshes_once_with_the_tide_cue_pitched_up() -> void:
	var s := _fight()
	var w: World = s[0]
	var t: BossTable = s[2]
	var reader := WorldReader.new(w)
	var ev := AudioEvents.new()
	ev.prime(reader)
	BossStream.form(w, s[1], BossAi.entry_of(w, s[1]), t.phase_wave_atk[0], 1)
	var cues := []
	for k in 100:
		w.step(InputFrame.new())
		for c: Array in ev.collect(reader):
			if c[0] == &"boss_tide_pull":
				cues.append(c)
	assert_eq(cues.size(), 1, "one whoosh, as it leaves the wall (not at its foam line)")
	assert_almost_eq(float(cues[0][2]), AudioEvents.WAVE_PITCH, 0.0001, "the tide cue, pitched up")
