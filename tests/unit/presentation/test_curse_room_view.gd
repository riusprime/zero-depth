extends GutTest
## v0.8.0 N17 (owner O75): the curse device. No name floats over any pedestal (the curse altar included): it shows
## only in the panel interact opens, and the altar's prompt doesn't name it. The curse room's altar is its own model (a
## dark stone altar with a cracked crystal; the owner's `curse_altar`, delivered 2026-10-18, replaces the stone through
## the manifest; a soft cold-violet light on its crystal pulses with the glyphs) in a dark room: a shroud over its
## floor, a cold light, the owner's glyphs round the altar and along the walls, glowing slowly (steady under
## reduced motion), fading to embers once its choice is taken.

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


func test_the_altar_is_its_own_dark_model_in_a_dark_glyph_room() -> void:
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
	assert_lt(
		(room.shroud.material_override as StandardMaterial3D).albedo_color.get_luminance(),
		0.05,
		"dark"
	)
	assert_lt(room.cold.light_energy, 1.0, "a low light")
	assert_gt(room.cold.light_color.b, room.cold.light_color.r, "a cold one")
	assert_eq(room.floor_count, CurseRoomView.RING_COUNT, "a ring of glyphs round the altar")
	assert_gt(room.sigils.size(), room.floor_count, "and sigils along the walls")
	assert_true(room.sigils[0] is Sprite3D, "the owner's glyph sheets")
	for s in room.sigils:
		assert_true(rect.has_point(SimPlane.to_sim(s.position)), "inside the room")
	var a := room.glow_of(0)
	room._process(1.0)
	assert_ne(room.glow_of(0), a, "the glyphs glow slowly")
	var none := _view(EventLab.world(3))
	if EventLab.world(3).ev.curse_k < 0:
		assert_null(none.curse_room, "no dressing without a curse room")


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
	Stats.add_card(w, Stats.Stat.DAMAGE, 0)  # test setup: a raised stat (the curse events need one)
	EventLab.open(w, k)
	var t := Events.table(w, k)
	EventLab.pick(w, t.choice_count())  # the last choice
	if w.ev.state[k] == Events.State.READY:
		EventLab.open(w, k)
		EventLab.pick(w, 1)
	assert_eq(w.ev.state[k], Events.State.DONE, "its choice taken")
	view._process(0.1)
	assert_lt(view.glyph_energy(k), lit * 0.2, "the altar's crystal goes dark")
	assert_eq(room.glow_of(0), CurseRoomView.SPENT_GLOW, "the glyphs fade to embers")


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
