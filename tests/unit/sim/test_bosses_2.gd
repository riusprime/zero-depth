extends GutTest
## The second boss of each pool (PLAN v0.4.0 BO): the Warlord (floor 1), the Hive Lens (floor 2) and the Foundry
## (floor 3). The pools hold two bosses each and a run's draw meets both; every attack telegraphs at least the minimum
## before it lands; the new flood move (parallel lanes that stand while active: the Warlord's spears, the Foundry's
## molten floor); the Warlord's shield that drops while its weak point is open; the Hive Lens's split into three
## drones; the Foundry's Bomb Drones; the BX anti-kite rules on each; the recap's causes; determinism.

const S := EnemyAi.State
const NEW_BOSSES: Array[StringName] = [&"warlord", &"hive_lens", &"foundry"]
const POOLS := {
	1: [&"gatekeeper", &"warlord"],
	2: [&"brood_mother", &"hive_lens"],
	3: [&"siege_engine", &"foundry"]
}


func _until_state(w: World, aid: int, state: int, limit: int = 600) -> void:
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == state, limit
	)


func _count(w: World, kind: int) -> int:
	var n := 0
	for k in w.actors.size():
		if w.actors.kinds[k] == kind and w.actors.dead[k] == 0:
			n += 1
	return n


func test_each_pool_holds_two_bosses() -> void:
	var repo := ContentRepository.load_all()
	var tables := ContentCompiler.compile_bosses(repo)
	for f: int in POOLS:
		var pool := ContentCompiler.compile_boss_pool(repo, f)
		var ids := []
		for k in pool:
			ids.append(tables[k].id)
		ids.sort()
		var want: Array = POOLS[f].duplicate()
		want.sort()
		assert_eq(ids, want, "floor %d's pool" % f)


func test_the_runs_draw_meets_both_bosses_of_every_pool() -> void:
	var repo := ContentRepository.load_all()
	var tables := ContentCompiler.compile_bosses(repo)
	var run_table := ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors"))
	for f: int in POOLS:
		var pool := ContentCompiler.compile_boss_pool(repo, f)
		var seen := {}
		for s in 40:
			var run := RunState.start(1000 + s, run_table)
			seen[tables[run.pick_boss(pool, f)].id] = true
			assert_eq(
				run.pick_boss(pool, f),
				RunState.start(1000 + s, run_table).pick_boss(pool, f),
				"a run always meets the same boss"
			)
		for id: StringName in POOLS[f]:
			assert_true(seen.has(id), "floor %d: 40 runs meet %s" % [f, id])


func test_the_new_kinds_are_bosses() -> void:
	var w := BossLab.world()
	var want := {
		&"warlord": ActorStore.Kind.WARLORD,
		&"hive_lens": ActorStore.Kind.HIVE_LENS,
		&"foundry": ActorStore.Kind.FOUNDRY,
	}
	for id: StringName in want:
		var t := w.boss_tables[BossLab.table_index(w, id)]
		assert_eq(t.kind, want[id])
		assert_true(BossAi.is_boss_kind(t.kind), "%s is a boss kind" % id)
	assert_false(BossAi.is_boss_kind(ActorStore.Kind.LENS_DRONE), "its drones are not")
	assert_true(EnemyAi.is_enemy_kind(ActorStore.Kind.LENS_DRONE))


func test_arenas_come_from_data() -> void:
	var w := BossLab.world()
	var want := {
		&"warlord": [Vector2i(3, 2), FloorLayout.Template.OPEN],
		&"hive_lens": [Vector2i(2, 2), FloorLayout.Template.CENTRE],
		&"foundry": [Vector2i(3, 2), FloorLayout.Template.BUNKERS],
	}
	for id: StringName in want:
		var t := w.boss_tables[BossLab.table_index(w, id)]
		assert_eq(t.arena_cells, want[id][0], "%s arena size" % id)
		assert_eq(t.arena_template, want[id][1], "%s arena template" % id)


## The ticks a damaging telegraph shows before the attack first resolves on the player, standing at `stand`.
func _telegraph_lead(id: StringName, attack_id: StringName, stand: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, stand)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	BossLab.start(w, i, attack_id)
	var shown := 0
	for t in 400:
		var j := w.actors.index_of(aid)
		var tg := BossAi.telegraph(w, j)
		if not tg.is_empty() and tg["shape"] != &"ripple":
			shown += 1
		w.actors.set_pos(0, stand)
		w.step(InputFrame.new())
		if CombatLab.player_damage(w).size() > 0:
			return [shown, true]
	return [shown, false]


func test_every_attack_telegraphs_at_least_the_minimum_before_it_lands() -> void:
	var w := BossLab.world()
	for id in NEW_BOSSES:
		var i := BossLab.ready_boss(w, id, Vector2(40, 40))
		var t := BossAi.table_of(w, i)
		for atk in t.attacks:
			var stand := Vector2(3.0, 0.0)
			match atk.move:
				BossAttackTable.Move.BROOD:
					stand = Vector2(-3.0, 0.0)
				BossAttackTable.Move.DEPLOY:
					stand = Vector2(0, 2.8)
				BossAttackTable.Move.CHARGE, BossAttackTable.Move.LEAP:
					stand = Vector2(6.0, 0.0)
				BossAttackTable.Move.SLAM_RING:
					stand = Vector2(atk.inner_radius_m + 1.6, 0.0)
			var got := _telegraph_lead(id, atk.id, stand)
			assert_true(got[1], "%s %s lands on a player who stays put" % [id, atk.id])
			assert_gte(
				got[0], SimTick.MIN_TELEGRAPH_TICKS, "%s %s shows its area first" % [id, atk.id]
			)


func test_flood_lanes_are_parallel_and_gap_apart() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"warlord")
	w.actors.set_pos(0, Vector2(8, 0))
	BossLab.start(w, i, &"spear_lines")
	var tg := BossAi.telegraph(w, i)
	assert_eq(tg["shape"], &"lanes")
	var obbs: Array = tg["obbs"]
	assert_eq(obbs.size(), 3)
	var atk := BossAi.attack_of(w, i)
	for o: Obb in obbs:
		assert_eq(o.angle, (obbs[0] as Obb).angle, "parallel")
	var across := ((obbs[1] as Obb).center - (obbs[0] as Obb).center).dot((obbs[0] as Obb).axis_v)
	assert_almost_eq(absf(across), atk.gap_m, 0.01, "gap_m apart")
	assert_almost_eq((obbs[1] as Obb).center.y, 0.0, 0.01, "the middle lane runs at the player")
	assert_false(tg.has("style"), "the windup is a plain mark")
	BossLab.start(w, i, &"spear_wall")
	assert_eq((BossAi.telegraph(w, i)["obbs"] as Array).size(), 5, "phase two's wall is five")


func test_the_molten_floor_stands_and_burns_again_every_period() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"foundry")
	var aid := w.actors.ids[i]
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	var stand := Vector2(6, 0)
	w.actors.set_pos(0, stand)
	BossLab.start(w, i, &"molten_flood")
	var atk := BossAi.attack_of(w, i)
	var hits := 0
	var styled := 0
	for t in atk.windup_ticks + atk.active_ticks + 5:
		w.actors.set_pos(0, stand)
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		var j := w.actors.index_of(aid)
		var tg := BossAi.telegraph(w, j)
		if w.actors.state[j] == S.ACTIVE:
			assert_false(tg.is_empty(), "the lanes stay drawn while they burn")
			if tg.get("style", &"") == &"molten":
				styled += 1
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
				hits += 1
	assert_gt(styled, atk.active_ticks - 3, "drawn molten for the active time")
	assert_gte(hits, 2, "standing in it burns again")
	assert_lte(hits, atk.active_ticks / atk.burn_ticks + 1, "at most once per burn period")


func test_a_warlord_kill_by_spears_shows_spear_marks() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"warlord")
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(5, 0))
	w.actors.hp[0] = 5
	BossLab.start(w, i, &"spear_lines")
	var styles := {}
	for t in 120:
		w.step(InputFrame.new())
		var j := w.actors.index_of(aid)
		styles[BossAi.telegraph(w, j).get("style", &"")] = true
		if w.player_dead():
			break
	assert_true(w.player_dead())
	assert_true(styles.has(&"spears"), "the Warlord's lanes stand as spears")
	assert_eq(WorldReader.new(w).killer_cause_key(), &"CAUSE_WARLORD_SPEARS")


func test_the_warlords_shield_drops_while_its_weak_point_is_open() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"warlord", Vector2(0, 0))
	var aid := w.actors.ids[i]
	var at := w.actors.pos(i)
	var front := at + Vector2(1.5, 0)
	assert_eq(Damage.target_mult(w, i, front)[0], 650, "the shield in front")
	assert_eq(Damage.target_mult(w, i, front)[1], SimEvent.TAG_ARMOURED)
	assert_eq(Damage.target_mult(w, i, at + Vector2(-1.5, 0))[0], 1250, "weak from behind")
	w.actors.set_pos(0, Vector2(3, 0))
	BossLab.start(w, i, &"spear_lines")
	_until_state(w, aid, S.RECOVER)
	i = w.actors.index_of(aid)
	assert_gt(w.bosses.exposed_t[BossAi.entry_of(w, i)], 0, "planting the spears opens it")
	var up := Damage.target_mult(w, i, w.actors.pos(i) + Vector2(1.5, 0))
	assert_eq(up[0], 1000, "shield up: full damage from the front")
	assert_eq(up[1], 0)
	w.bosses.exposed_t[BossAi.entry_of(w, i)] = 0
	assert_eq(Damage.target_mult(w, i, w.actors.pos(i) + Vector2(1.5, 0))[0], 650, "and back")
	# The Gatekeeper keeps its armour while exposed (the field is the Warlord's).
	var g := BossLab.ready_boss(w, &"gatekeeper", Vector2(20, 0))
	w.bosses.exposed_t[BossAi.entry_of(w, g)] = 60
	assert_eq(Damage.target_mult(w, g, w.actors.pos(g) + Vector2(1.5, 0))[0], 800)


func test_the_hive_lens_splits_into_three_drones_at_half_hp() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"hive_lens", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(7, 0))
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	w.step(InputFrame.new())
	BossLab.through_gate(w, aid)  # v0.5.5 DS: the 66 % gate first
	i = w.actors.index_of(aid)
	var t := BossAi.table_of(w, i)
	assert_eq(w.bosses.attack[BossAi.entry_of(w, i)], t.attack_index(&"split"), "it opens phase 2")
	assert_eq(BossAi.telegraph(w, i)["shape"], &"discs", "where the drones land is marked")
	_until_state(w, aid, S.RECOVER)
	assert_eq(_count(w, ActorStore.Kind.LENS_DRONE), 3, "three drones")
	CombatLab.idle(w, 400)
	assert_eq(_count(w, ActorStore.Kind.LENS_DRONE), 3, "it splits once")


func test_lens_drones_fly_the_needles_behaviour() -> void:
	var w := BossLab.world()
	var id := w.add_enemy(ActorStore.Kind.LENS_DRONE, Vector2(8, 0))
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	var marked := false
	var fired := 0
	var seq := w.last_event_seq()
	for t in 400:
		w.step(InputFrame.new())
		var i := w.actors.index_of(id)
		var tg := EnemyAi.telegraph(w, i)
		if not tg.is_empty():
			marked = marked or tg["shape"] == &"lanes"
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.SPAWN and e.owner_id == id and e.source_id != id:
			fired += 1
	assert_true(marked, "its shots are marked as lanes first")
	assert_gt(fired, 0, "it fires")
	assert_eq(EnemyAi.behaviour_of(ActorStore.Kind.LENS_DRONE), ActorStore.Kind.NEEDLE)
	assert_eq(EnemyAi.behaviour_of(ActorStore.Kind.CHARGER), ActorStore.Kind.CHARGER)


func test_the_foundry_launches_bomb_drones_capped() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"foundry", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(12, 0))
	for n in 3:
		i = w.actors.index_of(aid)
		BossLab.start(w, i, &"bomb_launch")
		_until_state(w, aid, S.RECOVER)
	assert_eq(
		_count(w, ActorStore.Kind.BOMB_DRONE), 3, "three launches of two, capped at three alive"
	)


func test_the_foundrys_phase_two_opens_with_five_molten_lanes() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"foundry", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(8, 0))
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	w.step(InputFrame.new())
	BossLab.through_gate(w, aid)  # v0.5.5 DS: the 66 % gate first
	i = w.actors.index_of(aid)
	var t := BossAi.table_of(w, i)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, i)], 1)
	assert_eq(w.bosses.attack[BossAi.entry_of(w, i)], t.attack_index(&"molten_flood_5"))
	assert_eq((BossAi.telegraph(w, i)["obbs"] as Array).size(), 5)


func test_each_keeps_the_anti_kite_rules() -> void:
	var w := BossLab.world()
	for id in NEW_BOSSES:
		var t := w.boss_tables[BossLab.table_index(w, id)]
		assert_lt(t.ranged_far_permille, 1000, "%s: ranged armour" % id)
		assert_gte(t.punish_attack, 0, "%s: a punish move" % id)
		assert_gte(t.gap_attack, 0, "%s: a gap-closer" % id)
		assert_gt(t.close_step_m, 0.0, "%s: a closing band" % id)
		assert_gt(t.weak_mult_permille, 1000, "%s: a weak point up close" % id)
		assert_gt(t.commit_ticks, 0, "%s: tracks until it commits" % id)
		assert_gt(t.dash_read_ticks, 0, "%s: reads dashes" % id)
		var openers := 0
		for atk in t.attacks:
			if atk.opens_weak:
				openers += 1
		assert_gt(openers, 1, "%s: attacks open the weak point" % id)


func test_staying_far_brings_the_punish_move() -> void:
	for id in NEW_BOSSES:
		var w := BossLab.world()
		var i := BossLab.ready_boss(w, id, Vector2(0, 0))
		var aid := w.actors.ids[i]
		var t := BossAi.table_of(w, i)
		w.actors.set_pos(0, Vector2(t.radius_m + t.punish_distance_m + 3.0, 0))
		w.bosses.far_t[BossAi.entry_of(w, i)] = t.punish_ticks
		w.bosses.gap_t[BossAi.entry_of(w, i)] = 0
		w.step(InputFrame.new())
		i = w.actors.index_of(aid)
		assert_eq(w.bosses.attack[BossAi.entry_of(w, i)], t.punish_attack, "%s punishes" % id)


func test_flood_windups_track_then_commit() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"foundry", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(8, 0))
	BossLab.start(w, i, &"molten_flood")
	var first: int = (BossAi.telegraph(w, i)["obbs"][0] as Obb).angle
	w.actors.set_pos(0, Vector2(0, 8))
	w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	assert_ne((BossAi.telegraph(w, i)["obbs"][0] as Obb).angle, first, "it follows the player")
	var atk := BossAi.attack_of(w, i)
	var t := BossAi.table_of(w, i)
	CombatLab.idle(w, atk.windup_ticks - t.commit_ticks)
	i = w.actors.index_of(aid)
	var locked: int = (BossAi.telegraph(w, i)["obbs"][0] as Obb).angle
	w.actors.set_pos(0, Vector2(-8, 0))
	w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	assert_eq((BossAi.telegraph(w, i)["obbs"][0] as Obb).angle, locked, "committed: the lanes hold")


func test_recap_causes_name_the_new_attacks() -> void:
	var w := BossLab.world()
	for id in NEW_BOSSES:
		var t := w.boss_tables[BossLab.table_index(w, id)]
		for atk in t.attacks:
			assert_true(
				String(atk.cause_key).begins_with("CAUSE_"), "%s %s has a cause" % [id, atk.id]
			)
	assert_eq(
		ReadableCause.cause_key(w, ActorStore.Kind.LENS_DRONE, -1, 0),
		"CAUSE_LENS_DRONE",
		"a drone's hit is the drone's"
	)


func test_new_boss_fights_are_deterministic() -> void:
	for id in NEW_BOSSES:
		var hashes := []
		for run in 2:
			var w := BossLab.world(77)
			w.spawn_boss(BossLab.table_index(w, id), Vector2(8, 3))
			for t in 900:
				w.step(InputFrame.make(Vector2i(0, 60 if (t / 90) % 2 == 0 else -60), 0, 500, 0, 0))
			hashes.append(w.state_hash())
		assert_eq(hashes[0], hashes[1], "%s replays the same" % id)


## No damage without a readable cause (v0.1.0 Step 9, v0.3.0 O) against each new boss in its own room: the fighting
## bot (FightBot) on the boss's real floor (FightLab, the run seed picked so the floor's pool draws it), with its HP
## topped up, until the boss dies or 3600 ticks; every hit had its telegraph shown for the minimum and a recap line.
func test_every_hit_from_the_new_bosses_has_a_readable_cause() -> void:
	var repo := ContentRepository.load_all()
	var tables := ContentCompiler.compile_bosses(repo)
	var run_table := ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors"))
	for f: int in [1, 2, 3]:
		var id: StringName = POOLS[f][1]
		var pool := ContentCompiler.compile_boss_pool(repo, f)
		var run_seed := 9100
		while tables[RunState.start(run_seed, run_table).pick_boss(pool, f)].id != id:
			run_seed += 1
		var w := FightLab.floor_world(run_seed, f)
		var bot := FightBot.new(run_seed)
		var check := ReadableCause.new(w)
		FightLab.enter_boss_room(w)
		var seen := false
		for t in 3600:
			w.step(bot.frame(w))
			check.observe(w)
			if not w.player_dead():
				w.actors.hp[0] = w.actors.max_hp[0]
			seen = seen or (w.boss_id >= 0 and w.actors.kinds[w.actors.index_of(w.boss_id)] != 0)
			if seen and not w.boss_alive():
				break
		assert_true(seen, "floor %d (seed %d): %s fought" % [f, run_seed, id])
		print(
			(
				"BO_CAUSE| %s seed=%d ticks=%d hits=%d violations=%d by_cause=%s"
				% [
					id,
					run_seed,
					w.tick,
					check.damage_count,
					check.violations.size(),
					check.by_cause
				]
			)
		)
		assert_gt(check.damage_count, 2, "%s hit the bot often enough to check" % id)
		for v: Dictionary in check.violations:
			fail_test("%s: unreadable hit: %s" % [id, JSON.stringify(v)])
		var own := 0
		for k: String in check.by_cause:
			if (
				k.begins_with("CAUSE_" + String(id).to_upper().split("_")[0])
				or k == "CAUSE_LENS_DRONE"
			):
				own += int(check.by_cause[k])
		assert_gt(own, 0, "%s's own attacks were among them: %s" % [id, check.by_cause])
