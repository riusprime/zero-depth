extends GutTest
## v0.11.0 O9 (PLAN H1, M4; owner Q14, Q15): a horde surge in the real game. The run starts from the menu through real
## input only (Input.parse_input_event); the floor's first surge is planned by the sim on its first tick. Test speed-up
## (as test_e2e_hud_style poses the floor time): the floor clock (World.run_ticks, the sim's own field) is moved to a
## second before that surge, and the hero is made unhurtable; the rest is the real loop. The surge's sound cue and HUD
## line come, the floor's biome critter arrives in numbers, every one drawn through the VAT crowd.

const MAX_FRAMES := 1200


func test_a_surge_arrives_with_its_cue_in_a_real_run() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.frames(30)
	var w := e.world()
	var reader := main.driver.reader
	assert_gte(w.critter_kind, 0, "the floor's biome has its critter")
	assert_true(EnemyAi.is_critter(w.critter_kind))
	assert_false(w.surge_at.is_empty(), "the floor planned its surges")
	assert_true(w.surge_at.size() >= 1 and w.surge_at.size() <= 2, "once or twice")
	if w.surge_at.is_empty():
		return
	# Test speed-up (labelled): the floor clock to a second before the first surge; the hero unhurtable.
	w.actors.invuln[0] = 1 << 24
	w.run_ticks = w.surge_at[0] - 60
	var hud: Hud = main.get_node("UI/Hud")
	var saw_line := false
	var began := false
	var seen := {}
	var most_drawn := 0
	var all_vat := true
	var seq := w.last_event_seq()
	for f in MAX_FRAMES:
		await e.frames(1)
		for ev in w.events_since(seq):
			seq = ev.seq
			began = began or ev.kind == SimEvent.Kind.SURGE
		saw_line = saw_line or hud.phase_hud.current_entry() == PackedStringArray(["HUD_SURGE", ""])
		var drawn := 0
		for i in range(1, w.actors.size()):
			if w.actors.kinds[i] != w.critter_kind or w.actors.dead[i] == 1:
				continue
			seen[w.actors.ids[i]] = true
			var node := main.view.actors.actor_node(w.actors.ids[i])
			if node == null:
				continue  # not synced yet (it arrived this frame)
			if (node.get_meta(&"enemy_avatar") as HordeAvatar).vat:
				drawn += 1
			else:
				all_vat = false
		most_drawn = maxi(most_drawn, drawn)
		if began and saw_line and not reader.surge_running():
			break
	assert_true(began, "the surge began (its SURGE cue)")
	assert_true(saw_line, "its HUD line showed: %s" % tr("HUD_SURGE"))
	assert_gte(seen.size(), 30, "the critters came in numbers (%d)" % seen.size())
	assert_true(all_vat, "each one drawn through the VAT crowd")
	assert_gte(most_drawn, 10, "many at once in the crowd (%d)" % most_drawn)
