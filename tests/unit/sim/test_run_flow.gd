extends GutTest
## The run (v0.3.0 PLAN L3-L4, B): three floors in a random biome order, floor seeds from the run seed, enemy scaling
## per floor, the carry between floors (items, shards when present, a 40 % heal), and the boss flow on a floor:
## walking past the boss door seals it and stops spawns, the boss's death opens the portal, the portal ends the floor.

const LONG := 1 << 24


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(_repo().get_def(&"run", &"three_floors"))


## A real floor (the app's FloorScenario) with an invulnerable player.
func _floor_world(seed_value: int, run: RunState = null) -> World:
	var repo := _repo()
	var enemies := ContentCompiler.compile_enemies(repo)
	if run != null:
		run.scale_enemies(enemies)
	var w := FloorScenario.build(
		seed_value,
		PlayerTable.starting_values(),
		enemies,
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo),
		null,
		run
	)
	w.actors.invuln[0] = LONG
	return w


func _kill_enemies(w: World) -> void:
	for i in range(1, w.actors.size()):
		w.actors.invuln[i] = 0
		Damage.hit(w, i, 999999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))


func _events_of(w: World, kind: SimEvent.Kind) -> int:
	var n := 0
	for e in w.events_since(0):
		if e.kind == kind:
			n += 1
	return n


func _into(w: World) -> Vector2:
	return Kin.dir(w.floor_layout.boss_door_angle)


# --- run state ---------------------------------------------------------------------------------------------


func test_the_run_data_compiles() -> void:
	var t := _run_table()
	assert_eq(t.floors, 3)
	assert_eq(t.biome_count, 3)
	assert_eq(t.hp_per_floor_permille, 400)
	assert_eq(t.damage_per_floor_permille, 200)
	assert_eq(t.heal_permille, 400)
	var def: RunDefinition = _repo().get_def(&"run", &"three_floors")
	for id in def.biomes:
		assert_not_null(_repo().get_def(&"biomes", id), "biome %s exists" % id)


func test_biome_order_is_a_shuffle_per_run() -> void:
	var t := _run_table()
	var orders := {}
	for s in 40:
		var r := RunState.start(100 + s, t)
		var o := r.biome_order
		assert_eq(o.size(), 3)
		var sorted := o.duplicate()
		sorted.sort()
		assert_eq(sorted, PackedInt32Array([0, 1, 2]), "each biome once")
		orders[str(o)] = true
		assert_eq(RunState.start(100 + s, t).biome_order, o, "same run seed, same order")
	assert_gte(orders.size(), 4, "the order varies between runs")


func test_floor_seeds_derive_from_the_run_seed() -> void:
	var r := RunState.start(4242, _run_table())
	assert_eq(r.floor_seed(1), 4242, "floor 1 uses the run seed")
	assert_ne(r.floor_seed(2), r.floor_seed(1))
	assert_ne(r.floor_seed(3), r.floor_seed(2))
	assert_eq(r.floor_seed(2), RunState.start(4242, _run_table()).floor_seed(2), "deterministic")
	assert_ne(r.floor_seed(2), RunState.start(4243, _run_table()).floor_seed(2))


func test_enemies_scale_with_the_floor() -> void:
	var base := CombatLab.tables()
	var r := RunState.start(1, _run_table())
	for f in [1, 2, 3]:
		var t := CombatLab.tables()
		r.scale_enemies(t, f)
		for k in t.size():
			assert_eq(t[k].hp, base[k].hp * (10 + 4 * (f - 1)) / 10, "HP x (1 + 0.4 (f - 1))")
			assert_eq(
				t[k].damage, base[k].damage * (10 + 2 * (f - 1)) / 10, "damage x (1 + 0.2 (f - 1))"
			)


func test_the_carry_keeps_items_and_heals_forty_percent() -> void:
	var r := RunState.start(7, _run_table())
	var w := _floor_world(r.floor_seed(), r)
	w.add_item(0)
	w.add_item(3)
	w.actors.hp[0] = 10
	w.run_ticks = 600
	w.kills = 5
	r.finish_floor(w)
	assert_eq(r.floor_index, 2)
	assert_eq(r.carry[RunCarry.HP], 10 + 40, "heal 40 % of 100")
	assert_eq(r.ticks_done, 600)
	assert_eq(r.kills_done, 5)
	var w2 := _floor_world(r.floor_seed(), r)
	assert_eq(w2.items_owned, PackedInt32Array([0, 3]), "items carried in order")
	assert_true(w2.item_mods.has(w2.item_tables[0].kind), "their modifiers are live")
	assert_eq(w2.actors.hp[0], 50)
	assert_eq(w2.floor_index, 2)
	assert_eq(w2.floor_count, 3)
	assert_eq(w2.run_ticks, 0, "the danger tier restarts on each floor")
	assert_eq(WorldReader.new(w2).tier(), 0)
	for i in w2.pickups.ids.size():
		assert_false(w2.pickups.item[i] in [0, 3], "a floor never offers an item you hold")
	w2.actors.hp[0] = 90
	assert_eq(RunCarry.take(w2, 400)[RunCarry.HP], 100, "the heal stops at max HP")


func test_the_carry_names_its_fields_in_one_place() -> void:
	assert_has(RunCarry.FIELDS, &"items_owned")
	assert_has(RunCarry.FIELDS, &"shards", "E's shards carry when World has them")
	var w := CombatLab.world()
	var c := RunCarry.take(w, 400)
	assert_eq(c.has(&"shards"), &"shards" in w, "a field the world lacks is skipped")


# --- boss flow ---------------------------------------------------------------------------------------------


func test_entering_the_boss_room_seals_it_and_starts_the_boss() -> void:
	var w := _floor_world(31)
	var f := w.floor_layout
	var walls_before := w.walls.size()
	CombatLab.idle(w, 5)
	assert_eq(w.boss_flow.state, BossFlow.State.WAITING)
	# Standing in the doorway does not seal it.
	w.actors.set_pos(0, f.boss_door_center + _into(w) * 0.3)
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 2)
	assert_eq(w.boss_flow.state, BossFlow.State.WAITING, "the doorway itself doesn't seal it")
	assert_false(w.boss_alive())
	w.actors.set_pos(0, f.boss_door_center + _into(w) * 2.5)
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "past the door line, the fight starts")
	assert_eq(w.walls.size(), walls_before + 1, "the door's collider joined the walls")
	assert_eq(_events_of(w, SimEvent.Kind.BOSS_ROOM_SEALED), 1)
	assert_true(w.boss_alive(), "the boss is up")
	var bi := w.actors.index_of(w.boss_id)
	assert_eq(w.actors.pos(bi), f.boss_spawn)
	assert_eq(w.actors.max_hp[bi], w.enemy_table(ActorStore.Kind.WARDEN).hp * BossStub.HP_MULT)
	var reader := WorldReader.new(w)
	assert_true(reader.boss_door_sealed())
	assert_false(reader.portal_active())


func test_the_sealed_door_holds_and_spawns_stop() -> void:
	var w := _floor_world(32)
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_center + _into(w) * 2.5)
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT)
	var boss := w.boss_id
	for i in range(1, w.actors.size()):
		if w.actors.ids[i] != boss:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 999999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
	var ticks := w.run_ticks
	var spawned := 0
	for k in 900:
		var before := w.last_event_seq()
		w.step(InputFrame.new())
		for e in w.events_since(before):
			if e.kind == SimEvent.Kind.SPAWN and w.actors.index_of(e.target_id) >= 0:
				spawned += 1
	assert_eq(spawned, 0, "no normal spawns while the boss room is sealed")
	assert_eq(w.run_ticks, ticks + 900, "the floor's clock keeps running")
	# Walk back into the door from inside: it holds.
	w.actors.set_pos(0, f.boss_door_center + _into(w) * 1.5)
	var frame := InputFrame.new()
	var back := -_into(w)
	frame.move = Vector2i(roundi(back.x * SimTick.MOVE_MAX), roundi(back.y * SimTick.MOVE_MAX))
	for k in 120:
		w.step(frame)
	assert_gt(f.boss_door_depth(w.player_pos()), 0.0, "the sealed door keeps you in")


func test_the_boss_dying_opens_the_portal_and_the_portal_ends_the_floor() -> void:
	var w := _floor_world(33)
	w.floor_count = 3  # floor 1 of a three-floor run
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	w.actors.set_pos(0, f.boss_door_center + _into(w) * 2.5)
	CombatLab.idle(w, 1)
	CombatLab.idle(w, 3)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 1, 1, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)
	assert_false(w.boss_alive())
	assert_eq(_events_of(w, SimEvent.Kind.BOSS_DEFEATED), 1, "BOSS_DEFEATED once")
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the portal opens")
	assert_eq(_events_of(w, SimEvent.Kind.PORTAL_OPENED), 1)
	assert_true(reader.portal_active())
	assert_eq(reader.outcome(), 0, "the floor isn't over until you walk in")
	CombatLab.idle(w, 30)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "standing elsewhere keeps the floor going")
	w.actors.set_pos(0, f.portal_front_point())
	var frame := InputFrame.new()
	var to_gate := -f.portal_facing()
	frame.move = Vector2i(
		roundi(to_gate.x * SimTick.MOVE_MAX), roundi(to_gate.y * SimTick.MOVE_MAX)
	)
	var used := CombatLab.until(
		w,
		func(x: World) -> bool:
			x.step(frame)
			return x.boss_flow.exited(),
		240
	)
	assert_gte(used, 0, "walking into the gate takes the portal")
	assert_eq(_events_of(w, SimEvent.Kind.FLOOR_EXIT), 1)
	assert_eq(reader.outcome(), 3, "floor 1 of 3: on to the next floor")
	var tick := w.tick
	var hash_pos := w.player_pos()
	CombatLab.idle(w, 10)
	assert_eq(w.tick, tick + 10)
	assert_eq(w.player_pos(), hash_pos, "after the portal, the floor stands still")
	w.floor_index = 3
	assert_eq(reader.outcome(), 1, "the last floor's portal wins the run")


func test_the_portal_is_inert_before_the_boss_dies() -> void:
	var w := _floor_world(34)
	w.actors.set_pos(0, w.floor_layout.portal_front_point())
	CombatLab.idle(w, 60)
	assert_false(w.boss_flow.exited(), "a sealed gate takes no one")


func test_same_seed_same_boss_flow() -> void:
	var hashes: Array[String] = []
	for k in 2:
		var w := _floor_world(35)
		w.actors.set_pos(0, w.floor_layout.boss_door_center + _into(w) * 2.5)
		CombatLab.idle(w, 120)
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
