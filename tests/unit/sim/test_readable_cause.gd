extends GutTest
## No damage without a readable cause (PLAN v0.1.0 Step 9, v0.3.0 O): every hit the player takes on a real floor and
## in its boss room comes from an attack telegraphed for at least MIN_TELEGRAPH_TICKS (or a projectile on screen long
## enough) and has a death-recap line in en and es. The long, many-seed version is scripts/checks/readable_cause.gd.


func test_every_hit_on_each_floor_and_boss_has_a_readable_cause() -> void:
	var damage := 0
	# Two seeds: one seed alone left the bot with too few hits once the bosses learned to clear the floor (BX).
	for job in [[9100, 1], [9100, 2], [9100, 3], [9101, 1], [9101, 2], [9101, 3]]:
		var f: int = job[1]
		var r := CauseRun.run(job[0], f, 1200, 2400, &"guard" if f != 2 else &"blink")
		damage += int(r["damage"])
		assert_true(r["boss_seen"], "floor %d: its boss fought" % f)
		for v: Dictionary in r["violations"]:
			fail_test("unreadable hit: %s" % JSON.stringify(v))
		if not String(r["death_cause"]).is_empty():
			assert_eq(
				r["death_cause"],
				r["death_expected"],
				"floor %d: the recap names the killing hit" % f
			)
	assert_gt(damage, 20, "the bot was hit often enough for the check to mean something")


func test_a_hit_with_no_telegraph_is_reported() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(1.0, 0.0))
	var check := ReadableCause.new(w)
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 2)
	check.observe(w)
	var i := w.actors.index_of(id)
	Damage.hit(w, 0, 5, id, id, w.take_root(), SimEvent.TAG_MELEE, w.actors.pos(i), w.player_pos())
	check.observe(w)
	assert_eq(check.damage_count, 1)
	assert_eq(check.violations.size(), 1, "an untelegraphed hit fails the check")
	assert_eq(check.violations[0]["cause"], "CAUSE_CHARGER", "it still has its recap line")


func test_a_fresh_untelegraphed_projectile_is_reported_and_an_old_one_is_not() -> void:
	for age in [2, ReadableCause.PROJECTILE_MIN_TICKS + 2]:
		var w := CombatLab.world()
		var id := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(age * 0.2 + 1.0, 0.0))
		var check := ReadableCause.new(w)
		var at := w.actors.pos(w.actors.index_of(id))
		w.queue_projectile(
			id,
			ActorStore.TEAM_ENEMY,
			at - Vector2(0.5, 0),
			Vector2(-0.2, 0),
			5,
			0.1,
			200,
			SimEvent.TAG_PROJECTILE
		)
		for t in 80:
			w.step(InputFrame.new())
			check.observe(w)
			if check.damage_count > 0:
				break
		assert_eq(check.damage_count, 1, "the bolt hit (age %d)" % age)
		var fresh: bool = age < ReadableCause.PROJECTILE_MIN_TICKS
		assert_eq(check.violations.size(), 1 if fresh else 0, "bolt flying ~%d ticks" % age)


func test_every_cause_line_exists_in_both_languages() -> void:
	var rows := ReadableCause.locale_rows()
	var keys: Array = EndPanel.CAUSES.values()
	for t in BossLab.tables():
		for atk in t.attacks:
			keys.append(String(atk.cause_key))
	for k: String in keys:
		assert_true(rows.has(k), "%s is in strings.csv" % k)
		if rows.has(k):
			assert_false(String(rows[k][0]).is_empty(), "%s en" % k)
			assert_false(String(rows[k][1]).is_empty(), "%s es" % k)
