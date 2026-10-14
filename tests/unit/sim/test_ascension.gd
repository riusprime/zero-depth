extends GutTest
## v0.7.5 AP (owner N4): the Ascension portal and the endless loop, in the sim. On a run's last floor of a loop the
## gate is the Ascension portal; walking in opens the choice and the world waits; End the run leads to the final boss
## (v0.8.0 FB1; it wins the run when beaten), Ascend ends the
## floor and the run goes on at floor 1 of the next loop with the build carried, new biomes and seeds, harder (data);
## Not yet closes it until the hero steps out. The run's floor counts across loops (shop and curse cadence, wand slots).

const LONG := 1 << 24


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(_repo().get_def(&"run", &"three_floors"))


## A real floor of `run` (the app's FloorScenario) with an invulnerable player, as test_run_flow builds one.
func _floor_world(run: RunState) -> World:
	var repo := _repo()
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var w := FloorScenario.build(
		run.floor_seed(),
		PlayerTable.starting_values(),
		enemies,
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		run.floor_index,
		null,
		run,
		ContentCompiler.compile_combos(repo)
	)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	w.set_boss_tables(bosses)
	w.actors.invuln[0] = LONG
	return w


## A run moved to its last floor (finish_floor twice through normal portals).
func _last_floor_run(seed_value: int) -> RunState:
	var r := RunState.start(seed_value, _run_table())
	for k in r.table.floors - 1:
		var w := _floor_world(r)
		w.boss_flow.route_taken = Routes.Route.NORMAL
		r.finish_floor(w)
	return r


## Seals the boss room, kills the boss and stands the hero in front of the open portal.
func _open_portal(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "the boss room sealed")
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the portal opened")
	w.actors.set_pos(0, f.portal_front_point())


## The frame that walks toward the gate's face.
func _into_gate(w: World) -> InputFrame:
	var frame := InputFrame.new()
	var to_gate := -w.floor_layout.portal_facing()
	frame.move = Vector2i(
		roundi(to_gate.x * SimTick.MOVE_MAX), roundi(to_gate.y * SimTick.MOVE_MAX)
	)
	return frame


func _walk_in(w: World) -> int:
	var frame := _into_gate(w)
	return CombatLab.until(
		w,
		func(x: World) -> bool:
			x.step(frame)
			return Ascension.waiting(x) or x.boss_flow.state == BossFlow.State.ENTERING,
		240
	)


func _pick(w: World, value: int) -> void:
	var frame := InputFrame.new()
	frame.pick = value
	w.step(frame)


func test_only_the_last_floor_of_a_loop_has_the_ascension_portal() -> void:
	var r := RunState.start(11, _run_table())
	var w := _floor_world(r)
	assert_false(w.boss_flow.ascension, "floor 1 has the gate")
	assert_false(WorldReader.new(w).ascension_floor())
	r = _last_floor_run(11)
	assert_eq(r.floor_index, 3)
	var w3 := _floor_world(r)
	assert_true(w3.boss_flow.ascension, "the run's last floor has the Ascension portal")
	assert_true(WorldReader.new(w3).ascension_floor())
	assert_false(w3.floor_layout.has_deep_portal, "and no Deep gate beside it")


func test_walking_in_opens_the_choice_and_the_world_waits() -> void:
	var r := _last_floor_run(12)
	var w := _floor_world(r)
	var reader := WorldReader.new(w)
	_open_portal(w)
	assert_gte(_walk_in(w), 0, "walking into the opening reaches the portal")
	assert_true(reader.ascension_open(), "the choice opened")
	assert_eq(reader.outcome(), 0, "nothing is decided yet")
	var at := w.player_pos()
	var tick := w.tick
	var frame := _into_gate(w)
	for k in 30:
		w.step(frame)
	assert_eq(w.player_pos(), at, "the world waits for the choice")
	assert_eq(w.tick, tick + 30, "the ticks still count")
	assert_true(reader.ascension_open())
	_pick(w, 3)  # not one of the choices
	assert_true(reader.ascension_open(), "any other pick is ignored")


## v0.8.0 FB1 (owner, F1 "changed"): End the run no longer wins at once: it takes the hero on to the final arena (the
## run's last world, test_final_boss.gd), on the same floor and loop.
func test_end_the_run_leads_to_the_final_boss() -> void:
	var r := _last_floor_run(13)
	var w := _floor_world(r)
	var reader := WorldReader.new(w)
	_open_portal(w)
	_walk_in(w)
	_pick(w, WorldReader.PICK_ASCEND_END)
	assert_false(reader.ascension_open(), "the choice closed")
	assert_eq(w.boss_flow.state, BossFlow.State.ENTERING, "the hero goes in")
	assert_eq(reader.ascension_choice(), WorldReader.ASCEND_END)
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)
	assert_true(w.boss_flow.exited())
	assert_eq(reader.outcome(), 3, "End the run: on to the final arena (FB1)")
	assert_eq(r.loops_cleared(w), 1, "the loop's floors are done")
	r.finish_floor(w)
	assert_true(r.final_fight, "the next world is the final boss's")
	assert_eq(r.loop, 1, "no new loop")
	assert_eq(r.floor_index, 3)


func test_ascend_starts_the_next_loop_with_the_build() -> void:
	var r := _last_floor_run(14)
	var w := _floor_world(r)
	var reader := WorldReader.new(w)
	w.add_item(0)
	_open_portal(w)
	_walk_in(w)
	_pick(w, WorldReader.PICK_ASCEND_ASCEND)
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)
	assert_eq(reader.outcome(), 3, "Ascend: on to the next floor")
	var held := w.shards
	var biome_3 := r.biome_of()
	var seeds := [r.floor_seed(1), r.floor_seed(2), r.floor_seed(3)]
	r.finish_floor(w)
	assert_eq(r.loop, 2, "loop 2")
	assert_eq(r.floor_index, 1, "at its floor 1")
	assert_eq(r.loop_floors, 3)
	assert_eq(r.run_floor(), 4, "the run's fourth floor")
	assert_eq(r.loops_cleared(), 1)
	assert_eq(r.biome_order.size(), 6, "the next loop's biomes were drawn")
	assert_ne(r.biome_of(), biome_3, "the new loop never opens on the biome it left")
	assert_false(seeds.has(r.floor_seed()), "a new floor seed")
	assert_eq(r.routes.size(), 4, "a route per run floor")
	var w2 := _floor_world(r)
	assert_eq(w2.floor_index, 1, "the floor tables read floor 1")
	assert_eq(w2.loop, 2)
	assert_eq(w2.run_floor_index(), 4)
	assert_eq(w2.items_owned, PackedInt32Array([0]), "the build came along")
	assert_eq(w2.shards, held / 2, "half the shards, as through any portal")
	assert_false(w2.boss_flow.ascension, "loop 2's floor 1 has the gate")
	assert_eq(w2.loop_threat, r.table.loop_threat, "the loop adds its threat")
	assert_eq(Curses.threat(w2), r.table.loop_threat, "threat T shows it")
	assert_eq(w2.loop_cap_permille, r.table.loop_catch_up_cap_permille)


func test_not_yet_closes_until_the_hero_steps_out() -> void:
	var r := _last_floor_run(15)
	var w := _floor_world(r)
	var reader := WorldReader.new(w)
	_open_portal(w)
	_walk_in(w)
	_pick(w, InputFrame.PICK_CANCEL)
	assert_false(reader.ascension_open(), "Not yet closed it")
	var frame := _into_gate(w)
	for k in 20:
		w.step(frame)
	assert_false(reader.ascension_open(), "standing in the opening keeps it closed")
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "and nothing was taken")
	w.actors.set_pos(0, w.floor_layout.portal_front_point() + w.floor_layout.portal_facing() * 2.0)
	CombatLab.idle(w, 2)
	assert_gte(_walk_in(w), 0)
	assert_true(reader.ascension_open(), "walking in again opens it again")


func test_loop_scaling_compounds_and_caps() -> void:
	var r := RunState.start(1, _run_table())
	assert_eq(r.loop_permille(4000), 1000, "loop 1: no factor")
	assert_eq(r.loop_permille(4000, 2), 4000)
	assert_eq(r.loop_permille(4000, 3), 16000, "compounding")
	assert_eq(r.loop_permille(4000, 40), r.table.loop_scale_cap_permille, "capped")
	var base := CombatLab.tables()
	r.loop = 2
	r.loop_floors = 3
	var t := CombatLab.tables()
	r.scale_enemies(t, 1)
	for k in t.size():
		assert_eq(
			t[k].hp,
			maxi(1, (base[k].hp * r.table.loop_enemy_hp_permille + 500) / 1000),
			"loop 2 floor 1: floor 1's HP x the loop factor"
		)


func test_loop_bosses_are_not_eased_and_scale_up() -> void:
	var repo := _repo()
	var base := ContentCompiler.compile_bosses(repo)
	var r := RunState.start(1, _run_table())
	var t1 := ContentCompiler.compile_bosses(repo)
	r.scale_bosses(t1, 1)
	assert_eq(t1[0].hp, base[0].hp * 800 / 1000, "the run's first floor is eased (D9)")
	r.loop = 2
	r.loop_floors = 3
	var t2 := ContentCompiler.compile_bosses(repo)
	r.scale_bosses(t2, 1)
	assert_eq(
		t2[0].hp,
		base[0].hp * r.table.loop_boss_hp_permille / 1000,
		"loop 2's floor 1: no ease, x the loop's boss factor"
	)


## v0.8.0 LS (owner Q6): enemies and bosses alike, HP x6 and damage x1.2 per loop, compounding; the x100 cap holds
## HP from loop 4 (6^3 = 216), damage stays small.
func test_q6_loop_factors_from_the_data() -> void:
	var r := RunState.start(1, _run_table())
	assert_eq(r.table.loop_enemy_hp_permille, 6000)
	assert_eq(r.table.loop_boss_hp_permille, 6000)
	assert_eq(r.table.loop_enemy_damage_permille, 1200)
	assert_eq(r.table.loop_boss_damage_permille, 1200)
	var hp := []
	var dmg := []
	for l in range(1, 6):
		hp.append(r.loop_permille(r.table.loop_enemy_hp_permille, l))
		dmg.append(r.loop_permille(r.table.loop_enemy_damage_permille, l))
	assert_eq(hp, [1000, 6000, 36000, 100000, 100000], "HP x6 per loop, capped at x100")
	assert_eq(dmg, [1000, 1200, 1440, 1728, 2073], "damage x1.2 per loop")


## v0.8.0 LS (owner Q6): on loop 2 and loop 3's floor 1, an enemy and a boss have HP x6 / x36 and damage x1.2 /
## x1.44 of loop 1's unscaled floor-1 tables (no floor-1 ease past the first loop).
func test_q6_loops_2_and_3_scale_an_enemy_and_a_boss() -> void:
	var repo := _repo()
	var base_e := CombatLab.tables()
	var base_b := ContentCompiler.compile_bosses(repo)
	var r := RunState.start(1, _run_table())
	for c: Array in [[2, 6000, 1200], [3, 36000, 1440]]:
		r.loop = c[0]
		r.loop_floors = 3 * (c[0] - 1)
		var e := CombatLab.tables()
		r.scale_enemies(e, 1)
		assert_eq(e[0].hp, maxi(1, SpawnTable.scale(base_e[0].hp, c[1])), "loop %d enemy HP" % c[0])
		assert_eq(e[0].damage, SpawnTable.scale(base_e[0].damage, c[2]), "loop %d enemy dmg" % c[0])
		var b := ContentCompiler.compile_bosses(repo)
		r.scale_bosses(b, 1)
		assert_eq(b[0].hp, base_b[0].hp * c[1] / 1000, "loop %d boss HP" % c[0])
		assert_eq(
			b[0].attacks[0].damage,
			base_b[0].attacks[0].damage * c[2] / 1000,
			"loop %d boss attack damage" % c[0]
		)
	assert_gt(base_e[0].damage, 0, "the enemy checked deals damage")
	assert_gt(base_b[0].attacks[0].damage, 0, "the boss attack checked deals damage")


func test_the_shop_and_curse_cadence_count_the_run_floor() -> void:
	var shop := ContentCompiler.compile_shop(_repo().get_def(&"shop", &"terminal"))
	var featured := []
	for f in range(1, 10):
		if shop.on_floor(f):
			featured.append(f)
	assert_eq(featured, [1, 3, 5, 7, 9], "every two run floors, across loop seams")
	var r := _last_floor_run(16)
	var w := _floor_world(r)
	_open_portal(w)
	_walk_in(w)
	_pick(w, WorldReader.PICK_ASCEND_ASCEND)
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)
	r.finish_floor(w)
	var w4 := _floor_world(r)
	FloorScenario.add_shop(w4, shop)
	assert_false(w4.shop.present(), "run floor 4 (loop 2, floor 1) has no shop after floor 3's")
	EventCompiler.setup(w4, _repo())
	assert_false(Curses.curse_floor_open(w4), "nor cursed chests")
	w4.run_floor = 5
	assert_true(Curses.curse_floor_open(w4), "run floor 5 (loop 2, floor 2) has them")


func test_the_wand_keeps_its_slots_in_the_next_loop() -> void:
	var r := RunState.start(17, _run_table())
	r.loop = 2
	r.loop_floors = 3
	var w := _floor_world(r)
	w.wand_table = WandCompiler.from_repo(_repo())
	assert_eq(
		Wand.slots(w), w.wand_table.slots_at(3), "loop 2's floor 1 keeps the last floor's slots"
	)


func test_the_next_loop_is_deterministic() -> void:
	var a := _last_floor_run(18)
	var b := _last_floor_run(18)
	var wa := _floor_world(a)
	var wb := _floor_world(b)
	wa.boss_flow.ascension = true
	wa.boss_flow.ascend_choice = Ascension.Choice.ASCEND
	wb.boss_flow.ascend_choice = Ascension.Choice.ASCEND
	a.finish_floor(wa)
	b.finish_floor(wb)
	assert_eq(a.biome_order, b.biome_order, "the same run draws the same loop biomes")
	assert_eq(a.floor_seed(), b.floor_seed())
	assert_eq(
		_floor_world(a).state_hash(), _floor_world(b).state_hash(), "and builds the same floor"
	)


func test_a_loop_one_floor_hashes_without_the_loop_fields() -> void:
	var r := RunState.start(19, _run_table())
	var w := _floor_world(r)
	var h := w.state_hash()
	w.loop_cap_permille = 999  # left out of the hash on loop 1 (its value there is always 0)
	assert_eq(w.state_hash(), h, "loop 1 hashes as before AP")
	w.loop = 2
	assert_ne(w.state_hash(), h, "past loop 1 the loop is hashed")
