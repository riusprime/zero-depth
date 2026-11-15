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
	await e.click_dev("God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"siege_engine")].name_key)
	for k in 8:
		if choice.text == name:
			break
		await e.click_dev("NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name)
	await e.click_dev("SpawnBoss")
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


## The Siege Engine's second phase reaches the screen: summoned from the dev panel as above, brought to its second
## phase (TEST HELPER: its HP is set just under the threshold; a real fight to it is minutes long), then real frames:
## a Target Lock's reticle is drawn on the reader's circle, and the shell it brings down leaves a boulder drawn on the
## wall's footprint.
func test_the_siege_engines_target_lock_and_boulder_are_drawn() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	await e.click_dev("God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, &"siege_engine")].name_key)
	for k in 8:
		if choice.text == name:
			break
		await e.click_dev("NextBoss")
		await e.frames(1)
	await e.click_dev("SpawnBoss")
	await e.frames(2)
	await e.tap(KEY_QUOTELEFT)
	assert_false(main.is_dev_panel_open())
	var reader := main.driver.reader
	var bid := reader.actor_id(reader.boss_index())
	var j := w.actors.index_of(bid)
	w.actors.hp[j] = w.actors.max_hp[j] * 650 / 1000
	var field: SiegeFieldViews = main.view.siege_field
	var seen_lock := false
	var lock_ok := false
	var shells := 0
	var seq := w.last_event_seq()
	for k in 60 * 40:
		await e.frames(1)
		# The shell leaves a boulder only inside the Engine's room on open floor: the stick keeps the hero 6-8 m
		# from it (real input), so the lock follows it there.
		var to := reader.actor_pos(w.actors.index_of(bid)) - reader.player_pos()
		var want := (
			to.normalized()
			if to.length() > 8.0
			else (-to.normalized() if to.length() < 6.0 else Vector2.ZERO)
		)
		e.stick_toward(want)
		# TEST HELPER: the start hall's own enemies crowding the hero are killed (a body within 0.3 m of the shell's
		# square leaves no boulder, the sim's rule; a swarmer hugging the hero blocked every shell here).
		for jj in range(1, w.actors.size()):
			if (
				w.actors.dead[jj] == 0
				and jj != w.actors.index_of(bid)
				and not WorldReader.is_boss_kind(w.actors.kinds[jj])
				and w.actors.pos(jj).distance_to(w.player_pos()) < 5.0
			):
				var hero_id := w.actors.ids[0]
				var at := w.actors.pos(jj)
				Damage.hit(w, jj, 1 << 20, hero_id, hero_id, w.take_root(), 0, w.player_pos(), at)
		shells += SiegeLab.ticks_of(w, &"siege_shell", seq).size()
		seq = w.last_event_seq()
		var siege := reader.boss_siege()
		if siege.is_empty():
			continue
		var lock: Dictionary = siege["lock"]
		var drawn := field.lock_circle()
		if not lock.is_empty() and not drawn.is_empty():
			seen_lock = true
			lock_ok = (
				(drawn[0] as Vector2).distance_to(lock["centre"]) < 0.3
				and is_equal_approx(drawn[1], float(lock["radius"]))
			)
		if not (siege["boulders"] as Array).is_empty() and field.boulders_shown() > 0:
			break
	assert_true(seen_lock, "a Target Lock's reticle was drawn")
	assert_true(lock_ok, "on the reader's circle, of its radius")
	e.stick_toward(Vector2.ZERO)
	gut.p("shells landed: %d" % shells)
	var rows: Array = reader.boss_siege().get("boulders", [])
	assert_false(rows.is_empty(), "a shell left a boulder")
	if rows.is_empty():
		return
	await e.frames(20)
	rows = reader.boss_siege()["boulders"]
	assert_eq(field.boulders_shown(), rows.size(), "a rock per boulder")
	var f := field.boulder_footprint(0)
	assert_almost_eq(f["centre"], rows[0]["centre"], Vector2(0.01, 0.01), "on the wall's footprint")
	assert_almost_eq((f["half"] as Vector2).x, float(rows[0]["half"]), 0.01)
