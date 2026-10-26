extends GutTest
## v0.9.5 FC2 (FORM_COMBOS.md B1-B10): what ten cards do to the Bomb form (BombMods), one test a row with the table's
## numbers. The plain bomb deals 22 to the dummies (4.5 x the orb's 5), thrown at tick 0 and bursting on the first
## enemy it touches about 19 ticks later; aim 0 is +x and the hero stands at the origin.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000


func _world(cards: Array, at: Array = [Vector2(4.0, 0.0)]) -> World:
	var ids: Array = [&"gun_bomb"]
	ids.append_array(cards)
	var enemies := []
	for p: Vector2 in at:
		enemies.append([p, HP])
	return W.world(&"gun", ids, enemies)


func _blasts(w: World) -> Array[SimEvent]:
	return W.events(w, SimEvent.Kind.BLAST)


## The direct damage the player dealt to actor `idx`: [hits, total].
func _dealt(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var n := 0
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			n += 1
			total += e.amount
	return [n, total]


func _rows(w: World, kind: int) -> int:
	var n := 0
	for k in w.mx.bm_kind.size():
		if w.mx.bm_kind[k] & BombMods.KIND_MASK == kind:
			n += 1
	return n


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_bomb_has_none() -> void:
	assert_eq(BombMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in BombMods.CARD_IDS.size():
		var w := _world([BombMods.CARD_IDS[k]])
		assert_eq(
			BombMods.mask(Modifiers.bolt(w)), BombMods.CARD_BITS[k], "%s" % BombMods.CARD_IDS[k]
		)
		var s := Modifiers.bolt(w)
		assert_eq(
			[s.blast_mm, s.period_ticks, s.damage], [2200, 60, 22], "its generic ops are skipped"
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % BombMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in BombMods.DEFAULTS:
		assert_eq(BombMods.param(w, k), int(BombMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"bomb"))
	var keys := BombMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.BOMB_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")
	var laser_keys := LaserMods.DEFAULTS.keys()
	laser_keys.sort()
	var laser_content := AttackFormRow.LASER_KEYS.duplicate()
	laser_content.sort()
	assert_eq(laser_content, laser_keys)


func test_the_bomb_row_allows_the_ten_cards_and_keeps_five_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in BombMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [&"gun_pierce", &"orbit_rounds", &"gun_spiral", &"gun_swirl", &"gun_threadline"]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


# --- B1 Halo ----------------------------------------------------------------------------------------------------------
func test_b1_halo_lands_four_bombs_in_a_cross_3_m_around_the_hero() -> void:
	var at: Array = [Vector2(0.0, 3.0), Vector2(-3.0, 0.0), Vector2(0.0, -3.0)]
	var w := _world([&"halo_shot"], at)
	W.run(w, 2, 0, W.S)
	assert_eq(_rows(w, BombMods.K_DROP), 4, "four bombs wait to land")
	var spots := []
	for k in w.mx.bm_at.size():
		spots.append(w.mx.bm_at[k].snapped(Vector2(0.01, 0.01)))
	assert_true(spots.has(Vector2(3.0, 0.0)) and spots.has(Vector2(0.0, 3.0)), "the cross")
	assert_true(spots.has(Vector2(-3.0, 0.0)) and spots.has(Vector2(0.0, -3.0)), "all four")
	W.run(w, 28, 0, W.S)
	assert_eq(_rows(w, BombMods.K_DROP), 0)
	for k in [1, 2, 3]:
		assert_eq(_dealt(w, k), [1, 22], "100 %% on the enemy at the cross point %d" % k)
	for lvl in [1, 2, 3]:  # Halo's level adds nothing
		var lv := _world([&"halo_shot"], [])
		CardLevels.set_level(lv, W.item(lv, &"halo_shot"), lvl)
		W.run(lv, 2, 0, W.S)
		assert_eq(_rows(lv, BombMods.K_DROP), 4, "Lv %d: four bombs" % lvl)


# --- B2 Ring ----------------------------------------------------------------------------------------------------------
func test_b2_ring_grows_to_3_5_m_over_0_4_s_hitting_each_enemy_once_at_half() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.0), Vector2(3.3, 3.0)])
	W.run(w, 22, 0, W.S)
	assert_eq(_rows(w, BombMods.K_RING), 1, "the blast left a ring")
	var born: int = w.mx.bm_born[0]
	assert_eq(w.mx.bm_r[0], 3500, "3.5 m")
	assert_eq(w.mx.bm_due[0] - born, 24, "0.4 s")
	W.run(w, 50, 0, W.S)
	assert_eq(_rows(w, BombMods.K_RING), 0, "gone")
	assert_eq(
		_dealt(w, 2), [1, 11], "the enemy 3 m off: one ring hit, 50 % of 22, nothing from the blast"
	)
	assert_eq(_dealt(w, 1)[0], 2, "the enemy in the blast: the blast and the ring, once each")


func test_b2_ring_hits_arrive_as_it_grows() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.0), Vector2(3.3, 3.0)])
	W.run(w, 80, 0, W.S)
	var ticks := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == w.actors.ids[2]:
			ticks.append(e.tick)
	var hit_at: int = ticks[0]
	var burst_at: int = _blasts(w)[0].tick
	assert_between(hit_at - burst_at, 18, 24, "3 m of 3.5 m: about 20 of the 24 ticks")


# --- B3 Backfire ------------------------------------------------------------------------------------------------------
func test_b3_backfire_drops_a_bomb_at_the_feet_with_a_half_second_fuse() -> void:
	var w := _world([&"gun_backfire"], [Vector2(-1.5, 0.0)])
	W.run(w, 2, 0, W.S)
	assert_eq(_rows(w, BombMods.K_DROP), 1)
	assert_eq(w.mx.bm_at[0], Vector2.ZERO, "at the hero's feet")
	assert_eq(w.mx.bm_due[0] - w.mx.bm_born[0], 30, "0.5 s")
	W.run(w, 40, 0, W.S)
	assert_eq(_dealt(w, 1), [1, 22], "100 % on the enemy behind")
	var hit: int = _blasts(w)[0].tick
	assert_between(hit, 30, 33, "the drop goes off first, at the fuse's end")


# --- B4 Ricochet ------------------------------------------------------------------------------------------------------
func test_b4_ricochet_skips_2_m_further_and_a_wall_stops_the_skip() -> void:
	var plain := _world([], [])
	var skipping := _world([&"gun_ricochet"], [])
	W.run(plain, 60, 0, W.S)
	W.run(skipping, 60, 0, W.S)
	var a := _blasts(plain)[0].pos.x
	var b := _blasts(skipping)[0].pos.x
	assert_almost_eq(b - a, 2.0, 0.1, "bursts 2 m further along its travel")
	var walled := _world([&"gun_ricochet"], [])
	walled.add_wall_now(Obb.make(Vector2(9.2, 0.0), Vector2(0.2, 3.0), 0))
	W.run(walled, 70, 0, W.S)
	assert_lt(_blasts(walled)[0].pos.x, 9.0, "a wall ahead keeps the skip short")


# --- B5 Homing --------------------------------------------------------------------------------------------------------
func test_b5_homing_lands_on_the_nearest_enemy_within_3_m_of_the_aim_point() -> void:
	var w := _world([&"gun_homing"], [Vector2(8.0, 2.0), Vector2(8.5, -2.4)])
	W.run(w, 60, 0, W.S)
	var e := _blasts(w)[0]
	assert_lt(e.pos.distance_to(Vector2(8.0, 2.0)), 0.05, "on the nearest of the two")
	var far := _world([&"gun_homing"], [Vector2(8.0, 5.0)])
	W.run(far, 60, 0, W.S)
	assert_almost_eq(_blasts(far)[0].pos.x, 8.7, 0.3, "none within 3 m: where it was aimed")
	assert_almost_eq(_blasts(far)[0].pos.y, 0.0, 0.05)


# --- B6 Echo ----------------------------------------------------------------------------------------------------------
func test_b6_echo_repeats_the_blast_half_a_second_later_at_half() -> void:
	var w := _world([&"gun_echo"])
	W.run(w, 56, 0, W.S)
	var b := _blasts(w)
	assert_eq(b.size(), 2)
	assert_eq(b[1].tick - b[0].tick, 30, "0.5 s later")
	assert_eq(b[1].pos, b[0].pos, "at the same spot")
	assert_eq(_dealt(w, 1), [2, 33], "22 then 11")


# --- B7 Big Shot ------------------------------------------------------------------------------------------------------
func test_b7_big_shot_blasts_3_3_m_for_60_percent_more_thrown_slower() -> void:
	var w := _world([&"gun_big_shot"], [Vector2(4.0, 0.0), Vector2(3.3, 2.8)])
	assert_almost_eq(Bomb.radius_m(w, Modifiers.bolt(w)), 3.3, 0.001)
	W.run(w, 2, 0, W.S)
	var speed := 0.0
	for i in w.projectiles.size():
		if Bomb.touches(w, i):
			speed = Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i]).length() * 60.0
	assert_almost_eq(speed, 9.0, 0.01, "25 % slower than 12 m/s")
	W.run(w, 40, 0, W.S)
	assert_eq(_blasts(w)[0].amount, 3300)
	assert_eq(_dealt(w, 1), [1, 35], "22 x 1.6")
	assert_eq(_dealt(w, 2), [1, 35], "the enemy 2.8 m off is inside the bigger blast")


# --- B8 Rapid Fire ----------------------------------------------------------------------------------------------------
func test_b8_rapid_fire_blasts_1_6_m_every_0_6_s_within_10_percent_of_the_dps() -> void:
	var rapid := _world([&"gun_rapid_fire"])
	var plain := _world([])
	assert_eq(ItemEffects.shot_period_ticks(rapid), 36, "0.6 s")
	assert_eq(ItemEffects.shot_period_ticks(plain), 60)
	assert_almost_eq(Bomb.radius_m(rapid, Modifiers.bolt(rapid)), 1.6, 0.01)
	W.run(rapid, 600, 0, W.S)
	W.run(plain, 600, 0, W.S)
	var r := float(_dealt(rapid, 1)[1])
	var p := float(_dealt(plain, 1)[1])
	assert_between(r / p, 0.9, 1.1, "Rapid Fire's DPS %d vs plain %d" % [r, p])
	assert_eq(_blasts(rapid)[0].amount, 1600)
	assert_eq(_each(rapid), 14, "22 x 0.65, rounded down")


func _each(w: World) -> int:
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == w.actors.ids[1] and not (e.tags & SimEvent.TAG_DOT):
			return e.amount
	return 0


# --- B9 Split ---------------------------------------------------------------------------------------------------------
func test_b9_split_throws_bomblets_2_m_out_that_burst_0_3_s_later_at_40_percent() -> void:
	var w := _world([&"split_shot"], [Vector2(4.0, 0.0), Vector2(6.3, 0.0)])
	var split := W.item(w, &"split_shot")
	assert_eq(CardLevels.level(w, split), 1)
	assert_eq(BombMods.bomblet_count(Modifiers.bolt(w)), 2, "Lv 1: two")
	W.run(w, 2, 0, W.S)
	W.run(w, 48, 0, W.S)
	var b := _blasts(w)
	assert_eq(b.size(), 3, "the blast and two bomblets")
	assert_eq(b[1].tick - b[0].tick, 18, "0.3 s")
	assert_eq(b[1].amount, 1200, "1.2 m")
	assert_almost_eq(b[1].pos.distance_to(b[0].pos), 2.0, 0.05, "2 m out")
	assert_eq(_dealt(w, 2), [1, 8], "the far enemy: one bomblet, 40 % of 22")


func test_b9_splits_level_sets_two_three_or_four_bomblets() -> void:
	for lvl in [1, 2, 3]:
		var w := _world([&"split_shot"], [Vector2(4.0, 0.0)])
		CardLevels.set_level(w, W.item(w, &"split_shot"), lvl)
		assert_eq(BombMods.bomblet_count(Modifiers.bolt(w)), lvl + 1, "Lv %d" % lvl)
		W.run(w, 56, 0, W.S)
		assert_eq(_blasts(w).size(), 1 + lvl + 1, "Lv %d: bomblets" % lvl)
	var w3 := _world([&"split_shot"], [Vector2(4.0, 0.0)])
	CardLevels.set_level(w3, W.item(w3, &"split_shot"), 2)
	W.run(w3, 56, 0, W.S)
	var origin: Vector2 = _blasts(w3)[0].pos
	var spots: Array[Vector2] = []
	for k in range(1, 4):
		spots.append(_blasts(w3)[k].pos)
		assert_almost_eq(spots[k - 1].distance_to(origin), 2.0, 0.05)
	assert_almost_eq(
		spots[0].distance_to(spots[1]), 2.0 * sqrt(3.0), 0.1, "0, 120 and 240 degrees apart"
	)
	assert_almost_eq(spots[1].distance_to(spots[2]), 2.0 * sqrt(3.0), 0.1)
	assert_almost_eq(spots[0].x, origin.x + 2.0, 0.05, "the first along the aim")


# --- B10 Mine ---------------------------------------------------------------------------------------------------------
func test_b10_mine_waits_until_an_enemy_comes_within_1_5_m() -> void:
	var w := _world([&"gun_mine"], [])
	W.run(w, 50, 0, W.S)
	assert_eq(_rows(w, BombMods.K_MINE), 1, "the bomb waits where it landed")
	assert_eq(_blasts(w).size(), 0)
	var spot: Vector2 = w.mx.bm_at[0]
	w.add_dummy(spot + Vector2(0.0, 2.2), 0.35, HP)
	W.run(w, 2, 0, 0)
	assert_eq(_rows(w, BombMods.K_MINE), 1, "2.2 m off: it waits")
	w.add_dummy(spot + Vector2(0.0, 1.0), 0.35, HP)
	W.run(w, 2, 0, 0)
	assert_eq(_rows(w, BombMods.K_MINE), 0, "an enemy within 1.5 m sets it off")
	assert_eq(_blasts(w).size(), 1)
	assert_eq(_dealt(w, w.actors.size() - 1), [1, 22], "100 %")


func test_b10_mine_keeps_five_the_oldest_bursts_for_a_sixth_and_they_last_12_s() -> void:
	var w := _world([&"gun_mine"], [])
	var most := 0
	for k in 420:
		W.run(w, 1, 0, W.S)
		most = maxi(most, _rows(w, BombMods.K_MINE))
	assert_eq(most, 5, "at most five waiting")
	assert_eq(_rows(w, BombMods.K_MINE), 5)
	assert_eq(_blasts(w).size(), 2, "the 6th and 7th landing set the two oldest off")
	W.run(w, 800, 0, 0)
	assert_eq(_rows(w, BombMods.K_MINE), 0, "12 s later the rest burst anyway")
	assert_eq(_blasts(w).size(), 7)


# --- Caps, determinism, snapshots ---------------------------------------------------------------------------
func test_rows_are_capped() -> void:
	var w := _world(
		[&"halo_shot", &"gun_ring", &"gun_echo", &"split_shot", &"gun_rapid_fire"],
		[Vector2(3.0, 0.5)]
	)
	var most := 0
	for k in 600:
		W.run(w, 1, 0, W.S)
		most = maxi(most, w.mx.bm_kind.size())
	assert_lte(most, BombMods.ROWS_MAX)
	assert_gt(most, 0)


func test_a_plain_bomb_leaves_no_state() -> void:
	var w := _world([])
	W.run(w, 300, 0, W.S)
	assert_false(w.mx.bm_touched())
	assert_eq(w.mx.bm_next, 0)


func test_a_card_bomb_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(2.0, 1.0), Vector2(3.5, -1.0), Vector2(-3.0, 2.0), Vector2(5.0, 3.0)]
	var cards := [&"halo_shot", &"gun_echo", &"gun_ring", &"split_shot", &"gun_backfire"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 24, 0, W.S, 300)
	W.run(b, 24, 0, W.S, 300)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.bm_touched(), "rows are waiting")
	assert_gt(a.mx.bm_kind.size(), 0)
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.bm_at, a.mx.bm_at)
	assert_eq(c.mx.bm_hit, a.mx.bm_hit)
	W.run(a, 80, 0, W.S, 300)
	W.run(c, 80, 0, W.S, 300)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_rows_are_dropped_when_the_shot_is_no_bomb_any_more() -> void:
	var w := _world([&"gun_mine"], [])
	W.run(w, 50, 0, W.S)
	assert_eq(_rows(w, BombMods.K_MINE), 1)
	var bomb := W.item(w, &"gun_bomb")
	Shop.remove_item(w, bomb)
	W.run(w, 2, 0, 0)
	assert_false(w.mx.bm_touched())
