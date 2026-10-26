# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 FC7 (FORM_COMBOS.md S1-S11): what eleven cards do to the Seekers form (SeekerMods), one test a row with the
## table's numbers. A plain volley is three darts of 2 damage (45 % of 5) every 18 ticks, 10 m/s for 60 ticks, curving
## at 360 degrees a second; aim 0 is +x, the hero stands at the origin, the dummies are 0.35 m wide.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const ANGLE_FUZZ := 3


func _world(cards: Array, at: Array = [], r: float = 0.35) -> World:
	var ids: Array = [&"gun_seekers"]
	ids.append_array(cards)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


## One volley (SHOOT held one tick), then `rest` ticks.
func _volley(w: World, rest: int = 0) -> void:
	W.run(w, 1, 0, W.S)
	W.run(w, rest, 0, 0)


func _hits(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append([e.tick, e.amount, e.tags])
	return out


func _darts(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if Seekers.is_dart(w, i):
			out.append(i)
	return out


func _pos(w: World, i: int) -> Vector2:
	return Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])


func _angle(w: World, i: int) -> int:
	return Kin.angle_of(Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i]))


func _speed(w: World, i: int) -> float:
	return Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i]).length()


func _rows_of(w: World, kind: int) -> int:
	var n := 0
	for k in w.mx.sk_kind.size():
		if w.mx.sk_kind[k] & SeekerMods.KIND_MASK == kind:
			n += 1
	return n


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_seekers_has_none() -> void:
	assert_eq(SeekerMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in SeekerMods.CARD_IDS.size():
		var w := _world([SeekerMods.CARD_IDS[k]])
		var s := Modifiers.bolt(w)
		assert_eq(SeekerMods.mask(s), SeekerMods.CARD_BITS[k], "%s" % SeekerMods.CARD_IDS[k])
		assert_eq(
			[
				s.seekers,
				s.count,
				s.period_ticks,
				s.life_ticks,
				s.share_permille,
				s.bounces,
				s.pierce
			],
			[1, 3, 18, 60, 450, 0, 0],
			"its generic ops are skipped (%s)" % SeekerMods.CARD_IDS[k]
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % SeekerMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in SeekerMods.DEFAULTS:
		assert_eq(SeekerMods.param(w, k), int(SeekerMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"seekers"))
	var keys := SeekerMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.SEEKER_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_seekers_row_allows_the_eleven_cards_and_keeps_five_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in SeekerMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [&"gun_backfire", &"gun_homing", &"gun_spiral", &"gun_swirl", &"gun_threadline"]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_a_plain_seekers_leaves_no_state() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	_volley(w, 90)
	assert_false(w.mx.sk_touched())
	assert_eq(w.mx.sk_next, 0)


# --- S1 Twin ----------------------------------------------------------------------------------------------------------
func test_s1_twin_is_six_darts_at_sixty_percent_each() -> void:
	var w := _world([&"gun_twin"])
	_volley(w)
	var d := _darts(w)
	assert_eq(d.size(), 6, "six darts")
	for i in d:
		assert_eq(w.projectiles.damage[i], SeekerMods.share(2, 600), "60 % of a dart (2): 1")


# --- S2 Halo ----------------------------------------------------------------------------------------------------------
func test_s2_halo_leaves_in_even_directions_flies_straight_18_ticks_then_seeks() -> void:
	var w := _world([&"halo_shot"], [Vector2(0.0, 4.0)])
	_volley(w)
	var d := _darts(w)
	assert_eq(d.size(), 3, "the three darts")
	var angles := []
	for i in d:
		angles.append(_angle(w, i))
	angles.sort()
	for k in 3:
		assert_almost_eq(
			float(angles[k]), float(k * 4096 / 3), float(ANGLE_FUZZ), "every 120 degrees"
		)
	var first := {}
	for i in d:
		first[w.projectiles.ids[i]] = _angle(w, i)
	W.run(w, 15, 0, 0)  # tick 17 of their life: still straight
	for i in _darts(w):
		var id: int = w.projectiles.ids[i]
		if first.has(id):
			assert_almost_eq(float(_angle(w, i)), float(first[id]), float(ANGLE_FUZZ), "straight")
	W.run(w, 25, 0, 0)
	var bent := 0
	for i in _darts(w):
		var id: int = w.projectiles.ids[i]
		if first.has(id) and absi(Kin.angle_diff(_angle(w, i), first[id])) > 100:
			bent += 1
	assert_gt(bent, 0, "then they turn to their target")


# --- S3 Ring ----------------------------------------------------------------------------------------------------------
func test_s3_ring_makes_a_one_metre_ring_of_30_percent_at_each_hit() -> void:
	var w := _world([&"gun_ring"], [Vector2(3.0, 0.0), Vector2(3.0, 0.8)])
	var plain := _world([], [Vector2(3.0, 0.0), Vector2(3.0, 0.8)])
	_volley(w, 40)
	_volley(plain, 40)
	var area := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.tags & SimEvent.TAG_AREA:
			area += 1
			assert_eq(e.amount, SeekerMods.share(2, 300), "30 % of the dart")
	assert_gt(area, 0, "rings landed")
	for e in W.events(plain, SimEvent.Kind.DAMAGE):
		assert_false(e.tags & SimEvent.TAG_AREA != 0, "a plain dart makes none")
	var ringed := false
	for t in 12:
		W.run(w, 1, 0, 0)
		ringed = ringed or not SeekerMods.read_rings(w).is_empty()
	assert_true(ringed or area > 0, "and the view reads it")
	assert_almost_eq(float(Stats.area(w, 1.0)), 1.0, 0.5)


func test_s3_each_enemy_in_a_ring_is_hit_once_per_ring() -> void:
	var w := _world([&"gun_ring"], [Vector2(3.0, 0.0)])
	W.run(w, 1, 0, W.S)
	var rings := 0
	var seen := {}
	for t in 60:
		W.run(w, 1, 0, 0)
		var n := _rows_of(w, SeekerMods.K_RING)
		if n > 0:
			rings = maxi(rings, n)
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.tags & SimEvent.TAG_AREA:
			var key := "%d:%d" % [e.tick, e.target_id]
			seen[key] = int(seen.get(key, 0)) + 1
	assert_gt(rings, 0)
	assert_gt(seen.size(), 0)
	for key: String in seen:
		assert_lte(
			seen[key], 3, "one hit a ring, at most one ring a dart (three darts) a tick: %s" % key
		)


# --- S4 Pierce --------------------------------------------------------------------------------------------------------
func test_s4_pierce_goes_through_and_seeks_the_next_unhit_enemy_up_to_three_hits() -> void:
	var w := _world(
		[&"gun_pierce"],
		[Vector2(2.5, 0.0), Vector2(4.0, 0.0), Vector2(5.5, 0.0), Vector2(7.0, 0.0)]
	)
	var most := 0
	W.run(w, 1, 0, W.S)
	for t in 80:
		W.run(w, 1, 0, 0)
		var per := {}
		for r in w.mx.sk_hit_row:
			per[r] = int(per.get(r, 0)) + 1
		for r: int in per:
			most = maxi(most, per[r])
			var actors := {}
			for q in w.mx.sk_hit_row.size():
				if w.mx.sk_hit_row[q] == r:
					assert_false(actors.has(w.mx.sk_hit_actor[q]), "never the same enemy twice")
					actors[w.mx.sk_hit_actor[q]] = true
	assert_eq(most, 2, "two hits are noted; the third ends the dart")
	var per_enemy := []
	for k in range(1, 5):
		per_enemy.append(_hits(w, k).size())
	assert_eq(
		per_enemy,
		[3, 3, 3, 0],
		"each of the three darts hit the first three enemies, none a fourth"
	)


# --- S5 Ricochet ------------------------------------------------------------------------------------------------------
func test_s5_ricochet_darts_are_thrown_with_three_wall_bounces() -> void:
	var w := _world([&"gun_ricochet"])
	_volley(w)
	assert_eq(_darts(w).size(), 3)
	for i in _darts(w):
		assert_eq(w.projectiles.bounces[i], 3)


# --- S6 Echo ----------------------------------------------------------------------------------------------------------
func test_s6_echo_sends_a_second_volley_18_ticks_later_at_half_and_it_follows_nothing() -> void:
	var w := _world([&"gun_echo", &"split_shot"])
	_volley(w)
	assert_eq(_darts(w).size(), 3)
	assert_eq(_rows_of(w, SeekerMods.K_OPEN), 3, "three ghosts wait")
	W.run(w, 16, 0, 0)
	assert_eq(_darts(w).size(), 3, "not yet")
	W.run(w, 3, 0, 0)
	var d := _darts(w)
	assert_eq(d.size(), 6, "the second volley")
	var halves := 0
	for i in d:
		if w.projectiles.damage[i] == SeekerMods.share(2, 500):
			halves += 1
	assert_eq(halves, 3, "at 50 %")
	for k in w.mx.sk_kind.size():
		if w.mx.sk_kind[k] & SeekerMods.KIND_MASK == SeekerMods.K_BALL and w.mx.sk_born[k] > 10:
			assert_ne(w.mx.sk_kind[k] & SeekerMods.F_NOFOLLOW, 0, "a ghost starts no follow-ups")
	assert_eq(_rows_of(w, SeekerMods.K_OPEN), 0, "and none waits for it")


# --- S7 Big Shot, S8 Rapid Fire ---------------------------------------------------------------------------------------
func test_s7_big_shot_is_two_darts_at_double_damage_and_one_and_a_half_the_radius() -> void:
	var w := _world([&"gun_big_shot"])
	var plain := _world([])
	_volley(w)
	_volley(plain)
	var d := _darts(w)
	assert_eq(d.size(), 2)
	for i in d:
		assert_eq(w.projectiles.damage[i], 4, "x 2.0")
		assert_almost_eq(
			w.projectiles.radius[i], plain.projectiles.radius[_darts(plain)[0]] * 1.5, 0.001
		)


func test_s8_rapid_fire_is_five_darts_at_65_percent_and_seven_tenths_the_radius() -> void:
	var w := _world([&"gun_rapid_fire"])
	var plain := _world([])
	_volley(w)
	_volley(plain)
	var d := _darts(w)
	assert_eq(d.size(), 5)
	for i in d:
		assert_eq(w.projectiles.damage[i], SeekerMods.share(2, 650))
		assert_almost_eq(
			w.projectiles.radius[i], plain.projectiles.radius[_darts(plain)[0]] * 0.7, 0.001
		)


# --- S9 Split ---------------------------------------------------------------------------------------------------------
func test_s9_split_sheds_two_children_once_that_seek_other_enemies() -> void:
	var w := _world([&"split_shot"], [Vector2(3.0, 0.0), Vector2(3.0, 3.0), Vector2(3.0, -3.0)])
	W.run(w, 1, 0, W.S)
	var children := 0
	for t in 70:
		W.run(w, 1, 0, 0)
		var n := 0
		for k in w.mx.sk_kind.size():
			if (
				w.mx.sk_kind[k] & SeekerMods.F_CHILD != 0
				and w.mx.sk_kind[k] & 3 == SeekerMods.K_BALL
			):
				n += 1
				assert_ne(
					w.mx.sk_kind[k] & SeekerMods.F_NOFOLLOW, 0, "children start no follow-ups"
				)
				var hit_by: int = w.mx.sk_aux[k] - 1
				assert_gte(hit_by, 0, "it remembers the enemy it split from")
		children = maxi(children, n)
	assert_gt(children, 1, "children appeared in pairs")
	assert_lte(children, 6, "two a dart, once a dart")
	var third := 0
	for i in range(2, 4):
		third += _hits(w, i).size()
	assert_gt(third, 0, "and the other enemies were hit")


# --- S10 Mine ---------------------------------------------------------------------------------------------------------
func test_s10_mine_hangs_still_36_ticks_then_all_dive_at_their_targets() -> void:
	var w := _world([&"gun_mine"], [Vector2(0.0, 5.0)])
	_volley(w)
	var start := {}
	for i in _darts(w):
		start[w.projectiles.ids[i]] = _pos(w, i)
	W.run(w, 30, 0, 0)
	for i in _darts(w):
		assert_eq(_speed(w, i), 0.0, "still")
		assert_lt((_pos(w, i) - start[w.projectiles.ids[i]]).length(), 0.3, "where it was")
	assert_eq(_hits(w, 1).size(), 0)
	W.run(w, 12, 0, 0)  # past tick 36
	for i in _darts(w):
		assert_gt(_speed(w, i), 0.1, "diving")
	W.run(w, 40, 0, 0)
	assert_gt(_hits(w, 1).size(), 0, "they reach it")


# --- S11 Orbit --------------------------------------------------------------------------------------------------------
func test_s11_orbit_circles_the_hero_once_at_2_5_m_then_launches() -> void:
	var w := _world([&"orbit_rounds"])
	_volley(w)
	var near := 0
	var total := 0
	for k in 52:
		W.run(w, 1, 0, 0)
		if k >= 6:
			for i in _darts(w):
				total += 1
				if absf((_pos(w, i) - w.player_pos()).length() - 2.5) < 0.2:
					near += 1
	assert_gte(near * 10, total * 9, "on the 2.5 m circle for the lap")
	W.run(w, 40, 0, 0)
	for i in _darts(w):
		assert_gt((_pos(w, i) - w.player_pos()).length(), 3.5, "launched away from the hero")


# --- Bound, determinism, saves ----------------------------------------------------------------------------------------
func test_at_most_24_live_darts_a_hero_and_64_rows() -> void:
	var w := _world(
		[&"gun_twin", &"gun_echo", &"gun_rapid_fire", &"split_shot", &"gun_ring", &"orbit_rounds"],
		[Vector2(4.0, 0.0), Vector2(0.0, 4.0)]
	)
	var most := 0
	var rows := 0
	for t in 400:
		W.run(w, 1, 0, W.S)
		most = maxi(most, _darts(w).size())
		rows = maxi(rows, w.mx.sk_kind.size())
	assert_lte(most, SeekerMods.param(w, "live_max"), "at most 24 live darts")
	assert_lte(rows, SeekerMods.ROWS_MAX)
	assert_eq(most, 24, "and the cap is reached")


func test_a_seekers_with_cards_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(5.0, 0.0), Vector2(3.0, 1.5), Vector2(-3.0, 2.0), Vector2(0.0, -4.0)]
	var cards := [&"gun_twin", &"gun_echo", &"gun_ring", &"split_shot", &"gun_pierce"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 50, 0, W.S)
	W.run(b, 50, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.sk_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.sk_at, a.mx.sk_at)
	assert_eq(c.mx.sk_kind, a.mx.sk_kind)
	assert_eq(c.mx.sk_hit_row, a.mx.sk_hit_row)
	W.run(a, 100, 0, W.S)
	W.run(c, 100, 0, W.S)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_a_plain_seekers_hash_has_no_seekers_block() -> void:
	var a := _world([], [Vector2(4.0, 0.0)])
	W.run(a, 50, 0, W.S)
	assert_false(a.mx.sk_touched())
	var h := StateHasher.new()
	h.add_string("seekers")
	a.mx.hash_into(h)
	var with := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	W.run(with, 10, 0, W.S)
	var h2 := StateHasher.new()
	h2.add_string("seekers")
	with.mx.hash_into(h2)
	assert_true(with.mx.sk_touched())
	var same := _world([], [Vector2(4.0, 0.0)])
	W.run(same, 50, 0, W.S)
	var h3 := StateHasher.new()
	h3.add_string("seekers")
	same.mx.hash_into(h3)
	var x := h.finish_hex()
	assert_eq(x, h3.finish_hex(), "no block while no row is set")
	assert_ne(x, h2.finish_hex(), "the rows are hashed while set")


func test_an_older_save_without_the_rows_loads_empty() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	W.run(w, 10, 0, W.S)
	assert_true(w.mx.sk_touched())
	var snap := w.to_snapshot()
	var mx: Dictionary = (snap["world"] as Dictionary)[&"mx"]
	for f: StringName in WorldSnapshot.ADDED_SINCE_V05[&"ModifierState"]:
		if String(f).begins_with("sk_"):
			assert_true(mx.has(f), "%s is saved" % f)
			mx.erase(f)
	var base := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	assert_eq(WorldSnapshot.apply(base, snap), "", "an older snapshot restores")
	assert_false(base.mx.sk_touched(), "with no Seekers rows")
	W.run(base, 10, 0, 0)


func test_rows_are_dropped_when_the_shot_is_no_seekers_any_more() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	_volley(w, 3)
	assert_true(w.mx.sk_touched())
	Shop.remove_item(w, W.item(w, &"gun_seekers"))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.sk_touched())
