extends GutTest
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring): the hub's plan, its flags and its World. The plan's north
## is the screen's top; stations are found by where the hero stands; the flags read the profile and never write it; the
## hub's World walks the hero on the run's rules inside the plaza's walls.

var _repo: ContentRepository
var _hub: HubDefinition


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_hub = _repo.get_def(&"hub", &"rune_ring")


func test_the_rune_ring_is_valid_content() -> void:
	assert_not_null(_hub, "data/hub/rune_ring.tres")
	assert_eq(_hub.validate().size(), 0, "no issues")
	var ids := []
	for s in _hub.stations:
		ids.append(s.id)
	assert_eq(ids, [&"archive", &"trophy", &"wardrobe", &"progression", &"credits"])
	assert_eq(_hub.rune_count, 16, "16 floor runes")


func test_a_broken_hub_is_caught() -> void:
	var bad := _hub.duplicate(true) as HubDefinition
	bad.stations[0].panel = &"nowhere"
	bad.stations[1].at = Vector2(14.0, 0.0)
	bad.rune_flag = "count:collectibles"
	var codes := []
	for i in bad.validate():
		codes.append(i.code)
	assert_has(codes, &"hub_panel")
	assert_has(codes, &"hub_station_out")
	assert_has(codes, &"hub_flag")


func test_flag_grammar() -> void:
	for ok in [
		"achievement:win_run", "codex:bosses:foundry", "codex_total:bosses:kills:1", "count:x:3"
	]:
		assert_true(HubStateDefinition.flag_ok(ok), ok)
	assert_true(HubStateDefinition.flag_ok("profile:hub:gate"))
	for bad in ["", "achievement", "nope:x", "count:x:many", "codex:bosses", "achievement:a:b"]:
		assert_false(HubStateDefinition.flag_ok(bad), bad)


func test_the_plan_turns_onto_the_screen() -> void:
	# The camera looks toward sim (-1, +1): the plan's north is there, its east at sim (1, 1).
	assert_almost_eq(
		HubLayout.to_sim(Vector2(0, 1)), Vector2(-1, 1).normalized(), Vector2.ONE * 1e-5
	)
	assert_almost_eq(
		HubLayout.to_sim(Vector2(1, 0)), Vector2(1, 1).normalized(), Vector2.ONE * 1e-5
	)
	var p := Vector2(3.5, -7.25)
	assert_almost_eq(HubLayout.to_plan(HubLayout.to_sim(p)), p, Vector2.ONE * 1e-5)


func test_stations_are_found_where_the_hero_stands() -> void:
	var l := HubLayout.new(_hub)
	assert_eq(l.station_at(l.spawn()), &"", "nothing at the spawn")
	assert_eq(
		l.station_at(HubLayout.to_sim(Vector2(0, -3.0))), HubLayout.MACHINE, "the machine's ring"
	)
	for id: StringName in [&"archive", &"trophy", &"wardrobe", &"progression", &"credits"]:
		assert_eq(l.station_at(HubLayout.to_sim(l.front_of(id))), id, "before the %s" % id)
	# v0.9.0 HB3: the stations stand along the top half, each turned to face the plaza's middle.
	for s in _hub.stations:
		assert_gt(s.at.y, 0.0, "%s stands in the top (north) half" % s.id)
		var front := Vector2(0, -1).rotated(HubLayout.facing(s.at))
		assert_almost_eq(
			front, -s.at.normalized(), Vector2.ONE * 1e-4, "%s faces the middle" % s.id
		)
	assert_lt(_hub.spawn.y, 0.0, "the spawn on the bottom half")
	assert_gt(_hub.radius_m, 15.0, "the plaza grew (12.5 -> 16 m)")
	assert_eq(l.panel_of(&"archive"), &"codex")
	assert_eq(l.panel_of(HubLayout.MACHINE), &"portal")
	assert_eq(l.keys_of(&"trophy"), [&"HUB_TROPHY", &"HUB_PROMPT_TROPHY"] as Array[StringName])
	assert_eq(l.rune_points().size(), 16)
	assert_almost_eq(
		l.rune_points()[0], Vector2(0, -_hub.rune_ring_m), Vector2.ONE * 1e-4, "rune 0 due south"
	)
	# v0.9.0 HB3: the runes stand clear of the machine (its 4.6 m ring hides about 6.5 m of floor north of it).
	for p in l.rune_points():
		assert_gt(p.length(), _hub.machine_reach_m + 3.0, "a rune clear of the machine")


func test_the_gate_is_a_wall_until_it_opens() -> void:
	var sealed := HubLayout.new(_hub, false).walls().size()
	var open := HubLayout.new(_hub, true).walls().size()
	assert_eq(sealed, open + 1, "the sealed gate is one more wall")


func test_flags_read_the_profile_and_never_write_it() -> void:
	var profile := ProfileStore.new("")
	var codex := CodexStore.new(profile)
	var ach := AchievementStore.new(profile)
	var f := HubFlags.new(profile, codex, ach)
	var keys_before := profile.data.keys()
	var s := f.states(_hub)
	assert_false(bool(s[&"gate_open"]), "sealed on a fresh profile")
	assert_false(bool(s[&"trophy_lit"]))
	assert_eq((s[&"runes"] as Array).count(true), 0, "every rune dark")
	# v0.9.0 CL: a fresh profile (version 3) has the section, empty; the flags only read it
	assert_eq(profile.data.get("collectibles"), {}, "the collectibles section stays as it was")
	assert_eq(profile.data.keys(), keys_before)
	codex.add(&"bosses", &"foundry", &"kills")
	ach.unlock(&"ascend_1")
	profile.data["collectibles"] = {"a": 1, "b": 1, "c": 1}
	s = f.states(_hub)
	assert_true(bool(s[&"trophy_lit"]), "a boss fell: the trophy brazier")
	assert_true(bool(s[&"machine_looped"]), "an Ascension: the machine's violet ring")
	assert_eq((s[&"runes"] as Array).count(true), 3, "a rune per collectible (CL hook)")
	assert_eq(f.boss_trophies([&"foundry", &"warlord"]), [true, false] as Array[bool])
	profile.data["collectibles"] = {}
	for k in 12:
		profile.data["collectibles"]["c%d" % k] = 1
	assert_true(bool(f.states(_hub)[&"gate_open"]), "12 collectibles open the north gate (CL hook)")
	assert_true(f.value("profile:collectibles:c3"))


func test_the_hub_world_walks_the_hero_and_holds_it_in() -> void:
	var l := HubLayout.new(_hub)
	var w := HubScenario.build(_repo, l, &"blade")
	var start := w.player_pos()
	assert_almost_eq(start, l.spawn(), Vector2.ONE * 1e-4)
	# North on the screen for 4 s: toward the machine; its core stops the hero.
	for k in 240:
		w.step(_frame_toward(Vector2(0, 1)))
	var p := HubLayout.to_plan(w.player_pos())
	assert_gt(p.y, _hub.spawn.y + 5.0, "walked north")
	assert_gt(p.length(), _hub.machine_core_m * 0.9, "the machine's core holds")
	# West for 5 s: the rim holds.
	for k in 300:
		w.step(_frame_toward(Vector2(-1, 0)))
	assert_lt(HubLayout.to_plan(w.player_pos()).length(), _hub.radius_m, "inside the plaza")
	assert_eq(w.actors.size(), 1, "the hero alone: no enemy ever spawns")


## One tick's frame moving toward a plan direction (the screen's: the latch turns it onto the sim plane).
## v0.9.0 HB3: walking times on the bigger plaza stay short: from the spawn, the hero walking straight (round the
## machine where it is in the way) reaches the machine and every station in a few seconds of play (60 ticks a second).
func test_walking_times_from_the_spawn_stay_short() -> void:
	var l := HubLayout.new(_hub)
	var line := []
	for id: StringName in [
		&"portal", &"wardrobe", &"progression", &"archive", &"trophy", &"credits"
	]:
		var w := HubScenario.build(_repo, l, &"blade")
		var goal := l.front_of(id, 0.2)
		var ticks := 0
		while l.station_at(w.player_pos()) != id and ticks < 900:
			var p := HubLayout.to_plan(w.player_pos())
			var to := goal - p
			if id != HubLayout.MACHINE and HubWalk._gap_to_centre(p, goal) < 3.9:
				var side := p + goal
				to = side.normalized() * 4.8 - p
			w.step(_frame_toward(to.normalized()))
			ticks += 1
		assert_eq(l.station_at(w.player_pos()), id, "the hero reaches the %s" % id)
		assert_lt(ticks, 6 * 60, "%s within 6 s" % id)
		line.append("%s %.2f s" % [id, ticks / 60.0])
	gut.p("HB3 walking times from the spawn: %s" % ", ".join(line))


func _frame_toward(plan_dir: Vector2) -> InputFrame:
	var latch := InputLatch.new()
	return latch.close_frame(plan_dir, Vector2.RIGHT, 1.0)
