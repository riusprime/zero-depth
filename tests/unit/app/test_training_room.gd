extends GutTest
## v0.10.5 O17 (owner P17): the hub's Training Room: a bit smaller than the plaza, the hero can't die there, the endless
## dummy takes hits (the DPS meter counts them over the last 5 s) and never dies, the terminal offers only what the
## Codex has met, and nothing done there reaches the profile (the Codex, achievements, records, unlocks, fragments).


func before_all() -> void:
	InputDefaults.apply()  # the driver samples the move actions


func _repo() -> ContentRepository:
	return AttackScenario.repo()


func _world(build: StringName = &"gun") -> World:
	var repo := _repo()
	return TrainingScenario.build(repo, build, repo.get_def(&"biomes", HubSession.BIOME))


func _dummy(w: World) -> int:
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == ActorStore.Kind.DUMMY:
			return i
	return -1


## The id of the first wand card the Gun can take (in item order).
func _wand_card_id(w: World) -> StringName:
	var api := PlaygroundApi.new(w)
	for e in api.catalog():
		if e["group"] == PlaygroundApi.GROUP_WAND:
			return w.item_tables[int(e["code"])].id
	return &""


func _session(w: World, codex: CodexStore) -> TrainingSession:
	var driver := SimDriver.new()
	driver.setup(w)
	add_child_autofree(driver)
	var ui := CanvasLayer.new()
	add_child_autofree(ui)
	var s := TrainingSession.new(driver, ui, &"gun", [], codex, CodexCatalog.build(_repo()), {})
	add_child_autofree(s)
	return s


func test_the_room_is_a_bit_smaller_than_the_plaza() -> void:
	var w := _world()
	var room := TrainingScenario.room_of(w)
	var hub: HubDefinition = _repo().get_def(&"hub", HubSession.HUB_ID)
	gut.p(
		(
			"O17: the Training Room is %.1f x %.1f m; the plaza %.1f m across"
			% [room.size.x, room.size.y, hub.radius_m * 2.0]
		)
	)
	assert_lt(room.size.x, hub.radius_m * 2.0, "narrower than the plaza")
	assert_lt(room.size.y, hub.radius_m * 2.0)
	assert_gt(room.size.x, 15.0, "room to fight in")
	assert_true(room.has_point(w.player_pos()), "the hero starts inside")
	assert_almost_eq(w.player_pos(), TrainingRoom.start_point(room), Vector2.ONE * 1e-3)
	assert_false(TrainingRoom.at_exit(room, w.player_pos()), "not on the exit pad at the start")
	assert_false(TrainingRoom.at_terminal(room, w.player_pos()), "nor at the terminal")
	for p in [TrainingRoom.exit_point(room), TrainingRoom.terminal_point(room)]:
		assert_true(room.grow(-0.5).has_point(p), "the exit and the terminal are in the room")
	assert_null(w.ice, "no ice in the Training Room")


func test_the_hero_cannot_die_there() -> void:
	var w := _world()
	var at := w.player_pos()
	Damage.hit(w, 0, 999999, 0, 0, w.take_root(), 0, at, at)
	assert_eq(w.actors.hp[0], TrainingScenario.HP_FLOOR, "HP floors at 1")
	assert_false(w.player_dead(), "alive")
	for t in 120:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
	assert_false(w.player_dead())


func test_a_run_world_has_no_hp_floor() -> void:
	var repo := _repo()
	var w := PlaygroundScenario.build(repo, &"gun", repo.get_def(&"biomes", &"ruins"))
	assert_eq(w.player_hp_floor, 0, "off outside the Training Room")
	var at := w.player_pos()
	Damage.hit(w, 0, 999999, 0, 0, w.take_root(), 0, at, at)
	assert_true(w.player_dead(), "a killing blow kills elsewhere")


func test_the_dummy_takes_hits_counts_dps_and_never_dies() -> void:
	var s := _session(_world(), CodexStore.new(ProfileStore.new("")))
	var w := s.driver.world
	var i := _dummy(w)
	assert_gt(i, 0, "the endless dummy stands in the room")
	assert_almost_eq(w.actors.pos(i), TrainingRoom.dummy_point(s.room), Vector2.ONE * 1e-3)
	var at := w.actors.pos(i)
	var max_hp := w.actors.max_hp[i]
	for k in 3:
		Damage.hit(w, _dummy(w), 50000, 0, w.actors.ids[0], w.take_root(), 0, at, at)
		s.driver.step_once()
	i = _dummy(w)
	assert_gt(i, 0, "still there")
	assert_eq(w.actors.dead[i], 0, "never dies")
	assert_eq(w.actors.hp[i], max_hp, "its HP comes back")
	assert_eq(DpsTally.WINDOW_TICKS, 300, "the meter's recent DPS is over the last 5 s")
	assert_gt(s.meter.tally.dps_recent(w.tick), 0.0, "the hits are counted")
	s.meter.reset(s.driver.reader)
	assert_eq(s.meter.tally.dps_recent(w.tick), 0.0, "and reset")


func test_the_terminal_offers_only_what_the_codex_met() -> void:
	var w := _world()
	var api := PlaygroundApi.new(w)
	var codex := CodexStore.new(ProfileStore.new(""))
	var catalog := CodexCatalog.build(_repo())
	assert_eq(TrainingRoom.known_enemies(api.enemy_choices(), codex, catalog).size(), 0)
	assert_eq(TrainingRoom.known_cards(api, codex).size(), 0)
	codex.unlock(&"enemies", &"charger")
	var card := _wand_card_id(w)
	codex.unlock(&"cards", card)
	var enemies := TrainingRoom.known_enemies(api.enemy_choices(), codex, catalog)
	assert_eq(enemies.size(), 1, "the Charger alone")
	assert_eq(int(enemies[0]["kind"]), ActorStore.Kind.CHARGER)
	var cards := TrainingRoom.known_cards(api, codex)
	assert_eq(cards.size(), 1, "the one card seen")
	assert_eq(w.item_tables[int(cards[0]["code"])].id, card)


func test_spawn_points_stand_in_the_room_away_from_the_door() -> void:
	var w := _world()
	var api := PlaygroundApi.new(w)
	var room := TrainingScenario.room_of(w)
	for count: int in TrainingRoom.COUNTS:
		var pts := TrainingRoom.spawn_points(room, count)
		assert_eq(pts.size(), count)
		for p in pts:
			assert_true(api.clear_spot(p, 0.6), "%d: a clear spot" % count)
	var one := TrainingRoom.spawn_points(room, 1)[0]
	assert_gt(
		one.distance_to(TrainingRoom.exit_point(room)),
		TrainingRoom.dummy_point(room).distance_to(TrainingRoom.exit_point(room)),
		"one alone stands past the dummy, away from the door"
	)


func test_the_terminal_spawns_clears_grants_and_removes() -> void:
	var codex := CodexStore.new(ProfileStore.new(""))
	var s := _session(_world(), codex)
	var w := s.driver.world
	var before := w.actors.size()
	s.spawn(ActorStore.Kind.CHARGER, 3)
	s.driver.step_once()
	assert_eq(w.actors.size(), before + 3, "three Chargers")
	s.clear()
	s.driver.step_once()
	assert_eq(w.actors.size(), before, "cleared; the dummy stays")
	assert_gt(_dummy(w), 0)
	var api := s.api
	var code := -1
	for e in api.catalog():
		if e["group"] == PlaygroundApi.GROUP_WAND and code < 0:
			code = int(e["code"])
	s.grant(code, 4)
	s.driver.step_once()
	assert_true(w.items_owned.has(code), "the card is in the wand")
	assert_eq(
		CardLevels.level(w, code), mini(4, CardLevels.max_level(w, code)), "at the level picked"
	)
	s.remove_last_card()
	s.driver.step_once()
	assert_false(w.items_owned.has(code), "and out again")


## Nothing done in the Training Room reaches the profile: a session in the real game (Main) that spawns enemies, kills
## them, takes a card and goes back to the hub leaves the Codex, the achievements, the records, the unlocks and the
## fragments as they were.
func test_nothing_counts() -> void:
	var profile := ProfileStore.new("")
	var codex := CodexStore.new(profile)
	codex.unlock(&"enemies", &"charger")
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	main._show_hub()  # the hub reads (and makes) its empty sections first
	await e.frames(2)
	var before := JSON.stringify(profile.data, "", true)

	TrainingFlow.start(main, &"gun")
	await e.frames(2)
	assert_not_null(main.training, "the Training Room runs")
	var w := main.driver.world
	main.training.spawn(ActorStore.Kind.CHARGER, 8)
	await e.frames(2)
	var kills := 0
	for i in range(w.actors.size() - 1, 0, -1):
		if w.actors.kinds[i] == ActorStore.Kind.CHARGER:
			var at := w.actors.pos(i)
			Damage.hit(w, i, 999999, 0, w.actors.ids[0], w.take_root(), 0, at, at)
			kills += 1
	assert_eq(kills, 8, "eight Chargers fell")
	var code := -1
	for c in main.training.api.catalog():
		if c["group"] == PlaygroundApi.GROUP_WAND and code < 0:
			code = int(c["code"])
	main.training.grant(code, 5)
	await e.frames(120)
	main._show_hub()
	await e.frames(2)
	assert_not_null(main.hub, "back in the hub")
	assert_eq(JSON.stringify(profile.data, "", true), before, "the profile is untouched")
	assert_false(main.codex.dirty, "no Codex count")
	assert_false(main.achievements.dirty, "no achievement")
