# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 FC6 (FORM_COMBOS.md G1-G11): what eleven cards do to the Glaive form (GlaiveMods), one test a row with the
## table's numbers. A plain disc deals 8 a pass (5 x 1.6), flies 0.2333 m a tick for 60 ticks (7 m out, then home), and
## is thrown every 42 ticks from 0.7 m out; aim 0 is +x, the hero stands at the origin, the dummies are 0.35 m wide.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
## Ticks after a throw for a disc (and its echo) to fly out and come home.
const FLY := 130


func _world(cards: Array, at: Array = [], r: float = 0.35) -> World:
	var ids: Array = [&"gun_glaive"]
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


func _total(hits: Array) -> int:
	var n := 0
	for h: Array in hits:
		n += h[1]
	return n


func _discs(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if Glaive.is_disc(w, i):
			out.append(i)
	return out


func _pos(w: World, i: int) -> Vector2:
	return Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])


func _angle(w: World, i: int) -> int:
	return Kin.angle_of(Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i]))


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_glaive_has_none() -> void:
	assert_eq(GlaiveMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in GlaiveMods.CARD_IDS.size():
		var w := _world([GlaiveMods.CARD_IDS[k]])
		var s := Modifiers.bolt(w)
		assert_eq(GlaiveMods.mask(s), GlaiveMods.CARD_BITS[k], "%s" % GlaiveMods.CARD_IDS[k])
		assert_eq(
			[s.glaive, s.period_ticks, s.life_ticks, s.homing, s.orbit_ticks, s.bounces],
			[1, 42, 60, 0, 0, 0],
			"its generic ops are skipped (%s)" % GlaiveMods.CARD_IDS[k]
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % GlaiveMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in GlaiveMods.DEFAULTS:
		assert_eq(GlaiveMods.param(w, k), int(GlaiveMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"glaive"))
	var keys := GlaiveMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.GLAIVE_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_glaive_row_allows_the_eleven_cards_and_keeps_three_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in GlaiveMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [&"gun_twin", &"gun_swirl"]:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s stays on" % id)
	for id in [&"gun_pierce", &"gun_spiral", &"gun_threadline"]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_a_plain_glaive_leaves_no_state() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	_throw(w, FLY)
	assert_false(w.mx.gm_touched())
	assert_eq(w.mx.gm_next, 0)
	assert_eq(_hits(w, 1).size(), 2, "one pass each way")


# --- G1 Halo ----------------------------------------------------------------------------------------------------------
func test_g1_halo_throws_four_discs_every_90_degrees_at_half_and_all_return() -> void:
	var w := _world(
		[&"halo_shot"],
		[Vector2(4.0, 0.0), Vector2(0.0, 4.0), Vector2(-4.0, 0.0), Vector2(0.0, -4.0)]
	)
	_throw(w)
	var d := _discs(w)
	assert_eq(d.size(), 4, "four discs")
	var angles := []
	for i in d:
		angles.append(_angle(w, i))
		assert_eq(w.projectiles.damage[i], 4, "50 % of 8")
	angles.sort()
	for k in 4:
		assert_between(angles[k], k * 1024 - 2, k * 1024 + 2, "every 90 degrees from the aim")
	W.run(w, 60, 0, 0)  # the second throw (tick 43) is not yet in reach
	for k in 4:
		assert_eq(_hits(w, k + 1).size(), 2, "enemy %d is hit going out and coming back" % k)
		assert_eq(_total(_hits(w, k + 1)), 8)
	W.run(w, 40, 0, 0)
	assert_true(w.projectiles.size() <= 4, "the first four are caught")


# --- G2 Ring ----------------------------------------------------------------------------------------------------------
func test_g2_ring_hurts_enemies_within_1_m_of_the_disc_for_40_percent() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.8)])
	_throw(w, 43)
	var h := _hits(w, 1)
	var plain := _world([], [Vector2(4.0, 0.8)])
	_throw(plain, 43)
	assert_eq(_hits(plain, 1).size(), 0, "the disc itself misses an enemy 0.8 m off its line")
	assert_eq(h.size(), 2, "the ring reaches it out and back")
	for x: Array in h:
		assert_eq(x[1], 3, "40 % of 8")
	assert_gte(h[1][0] - h[0][0], 30, "one disc's ring hits an enemy once per 30 ticks")


func test_g2_ring_hits_a_held_enemy_once_every_30_ticks() -> void:
	var w := _world([&"gun_mine", &"gun_ring"])
	_throw(w, 39)
	var hold := _pos(w, _discs(w)[0])
	w.add_dummy(hold + Vector2(0.0, 0.9), 0.35, HP)
	W.run(w, 80, 0, 0)
	var h := _hits(w, 1)
	assert_gte(h.size(), 3, "the disc spins in place and its ring keeps hitting")
	for k in range(1, h.size()):
		assert_gte(h[k][0] - h[k - 1][0], 30, "never twice inside 30 ticks")


# --- G3 Backfire ------------------------------------------------------------------------------------------------------
func test_g3_backfire_throws_a_second_disc_straight_behind_at_full_damage() -> void:
	var w := _world([&"gun_backfire"], [Vector2(-4.0, 0.0)])
	_throw(w)
	var d := _discs(w)
	assert_eq(d.size(), 2, "two discs")
	var behind := -1
	for i in d:
		if w.projectiles.vel_x[i] < 0.0:
			behind = i
	assert_gte(behind, 0, "one flies straight back")
	assert_eq(w.projectiles.damage[behind], 8, "100 %")
	assert_eq(w.projectiles.vel_y[behind], 0.0)
	W.run(w, 60, 0, 0)
	assert_eq(_hits(w, 1).size(), 2, "the disc behind hit the enemy there out and back")
	assert_eq(_total(_hits(w, 1)), 16)


func test_g3_backfire_under_halo_adds_nothing_the_disc_at_180_is_there() -> void:
	var w := _world([&"halo_shot", &"gun_backfire"])
	_throw(w)
	assert_eq(_discs(w).size(), 4)


# --- G4 Ricochet ------------------------------------------------------------------------------------------------------
func test_g4_ricochet_bounces_twice_on_the_way_out_then_it_turns_home() -> void:
	var w := _world([&"gun_ricochet"], [Vector2(3.0, 0.0)])
	w.add_wall_now(Obb.make(Vector2(6.0, 0.0), Vector2(0.2, 3.0), 0))
	_throw(w)
	var i := _discs(w)[0]
	assert_eq(w.projectiles.bounces[i], 2, "two bounces")
	var turned := false
	for k in 80:
		W.run(w, 1, 0, 0)
		var d := _discs(w)
		if d.is_empty():
			break
		if w.projectiles.vel_x[d[0]] < 0.0:
			turned = true
	assert_true(turned, "it came back off the wall")
	assert_eq(_hits(w, 1).size(), 2, "and hit the enemy going out and coming back off the wall")


func test_g4_ricochet_leaves_no_bounce_once_the_disc_turns_home() -> void:
	var w := _world([&"gun_ricochet"])
	_throw(w)
	W.run(w, 40, 0, 0)
	var i := _discs(w)[0]
	assert_true(Glaive.coming_back(w, i))
	assert_eq(w.projectiles.bounces[i], 0, "the bounces end when it turns home")


# --- G5 Homing --------------------------------------------------------------------------------------------------------
func test_g5_homing_turns_toward_the_nearest_enemy_within_6_m_at_90_degrees_a_second() -> void:
	var w := _world([&"gun_homing"], [Vector2(5.5, 1.5)])
	var plain := _world([], [Vector2(5.5, 1.5)])
	_throw(w)
	_throw(plain)
	var prev := _angle(w, _discs(w)[0])
	var most := 0
	var turned := 0
	for k in 40:
		W.run(w, 1, 0, 0)
		var d := _discs(w)
		if d.is_empty() or Glaive.coming_back(w, d[0]):
			break
		var a := _angle(w, d[0])
		most = maxi(most, Kin.angle_diff(a, prev))
		turned = maxi(turned, Kin.angle_diff(a, 0))
		prev = a
	assert_between(most, 1, 17, "at most 90 degrees a second: 17 units a tick")
	assert_gt(turned, 100, "it turned a good way toward the enemy")
	W.run(w, FLY, 0, 0)
	W.run(plain, FLY, 0, 0)
	assert_eq(_hits(plain, 1).size(), 0, "a straight disc misses an enemy 1.5 m off its line")
	assert_gte(_hits(w, 1).size(), 1, "the homing disc hits it")


func test_g5_homing_ignores_an_enemy_more_than_6_m_away() -> void:
	var w := _world([&"gun_homing"], [Vector2(5.0, 7.0)])
	_throw(w)
	W.run(w, 6, 0, 0)
	assert_eq(_angle(w, _discs(w)[0]), 0, "no enemy within 6 m: it flies straight")


func test_g5_homing_on_the_way_back_skips_the_enemy_it_chased_out() -> void:
	var w := _world([&"gun_homing"], [Vector2(5.5, 1.5)])
	_throw(w)
	W.run(w, 10, 0, 0)
	var i := _discs(w)[0]
	var chased: int = w.mx.gm_aux[0]
	assert_eq(chased, w.actors.ids[1] + 1, "the outward target is remembered (id + 1)")
	var cur := _angle(w, i)
	assert_eq(GlaiveMods._target(w, i, cur, 0), 1, "the enemy is the nearest ahead")
	assert_eq(GlaiveMods._target(w, i, cur, chased), -1, "but never the one to go back to")


func test_g5_homing_on_the_way_back_goes_to_a_different_enemy_if_one_is_near() -> void:
	var w := _world([&"gun_homing"])
	_throw(w)
	var i := _discs(w)[0]
	while not Glaive.coming_back(w, i):
		W.run(w, 1, 0, 0)
		i = _discs(w)[0]
	var plain := _world([])
	_throw(plain)
	W.run(plain, w.tick - plain.tick, 0, 0)
	var b := Vector2(4.0, -0.9)  # 0.9 m off the way home: a straight disc misses it
	w.add_dummy(b, 0.35, HP)
	plain.add_dummy(b, 0.35, HP)
	W.run(w, 60, 0, 0)
	W.run(plain, 60, 0, 0)
	assert_eq(_hits(plain, 1).size(), 0, "a straight disc going home misses it")
	assert_gte(_hits(w, 1).size(), 1, "the homing disc swings to it on the way back")


# --- G6 Echo ----------------------------------------------------------------------------------------------------------
func test_g6_echo_sends_a_second_disc_18_ticks_later_at_half() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_throw(w, 62)
	var h := _hits(w, 1)
	assert_eq(h[0][1], 8)
	assert_eq(h[1][0] - h[0][0], 18, "18 ticks later")
	assert_eq(h[1][1], 4, "at 50 %")
	assert_eq(_total(h), 8 + 4 + 8 + 4, "out and back, the disc and its echo")


func test_g6_echo_starts_no_follow_ups() -> void:
	var w := _world([&"gun_echo", &"split_shot"], [Vector2(3.0, 0.0)])
	_throw(w, 11)
	var small := 0
	for i in _discs(w):
		small += 1 if w.projectiles.ret[i] == 0 else 0
	assert_eq(small, 2, "the first disc's two small discs")
	W.run(w, 18, 0, 0)  # they have ended; the echo's disc hit the enemy meanwhile (tick 26)
	assert_eq(_hits(w, 1).size(), 2, "the echo's disc did hit it")
	for i in _discs(w):
		assert_true(w.projectiles.ret[i] != 0, "no small discs from the echo's hit")


# --- G7 Big Shot ------------------------------------------------------------------------------------------------------
func test_g7_big_shot_is_a_third_bigger_slower_and_stronger() -> void:
	var w := _world([&"gun_big_shot"])
	_throw(w)
	var i := _discs(w)[0]
	assert_almost_eq(w.projectiles.radius[i], 0.45, 0.001, "radius x 1.5")
	assert_almost_eq(w.projectiles.vel_x[i], 0.175, 0.001, "speed x 0.75")
	assert_eq(w.projectiles.damage[i], 12, "damage x 1.6")


# --- G8 Rapid Fire ----------------------------------------------------------------------------------------------------
func test_g8_rapid_fire_throws_every_27_ticks_smaller_faster_and_weaker() -> void:
	var w := _world([&"gun_rapid_fire"])
	var born := []
	var seen := {}
	for t in 60:
		W.run(w, 1, 0, W.S)
		for i in w.projectiles.size():
			if not seen.has(w.projectiles.ids[i]):
				seen[w.projectiles.ids[i]] = true
				born.append(w.tick)
	assert_eq(born[1] - born[0], 27, "every 27 ticks")
	var i := 0
	assert_almost_eq(w.projectiles.radius[i], 0.21, 0.001, "radius x 0.7")
	assert_almost_eq(absf(w.projectiles.vel_x[i]), 0.29167, 0.001, "speed x 1.25")
	assert_eq(w.projectiles.damage[i], 5, "damage x 0.7")


func test_g8_rapid_fire_with_big_shot_multiplies_both() -> void:
	var w := _world([&"gun_rapid_fire", &"gun_big_shot"])
	_throw(w)
	var i := _discs(w)[0]
	assert_almost_eq(w.projectiles.radius[i], 0.3 * 1.5 * 0.7, 0.001)
	assert_almost_eq(w.projectiles.vel_x[i], 0.2333 * 0.75 * 1.25, 0.001)
	assert_eq(w.projectiles.damage[i], 8, "8 x 1.6 x 0.7")


# --- G9 Split ---------------------------------------------------------------------------------------------------------
func test_g9_split_sheds_two_small_discs_at_30_degrees_that_fly_on_4_m() -> void:
	var w := _world([&"split_shot"], [Vector2(3.0, 0.0), Vector2(5.1, 1.0), Vector2(5.1, -1.0)])
	_throw(w, 45)
	assert_eq(_hits(w, 2), [[14, 2]], "a small disc hit the enemy at +30 degrees: 30 % of 8")
	assert_eq(_hits(w, 3), [[14, 2]], "and the one at -30 degrees")
	assert_eq(_hits(w, 1).size(), 2, "the first enemy took the disc going out and back")


func test_g9_split_a_small_disc_has_no_return_and_ends_after_4_m() -> void:
	var w := _world([&"split_shot"], [Vector2(3.0, 0.0)])
	_throw(w, 12)
	var small := []
	for i in _discs(w):
		if w.projectiles.ret[i] == 0:
			small.append(i)
	assert_eq(small.size(), 2)
	var a := Kin.angle_diff(_angle(w, small[0]), 0)
	assert_between(a, 339, 343, "30 degrees off the line")
	for i in small:
		assert_eq(w.projectiles.damage[i], 2)
		assert_almost_eq(w.projectiles.radius[i], 0.21, 0.001, "small")
	W.run(w, 20, 0, 0)
	for i in _discs(w):
		assert_true(w.projectiles.ret[i] != 0, "they ended")


func test_g9_split_sheds_once_a_disc() -> void:
	var w := _world([&"split_shot"], [Vector2(3.0, 0.0), Vector2(4.0, 0.0)])
	_throw(w, 41)
	var rows := 0
	for k in w.mx.gm_kind.size():
		rows += 1 if w.mx.gm_kind[k] & GlaiveMods.F_SPLIT != 0 else 0
	assert_eq(rows, 1, "one disc, one shedding")
	assert_lte(w.mx.gm_kind.size(), 3, "a disc and its two small ones")


# --- G10 Mine ---------------------------------------------------------------------------------------------------------
func test_g10_mine_stops_at_its_far_point_72_ticks_then_returns() -> void:
	var w := _world([&"gun_mine"])
	_throw(w)
	var still := 0
	var prev := Vector2.INF
	var held_at := Vector2.ZERO
	for k in 130:
		W.run(w, 1, 0, 0)
		var d := _discs(w)
		if d.is_empty():
			break
		var p := _pos(w, d[0])
		if p == prev:
			still += 1
			held_at = p
		prev = p
	assert_between(still, 70, 74, "72 ticks in place")
	assert_between(held_at.x, 7.0, 8.0, "at its far point")
	assert_true(_discs(w).is_empty() or Glaive.coming_back(w, _discs(w)[0]), "then it returns")


func test_g10_mine_hits_an_enemy_at_the_far_point_each_30_ticks() -> void:
	var w := _world([&"gun_mine"])
	_throw(w, 39)
	var hold := _pos(w, _discs(w)[0])
	w.add_dummy(hold, 0.35, HP)
	W.run(w, 70, 0, 0)
	var h := _hits(w, 1)
	assert_gte(h.size(), 3, "while it spins it keeps hitting")
	for x: Array in h:
		assert_eq(x[1], 8)
	assert_gte(h[1][0] - h[0][0], 30, "a hit at most once per 30 ticks")


# --- G11 Orbit --------------------------------------------------------------------------------------------------------
func test_g11_orbit_circles_the_hero_once_at_2_5_m_then_flies_out_along_the_aim() -> void:
	var w := _world([&"orbit_rounds"])
	_throw(w)
	var near := 0
	for k in 56:
		W.run(w, 1, 0, 0)
		var d := _discs(w)[0]
		if k >= 6:
			var dist := (_pos(w, d) - w.player_pos()).length()
			if absf(dist - 2.5) < 0.15:
				near += 1
	assert_gte(near, 48, "on a 2.5 m circle for the lap")
	W.run(w, 12, 0, 0)
	var i := _discs(w)[0]
	assert_eq(_angle(w, i), 0, "then out along the aim")
	assert_gt(_pos(w, i).x, 2.6)


# --- Bound, determinism, saves ----------------------------------------------------------------------------------------
func test_at_most_eight_live_discs_a_hero_and_64_rows() -> void:
	var w := _world(
		[&"halo_shot", &"gun_echo", &"gun_rapid_fire", &"split_shot", &"gun_ring"],
		[Vector2(4.0, 0.0), Vector2(0.0, 4.0)]
	)
	var most := 0
	var rows := 0
	for t in 300:
		W.run(w, 1, 0, W.S)
		most = maxi(most, _discs(w).size())
		rows = maxi(rows, w.mx.gm_kind.size())
	assert_lte(most, GlaiveMods.param(w, "live_max"), "at most 8 live discs")
	assert_lte(rows, GlaiveMods.ROWS_MAX)
	assert_gt(most, 4, "and the cap is reached")


func test_a_glaive_with_cards_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(5.0, 0.0), Vector2(3.0, 1.5), Vector2(-3.0, 2.0), Vector2(0.0, -4.0)]
	var cards := [&"halo_shot", &"gun_echo", &"gun_ring", &"split_shot", &"gun_homing", &"gun_mine"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 70, 0, W.S)
	W.run(b, 70, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.gm_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.gm_at, a.mx.gm_at)
	assert_eq(c.mx.gm_kind, a.mx.gm_kind)
	assert_eq(c.mx.gm_hit_row, a.mx.gm_hit_row)
	W.run(a, FLY, 0, W.S)
	W.run(c, FLY, 0, W.S)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_a_plain_glaive_hash_has_no_glaive_block() -> void:
	var a := _world([], [Vector2(4.0, 0.0)])
	W.run(a, 50, 0, W.S)
	assert_false(a.mx.gm_touched())
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
	assert_true(w.mx.gm_touched())
	var snap := w.to_snapshot()
	var mx: Dictionary = (snap["world"] as Dictionary)[&"mx"]
	for f: StringName in WorldSnapshot.ADDED_SINCE_V05[&"ModifierState"]:
		if String(f).begins_with("gm_"):
			assert_true(mx.has(f), "%s is saved" % f)
			mx.erase(f)
	var base := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	assert_eq(WorldSnapshot.apply(base, snap), "", "an older snapshot restores")
	assert_false(base.mx.gm_touched(), "with no Glaive rows")
	W.run(base, 10, 0, 0)


func test_rows_are_dropped_when_the_shot_is_no_glaive_any_more() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_throw(w, 3)
	assert_true(w.mx.gm_touched())
	Shop.remove_item(w, W.item(w, &"gun_glaive"))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.gm_touched())
