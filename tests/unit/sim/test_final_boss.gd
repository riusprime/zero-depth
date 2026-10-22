# gdlint: disable=max-public-methods
extends GutTest
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F1-F3, F7): the final boss's flow and its fight in the sim. The Ascension
## portal (any loop; v0.8.0 P2, End the run before) leads to the final arena instead of winning at once; the Loop device
## (Ascend before P2) loops; the arena is a round walled room;
## one fight, three bodies: a body keeps 1 HP until its segment ends, then shatters (1.5 s, invulnerable, every
## hostile shot cleared) and the next rises where it stood; the last one's fall wins the run; the Colossus scales
## with the loop like the floors' bosses; a world saved at a body's start resumes there.

const LONG := 1 << 24


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(_repo().get_def(&"run", SaveLab.RUN_ID))


func _arena(seed_value: int = 41, loop: int = 1) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value, &"blade", loop))
	w.actors.invuln[0] = LONG
	return w


# --- F1: the flow -------------------------------------------------------------------------------------------------


func test_the_run_names_its_final_boss() -> void:
	var t := _run_table()
	assert_eq(
		t.final_bosses,
		[&"colossus", &"prism", &"nemesis"] as Array[StringName],
		"three bodies in order"
	)
	assert_eq(t.final_name_key, &"BOSS_HOLLOW_CROWN")
	assert_eq(t.final_arena, &"hollow_arena")
	assert_eq(t.final_shatter_ticks, 90, "the shatter: 1.5 s")
	var finals := ContentCompiler.compile_final_bosses(_repo(), t)
	assert_eq(finals.size(), 3)
	assert_eq(finals[0].kind, ActorStore.Kind.COLOSSUS)
	assert_eq(finals[1].kind, ActorStore.Kind.PRISM)
	assert_eq(finals[2].kind, ActorStore.Kind.NEMESIS)
	for f in finals:
		assert_true(BossAi.is_boss_kind(f.kind), "%s is a boss" % f.id)


func test_the_floors_boss_indices_stay_as_they_were() -> void:
	var ids := []
	for b in ContentCompiler.compile_bosses(_repo()):
		ids.append(b.id)
	assert_eq(
		ids,
		[&"brood_mother", &"foundry", &"gatekeeper", &"hive_lens", &"siege_engine", &"warlord"],
		"the final bodies are in their own category, so every saved boss index means what it did"
	)


func test_end_the_run_leads_to_the_final_arena() -> void:
	var run := SaveLab.run_state(51, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	assert_true(w.boss_flow.ascension)
	assert_true(w.boss_flow.final_next, "the run has a final boss")
	w.boss_flow.ascend_choice = Ascension.Choice.ASCENSION
	w.boss_flow.state = BossFlow.State.EXITED
	assert_eq(WorldReader.new(w).outcome(), 3, "End the run: on to the next world, not a win")
	run.finish_floor(w)
	assert_true(run.final_fight, "the next world is the final arena")
	assert_eq(run.floor_index, 5, "still the loop's last floor (v0.9.0 FV: floor 5)")
	assert_eq(run.loop, 1, "no loop after it")


func test_end_on_a_later_loop_leads_there_too() -> void:
	var run := SaveLab.run_state(52, SaveLab.floors())
	run.loop = 3
	run.loop_floors = 10
	while run.routes.size() < run.run_floor():
		run.routes.append(Routes.Route.NORMAL)
	var w := SaveLab.build_floor(run)
	assert_true(w.boss_flow.final_next, "any loop")
	w.boss_flow.ascend_choice = Ascension.Choice.ASCENSION
	w.boss_flow.state = BossFlow.State.EXITED
	assert_eq(WorldReader.new(w).outcome(), 3)
	run.finish_floor(w)
	assert_true(run.final_fight)
	assert_eq(run.loop, 3)


func test_ascend_skips_the_final_boss() -> void:
	var run := SaveLab.run_state(53, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	w.boss_flow.ascend_choice = Ascension.Choice.LOOP
	w.boss_flow.state = BossFlow.State.EXITED
	assert_eq(WorldReader.new(w).outcome(), 3)
	run.finish_floor(w)
	assert_false(run.final_fight, "Ascend goes on to the next loop")
	assert_eq(run.loop, 2)
	assert_eq(run.floor_index, 1)


func test_a_run_without_a_final_boss_ends_at_once() -> void:
	var run := SaveLab.run_state(54, SaveLab.floors())
	run.table.final_bosses = []
	var w := SaveLab.build_floor(run)
	assert_false(w.boss_flow.final_next)
	w.boss_flow.ascend_choice = Ascension.Choice.ASCENSION
	w.boss_flow.state = BossFlow.State.EXITED
	assert_eq(WorldReader.new(w).outcome(), 1, "as before FB1")


# --- F2: the arena ------------------------------------------------------------------------------------------------


func test_the_arena_is_a_round_walled_room() -> void:
	var w := _arena(61)
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	var r := FinalArena.radius_of(f)
	assert_almost_eq(r, 15.0, 0.01, "the arena's radius (data)")
	assert_eq(FinalArena.segments_of(f), 32, "32 wall segments")
	assert_eq(f.walls.size(), 32, "nothing inside: no cover")
	for o in f.walls:
		assert_almost_eq(
			Kin.length(o.center) - o.half.x, r, 0.01, "each inner face stands on the circle"
		)
	assert_true(reader.final_arena())
	assert_false(reader.has_gate(), "no portal gate in the arena")
	assert_almost_eq(
		Kin.length(w.player_pos()), r * FinalArena.START_FRACTION, 0.05, "the hero arrives inside"
	)
	assert_eq(f.room_of(w.player_pos()), 0)
	assert_lt(Kin.length(f.portal_pos), r + 1.0, "the sealed gate stands in the ring")
	assert_gt(Kin.length(f.portal_pos), r - 0.01)


func test_nothing_leaves_the_ring() -> void:
	var w := _arena(62)
	w.actors.set_pos(0, Vector2.ZERO)
	var r := FinalArena.radius_of(w.floor_layout)
	for d in 16:
		var to := Kin.dir(d * 256) * (r + 10.0)
		w.actors.set_pos(0, Vector2.ZERO)
		w.vel = Vector2.ZERO
		for k in 260:
			w.step(FinalLab.walk(w, to))
		assert_lt(Kin.length(w.player_pos()), r, "walking toward %d stays inside the ring" % d)


func test_the_arena_is_built_the_same_way_every_time() -> void:
	var a := _arena(63)
	var b := _arena(63)
	assert_eq(a.state_hash(), b.state_hash())
	for k in 200:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")


# --- F3: one fight, three bodies ---------------------------------------------------------------------------------


func test_the_colossus_rises_at_the_centre_first() -> void:
	var w := _arena(71)
	var i := FinalLab.body(w)
	assert_gte(i, 0)
	assert_eq(w.actors.kinds[i], ActorStore.Kind.COLOSSUS)
	assert_eq(w.actors.pos(i), Vector2.ZERO)
	assert_eq(w.final_fight.phase, 0)
	var reader := WorldReader.new(w)
	assert_eq(reader.final_phases(), 3)
	assert_eq(reader.final_segment_name_key(0), &"BOSS_COLOSSUS")
	assert_eq(reader.final_segment_name_key(1), &"BOSS_PRISM")
	assert_eq(reader.final_segment_name_key(2), &"BOSS_NEMESIS")
	assert_eq(reader.final_name_key(), &"BOSS_HOLLOW_CROWN")
	FinalLab.past_rise(w)
	assert_eq(reader.final_segment_permille(0), 1000, "full once risen")
	assert_eq(reader.final_segment_permille(1), 1000, "the bodies to come are full")


func test_a_body_keeps_one_hp_until_its_segment_ends() -> void:
	var w := _arena(72)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	FinalLab.hit(w, w.actors.hp[i] * 10)
	assert_eq(w.actors.hp[i], 1, "even the world's own hit leaves it 1 HP")
	assert_eq(w.actors.dead[i], 0)


func test_the_segment_end_shatters_the_body() -> void:
	var w := _arena(73)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	var id := w.actors.ids[i]
	var at := w.actors.pos(i)
	# hostile shots on the floor, and its rise's leftovers
	w.queue_projectile(id, ActorStore.TEAM_ENEMY, Vector2(4, 0), Vector2(0.01, 0), 5, 0.2, 600, 0)
	w.queue_projectile(id, ActorStore.TEAM_ENEMY, Vector2(-4, 0), Vector2(0.01, 0), 5, 0.2, 600, 0)
	w.step(InputFrame.new())
	var hostile := func() -> int:
		var n := 0
		for k in w.projectiles.size():
			if w.projectiles.team[k] != ActorStore.TEAM_PLAYER:
				n += 1
		return n
	assert_eq(hostile.call(), 2, "two hostile shots fly")
	FinalLab.end_segment(w)
	i = w.actors.index_of(id)
	assert_eq(w.actors.state[i], FinalBoss.SHATTER, "it shatters")
	assert_true(FinalBoss.shattering(w))
	assert_eq(hostile.call(), 0, "every hostile shot cleared")
	var reader := WorldReader.new(w)
	assert_eq(reader.final_segment_permille(0), 0, "its segment is empty")
	var hp := w.actors.hp[i]
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 50, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, at, at)
	assert_eq(w.actors.hp[i], hp, "it can't be hurt while it shatters")
	var ticks := 0
	while FinalBoss.shattering(w) and ticks < 200:
		w.step(InputFrame.new())
		ticks += 1
		assert_eq(hostile.call(), 0, "no shot while it shatters")
	assert_eq(ticks, w.final_fight.shatter_ticks, "the shatter lasts its 1.5 s")
	assert_eq(w.actors.index_of(id), -1, "the Colossus is gone")
	var j := FinalLab.body(w)
	assert_eq(w.actors.kinds[j], ActorStore.Kind.PRISM, "the Prism rises")
	assert_eq(w.actors.pos(j), at, "where the Colossus stood")
	assert_eq(w.actors.state[j], EnemyAi.State.SPAWN, "rising")
	assert_eq(w.final_fight.phase, 1)
	assert_eq(w.final_fight.phase_tick, w.tick - 1, "its start")


func test_a_shattered_body_counts_as_defeated() -> void:
	var w := _arena(74)
	FinalLab.past_rise(w)
	var seq := w.last_event_seq()
	FinalLab.end_segment(w)
	FinalLab.through_shatter(w)
	var defeated := 0
	var shattered := 0
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.BOSS_DEFEATED:
			defeated += 1
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == FinalBoss.EFFECT_SHATTER:
			shattered += 1
	assert_eq(defeated, 1, "the Codex counts the Colossus beaten")
	assert_eq(shattered, 1, "the views see one shatter")


func test_the_last_body_wins_the_run() -> void:
	var w := _arena(75)
	var reader := WorldReader.new(w)
	FinalLab.past_rise(w)
	for k in 2:
		FinalLab.end_segment(w)
		FinalLab.through_shatter(w)
	assert_eq(w.actors.kinds[FinalLab.body(w)], ActorStore.Kind.NEMESIS)
	assert_eq(reader.outcome(), 0)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	w.step(InputFrame.new())
	assert_true(w.final_fight.won)
	assert_true(reader.final_won())
	assert_eq(reader.outcome(), 1, "the run is won")
	var run := FinalLab.run_state(75)
	assert_eq(run.loops_cleared(w), 1, "the loop counts as cleared")


func test_dying_to_it_is_a_death() -> void:
	var w := _arena(76)
	var run := FinalLab.run_state(76)
	w.actors.invuln[0] = 0
	w.actors.hp[0] = 1
	FinalLab.past_rise(w)
	for k in 1200:
		w.step(InputFrame.new())
		if w.player_dead():
			break
	assert_true(w.player_dead(), "the Colossus kills a hero who stands still")
	assert_eq(WorldReader.new(w).outcome(), 2)
	assert_ne(WorldReader.new(w).killer_cause_key(), &"", "a named death")
	assert_eq(run.loops_cleared(w), 0, "dying to it clears no loop")


func test_the_run_clock_counts_in_the_arena() -> void:
	var w := _arena(77)
	CombatLab.idle(w, 120)
	assert_eq(w.run_ticks, 120, "the fight's time is the run's")


func test_the_colossus_scales_with_the_loop() -> void:
	var w1 := _arena(78, 1)
	var w2 := _arena(78, 2)
	var hp1 := w1.actors.max_hp[FinalLab.body(w1)]
	var hp2 := w2.actors.max_hp[FinalLab.body(w2)]
	var t := _run_table()
	assert_gt(
		hp2, hp1 * (t.loop_boss_hp_permille / 1000) - 2, "its HP × the loop's boss factor (F7)"
	)


# --- Saves --------------------------------------------------------------------------------------------------------


func test_a_save_at_a_body_start_resumes_there() -> void:
	var run := FinalLab.run_state(81)
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = LONG
	FinalLab.past_rise(w)
	var saver := RunSaver.new(RunSaveStore.new(""))
	saver.begin_floor(w, run, 81)
	assert_eq(saver.entries, 1, "the arena's start saves (the first body's start)")
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] * 10)
	for k in 200:
		w.step(InputFrame.new())
		saver.after_tick(w, run, 81)
		if w.final_fight.phase == 1:
			break
	assert_eq(saver.entries, 2, "the Prism's start saves")
	var p := saver.last
	assert_true(bool(p["run"]["final"]), "the run is at its final boss")
	var back := RunSaver.run_from(p, _run_table())
	assert_true(back.final_fight)
	var w2 := FinalLab.arena(back, false)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "the snapshot fits the rebuilt arena")
	assert_eq(w2.state_hash(), w.state_hash(), "Continue resumes at the Prism's start")
	assert_eq(w2.final_fight.phase, 1)
	assert_eq(w2.actors.state[FinalLab.body(w2)], EnemyAi.State.SPAWN, "rising, as it was saved")
	for k in 120:
		w.step(InputFrame.new())
		w2.step(InputFrame.new())
	assert_eq(w2.state_hash(), w.state_hash(), "and the fight goes on the same")


func test_a_snapshot_mid_shatter_round_trips() -> void:
	var run := FinalLab.run_state(82)
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = LONG
	FinalLab.past_rise(w)
	FinalLab.end_segment(w)
	CombatLab.idle(w, 20)
	var snap := w.to_snapshot()
	var w2 := FinalLab.arena(run, false)
	assert_eq(WorldSnapshot.apply(w2, snap), "")
	assert_eq(w2.state_hash(), w.state_hash())
	for k in 150:
		w.step(InputFrame.new())
		w2.step(InputFrame.new())
	assert_eq(w2.state_hash(), w.state_hash(), "the shatter and the rise go on the same")


func test_an_ascension_floor_saved_before_fb1_still_loads_and_leads_on() -> void:
	var run := SaveLab.run_state(83, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 20)
	var p := RunSaver.payload_of(w, run, 83, PackedByteArray())
	(p["run"] as Dictionary).erase("final")  # as a payload written before FB1
	var snap: Dictionary = p["world"]["world"]
	snap.erase(&"final_fight")
	(snap[&"boss_flow"] as Dictionary).erase(&"final_next")
	var back := RunSaver.run_from(p, _run_table())
	assert_false(back.final_fight)
	var w2 := SaveLab.build_floor(back)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "a snapshot without the FB1 fields restores")
	assert_eq(w2.state_hash(), w.state_hash(), "the same state")
	assert_true(w2.boss_flow.final_next, "and End the run now leads to the final boss")
	assert_null(w2.final_fight)


# --- the Playground's summon and the dev jump -----------------------------------------------------------------------


func test_a_jump_hands_the_fight_to_a_body() -> void:
	var w := _arena(91)
	FinalLab.past_rise(w)
	var old := w.actors.ids[FinalLab.body(w)]
	FinalBoss.jump(w, 2)
	assert_eq(w.actors.index_of(old), -1, "the Colossus leaves")
	assert_eq(w.actors.kinds[FinalLab.body(w)], ActorStore.Kind.NEMESIS)
	assert_eq(w.final_fight.phase, 2)
	assert_eq(WorldReader.new(w).final_segment_permille(0), 0)
	assert_eq(WorldReader.new(w).final_segment_permille(1), 0, "the skipped bodies count as beaten")


func test_the_shatter_state_is_its_own() -> void:
	var taken := [
		BossAi.STAGGERED,
		BossAi.GATE,
		BossSignatures.EGG,
		BossSignatures.EGG_BURST,
		BossSignatures.EGG_GONE,
	]
	for s: int in EnemyAi.State.values():
		taken.append(s)
	assert_false(
		taken.has(FinalBoss.SHATTER), "the views read a body's shatter off its state alone"
	)
