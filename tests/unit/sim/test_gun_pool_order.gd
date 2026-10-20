extends GutTest
## v0.6.5 WN3 (docs/design/WAND.md rules 2, 6, 8; the Gun pool): the Gun cards apply left to right (order-sensitive
## by construction: a card reaches the children built to its left, never those to its right), a duplicate levels a
## card up 1–5 without a new slot, the levels compile into the bolt and travel with saves and floors, and the cards
## are offered only in Gun runs. Mechanics only: no bot, no balance (owner P1).

const TICKS := 360

var _repo: ContentRepository


func before_all() -> void:
	_repo = AttackScenario.repo()


## A run's world on floor 1 with the shipped wand (4 slots), items and abilities.
func _world(build: StringName = &"gun") -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(5, t)
	w.floor_index = 1
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _it(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


func _bolt(ids: Array) -> AttackSpec:
	return Modifiers.bolt(WandLab.fight(&"gun", ids))


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	for k in s.hooks:
		if k.id == id:
			return k
	return null


func _fight(ids: Array) -> Dictionary:
	return WandLab.run(WandLab.fight(&"gun", ids), TICKS)


# --- Order ------------------------------------------------------------------------------------------------------
func test_big_split_is_a_big_shot_with_normal_shards_split_big_makes_big_shards() -> void:
	var plain := _bolt([])
	var a := _bolt([&"gun_big_shot", &"split_shot"])
	var b := _bolt([&"split_shot", &"gun_big_shot"])
	assert_almost_eq(a.radius_m, plain.radius_m * 2.0, 1e-5, "Big·Split: the shot is big")
	assert_almost_eq(b.radius_m, plain.radius_m * 2.0, 1e-5, "Split·Big: so is this one")
	var sa := _hook(a, &"split_shot").child
	var sb := _hook(b, &"split_shot").child
	assert_almost_eq(sa.radius_m, 0.08, 1e-5, "Big·Split: the shards are the card's half size")
	assert_almost_eq(sb.radius_m, 0.16, 1e-5, "Split·Big: Big reaches the shards built to its left")
	assert_eq([sa.damage_mul_permille, sb.damage_mul_permille], [1000, 1600])
	var fa := _fight([&"gun_big_shot", &"split_shot"])
	var fb := _fight([&"split_shot", &"gun_big_shot"])
	assert_ne(fa["digest"], fb["digest"], "the two orders fight differently")
	for f: Dictionary in [fa, fb]:
		assert_gt(int((f["hits_by_effect"] as Dictionary).get(&"split_shot", 0)), 0, "shards land")


func test_spread_homing_is_the_same_either_way_split_homing_is_not() -> void:
	# Two cards that both rewrite the one bolt commute (a fan of seeking bolts both ways); a card that builds a child
	# (Split) makes the order matter: Homing reaches the shards only from its right.
	var a := _bolt([&"gun_spread", &"gun_homing"])
	var b := _bolt([&"gun_homing", &"gun_spread"])
	assert_eq(
		[a.count, a.spread, a.homing], [b.count, b.spread, b.homing], "a fan of seeking bolts"
	)
	assert_eq(a.count, 3)
	assert_gt(a.homing, 0)
	var fa := _fight([&"gun_spread", &"gun_homing"])
	var fb := _fight([&"gun_homing", &"gun_spread"])
	assert_eq(fa["digest"], fb["digest"], "the same fight's events")
	var c := _bolt([&"split_shot", &"gun_homing"])
	var d := _bolt([&"gun_homing", &"split_shot"])
	assert_gt(_hook(c, &"split_shot").child.homing, 0, "Split·Homing: the shards seek")
	assert_eq(_hook(d, &"split_shot").child.homing, 0, "Homing·Split: only the shot does")
	assert_ne(
		_fight([&"split_shot", &"gun_homing"])["digest"],
		_fight([&"gun_homing", &"split_shot"])["digest"]
	)


func test_split_spread_fans_the_shards_spread_split_splits_the_fan() -> void:
	var a := _bolt([&"gun_spread", &"split_shot"])
	var b := _bolt([&"split_shot", &"gun_spread"])
	assert_eq([a.count, _hook(a, &"split_shot").child.count], [3, 3], "a fan, each splitting in 3")
	assert_eq([b.count, _hook(b, &"split_shot").child.count], [3, 5], "a fan whose shards fan in 5")


func test_a_trigger_cuts_the_gun_cards_too() -> void:
	# Big · ON HIT · Spread: a big shot whose hits cast a small fan; Spread · ON HIT · Big: a fan whose hits cast a big
	# small bolt.
	var a := _bolt([&"gun_big_shot", &"trigger_on_hit", &"gun_spread"])
	var b := _bolt([&"gun_spread", &"trigger_on_hit", &"gun_big_shot"])
	var ca := _hook(a, &"trigger_on_hit").child
	var cb := _hook(b, &"trigger_on_hit").child
	assert_eq([a.count, ca.count], [1, 3], "the shot is one, its child a fan")
	assert_eq([b.count, cb.count], [3, 1], "the shot a fan, its child one")
	assert_gt(a.radius_m, b.radius_m, "Big left of the cut: the shot is big")
	assert_gt(cb.radius_m, ca.radius_m, "Big right of it: the child is")
	assert_ne(
		_fight([&"gun_big_shot", &"trigger_on_hit", &"gun_spread"])["digest"],
		_fight([&"gun_spread", &"trigger_on_hit", &"gun_big_shot"])["digest"]
	)


func test_mine_then_split_vs_split_then_mine() -> void:
	# Split·Mine: the shards become mines too; Mine·Split: only the shot waits.
	var a := _bolt([&"split_shot", &"gun_mine"])
	var b := _bolt([&"gun_mine", &"split_shot"])
	assert_gt(_hook(a, &"split_shot").child.mine_ticks, 0)
	assert_eq(_hook(b, &"split_shot").child.mine_ticks, 0)
	assert_gt(b.mine_ticks, 0)


# --- Levels -------------------------------------------------------------------------------------------------------
func test_a_duplicate_levels_the_card_up_without_a_slot() -> void:
	var w := _world()
	var k := _it(w, &"gun_spread")
	assert_true(BuildSlots.take(w, k))
	assert_eq([CardLevels.level(w, k), w.mod_slots.size()], [1, 1])
	assert_false(BuildSlots.needs_swap(w, k), "a held card never needs a swap")
	var h := w.state_hash()
	assert_true(BuildSlots.take(w, k))
	assert_eq([CardLevels.level(w, k), w.mod_slots.size()], [2, 1], "level 2, the same one slot")
	assert_ne(w.state_hash(), h, "the level is hashed")
	var s := Modifiers.bolt(w)
	# v0.8.0 MR (O91): +2 shots at level 1, +1 a level after
	assert_eq([s.count, s.spread], [4, ContentCompiler.degrees_to_units(40.0)], "+1 shot, +10°")
	assert_eq(int((Wand.read(w)["cards"] as Array)[0]["level"]), 2, "the wand reads the level")


func test_levels_stop_at_five_and_the_card_leaves_the_offers() -> void:
	var w := _world()
	var k := _it(w, &"gun_pierce")
	assert_has(ItemPool.available(w), k, "offered")
	BuildSlots.take(w, k)
	assert_has(ItemPool.available(w), k, "held below level 5: its level-up is offered")
	assert_true(Shop.can_apply(w, k), "the shop sells the level-up")
	for n in 6:
		BuildSlots.take(w, k)
	assert_eq(CardLevels.level(w, k), CardLevels.MAX_LEVEL)
	assert_eq(Modifiers.bolt(w).pierce, 2 + 4, "+1 a level")
	assert_does_not_have(ItemPool.available(w), k, "at level 5 it's no longer offered")
	assert_false(Shop.can_apply(w, k))
	var old := _it(w, &"splinter_shot")  # v0.6.5 WN5a: Ember Core is S1 Fire now (it levels)
	BuildSlots.take(w, old)
	assert_does_not_have(ItemPool.available(w), old, "a card without levels still leaves once held")


func test_each_gun_card_grows_with_its_level() -> void:
	# The level's step per card (per_level in its data): level 3 against level 1 on the compiled bolt.
	var grows := {
		&"gun_big_shot": [&"damage_mul_permille", 1600, 1800],
		# v0.8.0 MR (O91): Rapid Fire's ramp cap grows (its base rate doesn't); Twin's lane share and Spread's +1
		&"gun_rapid_fire": [&"ramp_cap_permille", 600, 900],
		&"gun_twin": [&"share_permille", 600, 700],
		&"gun_spread": [&"count", 3, 5],
		&"gun_pierce": [&"pierce", 2, 4],
		&"gun_ricochet": [&"bounces", 2, 4],
		&"gun_spiral": [&"damage_mul_permille", 1000, 1200],
		&"gun_mine": [&"mine_ticks", 180, 240],
		&"gun_charge": [&"hold_permille", 3000, 3500],
		&"gun_echo": [&"repeat_damage_permille", 500, 600],
		&"gun_backfire": [&"damage_mul_permille", 1000, 1200],
		&"boomerang": [&"damage_mul_permille", 1000, 1200],
		&"orbit_rounds": [&"damage_mul_permille", 1000, 1200],
		&"halo_shot": [&"count", 3, 5],
	}
	for id: StringName in grows:
		var g: Array = grows[id]
		var w := _world()
		var k := _it(w, id)
		BuildSlots.take(w, k)
		assert_eq(Modifiers.bolt(w).get(g[0]), g[1], "%s at level 1" % id)
		BuildSlots.take(w, k)
		BuildSlots.take(w, k)
		assert_eq(Modifiers.bolt(w).get(g[0]), g[2], "%s at level 3" % id)
	var w := _world()
	var hm := _it(w, &"gun_homing")
	BuildSlots.take(w, hm)
	var turn := Modifiers.bolt(w).homing
	BuildSlots.take(w, hm)
	assert_gt(Modifiers.bolt(w).homing, turn, "Homing turns harder")
	var sp := _it(w, &"split_shot")
	BuildSlots.take(w, sp)
	BuildSlots.take(w, sp)
	assert_eq(_hook(Modifiers.bolt(w), &"split_shot").child.count, 4, "Split: +1 shard a level")
	var mn := _world()
	var m := _it(mn, &"gun_mine")
	BuildSlots.take(mn, m)
	BuildSlots.take(mn, m)
	assert_eq(
		_hook(Modifiers.bolt(mn), &"gun_mine").damage_permille, 1100, "the mine's blast +10 %"
	)


func test_levels_travel_with_the_carry_and_a_snapshot() -> void:
	var w := _world()
	var k := _it(w, &"gun_big_shot")
	for n in 3:
		BuildSlots.take(w, k)
	var carry := RunCarry.take(w, 0)
	var next := _world()
	RunCarry.apply(next, carry)
	Abilities.start_floor(next)
	assert_eq(CardLevels.level(next, k), 3, "into the next floor")
	assert_eq(Modifiers.bolt(next).damage_mul_permille, 1800)
	for t in 30:
		w.step(AttackScenario.frame(t))
	var snap := w.to_snapshot()
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(CardLevels.level(base, k), 3)
	assert_eq(base.state_hash(), w.state_hash(), "equal hashes")
	for t in range(30, 120):
		w.step(AttackScenario.frame(t))
		base.step(AttackScenario.frame(t))
	assert_eq(base.state_hash(), w.state_hash(), "and they play on the same")


func test_a_snapshot_mid_charge_and_with_waiting_mines_plays_on_the_same() -> void:
	var w := WandLab.fight(&"gun", [&"gun_charge", &"gun_mine", &"gun_spiral"])
	for t in 200:
		w.step(AttackScenario.frame(t))
	var snap := w.to_snapshot()
	var base := WandLab.fight(&"gun", [&"gun_charge", &"gun_mine", &"gun_spiral"])
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.state_hash(), w.state_hash())
	for t in range(200, 420):
		w.step(AttackScenario.frame(t))
		base.step(AttackScenario.frame(t))
	assert_eq(base.state_hash(), w.state_hash())


func test_catch_up_counts_a_cards_levels() -> void:
	var w := _world()
	w.catch_up_table = CatchUpTable.new()
	var k := _it(w, &"gun_twin")
	BuildSlots.take(w, k)
	var one := CatchUp.power(w)
	BuildSlots.take(w, k)
	assert_gt(CatchUp.power(w), one, "a level-up is power")


# --- The pool -----------------------------------------------------------------------------------------------------
func test_the_gun_cards_are_offered_only_in_gun_runs() -> void:
	var gun_pool := CardPoolSurvey.pool(_repo, &"gun")[0]
	var blade_pool := CardPoolSurvey.pool(_repo, &"blade")[0]
	for id: String in [
		"gun_big_shot",
		"gun_rapid_fire",
		"gun_twin",
		"gun_spread",
		"split_shot",
		"gun_pierce",
		"gun_ricochet",
		"gun_homing",
		"boomerang",
		"orbit_rounds",
		"gun_spiral",
		"gun_mine",
		"gun_charge",
		"gun_echo",
		"gun_backfire",
		"halo_shot",
	]:
		assert_has(gun_pool, "mod:" + id, "%s in the Gun's pool" % id)
		assert_does_not_have(blade_pool, "mod:" + id, "%s never in the Blade's" % id)
	for id: String in ["seeker", "twin_cast", "rearguard"]:
		# v0.6.5 WN5b: retired (WAND.md: → G8, G14, G15 on the Gun; Twin Cast → B5 on the Blade): in no pool.
		assert_does_not_have(blade_pool, "mod:" + id, "%s retired" % id)
		assert_does_not_have(gun_pool, "mod:" + id)
	var b := _world(&"blade")
	assert_false(ItemPool.usable(b, _it(b, &"gun_big_shot")))
	assert_does_not_have(ItemPool.available(b), _it(b, &"gun_big_shot"))
