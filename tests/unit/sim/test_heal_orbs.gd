extends GutTest
## v0.4.0 TU, the owner's answers of 2026-10-08: heal orbs walked over, the floor-1 boss eased with a full heal at its
## door (D9), and shards that keep growing with floor time (D7).
## v0.11.0 F3 (owner's playtest §6): every run earns orbs through kills, with no card: 20 % of max HP, one on the floor,
## a 30 s cooldown from each pickup, a meter weighted by the enemy's base HP. The mechanic tests below shrink the meter
## (a test-side write) to force a drop.

const KIND := ActorStore.Kind
const COOLDOWN := 1800


func _world(meter: int = 1) -> World:
	var w := CombatLab.world()
	w.reward_table = ContentCompiler.compile_rewards(
		SharedContent.repo().get_def(&"rewards", &"floor")
	)
	w.reward_table.heal_orb_meter = meter
	return w


func _kill(w: World, at: Vector2, kind: int = KIND.CHARGER) -> void:
	var id := w.add_enemy(kind, at)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 999999, 0, 0, w.take_root(), 0, at, at)
	w.step(InputFrame.new())


## Takes the orb lying on the floor (a hurt hero walks onto it): the tick after, the cooldown runs.
func _take(w: World) -> void:
	w.actors.hp[0] = 10
	w.actors.set_pos(0, w.orbs.pos(0))
	w.step(InputFrame.new())


func test_the_shipped_numbers() -> void:
	var repo := SharedContent.repo()
	var t := ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))
	assert_eq(t.heal_orb_heal_permille, 200, "F3: 20 % of max HP")
	assert_eq(t.heal_orb_cooldown_ticks, COOLDOWN, "F3: 30 s")
	assert_gt(t.heal_orb_meter, 0, "F3: kills earn orbs in every run")
	assert_eq(RewardTable.new().heal_orb_meter, 0, "a world without reward data earns none")
	var tuning: SimTuningDefinition = repo.get_def(&"tuning", &"sim")
	assert_eq(
		RunContentCompiler.compile_sim_tuning(tuning).heal_orbs_max, 1, "F3: one on the floor"
	)


func test_lifesprout_is_disabled_but_kept() -> void:
	var repo := SharedContent.repo()
	var ls := ContentCompiler.compile_stat_cards(repo)[Stats.Stat.LIFESPROUT]
	assert_not_null(ls, "F3: the card's file stays, so it can return")
	assert_eq(ls.weight, 0, "F3: never offered (Offers leaves out a weight under 1)")


func test_lifesprout_has_no_effect_on_earning() -> void:
	var w := _world(10000)
	w.stat_tables = ContentCompiler.compile_stat_cards(SharedContent.repo())
	_kill(w, Vector2(6, 0))
	var plain := w.orbs.meter
	Stats.add_card(w, Stats.Stat.LIFESPROUT, Stats.Rarity.EPIC)
	_kill(w, Vector2(6, 0))
	assert_eq(w.orbs.meter, plain * 2, "the card adds nothing")


func test_earning_draws_no_loot() -> void:
	var w := _world(10000)
	var loot := w.rng_loot.state
	for k in 20:
		_kill(w, Vector2(6, 0))
	assert_eq(w.rng_loot.state, loot, "the meter is not a roll")


func test_the_meter_fills_and_the_orb_drops_where_the_filling_kill_fell() -> void:
	var w := _world()
	var per := HealOrbs.points(w, KIND.CHARGER)
	w.reward_table.heal_orb_meter = per * 3
	_kill(w, Vector2(5, 2))
	_kill(w, Vector2(5, 2))
	assert_eq([w.orbs.size(), w.orbs.meter], [0, per * 2], "two of three: no orb yet")
	_kill(w, Vector2(6, 0))
	assert_eq([w.orbs.size(), w.orbs.meter], [1, 0], "the third fills it, and it resets")
	assert_almost_eq(w.orbs.pos(0).x, 6.0, 0.6, "where the filling kill fell")


func test_a_boss_earns_nothing() -> void:
	var b := BossLab.world()
	b.reward_table.heal_orb_meter = 1
	var bi := b.actors.index_of(b.spawn_boss(0, Vector2(6, 0)))
	b.actors.invuln[bi] = 0
	Damage.hit(b, bi, 9999999, 0, 0, b.take_root(), 0, Vector2(6, 0), Vector2(6, 0))
	b.step(InputFrame.new())
	assert_eq([b.orbs.size(), b.orbs.meter], [0, 0], "a boss drops no orb and earns no points")


func test_points_follow_base_hp_within_the_clamp_and_ignore_scaling() -> void:
	var w := _world()
	var t := w.reward_table
	var e := w.enemy_table(KIND.CHARGER)
	assert_eq(HealOrbs.points(w, KIND.CHARGER), e.base_hp, "1 point per base HP")
	var base := e.base_hp
	e.hp = e.hp * 9  # as RunState.scale_enemies does on deep floors and loops
	assert_eq(HealOrbs.points(w, KIND.CHARGER), base, "scaling earns nothing more")
	e.base_hp = 1
	assert_eq(HealOrbs.points(w, KIND.CHARGER), t.heal_orb_points_min, "the floor of the clamp")
	e.base_hp = 100000
	assert_eq(HealOrbs.points(w, KIND.CHARGER), t.heal_orb_points_max, "the ceiling of the clamp")


func test_many_critters_earn_about_what_a_few_big_ones_earn() -> void:
	var w := _world()
	var repo := SharedContent.repo()
	var critter: EnemyDefinition = repo.get_def(&"enemies", &"swarmer")
	var big: EnemyDefinition = repo.get_def(&"enemies", &"shield_bearer")
	var critters := big.hp / critter.hp
	var c := (
		clampi(critter.hp, w.reward_table.heal_orb_points_min, w.reward_table.heal_orb_points_max)
		* critters
	)
	var b := clampi(big.hp, w.reward_table.heal_orb_points_min, w.reward_table.heal_orb_points_max)
	assert_between(c, b * 3 / 4, b * 5 / 4, "%d critters (%d) vs one big (%d)" % [critters, c, b])


func test_one_orb_at_most_and_progress_stops_while_it_lies() -> void:
	var w := _world()
	_kill(w, Vector2(3, 0))
	assert_eq(w.orbs.size(), 1)
	var id := w.orbs.ids[0]
	w.actors.set_pos(0, w.orbs.pos(0))
	w.step(InputFrame.new())
	assert_eq(w.orbs.size(), 1, "full HP: the orb stays")
	for k in 20:
		_kill(w, Vector2(8, float(k)))
	assert_eq([w.orbs.size(), w.orbs.ids[0]], [1, id], "never a second, never replaced")
	assert_eq(w.orbs.meter, 0, "no progress while one lies")


func test_walking_over_an_orb_heals_a_fifth_and_never_past_full() -> void:
	var w := _world()
	_kill(w, Vector2(3, 0))
	_take(w)
	assert_eq(w.orbs.size(), 0, "taken")
	assert_eq(w.actors.hp[0], 10 + w.actors.max_hp[0] / 5, "+20 % of max HP")
	var heals := w.events_since(0).filter(
		func(e: SimEvent) -> bool:
			return e.kind == SimEvent.Kind.HEAL and e.effect_id == HealOrbs.EFFECT
	)
	assert_eq(heals.size(), 1)
	w.tick += COOLDOWN
	_kill(w, Vector2(-3, 0))
	w.actors.hp[0] = w.actors.max_hp[0] - 5
	w.actors.set_pos(0, w.orbs.pos(0))
	w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "capped at max HP")


func test_the_cooldown_blocks_orbs_and_progress_until_it_ends() -> void:
	var w := _world(30)
	var per := HealOrbs.points(w, KIND.CHARGER)
	w.reward_table.heal_orb_meter = per
	_kill(w, Vector2(3, 0))
	_take(w)
	var ready := w.orbs.ready_tick
	assert_eq(ready, w.tick - 1 + COOLDOWN, "a pickup starts 30 s, on World.tick")
	_kill(w, Vector2(3, 0))
	assert_eq([w.orbs.size(), w.orbs.meter], [0, 0], "cooling: no orb, no progress")
	while w.tick < ready - 1:
		w.step(InputFrame.new())
	_kill(w, Vector2(3, 0))
	assert_eq(w.tick - 1, ready - 1, "the last tick of the cooldown")
	assert_eq([w.orbs.size(), w.orbs.meter], [0, 0], "the last cooling tick earns nothing")
	_kill(w, Vector2(8, 0))  # away from the hurt hero, who would take it at once
	assert_eq(w.orbs.size(), 1, "the cooldown is over: the kill earns the orb")


func test_a_broken_prop_obeys_the_gate_and_leaves_the_meter() -> void:
	var w := _world(1000)
	w.breakables = Breakables.new()
	w.breakables.add(Vector2(4, 0), Breakables.Kind.CRATE, 0, Breakables.Drop.HEAL, 0)
	w.breakables.add(Vector2(5, 0), Breakables.Kind.CRATE, 0, Breakables.Drop.HEAL, 0)
	w.breakables.add(Vector2(6, 0), Breakables.Kind.CRATE, 0, Breakables.Drop.HEAL, 0)
	w.orbs.meter = 40
	w.orbs.ready_tick = w.tick + 100
	Breakables.hit(w, 0)
	assert_eq(w.orbs.size(), 0, "during the cooldown: nothing")
	w.orbs.ready_tick = 0
	Breakables.hit(w, 1)
	assert_eq(w.orbs.size(), 1, "gate open: the orb")
	assert_eq(w.orbs.meter, 40, "the meter is not touched")
	var id := w.orbs.ids[0]
	Breakables.hit(w, 2)
	assert_eq(
		[w.orbs.size(), w.orbs.ids[0]], [1, id], "one lies: drops nothing, pushes out nothing"
	)


## The owner's 40 % a minute, by construction: heavy kills every tick for ten minutes, a hurt hero standing on every
## orb as it drops: never more than 2 pickups (40 % of max HP) in any 60 s.
func test_the_healing_rate_never_exceeds_forty_percent_a_minute() -> void:
	var w := _world()
	var at := PackedInt32Array()
	var ready := 0
	for tick in 18000:  # five minutes
		_kill(w, w.player_pos() + Vector2(0.2, 0))
		if w.orbs.ready_tick != ready:
			ready = w.orbs.ready_tick
			at.append(w.tick)
			assert_eq(w.actors.hp[0], 1 + w.actors.max_hp[0] / 5, "20 % each")
		if w.orbs.size() > 0:
			w.actors.set_pos(0, w.orbs.pos(0))
		w.actors.hp[0] = 1
	assert_eq(at.size(), 10, "heavy kills earn one every 30 s (%s)" % [at])
	for k in range(1, at.size()):
		assert_gte(at[k] - at[k - 1], COOLDOWN, "pickups are 30 s apart at least")
	for k in range(2, at.size()):
		assert_gte(at[k] - at[k - 2], 3600, "so no 60 s holds three: at most 40 % of max HP")


func test_the_state_is_hashed_once_used_and_survives_a_snapshot() -> void:
	var a := CombatLab.world()
	var b := CombatLab.world()
	b.orbs = HealOrbStore.new()
	assert_eq(a.state_hash(), b.state_hash(), "an untouched store adds nothing to the hash")
	b.orbs.add(99, Vector2.ONE)
	assert_ne(a.state_hash(), b.state_hash(), "an orb on the floor is state")
	var w := _world(10000)
	_kill(w, Vector2(6, 0))
	assert_true(w.orbs.touched, "a kill's points use the store")
	var before := w.state_hash()
	w.orbs.meter += 1
	assert_ne(w.state_hash(), before, "the meter is state")
	w.orbs.meter -= 1
	w.orbs.ready_tick = 7
	assert_ne(w.state_hash(), before, "the cooldown is state")
	var props := w.orbs.get_property_list().map(func(p: Dictionary) -> String: return p["name"])
	assert_has(props, "meter", "WorldSnapshot copies a store's script properties")
	assert_has(props, "ready_tick")


func test_floor_1_bosses_are_eased_and_their_room_heals_you() -> void:
	var repo := SharedContent.repo()
	var run := RunState.start(5, ContentCompiler.compile_run(repo.get_def(&"run", RunSaver.RUN_ID)))
	var base := ContentCompiler.compile_bosses(repo)
	var t := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(t, 1)
	for k in t.size():
		assert_eq(t[k].hp, base[k].hp * 800 / 1000, "%s: -20 %% HP on floor 1" % t[k].id)
	var lab := RunLab.new(repo, 77, &"blade")
	var w := lab.floor_world()
	assert_eq(w.boss_room_heal_permille, 1000, "floor 1: full")
	w.actors.hp[0] = 20
	w.actors.set_pos(0, w.floor_layout.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	assert_true(w.boss_flow.door_sealed())
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "the floor-1 boss room restores your HP")
	lab.next_floor(w)
	var w2 := lab.floor_world()
	assert_eq(w2.boss_room_heal_permille, 0, "floor 2: no heal")
	var t2 := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(t2, 2)
	assert_eq(t2[0].hp, base[0].hp * 1200 / 1000, "floor 2 unchanged (v0.9.0 FV: +20 % a floor)")


func test_shards_stop_growing_after_the_peak() -> void:
	var w := RunLab.new(SharedContent.repo(), 78, &"gun").floor_world()
	var peak := w.reward_table.shard_cap_min_ticks  # v0.10.5 O7a: the cap (floor 1 peaks at 90 s, the minimum is 180 s)
	w.run_ticks = peak
	var at_peak := Rewards.shards_for_kill(w, KIND.CHARGER)
	w.run_ticks = peak + 3600 * 2
	# v0.9.5 DC: past the peak the danger tier keeps rising (+1 per 30 s to 20), so the curve no longer holds
	assert_gt(
		w.spawner.danger_tier(w.run_ticks), w.spawner.danger_tier(peak), "the tier keeps rising"
	)
	assert_eq(
		Rewards.shards_for_kill(w, KIND.CHARGER), at_peak, "v0.10.5 O7a: no more past the peak"
	)
	w.reward_table.shard_tier_caps_at_peak = false
	assert_gt(
		Rewards.shards_for_kill(w, KIND.CHARGER), at_peak, "flag off: staying longer pays more"
	)
