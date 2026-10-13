extends GutTest
## v0.7.5 BF1 (owner N15; BOSS_FIGHTS.md "Readable"): the fireballs are drawn by FireballViews (pooled per look, never
## as ActorViews' plain shots), in their boss's look, never the hero's attack colours, with a bright core and a dark
## edge; Effects density Low thins the trails and keeps the balls; the shield shell stands while the boss is shielded;
## a tracking marker is a dull outline and a locked one a bright flash.

const LOW := "low"


func _firing(id: StringName, attack_id: StringName) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(9, 0))
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	BossLab.start(w, i, attack_id)
	CombatLab.idle(w, 70)
	return [w, i]


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_fireballs_are_drawn_in_their_bosss_look_and_not_as_plain_shots() -> void:
	for spec in [
		[&"gatekeeper", &"rock_rings", &"ember_stone"], [&"warlord", &"javelin_fan", &"spear_ember"]
	]:
		var s := _firing(spec[0], spec[1])
		var w: World = s[0]
		var reader := WorldReader.new(w)
		assert_gt(reader.projectile_count(), 0)
		var fb := FireballViews.new()
		add_child_autofree(fb)
		var actors := ActorViews.new()
		add_child_autofree(actors)
		fb.sync(reader)
		actors.sync(reader)
		assert_eq(fb.count(), reader.projectile_count(), "%s: every fireball drawn" % spec[1])
		assert_eq(fb.ball_count(spec[2]), reader.projectile_count(), "in its look")
		for k in reader.projectile_count():
			assert_null(actors.projectile_node(reader.projectile_id(k)), "not as a plain shot")
		fb._process(0.016)  # the blend between ticks draws too
		assert_eq(fb.ball_count(spec[2]), reader.projectile_count())


func test_hostile_looks_keep_off_the_heros_colours_with_a_bright_core_and_dark_edge() -> void:
	var hero := [
		ThemePalette.color(&"player_core"), HeatLooks.HOT, HeatLooks.OVERCLOCK, HeatLooks.WHITE_HOT
	]
	for key: StringName in FireballViews.LOOKS:
		var look := FireballViews.look_of(key)
		for c: Color in hero:
			assert_gt(_dist(look["core"], c), 0.2, "%s's core is not a hero colour" % key)
		assert_gt((look["core"] as Color).get_luminance(), 0.55, "%s: a bright core" % key)
		assert_lt((look["edge"] as Color).get_luminance(), 0.15, "%s: a dark edge" % key)
	assert_false(
		FireballViews.look_of(&"someone_new").is_empty(), "a new look draws before it is made"
	)
	for c: Color in BossShieldView.COLORS.values():
		assert_gt(
			_dist(c, ThemePalette.color(&"player_core")), 0.3, "a shell is never the hero's cyan"
		)


func test_effects_density_low_thins_the_trails_and_keeps_the_balls() -> void:
	var s := _firing(&"gatekeeper", &"rock_rings")
	var reader := WorldReader.new(s[0])
	var fb := FireballViews.new()
	add_child_autofree(fb)
	var was := ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	fb.sync(reader)
	var balls := fb.ball_count(&"ember_stone")
	var trails := fb.trail_count(&"ember_stone")
	assert_eq(trails, balls, "high: a trail each")
	ViewPrefs.effects_density = LOW
	fb.sync(reader)
	assert_eq(fb.ball_count(&"ember_stone"), balls, "low: the balls stay")
	assert_lt(fb.trail_count(&"ember_stone"), trails, "low: fewer trails")
	ViewPrefs.effects_density = was


func test_the_shield_shell_stands_while_shielded_only() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(9, 0))
	w.actors.hp[0] = 1 << 20
	var reader := WorldReader.new(w)
	var view := BossShieldView.new()
	add_child_autofree(view)
	view.sync(reader)
	assert_eq(view.count(), 0, "open: no shell")
	BossLab.start(w, i, &"rock_rings")
	w.step(InputFrame.new())
	view.sync(reader)
	assert_eq(view.count(), 1, "the shell rises with the signature pattern")
	view._process(0.2)
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return x.actors.state[x.actors.index_of(aid)] == EnemyAi.State.RECOVER
	)
	view.sync(reader)
	assert_eq(view.count(), 0, "gone as it opens")


func test_a_tracking_marker_is_dull_and_a_locked_one_flashes() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	var reader := WorldReader.new(w)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	BossLab.start(w, i, &"fist_slam")
	CombatLab.idle(w, 10)
	tv.sync(reader)
	assert_eq(tv.count(), 1)
	assert_eq(_surfaces(tv, "Fill"), 0, "tracking: no fill, an outline only")
	assert_gt(_surfaces(tv, "Edge"), 0)
	var atk := BossAi.attack_of(w, i)
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks - 10 + 2)
	tv.sync(reader)
	assert_true(reader.telegraph(i)["locked"])
	assert_gt(_surfaces(tv, "Fill"), 0, "locked: the bright filled flash")


func _surfaces(tv: TelegraphViews, part: String) -> int:
	var n := 0
	for mi: MeshInstance3D in tv.find_children(part, "MeshInstance3D", true, false):
		if mi.mesh is ImmediateMesh:
			n += (mi.mesh as ImmediateMesh).get_surface_count()
	return n
