extends GutTest
## v0.9.5 FC3 (FORM_COMBOS.md V1-V10): what ten cards do to the Void form (VoidMods), one test a row with the table's
## numbers. The plain void deals 10 a tick (one orb hit x 2.0), flies 0.162 m a tick for 67 ticks from 0.86 m out, one
## every 36 ticks; aim 0 is +x, the hero stands at the origin and the aim point is 3.0 m out.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000


func _world(cards: Array, at: Array = [], r: float = 0.35) -> World:
	var ids: Array = [&"gun_void"]
	ids.append_array(cards)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


func _voids(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if VoidShots.is_void_projectile(w, i):
			out.append(i)
	return out


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
	for k in w.mx.vm_kind.size():
		if w.mx.vm_kind[k] & VoidMods.KIND_MASK == kind:
			n += 1
	return n


## The void projectile whose id is `id`'s index now, or -1.
func _index_of(w: World, id: int) -> int:
	return w.projectiles.ids.find(id)


## Runs ticks holding shoot until the first void is gone; returns the tick it vanished at (or -1).
func _until_gone(w: World, id: int, most: int = 400, held: int = W.S) -> int:
	for k in most:
		W.run(w, 1, 0, held)
		if _index_of(w, id) < 0:
			return w.tick
	return -1


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_card_sets_its_bit_and_a_plain_void_has_none() -> void:
	assert_eq(VoidMods.mask(Modifiers.bolt(_world([]))), 0)
	for k in VoidMods.CARD_IDS.size():
		var w := _world([VoidMods.CARD_IDS[k]])
		assert_eq(
			VoidMods.mask(Modifiers.bolt(w)), VoidMods.CARD_BITS[k], "%s" % VoidMods.CARD_IDS[k]
		)
		var s := Modifiers.bolt(w)
		assert_eq(
			[s.void_mm, s.period_ticks, s.damage, s.life_ticks],
			[1000, 36, 10, 67],
			"its generic ops are skipped"
		)
		assert_true(s.hooks.is_empty(), "no hook from %s" % VoidMods.CARD_IDS[k])


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in VoidMods.DEFAULTS:
		assert_eq(VoidMods.param(w, k), int(VoidMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"void"))
	var keys := VoidMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.VOID_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_void_row_allows_the_ten_cards_and_keeps_five_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in VoidMods.CARD_IDS:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [&"halo_shot", &"gun_pierce", &"gun_spiral", &"gun_swirl", &"gun_threadline"]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_a_plain_void_leaves_no_state() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	W.run(w, 300, 0, W.S)
	assert_false(w.mx.vm_touched())
	assert_eq(w.mx.vm_next, 0)


# --- V1 Ring ----------------------------------------------------------------------------------------------------------
func test_v1_ring_collapses_in_a_3_m_lightning_ring_over_0_3_s_hitting_each_enemy_once() -> void:
	var w := _world([&"gun_ring"], [Vector2(13.8, 0.0)])
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	var gone := _until_gone(w, id)
	assert_between(gone, 66, 70, "the void ends after its 67 ticks")
	W.run(w, 1, 0, W.S)
	assert_eq(_rows(w, VoidMods.K_RING), 1, "it left a ring")
	var k := -1
	for q in w.mx.vm_kind.size():
		if w.mx.vm_kind[q] & VoidMods.KIND_MASK == VoidMods.K_RING:
			k = q
	assert_eq(w.mx.vm_r[k], 3000, "3 m")
	assert_eq(w.mx.vm_due[k] - w.mx.vm_born[k], 18, "0.3 s")
	assert_eq(w.mx.vm_dmg[k], 30, "60 % of one aura tick x 5")
	assert_eq(_dealt(w, 1), [0, 0], "nothing yet: the enemy is 2 m past the end")
	W.run(w, 20, 0, 0)
	assert_eq(_rows(w, VoidMods.K_RING), 0, "gone")
	assert_eq(_dealt(w, 1), [1, 30], "one ring hit")


# --- V2 Backfire ------------------------------------------------------------------------------------------------------
func test_v2_backfire_throws_a_second_void_behind_at_full_damage() -> void:
	var w := _world([&"gun_backfire"])
	W.run(w, 2, 0, W.S)
	var v := _voids(w)
	assert_eq(v.size(), 2)
	var p := w.projectiles
	assert_gt(p.vel_x[v[0]], 0.0, "one along the aim")
	assert_almost_eq(p.vel_x[v[1]], -p.vel_x[v[0]], 0.0001, "one straight behind")
	assert_eq([p.damage[v[0]], p.damage[v[1]]], [10, 10], "100 %")
	assert_eq(p.life[v[0]], p.life[v[1]])


# --- V3 Ricochet ------------------------------------------------------------------------------------------------------
func test_v3_ricochet_bounces_off_a_wall_and_keeps_drifting_with_its_life_unchanged() -> void:
	var plain := _world([])
	plain.add_wall_now(Obb.make(Vector2(6.5, 0.0), Vector2(0.2, 3.0), 0))
	var w := _world([&"gun_ricochet"])
	w.add_wall_now(Obb.make(Vector2(6.5, 0.0), Vector2(0.2, 3.0), 0))
	var free := _world([])
	W.run(plain, 1, 0, W.S)
	W.run(free, 1, 0, W.S)
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	var plain_id := plain.projectiles.ids[0]
	var free_id := free.projectiles.ids[0]
	W.run(plain, 49, 0, W.S)
	W.run(w, 49, 0, W.S)
	assert_eq(_index_of(plain, plain_id), -1, "a plain void ends on the wall")
	var i := _index_of(w, id)
	assert_gte(i, 0, "the ricochet void is still drifting")
	assert_lt(w.projectiles.vel_x[i], 0.0, "back the way it came")
	assert_eq(w.projectiles.bounces[i], 64 - 1, "one bounce used")
	assert_eq(
		_until_gone(w, id), _until_gone(free, free_id), "its life is unchanged: the free flight's"
	)


# --- V4 Homing --------------------------------------------------------------------------------------------------------
func test_v4_homing_turns_toward_the_densest_group_within_6_m_at_90_degrees_a_second() -> void:
	var group: Array = [Vector2(5.0, 4.0), Vector2(5.6, 4.0), Vector2(5.0, 4.6), Vector2(5.6, 4.6)]
	var at := group.duplicate()
	at.append(Vector2(4.0, -3.5))  # a lone enemy, nearer to the path's line than to the group
	var w := _world([&"gun_homing"], at)
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	var last := -1
	var worst := 0
	for k in 60:
		W.run(w, 1, 0, W.S)
		var i := _index_of(w, id)
		if i < 0:
			break
		var a := Kin.angle_of(Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i]))
		if last >= 0:
			worst = maxi(worst, Kin.angle_diff(a, last))
		last = a
	assert_lte(worst, 17, "at most 90 degrees a second: 17 of 4096 a tick")
	assert_gt(worst, 0, "it did turn")
	var i := _index_of(w, id)
	assert_gte(i, 0)
	assert_gt(w.projectiles.pos_y[i], 0.5, "drifting up toward the group, not the lone enemy below")
	var row := VoidMods.row_of(w.mx, id)
	assert_true(w.mx.vm_kind[row] & VoidMods.F_TARGET != 0)
	assert_lt(w.mx.vm_at[row].distance_to(Vector2(5.3, 4.3)), 1.0, "its target is in the group")
	var plain := _world([], at)
	W.run(plain, 61, 0, W.S)
	assert_almost_eq(plain.projectiles.pos_y[0], 0.0, 0.01, "a plain void flies straight")
	_homing_ignores_enemies_beyond_6_m()


func _homing_ignores_enemies_beyond_6_m() -> void:
	var w := _world([&"gun_homing"], [Vector2(2.0, 9.0), Vector2(2.3, 9.0)])
	W.run(w, 40, 0, W.S)
	assert_almost_eq(w.projectiles.pos_y[0], 0.0, 0.01, "no group within 6 m: straight on")


# --- V5 Echo ----------------------------------------------------------------------------------------------------------
func test_v5_echo_opens_a_smaller_void_where_it_ended_at_60_percent_half_the_life() -> void:
	var w := _world([&"gun_echo"])
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	var gone := _until_gone(w, id, 400, 0)
	var end_x := 0.86 + 0.162 * 66.0
	W.run(w, 2, 0, 0)
	var echo := -1
	for i in _voids(w):
		if w.projectiles.vel_x[i] == 0.0:
			echo = i
	assert_gte(echo, 0, "a still void opened at tick %d" % gone)
	if echo < 0:
		return
	var p := w.projectiles
	assert_almost_eq(p.pos_x[echo], end_x, 0.35, "where the first ended")
	assert_eq(p.damage[echo], 6, "60 % of 10")
	assert_between(p.life[echo], 31, 33, "half the 67 ticks")
	var seen := VoidShots.read(w)
	var aura := 0.0
	var pull := 0.0
	for v in seen:
		if v["id"] == p.ids[echo]:
			aura = v["aura"]
			pull = v["pull"]
	assert_almost_eq(aura, 0.5, 0.001, "half the aura")
	assert_almost_eq(pull, 1.5, 0.001, "half the pull radius")
	var eid: int = p.ids[echo]
	_until_gone(w, eid, 60, 0)
	W.run(w, 3, 0, 0)
	assert_eq(_voids(w).size(), 0, "no echo of an echo")


# --- V6 Big Shot ------------------------------------------------------------------------------------------------------
func test_v6_big_shot_has_a_1_6_m_aura_pulls_from_4_5_m_flies_30_percent_slower_for_60_percent_more(
) -> void:
	var w := _world([&"gun_big_shot"])
	W.run(w, 2, 0, W.S)
	var i := _voids(w)[0]
	var p := w.projectiles
	assert_eq(p.damage[i], 16, "+60 % a tick")
	assert_almost_eq(Vector2(p.vel_x[i], p.vel_y[i]).length(), 0.162 * 0.7, 0.0001, "30 % slower")
	var v := VoidShots.read(w)[0]
	assert_almost_eq(v["aura"], 1.6, 0.001)
	assert_almost_eq(v["pull"], 4.5, 0.001)
	assert_eq(p.life[i], 66, "its life is unchanged")
	_big_shots_pull_reaches_4_5_m_and_never_a_boss()


func _big_shots_pull_reaches_4_5_m_and_never_a_boss() -> void:
	var w := _world([&"gun_big_shot"], [Vector2(3.0, 4.0)])
	W.run(w, 8, 0, W.S)
	var by: Array = VoidShots.steps(w, _voids(w))
	assert_eq((by[0] as PackedInt32Array).size(), 1, "an enemy 4 m off the path is pulled")
	w.actors.kinds[1] = ActorStore.Kind.GATEKEEPER
	assert_eq((VoidShots.steps(w, _voids(w))[0] as PackedInt32Array).size(), 0, "a boss: none")


# --- V7 Rapid Fire ----------------------------------------------------------------------------------------------------
func test_v7_rapid_fire_throws_every_0_4_s_smaller_voids_with_half_the_life_at_70_percent() -> void:
	var w := _world([&"gun_rapid_fire"])
	assert_eq(ItemEffects.shot_period_ticks(w), 24, "0.4 s")
	assert_eq(ItemEffects.shot_period_ticks(_world([])), 36)
	W.run(w, 2, 0, W.S)
	var i := _voids(w)[0]
	assert_eq(w.projectiles.damage[i], 7, "x 0.7 a tick")
	assert_between(w.projectiles.life[i], 32, 33, "half the life")
	assert_almost_eq(VoidShots.read(w)[0]["aura"], 0.7, 0.001, "0.7 m")
	assert_almost_eq(VoidShots.read(w)[0]["pull"], 3.0, 0.001, "the pull is unchanged")
	var plain := _world([])
	W.run(w, 238, 0, W.S)
	W.run(plain, 240, 0, W.S)
	var made := W.events(w, SimEvent.Kind.SPAWN).size()
	var made_plain := W.events(plain, SimEvent.Kind.SPAWN).size()
	assert_eq([made, made_plain], [10, 7], "ten voids in 4 s against seven")


# --- V8 Split ---------------------------------------------------------------------------------------------------------
func test_v8_split_makes_mini_voids_1_5_m_out_at_even_angles_for_1_s_at_40_percent() -> void:
	var w := _world([&"split_shot"])
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	_until_gone(w, id)
	W.run(w, 2, 0, 0)
	var minis := []
	for i in _voids(w):
		if w.projectiles.vel_x[i] == 0.0:
			minis.append(i)
	assert_eq(minis.size(), 2, "Lv 1: 2 minis")
	if minis.size() < 2:
		return
	var p := w.projectiles
	var centre := (
		(
			Vector2(p.pos_x[minis[0]], p.pos_y[minis[0]])
			+ Vector2(p.pos_x[minis[1]], p.pos_y[minis[1]])
		)
		/ 2.0
	)
	assert_almost_eq(Vector2(p.pos_x[minis[0]], p.pos_y[minis[0]]).distance_to(centre), 1.5, 0.05)
	assert_eq(p.damage[minis[0]], 4, "40 % of 10")
	assert_between(p.life[minis[0]], 58, 60, "1.0 s")
	var read := VoidShots.read(w)
	var found := 0
	for v in read:
		if absf(v["aura"] - 0.6) < 0.001:
			found += 1
	assert_eq(found, 2, "a 0.6 m aura each")


func test_v8_splits_level_sets_two_three_or_four_minis_at_0_120_240() -> void:
	for lvl in [1, 2, 3]:
		var w := _world([&"split_shot"])
		CardLevels.set_level(w, W.item(w, &"split_shot"), lvl)
		assert_eq(VoidMods.mini_count(Modifiers.bolt(w)), lvl + 1, "Lv %d" % lvl)
		W.run(w, 1, 0, W.S)
		var id := w.projectiles.ids[_voids(w)[0]]
		_until_gone(w, id)
		W.run(w, 2, 0, 0)
		var minis := []
		for i in _voids(w):
			if w.projectiles.vel_x[i] == 0.0:
				minis.append(i)
		assert_eq(minis.size(), lvl + 1, "Lv %d: minis" % lvl)
	var w3 := _world([&"split_shot"])
	CardLevels.set_level(w3, W.item(w3, &"split_shot"), 2)
	W.run(w3, 1, 0, W.S)
	var id3 := w3.projectiles.ids[_voids(w3)[0]]
	_until_gone(w3, id3)
	W.run(w3, 2, 0, 0)
	var spots: Array[Vector2] = []
	for i in _voids(w3):
		if w3.projectiles.vel_x[i] == 0.0:
			spots.append(Vector2(w3.projectiles.pos_x[i], w3.projectiles.pos_y[i]))
	assert_eq(spots.size(), 3)
	assert_almost_eq(spots[0].distance_to(spots[1]), 1.5 * sqrt(3.0), 0.1, "120 degrees apart")
	assert_almost_eq(spots[1].distance_to(spots[2]), 1.5 * sqrt(3.0), 0.1)


# --- V9 Mine ----------------------------------------------------------------------------------------------------------
func test_v9_mine_stops_at_the_aim_point_holds_3_s_its_aura_ticking_then_ends() -> void:
	var w := _world([&"gun_mine"], [Vector2(3.0, 0.8)])
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	W.run(w, 25, 0, W.S)
	var i := _index_of(w, id)
	assert_gte(i, 0)
	assert_almost_eq(w.projectiles.pos_x[i], 3.0, 0.001, "the aim point: 300 cm out")
	assert_eq(w.projectiles.vel_x[i], 0.0, "still")
	assert_between(w.projectiles.life[i], 160, 180, "held for 3 s")
	var hits_a: int = _dealt(w, 1)[0]
	W.run(w, 120, 0, 0)
	var hits_b: int = _dealt(w, 1)[0]
	assert_gte(hits_b - hits_a, 9, "its aura ticks the whole time (every 12 ticks)")
	assert_gte(_index_of(w, id), 0, "still there 2.5 s on")
	var gone := _until_gone(w, id, 120)
	assert_between(gone, 195, 215, "gone 3 s after it stopped")


func test_v9_mine_stops_short_of_an_aim_point_beyond_its_reach() -> void:
	var w := _world([&"gun_mine"])
	for k in 75:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 2000, W.S, 0))
	var i := _voids(w)[0]
	assert_almost_eq(w.projectiles.vel_x[i], 0.0, 0.0001)
	assert_lt(w.projectiles.pos_x[i], 11.0, "where it would have landed, not off the map")
	assert_gt(w.projectiles.pos_x[i], 9.5)


# --- V10 Orbit --------------------------------------------------------------------------------------------------------
func test_v10_orbit_circles_the_hero_once_at_2_5_m_in_1_s_then_flies_out_along_the_aim() -> void:
	var w := _world([&"orbit_rounds"])
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_voids(w)[0]]
	var turned := 0.0
	var last := Vector2.ZERO
	for k in 60:
		W.run(w, 1, 0, W.S)
		var i := _index_of(w, id)
		var at := Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])
		assert_almost_eq(at.length(), 2.5, 0.06, "tick %d: on the circle" % k)
		if k > 0:
			turned += absf(last.angle_to(at))
		last = at
	assert_almost_eq(turned, TAU * 59.0 / 60.0, 0.15, "one full lap")
	W.run(w, 8, 0, 0)
	var i := _index_of(w, id)
	assert_gt(w.projectiles.vel_x[i], 0.0, "out along the aim")
	assert_almost_eq(w.projectiles.vel_y[i], 0.0, 0.001)
	assert_gt(w.projectiles.pos_x[i], 2.5)
	assert_eq(_until_gone(w, id), 1 + 127, "one extra second of life: 67 + 60 ticks")


# --- The bounds -------------------------------------------------------------------------------------------------------
func test_no_hero_has_more_than_six_live_voids_the_oldest_ending_first() -> void:
	var w := _world(
		[&"gun_rapid_fire", &"gun_backfire", &"split_shot", &"gun_echo", &"gun_ring", &"gun_twin"],
		[Vector2(4.0, 0.5)]
	)
	var most := 0
	var rows := 0
	for k in 600:
		W.run(w, 1, 0, W.S)
		most = maxi(most, _voids(w).size())
		rows = maxi(rows, w.mx.vm_kind.size())
		var ids := []
		for i in _voids(w):
			ids.append(w.projectiles.ids[i])
		assert_lte(ids.size(), 6, "tick %d" % w.tick)
	assert_eq(most, 6, "the cap was reached")
	assert_lte(rows, VoidMods.ROWS_MAX)


func test_the_cap_ends_the_oldest_first() -> void:
	var w := _world(
		[&"gun_rapid_fire", &"gun_backfire", &"split_shot", &"gun_echo", &"gun_ring", &"gun_twin"]
	)
	var prev := {}  # id -> its life left a tick ago
	var cut := 0
	for k in 300:
		W.run(w, 1, 0, W.S)
		var now := {}
		for i in _voids(w):
			now[w.projectiles.ids[i]] = w.projectiles.life[i]
		for id: int in prev:
			if not now.has(id) and prev[id] > 1:  # gone with life left: the cap ended it
				cut += 1
				for older: int in prev:
					if older < id:
						assert_false(
							now.has(older), "tick %d: older void %d went first" % [w.tick, older]
						)
		prev = now
	assert_gt(cut, 0, "the cap did end some")


func test_a_card_void_is_deterministic_and_its_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(5.0, 1.0), Vector2(6.0, -1.0), Vector2(-3.0, 2.0), Vector2(7.0, 3.0)]
	var cards := [&"gun_homing", &"gun_echo", &"gun_ring", &"split_shot", &"gun_mine"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 150, 0, W.S, 300)
	W.run(b, 150, 0, W.S, 300)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.vm_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.vm_at, a.mx.vm_at)
	assert_eq(c.mx.vm_stop, a.mx.vm_stop)
	assert_eq(c.mx.vm_hit, a.mx.vm_hit)
	assert_eq(c.mx.vm_kind, a.mx.vm_kind)
	W.run(a, 120, 0, W.S, 300)
	W.run(c, 120, 0, W.S, 300)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_rows_are_dropped_when_the_shot_is_no_void_any_more() -> void:
	var w := _world([&"gun_mine"])
	W.run(w, 30, 0, W.S)
	assert_true(w.mx.vm_touched())
	Shop.remove_item(w, W.item(w, &"gun_void"))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.vm_touched())
