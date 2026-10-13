extends GutTest
## v0.7.5 NB1 (owner N2) in the real game, by input events only (Input.parse_input_event): Play, then Restart run from
## the pause menu until a run's first floor is Frozen Shore (the run's biome draw; the loop keeps the test right when
## another biome joins the draw, as Starfall did in NB2: 3 floors from 5 since then). The HUD names it, the floor is lit
## by its cold mood and dressed with its look (the frozen sea past the edge, snow and ice instead of grass and
## rubble), its ambience loop plays, and its ice is in the sim. Walking onto a patch with the stick puts the hero on
## ice, and letting go there slides: the hero is still moving after the time a stop takes on dry ground. Reads of
## nodes are fine.

const MAX_RESTARTS := 12


func after_each() -> void:
	Input.action_release(&"pause")
	for a in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)


func _restart(e: E2e) -> void:
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)  # Resume -> Build (v0.6.5 WN2)
	await e.tap(KEY_DOWN)  # -> Restart run
	await e.tap(KEY_ENTER)
	await e.frames(3)


func test_frozen_shore_is_reached_drawn_and_its_ice_slides() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(3)
	for k in MAX_RESTARTS:
		if main.run_biome_id() == &"frozen_shore":
			break
		await _restart(e)
	assert_eq(main.run_biome_id(), &"frozen_shore", "a run whose floor 1 is Frozen Shore")
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"frozen_shore")
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.floor_text(), tr("HUD_FLOOR") % [1, tr("BIOME_FROZEN_SHORE")], "the HUD names it")
	var stage := main.view.stage
	assert_eq(stage.mood, biome.mood, "its cold mood")
	assert_eq(stage.look, biome.look, "its look")
	assert_not_null(stage.edge, "the frozen sea past the floor's edge")
	assert_gt(stage.edge.floe_count, 0, "with ice floes")
	assert_not_null(stage.kit, "dressed with the kit")
	assert_not_null(stage.kit.get_node_or_null("Decor_snow_drift"), "snow drifts, not grass")
	assert_eq(main.view.actors.enemy_tint, biome.look.enemy_tint, "the enemies' cold cast")
	assert_eq(main.audio.ambience_id(), &"frozen_shore", "its ambience loop")
	var reader := WorldReader.new(e.world())
	assert_gt(reader.ice_patch_count(), 0, "this floor has ice")
	assert_eq(stage.ice.patch_count, reader.ice_patch_count(), "every patch is drawn")
	# Walk onto the nearest patch, then run across it and let go.
	var best := Rect2()
	var best_d := INF
	for i in reader.ice_patch_count():
		var r := reader.ice_patch(i)
		var d := (r.get_center() - reader.player_pos()).length()
		if d < best_d:
			best_d = d
			best = r
	# Arriving at speed, the hero may slide past the centre: walk back from close by until it rests on the patch.
	for attempt in 4:
		assert_true(
			await e.walk_to(best.get_center(), 0.3), "the stick walks the hero onto the ice"
		)
		await e.frames(40)
		if reader.player_on_ice() and (reader.player_pos() - best.get_center()).length() < 0.6:
			break
	assert_true(reader.player_on_ice(), "the hero stands on ice")
	var w := e.world()
	var dir := Vector2.RIGHT if best.size.x >= best.size.y else Vector2.UP
	e.stick_toward(-dir)
	await e.frames(8)
	e.stick_toward(dir)
	await e.frames(10)
	e.stick_toward(Vector2.ZERO)
	await e.frames(8)  # dry ground stops under 10 % of top speed in 5 ticks (test_movement_feel)
	assert_gt(
		w.vel.length(), w.player.move_speed * 0.2, "eight ticks after letting go it still slides"
	)
	assert_eq(get_errors().size(), 0, "no engine or script error")
