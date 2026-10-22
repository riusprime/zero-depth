extends GutTest
## v0.7.5 AP: the Ascension portal's views (v0.8.0 P2: the choice panel is gone; the Loop device stands beside the
## portal); the portal has its own look (gold-white and lavender, never the
## visor blue or the Deep violet) and its column rises when the portal opens; the HUD, pause line and recap say
## "Loop N · " past the first loop, and the recap counts the loops cleared.


## v0.8.0 P2 (owner O28): the Loop device has its own look (green, apart from the portal's gold and lavender, the
## gate's blue and Deep's violet), smaller than the portal; dormant until the portal opens, then lit and turning;
## reduced motion holds its turn. v0.8.0 N18 (owner O76): no floating name, ever (P2's "Loop" label removed).
func test_p2_the_loop_device_has_its_own_look_and_lights_when_open() -> void:
	var d := LoopDevice.new()
	add_child_autofree(d)
	d.setup(Vector2(1.0, 2.0), 0, 0.9)
	assert_true(d.is_sealed(), "dormant at first")
	for c: Color in [LoopDevice.GREEN]:
		for other: Color in [
			PortalGate.visor_blue(),
			PortalGate.DEEP_VIOLET,
			PortalGate.DEEP_RIM,
			AscensionPortal.GOLD,
			AscensionPortal.LAVENDER,
			AscensionPortal.CORE,
		]:
			assert_gt(
				_dist(c, other), 0.25, "%s reads apart from %s" % [c.to_html(), other.to_html()]
			)
	assert_lt(
		LoopDevice.RING_Y + LoopDevice.RING_R,
		AscensionPortal.COLUMN_H * 0.25,
		"smaller than the portal"
	)
	var dim := d.light.light_energy
	d.calm = false
	d.set_sealed(false)
	assert_eq(
		d.find_children("*", "Label3D", true, false).size(), 0, "no floating name once open (O76)"
	)
	d._process(0.5)
	assert_gt(d.light.light_energy, dim, "lit")
	assert_gt(d.chase, 0.0, "its arrowheads chase round the ring")
	var calm := LoopDevice.new()
	add_child_autofree(calm)
	calm.setup(Vector2.ZERO, 0, 0.9)
	calm.calm = true
	calm.set_sealed(false)
	calm._process(0.5)
	assert_eq(calm.chase, 0.0, "reduced motion: they stand")


func test_the_portal_has_its_own_look_and_its_column_rises() -> void:
	var p := AscensionPortal.new()
	add_child_autofree(p)
	p.calm = false
	assert_true(p.is_sealed(), "dormant at first")
	assert_false(p.column.visible, "no column while the boss lives")
	for c: Color in [AscensionPortal.GOLD, AscensionPortal.LAVENDER, AscensionPortal.CORE]:
		for other: Color in [PortalGate.visor_blue(), PortalGate.DEEP_VIOLET, PortalGate.DEEP_RIM]:
			assert_gt(_dist(c, other), 0.25, "%s reads apart from the other portals" % c.to_html())
	p.set_sealed(false)
	assert_false(p.is_sealed())
	assert_eq(p.rise, 0.0, "the column starts at the dais")
	p._process(AscensionPortal.RISE_SECONDS * 0.5)
	assert_almost_eq(p.rise, 0.5, 0.01, "and rises")
	assert_true(p.column.visible)
	p._process(AscensionPortal.RISE_SECONDS)
	assert_eq(p.rise, 1.0, "to its full height")
	assert_gt(p.light.light_energy, AscensionPortal.LIGHT_SEALED)
	var calm := AscensionPortal.new()
	calm.calm = true
	add_child_autofree(calm)
	calm.set_sealed(false)
	assert_eq(calm.rise, 1.0, "reduced motion: there at once")


func _palette() -> Dictionary:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	return biome.palette


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_the_world_view_draws_the_ascension_portal_on_the_last_floor() -> void:
	var w := SaveLab.floor_world(42, 3)
	var view := WorldViewRoot.new()
	add_child_autofree(view)
	view.setup(WorldReader.new(w), _palette(), 40.0)
	assert_not_null(view.ascension, "the Ascension portal")
	assert_null(view.gate, "not the blue gate")
	assert_not_null(view.loop_device, "v0.8.0 P2: and the Loop device")
	assert_eq(
		view.loop_device.position, SimPlane.to_3d(w.floor_layout.loop_pos), "where the sim's pad is"
	)
	assert_true(view.loop_device.is_sealed(), "dormant while the boss lives")
	w.boss_flow.state = BossFlow.State.OPEN  # a state set for the view only (the sim's path: test_ascension)
	view.sync()
	assert_false(view.loop_device.is_sealed(), "it opens with the portal")
	assert_false(view.ascension.is_sealed())
	assert_eq(
		view.ascension.find_children("*", "Label3D", true, false).size(),
		0,
		"v0.8.0 N18 (O76): the open portal has no floating name"
	)
	var w1 := SaveLab.floor_world(42, 1)
	var view1 := WorldViewRoot.new()
	add_child_autofree(view1)
	view1.setup(WorldReader.new(w1), _palette(), 40.0)
	assert_null(view1.ascension, "floor 1 keeps its gate")
	assert_null(view1.loop_device, "and has no Loop device")
	assert_not_null(view1.gate)


func test_loop_lines_on_the_hud_pause_and_recap() -> void:
	assert_eq(Hud.loop_prefix(self, 1), "", "loop 1 reads as before")
	assert_eq(Hud.loop_prefix(self, 3), tr("HUD_LOOP") % 3 + " · ")
	var end := EndPanel.new(true, -1, &"", {"floor": 3, "floors": 3, "loop": 2, "loops_cleared": 2})
	add_child_autofree(end)
	assert_eq(end.recap_line("Floor"), tr("HUD_LOOP") % 2 + " · " + tr("UI_RECAP_FLOOR") % [3, 3])
	assert_eq(end.recap_line("Loops"), tr("UI_RECAP_LOOPS") % 2, "the loops cleared")
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	pause.show_run(1, 75.0, 10, 4, 2)
	assert_true(
		pause.run_line.text.begins_with(tr("HUD_LOOP") % 2), "the pause line names the loop"
	)
