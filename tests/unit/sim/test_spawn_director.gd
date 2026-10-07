extends GutTest
## Continuous spawning (PLAN v0.2.0 C, L6): tiers every 30 s raise the cap, shorten the interval, unlock the
## Warden and scale HP; spawns stay at least 8 m from the player and stop when the player dies.

const LONG := 1 << 24


func _table() -> SpawnTable:
	var repo := ContentRepository.load_all()
	return ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo)


## A wall-less world with the real enemies and three rings of spawn points: 5 m (always too near), 9 m, 12 m.
func _world(seed_value: int = 11, invulnerable: bool = true) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for r in [5.0, 9.0, 12.0]:
		for k in 8:
			w.spawn_points.append(Kin.dir(k * 512) * r)
	w.spawner = _table()
	if invulnerable:
		w.actors.invuln[0] = LONG
	return w


func _kill_all(w: World) -> void:
	for i in range(1, w.actors.size()):
		w.actors.invuln[i] = 0
		Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))


## Steps n ticks; returns [tick, kind, pos, max_hp, player_pos] for each enemy that appeared.
func _run(w: World, n: int, kill_each_tick: bool = false, moving: bool = false) -> Array:
	var seen := {}
	for i in w.actors.size():
		seen[w.actors.ids[i]] = true
	var out := []
	for t in n:
		var f := InputFrame.new()
		if moving:
			f = InputFrame.make(Vector2i(127 if (t / 90) % 2 == 0 else -127, 0), 0, 0, 0, 0)
		w.step(f)
		for i in range(1, w.actors.size()):
			var id := w.actors.ids[i]
			if not seen.has(id):
				seen[id] = true
				out.append(
					[w.tick, w.actors.kinds[i], w.actors.pos(i), w.actors.max_hp[i], w.player_pos()]
				)
		if kill_each_tick:
			_kill_all(w)
	return out


func test_the_table_follows_the_formula_per_tier() -> void:
	var t := _table()
	assert_eq(t.tier_ticks, 1800, "30 s")
	for tier in 12:
		assert_eq(t.cap(tier), mini(3 + 2 * tier, 14), "cap at tier %d" % tier)
		var want_interval := maxi(48, 180 - 15 * tier)  # max(0.8, 3.0 - 0.25n) s at 60 Hz
		assert_eq(t.interval(tier), want_interval, "interval at tier %d" % tier)
	assert_eq(t.cap(6), 14, "capped at 14")
	assert_eq(t.interval(9), 48, "floored at 0.8 s")
	assert_eq(t.hp_per_tier_permille, 80)


func test_tiers_advance_every_30_seconds() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	CombatLab.idle(w, 1799)
	assert_eq(r.tier(), 0)
	CombatLab.idle(w, 1)
	assert_eq(r.tier(), 1, "tier 1 at 30 s")
	assert_almost_eq(r.run_seconds(), 30.0, 1e-6)
	CombatLab.idle(w, 1800)
	assert_eq(r.tier(), 2, "tier 2 at 60 s")


func test_spawns_follow_the_interval_and_never_exceed_the_cap() -> void:
	var w := _world()
	var t := w.spawner
	var spawns := _run(w, 180 * 5)
	assert_gte(spawns.size(), 3)
	assert_eq(spawns[0][0], 180, "the first enemy arrives after one interval (3 s)")
	assert_eq(spawns[1][0], 360, "then one every 3 s")
	assert_eq(spawns[2][0], 540)
	assert_eq(spawns.size(), t.cap(0), "nobody dies, so the cap of 3 holds")
	# A longer run: the alive count stays under each tier's cap.
	var w2 := _world(5)
	for n in 3600 * 2:
		w2.step(InputFrame.new())
		assert_lte(WaveDirector.enemies_alive(w2), t.cap(t.tier_at(w2.run_ticks)), "under the cap")
		if n % 7 == 0:
			_kill_all(w2)


func test_a_later_tier_spawns_faster() -> void:
	var w := _world()
	w.run_ticks = 1800 * 4  # tier 4: interval 2.0 s
	w.spawn_cd = 1
	var spawns := _run(w, 400, true)
	assert_gte(spawns.size(), 3)
	assert_eq(spawns[1][0] - spawns[0][0], 120, "2.0 s apart at tier 4")


func test_the_mix_only_uses_unlocked_kinds() -> void:
	var w := _world()
	var t := w.spawner
	var at_zero := SpawnDirector.unlocked(w, t, 0)
	for k in at_zero:
		assert_ne(t.kinds[k], ActorStore.Kind.WARDEN, "no Warden at tier 0")
	# v0.4.0 EN: Swarmers and Splitters join at tier 1; Shield Bearers, Mine Layers and Snipers at 2; Menders at 3.
	assert_eq(SpawnDirector.unlocked(w, t, 1).size(), 6, "the first six from tier 1")
	assert_eq(SpawnDirector.unlocked(w, t, 2).size(), 10, "ten from tier 2")
	assert_eq(SpawnDirector.unlocked(w, t, 3).size(), 11, "all eleven from tier 3")
	for k in SpawnDirector.unlocked(w, t, 1):
		assert_ne(t.kinds[k], ActorStore.Kind.BOMB_DRONE, "no Bomb Drone before tier 2")
	for k in at_zero:
		assert_ne(t.kinds[k], ActorStore.Kind.ARC_CASTER, "no Arc Caster at tier 0")
	var early := _run(w, 1790, true)
	assert_gt(early.size(), 5)
	for s in early:
		assert_ne(s[1], ActorStore.Kind.WARDEN, "no Warden spawns at tier 0")
	var late := _run(w, 1800 * 2, true)
	var kinds := {}
	for s in late:
		kinds[s[1]] = true
	assert_true(kinds.has(ActorStore.Kind.WARDEN), "Wardens join from tier 1")
	assert_true(kinds.has(ActorStore.Kind.CHARGER))
	assert_true(kinds.has(ActorStore.Kind.NEEDLE))


func test_spawns_are_never_near_the_player() -> void:
	var w := _world(23)
	var spawns := _run(w, 3600, true, true)
	assert_gt(spawns.size(), 10)
	for s in spawns:
		assert_gte(Kin.length(s[2] - s[4]), 8.0, "spawned at least 8 m away")


func test_no_far_point_means_no_spawn() -> void:
	var w := _world()
	w.spawn_points = PackedVector2Array([Vector2(5, 0), Vector2(0, -5), Vector2(-7.9, 0)])
	assert_eq(_run(w, 900).size(), 0, "nothing appears next to the player")


func test_hp_scales_by_tier() -> void:
	var t := _table()
	assert_eq(t.scaled_hp(100, 0), 100)
	assert_eq(t.scaled_hp(100, 1), 108)
	assert_eq(t.scaled_hp(100, 5), 140)
	assert_eq(t.scaled_hp(25, 3), 31, "integer math: 25 × 1240 / 1000")
	var w := _world()
	w.run_ticks = 1800 * 3
	w.spawn_cd = 1
	var spawns := _run(w, 5)
	assert_eq(spawns.size(), 1)
	var base := w.enemy_table(spawns[0][1]).hp
	assert_eq(spawns[0][3], base * 1240 / 1000, "max HP × 1.24 at tier 3")
	assert_eq(w.actors.hp[1], w.actors.max_hp[1], "spawns at full (scaled) HP")


func test_no_spawns_after_death() -> void:
	var w := _world(11, false)
	CombatLab.idle(w, 200)
	Damage.hit(w, 0, 99999, 1, 1, 1, 0, Vector2.ZERO, Vector2.ZERO)
	assert_true(w.player_dead())
	_kill_all(w)
	CombatLab.idle(w, 2)
	var ticks := w.run_ticks
	assert_eq(_run(w, 1200).size(), 0, "nothing spawns after death")
	assert_eq(w.run_ticks, ticks, "the run clock stops")


func test_kills_are_counted() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	_run(w, 400)
	var alive := WaveDirector.enemies_alive(w)
	assert_eq(alive, 2)
	_kill_all(w)
	CombatLab.idle(w, 20)
	assert_eq(r.kills(), alive)


func test_same_seed_same_spawns() -> void:
	var a := _world(42)
	var b := _world(42)
	var sa := _run(a, 2400, true, true)
	var sb := _run(b, 2400, true, true)
	assert_gt(sa.size(), 5)
	assert_eq(str(sa), str(sb), "same spawn sequence")
	assert_eq(a.state_hash(), b.state_hash())
	var c := _world(43)
	assert_ne(str(_run(c, 2400, true, true)), str(sa), "another seed differs")
