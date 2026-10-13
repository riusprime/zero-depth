extends GutTest
## v0.7.5 BF1 (owner N15, "Track, then lock 0.8 s"): the Gatekeeper's dodge-first fight reaches the real game.
## Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks pick the
## Gatekeeper and summon it (God keeps the player standing; hits still show as HIT events), backtick closes it. The
## boss fires its fireball patterns (drawn by FireballViews in its look) and lays its tracked circles; when a Fist Slam
## locks, the player walks out with the stick, and the circle strikes where it locked, missing the player.

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


func test_the_gatekeeper_fight_and_walking_out_of_a_locked_circle() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"gatekeeper")].name_key)
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
	assert_eq(reader.actor_kind(bi), ActorStore.Kind.GATEKEEPER)
	var bid := reader.actor_id(bi)
	# It rises 6 m off with a pillar of the start hall between (fireballs stop at walls): step aside into its sight.
	var to_boss := (reader.actor_pos(bi) - reader.player_pos()).normalized()
	e.stick_toward(Vector2(-to_boss.y, to_boss.x))
	await e.frames(25)
	e.stick_toward(Vector2.ZERO)
	var fireballs := 0
	var dodged := false
	var locked_seen := false
	for k in 3600:
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		fireballs = maxi(fireballs, main.view.fireballs.ball_count(&"ember_stone"))
		if dodged:
			if fireballs > 0:
				break
			continue
		var tg := reader.telegraph(i)
		if tg.is_empty() or tg.get("move", -1) != WorldReader.MOVE_MARKS:
			continue
		if not tg["items"][0]["locked"] or (tg["items"] as Array).size() != 1:
			continue
		# A Fist Slam just locked: walk out of it with the stick until it has struck.
		locked_seen = true
		var center: Vector2 = tg["items"][0]["center"]
		var radius: float = tg["items"][0]["radius"]
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
			if now.is_empty() or now.get("move", -1) != WorldReader.MOVE_MARKS:
				struck = true
				break
			assert_eq(now["items"][0]["center"], center, "the circle holds where it locked")
		e.stick_toward(Vector2.ZERO)
		assert_true(struck, "the circle struck")
		assert_gt(reader.player_pos().distance_to(center), radius, "the player walked out")
		assert_false(hit, "and the locked circle missed")
		dodged = struck and not hit
	assert_true(locked_seen, "a Fist Slam locked on the player")
	assert_true(dodged, "dodged by moving after the lock")
	assert_gt(fireballs, 0, "the Gatekeeper's ember stones were drawn")
