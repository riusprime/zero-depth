extends GutTest
## v0.9.5 FC0 (owner: Rune Explosion): its look. The violet dome and the rune ring follow the sim's edge radius, every
## shader is unshaded with fog_disabled (and masked to the ring's disc: no square), the dome is translucent (alpha at
## most 0.35) and absent under Reduced motion, the rune strip is drawn once and cached, the views are gone with the
## burst, and the burst booms once.

const W := preload("res://tests/support/mx4_world.gd")


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ViewPrefs.effects_density = "medium"


func _world(items: Array = []) -> World:
	var ids: Array = [&"gun_rune_explosion"]
	ids.append_array(items)
	var w := W.world(&"gun", ids)
	w.add_dummy(Vector2(2.0, 0.0), 0.35, 1000000)
	return w


func test_the_dome_and_ring_follow_the_sims_edge_and_go_with_it() -> void:
	var view: RuneExplosionView = add_child_autofree(RuneExplosionView.new())
	var w := _world()
	var r := WorldReader.new(w)
	view.sync(r)
	assert_eq(view.bursts, 0)
	W.run(w, 1, 0, W.S)
	W.run(w, 10, 0, 0)
	view.sync(r)
	assert_eq(view.bursts, 1, "one burst")
	assert_almost_eq(view.edges[0], r.rune_bursts()[0]["edge"], 1e-5, "the sim's edge")
	var dome: MeshInstance3D = view._domes[0]
	var ring: MeshInstance3D = view._rings[0]
	assert_true(dome.visible and ring.visible, "dome and ring shown")
	assert_almost_eq(
		dome.transform.basis.x.length(), view.edges[0], 1e-4, "the dome spans the edge"
	)
	assert_almost_eq(dome.transform.basis.y.length(), 0.45 * view.edges[0], 1e-4, "0.45 x as tall")
	W.run(w, 6, 0, 0)
	view.sync(r)
	assert_gt(view.edges[0], 2.0, "it grew")
	W.run(w, 80, 0, 0)
	view.sync(r)
	assert_eq(view.bursts, 0, "gone with the burst")
	assert_false(view._domes[0].visible or view._rings[0].visible)


func test_every_shader_is_unshaded_fog_disabled_and_the_dome_is_translucent() -> void:
	for code: String in [RuneExplosionView.DOME_SHADER, RuneExplosionView.RING_SHADER]:
		assert_string_contains(code, "fog_disabled")
		assert_string_contains(code, "unshaded")
	assert_string_contains(RuneExplosionView.DOME_SHADER, "blend_mix")
	assert_string_contains(RuneExplosionView.RING_SHADER, "blend_add")
	assert_string_contains(
		RuneExplosionView.RING_SHADER, "smoothstep(edge_f, edge_f", "an edge mask"
	)
	assert_string_contains(RuneExplosionView.DOME_SHADER, "0.35", "alpha capped at 0.35")
	assert_lte(RuneExplosionView.DOME_ALPHA_MAX, 0.35)


func test_the_fade_holds_then_falls_over_the_last_thirty_percent_and_after() -> void:
	assert_eq(RuneExplosionView.fade_of(0, 21, 9), 1.0)
	assert_eq(RuneExplosionView.fade_of(14, 21, 9), 1.0, "full until 70 % of the growth")
	assert_lt(RuneExplosionView.fade_of(21, 21, 9), 0.6, "falling at full size")
	assert_eq(RuneExplosionView.fade_of(30, 21, 9), 0.0, "gone 0.15 s after")


func test_reduced_motion_draws_the_floor_ring_only() -> void:
	ViewPrefs.reduced_motion = true
	var view: RuneExplosionView = add_child_autofree(RuneExplosionView.new())
	var w := _world()
	W.run(w, 8, 0, W.S)
	view.sync(WorldReader.new(w))
	assert_eq(view.bursts, 1)
	assert_false(view.domes_shown)
	assert_false(view._domes[0].visible, "no dome")
	assert_true(view._rings[0].visible, "the floor ring stays")


func test_the_rune_strip_is_twelve_glyphs_drawn_once_and_cached() -> void:
	var a := RuneExplosionView.glyph_texture()
	var b := RuneExplosionView.glyph_texture()
	assert_same(a, b, "cached")
	assert_eq(a.get_width(), 12 * RuneExplosionView.GLYPH_PX)
	var img := a.get_image()
	for c in 12:
		var lit := 0
		for x in RuneExplosionView.GLYPH_PX:
			for y in RuneExplosionView.GLYPH_PX:
				if img.get_pixel(c * RuneExplosionView.GLYPH_PX + x, y).r > 0.5:
					lit += 1
		assert_gt(lit, 40, "glyph %d is drawn" % c)


func test_a_burst_booms_once_with_its_own_cue() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world()
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 24:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		audio.sync(r)
	var n := 0
	for c in audio.played_log:
		n += 1 if c == &"rune_burst" else 0
	assert_eq(n, 1, "one boom for the one burst")
	assert_not_null(audio.stream_for(&"rune_burst"), "the placeholder file")


func test_fc5_the_cards_floor_rings_and_shards_follow_the_sim() -> void:
	var view: RuneExplosionView = add_child_autofree(RuneExplosionView.new())
	var w := _world([&"gun_ring", &"gun_mine", &"split_shot", &"gun_echo"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	W.run(w, 12, 0, 0)
	view.sync(r)
	var fx := r.rune_effects()
	assert_eq(fx["mines"].size(), 1, "a trap")
	assert_eq(fx["glyphs"].size(), 1, "an Echo glyph waits")
	assert_eq(fx["shards"].size(), 2, "two shards")
	assert_eq(view.shards, 2, "both drawn")
	assert_eq(view.extras, 2, "the trap and the glyph (the ring is not full yet)")
	W.run(w, 12, 0, 0)
	view.sync(r)
	assert_eq(r.rune_effects()["holds"].size(), 1)
	assert_eq(view.extras, 3, "and the held ring")
	assert_true(view._x_rings[0].visible)
