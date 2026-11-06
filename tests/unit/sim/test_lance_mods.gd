extends GutTest
## v0.9.5 FC4 (FORM_COMBOS.md N1-N9): what nine cards do to the Lance form (LanceMods), one test a row with the table's
## numbers. A full charge (72 ticks) deals 58, a tap 5; the ball leaves 0.86 m out; aim 0 is +x, the hero stands at the
## origin, the orb's radius is read from the spec.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
## Ticks after a release for a ball (and its echo) to fly its whole range.
const FLY := 90


func _world(cards: Array, at: Array = [], r: float = 0.35) -> World:
	var ids: Array = [&"gun_lance"]
	ids.append_array(cards)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


## Holds SHOOT `held` ticks (-1: to full), then lets go for `rest` ticks.
func _release(w: World, held: int = -1, rest: int = 1) -> void:
	var n := LanceMods.hold_ticks(w, Modifiers.bolt(w)) if held < 0 else held
	W.run(w, n, 0, W.S)
	W.run(w, rest, 0, 0)


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


## The ticks at which actor `idx` took direct damage.
func _hit_ticks(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append(e.tick)
	return out


func _balls(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			out.append(i)
	return out


func _angle(w: World, i: int) -> int:
	return Kin.angle_of(Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i]))


func _rows(w: World, kind: int) -> int:
	var n := 0
	for k in w.mx.lm_kind.size():
		if w.mx.lm_kind[k] & LanceMods.KIND_MASK == kind:
			n += 1
	return n


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_lance_has_none() -> void:
	assert_eq(LanceMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in LanceMods.CARD_IDS.size():
		var w := _world([LanceMods.CARD_IDS[k]])
		var s := Modifiers.bolt(w)
		assert_eq(LanceMods.mask(s), LanceMods.CARD_BITS[k], "%s" % LanceMods.CARD_IDS[k])
		assert_eq(
			[s.lance, s.hold_ticks, s.hold_permille, s.period_ticks, s.pierce],
			[1, 72, 11600, 24, Lance.PIERCE_ALL],
			"its generic ops are skipped"
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % LanceMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in LanceMods.DEFAULTS:
		assert_eq(LanceMods.param(w, k), int(LanceMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"lance"))
	var keys := LanceMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.LANCE_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_lance_row_allows_the_nine_cards_and_keeps_six_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in LanceMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [
		&"gun_pierce", &"gun_mine", &"orbit_rounds", &"gun_spiral", &"gun_swirl", &"gun_threadline"
	]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_a_plain_lance_leaves_no_state() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	_release(w, -1, FLY)
	assert_false(w.mx.lm_touched())
	assert_eq(w.mx.lm_next, 0)


# --- N1 Halo ----------------------------------------------------------------------------------------------------------
func test_n1_halo_fires_six_lances_every_60_degrees_at_half_on_a_full_charge() -> void:
	var at := []
	for k in 6:
		at.append(Vector2(4.0, 0.0).rotated(deg_to_rad(60.0 * k)))
	var w := _world([&"halo_shot"], at)
	_release(w, -1, 2)
	var balls := _balls(w)
	assert_eq(balls.size(), 6, "six lances")
	var angles := []
	for i in balls:
		angles.append(_angle(w, i))
		assert_eq(w.projectiles.damage[i], 29, "50 % of 58")
	angles.sort()
	for k in 6:
		assert_between(
			angles[k], k * 4096 / 6 - 2, k * 4096 / 6 + 2, "every 60 degrees from the aim"
		)
	W.run(w, FLY, 0, 0)
	for k in 6:
		assert_eq(_dealt(w, k + 1), [1, 29], "each enemy takes one lance at 50 %")


func test_n1_halo_a_tap_and_a_partial_charge_fire_one_lance_as_today() -> void:
	for c: Array in [[1, 5], [36, 31]]:
		var w := _world([&"halo_shot"])
		_release(w, c[0], 2)
		assert_eq(_balls(w).size(), 1, "%d ticks held: one" % c[0])
		assert_eq(w.projectiles.damage[_balls(w)[0]], c[1], "and its whole damage")


# --- N2 Ring ----------------------------------------------------------------------------------------------------------
## Where a lance fired along +x ends (its last place before it goes), in a world with `cards`.
func _lance_end(cards: Array) -> Vector2:
	var w := _world(cards)
	_release(w, -1, 2)
	var last := Vector2.ZERO
	for k in 200:
		var i := _balls(w)
		if i.is_empty():
			break
		last = Vector2(w.projectiles.pos_x[i[0]], w.projectiles.pos_y[i[0]])
		W.run(w, 1, 0, 0)
	return last


func test_n2_ring_bursts_a_2_m_lightning_ring_over_0_25_s_where_the_lance_ends() -> void:
	var end := _lance_end([&"gun_ring"])
	assert_gt(end.x, 8.0, "the lance flew its range")
	var w := _world([&"gun_ring"], [end + Vector2(0.0, 1.5), end + Vector2(0.0, 2.6)])
	_release(w, -1, 1)
	var seen := 0
	var biggest := 0.0
	for k in FLY + 10:
		W.run(w, 1, 0, 0)
		var rings := LanceMods.read_rings(w)
		seen = maxi(seen, rings.size())
		for r in rings:
			biggest = maxf(biggest, r["r"])
	assert_eq(seen, 1, "one ring")
	assert_almost_eq(biggest, 2.0, 0.01, "2 m")
	assert_eq(_dealt(w, 1), [1, 29], "an enemy 1.5 m off the end takes 50 % once")
	assert_eq(_dealt(w, 2)[0], 0, "and one beyond the reach none")
	var tagged := false
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == w.actors.ids[1]:
			tagged = e.tags & SimEvent.TAG_AREA != 0
	assert_true(tagged, "TAG_AREA")
	assert_eq(_rows(w, LanceMods.K_RING), 0, "and the ring is gone")


# --- N3 Backfire ------------------------------------------------------------------------------------------------------
func test_n3_backfire_also_fires_a_lance_behind_at_half() -> void:
	var w := _world([&"gun_backfire"], [Vector2(4.0, 0.0), Vector2(-4.0, 0.0)])
	_release(w, -1, 2)
	var balls := _balls(w)
	assert_eq(balls.size(), 2)
	assert_eq(_angle(w, balls[1]), 2048, "straight behind")
	assert_eq(w.projectiles.damage[balls[1]], 29, "50 %")
	assert_eq(w.projectiles.damage[balls[0]], 58, "the front lance is whole")
	W.run(w, FLY, 0, 0)
	assert_eq([_dealt(w, 1), _dealt(w, 2)], [[1, 58], [1, 29]])


# --- N4 Ricochet ------------------------------------------------------------------------------------------------------
func test_n4_ricochet_reflects_a_full_charge_off_the_first_wall_once_and_keeps_its_range() -> void:
	var w := _world([&"gun_ricochet"], [Vector2(3.0, 0.0)])
	w.add_wall_now(Obb.make(Vector2(7.0, 0.0), Vector2(0.2, 3.0), 0))
	_release(w, -1, 2)
	var i := _balls(w)[0]
	assert_eq(w.projectiles.bounces[i], 1, "one bounce")
	var turned := false
	var passes := 0
	for k in FLY:
		W.run(w, 1, 0, 0)
		var b := _balls(w)
		if b.is_empty():
			break
		if w.projectiles.vel_x[b[0]] < 0.0:
			turned = true
	passes = _dealt(w, 1)[0]
	assert_true(turned, "it came back off the wall")
	assert_eq(passes, 2, "and hit the enemy on the way out and back")
	var tap := _world([&"gun_ricochet"], [Vector2(3.0, 0.0)])
	tap.add_wall_now(Obb.make(Vector2(7.0, 0.0), Vector2(0.2, 3.0), 0))
	_release(tap, 1, 2)
	assert_eq(tap.projectiles.bounces[_balls(tap)[0]], 0, "a tap does not bounce")
	W.run(tap, FLY, 0, 0)
	assert_eq(_dealt(tap, 1)[0], 1, "one pass")


# --- N5 Homing --------------------------------------------------------------------------------------------------------
func test_n5_homing_bends_a_lance_toward_the_nearest_enemy_ahead_at_up_to_60_degrees_a_second(
) -> void:
	var w := _world([&"gun_homing"], [Vector2(9.0, 1.4)])
	_release(w, 1, 1)
	var plain := _world([], [Vector2(9.0, 1.4)])
	_release(plain, 1, 1)
	var prev := _angle(w, _balls(w)[0])
	var most := 0
	var turned := 0
	for k in 40:
		W.run(w, 1, 0, 0)
		var b := _balls(w)
		if b.is_empty():
			break
		var a := _angle(w, b[0])
		most = maxi(most, Kin.angle_diff(a, prev))
		prev = a
	turned = prev
	assert_between(most, 1, 11, "at most 60 degrees a second: 11 units a tick")
	assert_gt(turned, 0, "it turned toward the enemy")
	W.run(plain, FLY, 0, 0)
	W.run(w, FLY, 0, 0)
	assert_eq(_dealt(plain, 1)[0], 0, "a straight tap misses an enemy 1.4 m off the line")
	assert_gte(_dealt(w, 1)[0], 1, "the homing lance hits it")


func test_n5_homing_ignores_an_enemy_more_than_60_degrees_off_its_line() -> void:
	var w := _world([&"gun_homing"], [Vector2(2.0, 4.0), Vector2(-3.0, 0.0)])
	_release(w, 1, 1)
	var b := _balls(w)[0]
	for k in 20:
		W.run(w, 1, 0, 0)
	assert_eq(_angle(w, b), 0, "an enemy at 63 degrees and one behind do not bend it")


# --- N6 Echo ----------------------------------------------------------------------------------------------------------
func test_n6_echo_repeats_the_same_line_0_4_s_later_at_half() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_release(w, -1, 1)
	var fired := w.tick
	assert_eq(_rows(w, LanceMods.K_ECHO), 1, "the ghost waits")
	W.run(w, FLY, 0, 0)
	assert_eq(_dealt(w, 1), [2, 58 + 29], "the lance and its ghost")
	var ticks := _hit_ticks(w, 1)
	assert_between(ticks[1] - ticks[0], 23, 25, "0.4 s apart")
	assert_gt(ticks[0], fired, "after the release")
	assert_eq(_rows(w, LanceMods.K_ECHO), 0)
	assert_eq(w.projectiles.size(), 0, "the ghost starts no follow-up")


func test_n6_echo_ghost_flies_the_line_the_hero_fired_even_after_moving() -> void:
	var w := _world([&"gun_echo"], [Vector2(5.0, 0.0)])
	_release(w, -1, 1)
	W.run(w, 4, 0, 0, 0, Vector2i(0, 1))  # the hero steps off the line
	W.run(w, FLY, 0, 0)
	assert_eq(_dealt(w, 1)[0], 2, "the ghost still hits the enemy on the old line")


# --- N7 Big Shot ------------------------------------------------------------------------------------------------------
func test_n7_big_shot_is_twice_as_wide_60_percent_stronger_and_charges_0_3_s_longer() -> void:
	var w := _world([&"gun_big_shot"])
	var plain := _world([])
	assert_eq(LanceMods.hold_ticks(w, Modifiers.bolt(w)), 90, "1.2 s + 0.3 s")
	_release(plain, -1, 2)
	_release(w, 89, 0)
	assert_eq(_balls(w).size(), 0, "not full at 89 ticks: still charging")
	var w2 := _world([&"gun_big_shot"])
	_release(w2, -1, 2)
	var i := _balls(w2)[0]
	assert_eq(w2.projectiles.damage[i], 92, "58 x 1.6")
	assert_almost_eq(
		w2.projectiles.radius[i],
		plain.projectiles.radius[_balls(plain)[0]] * 2.0,
		0.001,
		"twice as wide"
	)
	var e: SimEvent = W.events(w2, SimEvent.Kind.LANCE)[0]
	assert_almost_eq(e.amount / 1000.0, w2.projectiles.radius[i], 0.001, "and the event says so")


# --- N8 Rapid Fire ----------------------------------------------------------------------------------------------------
func test_n8_rapid_fire_charges_40_percent_faster_for_30_percent_less() -> void:
	var w := _world([&"gun_rapid_fire"])
	assert_eq(LanceMods.hold_ticks(w, Modifiers.bolt(w)), 51, "1.2 s / 1.4")
	W.run(w, 25, 0, W.S)
	assert_almost_eq(Lance.charge(w), 25.0 / 51.0, 1e-6)
	W.run(w, 26, 0, W.S)
	assert_almost_eq(Lance.charge(w), 1.0, 1e-6, "full at 51 ticks")
	W.run(w, 1, 0, 0)
	assert_eq(w.projectiles.damage[_balls(w)[0]], 40, "58 x 0.7")


# --- N9 Split ---------------------------------------------------------------------------------------------------------
func test_n9_split_every_pierced_enemy_spits_two_25_percent_shards_sideways_up_to_six() -> void:
	var at := []
	for k in 8:
		at.append(Vector2(2.0 + 1.0 * k, 0.0))
	for k in 8:
		at.append(Vector2(2.0 + 1.0 * k, 1.8))
		at.append(Vector2(2.0 + 1.0 * k, -1.8))
	var w := _world([&"split_shot"], at, 0.3)
	_release(w, -1, FLY)
	var line_hits := 0
	var sides := []
	for k in 8:
		line_hits += _dealt(w, 1 + k)[0]
	for k in range(8, 16):
		sides.append(_dealt(w, 1 + 2 * k - 8)[1])
		sides.append(_dealt(w, 2 + 2 * k - 8)[1])
	assert_eq(line_hits, 8, "the lance pierced all eight")
	var spat := 0
	var shard := 58 * 250 / 1000
	for v in sides:
		if v == shard:
			spat += 1
		else:
			assert_eq(v, 0, "a side enemy takes a shard or nothing")
	assert_eq(spat, 12, "six enemies spat two shards each: 12 landed, the other two enemies' none")
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.amount == shard:
			assert_true(e.tags & SimEvent.TAG_SHRAPNEL != 0, "TAG_SHRAPNEL")
	assert_eq(_rows(w, LanceMods.K_SHARD), 0, "the shards' rows are gone")


func test_n9_split_a_shard_stops_at_3_m() -> void:
	var w := _world([&"split_shot"], [Vector2(3.0, 0.0), Vector2(3.0, 4.2)])
	_release(w, -1, FLY)
	assert_eq(_dealt(w, 2)[0], 0, "an enemy 4.2 m off the line is out of the shard's 3 m")


# --- Together ---------------------------------------------------------------------------------------------------------
func test_a_lance_with_cards_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(5.0, 0.0), Vector2(6.0, 1.0), Vector2(-3.0, 2.0), Vector2(7.0, -3.0)]
	var cards := [&"halo_shot", &"gun_echo", &"gun_ring", &"split_shot", &"gun_homing"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	_release(a, -1, 12)
	_release(b, -1, 12)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.lm_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.lm_at, a.mx.lm_at)
	assert_eq(c.mx.lm_kind, a.mx.lm_kind)
	assert_eq(c.mx.lm_hit, a.mx.lm_hit)
	W.run(a, FLY, 0, 0)
	W.run(c, FLY, 0, 0)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_rows_are_dropped_when_the_shot_is_no_lance_any_more() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_release(w, -1, 3)
	assert_true(w.mx.lm_touched())
	Shop.remove_item(w, W.item(w, &"gun_lance"))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.lm_touched())
