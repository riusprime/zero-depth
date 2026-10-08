extends GutTest
## Continuous spawning (PLAN v0.2.0 C, L6; hordes v0.4.0 SC, owner F7/F10): tiers every 30 s raise the cap (14 / 30
## / 50 at tier 0 of floors 1-3, +6 a tier, at most 120), shorten the interval (-10 % a tier), unlock more of the
## mix and scale HP (×1.10 a tier) and damage (×1.05 a tier). Packs arrive at the edges of the player's room and its
## neighbours, never within 8 m of the player, never in the boss room, and stop when the player dies.

const LONG := 1 << 24
const KIND := ActorStore.Kind


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


## Steps n ticks; returns [tick, kind, pos, max_hp, player_pos, power] for each enemy that appeared.
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
					[
						w.tick,
						w.actors.kinds[i],
						w.actors.pos(i),
						w.actors.max_hp[i],
						w.player_pos(),
						w.actors.power[i]
					]
				)
		if kill_each_tick:
			_kill_all(w)
	return out


## The arrivals grouped by tick: one group per pack.
func _packs(spawns: Array) -> Array:
	var by_tick := {}
	var order := []
	for s in spawns:
		if not by_tick.has(s[0]):
			by_tick[s[0]] = []
			order.append(s[0])
		by_tick[s[0]].append(s)
	return order.map(func(t: int) -> Array: return by_tick[t])


func test_the_cap_follows_the_formula_per_floor_and_tier() -> void:
	var t := _table()
	assert_eq(t.tier_ticks, 1800, "30 s")
	var base := {1: 14, 2: 30, 3: 50}
	for f in [1, 2, 3]:
		for tier in 30:
			assert_eq(
				t.cap(f, tier), mini(base[f] + 6 * tier, 120), "cap, floor %d tier %d" % [f, tier]
			)
	assert_eq(t.cap(1, 0), 14)
	assert_eq(t.cap(2, 0), 30)
	assert_eq(t.cap(3, 0), 50)
	assert_eq(t.cap(1, 17), 116)
	assert_eq(t.cap(1, 18), 120, "floor 1 reaches the hard cap at tier 18")
	assert_eq(t.cap(3, 12), 120, "floor 3 at tier 12")
	assert_eq(t.cap(4, 0), 50, "a floor past the table keeps the last entry")


## The tier tables are integer per-mille data (EI-02): within rounding of 1.10^tier, 1.05^tier and 0.9^tier, up to
## the tier cap (20, ten minutes), then flat.
func test_the_tier_tables_match_the_plan_formulas() -> void:
	var t := _table()
	assert_eq(t.hp_tier_permille.size(), 21)
	assert_eq(t.damage_tier_permille.size(), 21)
	assert_eq(t.interval_tier_permille.size(), 21)
	for tier in 21:
		assert_almost_eq(
			float(t.hp_tier_permille[tier]), 1000.0 * pow(1.10, tier), 0.5, "HP %d" % tier
		)
		assert_almost_eq(
			float(t.damage_tier_permille[tier]), 1000.0 * pow(1.05, tier), 0.5, "damage %d" % tier
		)
		assert_almost_eq(
			float(t.interval_tier_permille[tier]),
			1000.0 * pow(0.9, tier),
			0.5,
			"interval %d" % tier
		)
	assert_eq(t.scaled_hp(100, 0), 100)
	assert_eq(t.scaled_hp(100, 1), 110)
	assert_eq(t.scaled_hp(100, 5), 161, "100 × 1.611")
	assert_eq(t.scaled_hp(30, 3), 40, "rounded: 30 × 1.331 = 39.93")
	assert_eq(t.scaled_hp(100, 20), 673, "the tier cap")
	assert_eq(t.scaled_hp(100, 40), 673, "past the tier cap, flat")
	assert_eq(t.damage_permille(0), 1000)
	assert_eq(t.damage_permille(10), 1629)
	assert_eq(t.damage_permille(99), 2653)
	assert_eq(t.scaled_hp(1, 0), 1, "never 0 HP")


func test_the_interval_shrinks_ten_percent_a_tier() -> void:
	var t := _table()
	assert_eq(t.interval_start_ticks, 150, "2.5 s")
	assert_eq(t.interval_min_ticks, 24, "0.4 s")
	var want := [150, 135, 121, 109, 98, 88, 79, 71, 64, 58, 52]
	for tier in want.size():
		assert_eq(t.interval(tier), want[tier], "tier %d: 150 × 0.9^tier ticks" % tier)
	assert_eq(t.interval(20), 24, "150 × 0.122 = 18 → floored at 0.4 s")


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


func test_packs_follow_the_interval_and_never_exceed_the_cap() -> void:
	var w := _world()
	var t := w.spawner
	var packs := _packs(_run(w, 150 * 4))
	assert_gte(packs.size(), 3)
	assert_eq(packs[0][0][0], 150, "the first pack arrives after one interval (2.5 s)")
	assert_eq(packs[1][0][0], 300, "then one every 2.5 s")
	assert_eq(packs[2][0][0], 450)
	for p in packs:
		assert_between(p.size(), 2, 3, "floor 1 packs are 2-3 strong")
	# A longer run: the alive count stays under each tier's cap.
	var w2 := _world(5)
	var peak := 0
	for n in 3600 * 2:
		w2.step(InputFrame.new())
		var alive := WaveDirector.enemies_alive(w2)
		peak = maxi(peak, alive)
		assert_lte(alive, t.cap(1, t.tier_at(w2.run_ticks)), "under the cap")
		if n % 1500 == 0:
			_kill_all(w2)
	assert_gt(peak, 14, "the cap grew past tier 0's 14")


func test_a_later_tier_spawns_faster() -> void:
	var w := _world()
	w.run_ticks = 1800 * 4  # tier 4: 2.5 s × 0.656 = 98 ticks
	w.spawn_cd = 1
	var packs := _packs(_run(w, 400, true))
	assert_gte(packs.size(), 3)
	assert_eq(packs[1][0][0] - packs[0][0][0], 98, "98 ticks apart at tier 4")


func test_later_floors_send_bigger_packs_and_more_enemies() -> void:
	for f in [2, 3]:
		var w := _world(7)
		w.floor_index = f
		var packs := _packs(_run(w, 150 * 6))
		assert_eq(packs.size(), 6)
		for p in packs:
			assert_between(p.size(), 3, 4 if f == 2 else 5, "floor %d pack size" % f)
		_run(w, 150 * 5)
		assert_eq(w.spawner.tier_at(w.run_ticks), 0)
		var alive := WaveDirector.enemies_alive(w)
		assert_lte(alive, w.spawner.cap(f, 0), "never past the floor's cap")
		assert_gt(alive, w.spawner.cap(1, 0), "more than floor 1 ever fields at tier 0")


func test_a_fixed_pack_size_is_a_data_row() -> void:
	var w := _world()
	var sizes := w.spawner.packs.duplicate()
	sizes.fill(6)
	w.spawner.packs = sizes
	var packs := _packs(_run(w, 150 * 3))
	var sizes_seen := packs.map(func(p: Array) -> int: return p.size())
	assert_eq(sizes_seen, [6, 6, 2], "packs of 6, the third cut to the 2 the cap of 14 leaves")
	assert_eq(_run(w, 150).size(), 0, "full: nothing more")


func test_a_pack_stands_together() -> void:
	var w := _world()
	for p in _packs(_run(w, 150 * 5)):
		var anchor: Vector2 = p[0][2]
		for s in p:
			assert_lte(
				Kin.length(s[2] - anchor), 2.0 * SpawnDirector.PACK_STEP_M + 0.01, "near the anchor"
			)
			assert_gte(Kin.length(s[2] - s[4]), 8.0, "and 8 m from the player")


func test_the_mix_only_uses_unlocked_kinds() -> void:
	var w := _world()
	var t := w.spawner
	var at_zero := SpawnDirector.unlocked(w, t, 0)
	for k in at_zero:
		assert_ne(t.kinds[k], KIND.WARDEN, "no Warden at tier 0")
	# v0.4.0 EN: Swarmers and Splitters join at tier 1; Shield Bearers, Mine Layers and Snipers at 2; Menders at 3.
	assert_eq(SpawnDirector.unlocked(w, t, 1).size(), 6, "the first six from tier 1")
	assert_eq(SpawnDirector.unlocked(w, t, 2).size(), 10, "ten from tier 2")
	assert_eq(SpawnDirector.unlocked(w, t, 3).size(), 11, "all eleven from tier 3")
	for k in SpawnDirector.unlocked(w, t, 1):
		assert_ne(t.kinds[k], KIND.BOMB_DRONE, "no Bomb Drone before tier 2")
	for k in at_zero:
		assert_ne(t.kinds[k], KIND.ARC_CASTER, "no Arc Caster at tier 0")
	var early := _run(w, 1790, true)
	assert_gt(early.size(), 5)
	for s in early:
		assert_ne(s[1], KIND.WARDEN, "no Warden spawns at tier 0")
	var late := _run(w, 1800 * 2, true)
	var kinds := {}
	for s in late:
		kinds[s[1]] = true
	assert_true(kinds.has(KIND.WARDEN), "Wardens join from tier 1")
	assert_true(kinds.has(KIND.CHARGER))
	assert_true(kinds.has(KIND.NEEDLE))


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


func test_hp_and_damage_scale_by_tier() -> void:
	var w := _world()
	w.run_ticks = 1800 * 3
	w.spawn_cd = 1
	var spawns := _run(w, 5)
	assert_gte(spawns.size(), 2)
	var base := w.enemy_table(spawns[0][1]).hp
	assert_eq(spawns[0][3], (base * 1331 + 500) / 1000, "max HP × 1.331 at tier 3")
	assert_eq(spawns[0][5], 1158, "damage × 1.158 at tier 3")
	assert_eq(w.actors.hp[1], w.actors.max_hp[1], "spawns at full (scaled) HP")
	var i := 1
	assert_eq(EnemyAi.powered(w, i, 10), 12, "a 10-damage attack hits for 12 (11.58)")
	assert_eq(EnemyAi.powered(w, i, 100), 116)
	var placed := w.add_enemy(KIND.CHARGER, Vector2(20, 0))
	assert_eq(EnemyAi.powered(w, w.actors.index_of(placed), 10), 10, "an enemy placed by hand: ×1")


func test_a_tier_scaled_charger_hits_harder() -> void:
	var w := _world(11, false)
	w.spawner = null
	var id := w.add_enemy(KIND.CHARGER, Vector2(3, 0))
	var i := w.actors.index_of(id)
	w.actors.power[i] = 2000
	var hp0 := w.actors.hp[0]
	var dealt := 0
	for n in 400:
		w.step(InputFrame.new())
		if w.actors.hp[0] < hp0:
			dealt = hp0 - w.actors.hp[0]
			break
	var t := w.enemy_table(KIND.CHARGER)
	assert_gt(dealt, 0, "the charge landed")
	assert_eq(dealt, t.damage * 2, "power 2000: twice the table's damage")


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
	_run(w, 320)
	var alive := WaveDirector.enemies_alive(w)
	assert_between(alive, 4, 6, "two packs of 2-3")
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


# --- On a real floor ---------------------------------------------------------------------------------------


## Packs on a generated floor: in the player's room or a neighbour, never the boss room, clear of walls, 8 m away,
## and anchored at a room's edge when the rooms offer one.
func test_packs_on_a_floor_keep_the_placement_rules() -> void:
	var w := FightLab.floor_world(20261007, 2)
	w.actors.invuln[0] = LONG
	var f := w.floor_layout
	var anchors := SpawnDirector.anchor_points(w)
	assert_false(anchors.is_empty())
	for q in anchors:
		var rect := f.rooms[f.room_of(q)]
		var to_edge := minf(
			minf(q.x - rect.position.x, rect.end.x - q.x),
			minf(q.y - rect.position.y, rect.end.y - q.y)
		)
		assert_lte(to_edge, w.spawner.edge_band_m + 1e-4, "anchored at a room's edge")
	var room := f.room_of(w.player_pos())
	var near := f.neighbours(room)
	near.append(room)
	var spawns := _run(w, 1800, true)
	assert_gt(spawns.size(), 8)
	for s in spawns:
		var q: Vector2 = s[2]
		assert_gte(Kin.length(q - s[4]), 8.0, "8 m from the player")
		assert_true(near.has(f.room_of(q)), "in the player's room or a neighbour")
		assert_ne(f.room_of(q), f.boss_room, "never in the boss room")
		for wall in w.walls:
			assert_eq(Collide.circle_vs_obb(q, 0.5, wall), Vector2.ZERO, "clear of walls")


## v0.4.0 SC (F7): a floor at a high danger tier fields a large crowd (the cap at floor 3, tier 12 is 120).
func test_a_high_tier_floor_fields_a_large_crowd() -> void:
	var w := FightLab.floor_world(20261007, 3)
	w.actors.invuln[0] = LONG
	w.run_ticks = 1800 * 12
	var t := w.spawner
	assert_eq(t.cap(3, 12), 120)
	var peak := 0
	for n in 1500:
		w.step(InputFrame.new())
		w.actors.invuln[0] = LONG
		peak = maxi(peak, WaveDirector.enemies_alive(w))
	assert_gte(peak, 100, "a crowd of at least 100 on screen")
	assert_lte(peak, 120, "never past the cap")
