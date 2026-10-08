extends GutTest
## The Overrun threat branch (v0.4.0 AB): where its room goes (a property over 1,000 floor seeds), and in play the
## x1.5 HP and damage, the +50 % spawns while you're inside, the kill count that clears it, the ability-card altar
## and the doubled shards.

const SEEDS := 1000

var _repo: ContentRepository
var _items: Array[ItemTable] = []
var _enemies: Array[EnemyTable] = []
var _rewards: RewardTable
var _spawning: SpawnTable


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_items = ContentCompiler.compile_items(_repo)
	_enemies = ContentCompiler.compile_enemies(_repo)
	_rewards = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	_spawning = ContentCompiler.compile_spawning(_repo.get_def(&"spawning", &"floor_1"), _repo)


func _floor(seed_value: int) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := FloorScenario.build(seed_value, t, _enemies, _spawning, _items, _rewards, 1)
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	w.overrun_table = ContentCompiler.compile_overrun(_repo.get_def(&"overrun", &"overrun"))
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _enter(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, Overrun.reward_spot(f))
	w.step(InputFrame.new())


# --- Generation ---------------------------------------------------------------------------------------------------
func test_every_floor_has_one_overrun_room_off_the_boss_path() -> void:
	var none := 0
	var dead_ends := 0
	for s in range(1, SEEDS + 1):
		var f := FloorGenerator.generate(s)
		BossRoomBuilder.attach(f)
		var room := OverrunRooms.mark(f)
		if room < 0:
			none += 1
			assert_true(
				OverrunRooms.candidates(f).is_empty(), "seed %d: none only with no candidate" % s
			)
			continue
		var host := f.boss_host_room
		assert_false(
			room in [f.start_room, f.boss_room, host, f.portal_room], "seed %d: a side room" % s
		)
		assert_false(
			OverrunRooms.shortest_path(f, f.start_room, f.boss_room, -1).is_empty(),
			"seed %d: the boss room is reachable" % s
		)
		assert_false(
			OverrunRooms.shortest_path(f, f.start_room, room, -1).is_empty(),
			"seed %d: the Overrun room is reachable" % s
		)
		assert_false(
			OverrunRooms.shortest_path(f, f.start_room, host, -1).has(room),
			"seed %d: off the shortest way to the boss" % s
		)
		assert_false(
			OverrunRooms.shortest_path(f, f.start_room, f.boss_room, room).is_empty(),
			"seed %d: the boss is reachable without entering it" % s
		)
		assert_eq(
			f.overrun_doors.size(), f.neighbours(room).size(), "seed %d: every door framed" % s
		)
		for d in f.overrun_doors:
			assert_true(f.door_rooms[d].x == room or f.door_rooms[d].y == room)
		dead_ends += 1 if f.neighbours(room).size() == 1 else 0
	gut.p("overrun over %d seeds: %d floors without one, %d dead ends" % [SEEDS, none, dead_ends])
	assert_lt(none, SEEDS / 100, "exactly one per floor where possible (nearly always)")


func test_the_pick_is_deterministic_and_leaves_the_layout_alone() -> void:
	for s in [5, 77, 901]:
		var a := FloorGenerator.generate(s)
		BossRoomBuilder.attach(a)
		var walls := a.walls.size()
		var room := OverrunRooms.mark(a)
		var b := FloorGenerator.generate(s)
		BossRoomBuilder.attach(b)
		assert_eq(OverrunRooms.mark(b), room, "seed %d: same room" % s)
		assert_eq(a.walls.size(), walls, "no wall added")


# --- In play ------------------------------------------------------------------------------------------------------
func test_inside_only_in_the_room_and_spawns_are_raised() -> void:
	var w := _floor(21)
	assert_true(Overrun.enabled(w))
	w.step(InputFrame.new())
	assert_false(w.overrun.inside, "the start hall is not the Overrun")
	assert_false(w.overrun.touched(), "nor hashed before it is entered")
	assert_eq([Overrun.cap(w, 10), Overrun.interval(w, 60)], [10, 60])
	_enter(w)
	assert_true(w.overrun.inside)
	assert_eq([Overrun.cap(w, 10), Overrun.interval(w, 60)], [15, 40], "+50 % spawns")
	w.actors.set_pos(0, w.floor_layout.start_pos)
	w.step(InputFrame.new())
	assert_false(w.overrun.inside, "leaving it ends it")


func test_overrun_enemies_have_more_hp_and_hit_harder() -> void:
	var w := _floor(21)
	_enter(w)
	var guard := 0
	while w.overrun.boosted.is_empty() and guard < 1200:
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
		guard += 1
	assert_false(w.overrun.boosted.is_empty(), "an enemy arrived while inside")
	var i := w.actors.index_of(w.overrun.boosted[0])
	var base := _spawning.scaled_hp(w.enemy_table(w.actors.kinds[i]).hp, 0)
	assert_eq(w.actors.max_hp[i], base * 1500 / 1000, "x1.5 HP")
	assert_eq(w.actors.hp[i], w.actors.max_hp[i])
	var tier_power := _spawning.damage_permille(0)
	assert_eq(w.actors.power[i], tier_power * 1500 / 1000, "x1.5 on the tier's damage")
	assert_eq(EnemyAi.powered(w, i, 100), SpawnTable.scale(100, tier_power * 1500 / 1000))


func test_clearing_pays_an_ability_card_altar_and_double_shards() -> void:
	var w := _floor(21)
	_enter(w)
	var shards_before := w.shards
	var guard := 0
	while not w.overrun.cleared() and guard < 6000:
		guard += 1
		w.actors.invuln[0] = 5
		for id in w.overrun.boosted:
			var i := w.actors.index_of(id)
			if i > 0 and w.actors.invuln[i] == 0 and w.actors.dead[i] == 0:
				var at := w.actors.pos(i)
				Damage.hit(w, i, 100000, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, at, at)
		w.step(InputFrame.new())
	assert_true(w.overrun.cleared(), "twelve Overrun kills clear it")
	assert_gte(w.overrun.kills, 12, "packs can die together: the tick that reaches 12 clears it")
	assert_gt(w.overrun.shards_in, 0)
	assert_eq(w.overrun.bonus, w.overrun.shards_in, "their shards paid again: x2")
	assert_eq(w.shards - shards_before, w.overrun.shards_in * 2)
	var r := w.rewards.index_of(w.overrun.reward_id)
	assert_gte(r, 0, "an altar appeared")
	assert_eq(w.rewards.kind[r], RewardStore.Kind.ALTAR)
	var offer := w.rewards.offer_of(r)
	assert_false(offer.is_empty())
	for code in offer:
		assert_eq(Offers.type_of(code), Offers.ABILITY, "ability cards only")
	assert_true(Abilities.owned(w, Offers.ability_of(offer[0])), "a level-up of what you own first")
	assert_false(w.overrun.inside, "a cleared room is a normal room")
	assert_eq(Overrun.cap(w, 10), 10)


func test_overrun_play_replays_to_the_same_hash() -> void:
	var hashes := []
	for k in 2:
		var w := _floor(33)
		_enter(w)
		for n in 300:
			w.actors.invuln[0] = 5
			w.step(InputFrame.new())
		assert_true(w.overrun.touched())
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
