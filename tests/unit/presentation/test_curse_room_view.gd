extends GutTest
## v0.8.0 N17 (owner O75) and N19 (owner O80): the curse device. No name floats over any pedestal (the curse altar
## included): it shows only in the panel interact opens, and the altar's prompt doesn't name it. The curse room's altar
## is its own model (a dark stone altar with a cracked crystal; the owner's `curse_altar`, delivered 2026-10-18,
## replaces the stone through the manifest; a soft cold-violet light on its crystal pulses with the sigils) in a dark
## room: a shroud over its floor, a cold light, glowing slowly (steady under reduced motion), fading to embers once its
## choice is taken. N19: the four purple ritual sigils (fx_cast_sigils, not the element glyphs), crystal clusters on
## the sim's footprints, and no loose dressing from the room dresser inside it.

const TEST_MANIFEST := "user://test_curse_manifest.json"


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ShopModels.manifest = ShopModels.MANIFEST
	ShopModels.clear_cache()
	if FileAccess.file_exists(TEST_MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_MANIFEST))


## A floor with a curse room (EventLab's run seeds 300..; the first that has one).
func _world() -> World:
	for s in 60:
		var w := EventLab.world(300 + s)
		if w.ev.curse_k >= 0:
			return w
	fail_test("no floor with a curse room")
	return null


func _view(w: World) -> EventPedestalViews:
	var reader := WorldReader.new(w)
	var view := EventPedestalViews.new()
	add_child_autofree(view)
	view.setup(reader)
	view.sync(reader)
	return view


func test_no_name_floats_over_a_pedestal_or_the_altar() -> void:
	var w := _world()
	if w == null:
		return
	var view := _view(w)
	assert_eq(view.pedestal_count(), w.ev.size())
	assert_eq(view.label_count(), 0, "no Label3D over any pedestal")
	for k in w.ev.size():
		w.actors.set_pos(0, w.ev.pos(k))
		view.sync(WorldReader.new(w))
		assert_eq(view.label_count(), 0, "not even when you stand by it")
	var plain := _view(EventLab.world(3))
	assert_eq(plain.label_count(), 0, "a floor without a curse room neither")


func test_the_altar_is_its_own_dark_model_in_a_dark_pact_room() -> void:
	var w := _world()
	if w == null:
		return
	_stand_ins()
	var view := _view(w)
	var k := w.ev.curse_k
	var root := view.pedestal_root(k)
	assert_eq(root.name, &"CurseAltar", "the altar's own model")
	assert_false(view.curse_uses_model, "the code-made stand-in (no curse_altar model listed)")
	assert_null(root.get_node_or_null("Model"))
	for j in w.ev.size():
		if j != k:
			assert_ne(view.pedestal_root(j).name, &"CurseAltar", "the other pedestals keep theirs")
	var room := view.curse_room
	assert_not_null(room, "the room is dressed")
	var rect := w.floor_layout.rooms[w.ev.room[k]]
	assert_not_null(room.shroud, "a dark shroud over its floor")
	assert_eq(SimPlane.to_sim(room.shroud.position), rect.get_center(), "over the curse room")
	var veil := (room.shroud.material_override as StandardMaterial3D).albedo_color
	assert_lt(veil.get_luminance(), 0.05, "dark")
	assert_gte(veil.a, 0.75, "darker than N17's veil (0.62)")
	assert_lt(room.cold.light_energy, 0.5, "a low light")
	assert_false(room.cold.shadow_enabled, "no shadow (the light budget)")
	assert_gt(room.cold.light_color.b, room.cold.light_color.r, "a cold one")
	for s in room.sigils:
		assert_true(rect.has_point(SimPlane.to_sim(s.position)), "inside the room")
	var a := room.glow_of(0)
	var turn := room.turn_of(0)
	room._process(1.0)
	assert_ne(room.glow_of(0), a, "the sigils glow slowly")
	assert_ne(room.turn_of(0), turn, "and turn")
	var none := _view(EventLab.world(3))
	if EventLab.world(3).ev.curse_k < 0:
		assert_null(none.curse_room, "no dressing without a curse room")


## v0.8.0 N19 (O80: "you misstok the right glyphs I meant the purple ones that some enemies use and we have 4 of
## those"): the four ritual sigils of fx_cast_sigils, not the element glyphs: one large under the altar, the other three
## in a ring round it, and the four on the walls.
func test_the_four_purple_ritual_sigils_not_the_element_glyphs() -> void:
	var w := _world()
	if w == null:
		return
	var room := _view(w).curse_room
	var sheet := FxTextures.get_tex("fx_cast_sigils")
	assert_not_null(sheet, "the owner's sigil sheet is installed")
	assert_true(room.uses_sheet, "drawn from it")
	assert_eq(room.floor_count, 1 + CurseRoomView.RING_COUNT, "the big one and the ring of three")
	assert_gt(room.sigils.size(), room.floor_count, "and sigils on the walls")
	var used := {}
	for j in room.sigils.size():
		var m := room.sigils[j].material_override as ShaderMaterial
		assert_not_null(m, "sigil %d: the sigil shader" % j)
		if m == null:
			continue
		assert_eq(m.get_shader_parameter("sheet"), sheet, "sigil %d: fx_cast_sigils" % j)
		used[int(m.get_shader_parameter("cell"))] = true
	assert_eq(used.size(), 4, "all four sigils")
	var code := (room.sigils[0].material_override as ShaderMaterial).shader.code
	assert_ne(
		code.find("fog_disabled"),
		-1,
		"out of the biome's fog (Frozen Shore's turned them into pale squares)"
	)
	assert_true((room.shroud.material_override as StandardMaterial3D).disable_fog, "the veil too")
	var big := room.sigils[0]
	assert_eq(room.cells[0], 0, "the large one")
	assert_almost_eq(
		SimPlane.to_sim(big.position).distance_to(w.ev.pos(w.ev.curse_k)),
		0.0,
		0.01,
		"under the altar"
	)
	assert_gt((big.mesh as QuadMesh).size.x, 3.0, "large")
	assert_eq(
		room.find_children("*", "Sprite3D", true, false).size(),
		0,
		"no glyph sprite anywhere in the room"
	)
	var src := FileAccess.get_file_as_string("res://src/presentation/world_view/curse_room_view.gd")
	assert_eq(src.find("ElementGlyphs"), -1, "the element glyph sheets are not used")


func test_crystal_clusters_stand_on_the_sims_crystal_footprints() -> void:
	var w := _world()
	if w == null:
		return
	var room := _view(w).curse_room
	var list := WorldReader.new(w).curse_room_crystals()
	assert_gt(list.size(), 0, "the sim placed crystals")
	assert_eq(room.crystals.size(), list.size(), "one cluster each")
	for i in list.size():
		assert_almost_eq(
			SimPlane.to_sim(room.crystals[i].position).distance_to(list[i][0]), 0.0, 0.01
		)
		assert_gte(room.crystals[i].get_child_count(), 3, "a cluster of crystals")
	assert_gt(room.glow_mats.size(), 0, "some glow")
	var e := room.glow_mats[0].emission_energy_multiplier
	room._process(1.0)
	assert_ne(room.glow_mats[0].emission_energy_multiplier, e, "pulsing with the sigils")


func test_the_dresser_leaves_the_pact_room_alone() -> void:
	var room := Rect2(0, 0, 10, 8)
	var at := func(p: Vector2) -> Transform3D: return Transform3D(Basis(), SimPlane.to_3d(p))
	var placements: Array = [
		{"piece": &"rubble_small", "xform": at.call(Vector2(5, 4)), "wall": -1, "kind": &"decor"},
		{"piece": &"fire_barrel", "xform": at.call(Vector2(0.1, 4)), "wall": 3, "kind": &"light"},
		{"piece": &"crate", "xform": at.call(Vector2(5, -2)), "wall": 9, "kind": &"cover"},
		{"piece": &"rubble_small", "xform": at.call(Vector2(20, 4)), "wall": -1, "kind": &"decor"},
	]
	var kept := CurseRoomView.strip(placements, room)
	assert_eq(kept.size(), 2, "its loose decoration and wall light go")
	assert_eq(kept[0]["kind"], &"cover", "walls and other rooms stay")
	assert_eq(CurseRoomView.strip(placements, Rect2()).size(), 4, "no curse room: untouched")


func test_reduced_motion_holds_the_glow_and_a_taken_altar_fades() -> void:
	var w := _world()
	if w == null:
		return
	ViewPrefs.reduced_motion = true
	var view := _view(w)
	var room := view.curse_room
	var a := room.glow_of(1)
	room._process(1.0)
	assert_eq(room.glow_of(1), a, "steady under reduced motion")
	var k := w.ev.curse_k
	view._process(0.1)
	var lit := view.glyph_energy(k)
	EventLab.open(w, k)
	var t := Events.table(w, k)
	EventLab.pick(w, t.choice_count())  # the last choice
	if w.ev.state[k] == Events.State.READY:
		EventLab.open(w, k)
		EventLab.pick(w, 1)
	assert_eq(w.ev.state[k], Events.State.DONE, "its choice taken")
	view._process(0.1)
	assert_lt(view.glyph_energy(k), lit * 0.2, "the altar's crystal goes dark")
	assert_eq(room.glow_of(0), CurseRoomView.SPENT_GLOW, "the sigils fade to embers")


func test_the_prompt_does_not_name_it_and_the_panel_does() -> void:
	var w := _world()
	if w == null:
		return
	var k := w.ev.curse_k
	var reader := WorldReader.new(w)
	var hud := EventHud.new()
	add_child_autofree(hud)
	w.actors.set_pos(0, w.ev.pos(k))
	hud.sync(reader)
	var name := tr(Events.table(w, k).name_key)
	assert_eq(hud.prompt_text(), tr("UI_CURSE_ALTAR_OPEN"), "a plain prompt by the altar")
	assert_eq(hud.prompt_text().find(name), -1, "without its name")
	EventLab.open(w, k)
	hud.sync(reader)
	assert_true(hud.panel.is_open(), "interact opens its panel")
	assert_eq(hud.panel.title_text(), name, "the name shows there")
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		assert_ne(tr("UI_CURSE_ALTAR_OPEN"), "UI_CURSE_ALTAR_OPEN", "%s: translated" % lang)
	TranslationServer.set_locale("en")


## The fallback: a manifest that lists nothing.
func _stand_ins() -> void:
	var f := FileAccess.open(TEST_MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify({"models": []}))
	f.close()
	ShopModels.manifest = TEST_MANIFEST
	ShopModels.clear_cache()


func test_the_owners_delivered_altar_is_drawn_with_a_soft_pulsing_light() -> void:
	var model := ShopModels.get_model(&"curse_altar")
	assert_false(model.is_empty(), "the manifest lists the owner's curse_altar")
	if model.is_empty():
		return
	var box: AABB = model["aabb"]
	assert_almost_eq(box.size.y, 0.98, 0.01, "0.98 m high")
	assert_lte(box.size.x, 1.41, "inside its 1.4 m box")
	assert_lte(box.size.z, 1.41)
	assert_almost_eq(box.position.y, 0.0, 0.01, "on the floor")
	var tris := (model["mesh"] as ArrayMesh).surface_get_array_index_len(0) / 3
	assert_lte(tris, 4000, "decimated (%d triangles)" % tris)
	var w := _world()
	if w == null:
		return
	var view := _view(w)
	assert_true(view.curse_uses_model, "the altar draws the owner's model")
	assert_not_null(view.pedestal_root(w.ev.curse_k).get_node_or_null("Model"))
	var light := view.curse_light()
	assert_not_null(light, "a light on the floating crystal")
	assert_false(light.shadow_enabled, "no shadow (the light budget)")
	assert_lte(light.omni_range, 3.0, "short")
	assert_true(light.distance_fade_enabled, "fades out off screen")
	assert_gt(light.light_color.b, light.light_color.g, "cold violet")
	view._process(0.3)
	var a := light.light_energy
	view._process(1.0)
	assert_ne(light.light_energy, a, "it pulses with the glyphs")
	assert_lt(maxf(a, light.light_energy), 1.2, "low")
	ViewPrefs.reduced_motion = true
	view._process(0.5)
	var b := light.light_energy
	view._process(0.5)
	assert_eq(light.light_energy, b, "steady under reduced motion")


func test_the_owners_model_replaces_the_stone_when_listed() -> void:
	var listing := {"models": [{"id": "curse_altar", "path": "assets/models/kit/crate_stack.glb"}]}
	var f := FileAccess.open(TEST_MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(listing))
	f.close()
	ShopModels.manifest = TEST_MANIFEST
	ShopModels.clear_cache()
	var model := ShopModels.get_model(&"curse_altar")
	assert_false(model.is_empty(), "the listed model loads")
	assert_almost_eq((model["aabb"] as AABB).size.y, 0.98, 0.01, "scaled to the altar height")
	var w := _world()
	if w == null:
		return
	var view := _view(w)
	assert_true(view.curse_uses_model, "the altar draws the model")
	assert_not_null(view.pedestal_root(w.ev.curse_k).get_node_or_null("Model"))


## v0.8.0 N19 (N17's shots): the "Cursed" mark on a curse choice stays on one line, and the floor's phase line ("They
## stir") no longer shows behind the panel's title.
func test_the_panel_keeps_the_cursed_mark_on_one_line_and_hides_the_phase_line() -> void:
	var w := _world()
	if w == null:
		return
	var k := w.ev.curse_k
	var reader := WorldReader.new(w)
	var phase := PhaseHud.new()
	add_child_autofree(phase)
	phase.sync(reader)
	var had_line := phase.visible
	var hud := EventHud.new()
	add_child_autofree(hud)
	EventLab.open(w, k)
	hud.sync(reader)
	phase.sync(reader)
	assert_true(hud.panel.is_open())
	assert_false(phase.visible, "no phase line under the open panel")
	var heads := hud.panel.find_children("CursedHead", "Label", true, false)
	assert_gt(heads.size(), 0, "a curse choice wears the mark")
	await get_tree().process_frame
	await get_tree().process_frame
	for l: Label in heads:
		assert_eq(l.autowrap_mode, TextServer.AUTOWRAP_OFF, "never wrapped")
		assert_eq(l.get_line_count(), 1, "one line")
		var one := l.get_theme_font("font").get_height(l.get_theme_font_size("font_size"))
		assert_lt(l.size.y, one * 1.6, "one line high")
		assert_gt(l.size.x, l.size.y, "wider than high")
	EventLab.pick(w, InputFrame.PICK_CANCEL)
	hud.sync(reader)
	phase.sync(reader)
	assert_eq(phase.visible, had_line, "back once the panel closes")
