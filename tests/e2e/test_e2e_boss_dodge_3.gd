extends GutTest
## v0.7.5 BF3 (owner N15, "Track, then lock 0.8 s"): the Siege Engine's dodge-first fight reaches the real game.
## Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks pick the
## Siege Engine and summon it (God keeps the player standing; hits still show as HIT events), backtick closes it. When
## the first circle of a Barrage locks on the player, the stick walks out, and that circle strikes where it locked,
## missing the player; its Turret Cross's cannon embers are drawn by FireballViews in their look.

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


## The direction with the most room to walk out, away from the boss (a read of the walls, not an action).
func _way_out(w: World, from: Vector2, boss: Vector2) -> Vector2:
	var best := DIRS[0]
	var score := -INF
	for d: Vector2 in DIRS:
		var room := EnemyAi.clear_run(w, from, Kin.angle_of(d), 6.0, w.player.radius_m)
		var s := room + 2.0 * d.dot((from - boss).normalized())
		if s > score:
			score = s
			best = d
	return best


## The first circle of a Barrage (MOVE_MARKS) just locked: [its centre, radius], else [].
func _barrage_lock(reader: WorldReader, i: int) -> Array:
	var tg := reader.telegraph(i)
	if tg.is_empty() or tg.get("move", -1) != WorldReader.MOVE_MARKS:
		return []
	var first: Dictionary = tg["items"][0]
	if not first["locked"] or reader.boss_pattern(i).size() > 0:
		return []
	return [first["center"], first["radius"]]


func test_the_siege_engine_fight_and_walking_out_of_a_locked_barrage_circle() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"siege_engine")].name_key)
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
	var bi := reader.boss_index()
	assert_eq(reader.actor_kind(bi), ActorStore.Kind.SIEGE_ENGINE)
	var bid := reader.actor_id(bi)
	# It rises off to one side, maybe behind a pillar of the start hall (fireballs stop at walls): step aside.
	var to_boss := (reader.actor_pos(bi) - reader.player_pos()).normalized()
	e.stick_toward(Vector2(-to_boss.y, to_boss.x))
	await e.frames(25)
	e.stick_toward(Vector2.ZERO)
	var embers := 0
	var dodged := false
	var locked_seen := false
	for k in 5400:
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		embers = maxi(embers, main.view.fireballs.ball_count(&"cannon_ember"))
		if dodged:
			if embers > 0:
				break
			continue
		var lock := _barrage_lock(reader, i)
		if lock.is_empty():
			continue
		# A Barrage's first circle just locked: walk out of it with the stick until it has struck.
		locked_seen = true
		var center: Vector2 = lock[0]
		var radius: float = lock[1]
		assert_lt(
			reader.player_pos().distance_to(center), 0.3, "it locked on where the player stood"
		)
		e.stick_toward(_way_out(w, reader.player_pos(), reader.actor_pos(i)))
		var seq := w.last_event_seq()
		var struck := false
		var hit := false
		for f in 90:
			await e.frames(1)
			for ev in w.events_since(seq):
				seq = ev.seq
				if (
					ev.kind == SimEvent.Kind.HIT
					and ev.target_id == w.actors.ids[0]
					and ev.owner_id == bid
					and ev.tags & SimEvent.TAG_AREA
				):
					hit = true
			var j := w.actors.index_of(bid)
			var now := reader.telegraph(j) if j >= 0 else {}
			var still := false
			if not now.is_empty() and now.get("move", -1) == WorldReader.MOVE_MARKS:
				for item: Dictionary in now["items"]:
					still = still or (item["center"] == center and item["locked"])
			if not still:
				struck = true
				break
		e.stick_toward(Vector2.ZERO)
		assert_true(struck, "the circle struck")
		assert_gt(reader.player_pos().distance_to(center), radius, "the player walked out")
		assert_false(hit, "and the locked circle missed")
		dodged = struck and not hit
	assert_true(locked_seen, "a Barrage circle locked on the player")
	assert_true(dodged, "dodged by moving after the lock")
	assert_gt(embers, 0, "the Siege Engine's cannon embers were drawn")
