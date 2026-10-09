extends GutTest
## The Overrun threat branch (v0.4.0 AB): where its room goes (a property over 1,000 floor seeds), and in play (v0.5.5
## AR, owner S8) the sealed room: its 3-5 waves of 4 / 8 / 12 spawning inside with x1.5 HP and damage, the horde
## paused, the doors and the ability-card altar and the doubled shards after the last wave.

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


# --- In play (v0.5.5 AR, owner S8: the hardest sealed arena) ------------------------------------------------------
## Kills every enemy inside the sealed room (the waves' only way to end in a unit test).
func _kill_inside(w: World) -> void:
	if not w.arenas.sealed():
		return
	var rect := w.floor_layout.rooms[w.arenas.room].grow(Arenas.ROOM_MARGIN_M)
	for i in range(1, w.actors.size()):
		var at := w.actors.pos(i)
		if w.actors.dead[i] == 0 and w.actors.invuln[i] == 0 and rect.has_point(at):
			Damage.hit(w, i, 100000, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, at, at)


func _fight_to_clear(w: World, limit: int = 12000) -> int:
	var waves_seen := PackedInt32Array()
	var guard := 0
	while not w.overrun.cleared() and guard < limit:
		guard += 1
		w.actors.invuln[0] = 5
		_kill_inside(w)
		w.step(InputFrame.new())
		if w.arenas.sealed() and w.arenas.wave > 0 and not waves_seen.has(w.arenas.wave):
			waves_seen.append(w.arenas.wave)
	return waves_seen.size()


func test_walking_in_seals_it_and_the_horde_pauses() -> void:
	var w := _floor(21)
	assert_true(Overrun.enabled(w))
	w.step(InputFrame.new())
	assert_false(w.overrun.inside, "the start hall is not the Overrun")
	assert_false(w.overrun.touched(), "nor hashed before it is entered")
	assert_false(w.arenas.touched())
	_enter(w)
	assert_true(w.overrun.inside, "sealed in")
	assert_eq(w.arenas.room, w.floor_layout.overrun_room)
	assert_eq(
		w.arenas.barriers.size(), w.floor_layout.overrun_doors.size(), "a barrier in every doorway"
	)
	assert_between(w.arenas.waves, 3, 5, "3-5 waves, drawn per room")
	var cd := w.spawn_cd
	var ticks := w.run_ticks
	for n in 20:
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
	assert_eq(w.spawn_cd, cd, "the open floor's horde waits")
	assert_eq(w.run_ticks, ticks + 20, "the clock runs on")
	w.actors.set_pos(0, w.floor_layout.start_pos)
	w.step(InputFrame.new())
	assert_true(w.overrun.inside, "a teleport out doesn't unseal it: only the clear does")


func test_waves_of_four_spawn_inside_with_more_hp_and_damage() -> void:
	var w := _floor(21)
	_enter(w)
	var guard := 0
	while w.arenas.wave == 0 and guard < 600:
		w.actors.invuln[0] = 5
		w.step(InputFrame.new())
		guard += 1
	assert_eq(w.arenas.wave, 1, "the first wave came")
	var room := w.floor_layout.rooms[w.floor_layout.overrun_room]
	assert_eq(w.overrun.boosted.size(), 4, "floor 1: waves of 4")
	for id in w.overrun.boosted:
		var i := w.actors.index_of(id)
		assert_true(room.grow(0.1).has_point(w.actors.pos(i)), "spawned inside the room")
	var i := w.actors.index_of(w.overrun.boosted[0])
	var base := _spawning.hp_now(w.enemy_table(w.actors.kinds[i]).hp, w.run_ticks - 1)
	assert_eq(w.actors.max_hp[i], base * 1500 / 1000, "x1.5 HP")
	assert_eq(w.actors.power[i], _spawning.power_now(w.run_ticks - 1) * 1500 / 1000, "x1.5 damage")


func test_wave_sizes_follow_the_floor() -> void:
	var t := ContentCompiler.compile_overrun(_repo.get_def(&"overrun", &"overrun"))
	assert_eq(t.wave_sizes, PackedInt32Array([4, 8, 12]), "4, 8 or 12 by floor (S8)")
	assert_eq([t.waves_min, t.waves_max], [3, 5])
	assert_eq(ArenaTable.size_on(t.wave_sizes, 2), 8)
	assert_eq(ArenaTable.size_on(t.wave_sizes, 5), 12, "the last repeats")


func test_clearing_every_wave_opens_the_doors_and_pays() -> void:
	var w := _floor(21)
	var walls := w.walls.size()
	_enter(w)
	assert_eq(w.walls.size(), walls + w.arenas.barriers.size(), "the barriers stand")
	var waves := w.arenas.waves
	var shards_before := w.shards
	var seen := _fight_to_clear(w)
	assert_true(w.overrun.cleared(), "the last wave's death clears it")
	assert_eq(seen, waves, "every wave came, one after the other")
	assert_eq(w.walls.size(), walls, "the doors open")
	assert_false(w.arenas.sealed())
	assert_true(w.arenas.cleared.has(w.floor_layout.overrun_room))
	assert_eq(w.overrun.kills, waves * 4, "every Overrun kill counted")
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
	w.step(InputFrame.new())
	assert_false(w.arenas.sealed(), "and never seals again")


func test_overrun_play_replays_to_the_same_hash() -> void:
	var hashes := []
	for k in 2:
		var w := _floor(33)
		_enter(w)
		for n in 300:
			w.actors.invuln[0] = 5
			w.step(InputFrame.new())
		assert_true(w.overrun.touched())
		assert_true(w.arenas.touched())
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
