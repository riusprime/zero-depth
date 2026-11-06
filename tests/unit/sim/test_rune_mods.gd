extends GutTest
## v0.9.5 FC5 (FORM_COMBOS.md R1-R9): what nine cards do to the Rune Explosion form (RuneMods), one test a row with the
## table's numbers. The plain burst grows 0 to 3.5 m over 21 ticks round the hero (at the origin, aim +x), every 66
## ticks; the dummies stand still (radius 0.35). D is one plain burst's hit on a dummy.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const RUNE := &"gun_rune_explosion"

var _d := 0


## D: one plain burst's hit on a dummy 2 m out (measured once).
func _hit() -> int:
	if _d == 0:
		var w := _world([], [Vector2(2.0, 0.0)])
		W.run(w, 1, 0, W.S)
		W.run(w, 40, 0, 0)
		_d = _dealt(w, 1)[1]
	return _d


func _world(cards: Array, at: Array = []) -> World:
	var ids: Array = [RUNE]
	ids.append_array(cards)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, 0.35, HP)
	if not at.is_empty():
		W.run(w, 1, 0, 0)  # the actor grid takes the dummies in
	return w


## [hits, total] the player dealt on actor index `idx`.
func _dealt(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var n := 0
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			n += 1
			total += e.amount
	return [n, total]


func _amounts(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append(e.amount)
	return out


func _ticks(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append(e.tick)
	return out


func _rows(w: World, kind: int) -> int:
	var n := 0
	for k in w.mx.rm_kind.size():
		if w.mx.rm_kind[k] & RuneMods.KIND_MASK == kind:
			n += 1
	return n


### Runs `n` ticks holding SHOOT; the distinct ticks bursts were born on (waiting ones too), in order.
func _births(w: World, n: int) -> Array:
	var out := []
	for t in n:
		W.run(w, 1, 0, W.S)
		for b in w.mx.rune_born:
			if not out.has(b):
				out.append(b)
	return out


# One shot at tick 0 then `rest` ticks of nothing.
func _one(w: World, rest: int) -> void:
	W.run(w, 1, 0, W.S)
	W.run(w, rest, 0, 0)


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_burst_has_none() -> void:
	assert_eq(RuneMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in RuneMods.CARD_IDS.size():
		var w := _world([RuneMods.CARD_IDS[k]])
		var s := Modifiers.bolt(w)
		assert_eq(RuneMods.mask(s), RuneMods.CARD_BITS[k], "%s" % RuneMods.CARD_IDS[k])
		assert_eq(
			[s.rune_mm, s.rune_ticks, s.period_ticks], [3500, 21, 66], "generic ops are skipped"
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % RuneMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in RuneMods.DEFAULTS:
		assert_eq(RuneMods.param(w, k), int(RuneMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"rune_explosion"))
	var keys := RuneMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.RUNE_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_row_allows_the_nine_cards_and_keeps_seven_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in [&"gun_twin"] + RuneMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [
		&"halo_shot",
		&"gun_backfire",
		&"gun_pierce",
		&"orbit_rounds",
		&"gun_spiral",
		&"gun_swirl",
		&"gun_threadline"
	]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_a_plain_burst_leaves_no_state_and_its_rows_go_with_the_form() -> void:
	var w := _world([], [Vector2(2.0, 0.0)])
	W.run(w, 300, 0, W.S)
	assert_false(w.mx.rm_touched())
	assert_eq(w.mx.rm_next, 0)
	_rows_are_dropped_when_the_shot_is_no_rune_burst_any_more()


# --- R1 Twin ----------------------------------------------------------------------------------------------------------
func test_r1_twin_a_second_shield_at_70_percent_radius_and_damage_12_ticks_after() -> void:
	var w := _world([&"gun_twin"], [Vector2(1.5, 0.0)])
	W.run(w, 1, 0, W.S)
	assert_eq(w.mx.rune_uid.size(), 2)
	assert_eq(w.mx.rune_born[1] - w.mx.rune_born[0], 12)
	assert_almost_eq(w.mx.rune_radius[1], 3.5 * 0.7, 0.001)
	assert_eq(w.mx.rune_damage[1], (w.mx.rune_damage[0] * 700 + 500) / 1000)


# --- R2 Ring ----------------------------------------------------------------------------------------------------------
func test_r2_ring_holds_48_ticks_at_full_size_hitting_each_enemy_once_more_at_full_damage() -> void:
	var w := _world([&"gun_ring"], [Vector2(2.0, 0.0), Vector2(0.0, 3.0), Vector2(5.0, 0.0)])
	W.run(w, 1, 0, W.S)
	W.run(w, 21, 0, 0)  # age 21: the burst is full
	assert_eq(_rows(w, RuneMods.K_HOLD), 1, "a ring holds")
	var k := w.mx.rm_kind.find(RuneMods.K_HOLD)
	assert_eq(w.mx.rm_life[k], 48)
	assert_eq(w.mx.rm_r[k], 3500)
	W.run(w, 20, 0, 0)
	assert_eq(_rows(w, RuneMods.K_HOLD), 1, "still held")
	W.run(w, 40, 0, 0)
	assert_eq(_rows(w, RuneMods.K_HOLD), 0, "gone after 48 ticks")
	for idx in [1, 2]:
		assert_eq(
			_amounts(w, idx), [_hit(), _hit()], "enemy %d: the burst and the ring, once each" % idx
		)
	assert_eq(_dealt(w, 3)[0], 0, "past the reach")


# --- R3 Ricochet ------------------------------------------------------------------------------------------------------
func test_r3_ricochet_shrinks_back_over_21_ticks_hitting_each_enemy_once_more_at_half() -> void:
	var w := _world([&"gun_ricochet"], [Vector2(2.0, 0.0), Vector2(0.0, 3.0)])
	W.run(w, 1, 0, W.S)
	W.run(w, 21, 0, 0)
	assert_eq(_rows(w, RuneMods.K_SHRINK), 1)
	assert_eq(w.mx.rm_life[w.mx.rm_kind.find(RuneMods.K_SHRINK)], 21)
	W.run(w, 40, 0, 0)
	assert_eq(_rows(w, RuneMods.K_SHRINK), 0, "gone")
	for idx in [1, 2]:
		var a := _amounts(w, idx)
		assert_eq(a.size(), 2, "enemy %d: grown over, shrunk past" % idx)
		assert_eq(a[1], (_hit() * 500 + 500) / 1000, "half")
	var t1: int = _ticks(w, 1)[1]
	var t2: int = _ticks(w, 2)[1]
	assert_gt(t1, 21, "after the full size")
	assert_gt(t1, t2, "the far one is passed first on the way in")


# --- R4 Homing --------------------------------------------------------------------------------------------------------
func test_r4_homing_centres_the_burst_on_the_nearest_enemy_within_6_m() -> void:
	var w := _world([&"gun_homing"], [Vector2(5.0, 0.0), Vector2(-4.0, 0.0), Vector2(-6.5, 0.0)])
	W.run(w, 1, 0, W.S)
	var q := w.mx.rm_kind.find(RuneMods.K_BURST | RuneMods.F_FIXED)
	assert_gte(q, 0, "a fixed burst")
	assert_eq(w.mx.rm_at[q], Vector2(-4.0, 0.0), "on the nearest (4 m)")
	W.run(w, 60, 0, 0)
	assert_eq(_dealt(w, 2)[0], 1, "the target is hit")
	assert_eq(_dealt(w, 3)[0], 1, "and the one beside it, past the hero's own reach")
	assert_eq(_dealt(w, 1)[0], 0, "the far one is not (9 m from the target)")


func test_r4_homing_a_tie_takes_the_lowest_index_and_none_in_range_stays_on_the_hero() -> void:
	var w := _world([&"gun_homing"], [Vector2(3.0, 0.0), Vector2(-3.0, 0.0)])
	W.run(w, 1, 0, W.S)
	assert_eq(w.mx.rm_at[w.mx.rm_kind.find(RuneMods.K_BURST | RuneMods.F_FIXED)], Vector2(3.0, 0.0))
	var o := _world([&"gun_homing"], [Vector2(7.0, 0.0)])
	W.run(o, 1, 0, W.S)
	assert_eq(o.mx.rm_kind.size(), 0, "no row: it is on the hero")
	assert_eq(RuneExplosion.read(o)[0]["pos"], o.player_pos())


# --- R5 Echo ----------------------------------------------------------------------------------------------------------
func test_r5_echo_bursts_again_36_ticks_later_at_60_percent_and_starts_no_follow_ups() -> void:
	var w := _world([&"gun_echo", &"gun_ring"], [Vector2(2.0, 0.0)])
	var b := w.tick
	W.run(w, 1, 0, W.S)
	assert_eq(w.mx.rune_born, PackedInt32Array([b, b + 36]), "the echo is queued 36 ticks after")
	var r := WorldReader.new(w)
	assert_eq(r.rune_effects()["glyphs"].size(), 1, "a glyph waits where it burst")
	W.run(w, 100, 0, 0)
	var a := _amounts(w, 1)
	assert_eq(a.size(), 3, "burst, ring, echo")
	assert_eq(a[2], (_hit() * 600 + 500) / 1000, "60 %")
	assert_eq(w.mx.rune_born.size(), 0, "all over")
	assert_eq(_rows(w, RuneMods.K_HOLD), 0)
	assert_eq(
		w.mx.rm_next, 2, "one ring (the burst's) and the echo's meta, none from the echo burst"
	)


# --- R6 Big Shot ------------------------------------------------------------------------------------------------------
func test_r6_big_shot_is_5_m_for_160_percent_every_90_ticks() -> void:
	var w := _world([&"gun_big_shot"], [Vector2(4.5, 0.0)])
	W.run(w, 1, 0, W.S)
	assert_almost_eq(w.mx.rune_radius[0], 5.0, 0.001)
	var b := _births(w, 230)
	assert_gte(b.size(), 3)
	assert_eq(b[1] - b[0], 90, "the period")
	assert_eq(_amounts(w, 1)[0], (_hit() * 1600 + 500) / 1000, "x1.6")
	assert_eq(Modifiers.bolt(w).period_ticks, 66, "the spec's own period stays")
	assert_eq(ItemEffects.shot_period_ticks(w), 90)


# --- R7 Rapid Fire ----------------------------------------------------------------------------------------------------
func test_r7_rapid_fire_is_2_5_m_for_70_percent_every_42_ticks() -> void:
	var w := _world([&"gun_rapid_fire"], [Vector2(2.0, 0.0), Vector2(3.0, 0.0)])
	W.run(w, 1, 0, W.S)
	assert_almost_eq(w.mx.rune_radius[0], 2.5, 0.001)
	var b := _births(w, 130)
	assert_eq(_dealt(w, 2)[0], 0, "3 m is out of reach")
	assert_gte(b.size(), 3)
	assert_eq(b[1] - b[0], 42)
	assert_eq(_amounts(w, 1)[0], (_hit() * 700 + 500) / 1000, "x0.7")
	assert_eq(ItemEffects.shot_period_ticks(w), 42)


# --- R8 Split ---------------------------------------------------------------------------------------------------------
func test_r8_split_throws_two_shards_at_plus_and_minus_30_degrees_for_25_percent_over_4_m() -> void:
	# The enemy at 2 m throws shards from itself along 30 and -30 degrees about the +x direction; 3 m along each:
	# beyond the burst's own reach (4.83 m from the hero), inside the shards' 4 m.
	var c := 0.866025
	var w := _world(
		[&"split_shot"],
		[Vector2(2.0, 0.0), Vector2(2.0 + 3.0 * c, 1.5), Vector2(2.0 + 3.0 * c, -1.5)]
	)
	W.run(w, 1, 0, W.S)
	W.run(w, 12, 0, 0)
	assert_eq(_rows(w, RuneMods.K_SHARD), 2, "two shards")
	W.run(w, 60, 0, 0)
	assert_eq(_rows(w, RuneMods.K_SHARD), 0, "spent")
	for idx in [2, 3]:
		assert_eq(
			_amounts(w, idx), [(_hit() * 250 + 500) / 1000], "enemy %d: one shard hit, 25 %%" % idx
		)
	assert_eq(_dealt(w, 1)[0], 1, "the source takes only the burst")


func test_r8_no_more_than_24_shards_are_live() -> void:
	# Fourteen enemies on a 2 m ring are all reached on one tick: 28 shards asked for, 24 allowed.
	var at: Array = []
	for k in 14:
		var a := TAU * k / 14.0
		at.append(Vector2(2.0 * cos(a), 2.0 * sin(a)))
	var w := _world([&"split_shot"], at)
	var most := 0
	for t in 40:
		W.run(w, 1, 0, W.S if t == 0 else 0)
		most = maxi(most, _rows(w, RuneMods.K_SHARD))
	assert_eq(most, 24, "capped")
	_shard_ends_after_its_4_m()


func _shard_ends_after_its_4_m() -> void:
	var o := _world([&"split_shot"], [Vector2(2.0, 0.0)])
	_one(o, 13)
	var k := o.mx.rm_kind.find(RuneMods.K_SHARD)
	assert_gte(k, 0, "shards fly")
	assert_gt(RuneMods.shard_pos(o, k).distance_to(Vector2(2.0, 0.0)), 0.0)
	W.run(o, 40, 0, 0)
	assert_eq(_rows(o, RuneMods.K_SHARD), 0, "gone after the 4 m")


# --- R9 Mine ----------------------------------------------------------------------------------------------------------
func test_r9_mine_waits_240_ticks_and_the_first_enemy_within_0_6_m_sets_off_a_2_m_burst() -> void:
	var w := _world([&"gun_mine"], [])
	W.run(w, 1, 0, W.S)
	assert_eq(_rows(w, RuneMods.K_MINE), 1, "a trap where it burst")
	var k := w.mx.rm_kind.find(RuneMods.K_MINE)
	assert_eq(w.mx.rm_life[k], 240)
	assert_eq(w.mx.rm_at[k], w.player_pos())
	W.run(w, 40, 0, 0)  # the burst is over
	w.add_dummy(Vector2(1.5, 0.0), 0.35, HP)
	W.run(w, 5, 0, 0)
	assert_eq(_rows(w, RuneMods.K_MINE), 1, "not yet: the edge is 1.15 m off, past the 0.6 m")
	w.actors.set_pos(1, Vector2(0.9, 0.0))  # the edge is 0.55 m off
	W.run(w, 2, 0, 0)
	assert_eq(_rows(w, RuneMods.K_MINE), 0, "set off")
	W.run(w, 40, 0, 0)
	assert_eq(_amounts(w, 1), [_hit()], "a burst at 100 %")
	# An enemy 1.9 m off the trap is inside the 2 m burst (2.0 m plus its radius) though the burst is not its trigger.
	var v := _world([&"gun_mine"], [])
	W.run(v, 1, 0, W.S)
	W.run(v, 40, 0, 0)
	v.add_dummy(Vector2(0.55, 0.0), 0.35, HP)
	v.add_dummy(Vector2(1.9, 0.0), 0.35, HP)
	W.run(v, 60, 0, 0)
	assert_eq(_dealt(v, 2)[0], 1, "the 2 m burst reaches it")
	_mine_ends_after_240_ticks()


func _mine_ends_after_240_ticks() -> void:
	var w := _world([&"gun_mine"], [])
	W.run(w, 1, 0, W.S)
	W.run(w, 238, 0, 0)
	assert_eq(_rows(w, RuneMods.K_MINE), 1)
	W.run(w, 3, 0, 0)
	assert_eq(_rows(w, RuneMods.K_MINE), 0)


func test_r9_at_most_four_live_traps_the_oldest_ending_first() -> void:
	var w := _world([&"gun_mine", &"gun_rapid_fire"], [])
	var firsts := []
	for t in 260:
		W.run(w, 1, 0, W.S)
		var n := _rows(w, RuneMods.K_MINE)
		assert_lte(n, 4)
		if firsts.is_empty() and n > 0:
			firsts.append(w.mx.rm_id[w.mx.rm_kind.find(RuneMods.K_MINE)])
	assert_eq(_rows(w, RuneMods.K_MINE), 4, "four alive")
	assert_ne(w.mx.rm_id[w.mx.rm_kind.find(RuneMods.K_MINE)], firsts[0], "the oldest ended")


# --- Bounds, determinism, saves ---------------------------------------------------------------------------------------
func test_no_card_throws_projectiles_so_the_shot_cap_is_not_touched() -> void:
	var cards: Array = [
		&"gun_twin", &"gun_ring", &"gun_echo", &"split_shot", &"gun_mine", &"gun_rapid_fire"
	]
	var w := _world(cards, [Vector2(2.0, 0.0), Vector2(1.0, 1.0), Vector2(-2.0, 1.0)])
	var most := 0
	var bursts := 0
	for t in 400:
		W.run(w, 1, 0, W.S)
		most = maxi(most, w.projectiles.size())
		bursts = maxi(bursts, w.mx.rune_uid.size())
	assert_eq(most, 0, "no projectile")
	assert_lte(bursts, RuneMods.BURSTS_MAX)
	assert_lte(w.mx.rm_kind.size(), RuneMods.ROWS_MAX)


func test_each_enemy_is_hit_at_most_once_by_a_ring_or_a_shrink() -> void:
	var w := _world([&"gun_ring", &"gun_ricochet"], [Vector2(2.0, 0.0)])
	_one(w, 120)
	assert_eq(_dealt(w, 1)[0], 3, "burst, ring, shrink: once each")


func test_a_card_burst_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(2.0, 1.0), Vector2(3.0, -1.0), Vector2(-3.0, 2.0), Vector2(1.0, 2.0)]
	var cards := [&"gun_twin", &"gun_homing", &"gun_echo", &"gun_ring", &"split_shot", &"gun_mine"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 75, 0, W.S)
	W.run(b, 75, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.rm_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.rm_at, a.mx.rm_at)
	assert_eq(c.mx.rm_kind, a.mx.rm_kind)
	assert_eq(c.mx.rm_hit_foe, a.mx.rm_hit_foe)
	W.run(a, 150, 0, W.S)
	W.run(c, 150, 0, W.S)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_an_older_save_without_the_rows_loads_and_keeps_its_digest() -> void:
	var a := _world([&"gun_twin"], [Vector2(2.0, 0.0)])
	W.run(a, 10, 0, W.S)
	var hash_before := a.state_hash()
	var snap := WorldSnapshot.take(a)
	_strip(snap)
	var c := _world([&"gun_twin"], [Vector2(2.0, 0.0)])
	assert_eq(WorldSnapshot.apply(c, snap), "", "an older save loads")
	assert_false(c.mx.rm_touched())
	assert_eq(c.state_hash(), hash_before, "the same digest: the rows are unset, so unhashed")


func _strip(v: Variant) -> void:
	if v is Dictionary:
		for k in (v as Dictionary).keys():
			if String(k).begins_with("rm_"):
				(v as Dictionary).erase(k)
			else:
				_strip((v as Dictionary)[k])
	elif v is Array:
		for e in v:
			_strip(e)


func _rows_are_dropped_when_the_shot_is_no_rune_burst_any_more() -> void:
	var w := _world([&"gun_mine"], [])
	W.run(w, 10, 0, W.S)
	assert_true(w.mx.rm_touched())
	Shop.remove_item(w, W.item(w, RUNE))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.rm_touched())
