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
	for id: StringName in [&"archive", &"trophy", &"wardrobe", &"progression", &"credits"]:
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
		assert_true(
			g.has("halo") and g.has("pool") and g.has("light"), "%s: halo, floor pool, light" % id
		)
	assert_not_null(v.machine.portal, "the machine's swirling portal")
	assert_not_null(v.machine.get_node_or_null("Motes"), "and its motes")


func test_focus_brightens_the_station() -> void:
	var v := _view({})
	v.focus(&"archive")
	var arch: Dictionary = v.stations[&"archive"]["glow"]
	var cred: Dictionary = v.stations[&"credits"]["glow"]
	assert_gt(
		(arch["light"] as OmniLight3D).light_energy, (cred["light"] as OmniLight3D).light_energy
	)
	v.focus(HubLayout.MACHINE)
	assert_eq(v.machine.focus, 1.0, "the machine wakes when the hero stands at it")


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


func test_the_small_menu_and_the_end_panel_rows() -> void:
	var m := MainMenu.new("v", false)
	add_child_autofree(m)
	var rows := []
	for c in m.box.get_children():
		if c is Button:
			rows.append(String(c.name))
	assert_eq(rows, ["Continue", "Play", "Options", "Quit"])
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
