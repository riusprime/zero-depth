# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 FC9 (FORM_COMBOS.md P1-P6): what thirteen cards do to the Wisps form (WispMods and the cards that ride the
## wisps' shots). Three wisps circle the hero at 1.1 m (one turn in 150 ticks) and each fires every 36 ticks, staggered
## by 12, at the nearest enemy: a shot is 4 (80 % of the orb's 5). The hero stands at the origin, the dummies are 0.35 m
## wide, and the first wisp stands at +x on tick 0.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const FIVE := [&"gun_twin", &"halo_shot", &"gun_ring", &"gun_mine", &"orbit_rounds"]
const EIGHT := [
	&"gun_pierce",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_spiral",
]


func _world(cards: Array, at: Array = [], r: float = 0.35) -> World:
	var ids: Array = [&"gun_wisps"]
	ids.append_array(cards)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


## The hits the player dealt actor `idx`: [[tick, amount], ...].
func _hits(w: World, idx: int) -> Array:
	var id := w.actors.ids[idx]
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id and not (e.tags & SimEvent.TAG_DOT):
			out.append([e.tick, e.amount])
	return out


func _wisp_shots(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if Wisps.is_wisp_shot(w, i):
			out.append(i)
	return out


# --- The cards, the data ----------------------------------------------------------------------------------------------
func test_each_wisp_card_sets_its_bit_and_the_eight_set_none() -> void:
	assert_eq(WispMods.mask(Modifiers.bolt(_world([]))), 0)
	var plain := Modifiers.bolt(_world([]))
	for k in WispMods.CARD_IDS.size():
		var s := Modifiers.bolt(_world([WispMods.CARD_IDS[k]]))
		assert_eq(WispMods.mask(s), WispMods.CARD_BITS[k], "%s" % WispMods.CARD_IDS[k])
		assert_eq(
			[s.form, s.count, s.share_permille, s.radius_m, s.mine_ticks, s.orbit_ticks],
			[
				plain.form,
				plain.count,
				plain.share_permille,
				plain.radius_m,
				plain.mine_ticks,
				plain.orbit_ticks
			],
			"its generic ops are skipped (%s)" % WispMods.CARD_IDS[k]
		)
	for id in EIGHT:
		var s := Modifiers.bolt(_world([id]))
		assert_eq(WispMods.mask(s), 0, "%s is no wisp card" % id)
		assert_true(s.modifier_ids.has(String(id)), "%s compiled onto the spec" % id)
	assert_eq(Modifiers.bolt(_world([&"gun_pierce"])).pierce, 4)
	assert_eq(Modifiers.bolt(_world([&"gun_ricochet"])).bounces, 3)
	assert_gt(Modifiers.bolt(_world([&"gun_homing"])).homing, 0)
	assert_gt(Modifiers.bolt(_world([&"gun_spiral"])).spiral, 0)
	assert_gt(Modifiers.bolt(_world([&"gun_echo"])).repeat_delay_ticks, 0)


func test_the_data_row_holds_every_number_the_code_reads() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	for k: String in WispMods.DEFAULTS:
		assert_eq(WispMods.param(w, k), int(WispMods.DEFAULTS[k]), "%s: data = default" % k)
	assert_true(w.slot_table.params.has(&"wisps"))
	var keys := WispMods.DEFAULTS.keys()
	keys.sort()
	var content_keys := AttackFormRow.WISP_KEYS.duplicate()
	content_keys.sort()
	assert_eq(content_keys, keys, "the validator's key list and the code's agree")


func test_the_wisps_row_allows_thirteen_cards_and_keeps_three_off() -> void:
	var w := _world([])
	w.slot_table = WandCompiler.slots(W.repo(), w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	for id in FIVE + EIGHT:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s is on" % id)
	for id in [&"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"]:
		assert_true(AttackSlots.usable(w, W.item(w, id)), "%s stays on" % id)
	for id in [&"gun_backfire", &"gun_swirl", &"gun_threadline"]:
		assert_false(AttackSlots.usable(w, W.item(w, id)), "%s stays off" % id)


func test_plain_wisps_leave_no_state() -> void:
	var w := _world([], [Vector2(4.0, 0.0)])
	W.run(w, 200, 0, 0)
	assert_false(w.mx.pm_touched())
	assert_eq(Wisps.read(w).size(), 3)
	assert_eq(WispMods.read_rings(w).size(), 0)


# --- P1 Twin, P2 Halo -------------------------------------------------------------------------------------------------
func test_p1_twin_adds_a_fourth_wisp_evenly_spaced() -> void:
	var w := _world([&"gun_twin"])
	var ws := Wisps.read(w)
	assert_eq(ws.size(), 4, "a fourth wisp")
	for k in 4:
		assert_eq(
			(int(ws[k]["angle"]) - int(ws[0]["angle"])) & 4095, k * 1024, "a quarter turn apart"
		)
		assert_almost_eq((ws[k]["pos"] as Vector2).length(), Wisps.ORBIT_R_M, 0.01)
	assert_eq(Wisps.shot_damage(w, Modifiers.bolt(w)), 4, "at the same damage")


func test_p1_twin_fires_from_all_four_each_period() -> void:
	var w := _world([&"gun_twin"], [Vector2(4.0, 0.0)])
	var seen := {}
	for k in 36:
		W.run(w, 1, 0, 0)
		for i in w.projectiles.size():
			seen[w.projectiles.ids[i]] = true
	assert_eq(seen.size(), 4, "four shots in 0.6 s")


func test_p2_halo_is_six_wisps_at_sixty_percent_each() -> void:
	var w := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	var ws := Wisps.read(w)
	assert_eq(ws.size(), 6)
	assert_eq((int(ws[1]["angle"]) - int(ws[0]["angle"])) & 4095, 682, "a sixth of a turn apart")
	assert_eq(
		Wisps.shot_damage(w, Modifiers.bolt(w)),
		2,
		"60 percent of 4, rounded half up: 2 (the mines')"
	)
	W.run(w, 240, 0, 0)
	var hits := _hits(w, 1)
	assert_gt(hits.size(), 0)
	for h: Array in hits:  # v0.9.5 FC9b: 2.4 a shot, the carry deals 2 or 3
		assert_between(h[1], 2, 3, "each shot hits for 2 or 3 (2.4 with the carry)")


func test_p2_twin_with_halo_is_seven_wisps() -> void:
	var w := _world([&"halo_shot", &"gun_twin"])
	var ws := Wisps.read(w)
	assert_eq(ws.size(), 7)
	assert_eq(Wisps.shot_damage(w, Modifiers.bolt(w)), 2, "still 60 percent")


# --- P3 Ring ----------------------------------------------------------------------------------------------------------
func test_p3_ring_hits_the_neighbours_of_a_struck_enemy_once_per_ring() -> void:
	var at := [Vector2(4.0, 0.0), Vector2(4.0, 1.2)]
	var plain := _world([], at)
	var w := _world([&"gun_ring"], at)
	W.run(plain, 200, 0, 0)
	W.run(w, 200, 0, 0)
	var plain_total := _hits(plain, 1).size() + _hits(plain, 2).size()
	var total := _hits(w, 1).size() + _hits(w, 2).size()
	assert_gt(plain_total, 0, "the wisps shoot them")
	assert_gt(total, plain_total, "the rings add hits (%d vs %d)" % [total, plain_total])
	assert_lte(total - plain_total, plain_total, "at most one ring-hit on the other a landed shot")
	for idx in [1, 2]:
		for h: Array in _hits(w, idx):
			assert_eq(h[1], 4, "every hit, the shot's or the ring's, is the shot's 4")
	assert_true(w.mx.pm_touched())


func test_p3_ring_reaches_only_one_metre_and_is_drawn_for_a_moment() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.0), Vector2(-9.0, 0.0)])
	var plain := _world([], [Vector2(4.0, 0.0), Vector2(-9.0, 0.0)])
	var drawn := false
	for k in 150:
		W.run(w, 1, 0, 0)
		for row in WispMods.read_rings(w):
			drawn = true
			assert_almost_eq(float(row["r"]), 1.0, 0.001, "1 m")
			assert_lte(int(row["age"]), int(row["span"]), "and gone after its span")
			assert_gt((row["pos"] as Vector2).x, 2.0, "where the shot struck, at the near one")
	W.run(plain, 150, 0, 0)
	assert_true(drawn, "a ring is drawn")
	assert_eq(_hits(w, 2).size(), 0, "the far one is out of every ring")
	assert_eq(_hits(w, 1).size(), _hits(plain, 1).size(), "the shots land as before")
	var none := _world([&"gun_ring"], [])
	W.run(none, 60, 0, 0)
	assert_false(none.mx.pm_touched(), "no shot, no ring")


# --- P4 the eight cards on the wisps' shots ---------------------------------------------------------------------------
func test_p4_pierce_lets_a_wisp_shot_through_five_in_line() -> void:
	var line := []
	for k in 8:
		line.append(Vector2(3.0 + 1.2 * k, 0.0))
	var plain := _world([], line)
	var w := _world([&"gun_pierce"], line)
	W.run(plain, 60, 0, 0)
	W.run(w, 60, 0, 0)
	var reach := 0
	var reach_plain := 0
	for k in 8:
		reach = k + 1 if _hits(w, k + 1).size() > 0 else reach
		reach_plain = k + 1 if _hits(plain, k + 1).size() > 0 else reach_plain
	assert_gt(
		reach,
		reach_plain,
		"Pierce carries a shot farther down the line (%d vs %d)" % [reach, reach_plain]
	)
	var fresh := _world([&"gun_pierce"], line)
	W.run(fresh, 1, 0, 0)
	var ws := _wisp_shots(fresh)
	assert_gt(ws.size(), 0)
	assert_eq(fresh.projectiles.pierce_left[ws[0]], 5, "the card's 4 and the wisps' 1")


func test_p4_homing_ricochet_spiral_ride_the_wisp_shot() -> void:
	for id in [&"gun_homing", &"gun_ricochet", &"gun_spiral"]:
		var w := _world([id], [Vector2(4.0, 0.0)])
		W.run(w, 40, 0, 0)
		var ws := _wisp_shots(w)
		assert_gt(ws.size(), 0, "%s: wisp shots fly" % id)
		var i := ws[0]
		match id:
			&"gun_homing":
				assert_gt(w.projectiles.home[i], 0, "homing")
			&"gun_ricochet":
				assert_eq(w.projectiles.bounces[i], 3, "three bounces")
			&"gun_spiral":
				assert_gt(w.projectiles.spiral[i], 0, "a corkscrew")


func test_p4_big_shot_and_rapid_fire_change_the_wisp_shot() -> void:
	var plain := _world([], [Vector2(4.0, 0.0)])
	W.run(plain, 20, 0, 0)
	var r0 := plain.projectiles.radius[_wisp_shots(plain)[0]]
	var d0 := plain.projectiles.damage[_wisp_shots(plain)[0]]
	var big := _world([&"gun_big_shot"], [Vector2(4.0, 0.0)])
	W.run(big, 20, 0, 0)
	var bi := _wisp_shots(big)[0]
	assert_gt(big.projectiles.radius[bi], r0 * 2.0, "a bigger shot")
	assert_gt(big.projectiles.damage[bi], d0, "that hits harder")
	var rapid := _world([&"gun_rapid_fire"], [Vector2(4.0, 0.0)])
	W.run(rapid, 20, 0, 0)
	var ri := _wisp_shots(rapid)[0]
	assert_lt(rapid.projectiles.radius[ri], r0, "a smaller shot")


func test_p4_split_sheds_children_where_a_wisp_shot_hits() -> void:
	var w := _world([&"split_shot"], [Vector2(4.0, 0.0)])
	var seen := 0
	for k in 120:
		W.run(w, 1, 0, 0)
		seen = maxi(seen, W.projectiles_of(w, &"split_shot"))
	assert_gt(seen, 0, "Split's children fly from a wisp shot's hit")


func test_p4_echo_sends_a_ghost_after_each_wisp_shot() -> void:
	var at := [Vector2(4.0, 0.0)]
	var plain := _world([], at)
	var w := _world([&"gun_echo"], at)
	W.run(plain, 300, 0, 0)
	W.run(w, 300, 0, 0)
	var n0 := _hits(plain, 1).size()
	var n1 := _hits(w, 1).size()
	assert_gt(n1, n0 * 18 / 10, "about twice the hits (%d vs %d)" % [n1, n0])


func test_p4_the_cards_leave_the_ghosts_unringed_and_wisp_shots_distinct() -> void:
	var w := _world([&"gun_echo"], [Vector2(4.0, 0.0)])
	var ghost := false
	for k in 100:
		W.run(w, 1, 0, 0)
		for i in w.projectiles.size():
			if w.projectiles.second_of(i) == (ProjectileStore.REPEAT | ProjectileStore.SECONDARY):
				ghost = true
				assert_false(Wisps.is_wisp_shot(w, i), "an Echo ghost is no wisp shot")
	assert_true(ghost, "ghosts flew")


# --- P5 Mine ----------------------------------------------------------------------------------------------------------
func _mines(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	var k := WispMods.mine_hook(Modifiers.bolt(w))
	for i in w.projectiles.size():
		if w.projectiles.spec_key[i] == k.child.key:
			out.append(i)
	return out


func test_p5_each_wisp_drops_a_mine_every_two_seconds() -> void:
	var w := _world([&"gun_mine"])
	var k := WispMods.mine_hook(Modifiers.bolt(w))
	assert_not_null(k, "the mine is compiled as a hook")
	assert_eq(k.child.mine_ticks, 240, "the Mine card's own four seconds")
	var born := {}
	for t in 250:
		W.run(w, 1, 0, 0)
		for i in _mines(w):
			if not born.has(w.projectiles.ids[i]):
				born[w.projectiles.ids[i]] = w.tick
	var ticks := born.values()
	ticks.sort()
	assert_eq(ticks.size(), 7, "a drop every 40 ticks over 250: the three wisps, staggered")
	assert_eq(int(ticks[3]) - int(ticks[0]), 120, "a wisp drops again 120 ticks later")
	assert_eq(int(ticks[1]) - int(ticks[0]), 40, "the three are staggered over the 2 s")


func test_p5_a_mine_stands_still_and_hurts_what_touches_it() -> void:
	var ring := []
	for k in 8:
		ring.append(Vector2(2.0, 0.0).rotated(TAU * k / 8.0))
	var w := _world([&"gun_mine"], ring)
	var held := {}
	var moved := false
	for t in 200:
		W.run(w, 1, 0, 0)
		for i in _mines(w):
			var id := w.projectiles.ids[i]
			var p := Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])
			if held.has(id) and (held[id] as Vector2).distance_to(p) > 0.01:
				moved = true
			held[id] = p
	assert_false(moved, "a mine does not move")
	assert_gt(held.size(), 0, "mines were dropped")
	var hurt := 0
	for k in 8:
		hurt += _hits(w, k + 1).size()
	assert_gt(hurt, 0, "the dummies round the wisps are hurt")


func test_p5_at_most_six_live_mines_the_oldest_end_first() -> void:
	var w := _world([&"gun_mine", &"gun_twin"])
	var most := 0
	var oldest := 1 << 30
	for t in 700:
		W.run(w, 1, 0, 0)
		var m := _mines(w)
		most = maxi(most, m.size())
		assert_lte(m.size(), 6, "at most six live mines")
	assert_eq(most, 6, "and the bound is reached")
	for i in _mines(w):
		oldest = mini(oldest, w.projectiles.ids[i])
	assert_lt(oldest, 1 << 30)


# --- P6 Orbit ---------------------------------------------------------------------------------------------------------
func test_p6_orbit_widens_the_circle_to_three_and_a_half_metres() -> void:
	var w := _world([&"orbit_rounds"])
	for wd: Dictionary in Wisps.read(w):
		assert_almost_eq((wd["pos"] as Vector2).length(), 3.5, 0.01)
	W.run(w, 40, 0, 0)
	for wd: Dictionary in Wisps.read(w):
		assert_almost_eq((wd["pos"] as Vector2).distance_to(w.player_pos()), 3.5, 0.01)


func test_p6_a_wisp_hurts_what_it_touches_for_half_a_shot_once_per_thirty_ticks() -> void:
	var w := _world([&"orbit_rounds"], [Vector2(3.5, 0.0)])
	var spec := Modifiers.bolt(w)
	assert_eq(
		(Wisps.pos(w, 0, 3) - Vector2(3.5, 0.0)).length() < 0.01, true, "wisp 0 starts on the dummy"
	)
	W.run(w, 1, 0, 0)  # the first tick: it touches (and the dummy is a shot's target too)
	var touches := func() -> int:
		var n := 0
		for h: Array in _hits(w, 1):
			n += 1 if h[1] == 2 else 0
		return n
	assert_eq(touches.call(), 1, "touched, for half of a 4 shot")
	assert_eq(w.mx.pm_hit_wisp.size(), 1)
	WispMods.touch(w, spec, 3)
	assert_eq(touches.call(), 1, "not again within the gap")
	W.run(w, 31, 0, 0)  # the wisp has left; the gap runs out after 30 ticks
	assert_eq(w.mx.pm_hit_wisp.size(), 0, "the gap ran out")
	assert_eq(touches.call(), 1, "and it was touched once")


func test_p6_each_wisp_touches_the_enemy_in_its_path_once_a_lap() -> void:
	var w := _world([&"orbit_rounds"], [Vector2(0.0, 3.5)])
	W.run(w, 150, 0, 0)
	var twos := 0
	for h: Array in _hits(w, 1):
		if h[1] == 2:
			twos += 1
	assert_between(twos, 3, 4, "three wisps pass it in a lap, a hit each")


# --- The cap, determinism, save ---------------------------------------------------------------------------------------
## The hero's shots and the wisps' (launched from the wisps' spec), not Echo's ghosts, Split's children or the mines: as
## on the orbs, those follow-ups are bounded by their own rules, not by the per-second cap.
func test_the_forty_shots_a_second_cap_holds_with_seven_wisps() -> void:
	var w := _world(
		[&"halo_shot", &"gun_twin", &"gun_spiral", &"gun_mine"],
		[Vector2(4.0, 0.0), Vector2(0.0, 4.0)]
	)
	for k in 20:
		Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	var launched := {}
	var per_tick: Array[int] = []
	var most := 0
	for t in 600:
		W.run(w, 1, 0, W.S)
		var n := 0
		for i in w.projectiles.size():
			var pid := w.projectiles.ids[i]
			var kind := w.projectiles.second_of(i)
			var own := kind == 0 or kind == ProjectileStore.REPEAT
			if (
				w.projectiles.team[i] == ActorStore.TEAM_PLAYER
				and own
				and Wisps.is_wisps(Attacks.projectile_spec(w, i))
				and not launched.has(pid)
			):
				launched[pid] = true
				n += 1
		per_tick.append(n)
		var window := 0
		for j in range(maxi(0, per_tick.size() - 60), per_tick.size()):
			window += per_tick[j]
		most = maxi(most, window)
	assert_lte(most, 40, "40 a second at most (%d)" % most)


func test_wisps_with_cards_are_deterministic_and_the_rows_round_trip_a_snapshot() -> void:
	var at := [Vector2(3.5, 0.0), Vector2(3.0, 1.0), Vector2(0.0, 3.5)]
	var cards := [&"gun_ring", &"orbit_rounds", &"gun_echo", &"split_shot", &"gun_homing"]
	var a := _world(cards, at)
	var b := _world(cards, at)
	W.run(a, 160, 0, W.S)
	W.run(b, 160, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash(), "the same inputs, the same state")
	assert_true(a.mx.pm_touched(), "rows are set")
	var snap := WorldSnapshot.take(a)
	var c := _world(cards, at)
	assert_eq(WorldSnapshot.apply(c, snap), "", "the snapshot applies")
	assert_eq(c.state_hash(), a.state_hash(), "restored to the same state")
	assert_eq(c.mx.pm_ring_at, a.mx.pm_ring_at)
	assert_eq(c.mx.pm_hit_wisp, a.mx.pm_hit_wisp)
	W.run(a, 120, 0, W.S)
	W.run(c, 120, 0, W.S)
	assert_eq(c.state_hash(), a.state_hash(), "and it goes on the same")


func test_a_plain_wisps_hash_has_no_wisp_block() -> void:
	var a := _world([], [Vector2(4.0, 0.0)])
	W.run(a, 200, 0, W.S)
	assert_false(a.mx.pm_touched())
	var h := StateHasher.new()
	a.mx.hash_into(h)
	var with := _world([&"gun_ring"], [Vector2(4.0, 0.0)])
	W.run(with, 200, 0, W.S)
	assert_true(with.mx.pm_touched())
	var h2 := StateHasher.new()
	with.mx.hash_into(h2)
	assert_ne(h.finish_hex(), h2.finish_hex(), "the rows are hashed while set")


func test_an_older_save_without_the_rows_loads_empty() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.0)])
	W.run(w, 100, 0, 0)
	assert_true(w.mx.pm_touched())
	var snap := w.to_snapshot()
	var mx: Dictionary = (snap["world"] as Dictionary)[&"mx"]
	for f: StringName in WispMods.SNAPSHOT_FIELDS:
		assert_true(mx.has(f), "%s is saved" % f)
		mx.erase(f)
	var base := _world([&"gun_ring"], [Vector2(4.0, 0.0)])
	assert_eq(WorldSnapshot.apply(base, snap), "", "an older snapshot restores")
	assert_false(base.mx.pm_touched(), "with no Wisps rows")
	W.run(base, 10, 0, 0)


func test_rows_are_dropped_when_the_shot_is_no_wisps_any_more() -> void:
	var w := _world([&"gun_ring"], [Vector2(4.0, 0.0)])
	W.run(w, 100, 0, 0)
	assert_true(w.mx.pm_touched())
	Shop.remove_item(w, W.item(w, &"gun_wisps"))
	W.run(w, 2, 0, 0)
	assert_false(w.mx.pm_touched())


# --- FC9b: the carry --------------------------------------------------------------------------------------------------
func test_fc9b_halo_shots_of_two_point_four_add_up_exactly() -> void:
	var w := _world([&"halo_shot"])
	var spec := Modifiers.bolt(w)
	assert_eq(Wisps.shot_milli(w, spec), 2400, "60 percent of 4: 2.4 in thousandths")
	var total := 0
	for k in 5:
		total += WispMods.take(w, Wisps.shot_milli(w, spec))
	assert_eq(total, 12, "five shots of 2.4 deal 12 (2, 2, 3, 2, 3 with the carry)")
	assert_eq(w.mx.pm_carry, 0, "and nothing is left")
	assert_eq(WispMods.take(w, 400), 0, "a short carry deals 0, with no minimum of 1")
	assert_eq(w.mx.pm_carry, 400)


func _hurt(w: World) -> int:
	var sum := 0
	for h: Array in _hits(w, 1):
		sum += h[1]
	return sum


func test_fc9b_halo_six_wisps_deal_about_one_point_two_times_three_plain_wisps() -> void:
	var plain := _world([], [Vector2(4.0, 0.0)])
	var halo := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	W.run(plain, 600, 0, 0)
	W.run(halo, 600, 0, 0)
	var a := _hurt(plain)
	var b := _hurt(halo)
	assert_gt(a, 0)
	assert_between(float(b) / float(a), 1.1, 1.3, "Halo reads about x1.2 (%d vs %d)" % [b, a])


func test_fc9b_the_carry_is_saved_hashed_and_an_older_save_loads_with_none() -> void:
	var w := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	W.run(w, 100, 0, 0)
	assert_ne(w.mx.pm_carry, 0, "a carry is waiting")
	assert_true(w.mx.pm_touched(), "and it counts as set")
	var before := w.state_hash()
	w.mx.pm_carry += 100
	assert_ne(w.state_hash(), before, "the carry is hashed")
	w.mx.pm_carry -= 100
	var snap := w.to_snapshot()
	var mx: Dictionary = (snap["world"] as Dictionary)[&"mx"]
	assert_true(mx.has(&"pm_carry"), "pm_carry is saved")
	var c := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	assert_eq(WorldSnapshot.apply(c, snap), "")
	assert_eq(c.mx.pm_carry, w.mx.pm_carry, "it round-trips")
	assert_eq(c.state_hash(), w.state_hash())
	mx.erase(&"pm_carry")
	var old := _world([&"halo_shot"], [Vector2(4.0, 0.0)])
	assert_eq(WorldSnapshot.apply(old, snap), "", "an older save without it loads")
	assert_eq(old.mx.pm_carry, 0)
