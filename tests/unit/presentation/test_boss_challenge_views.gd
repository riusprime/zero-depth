extends GutTest
## The boss challenge's views (v0.3.0 BX): the boss bar fills over exactly the rise (L22), the weak point glows on
## the model (energy only, L17), deflected and weak-point hits spark, the closing band and the pull's vortex are
## drawn, and dissolving enemies leave their motes (L20). Views read WorldReader only.


func test_the_boss_bar_fills_over_exactly_the_rise() -> void:
	var w := BossLab.world()
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	var id := w.spawn_boss(BossLab.table_index(w, &"gatekeeper"), Vector2(6, 0))
	hud.sync(reader)
	assert_true(hud.boss_bar.visible, "the bar shows as the boss appears")
	assert_almost_eq(hud.boss_bar.hp_fraction(), 0.0, 0.001, "empty")
	var last := 0.0
	for t in range(1, BossAi.INTRO_TICKS + 1):
		w.step(InputFrame.new())
		hud.sync(reader)
		var f := hud.boss_bar.hp_fraction()
		assert_gte(f, last, "it only fills")
		last = f
		if t < BossAi.INTRO_TICKS:
			assert_almost_eq(f, float(t) / BossAi.INTRO_TICKS, 0.001, "tick %d" % t)
			assert_eq(w.actors.state[w.actors.index_of(id)], EnemyAi.State.SPAWN, "still rising")
	assert_almost_eq(hud.boss_bar.hp_fraction(), 1.0, 0.001, "full the tick it acts")
	assert_ne(w.actors.state[w.actors.index_of(id)], EnemyAi.State.SPAWN)
	var i := w.actors.index_of(id)
	Damage.hit(w, i, 280, 1, 1, 1, 0, Vector2(6, 5), w.actors.pos(i))
	hud.sync(reader)
	assert_almost_eq(hud.boss_bar.hp_fraction(), 0.8, 0.01, "then its real HP")


func test_the_weak_point_glows_on_the_model_by_energy_only() -> void:
	for avatar: BossAvatar in [
		GatekeeperAvatar.new(), BroodMotherAvatar.new(), SiegeEngineAvatar.new()
	]:
		add_child_autofree(avatar)
		avatar.setup(Color.BLACK)
		var mat := avatar.weak_material
		assert_true(mat.emission_enabled, "emission on from the start")
		avatar.apply_state(
			{"tick": 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_RECOVER, "weak": 1.0}
		)
		for k in 10:
			avatar.advance(0.05)
		assert_true(avatar.weak_core.visible, "open: the core shows")
		assert_gt(mat.emission_energy_multiplier, 1.0, "and glows")
		assert_gt(avatar.weak_light.light_energy, 0.5)
		avatar.apply_state(
			{"tick": 2, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE, "weak": 0.0}
		)
		for k in 20:
			avatar.advance(0.05)
		assert_false(avatar.weak_core.visible, "shut: hidden")
		assert_eq(mat.emission_energy_multiplier, 0.0)
		assert_true(mat.emission_enabled, "never toggled")


func test_the_avatar_reads_the_weak_point_from_the_sim() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper")
	var reader := WorldReader.new(w)
	assert_eq(reader.boss_weak_point_permille(i), 0)
	w.bosses.exposed_t[BossAi.entry_of(w, i)] = BossAi.table_of(w, i).weak_ticks / 2
	assert_eq(reader.boss_weak_point_permille(i), 500)
	assert_eq(reader.boss_weak_range_m(i), 2.5)


func _hit_feel() -> HitFeel:
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var hf := HitFeel.new(actors, rig)
	add_child_autofree(hf)
	return hf


func test_deflected_and_weak_point_hits_spark() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"brood_mother")
	var reader := WorldReader.new(w)
	var hf := _hit_feel()
	hf.sync(reader)
	var before := hf.spark_count()
	w.actors.set_pos(0, Vector2(12, 0))
	Damage.hit(w, i, 10, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i))
	hf.sync(reader)
	assert_eq(hf.spark_count() - before, 3, "a small dull spark for a deflected hit")
	before = hf.spark_count()
	w.bosses.exposed_t[BossAi.entry_of(w, i)] = 60
	w.actors.set_pos(0, Vector2(2, 0))
	Damage.hit(w, i, 10, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i))
	hf.sync(reader)
	assert_eq(hf.spark_count() - before, 9, "a big bright one on the weak point")


func test_the_band_the_vortex_and_the_dissolve_are_drawn() -> void:
	var w := BossLab.world()
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(4, 4))
	w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(-4, 4))
	var reader := WorldReader.new(w)
	var view := BossChallengeView.new()
	add_child_autofree(view)
	view.sync(reader)
	assert_eq(view.band(), {}, "no boss: nothing")
	BossChallenge.dissolve_floor(w)
	var i := BossLab.ready_boss(w, &"gatekeeper")
	view.sync(reader)
	assert_eq(view.dissolved_count(), 2, "both enemies dissolve on screen")
	var b := BossAi.entry_of(w, i)
	var t := BossAi.table_of(w, i)
	w.bosses.arena = Rect2(-15, -15, 30, 30)
	w.bosses.close_t[b] = t.close_step_ticks * 2 - t.close_warn_ticks / 2
	view.sync(reader)
	assert_eq(view.band()["depth"], Vector2(1, 1))
	assert_gt((view.band_mesh.mesh as ImmediateMesh).get_surface_count(), 0, "the band that hurts")
	assert_gt((view.warn_mesh.mesh as ImmediateMesh).get_surface_count(), 0, "the next step marked")
	w.actors.set_pos(0, Vector2(10, 0))
	BossLab.start(w, i, &"vortex_slam")
	view.sync(reader)
	assert_eq(view.vortex_count(), 1, "the vortex turns while the pull winds up")
	view._process(0.05)
	assert_gt((view.vortex_mesh.mesh as ImmediateMesh).get_surface_count(), 0)
