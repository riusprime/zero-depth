extends GutTest
## v0.5.5 Step DS (owner D7): mechanics HP can't skip. Every boss has phase gates at 66 % and 33 %: a burst stops at
## the gate, the gate is a short invulnerable transition that deals no damage and shows itself, it brings 2-4 adds of
## the floor's enemy kinds, and the next phase opens with its entry attack (new or faster attacks).

const LONG := 1 << 24
const BOSSES: Array[StringName] = [
	&"gatekeeper", &"brood_mother", &"siege_engine", &"warlord", &"hive_lens", &"foundry"
]


func _burst(w: World, i: int) -> int:
	return Damage.hit(
		w, i, 999999, w.actors.ids[0], w.actors.ids[0], 1, 0, w.actors.pos(i), w.actors.pos(i)
	)


func test_every_boss_has_gates_at_66_and_33_and_a_harder_last_phase() -> void:
	var w := BossLab.world()
	for id in BOSSES:
		var t := w.boss_tables[BossLab.table_index(w, id)]
		assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]), "%s: three phases" % id)
		assert_gte(t.phase_entry[2], 0, "%s: the last phase opens with its punish attack" % id)
		for k in [1, 2]:
			var newer := false
			for a in t.phase_attacks[k]:
				newer = newer or not t.phase_attacks[k - 1].has(a)
			assert_true(
				newer or t.phase_cd_permille[k] < t.phase_cd_permille[k - 1],
				"%s: phase %d adds an attack or a faster pattern" % [id, k]
			)
		assert_lt(
			t.phase_cd_permille[2], t.phase_cd_permille[1], "%s: the last phase is faster" % id
		)


func test_a_burst_stops_at_each_gate_and_the_gate_cannot_be_hurt() -> void:
	for id in BOSSES:
		var w := BossLab.world()
		w.actors.hp[0] = LONG
		w.actors.max_hp[0] = LONG
		var i := BossLab.ready_boss(w, id, Vector2(0, 0))
		var aid := w.actors.ids[i]
		w.actors.set_pos(0, Vector2(6, 0))
		var max_hp := w.actors.max_hp[i]
		_burst(w, i)
		assert_eq(w.actors.hp[i], max_hp * 660 / 1000, "%s: the burst stops at 66 %%" % id)
		assert_eq(_burst(w, i), 0, "%s: nothing more until the gate has run" % id)
		w.step(InputFrame.new())
		i = w.actors.index_of(aid)
		assert_eq(w.actors.state[i], BossAi.GATE, "%s: the gate" % id)
		assert_eq(_burst(w, i), 0, "%s: invulnerable in the gate" % id)
		BossLab.through_gate(w, aid)
		i = w.actors.index_of(aid)
		assert_eq(w.bosses.phase[BossAi.entry_of(w, i)], 1)
		w.actors.invuln[i] = 0
		_burst(w, i)
		assert_eq(w.actors.hp[i], max_hp * 330 / 1000, "%s: the next burst stops at 33 %%" % id)
		w.step(InputFrame.new())
		BossLab.through_gate(w, aid)
		i = w.actors.index_of(aid)
		assert_eq(w.bosses.phase[BossAi.entry_of(w, i)], 2, "%s: the last phase" % id)
		w.actors.invuln[i] = 0
		_burst(w, i)
		assert_eq(w.actors.dead[i], 1, "%s: past the last gate a burst can kill" % id)


func test_the_gate_deals_no_damage_and_shows_itself() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(2.5, 0))
	BossLab.start(w, i, &"fist_slam")
	CombatLab.idle(w, 5)
	i = w.actors.index_of(aid)
	_burst(w, i)
	var seq := w.last_event_seq()
	w.step(InputFrame.new())
	i = w.actors.index_of(aid)
	var reader := WorldReader.new(w)
	assert_true(reader.boss_in_gate(i))
	assert_true(BossAi.telegraph(w, i).is_empty(), "the slam in progress stops")
	var gates := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.effect_id == BossGates.EFFECT
	)
	assert_eq(gates.size(), 1, "STATUS_APPLY boss_phase_gate once")
	var p0 := reader.boss_gate_permille(i)
	CombatLab.idle(w, 30)
	i = w.actors.index_of(aid)
	assert_gt(reader.boss_gate_permille(i), p0, "the transition runs")
	CombatLab.idle(w, BossGates.GATE_TICKS - 30)
	assert_eq(CombatLab.player_damage(w), [], "no damage without a readable cause")
	i = w.actors.index_of(aid)
	assert_false(reader.boss_in_gate(i), "about a second")


func test_the_dev_panels_kill_passes_the_gates() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"warlord", Vector2(0, 0))
	Damage.hit(w, i, 999999, 0, 0, 1, 0, w.actors.pos(i), w.actors.pos(i))
	assert_eq(w.actors.dead[i], 1, "the world's own hit (owner 0)")


func _enemies(w: World) -> int:
	var n := 0
	for k in range(1, w.actors.size()):
		var kind := w.actors.kinds[k]
		if EnemyAi.is_enemy_kind(kind) and not BossAi.is_boss_kind(kind) and w.actors.dead[k] == 0:
			n += 1
	return n


func _gate_adds(f: int) -> Array:
	var w := SaveLab.floor_world(41, f)
	w.actors.invuln[0] = LONG
	while w.boss_flow.holds_world():  # floors after the first open with the arrival
		w.step(InputFrame.new())
	w.run_ticks = 1  # the floor's spawning stays (the adds come from its mix), its own packs held back
	w.spawn_cd = LONG
	var aid := w.spawn_boss(BossLab.table_index(w, &"gatekeeper"), w.player_pos() + Vector2(7, 0))
	var i := w.actors.index_of(aid)
	w.actors.invuln[i] = 0
	w.actors.state[i] = EnemyAi.State.MOVE
	var out := []
	for gate in [1, 2]:
		var before := _enemies(w)
		_burst(w, w.actors.index_of(aid))
		w.step(InputFrame.new())
		var added := _enemies(w) - before
		var rising := 0
		for k in range(1, w.actors.size()):
			var kind := w.actors.kinds[k]
			if (
				EnemyAi.is_enemy_kind(kind)
				and not BossAi.is_boss_kind(kind)
				and w.actors.invuln[k] > 0
			):
				rising += 1
				assert_true(w.spawner.kinds.has(kind), "a kind of the floor's mix")
		assert_gte(rising, added, "they rise with the spawn-in (no acting, no damage)")
		out.append(added)
		BossLab.through_gate(w, aid)
		w.actors.invuln[w.actors.index_of(aid)] = 0
	return out


func test_each_gate_brings_two_to_four_adds_of_the_floors_kinds() -> void:
	assert_eq(_gate_adds(1), [2, 2], "floor 1")
	assert_eq(_gate_adds(2), [2, 3], "floor 2")
	assert_eq(_gate_adds(3), [3, 4], "floor 3")
	assert_eq(BossGates.adds_for(9, 2), BossGates.ADDS_MAX)


func test_no_adds_without_spawning() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var before := _enemies(w)
	_burst(w, i)
	w.step(InputFrame.new())
	assert_eq(_enemies(w), before)
