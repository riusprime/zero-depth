# gdlint: disable=max-public-methods
extends GutTest
## v0.9.5 EE3 (ELEMENTS.md X1-X10): two elements held at Lv 3 turn on one named pair rule (ElementPairs). Each pair is
## on only with both elements at Lv 3 and does exactly its one thing; its work-doing rules fire 4 times a second.

const W := preload("res://tests/support/mx4_world.gd")
const BIG := 9000000
const CARDS := ElementPairs.CARDS


## A Gun world holding `elements` (ElementPairs element codes) at `lv` each, the pairs' table loaded, compiled.
func _world(elements: Array, enemies: Array, lv: int = 3) -> World:
	var ids: Array = []
	for e: int in elements:
		ids.append(CARDS[e])
	var w := W.world(&"gun", ids, enemies)
	w.pair_table = WandCompiler.pairs(W.repo())
	for id: StringName in ids:
		CardLevels.set_level(w, W.item(w, id), lv)
	ElementPairs.refresh(w)
	W.run(w, 1)  # the actor grid (enemies_near) is built by a tick
	return w


func _pair(x: int, enemies: Array, lv: int = 3) -> World:
	return _world(ElementPairs.ELEMENTS[x], enemies, lv)


## The same pair with its second element at Lv 2: the pair is off, everything else equal.
func _off(x: int, enemies: Array) -> World:
	var w := _pair(x, enemies)
	CardLevels.set_level(w, W.item(w, CARDS[ElementPairs.ELEMENTS[x][1]]), 2)
	ElementPairs.refresh(w)
	return w


func _hit(w: World, i: int, amount: int = 1000, tags: int = SimEvent.TAG_PROJECTILE) -> int:
	var a := w.actors
	return Damage.hit(w, i, amount, a.ids[0], a.ids[0], w.take_root(), tags, a.pos(0), a.pos(i))


func _burn(w: World, i: int, stacks: int = 1) -> void:
	Engines.add_burn(w, i, stacks, w.take_root(), &"test")


func _poison(w: World, i: int, stacks: int = 1) -> void:
	Venom.add(w, i, stacks, w.take_root())


func _bleed(w: World, i: int, stacks: int = 1) -> void:
	Engines.add_bleed(w, i, stacks, w.take_root())


func _freeze(w: World, i: int, ticks: int = 600) -> void:
	w.actors.frozen_t[i] = ticks


## The DAMAGE events dealt to the enemy at `i`, with `effect`.
func _dmg(w: World, i: int, effect: StringName = &"*") -> Array[SimEvent]:
	var id := w.actors.ids[i]
	var out: Array[SimEvent] = []
	for e in W.events(w, SimEvent.Kind.DAMAGE, effect):
		if e.target_id == id:
			out.append(e)
	return out


func _bursts(w: World) -> Array[SimEvent]:
	return W.events(w, SimEvent.Kind.STATUS_APPLY, SimEvent.EFFECT_PAIR_BURST)


## Fires the Gun east until the first chain hit; the targets of every TAG_CHAIN hit (by actor id), in order.
func _chain_targets(w: World, ticks: int = 40) -> Array:
	var first := -1
	for k in ticks:
		W.run(w, 1, 0, W.S, 0)
		for e in W.events(w, SimEvent.Kind.DAMAGE, &"*"):
			if e.owner_id == w.actors.ids[0] and first < 0:
				first = e.tick
		if first >= 0:
			break
	var out := []
	for e in W.events(w, SimEvent.Kind.DAMAGE, &"*"):
		if e.tick == first and e.tags & SimEvent.TAG_CHAIN:
			out.append(e.target_id)
	return out


# --- On and off ------------------------------------------------------------------------------------------------
func test_each_pair_is_on_only_with_both_elements_at_lv3() -> void:
	for x in ElementPairs.COUNT:
		var both := _pair(x, [])
		assert_eq(
			both.pair_mask,
			1 << x,
			"%s: exactly its own bit with both at Lv 3" % ElementPairs.IDS[x]
		)
		assert_true(ElementPairs.on(both, x))
		var lv2 := _pair(x, [], 2)
		assert_eq(lv2.pair_mask, 0, "%s: off with both at Lv 2" % ElementPairs.IDS[x])
		assert_eq(_off(x, []).pair_mask, 0, "%s: off with one at Lv 2" % ElementPairs.IDS[x])
		var first: int = ElementPairs.ELEMENTS[x][0]
		assert_eq(
			_world([first], []).pair_mask, 0, "%s: off with one element alone" % ElementPairs.IDS[x]
		)


func test_a_world_without_the_table_has_no_pairs() -> void:
	var w := W.world(&"gun", [&"ember_core", &"frost_core"], [])
	for id: StringName in [&"ember_core", &"frost_core"]:
		CardLevels.set_level(w, W.item(w, id), 3)
	ElementPairs.refresh(w)
	assert_eq(w.pair_mask, 0)
	assert_false(ElementPairs.on(w, ElementPairs.X1))


func test_the_ten_pairs_are_distinct_and_cover_every_two_elements() -> void:
	var seen := {}
	for x in ElementPairs.COUNT:
		var a: int = ElementPairs.ELEMENTS[x][0]
		var b: int = ElementPairs.ELEMENTS[x][1]
		seen["%d-%d" % [mini(a, b), maxi(a, b)]] = true
	assert_eq(seen.size(), 10, "5 elements make 10 distinct pairs")
	assert_eq(ElementPairs.IDS.size(), 10)


func test_a_pair_turning_on_announces_itself_once() -> void:
	var w := _world([ElementPairs.FIRE, ElementPairs.FROST], [], 2)
	assert_eq(W.events(w, SimEvent.Kind.PAIR_ON).size(), 0, "nothing at Lv 2")
	for id: StringName in [&"ember_core", &"frost_core"]:
		CardLevels.set_level(w, W.item(w, id), 3)
	Modifiers.book(w)
	var ev := W.events(w, SimEvent.Kind.PAIR_ON)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].amount, ElementPairs.X1)
	assert_eq(ev[0].effect_id, &"thermal_shock")
	Modifiers.invalidate(w)
	Modifiers.book(w)
	assert_eq(W.events(w, SimEvent.Kind.PAIR_ON).size(), 1, "a recompile does not repeat it")
	CardLevels.set_level(w, W.item(w, &"frost_core"), 2)
	Modifiers.book(w)
	assert_eq(w.pair_mask, 0, "and it turns off with the card")


func test_the_pairs_have_text_in_both_languages_within_60_chars() -> void:
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	var rows := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	for x in ElementPairs.COUNT:
		for key: StringName in [ElementPairs.name_key(x), ElementPairs.desc_key(x)]:
			assert_true(rows.has(String(key)), "%s has a row" % key)
			for col in [1, 2]:
				var s: String = rows[String(key)][col]
				assert_false(s.is_empty(), "%s column %d" % [key, col])
				if String(key).ends_with("_DESC"):
					assert_lte(s.length(), 60, "%s column %d is %d chars" % [key, col, s.length()])


# --- X1 Thermal Shock ------------------------------------------------------------------------------------------
func test_x1_a_hit_on_a_burning_frozen_enemy_bursts_x3_in_1_5_m() -> void:
	var w := _pair(
		ElementPairs.X1, [[Vector2(4, 0), BIG], [Vector2(4, 1.2), BIG], [Vector2(4, 4), BIG]]
	)
	_burn(w, 1)
	_freeze(w, 1)
	_hit(w, 1)
	var direct := _dmg(w, 1, &"*")
	var first := direct[0].amount
	assert_eq(w.actors.burn_stacks[1], 0, "the burn is gone")
	assert_eq(w.actors.frozen_t[1], 0, "and the freeze")
	var near := _dmg(w, 2, SimEvent.EFFECT_PAIR_BURST)
	assert_eq(near.size(), 1, "the neighbour at 1.2 m takes the burst")
	assert_eq(near[0].amount, first * 3, "x3 the hit's damage")
	assert_eq(_dmg(w, 3, SimEvent.EFFECT_PAIR_BURST).size(), 0, "the one at 4 m does not")
	assert_eq(_bursts(w).size(), 1)
	assert_eq(_bursts(w)[0].amount, 1500, "the burst event carries its radius in mm")


func test_x1_needs_both_statuses_and_the_pair() -> void:
	var w := _pair(ElementPairs.X1, [[Vector2(4, 0), BIG], [Vector2(4, 1.2), BIG]])
	_burn(w, 1)
	_hit(w, 1)
	_freeze(w, 2)
	_hit(w, 2)
	assert_eq(_bursts(w).size(), 0, "burning alone or frozen alone: no burst")
	var off := _off(ElementPairs.X1, [[Vector2(4, 0), BIG], [Vector2(4, 1.2), BIG]])
	_burn(off, 1)
	_freeze(off, 1)
	_hit(off, 1)
	assert_eq(_bursts(off).size(), 0, "the pair off: no burst")


func test_x1_fires_four_times_a_second_at_most() -> void:
	var enemies := []
	for k in 6:
		enemies.append([Vector2(4, 3.0 * k), BIG])
	var w := _pair(ElementPairs.X1, enemies)
	for i in range(1, 7):
		_burn(w, i)
		_freeze(w, i)
		_hit(w, i)
	assert_eq(_bursts(w).size(), 4, "6 qualifying hits in one tick: 4 bursts")
	W.run(w, 61)
	w.actors.frost_stacks[5] = 0  # (an earlier hit's frost would break it on the spot: Thermal Break)
	w.actors.frost_t[5] = 0
	_burn(w, 5)
	_freeze(w, 5)
	_hit(w, 5)
	assert_eq(_bursts(w).size(), 5, "a second later there is room again")


# --- X2 Toxic Fumes --------------------------------------------------------------------------------------------
func test_x2_a_poisoned_enemy_catching_fire_leaves_a_cloud_that_poisons_once_a_second() -> void:
	var w := _pair(
		ElementPairs.X2, [[Vector2(4, 0), BIG], [Vector2(4, 1.5), BIG], [Vector2(4, 5), BIG]]
	)
	_burn(w, 2)
	assert_eq(w.pair_clouds.size(), 0, "a burning enemy that is not poisoned: no cloud")
	_poison(w, 1)
	assert_eq(w.actors.poison_stacks[2], 0)
	_burn(w, 1)
	assert_eq(w.pair_clouds.size(), 3, "the poisoned one catching fire lays a cloud")
	assert_eq(w.pair_clouds[2], 180, "for 3 s")
	var a := w.actors
	W.run(w, 12)
	assert_eq(a.poison_stacks[2], 1, "the neighbour at 1.5 m is poisoned (1 stack)")
	assert_eq(a.poison_stacks[3], 0, "the one at 5 m is not (the cloud is 2 m)")
	W.run(w, 40)
	assert_eq(a.poison_stacks[2], 1, "once a second: no second stack yet")
	W.run(w, 40)
	assert_gte(a.poison_stacks[2], 2, "a second later it is poisoned again")
	W.run(w, 120)
	assert_eq(w.pair_clouds.size(), 0, "the cloud is gone after 3 s")


func test_x2_off_without_the_pair() -> void:
	var w := _off(ElementPairs.X2, [[Vector2(4, 0), BIG]])
	_poison(w, 1)
	_burn(w, 1)
	assert_eq(w.pair_clouds.size(), 0)


func test_x2_clouds_are_budgeted_and_capped() -> void:
	var enemies := []
	for k in 6:
		enemies.append([Vector2(4, 3.0 * k), BIG])
	var w := _pair(ElementPairs.X2, enemies)
	for i in range(1, 7):
		_poison(w, i)
		_burn(w, i)
	assert_eq(w.pair_clouds.size(), 12, "6 fires in one tick: 4 clouds")


# --- X3 / X8 / X9: the chain -----------------------------------------------------------------------------------
func _line() -> Array:
	return [[Vector2(3, 0), BIG], [Vector2(3, 2.5), BIG], [Vector2(3, 5), BIG]]


func _jumped(w: World, status: PackedInt32Array) -> int:
	var n := 0
	for t in _chain_targets(w):
		var i := w.actors.index_of(t)
		if i > 1 and status[i] > 0:
			n += 1
	return n


func test_x3_chain_jumps_set_enemies_on_fire() -> void:
	var on := _pair(ElementPairs.X3, _line())
	assert_gt(_jumped(on, on.actors.burn_stacks), 0, "a jumped-to enemy burns")
	var off := _off(ElementPairs.X3, _line())
	assert_eq(_jumped(off, off.actors.burn_stacks), 0, "not without the pair")


func test_x8_chain_jumps_carry_one_poison_stack() -> void:
	var on := _pair(ElementPairs.X8, _line())
	var targets := _chain_targets(on)
	var best := 0
	for t in targets:
		var i := on.actors.index_of(t)
		if i > 1:
			best = maxi(best, on.actors.poison_stacks[i])
	assert_eq(best, 1, "a jumped-to enemy holds 1 poison stack")
	var off := _off(ElementPairs.X8, _line())
	assert_eq(_jumped(off, off.actors.poison_stacks), 0, "not without the pair")


func test_x9_chain_jumps_apply_bleed() -> void:
	var on := _pair(ElementPairs.X9, _line())
	assert_gt(_jumped(on, on.actors.bleed_stacks), 0, "a jumped-to enemy bleeds")
	var off := _off(ElementPairs.X9, _line())
	assert_eq(_jumped(off, off.actors.bleed_stacks), 0, "not without the pair")


func test_the_chain_rules_fire_four_times_a_second_at_most() -> void:
	var w := _pair(ElementPairs.X3, [])
	for k in 8:
		w.add_dummy(Vector2(6, 3.0 * k), 0.35, BIG)
	var burning := 0
	for i in range(1, 9):
		ElementPairs.on_jump(w, i, w.take_root())
		burning += 1 if w.actors.burn_stacks[i] > 0 else 0
	assert_eq(burning, 4, "8 jumps in a tick: 4 burns")


# --- X4 Boiling Blood ------------------------------------------------------------------------------------------
func _first_bleed_tick(w: World, i: int) -> int:
	for k in 200:
		W.run(w, 1)
		for e in _dmg(w, i, Engines.EFFECT_BLEED):
			return e.amount
	return -1


func test_x4_bleed_ticks_on_a_burning_enemy_deal_double() -> void:
	var tick := []
	for pair_on in [false, true]:
		var w := _pair(ElementPairs.X4, [[Vector2(4, 0), BIG], [Vector2(4, 3), BIG]])
		if not pair_on:
			CardLevels.set_level(w, W.item(w, &"shared_bleed"), 2)
			ElementPairs.refresh(w)
		_bleed(w, 1)
		_bleed(w, 2)
		_burn(w, 1)
		w.actors.burn_cd[1] = 100000  # no burn tick in the way
		var burning := _first_bleed_tick(w, 1)
		w.actors.burn_stacks[1] = 0
		tick.append([burning, _dmg(w, 2, Engines.EFFECT_BLEED)[0].amount])
	assert_eq(tick[0][0], tick[0][1], "the pair off: a burning enemy bleeds as any")
	assert_eq(tick[1][0], tick[1][1] * 2, "the pair on: double on the burning one")


# --- X5 Cold Circuit -------------------------------------------------------------------------------------------
func test_x5_a_chain_prefers_a_frozen_enemy_and_hits_it_double() -> void:
	var w := _pair(
		ElementPairs.X5, [[Vector2(3, 0), BIG], [Vector2(3, 1.5), BIG], [Vector2(3, -3.5), BIG]]
	)
	_freeze(w, 3)
	var hit := PackedInt32Array([1])
	assert_eq(
		ElementPairs.frozen_target(w, w.actors.pos(1), 5.5, hit),
		3,
		"the frozen one, though farther"
	)
	assert_eq(ElementPairs.jump_damage(w, 3, 100), 200, "double on a frozen enemy")
	assert_eq(ElementPairs.jump_damage(w, 2, 100), 100, "and plain on the others")
	var off := _off(
		ElementPairs.X5, [[Vector2(3, 0), BIG], [Vector2(3, 1.5), BIG], [Vector2(3, -3.5), BIG]]
	)
	_freeze(off, 3)
	assert_eq(
		ElementPairs.frozen_target(off, off.actors.pos(1), 5.5, hit), -1, "off: no preference"
	)
	assert_eq(ElementPairs.jump_damage(off, 3, 100), 100)
	var targets := _chain_targets(w)
	assert_true(targets.has(w.actors.ids[3]), "the beam jumped to the frozen enemy")


# --- X6 Black Ice ----------------------------------------------------------------------------------------------
func test_x6_poisoned_enemies_are_slower_and_keep_poison_while_frozen() -> void:
	var w := _pair(ElementPairs.X6, [[Vector2(4, 0), BIG], [Vector2(4, 3), BIG]])
	var off := _off(ElementPairs.X6, [[Vector2(4, 0), BIG], [Vector2(4, 3), BIG]])
	assert_almost_eq(ItemProcs.slow_factor(w, 1), 1.0, 0.0001, "unpoisoned: unchanged")
	_poison(w, 1)
	_poison(off, 1)
	assert_almost_eq(ItemProcs.slow_factor(w, 1), 0.8, 0.0001, "poisoned: 20 % slower")
	assert_almost_eq(ItemProcs.slow_factor(off, 1), 1.0, 0.0001, "off: unchanged")
	w.actors.slow_t[1] = 100
	assert_almost_eq(
		ItemProcs.slow_factor(w, 1),
		w.item_mods.slow_permille * 0.8 / 1000.0,
		0.0001,
		"and on top of a slow"
	)
	var held := w.actors.poison_t[1]
	_freeze(w, 2)
	_poison(w, 2)
	_freeze(w, 1)
	W.run(w, 20)
	assert_eq(w.actors.poison_t[1], held, "frozen: the poison does not run down")
	w.actors.frozen_t[1] = 0
	W.run(w, 10)
	assert_eq(w.actors.poison_t[1], held - 10, "thawed: it runs")


# --- X7 Brittle ------------------------------------------------------------------------------------------------
func _brittle_world() -> World:
	var w := _pair(
		ElementPairs.X7,
		[
			[Vector2(4, 0), BIG],
			[Vector2(4, 1.0), BIG],
			[Vector2(4, -1.5), BIG],
			[Vector2(4, 6), BIG]
		]
	)
	_bleed(w, 1, 2)
	_freeze(w, 1)
	return w


func _expected_remaining(w: World, i: int) -> int:
	var a := w.actors
	var period := Engines.bleed_period(w)
	var ticks := 1 + (a.bleed_t[i] - a.bleed_cd[i]) / period if a.bleed_t[i] >= a.bleed_cd[i] else 0
	return w.item_mods.bleed_damage * a.bleed_stacks[i] * ticks


func test_x7_a_shattered_frozen_enemy_bursts_its_remaining_bleed_split_evenly() -> void:
	var w := _brittle_world()
	var total := _expected_remaining(w, 1)
	assert_gt(total, 0)
	_hit(w, 1)  # a hit on a frozen enemy shatters it (Frost Lv 3)
	var b := _dmg(w, 2, SimEvent.EFFECT_PAIR_BURST)
	var c := _dmg(w, 3, SimEvent.EFFECT_PAIR_BURST)
	assert_eq(b.size(), 1)
	assert_eq(c.size(), 1)
	assert_eq(b[0].amount, c[0].amount, "split evenly")
	# (the hit's own bleed feed landed first, so the bleed was at least what it was)
	assert_gte(b[0].amount * 2 + 1, total, "the two shares make the remaining bleed")
	assert_eq(_dmg(w, 4, SimEvent.EFFECT_PAIR_BURST).size(), 0, "none at 6 m")
	assert_eq(w.actors.bleed_stacks[1], 0, "its bleed is spent")


func test_x7_a_frozen_enemy_that_dies_bursts_the_same_way() -> void:
	var w := _brittle_world()
	var total := _expected_remaining(w, 1)
	Damage.tick_dot(w, 1, BIG * 2, w.actors.ids[0], w.actors.ids[0], &"test")
	assert_eq(w.actors.dead[1], 1)
	var b := _dmg(w, 2, SimEvent.EFFECT_PAIR_BURST)
	assert_eq(b.size(), 1, "a death bursts too")
	assert_lte(absi(b[0].amount * 2 - total), 1)


func test_x7_off_without_the_pair() -> void:
	var w := _brittle_world()
	CardLevels.set_level(w, W.item(w, &"shared_bleed"), 2)
	ElementPairs.refresh(w)
	_hit(w, 1)
	assert_eq(_dmg(w, 2, SimEvent.EFFECT_PAIR_BURST).size(), 0)


# --- X10 Sepsis ------------------------------------------------------------------------------------------------
func test_x10_three_stacks_of_both_take_twenty_percent_more() -> void:
	var damage := []
	for pair_on in [true, false]:
		var w := _pair(
			ElementPairs.X10, [[Vector2(4, 0), BIG], [Vector2(4, 3), BIG], [Vector2(4, 6), BIG]]
		)
		if not pair_on:
			CardLevels.set_level(w, W.item(w, &"shared_bleed"), 2)
			ElementPairs.refresh(w)
		var a := w.actors
		a.poison_stacks[1] = 3
		a.bleed_stacks[1] = 3
		a.poison_stacks[2] = 3
		a.bleed_stacks[2] = 2  # one short
		_hit(w, 1)
		_hit(w, 2)
		_hit(w, 3)
		damage.append([_dmg(w, 1)[0].amount, _dmg(w, 2)[0].amount, _dmg(w, 3)[0].amount])
	assert_eq(damage[1][0], damage[1][2], "off: no difference")
	assert_eq(damage[0][1], damage[0][2], "on: 3 and 2 stacks is not enough")
	assert_eq(damage[0][0], damage[0][2] * 1200 / 1000, "on: +20 % at 3 and 3")


# --- State -----------------------------------------------------------------------------------------------------
func _crowd(x: int) -> World:
	var enemies := []
	for k in 6:
		enemies.append([Vector2(3.0 + (k % 2), 1.6 * k - 4.0), BIG])
	var w := _pair(x, enemies)
	return w


func _run_crowd(w: World, ticks: int) -> void:
	for k in ticks:
		if k % 30 == 0:
			for i in range(1, w.actors.size()):
				_poison(w, i)
				_burn(w, i)
				_bleed(w, i)
				if i % 2 == 1:
					_freeze(w, i, 90)
		W.run(w, 1, 0, W.S, 0)


func test_every_pair_is_deterministic() -> void:
	for x in ElementPairs.COUNT:
		var hashes := []
		for n in 2:
			var w := _crowd(x)
			_run_crowd(w, 150)
			hashes.append(w.state_hash())
		assert_eq(hashes[0], hashes[1], "%s: the same run twice" % ElementPairs.IDS[x])


func test_the_state_is_hashed_only_while_a_pair_is_on() -> void:
	var on := _crowd(ElementPairs.X2)
	var before := on.state_hash()
	on.pair_log = PackedInt32Array([1, 5])
	assert_ne(on.state_hash(), before, "on: the budget log is hashed")
	var off := _world([ElementPairs.FIRE], [[Vector2(3, 0), BIG]])
	var h := off.state_hash()
	off.pair_log = PackedInt32Array([1, 5])
	assert_eq(off.state_hash(), h, "off: it is not")


func test_the_state_survives_a_snapshot() -> void:
	var w := _crowd(ElementPairs.X2)
	_run_crowd(w, 40)
	assert_gt(w.pair_clouds.size() + w.pair_log.size(), 0, "something to save")
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray())
	var base := _crowd(ElementPairs.X2)
	var r := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(r)
	if r == null:
		return
	assert_eq(r.pair_mask, w.pair_mask)
	assert_eq(r.pair_log, w.pair_log)
	assert_eq(r.pair_clouds, w.pair_clouds)
	assert_eq(r.state_hash(), w.state_hash(), "the restored hash equals")
	var announced := W.events(r, SimEvent.Kind.PAIR_ON).size()
	for x: World in [w, r]:
		_run_crowd(x, 100)
	assert_eq(r.state_hash(), w.state_hash(), "and they go on the same")
	assert_eq(
		W.events(r, SimEvent.Kind.PAIR_ON).size(), announced, "a restore does not announce it again"
	)
