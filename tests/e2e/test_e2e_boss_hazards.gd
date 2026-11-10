extends GutTest
## v0.11.0 F8 (owner 4.2) in the real game, by input events only (Input.parse_input_event): a Gun run from the menu;
## backtick opens the dev panel and clicks pick the boss, summon it and turn God on; the fight then runs by itself until
## the boss's real attack leaves its hazard (a Foundry pool, a Brood Mother venom pool, a Siege Engine rock), and the
## view draws it, warning first and then armed. No test helper touches the fight.

const TICKS := 5400


## Runs boss `id` until its hazard shows and arms.
func _fight(id: StringName, look: StringName) -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, id)].name_key)
	for k in 16:
		if choice.text == name:
			break
		await e.click_dev("NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name, "the panel names it")
	await e.click_dev("SpawnBoss")
	await e.frames(30)
	var reader := main.driver.reader
	var view := main.view.hazards
	assert_eq(reader.boss_hazards().size(), 0, "no hazard at the start")
	var warned := false
	var armed := false
	for k in TICKS:
		await e.frames(1)
		for r: Dictionary in reader.boss_hazards():
			assert_eq(r["look"], look, "its own look")
			warned = warned or not r["armed"]
			armed = armed or (r["armed"] and view.hazard_count() > 0)
		if warned and armed:
			break
	gut.p("F8 e2e %s: %d hazards at the end" % [id, reader.boss_hazards().size()])
	assert_true(warned, "%s: its hazard warned first" % id)
	assert_true(armed, "%s: and armed, drawn" % id)
	assert_lte(
		reader.boss_hazards().size(), w.boss_tables[BossLab.table_index(w, id)].hazard.max_count
	)
	await e.tap(KEY_QUOTELEFT)


func test_the_foundry_leaves_lava_pools() -> void:
	await _fight(&"foundry", &"lava")


func test_the_brood_mother_leaves_venom_pools() -> void:
	await _fight(&"brood_mother", &"venom")


func test_the_siege_engine_drops_rocks() -> void:
	await _fight(&"siege_engine", &"rock")
