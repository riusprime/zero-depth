extends GutTest
## v0.9.0 LZ (owner C §6.2; PLAN C49): the Laser's view. While the beam fires, one ribbon per beam ends where the sim's
## trace ends (on the enemy, at a wall), with an impact there; each element has its own look (colours, its own strip
## texture through the beam_core_<look> manifest id with a code fallback, its impact's shape); Twin shows two ribbons;
## nothing shows when the trigger is let go; the hum loops while the beam fires. v0.11.0 O1 (Q7): the lance shows for
## half a second after each shot (drawn out fast, its glow fading), not while held.

const W := preload("res://tests/support/mx4_world.gd")

var _view: LaserView


func before_each() -> void:
	_view = add_child_autofree(LaserView.new())


func _world(items: Array = [], at: Array = [[Vector2(4.0, 0.0), 100000]]) -> World:
	var ids: Array = [&"gun_laser"]
	ids.append_array(items)
	return W.world(&"gun", ids, at)


## v0.11.0 O1 (owner Q7: "instant, drawn fast (~0.15 s), glow fading ~0.5 s"): the shot's lance, as the sim hit it,
## through the enemy to 9 m, drawn out over DRAW_TICKS, its glow fading, gone by LANCE_GLOW_TICKS (held or not).
func test_a_shot_shows_one_lance_through_the_enemy_drawn_fast_and_fading() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq([_view.shown, _view.impacts, _view.look], [1, 0, &"default"], "no wall: no impact")
	var b: Dictionary = r.beams()[0]
	assert_almost_eq(
		(b["to"] as Vector2).x, 9.0 + w.player.radius_m, 0.05, "through the enemy to 9 m"
	)
	assert_lt(_view.drawn_now, 0.5, "it starts drawing at the hero")
	W.run(w, int(LaserWeight.DRAW_TICKS) - 1, 0, W.S)  # the first sync came a tick after the shot
	_view.sync(r)
	assert_almost_eq(_view.drawn_now, 1.0, 0.001, "drawn out in 0.15 s")
	assert_almost_eq(_view.fade_now, 1.0, 0.001, "at full glow")
	W.run(w, 12, 0, W.S)
	_view.sync(r)
	assert_between(_view.fade_now, 0.01, 0.99, "the glow fades")
	W.run(w, WorldReader.LANCE_GLOW_TICKS - 21, 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 0, "gone after 0.5 s, though still held")
	assert_eq(
		LaserView.cut(PackedVector2Array([Vector2.ZERO, Vector2(4, 0)]), 0.5)[1], Vector2(2, 0)
	)


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
	W.run(w2, 10, 0, W.S)
	_view.sync(r2)
	assert_gt(_view.ghosts_shown, 0, "Echo's strike to come shows as a ghost")
	assert_eq(_view.mines_shown, 1, "a held Mine (a lab) dropped one at the tip")
	var w3 := _world([&"gun_homing"], [[Vector2(3.0, 3.0), 100000]])
	var r3 := WorldReader.new(w3)
	W.run(w3, 3, 0, W.S)
	_view.sync(r3)
	assert_eq(_view.shown, 1, "v0.10.0 FX: a bent beam is one continuous ribbon")
	assert_gt(_view.points_shown, 4, "rounded along its curve")
	W.run(w3, WorldReader.LANCE_GLOW_TICKS, 0, 0)
	_view.sync(r3)
	assert_eq(_view.shown, 0, "the glow over: none")


## v0.10.5 W3-O8 (owner F14: the Laser "doesn't feel as powerful or impactful as other attack forms"): a beam with
## weight. The ribbon is a core with a halo round it (by Effects density), its width pulses slightly, a firing starts
## with a flash (the muzzle and the impact bigger, fading in FLASH_TICKS). v0.11.0 O1d: no hit sparks any more.
func test_w3o8_the_beam_has_a_core_a_glow_a_pulse_and_a_start_flash() -> void:
	var was := ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	var w := _world()
	w.add_wall_now(Obb.make(Vector2(6.0, 0.0), Vector2(0.2, 2.0), 0))  # v0.11.0 O1: the lance's impact is a wall's
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 1)
	assert_almost_eq(_view.flash_now, 1.0, 1e-4, "a firing starts with the flash")
	var mat: ShaderMaterial = _view.get("_beam_mat")[0]
	assert_almost_eq(
		float(mat.get_shader_parameter(&"core_frac")),
		1.0 / LaserWeight.GLOW_WIDTH,
		1e-4,
		"the core"
	)
	assert_eq(float(mat.get_shader_parameter(&"glow")), LaserWeight.glow("high"), "the halo")
	var muzzle: MeshInstance3D = _view.get("_muzzle")
	var big := muzzle.scale.x
	var widths: Array[float] = []
	for k in 22:  # v0.11.0 O1: within the lance's half second of glow
		W.run(w, 1, 0, W.S)
		_view.sync(r)
		if _view.flash_now == 0.0:
			widths.append(_view.width_now)
	assert_eq(_view.flash_now, 0.0, "the flash is over")
	assert_lt(muzzle.scale.x, big, "the muzzle settles")
	assert_gt(widths.max() - widths.min(), LaserWeight.PULSE, "the width pulses")
	assert_lt(widths.max(), 1.0 + LaserWeight.PULSE + 0.001, "slightly")
	ViewPrefs.effects_density = "low"
	_view.sync(r)
	assert_eq(float(mat.get_shader_parameter(&"glow")), LaserWeight.glow("low"))
	W.run(w, 170, 0, 0)  # v0.11.0 O1: past the 3 s cooldown
	_view.sync(r)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_almost_eq(_view.flash_now, 1.0, 1e-4, "a new shot flashes again")
	ViewPrefs.effects_density = was


func test_w3o8_laser_weight_numbers() -> void:
	assert_eq(LaserWeight.flash(0.0), 1.0)
	assert_eq(LaserWeight.flash(LaserWeight.FLASH_TICKS), 0.0)
	assert_lt(LaserWeight.flash(4.0), LaserWeight.flash(2.0), "fading")


## v0.11.0 VX (owner PD-13: new effects use the premade packs): with the pack, the lance is the pack's laser of its
## element (the scene's own core, outer and ball materials) laid on one tube through the sim's points, drawn out and
## fading as the ribbon did; the ribbon and the plain impact quad hide. v0.11.0 O1d: the element is the colour only.
func test_vx_the_lance_is_the_packs_laser_on_one_tube() -> void:
	var was := ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_view.pack_fx = add_child_autofree(PackFx.new())
	var w := _world()
	w.add_wall_now(Obb.make(Vector2(6.0, 0.0), Vector2(0.2, 2.0), 0))
	var r := WorldReader.new(w)
	W.run(w, int(LaserWeight.DRAW_TICKS), 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 1)
	assert_eq(_view.tubes_shown, 1, "one tube for the lance")
	var t: LaserPackTube = _view.tubes[0]
	assert_true(t.ok, "the pack scene's parts were found")
	assert_eq(
		t.scene_path, PackFx.scene_path_of(PackLooks.laser_id(&"")), "the plain laser's scene"
	)
	assert_true(t.visible)
	var ribbons: Array = _view.get("_ribbons")
	assert_false((ribbons[0] as MeshInstance3D).visible, "the ribbon hides")
	assert_false(
		(_view.get("_impacts")[0] as MeshInstance3D).visible, "the plain impact quad hides"
	)
	W.run(w, WorldReader.LANCE_GLOW_TICKS, 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 0)
	assert_false(t.visible, "the tube goes with the lance")
	ViewPrefs.effects_density = was


## v0.11.0 O1d (owner: "element just changes the color but does not spawn the fire/frost etc particles"): with an
## element
## the lance's look changes (its colour), and the effects layer draws nothing along the ray or at its hit.
func test_o1d_an_element_is_the_colour_only() -> void:
	var layer: VfxLayer = add_child_autofree(VfxLayer.new())
	var w := W.world(&"gun", [&"gun_laser", &"ember_core"], [[Vector2(4.0, 0.0), 100000]])
	w.add_wall_now(Obb.make(Vector2(6.0, 0.0), Vector2(0.2, 2.0), 0))
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	_view.sync(r)
	assert_eq(_view.shown, 1, "the lance is drawn")
	assert_eq(_view.look, &"fire", "its look is the element's")
	layer.begin(12.0)
	_view.draw_fx(layer)
	for pool: StringName in [&"spark", &"glow", &"ember", &"flame", &"flake", &"bolt", &"bubble"]:
		assert_eq(layer.used(pool), 0, "%s: nothing along the ray or at the hit" % pool)


## v0.11.0 O1d: the lance's tube only rebuilds when its points change or its radius has moved enough.
func test_o1d_the_tube_rebuilds_only_when_it_changes() -> void:
	var t: LaserPackTube = add_child_autofree(LaserPackTube.new())
	t.ok = true
	for m in [t.get("_core"), t.get("_outer"), t.get("_start"), t.get("_end")]:
		(m as MeshInstance3D).material_override = ShaderMaterial.new()
	var pts: Array[Vector3] = [Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0.2)]
	t.lay(pts, 0.1, 0.25, 1.0, 1.0, 1.0)
	assert_eq(t.rebuilds, 1, "built")
	assert_gt((t.get("_core").mesh as ArrayMesh).get_surface_count(), 0, "a surface")
	t.lay(pts, 0.1, 0.25, 0.9, 1.0, 1.0)
	assert_eq(t.rebuilds, 1, "the glow alone doesn't rebuild it")
	t.lay(pts, 0.102, 0.255, 0.8, 1.0, 1.0)
	assert_eq(t.rebuilds, 1, "nor a small change of radius")
	t.lay(pts, 0.05, 0.12, 0.5, 1.0, 1.0)
	assert_eq(t.rebuilds, 2, "a real thinning does")
	var more: Array[Vector3] = [
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0.2), Vector3(3, 0, 0.4)
	]
	t.lay(more, 0.05, 0.12, 0.5, 1.0, 1.0)
	assert_eq(t.rebuilds, 3, "as the lance draws out")
