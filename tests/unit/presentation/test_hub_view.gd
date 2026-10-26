extends GutTest
## v0.9.0 HB: the hub's view and menus. The Rune Ring draws every station, the machine, the 16 floor runes and the
## sealed gate from its plan; its glows are layered (a halo, a floor pool and a light each: the VX bar); the evolving
## states and the hooks (runes, gate, Archive shelf, robe) change what is drawn; the small menu; the end panel.

var _repo: ContentRepository
var _hub: HubDefinition


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_hub = _repo.get_def(&"hub", &"rune_ring")


func _view(states: Dictionary, trophies: Array[bool] = [false, true]) -> HubView:
	var l := HubLayout.new(_hub, bool(states.get(&"gate_open", false)))
	var w := HubScenario.build(_repo, l, &"blade")
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	var v := HubView.new()
	add_child_autofree(v)
	v.setup(WorldReader.new(w), l, states, trophies, biome.mood, biome.palette, "low")
	return v


func test_every_station_and_the_machine_are_drawn() -> void:
	var v := _view({})
	for id: StringName in [&"archive", &"trophy", &"wardrobe", &"progression", &"runic"]:
		assert_true(v.stations.has(id), "%s is drawn" % id)
		assert_not_null(v.plan.get_node_or_null("Station_%s" % id))
	assert_not_null(v.machine.altar, "the stand-in machine stands on SA's altar")
	assert_eq(v.runes.size(), 16, "16 floor runes")
	assert_false(v.gate_open(), "the north gate is sealed")
	assert_eq((v.stations[&"trophy"]["plaques"] as Array).size(), 2, "a plinth per floor boss")
	var lit_plaques := (v.stations[&"trophy"]["plaques"] as Array).filter(
		func(m: MeshInstance3D) -> bool: return bool(m.get_meta(&"lit"))
	)
	assert_eq(lit_plaques.size(), 1, "the fallen boss's plaque is lit")
	assert_false(
		(v.stations[&"trophy"]["crown"] as Node3D).visible, "no crown before the final boss"
	)


func test_the_glows_are_layered() -> void:
	var v := _view({})
	for id: StringName in v.stations:
		var g: Dictionary = v.stations[id]["glow"]
		if id == &"runic":  # v0.9.5 RS1: the Runic Stone has no halo (its veins are a ring)
			continue
		assert_true(
			g.has("halo") and g.has("pool") and g.has("light"), "%s: halo, floor pool, light" % id
		)
	assert_not_null(v.machine.portal, "the machine's swirling portal")
	assert_not_null(v.machine.get_node_or_null("Motes"), "and its motes")


func test_focus_brightens_the_station() -> void:
	var v := _view({})
	v.focus(&"archive")
	var arch: Dictionary = v.stations[&"archive"]["glow"]
	assert_gt((arch["light"] as OmniLight3D).light_energy, 0.0)
	assert_true(
		(v.stations[&"runic"]["glow"] as Dictionary).is_empty(), "the Runic Stone has no halo"
	)
	v.focus(HubLayout.MACHINE)
	assert_eq(v.machine.focus, 1.0, "the machine wakes when the hero stands at it")


## v0.9.5 RS1 (RUNIC_STONE.md S2, S3): locked, the stone is dark (no veins, no light); awake, its veins glow violet and
## a pulse flares them once and settles.
func test_the_runic_stone_is_dark_locked_and_violet_awake() -> void:
	var v := _view({})
	var st: Dictionary = v.stations[&"runic"]
	assert_false(v.runic_lit(), "locked: no veins")
	assert_eq((st["light"] as OmniLight3D).light_energy, 0.0)
	v.set_runic(true)
	assert_true(v.runic_lit(), "awake: the veins are lit")
	var mat := (st["ring"] as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(mat.emission, HubStations.RUNE_VIOLET, "violet #9B6BFF")
	var calm := mat.emission_energy_multiplier
	v.pulse_runic()
	v._advance_pulse(HubView.PULSE_S * 0.5)
	assert_gt(mat.emission_energy_multiplier, calm, "the pulse flares them")
	v._advance_pulse(HubView.PULSE_S)
	assert_eq(mat.emission_energy_multiplier, calm, "and they settle")
	v.set_runic(false)
	assert_false(v.runic_lit())


func test_the_states_and_hooks_change_the_hub() -> void:
	var runes: Array[bool] = []
	for i in 16:
		runes.append(i < 4)
	var v := _view(
		{&"gate_open": true, &"machine_looped": true, &"trophy_crown": true, &"runes": runes}
	)
	assert_true(v.gate_open(), "the gate opens on its flag")
	assert_true(v.machine.outer.visible, "an Ascension adds the machine's violet ring")
	assert_true(
		(v.stations[&"trophy"]["crown"] as Node3D).visible, "the crown after the final boss"
	)
	assert_true(v.rune_lit(3) and not v.rune_lit(4), "the first four runes lit")
	v.set_runes([true, true])
	assert_true(v.rune_lit(1) and not v.rune_lit(2), "CL's hook relights them")
	v.show_collected(5)
	var slots: Array = v.stations[&"archive"]["slots"]
	assert_eq(slots.size(), 16, "the Archive's 16 shelf slots")
	assert_true(bool(slots[4].get_meta(&"lit")) and not bool(slots[5].get_meta(&"lit", false)))
	v.set_robe(Color("#3A4A6B"))  # RB's hook: a no-op while the robe is part of the owner's wardrobe mesh
	var robe := v.stations[&"wardrobe"]["robe"] as MeshInstance3D
	if robe != null:
		assert_eq((robe.material_override as StandardMaterial3D).albedo_color, Color("#3A4A6B"))
	else:
		assert_not_null(v.stations[&"wardrobe"]["model"], "the owner's wardrobe draws the robe")


## v0.9.0 CL: the Archive's niches light per collectible found, in its colour; the Keystone on the alcove's pedestal is
## layered (a faceted stone, a core, a halo, a floor glow, a light, motes) and goes when taken.
func test_the_shelf_lights_each_find_and_the_keystone_waits() -> void:
	var v := _view({&"gate_open": true})
	var found: Array[bool] = []
	var colors: Array[Color] = []
	for k in 16:
		found.append(k == 2 or k == 9)
		colors.append(Color(1, 0.2, 0.2))
	v.show_found(found, colors)
	var slots: Array = v.stations[&"archive"]["slots"]
	assert_true(bool(slots[2].get_meta(&"lit")) and bool(slots[9].get_meta(&"lit")))
	assert_false(bool(slots[3].get_meta(&"lit")), "the rest stay dark")
	var m := (slots[9] as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(m.emission, Color(1, 0.2, 0.2), "in its own colour")
	assert_false(v.keystone_shown(), "nothing on the pedestal until set")
	v.set_keystone(true, Color(0.6, 0.8, 1))
	assert_true(v.keystone_shown())
	var g := v.keystone as CollectibleLooks
	assert_not_null(g.stone, "a faceted stone")
	assert_not_null(g.core, "a hot core")
	for part: String in ["halo", "pool", "light"]:
		assert_not_null(g.glow.get(part), "its glow's %s" % part)
	assert_not_null(g.motes, "motes")
	v.set_keystone(false)
	assert_false(v.keystone_shown(), "taken: gone")


## The owner's hub models (delivered 2026-10-22, listed in assets/models/manifest.json) draw the machine and the
## stations; their code stand-ins hide; the code's glows stay on them.
func test_the_owners_models_are_drawn() -> void:
	var v := _view({})
	assert_not_null(v.machine.model, "hub_portal_machine")
	assert_false(v.machine.stand_in.visible, "the stand-in altar and ring hide")
	assert_not_null(v.machine.portal, "the code's portal fills his ring")
	for id: StringName in [&"archive", &"wardrobe", &"progression"]:
		assert_not_null(v.stations[id]["model"], "%s: the owner's model" % id)
		var si := (v.stations[id]["root"] as Node3D).get_node_or_null("StandIn") as Node3D
		assert_false(si.visible, "%s: its stand-in hides" % id)
	var trophy_root := v.stations[&"trophy"]["root"] as Node3D
	var pedestals := trophy_root.get_children().filter(
		func(n: Node) -> bool: return n.get_meta(&"model_id", &"") == &"hub_trophy_pedestal"
	)
	assert_eq(pedestals.size(), 2, "a hub_trophy_pedestal per floor boss")


## v0.9.0 HB3: the owner's eight hub pieces (delivered 2026-10-23) dress the Rune Ring: his wall round the plaza (11
## segments, the north slot the gate's), his pillar braziers each with a layered fire, his gate (its doors apart, hidden
## when it opens), his 16 floor runes, the crates and planters, the trophy wall and the credits stone; the floor is his
## paving, medallion and walkway; every station faces the plaza's middle.
func test_the_owners_hub_pieces_dress_the_ring() -> void:
	var v := _view({})
	var ids := {}
	for n: Node in v.plan.find_children("*", "MeshInstance3D", true, false):
		var id: StringName = n.get_meta(&"model_id", &"")
		if id != &"":
			ids[id] = int(ids.get(id, 0)) + 1
	assert_eq(ids.get(&"hub_wall_segment", 0), 11, "11 wall segments")
	assert_eq(ids.get(&"hub_pillar_brazier", 0), _hub.pillars.size(), "a pillar per spot")
	assert_eq(ids.get(&"hub_floor_rune", 0), 16, "16 floor runes")
	assert_eq(ids.get(&"hub_sealed_gate", 0), 1, "the gate")
	assert_eq(ids.get(&"hub_sealed_gate_doors", 0), 1, "its doors")
	assert_eq(ids.get(&"hub_crates", 0) + ids.get(&"hub_crystal_planter", 0), _hub.props.size())
	assert_eq(ids.get(&"hub_trophy_wall", 0), 1, "the trophy wall behind the pedestals")
	assert_eq(ids.get(&"hub_credits_stone", 0), 1, "the credits stone")
	assert_eq(v.fires.size(), _hub.pillars.size(), "a fire per pillar")
	for f: Dictionary in v.fires:
		assert_true(
			f.has("halo") and f.has("pool") and f.has("light") and f.has("flames"),
			"a fire is layered: flames, halo, floor pool, light"
		)
	assert_not_null(v.plan.get_node_or_null("Medallion"), "the centre medallion")
	assert_not_null(v.plan.get_node_or_null("Paths/Ring"), "the walkway round it")
	for s in _hub.stations:
		var root := v.stations[s.id]["root"] as Node3D
		assert_almost_eq(
			root.rotation.y, HubLayout.facing(s.at), 1e-4, "%s faces the middle" % s.id
		)
	var open := _view({&"gate_open": true})
	assert_false(open.gate_seal.visible, "open: the doors are gone")


## v0.9.0 HB2: the walk into the portal: the hero climbs the steps (its node rises), the portal flares, the hero
## shrinks into the ring, and walk_finished fires once, in about 2-3 s; the World is never stepped by it.
func test_the_walk_into_the_portal() -> void:
	var v := _view({})
	watch_signals(v)
	var tick := v.reader.tick()
	var length := v.walk_into_portal()
	assert_between(length, 1.8, 3.2, "about 2-3 s")
	var top := 0.0
	for k in int(length * 60.0) + 2:
		v._advance_walk(1.0 / 60.0)
		top = maxf(top, v.hero.position.y)
	assert_gt(top, 1.0, "up the machine's steps")
	assert_gt(v.machine.flare, 0.9, "the portal flares")
	assert_false(v.hero.visible, "the hero is through the ring")
	assert_signal_emit_count(v, "walk_finished", 1)
	assert_eq(v.reader.tick(), tick, "the World holds")


func test_the_small_menu_and_the_end_panel_rows() -> void:
	var m := MainMenu.new("v", false)
	add_child_autofree(m)
	var rows := []
	for c in m.box.get_children():
		if c is Button:
			rows.append(String(c.name))
	assert_eq(rows, ["Continue", "Play", "Options", "Credits", "Quit"])  # v0.9.5 RS1: Credits is back
	assert_true((m.box.get_node("Continue") as Button).disabled)
	var with_save := MainMenu.new("v", true)
	add_child_autofree(with_save)
	assert_false((with_save.box.get_node("Continue") as Button).disabled)
	var end := EndPanel.new(false, 0)
	add_child_autofree(end)
	assert_not_null(end.box.get_node_or_null("Restart"))
	assert_eq(
		(end.box.get_node("Hub") as Button).text, "UI_TO_HUB", "the second row goes to the hub"
	)
	var panel := HubStationPanel.new(&"wardrobe", "HUB_WARDROBE", "HUB_WARDROBE_SOON")
	add_child_autofree(panel)
	assert_eq(panel.name, &"HubPanel_wardrobe")
	assert_not_null(panel.box.get_node_or_null("Back"))
