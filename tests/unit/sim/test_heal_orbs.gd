extends GutTest
## v0.4.0 TU, the owner's answers of 2026-10-08: heal orbs (D8: 10 % of kills, 25 % of max HP, walked over), the
## floor-1 boss eased with a full heal at its door (D9), and shards that keep growing with floor time (D7).

const KIND := ActorStore.Kind


func _world(chance: int = 1000) -> World:
	var w := CombatLab.world()
	w.reward_table = ContentCompiler.compile_rewards(
		ContentRepository.load_all().get_def(&"rewards", &"floor")
	)
	w.reward_table.heal_orb_chance_permille = chance
	return w


func _kill(w: World, at: Vector2, kind: int = KIND.CHARGER) -> void:
	var id := w.add_enemy(kind, at)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 999999, 1, 1, w.take_root(), 0, at, at)
	w.step(InputFrame.new())


func test_the_shipped_numbers() -> void:
	var t := ContentCompiler.compile_rewards(
		ContentRepository.load_all().get_def(&"rewards", &"floor")
	)
	assert_eq([t.heal_orb_chance_permille, t.heal_orb_heal_permille], [100, 250], "D8: 10 %, 25 %")
	assert_eq(
		RewardTable.new().heal_orb_chance_permille, 0, "a world without reward data drops none"
	)


func test_a_kill_drops_an_orb_where_it_fell_and_a_boss_none() -> void:
	var w := _world()
	_kill(w, Vector2(6, 0))
	assert_eq(w.orbs.size(), 1)
	assert_almost_eq(w.orbs.pos(0).x, 6.0, 0.6)
	var b := BossLab.world()
	b.reward_table.heal_orb_chance_permille = 1000
	var bi := b.actors.index_of(b.spawn_boss(0, Vector2(6, 0)))
	b.actors.invuln[bi] = 0
	Damage.hit(b, bi, 9999999, 1, 1, b.take_root(), 0, Vector2(6, 0), Vector2(6, 0))
	b.step(InputFrame.new())
	assert_eq(b.orbs.size(), 0, "a boss drops no orb")


func test_about_one_kill_in_ten_drops_one() -> void:
	var v := _world(100)
	var drops := 0
	for k in 400:
		var before := v.orbs.size()
		_kill(v, Vector2(6, 0))
		drops += v.orbs.size() - before
		v.orbs = HealOrbStore.new()  # a test-side reset, so the floor's limit never hides a drop
	assert_between(drops, 25, 60, "about 10 %% of 400 kills (%d)" % drops)


func test_walking_over_an_orb_heals_a_quarter_and_never_past_full() -> void:
	var w := _world()
	_kill(w, Vector2(3, 0))
	assert_eq(w.orbs.size(), 1)
	w.actors.hp[0] = 10
	var at := w.orbs.pos(0)
	w.actors.set_pos(0, at)
	w.step(InputFrame.new())
	assert_eq(w.orbs.size(), 0, "taken")
	assert_eq(w.actors.hp[0], 10 + w.actors.max_hp[0] / 4, "+25 % of max HP")
	var heals := w.events_since(0).filter(
		func(e: SimEvent) -> bool:
			return e.kind == SimEvent.Kind.HEAL and e.effect_id == HealOrbs.EFFECT
	)
	assert_eq(heals.size(), 1)
	_kill(w, Vector2(-3, 0))
	w.actors.hp[0] = w.actors.max_hp[0] - 5
	w.actors.set_pos(0, w.orbs.pos(0))
	w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "capped at max HP")


func test_an_orb_waits_while_hp_is_full_and_the_floor_holds_at_most_sixteen() -> void:
	var w := _world()
	_kill(w, Vector2(3, 0))
	w.actors.set_pos(0, w.orbs.pos(0))
	w.step(InputFrame.new())
	assert_eq(w.orbs.size(), 1, "full HP: the orb stays")
	for k in 20:
		_kill(w, Vector2(8, float(k)))
	assert_eq(w.orbs.size(), HealOrbs.MAX_ON_FLOOR)


func test_no_orb_no_hash_change() -> void:
	var a := CombatLab.world()
	var b := CombatLab.world()
	b.orbs = HealOrbStore.new()
	assert_eq(a.state_hash(), b.state_hash(), "an untouched store adds nothing to the hash")
	b.orbs.add(99, Vector2.ONE)
	assert_ne(a.state_hash(), b.state_hash(), "an orb on the floor is state")


func test_floor_1_bosses_are_eased_and_their_room_heals_you() -> void:
	var repo := ContentRepository.load_all()
	var run := RunState.start(5, ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors")))
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
	assert_eq(t2[0].hp, base[0].hp * 1400 / 1000, "floor 2 unchanged")


func test_shards_keep_growing_with_floor_time_after_the_peak() -> void:
	var w := RunLab.new(ContentRepository.load_all(), 78, &"gun").floor_world()
	var peak := TuningRun.peak_ticks(1)
	w.run_ticks = peak
	var at_peak := Rewards.shards_for_kill(w, KIND.CHARGER)
	w.run_ticks = peak + 3600 * 2
	assert_eq(w.spawner.danger_tier(w.run_ticks), w.spawner.danger_tier(peak), "the curve holds")
	assert_gt(Rewards.shards_for_kill(w, KIND.CHARGER), at_peak, "staying longer pays more shards")
