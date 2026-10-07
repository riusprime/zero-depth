extends GutTest
## The boss framework and the three bosses (PLAN v0.3.0 C; BLUEPRINT §F): spawning, telegraphs of at least
## MIN_TELEGRAPH_TICKS before any hit, the stagger meter, phases, BOSS_DEFEATED once, armour, broods and turrets.

const S := EnemyAi.State
const BOSSES: Array[StringName] = [&"gatekeeper", &"brood_mother", &"siege_engine"]


func _attack_ids(w: World, i: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for atk in BossAi.table_of(w, i).attacks:
		out.append(atk.id)
	return out


func test_spawn_boss_returns_its_id_and_it_rises_untouchable() -> void:
	var w := BossLab.world()
	var k := BossLab.table_index(w, &"gatekeeper")
	var id := w.spawn_boss(k, Vector2(8, 0))
	var i := w.actors.index_of(id)
	assert_eq(w.actors.kinds[i], ActorStore.Kind.GATEKEEPER)
	assert_eq(w.actors.hp[i], w.boss_tables[k].hp)
	assert_true(w.boss_alive())
	assert_eq(w.actors.state[i], S.SPAWN)
	assert_eq(
		Damage.hit(w, i, 50, 1, 1, 1, 0, Vector2.ZERO, Vector2(8, 0)), 0, "invulnerable rising"
	)
	CombatLab.idle(w, BossAi.INTRO_TICKS + 1)
	assert_ne(w.actors.state[w.actors.index_of(id)], S.SPAWN, "it acts after the intro")


func test_arena_accessors() -> void:
	var w := BossLab.world()
	var g := w.boss_tables[BossLab.table_index(w, &"gatekeeper")]
	assert_eq(g.arena_cells, Vector2i(3, 3))
	assert_eq(g.arena_template, FloorLayout.Template.PILLARS)
	var s := w.boss_tables[BossLab.table_index(w, &"siege_engine")]
	assert_eq(s.arena_cells, Vector2i(3, 1))
	assert_eq(s.arena_template, FloorLayout.Template.LINES)
	var b := w.boss_tables[BossLab.table_index(w, &"brood_mother")]
	assert_eq(b.arena_cells, Vector2i(2, 2))


func test_pools_hold_one_boss_per_floor() -> void:
	var repo := ContentRepository.load_all()
	var tables := ContentCompiler.compile_bosses(repo)
	var want := {1: &"gatekeeper", 2: &"brood_mother", 3: &"siege_engine"}
	for f in want:
		var pool := ContentCompiler.compile_boss_pool(repo, f)
		assert_eq(pool.size(), 1, "floor %d" % f)
		assert_eq(tables[pool[0]].id, want[f])
		assert_eq(BossTable.pick(pool, RngStream.new(5)), pool[0])
	assert_eq(BossTable.pick(PackedInt32Array(), RngStream.new(5)), -1)


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
	for id in BOSSES:
		var i := BossLab.ready_boss(w, id, Vector2(40, 40))
		for attack_id in _attack_ids(w, i):
			var atk := BossAi.table_of(w, i).attacks[BossAi.table_of(w, i).attack_index(attack_id)]
			var stand := Vector2(3.0, 0.0)  # inside a ring, a lane, a sweep, a fan, a leap or a barrage
			if atk.move == BossAttackTable.Move.BROOD or atk.move == BossAttackTable.Move.DEPLOY:
				stand = (
					Vector2(-2.8, 0.0) if atk.move == BossAttackTable.Move.BROOD else Vector2(0, 3)
				)
			if atk.move == BossAttackTable.Move.CHARGE:
				stand = Vector2(6.0, 0.0)
			var got := _telegraph_lead(id, attack_id, stand)
			assert_true(got[1], "%s %s lands on a player who stays put" % [id, attack_id])
			assert_gte(
				got[0],
				SimTick.MIN_TELEGRAPH_TICKS,
				"%s %s shows its area long enough first" % [id, attack_id]
			)


func test_stagger_fills_staggers_and_resets() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(6, 0))
	var aid := w.actors.ids[i]
	var t := BossAi.table_of(w, i)
	var b := BossAi.entry_of(w, i)
	var side := Vector2(6, 5)  # neither front nor back: full damage
	Damage.hit(w, i, 100, 1, 1, 1, 0, side, w.actors.pos(i))
	assert_eq(w.bosses.meter[b], 100 * 1000)
	w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	assert_eq(w.bosses.meter[b], 100 * 1000 - t.stagger_decay_milli, "the meter decays")
	Damage.tick_dot(w, i, 50, 1, 1, &"burn")
	assert_eq(
		w.bosses.meter[b], 100 * 1000 - t.stagger_decay_milli, "damage over time doesn't fill it"
	)
	var events_before := w.last_event_seq()
	Damage.hit(w, i, t.stagger_size_milli / 1000, 1, 1, 1, 0, side, w.actors.pos(i))
	assert_eq(w.actors.state[i], BossAi.STAGGERED, "a full meter staggers")
	assert_eq(w.bosses.meter[b], 0, "and resets")
	var stagger_events := w.events_since(events_before).filter(
		func(e: SimEvent) -> bool: return e.effect_id == &"boss_stagger"
	)
	assert_eq(stagger_events.size(), 1)
	Damage.hit(w, i, 10, 1, 1, 1, 0, side, w.actors.pos(i))
	assert_eq(w.bosses.meter[b], 0, "no filling while staggered")
	CombatLab.idle(w, t.stagger_ticks - 1)
	assert_eq(w.actors.state[w.actors.index_of(aid)], BossAi.STAGGERED, "staggered for its length")
	CombatLab.idle(w, 2)
	assert_eq(w.actors.state[w.actors.index_of(aid)], S.MOVE, "then it gets up")
	assert_eq(t.stagger_ticks, 150, "2.5 s")


func test_stagger_interrupts_an_attack() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(3, 0))
	BossLab.start(w, i, &"fist_slam")
	CombatLab.idle(w, 5)
	i = w.actors.index_of(aid)
	var size := BossAi.table_of(w, i).stagger_size_milli / 1000
	Damage.hit(w, i, size, 1, 1, 1, 0, Vector2(0, 5), w.actors.pos(i))
	assert_eq(w.actors.state[i], BossAi.STAGGERED)
	assert_true(BossAi.telegraph(w, i).is_empty(), "the slam is gone")
	CombatLab.idle(w, 120)
	assert_eq(CombatLab.player_damage(w), [], "and never lands")


func test_phase_two_starts_at_half_hp_with_its_entry_attack() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(9, 0))
	var b := BossAi.entry_of(w, i)
	var half := w.actors.max_hp[i] / 2
	w.actors.hp[i] = half + 1
	w.step(InputFrame.new())
	assert_eq(w.bosses.phase[b], 0, "above the threshold")
	i = w.actors.index_of(aid)
	w.actors.hp[i] = half
	w.actors.cd[i] = 0
	w.actors.state[i] = S.MOVE
	w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	assert_eq(w.bosses.phase[b], 1, "at the threshold")
	var t := BossAi.table_of(w, i)
	assert_eq(w.bosses.attack[b], t.attack_index(&"charge"), "phase two opens with the charge")
	assert_eq(w.actors.state[i], S.WINDUP)


func test_phase_two_lanes_are_five() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper")
	w.actors.set_pos(0, Vector2(8, 0))
	BossLab.start(w, i, &"shock_lanes")
	assert_eq((BossAi.telegraph(w, i)["obbs"] as Array).size(), 3)
	BossLab.start(w, i, &"shock_lanes_5")
	assert_eq((BossAi.telegraph(w, i)["obbs"] as Array).size(), 5)


func test_boss_defeated_fires_exactly_once_after_a_normal_kill() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"brood_mother", Vector2(5, 0))
	var aid := w.actors.ids[i]
	Damage.hit(w, i, 999999, 1, 1, 1, 0, Vector2.ZERO, w.actors.pos(i))
	Damage.hit(w, i, 999999, 1, 1, 1, 0, Vector2.ZERO, w.actors.pos(i))
	CombatLab.idle(w, 5)
	var kills := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.KILL and e.target_id == aid
	)
	var done := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.BOSS_DEFEATED
	)
	assert_eq(kills.size(), 1, "one KILL")
	assert_eq(done.size(), 1, "one BOSS_DEFEATED")
	assert_eq(done[0].target_id, aid)
	assert_eq(done[0].amount, BossLab.table_index(w, &"brood_mother"))
	assert_gt(done[0].seq, kills[0].seq, "after the KILL")
	assert_false(w.boss_alive())
	assert_eq(w.bosses.size(), 0)
	assert_eq(w.kills, 1, "a boss counts as a kill")


func test_the_gatekeeper_has_the_wardens_armour() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var at := w.actors.pos(i)
	assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, at + Vector2(5, 0), at), 80, "-20% from the front")
	assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, at + Vector2(-5, 0), at), 110, "+10% from behind")
	assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, at + Vector2(0, 5), at), 100, "sides")


func test_brood_hatches_and_caps_the_hatchlings() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"brood_mother", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(12, 0))
	for n in 3:
		i = w.actors.index_of(aid)
		BossLab.start(w, i, &"brood")
		CombatLab.until(
			w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
		)
	var count := 0
	for k in w.actors.size():
		if w.actors.kinds[k] == ActorStore.Kind.HATCHLING:
			count += 1
	assert_eq(count, 6, "three broods of three, capped at six alive")


func test_siege_phase_two_plants_and_deploys_two_needles() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"siege_engine", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(12, 0))
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	var needles := 0
	for k in w.actors.size():
		if w.actors.kinds[k] == ActorStore.Kind.NEEDLE:
			needles += 1
	assert_eq(needles, 2, "two turrets")
	i = w.actors.index_of(aid)
	var at := w.actors.pos(i)
	w.actors.set_pos(0, Vector2(30, 0))
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.MOVE
	)
	CombatLab.idle(w, 20)
	assert_eq(w.actors.pos(w.actors.index_of(aid)), at, "planted: it no longer walks")


func test_the_leap_and_burrow_dodge_hits() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"brood_mother", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(8, 0))
	BossLab.start(w, i, &"burrow")
	CombatLab.until(w, func(x: World) -> bool: return BossAi.hidden(x, x.actors.index_of(aid)))
	i = w.actors.index_of(aid)
	assert_true(w.actors.invuln[i] > 0, "underground: untouchable")
	assert_true(BossAi.passes_through(w, i))


func test_a_boss_kill_names_the_attack_in_the_recap() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper")
	w.actors.set_pos(0, Vector2(3, 0))
	w.actors.hp[0] = 5
	BossLab.start(w, i, &"fist_slam")
	CombatLab.idle(w, 80)
	assert_true(w.player_dead())
	assert_eq(w.killer_kind, ActorStore.Kind.GATEKEEPER)
	assert_eq(WorldReader.new(w).killer_cause_key(), &"CAUSE_GATEKEEPER_SLAM")


func test_a_boss_fight_is_deterministic_and_hashed() -> void:
	var hashes := []
	for run in 2:
		var w := BossLab.world(77)
		w.spawn_boss(BossLab.table_index(w, &"siege_engine"), Vector2(8, 3))
		for t in 900:
			w.step(InputFrame.make(Vector2i(0, 60 if (t / 90) % 2 == 0 else -60), 0, 500, 0, 0))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
	var plain := World.new(77, PlayerTable.starting_values())
	var with_tables := World.new(77, PlayerTable.starting_values())
	with_tables.set_boss_tables(BossLab.tables())
	assert_ne(plain.state_hash(), with_tables.state_hash(), "a boss world hashes its boss state")
