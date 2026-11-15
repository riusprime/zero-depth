extends GutTest
## The view of The Fallen's old vanishing interphase. The Fallen no longer vanishes (it stays in the room and casts
## remembered mechanics: WorldReader.boss_fallen), so WorldReader.final_interphase is always {} and the view draws
## nothing in a Fallen fight; its shader stays as it was until the view is retired.


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


func test_a_fallen_fight_at_a_gate_draws_nothing() -> void:
	var w := NemesisLab.world(851, &"blade", [], true, false)
	var i := FinalLab.body(w)
	w.actors.hp[i] = w.actors.max_hp[i] * 600 / 1000
	for k in 240:
		w.step(InputFrame.new())
	var v := _view()
	v.sync(WorldReader.new(w))
	assert_true(WorldReader.new(w).final_interphase().is_empty())
	assert_eq(v.beams_drawn() + v.discs_drawn() + v.lines_drawn() + v.points_drawn(), 0)
