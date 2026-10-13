extends GutTest
## v0.7.5 BF2 (owner N15, "Track, then lock 0.8 s"): the Brood Mother's dodge-first fight reaches the real game.
## Through main.tscn with real input only (Input.parse_input_event): backtick opens the dev panel, clicks pick the
## Brood Mother and summon it (God keeps the player standing; hits still show as HIT events), backtick closes it. She
## throws her acid patterns (drawn by FireballViews as acid globs) and leaps; when a Leap's circle locks on the player,
## the player walks out with the stick, and she lands where it locked, missing the player.

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


func test_the_brood_mother_fight_and_walking_out_of_a_locked_leap() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"brood_mother")].name_key)
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
	assert_eq(reader.actor_kind(bi), ActorStore.Kind.BROOD_MOTHER)
	var bid := reader.actor_id(bi)
	# She rises 6 m off with a pillar of the start hall between (globs stop at walls): step aside into her sight.
	var to_boss := (reader.actor_pos(bi) - reader.player_pos()).normalized()
	e.stick_toward(Vector2(-to_boss.y, to_boss.x))
	await e.frames(25)
	e.stick_toward(Vector2.ZERO)
	var globs := 0
	var dodged := false
	var locked_seen := false
	for k in 4800:
		await e.frames(1)
		var i := w.actors.index_of(bid)
		if i < 0:
			break
		globs = maxi(globs, main.view.fireballs.ball_count(&"acid_glob"))
		if dodged:
			if globs > 0:
				break
			continue
		var tg := reader.telegraph(i)
		if tg.is_empty() or tg.get("move", -1) != WorldReader.MOVE_LEAP:
			continue
		if not tg.get("locked", false) or reader.actor_state(i) != WorldReader.STATE_WINDUP:
			continue
		# A Leap just locked: walk out of its circle with the stick until she has landed.
		locked_seen = true
		var center: Vector2 = tg["center"]
		var radius: float = tg["radius"]
		assert_true(tg.get("tracked", false), "the circle tracked the player")
		assert_lt(
			reader.player_pos().distance_to(center), 0.3, "it locked on where the player stood"
		)
		e.stick_toward(_way_out(w, reader.player_pos(), reader.actor_pos(i)))
		var seq := w.last_event_seq()
		var landed := false
		var hit := false
		for f in 120:
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
			if now.is_empty() or now.get("move", -1) != WorldReader.MOVE_LEAP:
				landed = true
				break
			assert_eq(now["center"], center, "the circle holds where it locked")
		e.stick_toward(Vector2.ZERO)
		assert_true(landed, "she landed")
		assert_gt(reader.player_pos().distance_to(center), radius, "the player walked out")
		assert_false(hit, "and the locked leap missed")
		dodged = landed and not hit
	assert_true(locked_seen, "a Leap locked on the player")
	assert_true(dodged, "dodged by moving after the lock")
	assert_gt(globs, 0, "the Brood Mother's acid globs were drawn")
