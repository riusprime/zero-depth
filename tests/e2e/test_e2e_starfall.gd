extends GutTest
## v0.7.5 NB2 (owner N3) in the real game, by input events only (Input.parse_input_event): Play, then Restart run from
## the pause menu until a run's first floor is Starfall (the run's biome draw; the loop keeps the test right whatever
## seed draws it). The HUD names it, the floor is lit by its starry mood and dressed with its look (the starry void
## past the edge, star crystals instead of grass), its ambience loop plays, and its starglow pools are in the sim.
## Walking onto a pool with the stick and running across it, the hero moves faster than their own top speed. Reads of
## nodes are fine.

const MAX_RESTARTS := 16


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


func test_starfall_is_reached_drawn_and_its_pools_speed_the_hero() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(3)
	var reader := WorldReader.new(e.world())
	for k in MAX_RESTARTS:
		reader = WorldReader.new(e.world())
		if main.run_biome_id() == &"starfall" and reader.ice_patch_count() > 0:
			break
		await _restart(e)
	reader = WorldReader.new(e.world())
	assert_eq(main.run_biome_id(), &"starfall", "a run whose floor 1 is Starfall")
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"starfall")
	var hud: Hud = main.get_node("UI/Hud")
	assert_eq(hud.floor_text(), tr("HUD_FLOOR") % [1, tr("BIOME_STARFALL")], "the HUD names it")
	var stage := main.view.stage
	assert_eq(stage.mood, biome.mood, "its starry mood")
	assert_eq(stage.look, biome.look, "its look")
	assert_not_null(stage.edge, "the starry void past the floor's edge")
	assert_eq(stage.edge.style, &"stars")
	assert_gt(stage.edge.star_count, 0, "with stars")
	assert_gt(stage.edge.island_count, 0, "and floating islands")
	assert_not_null(stage.kit, "dressed with the kit")
	assert_not_null(stage.kit.get_node_or_null("Decor_star_crystal"), "star crystals, not grass")
	assert_eq(main.view.actors.enemy_tint, biome.look.enemy_tint, "the enemies' violet cast")
	assert_eq(main.audio.ambience_id(), &"starfall", "its ambience loop")
	assert_eq(reader.surface_kind(), &"starglow")
	assert_gt(reader.ice_patch_count(), 0, "this floor has starglow pools")
	assert_null(stage.ice, "no ice drawn")
	assert_eq(stage.glow.patch_count, reader.ice_patch_count(), "every pool is drawn")
	# Walk to the nearest pool's centre, back off along its long side, then run across it.
	var best := Rect2()
	var best_d := INF
	for i in reader.ice_patch_count():
		var r := reader.ice_patch(i)
		var d := (r.get_center() - reader.player_pos()).length()
		if d < best_d:
			best_d = d
			best = r
	for attempt in 4:
		assert_true(
			await e.walk_to(best.get_center(), 0.3), "the stick walks the hero onto the pool"
		)
		await e.frames(20)
		if reader.player_on_ice():
			break
	assert_true(reader.player_on_ice(), "the hero stands on a pool")
	var w := e.world()
	var dir := Vector2.RIGHT if best.size.x >= best.size.y else Vector2.UP
	var long := maxf(best.size.x, best.size.y)
	var fast := w.player.move_speed * 1.25  # the pool's top speed: legs of the run sized to stay on it
	var fastest := 0.0
	for leg: Array in [[-dir, 0.4], [dir, 0.8], [-dir, 0.8]]:
		e.stick_toward(leg[0])
		for t in int(long * float(leg[1]) / fast):
			await e.frames(1)
			if reader.player_on_ice():
				fastest = maxf(fastest, w.vel.length())
	e.stick_toward(Vector2.ZERO)
	await e.frames(20)
	gut.p(
		(
			"starfall e2e: run seed %d, %d pools, fastest on a pool %.4f m/tick (own top %.4f)"
			% [main.run.run_seed, reader.ice_patch_count(), fastest, w.player.move_speed]
		)
	)
	assert_gt(
		fastest, w.player.move_speed * 1.1, "on the pool the hero runs faster than their top speed"
	)
	assert_eq(get_errors().size(), 0, "no engine or script error")
