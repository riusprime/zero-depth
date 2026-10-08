extends GutTest
## Optional routes (v0.5.0 PLAN R5, step RT): two gates after the bosses of floors 1 and 2 (one on floor 3); walking
## into one takes that route exactly once and closes the other; the run keeps the route per floor; a Deep floor
## scales enemies and bosses ×1.25 on top of the floor (composed once), has one extra chest and a curse-free epic
## altar (epic stat cards and ability level-ups); the Deep gate always fits its boss room (a property over seeds);
## all of it deterministic.

const LONG := 1 << 24
## Generation properties: seeds per boss arena (each floor generates in ~0.15 s here).
const GATE_SEEDS := 200
const REWARD_SEEDS := 25

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(_repo.get_def(&"run", &"three_floors"))


## A run on floor `f`, every floor before it taken by `route`.
func _run_on(f: int, route: int = Routes.Route.NORMAL, seed_value: int = 7) -> RunState:
	var run := RunState.start(seed_value, _run_table(), &"blade")
	for k in f - 1:
		run.floor_index += 1
		run.routes.append(route)
	return run


## A real floor (the app's FloorScenario) on the run's current floor, with an invulnerable player, the build's
## abilities and the stat cards (as Main sets them up).
func _floor(run: RunState, seed_value: int = -1) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var enemies := ContentCompiler.compile_enemies(_repo)
	run.scale_enemies(enemies)
	var w := FloorScenario.build(
		seed_value if seed_value >= 0 else run.floor_seed(),
		t,
		enemies,
		ContentCompiler.compile_spawning(_repo.get_def(&"spawning", &"floor_1"), _repo),
		ContentCompiler.compile_items(_repo),
		ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor")),
		run.floor_index,
		null,
		run,
		ContentCompiler.compile_combos(_repo)
	)
	var bosses := ContentCompiler.compile_bosses(_repo)
	run.scale_bosses(bosses)
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	w.actors.invuln[0] = LONG
	return w


func _events_of(w: World, kind: SimEvent.Kind) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == kind:
			out.append(e)
	return out


## Seals the boss room, kills the boss: the gates open.
func _open_gates(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 1, 1, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 2)


## Walks from in front of a gate into it until the floor's way in starts (or 240 ticks).
func _walk_into(w: World, pos: Vector2, angle: int) -> bool:
	var n := Kin.dir(angle)
	w.actors.set_pos(0, pos + n * (FloorLayout.GATE_HALF_DEPTH + FloorLayout.GATE_FRONT * 0.5))
	var frame := InputFrame.new()
	frame.move = Vector2i(roundi(-n.x * SimTick.MOVE_MAX), roundi(-n.y * SimTick.MOVE_MAX))
	for k in 240:
		w.step(frame)
		if w.boss_flow.state != BossFlow.State.OPEN:
			return true
	return false


func _count(w: World, kind: int) -> int:
	var n := 0
	for i in w.rewards.size():
		if w.rewards.kind[i] == kind:
			n += 1
	return n


# --- the choice -----------------------------------------------------------------------------------------------


func test_the_run_data_has_the_deep_numbers() -> void:
	var t := _run_table()
	assert_eq(t.deep_scale_permille, 1250, "Deep: ×1.25 (R5)")
	assert_eq(t.deep_extra_chests, 1, "one extra chest")
	var good := RunDefinition.new()
	good.biomes = [&"ruins"]
	var bad := RunDefinition.new()
	bad.biomes = [&"ruins"]
	bad.deep_scale = 0.9
	bad.deep_extra_chests = -1
	assert_eq(
		bad.validate().size(),
		good.validate().size() + 2,
		"a Deep factor under 1 and negative chests are refused"
	)


func test_two_gates_only_after_the_bosses_of_floors_one_and_two() -> void:
	for f: int in [1, 2, 3]:
		var run := _run_on(f)
		assert_eq(Routes.offers_choice(run), f < 3, "floor %d" % f)
		var w := _floor(run)
		var reader := WorldReader.new(w)
		assert_eq(reader.has_deep_portal(), f < 3, "floor %d: the Deep gate stands only before the last" % f)
		assert_eq(w.floor_layout.has_deep_portal, f < 3)
		var before := w.walls.size()
		assert_false(reader.gate_open(Routes.Route.DEEP), "sealed before the boss dies")
		assert_false(reader.gate_open(Routes.Route.NORMAL))
		_open_gates(w)
		assert_true(reader.gate_open(Routes.Route.NORMAL), "floor %d: the gate opens" % f)
		assert_eq(reader.gate_open(Routes.Route.DEEP), f < 3, "floor %d: the Deep gate opens with it" % f)
		var opened := _events_of(w, SimEvent.Kind.PORTAL_OPENED)
		assert_eq(opened.size(), 1)
		assert_eq(opened[0].amount, 1 if f < 3 else 0, "the event says whether the Deep gate opened")
		assert_eq(w.walls.size(), before + 1, "only the door's seal joined the walls")
	var plain := WorldReader.new(World.new(1, PlayerTable.starting_values()))
	assert_false(plain.has_deep_portal(), "worlds without a run have no Deep gate")


func test_the_deep_gate_takes_the_deep_route_once_and_closes_the_gate() -> void:
	var run := _run_on(1)
	var w := _floor(run)
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	_open_gates(w)
	assert_true(_walk_into(w, f.deep_portal_pos, f.deep_portal_angle), "the Deep gate takes the hero")
	assert_eq(w.boss_flow.state, BossFlow.State.ENTERING)
	assert_eq(reader.route_taken(), Routes.Route.DEEP)
	assert_true(reader.gate_open(Routes.Route.DEEP))
	assert_false(reader.gate_open(Routes.Route.NORMAL), "the other gate closes")
	assert_eq(reader.entered_portal_pos(), f.deep_portal_pos, "the way in draws the hero to the Deep gate")
	# Standing in the other gate now changes nothing.
	w.actors.set_pos(0, f.portal_front_point())
	CombatLab.idle(w, 120)
	assert_true(w.boss_flow.exited())
	assert_eq(reader.route_taken(), Routes.Route.DEEP, "the route is taken exactly once")
	var exits := _events_of(w, SimEvent.Kind.FLOOR_EXIT)
	assert_eq(exits.size(), 1, "one FLOOR_EXIT")
	assert_eq(exits[0].amount, Routes.Route.DEEP, "naming the route")
	assert_eq(reader.outcome(), 3)
	run.finish_floor(w)
	assert_eq(run.floor_index, 2)
	assert_eq(run.routes, PackedInt32Array([Routes.Route.NORMAL, Routes.Route.DEEP]))
	assert_true(run.is_deep(), "floor 2 is Deep")
	assert_false(run.is_deep(1))
	var w2 := _floor(run)
	assert_true(Routes.is_deep(w2), "the next floor's world knows it")
	assert_true(WorldReader.new(w2).floor_is_deep())


func test_the_gate_takes_the_normal_route_and_closes_the_deep_gate() -> void:
	var run := _run_on(2, Routes.Route.DEEP)
	var w := _floor(run)
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	_open_gates(w)
	assert_true(_walk_into(w, f.portal_pos, f.portal_angle))
	assert_eq(reader.route_taken(), Routes.Route.NORMAL)
	assert_false(reader.gate_open(Routes.Route.DEEP), "the Deep gate closes")
	CombatLab.idle(w, 120)
	run.finish_floor(w)
	assert_eq(
		run.routes,
		PackedInt32Array([Routes.Route.NORMAL, Routes.Route.DEEP, Routes.Route.NORMAL]),
		"the run keeps every floor's route"
	)
	assert_false(run.is_deep())


# --- Deep scaling ---------------------------------------------------------------------------------------------


func test_deep_scaling_composes_with_the_floor_once() -> void:
	var t := _run_table()
	var base := ContentCompiler.compile_enemies(_repo)
	var bosses0 := ContentCompiler.compile_bosses(_repo)
	for f: int in [2, 3]:
		var normal := _run_on(f)
		var deep := _run_on(f, Routes.Route.DEEP)
		var en := ContentCompiler.compile_enemies(_repo)
		var ed := ContentCompiler.compile_enemies(_repo)
		normal.scale_enemies(en)
		deep.scale_enemies(ed)
		var hp_pm := SpawnTable.per_floor(t.enemy_hp_floor_permille, f)
		var dmg_pm := SpawnTable.per_floor(t.enemy_damage_floor_permille, f)
		var hp_deep := SpawnTable.scale(hp_pm, 1250)
		var dmg_deep := SpawnTable.scale(dmg_pm, 1250)
		for k in base.size():
			assert_eq(en[k].hp, maxi(1, SpawnTable.scale(base[k].hp, hp_pm)), "normal floor %d" % f)
			assert_eq(
				ed[k].hp,
				maxi(1, SpawnTable.scale(base[k].hp, hp_deep)),
				"Deep floor %d: HP × floor × 1.25, one scale" % f
			)
			assert_eq(ed[k].damage, SpawnTable.scale(base[k].damage, dmg_deep), "damage too")
		var bn := ContentCompiler.compile_bosses(_repo)
		var bd := ContentCompiler.compile_bosses(_repo)
		normal.scale_bosses(bn)
		deep.scale_bosses(bd)
		var boss_hp := 1000 + t.boss_hp_per_floor_permille * (f - 1)
		var boss_dmg := 1000 + t.boss_damage_per_floor_permille * (f - 1)
		for k in bosses0.size():
			assert_eq(bn[k].hp, maxi(1, bosses0[k].hp * boss_hp / 1000), "normal boss unchanged")
			assert_eq(bd[k].hp, maxi(1, bosses0[k].hp * (boss_hp * 1250 / 1000) / 1000), "Deep boss")
			for a in bd[k].attacks.size():
				var d0 := bosses0[k].attacks[a].damage
				assert_eq(bd[k].attacks[a].damage, d0 * (boss_dmg * 1250 / 1000) / 1000)
		# About ×1.25 of the normal floor, never ×1.25².
		var ratio := float(ed[0].hp) / float(en[0].hp)
		assert_almost_eq(ratio, 1.25, 0.05, "×1.25 over the normal floor %d" % f)
	assert_eq(_run_on(1).route_permille(), 1000, "floor 1 is never Deep")


func test_the_danger_tier_still_scales_deep_enemies_on_top() -> void:
	var run := _run_on(2, Routes.Route.DEEP)
	var w := _floor(run)
	var base := ContentCompiler.compile_enemies(_repo)
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(run.table.enemy_hp_floor_permille, 2), 1250)
	var used := CombatLab.until(w, func(x: World) -> bool: return x.actors.size() > 1, 3600)
	assert_gte(used, 0, "an enemy arrives")
	if used < 0:
		return
	var i := w.actors.size() - 1
	var kind := w.actors.kinds[i]
	var tier := w.spawner.tier_at(w.run_ticks)
	var base_hp := 0
	for t in base:
		if t.kind == kind:
			base_hp = t.hp
	var table_hp := maxi(1, SpawnTable.scale(base_hp, hp_pm))
	assert_eq(w.enemy_table(kind).hp, table_hp, "the table: floor × Deep")
	assert_eq(w.actors.max_hp[i], w.spawner.scaled_hp(table_hp, tier), "the tier on top, once")
	assert_eq(w.actors.power[i], w.spawner.damage_permille(tier), "the tier's damage power, untouched")


# --- Deep floors' rewards -------------------------------------------------------------------------------------


func test_deep_floors_have_an_extra_chest_and_an_epic_altar_property() -> void:
	for s in REWARD_SEEDS:
		var seed_value := 500 + s * 37
		var n := _floor(_run_on(2, Routes.Route.NORMAL), seed_value)
		var d := _floor(_run_on(2, Routes.Route.DEEP), seed_value)
		assert_eq(d.boss_flow.epic_altar_id >= 0, true, "seed %d: an epic altar" % seed_value)
		assert_eq(n.boss_flow.epic_altar_id, -1, "seed %d: none on a normal floor" % seed_value)
		assert_eq(d.rewards.size(), n.rewards.size() + 2, "seed %d: two more rewards" % seed_value)
		assert_eq(
			_count(d, RewardStore.Kind.CHEST),
			_count(n, RewardStore.Kind.CHEST) + 1,
			"seed %d: one extra chest" % seed_value
		)
		var epic := 0
		for i in d.rewards.size():
			if i < n.rewards.size():
				assert_eq(d.rewards.pos(i), n.rewards.pos(i), "the floor's own rewards stay put")
			if Routes.is_epic_altar(d, i):
				epic += 1
				assert_eq(d.rewards.kind[i], RewardStore.Kind.ALTAR)
				assert_eq(d.rewards.price[i], 0, "free")
			var room := d.floor_layout.room_of(d.rewards.pos(i))
			assert_ne(room, d.floor_layout.boss_room, "never in the boss room")
			assert_ne(room, d.floor_layout.start_room, "never in the start hall")
			for j in range(i + 1, d.rewards.size()):
				assert_gt(
					d.rewards.pos(i).distance_to(d.rewards.pos(j)), 1.0, "seed %d: apart" % seed_value
				)
		assert_eq(epic, 1, "seed %d: exactly one epic altar" % seed_value)


func test_the_epic_altar_offers_only_epic_stats_or_level_ups() -> void:
	for s in 30:
		var w := _floor(_run_on(2, Routes.Route.DEEP), 900 + s)
		var i := w.rewards.index_of(w.boss_flow.epic_altar_id)
		assert_gte(i, 0)
		var offer := Offers.roll(w, i)
		assert_eq(offer.size(), 3, "seed %d: three cards" % s)
		var seen := {}
		for c in offer:
			match Offers.type_of(c):
				Offers.STAT:
					assert_eq(Offers.rarity_of(c), Offers.EPIC, "an epic stat card")
				Offers.ABILITY:
					assert_true(Abilities.owned(w, Offers.ability_of(c)), "a level-up, not a new one")
				_:
					fail_test("seed %d: no mods (and no curses) on the epic altar" % s)
			assert_false(seen.has(c), "no repeats")
			seen[c] = true


func test_the_epic_altar_is_reached_and_picked_through_interact() -> void:
	var w := _floor(_run_on(2, Routes.Route.DEEP), 4242)
	var i := w.rewards.index_of(w.boss_flow.epic_altar_id)
	w.actors.set_pos(0, w.rewards.pos(i) + Vector2(0.6, 0))
	var reader := WorldReader.new(w)
	assert_true(reader.reward_is_epic(reader.reward_in_reach()))
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
	assert_eq(w.choosing, w.boss_flow.epic_altar_id, "the epic altar opens")
	var pick := InputFrame.new()
	pick.pick = 1
	w.step(pick)
	assert_eq(w.choosing, -1)
	assert_eq(w.rewards.index_of(w.boss_flow.epic_altar_id), -1, "taken")


# --- generation property and determinism ---------------------------------------------------------------------


func test_the_deep_gate_fits_every_boss_room_property() -> void:
	var bosses := ContentCompiler.compile_bosses(_repo)
	var p := FloorParams.defaults()
	var side := 0
	for s in GATE_SEEDS:
		var b := s % bosses.size()
		var spec := BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b)
		var f := FloorGenerator.generate(3000 + s)
		BossRoomBuilder.attach(f, spec)
		var placed := Routes.place_deep_gate(f)
		assert_true(placed, "seed %d boss %d: the Deep gate fits" % [3000 + s, b])
		if not placed:
			continue
		var r := f.rooms[f.boss_room]
		var box := Routes.deep_gate_collider(f)
		assert_true(r.grow(0.001).encloses(box.bounds()), "inside the boss room")
		assert_true(r.grow(0.001).encloses(Routes.deep_front(f)), "its front too")
		assert_false(
			Routes.zone(f.deep_portal_pos, f.deep_portal_angle).intersects(
				Routes.zone(f.portal_pos, f.portal_angle)
			),
			"apart from the gate"
		)
		for i in range(f.slab_first, f.walls.size()):
			assert_false(
				f.walls[i].bounds().intersects(Routes.zone(f.deep_portal_pos, f.deep_portal_angle)),
				"seed %d: no cover in front of it" % (3000 + s)
			)
		assert_eq(
			Collide.circle_vs_obb(f.boss_spawn, Routes.SPAWN_CLEAR, box), Vector2.ZERO, "clear of the boss"
		)
		assert_true(Routes.fits(f, p, r, f.deep_portal_pos, f.deep_portal_angle), "reached from the door")
		assert_false(
			BossFlow.in_gate(f.portal_pos, f.portal_angle, Routes.deep_front(f).get_center()),
			"one gate's mouth is not the other's"
		)
		if f.deep_portal_angle != f.portal_angle:
			side += 1
	gut.p("deep gate: %d seeds, %d on a side wall" % [GATE_SEEDS, side])


func test_routes_are_deterministic() -> void:
	var hashes := []
	for k in 2:
		var w := _floor(_run_on(2, Routes.Route.DEEP), 77)
		CombatLab.idle(w, 120)
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1], "the same Deep floor twice hashes the same")
	var n := _floor(_run_on(2, Routes.Route.NORMAL), 77)
	CombatLab.idle(n, 120)
	assert_ne(n.state_hash(), hashes[0], "the route is part of the state")
	var a := _floor(_run_on(1), 12)
	var b := _floor(_run_on(1), 12)
	assert_eq(a.floor_layout.deep_portal_pos, b.floor_layout.deep_portal_pos, "the gate's spot is a pure function")
