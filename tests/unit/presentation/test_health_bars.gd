extends GutTest
## v0.8.0 N4 (owner O56, O57): health bars that show the hit, the heal and the shield. The shared HealthBarTrail: the
## damage chunk holds from the burst's FIRST hit (later hits never restart it), then drains; under steady hits it
## always moves; a big hit lights it; a heal grows the fill; reduced motion makes both near-instant. The hero's HUD
## bar, the bars over enemies (one MultiMesh) and the boss bar use it; the boss bar is one full bar per phase that
## refills (animated) on a phase change and turns its invulnerable look (colour, "Invulnerable", the shields left)
## while the sim says the boss can't be hurt. Views read WorldReader only.

const DT := 1.0 / 60.0


func after_each() -> void:
	HudStyle.reduced_motion = false


func _run(t: HealthBarTrail, seconds: float) -> void:
	for k in roundi(seconds / DT):
		t.advance(DT)


func test_the_chunk_holds_from_the_bursts_first_hit_then_drains() -> void:
	var t := HealthBarTrail.new()
	t.set_target(0.9)
	assert_almost_eq(t.fill, 0.9, 0.0001, "the fill drops at once")
	assert_almost_eq(t.chunk_size(), 0.1, 0.0001, "the chunk keeps what was lost")
	assert_true(t.holding())
	_run(t, 0.2)
	t.set_target(0.8)  # later hits of the burst
	_run(t, 0.2)
	t.set_target(0.7)
	assert_almost_eq(t.chunk, 1.0, 0.0001, "the chunk still starts where the burst began")
	_run(t, 0.05)
	assert_true(t.holding(), "0.45 s after the first hit: still holding")
	_run(t, 0.1)
	assert_true(
		t.draining(),
		"0.55 s after the FIRST hit it drains: the later hits did not restart the hold"
	)
	assert_lt(t.chunk, 1.0, "and it moved")
	_run(t, HealthBarTrail.DRAIN_S + 0.05)
	assert_almost_eq(t.chunk_size(), 0.0, 0.0001, "drained to the fill")
	_run(t, HealthBarTrail.QUIET_S)
	assert_false(t.moving(), "the burst is over")
	t.set_target(0.6)
	assert_true(t.holding(), "a new burst holds again")


func test_under_steady_hits_the_chunk_always_moves() -> void:
	var t := HealthBarTrail.new()
	var edges: Array[float] = []
	var most := 0.0
	for k in 180:  # 3 s, a hit every 6 frames (10 a second), 0.4 % of the bar each
		if k % 6 == 0:
			t.set_target(t.target - 0.004)
		t.advance(DT)
		most = maxf(most, t.chunk_size())
		if k % 30 == 29:
			edges.append(t.chunk)
	for k in range(2, edges.size()):  # past the first hold
		assert_lt(edges[k], edges[k - 1], "the chunk's edge moved down (second %.1f)" % (k * 0.5))
	assert_lt(most, 0.05, "it trails the hits; it never grows without bound")


func test_a_big_hit_makes_a_big_lit_chunk() -> void:
	var small := HealthBarTrail.new()
	small.set_target(0.98)
	assert_eq(small.big, 0.0, "a small hit: the plain chunk")
	var t := HealthBarTrail.new()
	t.set_target(0.6)
	assert_almost_eq(t.chunk_size(), 0.4, 0.0001, "a huge crit's chunk is huge")
	assert_gt(t.big, 0.0, "and lit brighter")
	_run(t, HealthBarTrail.BIG_S + 0.02)
	assert_eq(t.big, 0.0)
	assert_almost_eq(t.chunk_size(), 0.4, 0.0001, "still holding all of it")


func test_a_heal_grows_the_fill() -> void:
	var t := HealthBarTrail.new()
	t.snap(0.2)
	t.set_target(1.0)
	assert_almost_eq(t.fill, 0.2, 0.0001, "no jump")
	assert_true(t.refilling())
	_run(t, HealthBarTrail.REFILL_S * 0.5)
	assert_almost_eq(t.fill, 0.6, 0.03, "half way through the refill")
	assert_eq(t.chunk_size(), 0.0, "no chunk on a heal")
	_run(t, HealthBarTrail.REFILL_S * 0.5 + 0.05)
	assert_almost_eq(t.fill, 1.0, 0.0001, "full")
	assert_false(t.moving())


func test_reduced_motion_makes_it_near_instant() -> void:
	HudStyle.reduced_motion = true
	var t := HealthBarTrail.new()
	t.set_target(0.5)
	assert_false(t.holding(), "no hold")
	_run(t, HealthBarTrail.CALM_S + DT)
	assert_almost_eq(t.chunk_size(), 0.0, 0.0001, "drained at once")
	t.set_target(1.0)
	_run(t, HealthBarTrail.CALM_S + DT)
	assert_almost_eq(t.fill, 1.0, 0.0001, "refilled at once")


func test_the_heros_hud_bar_shows_the_chunk() -> void:
	var w := CombatLab.world()
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	var bar := hud.hp_bar()
	w.actors.hp[0] = w.actors.max_hp[0] * 6 / 10
	hud.sync(reader)
	assert_almost_eq(bar.shown_fraction(), 0.6, 0.01, "the fill drops at once")
	assert_almost_eq(bar.chunk_fraction(), 0.4, 0.01, "the chunk keeps the loss")
	assert_eq(bar.chunk_color(), HudBar.CHUNK_BIG, "a big loss: lit")
	for k in roundi((HealthBarTrail.HOLD_S + HealthBarTrail.DRAIN_S + 0.1) / DT):
		bar._process(DT)
	assert_almost_eq(bar.chunk_fraction(), 0.0, 0.001, "then drains")


func test_enemy_bars_carry_the_chunk_in_one_multimesh() -> void:
	var w := BossLab.world()
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	var ids: Array[int] = []
	for k in 6:
		ids.append(w.add_enemy(WorldReader.KIND_CHARGER, Vector2(4 + k, 3)))
	for k in 80:  # past the spawn-in
		w.step(InputFrame.new())
	views.sync(reader)
	for id in ids:
		var i := w.actors.index_of(id)
		w.actors.hp[i] = w.actors.max_hp[i] / 2
	views.sync(reader)
	views.bar_chunks.advance(DT)
	assert_eq(views.bar_chunks.drawn(), 12, "two strips a bar, all in the one MultiMesh")
	assert_true(views.bar_chunks.visible)
	var bar: Node3D = views.actor_node(ids[0]).get_meta(&"bar")
	var i0 := w.actors.index_of(ids[0])
	var frac := float(w.actors.hp[i0]) / w.actors.max_hp[i0]
	assert_almost_eq(bar.scale.x, frac, 0.001, "the bar shows the HP")
	assert_almost_eq(views.bar_chunks.trail_of(ids[0]).chunk_size(), 1.0 - frac, 0.001)
	assert_eq(
		views.find_children("*", "MultiMeshInstance3D", true, false).size(),
		1,
		"one MultiMesh for every bar's chunk"
	)
	for k in roundi((HealthBarTrail.HOLD_S + HealthBarTrail.DRAIN_S + 0.1) / DT):
		views.bar_chunks.advance(DT)
	assert_eq(views.bar_chunks.drawn(), 0, "drained: nothing drawn")
	assert_false(views.bar_chunks.visible)


func test_the_boss_bar_refills_on_a_phase_change_and_says_invulnerable() -> void:
	var w := BossLab.world()
	var reader := WorldReader.new(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(6, 0))
	var aid := w.actors.ids[i]
	w.actors.cd[i] = 1 << 20
	bar.sync(reader)
	assert_almost_eq(bar.hp_fraction(), 1.0, 0.001, "a full bar")
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [1, 3])
	assert_false(bar.invulnerable(), "it can be hurt")
	assert_eq(bar.shield_text(), "")
	assert_eq(bar.hp_bar().color, ThemePalette.color(&"enemy_bar"))
	Damage.hit(w, i, 99999, 1, 1, 1, 0, Vector2(6, 5), w.actors.pos(i))  # stops at the 66 % gate
	bar.sync(reader)
	assert_almost_eq(bar.hp_fraction(), 0.0, 0.001, "the first phase's bar is empty")
	assert_gt(bar.chunk_fraction(), 0.9, "its chunk shows the whole phase taken")
	w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	assert_eq(w.actors.state[i], BossAi.GATE, "the gate runs")
	bar.sync(reader)
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [2, 3])
	assert_almost_eq(bar.hp_fraction(), 1.0, 0.001, "the second phase starts full")
	assert_lt(bar.shown_fraction(), 0.05, "but the bar grows to it, not at once")
	assert_true(bar.invulnerable(), "the gate can't be hurt")
	assert_eq(bar.hp_bar().color, BossBar.INVULNERABLE, "the bar changes colour")
	assert_eq(
		bar.shield_text(),
		tr("HUD_BOSS_INVULNERABLE") + "  ·  " + tr("HUD_BOSS_SHIELD_ONE"),
		"Invulnerable, and the one gate still to come"
	)
	for k in 24:
		bar.hp_bar()._process(DT)
	var mid := bar.shown_fraction()
	assert_between(mid, 0.3, 0.7, "the refill mid-way")
	for k in 30:
		bar.hp_bar()._process(DT)
	assert_almost_eq(bar.shown_fraction(), 1.0, 0.001, "refilled")
	BossLab.through_gate(w, aid)
	CombatLab.until(
		w,
		func(x: World) -> bool:
			return not WorldReader.new(x).boss_invulnerable(x.actors.index_of(aid))
	)
	bar.sync(reader)
	assert_false(bar.invulnerable(), "past the gate it can be hurt again")
	assert_eq(bar.shield_text(), "")


func test_a_shielded_pattern_shows_invulnerable() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"hive_lens", Vector2.ZERO)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	w.actors.cd[i] = 1 << 20
	var reader := WorldReader.new(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	BossLab.start(w, i, &"prism_spiral")
	for t in 50:
		w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	assert_true(reader.boss_shielded(i), "the signature pattern's shield is up")
	assert_true(reader.boss_invulnerable(i))
	bar.sync(reader)
	assert_true(bar.invulnerable())
	assert_string_starts_with(bar.shield_text(), tr("HUD_BOSS_INVULNERABLE"))
	assert_string_contains(bar.shield_text(), tr("HUD_BOSS_SHIELDS") % 2, "two gates still ahead")
	BossLab.until_open(w, aid)
	w.step(InputFrame.new())
	bar.sync(reader)
	assert_false(bar.invulnerable(), "open between patterns")


## Owner O59: nothing on the final boss's bar hints how many bodies remain: its shields left are its own gates only.
func test_the_final_bodies_shields_left_never_count_the_bodies_to_come() -> void:
	var run := FinalLab.run_state(207)
	var w := FinalLab.arena(run)
	var reader := WorldReader.new(w)
	FinalLab.past_rise(w)
	var b := FinalLab.body(w)
	assert_eq(reader.boss_shields_left(b), 1, "the Colossus's own gate only")
	FinalLab.end_segment(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	bar.sync(reader)
	assert_true(bar.invulnerable(), "the shatter")
	assert_string_starts_with(bar.shield_text(), tr("HUD_BOSS_INVULNERABLE"))
	assert_false(
		bar.shield_text().contains(tr("HUD_BOSS_SHIELDS") % 2),
		"the two bodies to come aren't counted"
	)
	assert_eq(bar.phase_text(), tr(reader.final_segment_name_key(0)), "its name only")
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	assert_eq(reader.boss_shields_left(FinalLab.body(w)), 0, "the Prism: no gate")
