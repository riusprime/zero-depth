extends GutTest
## v0.9.0 LK (owner Q21: "a visible seal with a sound"; FV, MI2: the owner's bar gate is `lockdown_seal`): the
## Lockdowns' view on a whole floor's view (WorldViewRoot, the Ruins kit). The owner's bars wait unseen above every
## doorway of every Lockdown room; on the seal they come down into the doorways with `lockdown_close` (captioned) and
## the banner reads LOCKDOWN with the formation and the enemies left; on the clear they rise out of sight with
## `lockdown_open` and the banner says the exits are open. A Hazard Lockdown shows each strike's ground warning before
## it lands, and the biome's hazard (Ruins: the sparking cable, a stand-in until its model arrives).


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	v.stage.prop_style = biome.id
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func _ids(reqs: Array) -> Array:
	var out: Array = []
	for r: Array in reqs:
		out.append(r[0])
	return out


func test_the_bars_drop_on_the_seal_and_rise_on_the_clear() -> void:
	var w := LockLab.world()
	assert_not_null(w, "a floor with a Lockdown")
	if w == null:
		return
	w.floor_layout.lockdown_kinds[0] = WorldReader.LOCKDOWN_NORMAL  # forced: this floor's first is a Hazard one
	var v := _view(w)
	var reader := v.reader
	var l := v.lockdowns
	assert_not_null(l, "the view is built")
	var r := LockLab.room(w)
	assert_eq(
		l.door_count(r), ArenaRooms.doors_of(w.floor_layout, r).size(), "bars for each doorway"
	)
	assert_eq(
		l.uses_model, ShopModels.listed_path(&"lockdown_seal") != "", "the owner's bars when listed"
	)
	assert_true(l.uses_model, "lockdown_seal is installed")
	assert_false(l.bars_visible(r), "open: unseen above the doorways")
	var cues := AudioEvents.new()
	cues.prime(reader)
	var hud := LockdownHud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	assert_false(hud.visible, "no banner before the seal")
	LockLab.enter(w, r)
	v.sync()
	hud.sync(reader)
	assert_true(_ids(cues.collect(reader)).has(&"lockdown_close"), "the seal's sound")
	l._process(LockdownView.DROP_S * 0.5)
	assert_between(l.bars_down(r), 0.3, 0.7, "sliding down")
	assert_true(l.bars_visible(r), "in sight as they come down")
	l._process(LockdownView.DROP_S)
	assert_eq(l.bars_down(r), 1.0, "in the doorways")
	assert_true(l.take_thud(), "they slam home (the camera's thud)")
	assert_false(l.take_thud(), "once")
	assert_true(hud.visible, "the banner")
	assert_eq(hud.title.text, tr("HUD_LOCKDOWN"))
	LockLab.to_wave(w)
	hud.sync(reader)
	assert_string_contains(hud.progress.text, "1 / %d" % w.lockdown.waves, false)
	LockLab.clear(w)
	v.sync()
	hud.sync(reader)
	assert_true(_ids(cues.collect(reader)).has(&"lockdown_open"), "the open's sound")
	assert_eq(hud.progress.text, tr("HUD_LOCKDOWN_CLEARED"), "the exits are open")
	l._process(LockdownView.RISE_S + 0.1)
	assert_eq(l.bars_down(r), 0.0, "risen")
	assert_false(l.bars_visible(r), "out of sight")
	for key in [&"CAPTION_LOCKDOWN_CLOSE", &"CAPTION_LOCKDOWN_OPEN", &"HUD_LOCKDOWN"]:
		assert_ne(TranslationServer.translate(key), String(key), "%s is a string" % key)


func test_a_hazard_lockdown_shows_its_warning_and_its_hazard() -> void:
	var w := LockLab.world()
	if w == null:
		return
	w.floor_layout.lockdown_kinds[0] = WorldReader.LOCKDOWN_HAZARD  # forced, before the view is built
	var v := _view(w)
	var l := v.lockdowns
	assert_eq(l.hazard_id, &"hazard_cable", "Ruins: the sparking cable")
	assert_false(l.hazard_uses_model, "a stand-in until the owner's model arrives")
	var r := LockLab.room(w)
	LockLab.enter(w, r)
	var hud := LockdownHud.new()
	add_child_autofree(hud)
	hud.sync(v.reader)
	assert_eq(hud.title.text, tr("HUD_LOCKDOWN_HAZARD"))
	var s := w.lockdown
	while s.strike_pos.is_empty() and w.tick - s.sealed_tick < 600:
		w.step(InputFrame.new())
	v.sync()
	assert_eq(l.warnings_shown(), 1, "the strike's ground warning")
	while s.landed_tick < 0 and w.tick - s.sealed_tick < 900:
		w.step(InputFrame.new())
	v.sync()
	assert_eq(l.warnings_shown(), 0, "gone as it lands")
	assert_true(v.lockdowns.get_node("Hazard").visible, "the hazard where it landed")
	for biome in LockdownView.HAZARDS:
		assert_true(
			ShopModels.SPECS.has(LockdownView.HAZARDS[biome]), "%s's hazard looked up by id" % biome
		)
