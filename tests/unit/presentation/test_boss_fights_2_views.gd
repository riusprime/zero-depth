extends GutTest
## v0.7.5 BF2 (owner N15; BOSS_FIGHTS.md "Fireball looks", "Readable"): the Brood Mother's acid globs and the Hive
## Lens's prism orbs are drawn by FireballViews in their own looks (never the hero's colours: the BF1 test covers every
## look); the Egg Storm's eggs fly onto their locked circles (BossShieldView); the Hive Lens closes its eye while its
## Prism Spiral keeps it shielded (the sim's read drives the model's shielded pose); and the avatars pose the new moves.

const DT := 1.0 / 60.0


func _firing(id: StringName, attack_id: StringName, ticks: int) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(9, 0))
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	BossLab.start(w, i, attack_id)
	CombatLab.idle(w, ticks)
	return [w, w.actors.ids[i]]


func test_acid_globs_and_prism_orbs_are_drawn_in_their_looks() -> void:
	for spec in [
		[&"brood_mother", &"web_spiral", 90, &"acid_glob"],
		[&"hive_lens", &"prism_spiral", 110, &"prism_orb"],
	]:
		var s := _firing(spec[0], spec[1], spec[2])
		var reader := WorldReader.new(s[0])
		assert_gt(reader.projectile_count(), 0, "%s fires" % spec[1])
		var fb := FireballViews.new()
		add_child_autofree(fb)
		fb.sync(reader)
		assert_eq(fb.ball_count(spec[3]), reader.projectile_count(), "%s: in its look" % spec[1])
		assert_true(FireballViews.LOOKS.has(spec[3]), "its own look, not the default")


func test_the_looks_differ_from_each_other_and_from_the_other_bosses() -> void:
	var cores := []
	for key: StringName in FireballViews.LOOKS:
		cores.append([key, FireballViews.look_of(key)["core"]])
	for a in cores:
		for b in cores:
			if a[0] == b[0]:
				continue
			var d := Vector3(a[1].r - b[1].r, a[1].g - b[1].g, a[1].b - b[1].b).length()
			assert_gt(d, 0.15, "%s and %s read apart" % [a[0], b[0]])


func test_each_locked_egg_flies_onto_its_circle() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"brood_mother", Vector2.ZERO)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	BossLab.start(w, i, &"egg_storm")
	var reader := WorldReader.new(w)
	var view := BossShieldView.new()
	add_child_autofree(view)
	var atk := BossAi.attack_of(w, i)
	CombatLab.idle(w, 10)
	view.sync(reader)
	assert_eq(view.lob_count(), 0, "tracking: no egg yet")
	assert_eq(view.count(), 1, "the shell stands through the Egg Storm")
	var most := 0
	for t in atk.windup_ticks + atk.active_ticks:
		w.actors.set_pos(0, Vector2(6, 0) + Vector2(0, 0.05) * t)
		w.step(InputFrame.new())
		view.sync(reader)
		var tg := reader.telegraph(w.actors.index_of(aid))
		var flying := 0
		for item: Dictionary in tg.get("items", []):
			flying += 1 if item.has("lob") else 0
		assert_eq(view.lob_count(), flying, "an egg per locked circle")
		most = maxi(most, flying)
	assert_gt(most, 0, "eggs flew")


func test_the_hive_lens_closes_its_eye_while_its_prism_spiral_shields_it() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"hive_lens", Vector2.ZERO)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	var reader := WorldReader.new(w)
	var a := HiveLensAvatar.new()
	a.setup(Color("#1A1A22"), &"outline")
	add_child_autofree(a)
	a.set_process(false)
	w.actors.cd[i] = 1 << 20  # it waits: no attack of its own before the test's
	for t in 30:
		w.step(InputFrame.new())
		a.sync(reader, w.actors.index_of(aid))
		a.advance(DT)
	assert_lt(a.shielded_amount(), 0.1, "open")
	BossLab.start(w, w.actors.index_of(aid), &"prism_spiral")
	for t in 50:
		w.step(InputFrame.new())
		a.sync(reader, w.actors.index_of(aid))
		a.advance(DT)
	assert_true(reader.boss_shielded(w.actors.index_of(aid)))
	assert_gt(a.shielded_amount(), 0.9, "the eye closed")
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return x.actors.state[x.actors.index_of(aid)] == EnemyAi.State.RECOVER
	)
	for t in 40:
		w.step(InputFrame.new())
		a.sync(reader, w.actors.index_of(aid))
		a.advance(DT)
	assert_lt(a.shielded_amount(), 0.1, "it opens between patterns")


func test_the_avatars_pose_the_new_moves() -> void:
	var b := BroodMotherAvatar.new()
	b.setup(Color("#1A1A22"), &"outline")
	add_child_autofree(b)
	b.apply_state(
		{
			"tick": 1,
			"pos": Vector2.ZERO,
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_MARKS
		}
	)
	assert_eq(b._move, WorldReader.MOVE_BROOD, "the Egg Storm swells the egg sac")
	b.apply_state(
		{
			"tick": 1,
			"pos": Vector2.ZERO,
			"state": WorldReader.STATE_ACTIVE,
			"move": WorldReader.MOVE_PATTERN
		}
	)
	assert_eq(b._move, WorldReader.MOVE_BROOD, "the Web Spiral too")
	var h := HiveLensAvatar.new()
	h.setup(Color("#1A1A22"), &"outline")
	add_child_autofree(h)
	h.apply_state(
		{
			"tick": 1,
			"pos": Vector2.ZERO,
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_PATTERN
		}
	)
	assert_eq(h._move, WorldReader.MOVE_BOLT_FAN, "a pattern spins the crown up")
	h.apply_state(
		{
			"tick": 1,
			"pos": Vector2.ZERO,
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_LANES
		}
	)
	assert_eq(h._move, WorldReader.MOVE_RAIL, "the Focus Beam stretches the iris")
