extends GutTest
## v0.9.0 LZ (owner C §6.2; PLAN C49): the Laser's view. While the beam fires, one ribbon per beam ends where the sim's
## trace ends (on the enemy, at a wall), with an impact there; each element has its own look (colours, its own strip
## texture through the beam_core_<look> manifest id with a code fallback, its impact's shape); Twin shows two ribbons;
## nothing shows when the trigger is let go; the hum loops while the beam fires.

const W := preload("res://tests/support/mx4_world.gd")

var _view: LaserView


func before_each() -> void:
	_view = add_child_autofree(LaserView.new())


func _world(items: Array = [], at: Array = [[Vector2(4.0, 0.0), 100000]]) -> World:
	var ids: Array = [&"gun_laser"]
	ids.append_array(items)
	return W.world(&"gun", ids, at)


func test_a_held_beam_shows_a_ribbon_to_the_enemy_with_an_impact() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	W.run(w, 3, 0, W.S)
	_view.sync(r)
	assert_eq([_view.shown, _view.impacts, _view.look], [1, 1, &"default"])
	var b: Dictionary = r.beams()[0]
	assert_almost_eq(
		(b["to"] as Vector2).x, 4.0 - 0.35 - 0.15, 0.05, "the beam ends on the enemy's edge"
	)
	W.run(w, 2, 0, 0)
	_view.sync(r)
	assert_eq(_view.shown, 0, "let go: no beam")


func test_twin_shows_two_beams() -> void:
	var w := _world([&"gun_twin"])
	var r := WorldReader.new(w)
	W.run(w, 2, 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 2)


func test_each_element_has_its_own_look_texture_and_impact() -> void:
	var cases := {
		&"": &"default",
		&"ember_core": &"fire",
		&"storm_core": &"lightning",
		&"frost_core": &"frost",
		&"venom_core": &"venom",
		&"shared_bleed": &"bleed",
	}
	var seen_core := []
	var seen_tex := []
	for card: StringName in cases:
		var w := _world([] if card == &"" else [card])
		var r := WorldReader.new(w)
		W.run(w, 2, 0, W.S)
		_view.sync(r)
		var look: StringName = cases[card]
		assert_eq(_view.look, look, "%s draws %s" % [card, look])
		assert_false(seen_core.has(BeamLooks.core(look)), "%s: its own core colour" % look)
		seen_core.append(BeamLooks.core(look))
		var img := BeamLooks.strip(look)
		assert_eq([img.get_width(), img.get_height()], [BeamLooks.TEX_W, BeamLooks.TEX_H])
		var sig := []
		for x in [0, 37, 101, 180]:
			for y in [4, 11, 16, 25]:
				sig.append(snappedf(img.get_pixel(x, y).a, 0.01))
		assert_false(seen_tex.has(sig), "%s: its own strip, not a recolour" % look)
		seen_tex.append(sig)
		assert_not_null(
			BeamLooks.texture(look), "the manifest id beam_core_%s or its code fallback" % look
		)
	var spikes := []
	for look: StringName in BeamLooks.LOOKS:
		spikes.append(BeamLooks.impact(look))
	assert_eq(spikes.size(), 6)
	assert_ne(
		BeamLooks.impact(&"lightning"), BeamLooks.impact(&"fire"), "impacts differ by element"
	)


func test_the_code_strip_tiles_along_the_beam() -> void:
	for look: StringName in BeamLooks.LOOKS:
		var img := BeamLooks.strip(look)
		var diff := 0.0
		for y in BeamLooks.TEX_H:
			diff += absf(img.get_pixel(0, y).a - img.get_pixel(BeamLooks.TEX_W - 1, y).a)
		assert_lt(diff / BeamLooks.TEX_H, 0.25, "%s: its ends meet" % look)


func test_the_hum_loops_while_the_beam_fires() -> void:
	var audio: AudioDirector = add_child_autofree(AudioDirector.new())
	var w := _world()
	var r := WorldReader.new(w)
	audio.attach(r, &"")
	W.run(w, 2, 0, W.S)
	audio.sync(r)
	assert_true(audio.holding(&"laser_loop"), "held: the hum")
	assert_true(audio.played_log.has(&"laser_loop"))
	var s := audio.stream_for(&"laser_loop")
	assert_not_null(s, "the placeholder file")
	assert_eq(
		(AudioDirector.looped(s) as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "loops"
	)
	W.run(w, 2, 0, 0)
	audio.sync(r)
	assert_false(audio.holding(&"laser_loop"), "let go: silent")


func test_v095_fc1_the_cards_extra_paths_ghosts_rings_and_mines_are_drawn() -> void:
	var w := _world(
		[&"halo_shot", &"gun_ring"], [[Vector2(4.0, 0.0), 100000], [Vector2(4.5, 1.0), 100000]]
	)
	var r := WorldReader.new(w)
	W.run(w, 3, 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 4, "the beam and Halo's three short beams")
	assert_eq(_view.rings_shown, 1, "Ring's circle at the tip")
	var w2 := _world([&"gun_echo", &"gun_mine"], [])
	var r2 := WorldReader.new(w2)
	W.run(w2, 70, 0, W.S)
	_view.sync(r2)
	assert_gt(_view.ghosts_shown, 0, "Echo's strikes to come show as ghosts")
	assert_eq(_view.mines_shown, 1, "a mine dropped at the tip after a second")
	var w3 := _world([&"gun_homing", &"gun_pierce"], [[Vector2(3.0, 3.0), 100000]])
	var r3 := WorldReader.new(w3)
	W.run(w3, 3, 0, W.S)
	_view.sync(r3)
	assert_gt(_view.shown, 1, "a bent beam is several ribbons")
	W.run(w3, 2, 0, 0)
	_view.sync(r3)
	assert_eq(_view.shown, 0, "let go: none")
