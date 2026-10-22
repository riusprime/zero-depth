extends GutTest
## v0.9.0 AF3 (owner Q7; ATTACK_FORMS.md F9, F10): the Wave's and the Wisps' views. Each Wave shot in flight is a band
## as wide as the sim's (WaveView, not the pulses or the bolt layer), in the element's look, gone when the shot is; it
## whooshes. The wisps are drawn where the sim has them round the hero, charging up before a shot; their orbs chirp
## and stay the pulses'; nothing without the card.

const W := preload("res://tests/support/mx4_world.gd")


func _world(card: StringName, items: Array = [], at: Array = []) -> World:
	var ids: Array = [card]
	ids.append_array(items)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, 0.35, 1000000)
	return w


func test_a_wave_is_drawn_as_wide_as_the_sims_band_and_goes_with_it() -> void:
	var view: WaveView = add_child_autofree(WaveView.new())
	var w := _world(&"gun_wave")
	var r := WorldReader.new(w)
	view.sync(r)
	assert_eq(view.waves, 0)
	W.run(w, 1, 0, W.S)
	view.sync(r)
	assert_eq(view.waves, 1, "one band")
	assert_almost_eq(view.widths[0], 3.0, 1e-4, "3 m wide, as the sim's")
	W.run(w, 200, 0, 0)
	view.sync(r)
	assert_eq(view.waves, 0, "gone with the shot")


func test_wave_shots_are_not_drawn_as_pulses_or_bolt_layers() -> void:
	var w := _world(&"gun_wave")
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	assert_eq(r.projectile_count(), 1)
	assert_true(r.projectile_is_wave(0), "the shot is a wave")
	var forms: AttackFormView = add_child_autofree(AttackFormView.new())
	forms._sync_bolts(r)
	assert_eq(forms._live.size(), 0, "no bolt layer for a wave")
	var orbs := W.world(&"gun")
	W.run(orbs, 1, 0, W.S)
	assert_false(WorldReader.new(orbs).projectile_is_wave(0), "an orb is no wave")


func test_the_element_sets_the_waves_look() -> void:
	var view: WaveView = add_child_autofree(WaveView.new())
	var w := _world(&"gun_wave", [&"storm_core"])
	W.run(w, 1, 0, W.S)
	view.sync(WorldReader.new(w))
	assert_eq(view.look, &"lightning")


func test_the_wave_whooshes() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world(&"gun_wave")
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 4:
		W.run(w, 1, 0, W.S if k == 0 else 0)
		audio.sync(r)
	assert_true(audio.played_log.has(&"wave_fire"), "the Wave's whoosh")
	assert_false(audio.played_log.has(&"bolt_fire"), "not the orb's shot")
	assert_not_null(audio.stream_for(&"wave_fire"), "the placeholder file")


func test_the_wisps_are_drawn_where_the_sim_has_them_and_charge_before_a_shot() -> void:
	var view: WispsView = add_child_autofree(WispsView.new())
	var w := _world(&"gun_wisps")
	var r := WorldReader.new(w)
	view.sync(r)
	assert_eq(view.wisps, 3, "three wisps")
	var sim := r.wisps()
	for k in 3:
		assert_eq(view.places[k], sim[k]["pos"], "wisp %d where the sim has it" % k)
	var none: WispsView = add_child_autofree(WispsView.new())
	none.sync(WorldReader.new(W.world(&"gun")))
	assert_eq(none.wisps, 0, "no card, no wisps")


func test_the_wisps_orbs_chirp_and_the_heros_shot_stays_the_orbs() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world(&"gun_wisps", [], [Vector2(4.0, 0.0)])
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	for k in 40:
		W.run(w, 1, 0, 0)
		audio.sync(r)
	assert_true(audio.played_log.has(&"wisp_fire"), "a wisp's chirp")
	assert_false(audio.played_log.has(&"bolt_fire"), "SHOOT never held: no Gun shot")
	assert_not_null(audio.stream_for(&"wisp_fire"), "the placeholder file")
	var shot := -1
	for i in r.projectile_count():
		if r.projectile_is_wisp(i):
			shot = i
	assert_gte(shot, 0, "a wisp's orb in flight")
	assert_eq(r.projectile_look(shot), "", "drawn by the pulses as an orb")
