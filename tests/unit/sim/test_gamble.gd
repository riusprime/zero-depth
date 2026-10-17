# gdlint: disable=max-public-methods
extends GutTest
## v0.3.0 L19, the gamble shrine: the shipped data, price steps per use and per floor, paying and refusing, the
## weighted draw (deterministic, proportional, never past a cap), every stat's hook, the carry across floors, the
## placement, and the press going to an altar or chest first. v0.8.0 N14 (owner O72): the shrine on ~40 % of floors,
## never in the start hall, the boss room or an arena; 3 wins a shrine, then spent; 30 % of paid uses fail (paid, no
## stat, the price still rises); saved and hashed; an older save's start-hall shrine stays and counts its uses as wins.

const I := InputFrame.INTERACT
const S := GambleTable.Stat

var _gamble: GambleTable
var _def: GambleDefinition
var _rewards: RewardTable
var _items: Array[ItemTable] = []
var _enemies: Array[EnemyTable] = []


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_def = repo.get_def(&"gamble", &"shrine")
	_gamble = ContentCompiler.compile_gamble(_def)
	_rewards = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))
	_items = ContentCompiler.compile_items(repo)
	_enemies = ContentCompiler.compile_enemies(repo)


## The shipped rules with no failure (v0.8.0 N14), and `wins` wins a shrine: the tests of the price, the draw and the
## caps, which need every paid use to win.
func _steady(wins: int = 3) -> GambleTable:
	var t := ContentCompiler.compile_gamble(_def)
	t.fail_permille = 0
	t.max_wins = wins
	return t


## A world with the shipped shrine rules but no failure (`table`: other rules) and a shrine at the player's feet.
func _world(seed_value: int = 5, table: GambleTable = null) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(_enemies)
	w.reward_table = _rewards
	w.gamble_table = table if table != null else _steady()
	w.gamble_id = w.take_root()
	w.gamble_pos = w.player_pos() + Vector2(0.5, 0)
	return w


func _press(w: World) -> void:
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, I))


## A copy of the shipped table with every cap raised (draw statistics without caps getting in the way).
func _uncapped() -> GambleTable:
	var t := GambleTable.new()
	t.amount = _gamble.amount.duplicate()
	t.weight = _gamble.weight.duplicate()
	t.fail_permille = 0  # v0.8.0 N14: every use wins, and the shrine is never spent
	t.max_wins = 1 << 30
	t.cap = PackedInt32Array()
	for s in GambleTable.STAT_COUNT:
		t.cap.append(1 << 20)
	return t


func test_the_shipped_data() -> void:
	assert_eq(_gamble.base_price, 25)
	assert_eq(_gamble.price_step_permille, 500)
	assert_eq(_gamble.floor_price_step_permille, 500)
	# max HP +8; melee +6 %; shot +6 %; move +4 %; dash cooldown -6 %; regen +0.5 %/s; heat +8 %; shards +5 %.
	assert_eq(_gamble.amount, PackedInt32Array([8, 60, 60, 40, 60, 5, 80, 50]))
	assert_eq(_gamble.weight, PackedInt32Array([3, 3, 3, 2, 2, 2, 2, 2]))
	assert_eq(_gamble.cap, PackedInt32Array([6, 5, 5, 4, 4, 4, 4, 4]))
	var fresh := GambleTable.new()
	assert_eq(fresh.amount, _gamble.amount, "the defaults equal the data")
	assert_eq(fresh.weight, _gamble.weight)
	assert_eq(fresh.cap, _gamble.cap)
	# v0.8.0 N14 (O72): 40 % of floors, 3 wins a shrine, 30 % of uses fail.
	assert_eq(_gamble.floor_chance_permille, 400)
	assert_eq(_gamble.max_wins, 3)
	assert_eq(_gamble.fail_permille, 300)
	assert_eq(fresh.floor_chance_permille, _gamble.floor_chance_permille)
	assert_eq(fresh.max_wins, _gamble.max_wins)
	assert_eq(fresh.fail_permille, _gamble.fail_permille)
	assert_eq(
		Array(GambleTable.STAT_IDS),
		Array(GambleStatEntry.STATS),
		"sim and content name the stats alike"
	)


func test_price_steps_per_use_and_per_floor() -> void:
	var got := []
	for k in 6:
		got.append(_gamble.price(k, 1))
	assert_eq(got, [25, 38, 57, 86, 129, 194], "× 1.5 per use, rounded half up")
	assert_eq(_gamble.price(0, 2), 37, "floor 2: × 1.5 base")
	assert_eq(_gamble.price(0, 3), 50, "floor 3: × 2 base")
	assert_eq(_gamble.price(1, 3), 75)


func test_a_use_pays_and_grants_one_stat() -> void:
	var w := _world()
	w.shards = 100
	_press(w)
	assert_eq(w.shards, 75, "paid 25")
	assert_eq(w.gamble_uses, 1)
	var total := 0
	for s in GambleTable.STAT_COUNT:
		total += Gamble.stacks(w, s)
	assert_eq(total, 1, "one stat")
	assert_eq(Gamble.stacks(w, w.gamble_last_stat), 1, "the last stat is the one won")
	assert_eq(w.gamble_tick, 0)
	assert_eq(Gamble.price(w), 38, "the next use costs more")
	CombatLab.idle(w, SimTick.INPUT_BUFFER_TICKS + 1)
	assert_eq(w.shards, 75, "one press, one use")


func test_cant_afford_pays_nothing() -> void:
	var w := _world()
	w.shards = 24
	_press(w)
	assert_eq(w.shards, 24)
	assert_eq(w.gamble_uses, 0)
	assert_true(w.gamble_stacks.is_empty(), "no stat")
	assert_eq(w.gamble_denied_tick, 0, "the refusal is recorded")
	assert_eq(w.gamble_tick, -1)


func test_out_of_reach_does_nothing() -> void:
	var w := _world()
	w.gamble_pos = w.player_pos() + Vector2(_gamble.interact_radius_m + 0.2, 0)
	w.shards = 100
	_press(w)
	assert_eq(w.shards, 100)
	assert_eq(w.gamble_denied_tick, -1)


func _sequence(seed_value: int, n: int) -> PackedInt32Array:
	var w := _world(seed_value)
	w.shards = 1 << 20
	var out := PackedInt32Array()
	for k in n:
		_press(w)
		CombatLab.idle(w, 1)
		out.append(w.gamble_last_stat)
	return out


func test_results_are_deterministic() -> void:
	assert_eq(_sequence(7, 12), _sequence(7, 12), "same seed, same stats")
	var a := _world(7)
	var b := _world(7)
	for w in [a, b]:
		w.shards = 500
		_press(w)
	assert_eq(a.state_hash(), b.state_hash())
	var differ := false
	for s in [8, 9, 10, 11]:
		differ = differ or _sequence(s, 12) != _sequence(7, 12)
	assert_true(differ, "other seeds draw other stats")


func test_draws_follow_the_weights() -> void:
	var w := _world(3, _uncapped())
	w.shards = 1 << 30
	var counts := PackedInt32Array()
	counts.resize(GambleTable.STAT_COUNT)
	var n := 1900
	for k in n:
		w.gamble_uses = 0  # keeps the price small
		w.input_buffer[3] = 1
		assert_true(Gamble.interact(w))
		counts[w.gamble_last_stat] += 1
	var total_weight := 0
	for v in _gamble.weight:
		total_weight += v
	for s in GambleTable.STAT_COUNT:
		var expect := float(n) * _gamble.weight[s] / total_weight
		assert_almost_eq(float(counts[s]), expect, expect * 0.25, "stat %d near its weight" % s)
	gut.p("draws per stat in %d: %s" % [n, str(counts)])


func test_a_weightless_stat_is_never_drawn() -> void:
	var t := _uncapped()
	t.weight[S.MELEE] = 0
	var w := _world(4, t)
	w.shards = 1 << 30
	for k in 300:
		w.input_buffer[3] = 1
		Gamble.interact(w)
	assert_eq(Gamble.stacks(w, S.MELEE), 0)


func test_caps_hold_and_a_spent_shrine_refuses() -> void:
	var w := _world(6, _steady(1 << 20))
	w.shards = 1 << 30
	var uses := 0
	for k in 60:
		_press(w)
		CombatLab.idle(w, 1)
	for s in GambleTable.STAT_COUNT:
		assert_eq(Gamble.stacks(w, s), _gamble.cap[s], "stat %d stops at its cap" % s)
		uses += _gamble.cap[s]
	assert_eq(w.gamble_uses, uses, "every use until all were capped")
	assert_true(Gamble.exhausted(w))
	var shards := w.shards
	_press(w)
	assert_eq(w.shards, shards, "a spent shrine takes nothing")
	assert_eq(w.gamble_uses, uses)
	assert_eq(w.gamble_denied_tick, w.tick - 1, "and says no")


func test_each_stat_reaches_its_hook() -> void:
	var w := _world()
	var base_speed := ItemProcs.move_speed(w)
	var base_dash := ItemProcs.dash_cooldown_ticks(w)
	var hp := w.actors.hp[0]
	var max_hp := w.actors.max_hp[0]
	w.actors.hp[0] = hp - 20
	for s in GambleTable.STAT_COUNT:
		Gamble.grant(w, s)
	assert_eq(w.actors.max_hp[0], max_hp + 8, "max HP +8")
	assert_eq(w.actors.hp[0], hp - 12, "and healed by as much")
	assert_eq(Gamble.melee_damage(w, 100), 106, "melee +6 %")
	assert_eq(Gamble.shot_damage(w, 50), 53, "shots +6 %")
	assert_almost_eq(ItemProcs.move_speed(w), base_speed * 1.04, 0.000001, "move +4 %")
	assert_eq(ItemProcs.dash_cooldown_ticks(w), base_dash * 940 / 1000, "dash cooldown -6 %")
	assert_eq(Gamble.regen_bonus_permille(w), 5, "regen +0.5 % of max HP per second")
	assert_eq(Gamble.heat_capacity_bonus_permille(w), 80, "heat capacity +8 %")
	assert_eq(Gamble.shard_gain(w, 20), 21, "shards +5 %")
	assert_eq(Gamble.melee_damage(_world(), 100), 100, "nothing won, nothing changes")


func test_shard_gain_raises_what_a_kill_pays() -> void:
	var w := _world()
	for k in 4:
		Gamble.grant(w, S.SHARDS)
	w.add_enemy(ActorStore.Kind.WARDEN, Vector2(6, 0))
	var i := w.actors.size() - 1
	w.actors.hp[i] = 0
	w.actors.dead[i] = 1
	CombatLab.idle(w, 1)
	# v0.5.5 EC (owner S4): a Warden pays 6 × 0.7 = 4 (4.2, rounded), then the shrine's × 1.2 = 4.8 → 5.
	assert_eq(w.shards, 5, "a Warden's 4 × 1.2 = 4.8, rounded")


func test_melee_damage_reaches_a_real_swing() -> void:
	var dealt := []
	for won in [0, 5]:
		var w := _world()
		for k in won:
			Gamble.grant(w, S.MELEE)
		var e := w.add_dummy(Vector2(1.0, 0), 0.35, 100000)
		w.actors.invuln[w.actors.index_of(e)] = 0
		var before := w.actors.hp[w.actors.index_of(e)]
		w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.PRIMARY))
		CombatLab.idle(w, 40)
		dealt.append(before - w.actors.hp[w.actors.index_of(e)])
	assert_gt(dealt[0], 0, "the swing hit")
	assert_eq(dealt[1], Gamble.raise(dealt[0], 300), "5 wins: +30 %")


func test_stats_carry_across_floors_and_the_price_resets() -> void:
	var w := _world()
	w.shards = 1000
	for k in 3:
		_press(w)
		CombatLab.idle(w, 1)
	Gamble.grant(w, S.MAX_HP)
	var stacks := w.gamble_stacks.duplicate()
	assert_true(RunCarry.FIELDS.has(&"gamble_stacks"))
	var carry := RunCarry.take(w, 400)
	var next := World.new(9, PlayerTable.starting_values())
	next.gamble_table = _gamble
	next.floor_index = 2
	RunCarry.apply(next, carry)
	assert_eq(next.gamble_stacks, stacks, "the stats won carry")
	carry[&"gamble_stacks"][0] += 1
	assert_eq(next.gamble_stacks, stacks, "copied, not shared")
	var won_hp := Gamble.bonus(next, S.MAX_HP)
	assert_gt(won_hp, 0)
	assert_eq(next.actors.max_hp[0], next.player.hp + won_hp, "max HP keeps its wins")
	assert_eq(
		next.actors.hp[0], carry[RunCarry.HP], "HP is clamped to the raised max, not the base"
	)
	assert_eq(next.gamble_uses, 0, "uses reset on a new floor")
	assert_eq(Gamble.price(next), 37, "floor 2's first price")


func test_the_stats_are_hashed() -> void:
	var a := _world()
	var b := _world()
	Gamble.grant(b, S.MOVE)
	assert_ne(a.state_hash(), b.state_hash())
	var plain := World.new(5, PlayerTable.starting_values())
	var shrine := World.new(5, PlayerTable.starting_values())
	shrine.gamble_id = 99
	assert_ne(plain.state_hash(), shrine.state_hash(), "a shrine is part of the state")


func test_an_altar_in_reach_takes_the_press_first() -> void:
	var w := _world()
	w.set_item_tables(_items)
	w.add_reward(RewardStore.Kind.ALTAR, w.player_pos() + Vector2(-0.5, 0), 0)
	w.shards = 100
	_press(w)
	assert_ne(w.choosing, -1, "the altar opened")
	assert_eq(w.shards, 100, "the shrine took nothing")
	assert_eq(w.gamble_uses, 0)


## The start-hall spot a floor saved before N14 keeps (Gamble.spot, through Gamble.site's `legacy`).
func test_an_old_floors_shrine_stands_in_the_start_hall_clear_of_walls() -> void:
	for s in 40:
		var layout := FloorGenerator.generate(1000 + s * 7)
		var p := Gamble.spot(layout, _gamble)
		assert_eq(Gamble.site(layout, _gamble, true), PackedVector2Array([p]), "legacy: always")
		assert_eq(layout.room_of(p), layout.start_room, "seed %d: in the start hall" % s)
		assert_almost_eq(
			p.distance_to(layout.start_pos), _gamble.spot_distance_m, 0.001, "at its distance"
		)
		for o in layout.walls:
			assert_eq(Collide.circle_vs_obb(p, _gamble.clear_radius_m, o), Vector2.ZERO, "clear")
		var exit := -1
		for d in layout.door_rooms.size():
			if (
				layout.door_rooms[d].x == layout.start_room
				or layout.door_rooms[d].y == layout.start_room
			):
				exit = d
		assert_gt(
			p.distance_to(layout.door_centers[exit]),
			layout.start_pos.distance_to(layout.door_centers[exit]),
			"seed %d: farther from the exit than the start" % s
		)


func test_without_a_clear_ring_it_falls_back_to_a_clear_spot() -> void:
	var layout := FloorGenerator.generate(1234)
	var t := GambleTable.new()
	t.spot_distance_m = 400.0  # every ring spot is outside the hall
	var p := Gamble.spot(layout, t)
	assert_true(layout.spawn_points[layout.start_room].has(p), "the hall's spawn point")


func _floor(seed_value: int) -> World:
	var repo := ContentRepository.load_all()
	return FloorScenario.build(
		seed_value,
		PlayerTable.starting_values(),
		_enemies,
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		_items,
		_rewards,
		1,
		null,
		null,
		ContentCompiler.compile_combos(repo),
		_gamble
	)


## The first seed from `from` whose floor draws a shrine (Gamble.STREAM).
func _seed_with_shrine(from: int) -> int:
	var s := from
	while not Gamble.stream(s, Gamble.STREAM).chance_permille(_gamble.floor_chance_permille):
		s += 1
	return s


func test_a_real_floor_places_its_shrine_the_same_way_every_time() -> void:
	var seed_value := _seed_with_shrine(77)
	var w := _floor(seed_value)
	assert_ne(w.gamble_id, -1, "a shrine")
	assert_ne(w.floor_layout.room_of(w.gamble_pos), w.floor_layout.start_room, "not the start hall")
	var foot := Gamble.collider(w.gamble_pos)
	var solid := false
	for o in w.walls:
		solid = solid or (o.center == foot.center and o.half == foot.half)
	assert_true(solid, "its footprint is a wall")
	for q in w.spawn_points:
		assert_gte(
			q.distance_to(w.gamble_pos),
			_gamble.clear_radius_m + Gamble.FOOTPRINT_HALF_M,
			"no spawn point under it"
		)
	var again := _floor(seed_value)
	assert_eq(again.gamble_pos, w.gamble_pos, "the same place on the same seed")
	assert_eq(again.state_hash(), w.state_hash())


# --- v0.8.0 N14 (owner O72) ------------------------------------------------------------------------------------
## A floor layout as FloorScenario marks it before the shrine: the boss room, the Overrun room, the arenas.
func _layout(seed_value: int, map: FloorParams, share: int) -> FloorLayout:
	var layout := FloorGenerator.generate(seed_value, map)
	BossRoomBuilder.attach(layout, BossArenaSpec.new())
	OverrunRooms.mark(layout)
	ArenaRooms.mark(layout, share)
	return layout


func test_a_floor_has_a_shrine_four_times_in_ten() -> void:
	var n := 4000
	var hit := 0
	for k in n:
		if Gamble.stream(9000 + k * 13, Gamble.STREAM).chance_permille(400):
			hit += 1
	gut.p("floors with a shrine: %d / %d (%d per mille)" % [hit, n, hit * 1000 / n])
	assert_almost_eq(float(hit) / n, 0.4, 0.03, "about 40 %")


func test_the_shrine_stands_in_a_combat_room_clear_and_reachable() -> void:
	var repo := ContentRepository.load_all()
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(repo)
	var share := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena")).share_permille
	var n := 60
	var drawn := 0
	var placed := 0
	for k in n:
		var seed_value := 5000 + k * 31
		var layout := _layout(seed_value, map, share)
		var at := Gamble.site(layout, _gamble, false, map)
		var rolled := Gamble.stream(seed_value, Gamble.STREAM).chance_permille(400)
		drawn += 1 if rolled else 0
		if not rolled:
			assert_true(at.is_empty(), "seed %d: no shrine when the draw says none" % seed_value)
			continue
		if at.is_empty():
			continue
		placed += 1
		var p := at[0]
		var room := layout.room_of(p)
		var tag := "seed %d" % seed_value
		assert_ne(room, layout.start_room, "%s: never the start hall" % tag)
		assert_ne(room, layout.boss_room, "%s: never the boss room" % tag)
		assert_ne(room, layout.boss_host_room, "%s: nor its host" % tag)
		assert_ne(room, layout.portal_room, "%s: nor the portal room" % tag)
		assert_ne(room, layout.overrun_room, "%s: nor the Overrun room" % tag)
		assert_ne(room, Routes.shop_room_of(layout), "%s: nor the shop's" % tag)
		assert_false(layout.arena_rooms.has(room), "%s: nor an arena" % tag)
		assert_true(layout.rooms[room].grow(-_gamble.clear_radius_m).has_point(p), tag)
		for o in layout.walls:
			assert_eq(Collide.circle_vs_obb(p, _gamble.clear_radius_m, o), Vector2.ZERO, tag)
		var must := layout.door_approaches(room, 1.0)
		for a in must:
			assert_gte(a.distance_to(p), Gamble.DOOR_GAP_M, "%s: clear of the doorways" % tag)
		var with: Array[Obb] = layout.room_walls(room)
		with.append(Gamble.collider(p))
		must.append(Gamble.front(p, must[0]))
		assert_true(FloorReach.whole(layout.rooms[room], with, map.nav_clearance, must), tag)
	gut.p("shrine drawn on %d / %d floors, placed on %d" % [drawn, n, placed])
	assert_eq(placed, drawn, "every floor that draws a shrine finds a room for it")
	assert_gt(placed, 0)


func test_three_wins_then_the_shrine_is_spent_and_refuses() -> void:
	var w := _world(5)
	w.shards = 10000
	for k in 3:
		_press(w)
		CombatLab.idle(w, 1)
	assert_eq(w.gamble_wins, 3, "three wins")
	assert_true(Gamble.spent(w), "spent")
	var total := 0
	for s in GambleTable.STAT_COUNT:
		total += Gamble.stacks(w, s)
	assert_eq(total, 3, "three stats")
	var shards := w.shards
	var uses := w.gamble_uses
	_press(w)
	assert_eq(w.shards, shards, "a spent shrine takes nothing")
	assert_eq(w.gamble_uses, uses)
	assert_eq(w.gamble_wins, 3, "and gives nothing")
	assert_eq(w.gamble_denied_tick, w.tick - 1, "it says no")
	var reader := WorldReader.new(w)
	assert_true(reader.gamble_spent())
	assert_eq([reader.gamble_wins(), reader.gamble_max_wins()], [3, 3])


func test_about_three_uses_in_ten_fail() -> void:
	var w := _world(5, _gamble)
	var n := 0
	var failed := 0
	for s in 20:
		w.seed_value = 700 + s
		for k in 100:
			n += 1
			failed += 1 if Gamble.fails(w, k) else 0
	gut.p("failed uses: %d / %d (%d per mille)" % [failed, n, failed * 1000 / n])
	assert_almost_eq(float(failed) / n, 0.3, 0.03, "about 30 %")
	assert_eq(Gamble.fails(w, 3), Gamble.fails(w, 3), "a use's outcome is fixed by the floor")
	var never := _world(5, _steady())
	for k in 50:
		assert_false(Gamble.fails(never, k), "fail_permille 0 never fails")


## The first world seed whose shrine's use `use` fails (and every use before it wins).
func _seed_failing_at(use: int) -> int:
	var w := _world(1, _gamble)
	for s in range(1, 1000):
		w.seed_value = s
		var ok := Gamble.fails(w, use)
		for k in use:
			ok = ok and not Gamble.fails(w, k)
		if ok:
			return s
	return -1


func test_a_failed_use_is_paid_grants_nothing_and_the_price_still_rises() -> void:
	var seed_value := _seed_failing_at(0)
	var w := _world(seed_value, _gamble)
	w.shards = 100
	var seq := w.events_since(-1).size()
	_press(w)
	assert_eq(w.shards, 75, "paid 25")
	assert_eq(w.gamble_uses, 1, "a try")
	assert_eq(w.gamble_wins, 0, "no win")
	assert_true(w.gamble_stacks.is_empty(), "no stat")
	assert_eq(w.gamble_fail_tick, 0, "the failure is recorded")
	assert_eq(w.gamble_tick, -1, "no win to show")
	assert_eq(Gamble.price(w), 38, "the price rises after a miss")
	var fails := 0
	for e in w.events_since(-1).slice(seq):
		fails += 1 if e.kind == SimEvent.Kind.GAMBLE_FAIL else 0
	assert_eq(fails, 1, "a GAMBLE_FAIL event")
	assert_false(Gamble.spent(w))
	var plain := _world(seed_value, _gamble)
	plain.shards = 100
	plain.gamble_uses = 1
	plain.gamble_wins = 1
	CombatLab.idle(plain, 1)
	plain.shards = 75
	assert_ne(plain.state_hash(), w.state_hash(), "the failure is hashed")


## A run seed whose floor 1 has a shrine.
func _run_with_shrine() -> int:
	for s in range(1, 40):
		var run := SaveLab.run_state(s, 1)
		if Gamble.stream(run.floor_seed(), Gamble.STREAM).chance_permille(400):
			return s
	return 1


func test_wins_tries_and_failures_survive_a_save_mid_shrine() -> void:
	var run_seed := _run_with_shrine()
	var w := SaveLab.floor_world(run_seed, 1)
	assert_ne(w.gamble_id, -1, "the floor has a shrine")
	w.shards = 10000
	w.gamble_uses = 2
	w.gamble_wins = 1
	w.gamble_fail_tick = 0
	Gamble.grant(w, GambleTable.Stat.MOVE)
	var snap := w.to_snapshot()
	var back := World.from_snapshot(snap, SaveLab.floor_world(run_seed, 1))
	assert_not_null(back, "the snapshot fits its floor")
	if back == null:
		return
	assert_eq([back.gamble_uses, back.gamble_wins, back.gamble_fail_tick], [2, 1, 0])
	assert_eq(back.gamble_pos, w.gamble_pos)
	assert_eq(back.state_hash(), w.state_hash())
	assert_eq(Gamble.price(back), Gamble.price(w), "the price after two tries")
	back.gamble_wins = 3
	assert_true(Gamble.spent(back), "spent at three wins after a load too")


func test_an_older_saves_shrine_stays_in_the_start_hall_and_counts_its_uses() -> void:
	var run := SaveLab.run_state(2, 1)
	run.floor_rules = RunState.FLOOR_RULES_V080_SR  # saved before N14
	assert_true(FloorScenario.legacy_shrine_of(run))
	var w := SaveLab.build_floor(run)
	assert_ne(w.gamble_id, -1, "an older floor always has its shrine")
	assert_eq(w.floor_layout.room_of(w.gamble_pos), w.floor_layout.start_room, "in the start hall")
	w.gamble_uses = 2
	w.gamble_wins = 2
	Gamble.grant(w, GambleTable.Stat.MAX_HP)
	Gamble.grant(w, GambleTable.Stat.MOVE)
	var snap := w.to_snapshot()
	var data: Dictionary = snap["world"]
	for f: StringName in [&"gamble_wins", &"gamble_fail_tick"]:
		assert_true(WorldSnapshot.ADDED_SINCE_V05[&"World"].has(f), "%s is listed as new" % f)
		data.erase(f)  # as a snapshot written before N14
	var again := SaveLab.run_state(2, 1)
	again.floor_rules = RunState.FLOOR_RULES_V080_SR
	var back := World.from_snapshot(snap, SaveLab.build_floor(again))
	assert_not_null(back, "an older save's floor fits")
	if back == null:
		return
	assert_eq(back.gamble_pos, w.gamble_pos, "its shrine stays where it was")
	assert_eq(back.gamble_wins, 2, "its wins start from its recorded uses")
	assert_eq(back.gamble_fail_tick, -1)
	back.shards = 10000
	back.actors.set_pos(0, back.gamble_pos + Vector2(1.2, 0))
	back.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, I))
	assert_eq(back.gamble_uses, 3, "and it keeps working")
	assert_false(FloorScenario.legacy_shrine_of(SaveLab.run_state(2, 1)), "today's floors")
	assert_false(FloorScenario.legacy_shrine_of(null), "a floor without a run")
