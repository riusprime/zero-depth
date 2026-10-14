extends GutTest
## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S2, S3): the Warlord's javelins and the Brood Mother's eggs reach the real
## game. Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks turn
## on God, pick the boss and summon it, backtick closes it. The boss fights on its own: the Warlord's Javelin Fan
## leaves javelins standing in the floor (BossSignatureViews) that then fly back; the Brood Mother's Egg Storm leaves
## eggs drawn on the floor, the Hatchlings inside hidden. (S1's pillars: test_e2e_stone_spikes.gd.)


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _summon(e: E2e, main: Main, id: StringName) -> int:
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, id)].name_key)
	for k in 8:
		if choice.text == name:
			break
		await _click(e, main, "NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name)
	await _click(e, main, "SpawnBoss")
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	assert_false(main.is_dev_panel_open())
	var reader := main.driver.reader
	return reader.actor_id(reader.boss_index())


func test_the_warlords_javelins_stand_in_the_floor_then_fly_back() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var bid := await _summon(e, main, &"warlord")
	var w := e.world()
	var stood := 0
	var back := false
	for k in 9000:
		await e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		stood = maxi(stood, main.view.signatures.javelin_count())
		if stood > 0 and main.view.signatures.javelin_count() == 0:
			back = true
			break
	assert_gt(stood, 0, "javelins stood in the floor")
	assert_true(back, "and flew back")


func test_the_brood_mothers_eggs_sit_on_the_floor() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var bid := await _summon(e, main, &"brood_mother")
	var w := e.world()
	var eggs := 0
	for k in 9000:
		await e.frames(1)
		if w.actors.index_of(bid) < 0:
			break
		eggs = main.view.signatures.egg_count()
		if eggs > 0:
			break
	assert_gt(eggs, 0, "eggs drawn on the floor")
	var reader := main.driver.reader
	for i in reader.actor_count():
		if reader.actor_egg_permille(i) >= 0:
			var node: Node3D = main.view.actors.actor_node(reader.actor_id(i))
			assert_false(
				(node.get_meta(&"facing") as Node3D).visible, "the Hatchling inside hidden"
			)
