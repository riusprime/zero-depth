# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 FC8 (FORM_COMBOS.md W1-W8): what eight cards do to the Wave form (WaveMods), one test a row with the table's
## numbers. A plain wave deals 30 a hit, rolls 0.1 m a tick for 108 ticks (10.8 m) from 0.65 m out, is 3 m wide
## (1.5 m a side, 0.5 m deep), and is thrown every 54 ticks; aim 0 is +x, the hero stands at the origin, the dummies are
## 0.35 m wide. A dummy 4 m out takes its hit on tick 28 of the throw.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
## Ticks after a throw for a wave (and its echo) to roll its whole run.
const RUN := 150


func _world(cards: Array, at: Array = [], r: float = 0.35) -> World:
	var ids: Array = [&"gun_wave"]
	ids.append_array(cards)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


## One throw (SHOOT held one tick), then `rest` ticks.
func _throw(w: World, rest: int = 0) -> void:
	W.run(w, 1, 0, W.S)
	W.run(w, rest, 0, 0)


## The direct hits the player landed on actor `idx`: [[tick, amount], ...].
func _hits(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append([e.tick, e.amount])
	return out


func _waves(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if WaveShots.is_wave_projectile(w, i):
			out.append(i)
	return out


func _pos(w: World, i: int) -> Vector2:
	return Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])


func _vel(w: World, i: int) -> Vector2:
	return Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i])


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_wave_has_none() -> void:
	assert_eq(WaveMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in WaveMods.CARD_IDS.size():
		var w := _world([WaveMods.CARD_IDS[k]])
		var s := Modifiers.bolt(w)
		assert_eq(WaveMods.mask(s), WaveMods.CARD_BITS[k], "%s" % WaveMods.CARD_IDS[k])
		assert_eq(
			[s.wave_mm, s.period_ticks, s.life_ticks, s.homing, s.spiral, s.bounces],
			[3000, 54, 108, 0, 0, 0],
			"its generic ops are skipped (%s)" % WaveMods.CARD_IDS[k]
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % WaveMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in WaveMods.DEFAULTS:
		assert_eq(WaveMods.param(w, k), int(WaveMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"wave"))
	var keys := WaveMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.WAVE_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_wave_row_allows_the_eight_cards_and_keeps_six_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in WaveMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [&"gun_twin", &"gun_backfire"]:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s stays on" % id)
	for id in [
		&"halo_shot", &"gun_ring", &"gun_pierce", &"orbit_rounds", &"gun_swirl", &"gun_threadline"
	]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_a_plain_wave_leaves_no_state() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	_throw(w, RUN)
	assert_false(w.mx.wm_touched())
	assert_eq(w.mx.wm_next, 0)
	assert_eq(_hits(w, 1), [[28, 30]], "one hit of 30 on tick 28")


# --- W1 Ricochet ------------------------------------------------------------------------------------------------------
func test_w1_ricochet_reflects_off_the_first_wall_and_rolls_back_once() -> void:
	var at := [Vector2(2.0, 0.0), Vector2(-1.5, 0.0)]
	var plain := _world([], at)
	plain.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 4.0), 0))
	_throw(plain, RUN)
	assert_eq(_hits(plain, 1).size(), 1, "the plain wave hits the near one")
	assert_eq(
		_hits(plain, 2).size(), 0, "and ends at the wall, never reaching the one behind the hero"
	)
	var w := _world([&"gun_ricochet"], at)
	w.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 4.0), 0))
	_throw(w)
	assert_eq(w.projectiles.bounces[_waves(w)[0]], 1, "one bounce")
	var turned := false
	for k in 100:
		W.run(w, 1, 0, 0)
		var ws := _waves(w)
		if ws.is_empty():
			break
		if _vel(w, ws[0]).x < 0.0:
			turned = true
			assert_eq(w.projectiles.bounces[ws[0]], 0, "the bounce is spent")
	assert_true(turned, "it rolled back off the wall")
	assert_eq(_hits(w, 1).size(), 1, "the near one is hit once (a wave hits each enemy once)")
	assert_eq(_hits(w, 2).size(), 1, "and the one behind the hero is hit on the way back")
	assert_eq(_hits(w, 2)[0][1], 30, "for the full 30")


func test_w1_ricochet_bounces_only_once() -> void:
	var w := _world([&"gun_ricochet"], [])
	w.add_wall_now(Obb.make(Vector2(3.0, 0.0), Vector2(0.2, 4.0), 0))
	w.add_wall_now(Obb.make(Vector2(-3.0, 0.0), Vector2(0.2, 4.0), 0))
	_throw(w, RUN)
	assert_true(_waves(w).is_empty(), "the second wall ends it")


# --- W2 Homing --------------------------------------------------------------------------------------------------------
func test_w2_homing_bends_toward_the_biggest_group_at_45_degrees_a_second() -> void:
	var cluster := [Vector2(6.0, 3.5), Vector2(6.6, 3.5), Vector2(6.0, 4.2)]
	var at := [Vector2(4.0, 0.0)]
	at.append_array(cluster)
	var plain := _world([], at)
	_throw(plain, RUN)
	for i in [2, 3, 4]:
		assert_eq(_hits(plain, i).size(), 0, "the plain wave misses the cluster")
	var w := _world([&"gun_homing"], at)
	_throw(w)
	assert_eq(
		w.mx.wm_aux[0],
		w.actors.ids[2] + 1,
		"it chose the first of the three, not the lone one ahead"
	)
	var start := Kin.angle_of(_vel(w, _waves(w)[0]))
	W.run(w, 10, 0, 0)
	var turned := Kin.angle_of(_vel(w, _waves(w)[0])) - start
	assert_between(turned, 70, 8 * 10 + 2, "at most 45 degrees a second (8 units a tick), 10 ticks")
	W.run(w, RUN, 0, 0)
	var got := 0
	for i in [2, 3, 4]:
		got += _hits(w, i).size()
	assert_gt(got, 0, "and the bend reaches the cluster")


func test_w2_homing_breaks_a_tie_on_the_lowest_index_and_ignores_enemies_outside_the_cone() -> void:
	var w := _world([&"gun_homing"], [Vector2(5.0, -2.5), Vector2(5.0, 2.5), Vector2(1.0, 6.0)])
	_throw(w)
	assert_eq(w.mx.wm_aux[0], w.actors.ids[1] + 1, "two alike: the lower index")
	var out := _world([&"gun_homing"], [Vector2(1.0, 6.0), Vector2(-4.0, 0.0)])
	_throw(out)
	assert_eq(
		out.mx.wm_aux[0], 0, "behind it and 80 degrees off the line are out of the 90 degree cone"
	)
	W.run(out, 20, 0, 0)
	assert_eq(Kin.angle_of(_vel(out, _waves(out)[0])), 0, "it rolls straight")


# --- W3 Echo ----------------------------------------------------------------------------------------------------------
func test_w3_echo_sends_a_second_wave_24_ticks_later_at_half_damage_and_no_more() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_throw(w, RUN)
	var hits := _hits(w, 1)
	assert_eq(hits.size(), 2, "the wave and its echo, no echo of the echo")
	assert_eq(hits[0], [28, 30])
	assert_eq(hits[1][1], 15, "50 %")
	assert_between(hits[1][0] - hits[0][0], 24, 25, "24 ticks later")


# --- W4 Big Shot ------------------------------------------------------------------------------------------------------
func test_w4_big_shot_is_5_m_wide_1_6_damage_and_a_quarter_slower() -> void:
	var wide := Vector2(4.0, 2.4)  # inside 5 m, outside 3 m
	var plain := _world([], [wide, Vector2(4.0, 0.0)])
	_throw(plain, RUN)
	assert_eq(_hits(plain, 1).size(), 0, "3 m does not reach 2.4 m off the line")
	var w := _world([&"gun_big_shot"], [wide, Vector2(4.0, 0.0)])
	_throw(w)
	var i := _waves(w)[0]
	assert_almost_eq(_vel(w, i).x, 0.075, 1e-5, "speed x 0.75")
	assert_eq(w.mx.wm_w[0], 5000, "5 m wide")
	assert_almost_eq(WaveShots.half_of(w, i), 2.5, 1e-6)
	W.run(w, RUN, 0, 0)
	assert_eq(_hits(w, 1).size(), 1, "5 m reaches it")
	assert_eq(_hits(w, 1)[0][1], 48, "30 x 1.6")
	assert_eq(_hits(w, 2)[0][1], 48)
	assert_gt(_hits(w, 2)[0][0], 28 + 8, "and it arrives later")


# --- W5 Rapid Fire ----------------------------------------------------------------------------------------------------
func test_w5_rapid_fire_is_2_m_wide_70_percent_damage_every_33_ticks() -> void:
	var off := Vector2(4.0, 1.5)  # inside 3 m, outside 2 m
	var plain := _world([], [off])
	_throw(plain, RUN)
	assert_eq(_hits(plain, 1).size(), 1)
	var w := _world([&"gun_rapid_fire"], [off, Vector2(4.0, 0.0)])
	assert_eq(ItemEffects.shot_period_ticks(w), 33, "0.55 s")
	_throw(w)
	assert_eq(w.mx.wm_w[0], 2000, "2 m wide")
	W.run(w, RUN, 0, 0)
	assert_eq(_hits(w, 1).size(), 0, "2 m does not reach 1.5 m off the line")
	assert_eq(_hits(w, 2)[0][1], 21, "30 x 0.7")
	var held := _world([&"gun_rapid_fire"], [Vector2(4.0, 0.0)])
	var base := _world([], [Vector2(4.0, 0.0)])
	W.run(held, 200, 0, W.S)
	W.run(base, 200, 0, W.S)
	assert_eq(_hits(base, 1).size(), 4, "a plain wave every 54 ticks")
	assert_eq(_hits(held, 1).size(), 6, "one every 33")


# --- W6 Split ---------------------------------------------------------------------------------------------------------
## Where the plain wave's run ends on the +x axis (the point it would split at), and the tick it ends.
func _end_of_run() -> Vector2:
	var w := _world([], [])
	_throw(w)
	var at := Vector2.ZERO
	for k in RUN:
		var ws := _waves(w)
		if ws.is_empty():
			break
		at = _pos(w, ws[0]) + _vel(w, ws[0])
		W.run(w, 1, 0, 0)
	return at


func test_w6_split_makes_two_half_width_waves_at_45_degrees_that_roll_3_m_more() -> void:
	var end := _end_of_run()
	var up := end + Kin.dir(512) * 2.0
	var down := end + Kin.dir(-512) * 2.0
	var off := end + Kin.dir(512) * 1.8 + Kin.dir(512 + 1024) * 1.2  # 1.2 m across the child's line: out of 0.75
	var far := end + Kin.dir(512) * 4.6  # past the 3 m
	var w := _world([&"split_shot"], [up, down, off, far])
	_throw(w, RUN)
	assert_eq(_hits(w, 1).size(), 1, "the upper child hits")
	assert_eq(_hits(w, 2).size(), 1, "the lower child hits")
	assert_eq(_hits(w, 1)[0][1], 15, "50 %")
	assert_eq(_hits(w, 3).size(), 0, "a child is half as wide: 1.5 m, 0.75 a side")
	assert_eq(_hits(w, 4).size(), 0, "and rolls 3 m, not more")
	assert_true(_waves(w).is_empty(), "no follow-ups: they end")
	var plain := _world([], [up, down])
	_throw(plain, RUN)
	assert_eq(
		_hits(plain, 1).size() + _hits(plain, 2).size(), 0, "a plain wave stops short of them"
	)


func test_w6_split_splits_only_once_and_not_an_echo() -> void:
	var w := _world([&"split_shot", &"gun_echo"], [])
	_throw(w)
	var most := 0
	for k in RUN + 60:
		W.run(w, 1, 0, 0)
		most = maxi(most, _waves(w).size())
	assert_lte(most, 3, "the wave and its echo overlap at most; a child splits no further")


# --- W7 Mine ----------------------------------------------------------------------------------------------------------
func test_w7_mine_stops_4_m_out_and_churns_90_ticks_then_ends() -> void:
	var w := _world([&"gun_mine"], [Vector2(7.0, 0.0)])
	_throw(w)
	var stop_tick := -1
	var stop_at := Vector2.ZERO
	for k in 100:
		W.run(w, 1, 0, 0)
		var ws := _waves(w)
		if not ws.is_empty() and _vel(w, ws[0]) == Vector2.ZERO:
			stop_tick = w.tick
			stop_at = _pos(w, ws[0])
			break
	assert_gt(stop_tick, 0, "it stopped")
	assert_almost_eq(
		(stop_at - w.mx.wm_at[0]).length(),
		4.0,
		0.11,
		"4 m out from where it left (a tick is 0.1 m)"
	)
	W.run(w, 89, 0, 0)
	assert_eq(_waves(w).size(), 1, "still churning 89 ticks on")
	assert_eq(_pos(w, _waves(w)[0]), stop_at, "in place")
	W.run(w, 2, 0, 0)
	assert_true(_waves(w).is_empty(), "gone after 90")
	assert_eq(_hits(w, 1).size(), 0, "the one at 7 m never met it")


func test_w7_mine_hits_what_walks_into_it_once() -> void:
	var w := _world([&"gun_mine"], [])
	_throw(w, 60)
	var stop := _pos(w, _waves(w)[0])
	w.add_dummy(stop + Vector2(0.3, 0.0), 0.35, HP)
	W.run(w, 60, 0, 0)
	assert_eq(_hits(w, 1).size(), 1, "the normal per-enemy rule: once, for the whole churn")
	assert_eq(_hits(w, 1)[0][1], 30)


# --- W8 Spiral --------------------------------------------------------------------------------------------------------
func test_w8_spiral_sways_08_m_a_side_with_a_one_second_period() -> void:
	var w := _world([&"gun_spiral"], [])
	_throw(w)
	var ys := []
	var xs := []
	for k in 70:
		var ws := _waves(w)
		ys.append(_pos(w, ws[0]).y)
		xs.append(_pos(w, ws[0]).x)
		W.run(w, 1, 0, 0)
	assert_almost_eq(ys.max(), 0.8, 0.03, "0.8 m to one side")
	assert_almost_eq(ys.min(), -0.8, 0.03, "0.8 m to the other")
	var first_peak := ys.find(ys.max())
	var second_peak := ys.find(ys.min())
	assert_between(second_peak - first_peak, 28, 32, "half a period between the sides")
	assert_almost_eq(ys[60], ys[0], 0.03, "one full period in 60 ticks (1.0 s)")
	assert_almost_eq(xs[60] - xs[0], 6.0, 0.05, "and it rolls on at 6 m/s")
	assert_eq(Kin.angle_of(_vel(w, _waves(w)[0])), 0, "its line is straight")


# --- The bound, the caps ----------------------------------------------------------------------------------------------
func test_at_most_8_live_waves_and_64_rows() -> void:
	var w := _world([&"gun_echo", &"gun_rapid_fire", &"gun_twin"], [])
	var most := 0
	var rows := 0
	for k in 600:
		W.run(w, 1, 0, W.S)
		most = maxi(most, _waves(w).size())
		rows = maxi(rows, w.mx.wm_kind.size())
	assert_lte(most, WaveMods.param(w, "live_max"), "at most 8 live waves")
	assert_lte(rows, WaveMods.ROWS_MAX)
	assert_gt(most, 6, "and the cap is reached")


func test_echo_and_split_children_do_not_spend_the_shot_cap() -> void:
	var base := _world([&"gun_twin", &"gun_rapid_fire"], [])
	var more := _world([&"gun_twin", &"gun_rapid_fire", &"gun_echo", &"split_shot"], [])
	W.run(base, 300, 0, W.S)
	W.run(more, 300, 0, W.S)
	assert_eq(ShotCap.last_second(more), ShotCap.last_second(base), "the same shots spent")
	assert_lte(ShotCap.last_second(more), 40, "within the 40 a second")


# --- State: determinism, save, hash -----------------------------------------------------------------------------------
func test_a_wave_with_cards_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(5.0, 0.0), Vector2(6.0, 3.0), Vector2(6.0, -3.0), Vector2(3.0, 1.5)]
	var cards := [&"gun_echo", &"gun_homing", &"gun_spiral", &"split_shot", &"gun_big_shot"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 40, 0, W.S)
	W.run(b, 40, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.wm_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.wm_at, a.mx.wm_at)
	assert_eq(c.mx.wm_kind, a.mx.wm_kind)
	assert_eq(c.mx.wm_w, a.mx.wm_w)
	W.run(a, RUN, 0, W.S)
	W.run(c, RUN, 0, W.S)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_a_plain_wave_hash_has_no_wave_block() -> void:
	var a := _world([], [Vector2(4.0, 0.0)])
	W.run(a, 50, 0, W.S)
	assert_false(a.mx.wm_touched())
	var h := StateHasher.new()
	a.mx.hash_into(h)
	var with := _world([&"gun_homing"], [Vector2(4.0, 0.0)])
	W.run(with, 50, 0, W.S)
	var h2 := StateHasher.new()
	with.mx.hash_into(h2)
	assert_ne(h.finish_hex(), h2.finish_hex(), "the rows are hashed while set")


func test_an_older_save_without_the_rows_loads_empty() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	W.run(w, 20, 0, W.S)
	assert_true(w.mx.wm_touched())
	var snap := w.to_snapshot()
	var mx: Dictionary = (snap["world"] as Dictionary)[&"mx"]
	for f: StringName in WaveMods.SNAPSHOT_FIELDS:
		assert_true(mx.has(f), "%s is saved" % f)
		mx.erase(f)
	var base := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	assert_eq(WorldSnapshot.apply(base, snap), "", "an older snapshot restores")
	assert_false(base.mx.wm_touched(), "with no Wave rows")
	W.run(base, 10, 0, 0)


func test_rows_are_dropped_when_the_shot_is_no_wave_any_more() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_throw(w, 3)
	assert_true(w.mx.wm_touched())
	Shop.remove_item(w, W.item(w, &"gun_wave"))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.wm_touched())
