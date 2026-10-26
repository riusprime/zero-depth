extends GutTest
## v0.5.5 Step DS (owner D4, D7, "Yes, but hidden"): the hidden growth-matching difficulty. The build's power P is a
## pure function of the loadout; m = clamp(sqrt(P / E), 1, cap) with the cap raised by threat T; enemies arrive with
## HP × m and damage × sqrt(m); a boss takes its own m (its cap) when it spawns; m is fixed for the floor, hashed,
## saved, and never reaches the player's screen. Mechanics only: no bot balance sims (P1).

const LONG := 1 << 24


func _stats_at_base(w: World) -> void:
	if w.stat_values.size() < Stats.COUNT:
		w.stat_values = PackedInt32Array(Stats.BASE)


## v0.9.5 BH1 (Q2): the boss's HP spread of world w, per mille (the named stream `boss:hp_spread`, its first draw).
func _spread(w: World) -> int:
	return RngStream.derive(w.seed_value, CatchUp.spread_stream(w)).range_int(-80, 80)


## The boss m for a capped power on world w: the cap, then the spread.
func _with_spread(w: World, m: int) -> int:
	return m * (1000 + _spread(w)) / 1000


func test_a_fresh_build_has_power_1000_and_floor_one_is_unscaled() -> void:
	var w := SaveLab.floor_world(31, 1)
	assert_not_null(w.catch_up_table, "Main's setup (SaveLab as Main) loads the catch-up")
	assert_eq(CatchUp.power(w), 1000, "the build you start with")
	assert_eq(w.catch_up.power, 1000)
	assert_eq(w.catch_up.expected, 1000, "E(1)")
	assert_eq(w.catch_up.cap, 1500, "cap(1) with T = 0")
	assert_eq(w.catch_up.enemy, 1000, "×1: a fresh build meets the regular scaling only")


func test_power_is_a_pure_function_of_a_forced_loadout() -> void:
	var w := SaveLab.floor_world(31, 1)
	_stats_at_base(w)
	w.stat_values[Stats.Stat.DAMAGE] = 1500
	w.stat_values[Stats.Stat.ATTACK_SPEED] = 1200
	w.stat_values[Stats.Stat.CRIT_CHANCE] = 150  # 5 % base + 15 % = 20 % at ×1.5: expected ×1.100
	var sword := Abilities.index_of_kind(w, AbilityTable.Kind.COMBO_SWORD)
	Abilities.grant(w, sword)  # the weapon at level 2: ×1.12
	var drone := Abilities.index_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	Abilities.grant(w, drone)
	Abilities.grant(w, drone)  # an ability at level 2: + 2 × 120
	assert_eq(w.combos_owned.size(), 0, "no combo in this loadout")
	# 1120 × 1.5 = 1680; × 1100 / 1025 (base crit 5 % × 1.5) = 1802; × 1.2 = 2162; × 1.24 = 2680.
	assert_eq(CatchUp.base_crit(w), 1025)
	assert_eq(CatchUp.power(w), 2680)
	var before := CatchUp.power(w)
	w.actors.set_pos(0, w.actors.pos(0) + Vector2(1, 0))
	w.actors.hp[0] = 1
	w.shards = 999
	w.kills = 50
	assert_eq(CatchUp.power(w), before, "how the run is played never moves P")


func test_the_multiplier_is_the_capped_square_root() -> void:
	assert_eq(CatchUp.isqrt(0), 0)
	assert_eq(CatchUp.isqrt(1), 1)
	assert_eq(CatchUp.isqrt(15), 3)
	assert_eq(CatchUp.isqrt(16), 4)
	assert_eq(CatchUp.isqrt(2000000), 1414)
	assert_eq(CatchUp.multiplier(4000, 1000, 2500), 2000, "×4 the power: ×2")
	assert_eq(CatchUp.multiplier(2000, 1000, 2500), 1414, "twice as strong: ×1.41, still easier")
	assert_eq(CatchUp.multiplier(500, 1000, 2500), 1000, "weaker than expected: never below ×1")
	assert_eq(CatchUp.multiplier(100000, 1000, 1500), 1500, "ten times stronger hits the cap")
	assert_eq(CatchUp.damage_permille(2000), 1414, "damage × sqrt(m)")
	assert_eq(CatchUp.damage_permille(1000), 1000)


func test_floor_two_reads_the_build_at_entry_and_the_cap_rises_with_threat() -> void:
	var w := SaveLab.floor_world(32, 2)
	_stats_at_base(w)
	w.stat_values[Stats.Stat.DAMAGE] = 8000  # P = 8000 against E(2) = 2000: sqrt(4) = ×2
	CatchUp.start_floor(w)
	assert_eq(w.catch_up.expected, 2000)
	assert_eq(w.catch_up.cap, 2000, "cap(2) at T = 0")
	assert_eq(w.catch_up.enemy, 2000)
	w.stat_values[Stats.Stat.DAMAGE] = 100000
	CatchUp.start_floor(w)
	assert_eq(w.catch_up.enemy, 2000, "a broken build stops at the cap")
	var d := SaveLab.build_floor(SaveLab.run_state(32, 2, &"blade", Routes.Route.DEEP))
	_stats_at_base(d)
	d.stat_values[Stats.Stat.DAMAGE] = 100000
	CatchUp.start_floor(d)
	assert_eq(Curses.threat(d), 1, "the Deep floor is T + 1")
	assert_eq(d.catch_up.cap, 2250, "+0.25 per T")
	assert_eq(d.catch_up.enemy, 2250)


func test_m_is_fixed_for_the_floor() -> void:
	var w := SaveLab.floor_world(33, 2)
	_stats_at_base(w)
	w.stat_values[Stats.Stat.DAMAGE] = 4000
	CatchUp.start_floor(w)
	var m := w.catch_up.enemy
	w.stat_values[Stats.Stat.DAMAGE] = 50000  # cards taken mid-floor
	w.actors.invuln[0] = LONG
	CombatLab.idle(w, 120)
	assert_eq(w.catch_up.enemy, m, "no mid-floor rubber band")


func test_an_arriving_enemy_takes_hp_times_m_and_damage_times_sqrt_m() -> void:
	var w := SaveLab.floor_world(34, 2)
	var kind := w.spawner.kinds[0]
	w.add_enemy(kind, w.player_pos() + Vector2(6, 0))
	var i := w.actors.size() - 1
	w.catch_up.enemy = 1000
	SpawnDirector.scale_arrival(w, i, 600)
	var hp := w.actors.max_hp[i]
	var power := w.actors.power[i]
	w.catch_up.enemy = 1440
	SpawnDirector.scale_arrival(w, i, 600)
	assert_eq(w.actors.max_hp[i], hp * 1440 / 1000, "HP × m")
	assert_eq(w.actors.hp[i], w.actors.max_hp[i])
	assert_eq(w.actors.power[i], power * 1200 / 1000, "damage × sqrt(1.44) = ×1.2")


func test_a_boss_takes_its_own_m_with_the_boss_cap() -> void:
	var w := SaveLab.floor_world(35, 1)
	_stats_at_base(w)
	w.stat_values[Stats.Stat.DAMAGE] = 100000
	var k := 0
	var aid := w.spawn_boss(k, w.player_pos() + Vector2(8, 0))
	var i := w.actors.index_of(aid)
	assert_eq(w.catch_up.boss_expected, 2000, "E at floor 1's end")
	assert_eq(w.catch_up.boss_cap, 2500, "the boss cap on floor 1 (v0.9.5 BH1: ×2.5)")
	var m := _with_spread(w, 2500)
	assert_eq(w.catch_up.boss, m)
	assert_eq(w.actors.max_hp[i], w.boss_tables[k].hp * m / 1000, "boss HP × m")
	assert_eq(w.actors.power[i], CatchUp.damage_permille(m), "its attacks × sqrt(m)")
	assert_eq(w.catch_up.enemy, 1000, "the floor's enemies keep their m")
	var n := SaveLab.floor_world(35, 1)
	var nid := n.spawn_boss(k, n.player_pos() + Vector2(8, 0))
	var ni := n.actors.index_of(nid)
	assert_eq(n.catch_up.boss, _with_spread(n, 1000), "a fresh build: ×1, then the spread")
	assert_eq(n.actors.max_hp[ni], n.boss_tables[k].hp * n.catch_up.boss / 1000)


## Audit G-12: a boss's scaled damage rounds half up, as an enemy's does (SpawnTable.scale).
func test_a_boss_scales_damage_by_the_enemies_rounding() -> void:
	var w := SaveLab.floor_world(35, 1)
	var i := w.actors.index_of(w.spawn_boss(0, w.player_pos() + Vector2(8, 0)))
	w.actors.power[i] = 1200  # test setup
	assert_eq(BossAi.powered(w, i, 14), 17, "16.8 rounds to 17")
	assert_eq(BossAi.powered(w, i, 14), EnemyAi.powered(w, i, 14))


func test_the_boss_cap_grows_by_floor_and_threat() -> void:
	var w := SaveLab.build_floor(SaveLab.run_state(36, 3, &"blade", Routes.Route.DEEP))
	_stats_at_base(w)
	w.stat_values[Stats.Stat.DAMAGE] = 1000000
	w.spawn_boss(0, w.player_pos() + Vector2(8, 0))
	assert_eq(Curses.threat(w), 2, "two Deep floors taken")
	assert_eq(w.catch_up.boss_cap, 4000, "cap(3) = ×3.5, + 2 × 0.25")
	assert_eq(w.catch_up.boss, _with_spread(w, 4000))


## v0.9.5 BH1 (Q2): the boss cap by floor 1-5 is 2.5 / 3.0 / 3.5 / 4.0 / 4.5, a floor past the table repeats the last.
func test_the_boss_cap_table_by_floor() -> void:
	var w := SaveLab.floor_world(36, 1)
	var t := w.catch_up_table
	assert_eq(t.boss_cap_permille, PackedInt32Array([2500, 3000, 3500, 4000, 4500]))
	for f in [1, 2, 3, 4, 5]:
		assert_eq(CatchUpTable.at_floor(t.boss_cap_permille, f), 2000 + 500 * f, "floor %d" % f)
	assert_eq(CatchUp.cap_at(t.boss_cap_permille, t, 5, 2), 4500 + 500, "+ 0.25 per Threat")
	assert_eq(
		t.boss_expected_permille, PackedInt32Array([2000, 4000, 7000]), "expected power unchanged"
	)


## v0.9.5 BH1 (Q2): the spread is +-8 %, deterministic by seed, and not the same for every seed.
func test_the_boss_spread_is_deterministic_by_seed_and_within_8_percent() -> void:
	var seen := {}
	for s in range(40, 70):
		var a := SaveLab.floor_world(s, 1)
		var b := SaveLab.floor_world(s, 1)
		_stats_at_base(a)
		_stats_at_base(b)
		a.stat_values[Stats.Stat.DAMAGE] = 100000
		b.stat_values[Stats.Stat.DAMAGE] = 100000
		CatchUp.read_boss(a)
		CatchUp.read_boss(b)
		assert_eq(a.catch_up.boss, b.catch_up.boss, "seed %d: the same spread" % s)
		assert_between(
			a.catch_up.boss, 2500 * 920 / 1000, 2500 * 1080 / 1000, "seed %d: +-8 %%" % s
		)
		seen[a.catch_up.boss] = true
	assert_gt(seen.size(), 5, "different seeds meet different HP")


## v0.9.5 BH1 (H2, Q2): m is read when the door starts to open and held: the build changed between the door and the
## spawn does not move it; with no door read, the spawn reads it as before.
func test_the_boss_m_is_read_at_the_door_not_at_the_spawn() -> void:
	var w := SaveLab.floor_world(35, 1)
	_stats_at_base(w)
	w.stat_values[Stats.Stat.DAMAGE] = 100000
	CatchUp.read_boss(w)
	var at_door := w.catch_up.boss
	assert_eq(w.catch_up.boss_read, 1)
	assert_eq(at_door, _with_spread(w, 2500), "the strong build at the door")
	w.stat_values[Stats.Stat.DAMAGE] = 1000  # weaker after the door starts to open
	var i := w.actors.index_of(w.spawn_boss(0, w.player_pos() + Vector2(8, 0)))
	assert_eq(w.catch_up.boss, at_door, "the spawn used the door's m")
	assert_eq(w.actors.max_hp[i], w.boss_tables[0].hp * at_door / 1000)
	assert_eq(w.catch_up.boss_read, 0, "consumed by the spawn")
	var j := w.actors.index_of(w.spawn_boss(0, w.player_pos() + Vector2(-8, 0)))
	assert_ne(w.catch_up.boss, at_door, "the next boss reads its own m at its spawn")
	assert_lt(w.actors.max_hp[j], w.actors.max_hp[i])


func test_a_door_read_m_is_hashed_and_saved() -> void:
	var a := SaveLab.floor_world(37, 2)
	var b := SaveLab.floor_world(37, 2)
	assert_eq(a.state_hash(), b.state_hash())
	CatchUp.read_boss(a)
	assert_ne(a.state_hash(), b.state_hash(), "the stored m is in the hash")
	var snap := a.to_snapshot()
	var base := SaveLab.floor_world(37, 2)
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.catch_up.boss_read, 1)
	assert_eq(base.catch_up.boss, a.catch_up.boss)
	assert_eq(base.state_hash(), a.state_hash())


func test_m_is_hashed_and_a_save_round_trips_it_with_equal_hashes() -> void:
	var a := SaveLab.floor_world(37, 2)
	var b := SaveLab.floor_world(37, 2)
	assert_eq(a.state_hash(), b.state_hash())
	b.catch_up.enemy += 1
	assert_ne(a.state_hash(), b.state_hash(), "m is in the hash")
	_stats_at_base(a)
	a.stat_values[Stats.Stat.DAMAGE] = 6000
	CatchUp.start_floor(a)
	a.actors.invuln[0] = LONG
	CombatLab.idle(a, 240)
	var snap := a.to_snapshot()
	var base := SaveLab.floor_world(37, 2)
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.catch_up.enemy, a.catch_up.enemy, "m comes back")
	assert_eq(base.catch_up.power, a.catch_up.power)
	assert_eq(base.state_hash(), a.state_hash(), "equal hashes after the restore")
	CombatLab.idle(a, 60)
	CombatLab.idle(base, 60)
	assert_eq(base.state_hash(), a.state_hash(), "and they stay equal")


func test_a_world_without_the_table_is_untouched() -> void:
	var w := BossLab.world()
	assert_null(w.catch_up_table)
	assert_eq(CatchUp.power(w), 1000)
	var aid := w.spawn_boss(0, Vector2(8, 0))
	var i := w.actors.index_of(aid)
	assert_eq(w.actors.max_hp[i], w.boss_tables[0].hp)


func test_it_stays_hidden_from_the_player() -> void:
	# Presentation reads the sim only through WorldReader (EI-07, the layering test): no accessor, no view.
	var reader := GdSource.code_only(GdSource.read("res://src/sim/world/world_reader.gd"))
	assert_false(reader.contains("catch_up"), "WorldReader exposes no catch-up")
	for path in GdSource.files_under("res://src/presentation"):
		assert_false(GdSource.read(path).contains("catch_up"), "%s never shows it" % path)
