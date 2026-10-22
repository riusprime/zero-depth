extends GutTest
## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S2, S3): the Warlord's javelins and the Brood Mother's eggs reach the real
## game. Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks turn
## on God, pick the boss and summon it, backtick closes it. The boss fights on its own: the Warlord's Javelin Fan
## leaves javelins standing in the floor (BossSignatureViews) that then fly back; the Brood Mother's Egg Storm leaves
## eggs drawn on the floor, the Hatchlings inside hidden. (S1's pillars: test_e2e_stone_spikes.gd.)
## v0.8.0 fix (after N14): the hero keeps the Warlord at fan range with the stick, the panel left open so God holds.
## A fan thrown point-blank spawns no javelin (no shot spawns within the pattern's safe radius of the player); before
## N14 the shrine stood between the hero and the Warlord in the start hall, kept it off, and took the javelins.

## The hero walks out when the Warlord is nearer than this (its radius plus the fan's safe radius, with room).
const KEEP_M := 4.5
const DIRS := [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(0.7071, 0.7071),
	Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071),
	Vector2(-0.7071, -0.7071)
]


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## `close` false leaves the panel open: closing it drops its DebugApi, and God with it (Main.toggle_dev_panel).
func _summon(e: E2e, main: Main, id: StringName, close: bool = true) -> int:
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
	if close:
		await e.tap(KEY_QUOTELEFT)
		assert_false(main.is_dev_panel_open())
	var reader := main.driver.reader
	return reader.actor_id(reader.boss_index())


## The direction with the most room to walk out, away from the boss (a read of the walls, not an action).
func _way_out(w: World, from: Vector2, boss: Vector2) -> Vector2:
	var best: Vector2 = DIRS[0]
	var score := -INF
	for d: Vector2 in DIRS:
		var room := EnemyAi.clear_run(w, from, Kin.angle_of(d), 6.0, w.player.radius_m)
		var s := room + 2.0 * d.dot((from - boss).normalized())
		if s > score:
			score = s
			best = d
	return best


func test_the_warlords_javelins_stand_in_the_floor_then_fly_back() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var bid := await _summon(e, main, &"warlord", false)  # God stays on while the hero walks
	var w := e.world()
	var reader := main.driver.reader
	var stood := 0
	var back := false
	for k in 9000:
		var bi := w.actors.index_of(bid)
		if bi < 0:
			break
		var me := reader.player_pos()
		var boss := reader.actor_pos(bi)
		e.stick_toward(_way_out(w, me, boss) if me.distance_to(boss) < KEEP_M else Vector2.ZERO)
		await e.frames(1)
		stood = maxi(stood, main.view.signatures.javelin_count())
		if stood > 0 and main.view.signatures.javelin_count() == 0:
			back = true
			break
	e.stick_toward(Vector2.ZERO)
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
