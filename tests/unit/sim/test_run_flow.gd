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
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		run.floor_index if run != null else 1,
		null,
		run,
		ContentCompiler.compile_combos(repo)
	)
	var bosses := ContentCompiler.compile_bosses(repo)
	if run != null:
		run.scale_bosses(bosses)
	w.set_boss_tables(bosses)  # as Main does after the build
	w.actors.invuln[0] = LONG
	return w


func _kill_enemies(w: World) -> void:
	for i in range(1, w.actors.size()):
		w.actors.invuln[i] = 0
		Damage.hit(w, i, 999999, 0, 0, 1, 0, w.actors.pos(i), w.actors.pos(i))


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
	assert_eq(
		t.enemy_hp_floor_permille, PackedInt32Array([1000, 1900, 3610]), "v0.4.0 SC: 1.9^(f - 1)"
	)
	assert_eq(t.enemy_damage_floor_permille, PackedInt32Array([1000, 1400, 1960]), "1.4^(f - 1)")
	assert_eq(t.boss_hp_per_floor_permille, 400, "bosses keep their own scaling")
	assert_eq(t.boss_damage_per_floor_permille, 200)
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


## v0.4.0 SC (F10): HP × 1.9^(f - 1) and damage × 1.4^(f - 1), per-mille tables, rounded half up; floor 4 and on
## keep floor 3's factor (the table's last entry).
func test_enemies_scale_with_the_floor() -> void:
	var base := CombatLab.tables()
	var r := RunState.start(1, _run_table())
	var hp_pm := {1: 1000, 2: 1900, 3: 3610, 4: 3610}
	var dmg_pm := {1: 1000, 2: 1400, 3: 1960, 4: 1960}
	for f in [1, 2, 3, 4]:
		var t := CombatLab.tables()
		r.scale_enemies(t, f)
		for k in t.size():
			assert_eq(
				t[k].hp, (base[k].hp * hp_pm[f] + 500) / 1000, "HP x 1.9^(f - 1), floor %d" % f
			)
			assert_eq(
				t[k].damage,
				(base[k].damage * dmg_pm[f] + 500) / 1000,
				"damage x 1.4^(f - 1), floor %d" % f
			)


func test_the_carry_keeps_items_and_heals_forty_percent() -> void:
	var r := RunState.start(7, _run_table())
	var w := _floor_world(r.floor_seed(), r)
	w.add_item(0)
	w.add_item(3)
	w.actors.hp[0] = 10
	w.run_ticks = 600
	w.kills = 5
	w.shards = 30
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
	assert_eq(w2.shards, 15, "shards carry (E), half of them (v0.5.5 Q-S4: keep half)")
	assert_eq(w2.shards_left_behind, 15, "the portal kept the other half")
	assert_eq(w2.floor_count, 3)
	assert_eq(w2.run_ticks, 0, "the danger tier restarts on each floor")
	assert_eq(WorldReader.new(w2).tier(), 0)
	for i in w2.rewards.size():
		for item in w2.rewards.offer_of(i):
			assert_false(item in [0, 3], "a floor never offers an item you hold")
	w2.actors.hp[0] = 90
	assert_eq(RunCarry.take(w2, 400)[RunCarry.HP], 100, "the heal stops at max HP")


func test_a_combo_owned_on_floor_one_is_active_on_floor_two() -> void:
	var r := RunState.start(9, _run_table())
	var w := _floor_world(r.floor_seed(), r)
	var first := 0
	while w.combo_tables[first].item_a < 0:  # v0.4.0 AB: the first item combo (ability pairs sort among them)
		first += 1
	var combo := w.combo_tables[first]
	w.add_item(combo.item_a)
	w.add_item(combo.item_b)
	w.guard_charges = 2
	assert_eq(w.combos_owned, PackedInt32Array([first]), "both items unlock the combo")
	assert_true(Engines.has_combo(w, combo.effect))
	r.finish_floor(w)
	var w2 := _floor_world(r.floor_seed(), r)
	assert_eq(w2.combos_owned, PackedInt32Array([first]), "the combo came along")
	assert_true(Engines.has_combo(w2, combo.effect), "and it is active on floor 2")
	assert_eq(w2.guard_charges, 2, "guard charges carry too")
	var unlocks := 0
	for e in w2.events_since(0):
		if e.kind == SimEvent.Kind.COMBO_UNLOCKED:
			unlocks += 1
	assert_eq(unlocks, 0, "no second unlock card on the new floor")


func test_each_floor_draws_its_boss_and_scales_it() -> void:
	var repo := _repo()
	var base := ContentCompiler.compile_bosses(repo)
	var r := RunState.start(5, _run_table())
	for f in [1, 2, 3]:
		var pool := ContentCompiler.compile_boss_pool(repo, f)
		assert_false(pool.is_empty(), "floor %d has a boss pool" % f)
		var k := r.pick_boss(pool, f)
		assert_has(pool, k, "the boss comes from floor %d's pool" % f)
		assert_eq(
			k,
			RunState.start(5, _run_table()).pick_boss(pool, f),
			"the same run meets the same boss"
		)
		var t := ContentCompiler.compile_bosses(repo)
		r.scale_bosses(t, f)
		# v0.4.0 TU (owner D9): floor 1's bosses x0.8 in the same step.
		var ease: int = 800 if f == 1 else 1000
		var hp_pm: int = (1000 + 400 * (f - 1)) * ease / 1000
		var dmg_pm: int = (1000 + 200 * (f - 1)) * ease / 1000
		assert_eq(
			t[k].hp, base[k].hp * hp_pm / 1000, "boss HP x (1 + 0.4 (f - 1)), x0.8 on floor 1"
		)
		for a in t[k].attacks.size():
			assert_eq(
				t[k].attacks[a].damage,
				base[k].attacks[a].damage * dmg_pm / 1000,
				"boss damage x (1 + 0.2 (f - 1)), x0.8 on floor 1"
			)


func test_the_boss_room_takes_the_bosses_arena() -> void:
	var bosses := ContentCompiler.compile_bosses(_repo())
	for k in bosses.size():
		var spec := BossArenaSpec.make(bosses[k].arena_cells, bosses[k].arena_template, k)
		var f := FloorGenerator.generate(321 + k)
		BossRoomBuilder.attach(f, spec)
		var cells := f.room_cells[f.boss_room].size
		assert_true(
			cells == spec.cells or cells == Vector2i(spec.cells.y, spec.cells.x),
			"%s: a %s room" % [bosses[k].id, spec.cells]
		)
		assert_eq(f.room_template[f.boss_room], spec.template)


func test_the_carry_names_its_fields_in_one_place() -> void:
	assert_has(RunCarry.FIELDS, &"items_owned")
	assert_has(RunCarry.FIELDS, &"combos_owned")
	assert_has(RunCarry.FIELDS, &"guard_charges")
	assert_has(RunCarry.FIELDS, &"shards", "E's shards carry when World has them")
	var w := CombatLab.world()
	var c := RunCarry.take(w, 400)
	assert_eq(c.has(&"shards"), &"shards" in w, "a field the world lacks is skipped")


## v0.5.5 EC (owner Q-S4, "Keep half"): a portal carries half the unspent shards, rounded down; the run's data says
## so, and the next floor knows how many were left behind.
func test_the_portal_keeps_half_the_shards_rounded_down() -> void:
	var run := ContentCompiler.compile_run(
		ContentRepository.load_all().get_def(&"run", &"three_floors")
	)
	assert_eq(run.shard_carry_permille, 500, "keep half")
	var w := CombatLab.world()
	w.shards = 31
	var c := RunCarry.take(w, 0, run.shard_carry_permille)
	assert_eq([c[&"shards"], c[RunCarry.LEFT]], [15, 16], "15 carried, 16 left behind")
	var next := CombatLab.world()
	RunCarry.apply(next, c)
	assert_eq([next.shards, next.shards_left_behind], [15, 16])
	assert_eq(RunCarry.take(w, 0)[&"shards"], 31, "without a run table every shard carries")
	w.shards = 0
	assert_eq(RunCarry.take(w, 0, 500)[RunCarry.LEFT], 0, "nothing held, nothing lost")


# --- boss flow ---------------------------------------------------------------------------------------------


func test_entering_the_boss_room_seals_it_and_starts_the_boss() -> void:
	var w := _floor_world(31)
	var f := w.floor_layout
	var walls_before := w.walls.size()
	CombatLab.idle(w, 5)
	assert_eq(w.boss_flow.state, BossFlow.State.WAITING)
	# Standing in the doorway does not seal it.
	w.actors.set_pos(0, f.boss_door_center)
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 2)
	assert_eq(w.boss_flow.state, BossFlow.State.WAITING, "the doorway itself doesn't seal it")
	assert_false(w.boss_alive())
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "past the door line, the fight starts")
	assert_eq(w.walls.size(), walls_before + 1, "the door's collider joined the walls")
	assert_eq(_events_of(w, SimEvent.Kind.BOSS_ROOM_SEALED), 1)
	assert_true(w.boss_alive(), "the boss is up")
	var bi := w.actors.index_of(w.boss_id)
	assert_eq(w.actors.pos(bi), f.boss_spawn)
	assert_eq(w.actors.kinds[bi], w.boss_tables[0].kind, "boss 0 (the default arena's)")
	assert_eq(w.actors.max_hp[bi], w.boss_tables[0].hp)
	var reader := WorldReader.new(w)
	assert_true(reader.boss_door_sealed())
	assert_false(reader.portal_active())


func test_the_sealed_door_holds_and_spawns_stop() -> void:
	var w := _floor_world(32)
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT)
	# Walk back into the door from inside while the boss rises (BossAi.INTRO_TICKS, it doesn't act): it holds.
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = LONG
	w.actors.set_pos(0, f.boss_door_inside(0.6))
	var frame := InputFrame.new()
	var back := -_into(w)
	frame.move = Vector2i(roundi(back.x * SimTick.MOVE_MAX), roundi(back.y * SimTick.MOVE_MAX))
	for k in 50:
		w.step(frame)
	assert_true(f.rooms[f.boss_room].has_point(w.player_pos()), "the sealed door keeps you in")
	assert_true(w.boss_flow.door_sealed())
	# The boss's own brood and turrets are the boss's (C); with it and everything else dead, nothing may arrive
	# while you stay in the boss room (v0.5.0 PB: it is a safe spot after the boss).
	w.actors.set_pos(0, f.boss_spawn)
	_kill_enemies(w)
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN)
	assert_false(w.boss_flow.door_sealed(), "v0.5.0 PB: the door opens after the boss")
	var ticks := w.run_ticks
	var spawned := 0
	for k in 900:
		var before := w.last_event_seq()
		w.step(InputFrame.new())
		for e in w.events_since(before):
			if e.kind == SimEvent.Kind.SPAWN and w.actors.index_of(e.target_id) >= 0:
				spawned += 1
	assert_eq(spawned, 0, "no normal spawns in the boss room")
	assert_eq(w.run_ticks, ticks + 900, "the floor's clock keeps running")


func test_the_boss_dying_opens_the_portal_and_the_portal_ends_the_floor() -> void:
	var w := _floor_world(33)
	w.floor_count = 3  # floor 1 of a three-floor run
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 1)
	CombatLab.idle(w, 3)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
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
		w.actors.set_pos(0, w.floor_layout.boss_door_inside(1.5))
		CombatLab.idle(w, 120)
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


# --- blink and the boss room (v0.3.0 B2) -------------------------------------------------------------------


## A floor whose boss door (the shared wall) is at most `max_depth` thick, with the player on Blink.
func _blink_floor(max_depth: float) -> World:
	for s in 60:
		var f := FloorGenerator.generate(700 + s)
		BossRoomBuilder.attach(f)
		if f.door_depths[f.boss_door_index] <= max_depth:
			var w := _floor_world(700 + s)
			w.player.utility = PlayerTable.Utility.BLINK
			return w
	return null


func _blink(w: World, dir: Vector2) -> void:
	w.vel = Vector2.ZERO
	w.step(InputFrame.make(Vector2i.ZERO, Kin.angle_of(dir), 1000, 0, InputFrame.UTILITY))


func test_blink_never_enters_the_boss_room_through_its_wall() -> void:
	var w := _blink_floor(3.2)
	assert_not_null(w, "a floor with a thin boss wall")
	if w == null:
		return
	var f := w.floor_layout
	var host := f.rooms[f.boss_host_room]
	var into := _into(w)
	var along := Vector2(-into.y, into.x)
	var width := f.door_widths[f.boss_door_index]
	var face := f.boss_door_outside(0.0)
	var tried := 0
	for k: float in [-1.0, 1.0]:
		# Beside the door, still against the shared wall: through it, the free floor beyond is within range.
		var at := face + along * k * (width * 0.5 + 1.2) - into * 0.4
		if not host.has_point(at) or not f.boss_cells_rect.has_point(at + into * 4.6):
			continue
		tried += 1
		w.actors.set_pos(0, at)
		w.blink_cd = 0
		_blink(w, into)
		assert_false(
			f.boss_cells_rect.has_point(w.player_pos()), "no blink through the boss room's wall"
		)
	assert_gt(tried, 0, "a spot beside the door against the shared wall")


func test_blink_through_the_open_doorway_is_allowed() -> void:
	var w := _blink_floor(3.2)
	if w == null:
		return
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_outside(0.4))
	_blink(w, _into(w))
	assert_true(f.boss_cells_rect.has_point(w.player_pos()), "straight through the open door")


func test_blink_never_leaves_or_enters_the_sealed_boss_room() -> void:
	var w := _blink_floor(3.2)
	if w == null:
		return
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 1)
	assert_true(w.boss_flow.door_sealed())
	w.actors.set_pos(0, f.boss_door_inside(0.4))
	w.blink_cd = 0
	_blink(w, -_into(w))
	assert_true(f.boss_cells_rect.has_point(w.player_pos()), "no blink out through the sealed door")
	w.actors.set_pos(0, f.boss_door_outside(0.4))
	w.blink_cd = 0
	_blink(w, _into(w))
	assert_false(f.boss_cells_rect.has_point(w.player_pos()), "and none in from outside")
