extends GutTest
## v0.9.5 EE2 (ELEMENTS.md E3-E5): Fire, Lightning and Frost gain a behaviour at Lv 2 and 3 (ElementLevelsFsf).
## Fire Lv 2 Wildfire (the burning ground is 50 % wider, 1 s longer), Lv 3 Heat sync (+15 % on a burning enemy from
## the hero's hits, never a burn tick); Lightning Lv 2 Fork (+1 jump, +1.5 m), Lv 3 Overcharge (every 6th hit that can
## chain calls a 1.5 m strike for x2 the hit, 4 a second); Frost Lv 2 Frostbite (+25 % on a frozen enemy), Lv 3 Shatter
## (a hit on a frozen enemy breaks it and sends 3 shards of 50 % at the nearest others within 3 m, 4 a second).
## Lv 1 is the card as it was.

const W := preload("res://tests/support/mx4_world.gd")
const FIRE := ElementLevelsFsf.FIRE
const STORM := ElementLevelsFsf.STORM
const FROST := ElementLevelsFsf.FROST
const BIG := 9000000


func _world(items: Array, enemies: Array, lv: int = 1) -> World:
	var w := W.world(&"gun", items, enemies)
	for id: StringName in items:
		CardLevels.set_level(w, W.item(w, id), lv)
	return w


## One hero projectile-tagged hit of `amount` on enemy index `i`; the HP it removed.
func _hit(w: World, i: int, amount: int = 1000, tags: int = SimEvent.TAG_PROJECTILE) -> int:
	var a := w.actors
	var root := w.take_root()
	return Damage.hit(w, i, amount, a.ids[0], a.ids[0], root, tags, a.pos(0), a.pos(i))


func _burn(w: World, i: int) -> void:
	Engines.add_burn(w, i, 2, w.take_root(), &"test")


func _apply_events(w: World, effect: StringName) -> Array[SimEvent]:
	return W.events(w, SimEvent.Kind.STATUS_APPLY, effect)


## The chain hits (TAG_CHAIN damage) the first bolt landing produced, by target id.
func _chain_targets(w: World) -> Array:
	var first := -1
	for k in 40:
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


## Runs the Gun until the first burning ground is lit; [radius, ticks it lasts from the tick it was lit].
func _patch(lv: int) -> Array:
	var w := _world([&"ember_core"], [[Vector2(3.0, 0.0), 1]], lv)
	for k in 60:
		W.run(w, 1, 0, W.S, 0)
		if not w.ab.fire_r.is_empty():
			return [w.ab.fire_r[0], w.ab.fire_end[0] - w.tick + 1]
	return []


# --- Lv 1: today ---------------------------------------------------------------------------------------------
func test_lv1_is_the_card_as_it_was() -> void:
	var p := _patch(1)
	assert_almost_eq(float(p[0]), 1.2, 0.001, "the patch is 1.2 m")
	assert_eq(p[1], 120, "and burns 2 s")
	var fire := _world([&"ember_core"], [[Vector2(3, 0), BIG], [Vector2(3, 5), BIG]])
	var plain := _hit(fire, 1)
	_burn(fire, 2)
	assert_eq(_hit(fire, 2), plain, "a burning enemy takes the plain hit")
	var w := _world([&"frost_core"], [[Vector2(3, 0), BIG], [Vector2(3, 5), BIG]])
	w.actors.frozen_t[2] = 300
	assert_eq(_hit(w, 2), plain, "a frozen enemy takes the plain hit")
	assert_eq(w.actors.frozen_t[2], 300, "and it stays frozen")
	assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 0, "no shatter")
	var s := _world(
		[&"storm_core"], [[Vector2(3, 0), BIG], [Vector2(3, 3), BIG], [Vector2(3, 6), BIG]]
	)
	assert_eq(_chain_targets(s).size(), 2, "one beam jump and one chain, as before")
	var far := _world(
		[&"storm_core"], [[Vector2(3, 0), BIG], [Vector2(3, 3.5), BIG], [Vector2(3, 8), BIG]]
	)
	assert_eq(_chain_targets(far).size(), 1, "a 4.5 m gap is out of the 4 m reach")
	var k := _fake_hook()
	for n in 30:
		ElementLevelsFsf.overcharge(s, k, AttackContext.make(Vector2.ZERO, 0, 100, 7, 0, &""), 1)
	assert_eq(s.el_chain_hits, 0, "Lv 1 counts nothing")
	assert_eq(_apply_events(s, SimEvent.EFFECT_STORM_STRIKE).size(), 0, "and calls no strike")


func test_the_cards_no_longer_grow_by_percent() -> void:
	for id: StringName in [&"ember_core", &"storm_core", &"frost_core"]:
		var lv1 := _world([id], [[Vector2(3, 0), 100]], 1)
		var lv3 := _world([id], [[Vector2(3, 0), 100]], 3)
		assert_eq(Modifiers.book(lv1).digest, Modifiers.book(lv3).digest, "%s: the same spell" % id)


# --- Fire ----------------------------------------------------------------------------------------------------
func test_lv2_wildfire_is_wider_and_lasts_longer() -> void:
	var p := _patch(2)
	assert_almost_eq(float(p[0]), 1.8, 0.001, "50 % wider")
	assert_eq(p[1], 180, "and 1 s longer")
	var p3 := _patch(3)
	assert_almost_eq(float(p3[0]), 1.8, 0.001, "Lv 3 keeps it")
	assert_eq(p3[1], 180)


func test_lv2_wildfire_lights_what_the_old_patch_missed() -> void:
	var burning := []
	for lv in [1, 2]:
		var w := _world([&"ember_core"], [[Vector2(3.0, 0.0), 1], [Vector2(3.0, 1.6), BIG]], lv)
		W.run(w, 90, 0, W.S, 0)
		assert_false(w.ab.fire_r.is_empty())
		burning.append(w.actors.burn_stacks[w.actors.index_of(3)])
	assert_eq(burning[0], 0, "1.6 m is outside the 1.2 m patch (and the 0.35 m body)")
	assert_gt(burning[1], 0, "and inside the 1.8 m one")


func test_lv3_heat_sync_adds_fifteen_percent_to_a_burning_enemy() -> void:
	for lv in [1, 2, 3]:
		var w := _world([&"ember_core"], [[Vector2(3, 0), BIG], [Vector2(3, 5), BIG]], lv)
		var plain := _hit(w, 1)
		_burn(w, 2)
		var burning := _hit(w, 2)
		assert_eq(burning, plain * 1150 / 1000 if lv == 3 else plain, "Lv %d" % lv)


func test_heat_sync_never_changes_a_burn_tick() -> void:
	var dots := []
	for lv in [1, 3]:
		var w := _world([&"ember_core"], [[Vector2(3, 0), BIG]], lv)
		_burn(w, 1)
		W.run(w, 40)
		var burn := []
		for e in W.events(w, SimEvent.Kind.DAMAGE, &"*"):
			if e.tags & SimEvent.TAG_DOT and e.target_id == w.actors.ids[1]:
				burn.append(e.amount)
		assert_gt(burn.size(), 0)
		dots.append(burn)
	assert_eq(dots[0], dots[1], "the burn ticks are the same at Lv 1 and Lv 3")


# --- Lightning -----------------------------------------------------------------------------------------------
func test_lv2_fork_adds_a_jump() -> void:
	var w := _world(
		[&"storm_core"],
		[
			[Vector2(3, 0), BIG],
			[Vector2(3, 3), BIG],
			[Vector2(3, 6), BIG],
			[Vector2(3, 9), BIG],
			[Vector2(3, 12), BIG]
		],
		2
	)
	assert_eq(_chain_targets(w).size(), 3, "the beam jump and two chains")


func test_lv2_fork_reaches_one_and_a_half_metres_further() -> void:
	var far := _world(
		[&"storm_core"], [[Vector2(3, 0), BIG], [Vector2(3, 3.5), BIG], [Vector2(3, 8), BIG]], 2
	)
	assert_eq(_chain_targets(far).size(), 2, "4.5 m is inside 5.5 m")
	var out := _world(
		[&"storm_core"], [[Vector2(3, 0), BIG], [Vector2(3, 3.5), BIG], [Vector2(3, 9.5), BIG]], 2
	)
	assert_eq(_chain_targets(out).size(), 1, "6 m is not")


func _fake_hook() -> AttackHook:
	var k := AttackHook.new()
	k.child = AttackSpec.new()
	k.child.effect_id = &"storm_core"
	return k


func test_lv3_overcharge_strikes_on_every_sixth_hit() -> void:
	var w := _world(
		[&"storm_core"], [[Vector2(3, 0), BIG], [Vector2(3, 1.4), BIG], [Vector2(3, 2.6), BIG]], 3
	)
	var strike := []
	for k in 400:
		W.run(w, 1, 0, W.S, 0)
		strike = _apply_events(w, SimEvent.EFFECT_STORM_STRIKE)
		if not strike.is_empty():
			break
	assert_eq(strike.size(), 1)
	assert_eq(w.el_chain_hits, 6, "the 6th hit that can chain")
	var pid := w.actors.ids[0]
	var hits := []
	var bolt := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE, &"*"):
		if e.owner_id != pid:
			continue
		if e.effect_id == SimEvent.EFFECT_STORM_STRIKE:
			hits.append(e)
		elif e.tags & SimEvent.TAG_PROJECTILE and e.target_id == w.actors.ids[1]:
			bolt = e.amount
	assert_eq(hits.size(), 2, "the two enemies inside 1.5 m; the third (2.6 m) is out")
	for e: SimEvent in hits:
		assert_eq(e.amount, bolt * 2, "x2 the hit's damage")
		assert_true(e.tags & SimEvent.TAG_AREA != 0, "TAG_AREA")
		assert_true(e.tags & SimEvent.TAG_CHAIN == 0, "it never chains")
	assert_eq(strike[0].amount, 1500, "the event carries its radius in mm")


func test_overcharge_is_four_a_second_and_a_second_later_again() -> void:
	var w := _world([&"storm_core"], [[Vector2(3, 0), BIG], [Vector2(3, 1), BIG]], 3)
	var k := _fake_hook()
	for n in 6 * 10:
		ElementLevelsFsf.overcharge(w, k, AttackContext.make(Vector2.ZERO, 0, 100, 7, 0, &""), 1)
	assert_eq(w.el_chain_hits, 60)
	assert_eq(_apply_events(w, SimEvent.EFFECT_STORM_STRIKE).size(), 4, "10 due, 4 allowed")
	W.run(w, 61)
	for n in 6:
		ElementLevelsFsf.overcharge(w, k, AttackContext.make(Vector2.ZERO, 0, 100, 7, 0, &""), 1)
	assert_eq(_apply_events(w, SimEvent.EFFECT_STORM_STRIKE).size(), 5, "a second on, one more")


# --- Frost ---------------------------------------------------------------------------------------------------
func test_lv2_frostbite_adds_a_quarter_to_a_frozen_enemy() -> void:
	for lv in [1, 2, 3]:
		var w := _world([&"frost_core"], [[Vector2(3, 0), BIG], [Vector2(3, 5), BIG]], lv)
		var plain := _hit(w, 1)
		w.actors.frozen_t[2] = 300
		var frozen := _hit(w, 2)
		assert_eq(frozen, plain * 1250 / 1000 if lv >= 2 else plain, "Lv %d" % lv)
		if lv == 2:
			assert_gt(w.actors.frozen_t[2], 0, "Lv 2 does not shatter")
			assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 0)


func _shatter_world() -> World:
	return _world(
		[&"frost_core"],
		[
			[Vector2(3, 0), BIG],
			[Vector2(3, 1.5), BIG],
			[Vector2(3, -2.5), BIG],
			[Vector2(3, 2.9), BIG],
			[Vector2(3, 3.4), BIG],
			[Vector2(3, 9), BIG]
		],
		3
	)


func test_lv3_shatter_breaks_the_ice_and_sends_three_shards() -> void:
	var w := _shatter_world()
	var a := w.actors
	a.frozen_t[1] = 300
	a.frozen_t[2] = 300  # a frozen neighbour: its shard must not shatter it again
	var got := _hit(w, 1)
	assert_eq(a.frozen_t[1], 0, "the freeze breaks")
	assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 1)
	var shards := _apply_events(w, SimEvent.EFFECT_FROST_SHARD)
	assert_eq(shards.size(), 3)
	var ids := []
	for e: SimEvent in shards:
		ids.append(e.target_id)
		assert_eq(e.source_id, a.ids[1], "from the broken enemy")
	assert_eq(
		ids, [a.ids[2], a.ids[3], a.ids[4]], "the three nearest, 1.5, 2.5 and 2.9 m; not 3.4 m"
	)
	var dmg := []
	for e in W.damage(w, SimEvent.EFFECT_FROST_SHARD):
		dmg.append(e)
		assert_eq(e.amount, got * 500 / 1000, "50 % of the hit")
		assert_true(e.tags & SimEvent.TAG_SHRAPNEL != 0, "TAG_SHRAPNEL")
	assert_eq(dmg.size(), 3)
	assert_gt(a.slow_t[3], 0, "a short slow")
	assert_eq(a.slow_t[3], w.item_tables[W.item(w, &"frost_core")].el_shard_slow_ticks)
	assert_eq(a.slow_t[5], 0, "not the one out of range")
	assert_eq(a.frozen_t[2], 300, "a shard does not shatter again")
	assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 1, "and one shatter only")


func test_a_hit_that_freezes_does_not_shatter() -> void:
	var w := _world([&"frost_core"], [[Vector2(3, 0), BIG], [Vector2(3, 1.5), BIG]], 3)
	var a := w.actors
	a.frost_stacks[1] = w.item_mods.frost_threshold - 1
	a.frost_t[1] = 120
	Engines.add_frost(w, 1, 1, w.take_root(), &"test")
	assert_gt(a.frozen_t[1], 0, "frozen by the stack")
	assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 0)


func test_shatter_is_four_a_second() -> void:
	var enemies := []
	for k in 12:
		enemies.append([Vector2(3.0 + 0.3 * (k % 4), -1.5 + 0.5 * k), BIG])
	var w := _world([&"frost_core"], enemies, 3)
	for k in 6:
		w.actors.frozen_t[1 + k * 2] = 600
	for k in 6:
		_hit(w, 1 + k * 2)
	assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 4, "6 frozen hit, 4 shatter")
	W.run(w, 61)
	var n := 0
	for k in 12:
		if w.actors.frozen_t[1 + k] > 0:
			_hit(w, 1 + k)
			n += 1
			break
	assert_eq(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 5, "a second on, one more")


# --- Determinism and saves ----------------------------------------------------------------------------------
func _crowd(lv: int) -> World:
	var enemies := []
	for k in 10:
		enemies.append([Vector2(3.0 + 0.2 * k, -1.2 + 0.5 * k), BIG])
	return _world([&"storm_core", &"frost_core"], enemies, lv)


func _burst(w: World, ticks: int) -> void:
	for k in ticks:
		if k % 50 == 0:
			for i in range(1, w.actors.size(), 3):
				w.actors.frozen_t[i] = 90
		W.run(w, 1, 0, W.S, 0)


func test_lv3_is_deterministic() -> void:
	var hashes := []
	var strikes := 0
	for n in 2:
		var w := _crowd(3)
		_burst(w, 400)
		hashes.append(w.state_hash())
		strikes = _apply_events(w, SimEvent.EFFECT_STORM_STRIKE).size()
		assert_gt(_apply_events(w, SimEvent.EFFECT_FROST_SHATTER).size(), 0)
	assert_eq(hashes[0], hashes[1])
	assert_gt(strikes, 0)


func test_the_counters_are_hashed_only_at_lv3() -> void:
	for lv in [1, 2, 3]:
		var w := _crowd(lv)
		var before := w.state_hash()
		w.el_chain_hits = 3
		w.el_strike_log = PackedInt32Array([5])
		w.el_shatter_log = PackedInt32Array([6])
		if lv < 3:
			assert_eq(w.state_hash(), before, "Lv %d hashes as it did" % lv)
		else:
			assert_ne(w.state_hash(), before, "Lv 3 hashes them")


func test_the_budgets_survive_a_snapshot() -> void:
	var w := _crowd(3)
	_burst(w, 130)
	assert_gt(w.el_chain_hits, 0)
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray())
	var base := _crowd(3)
	var r := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(r)
	if r == null:
		return
	assert_eq(r.el_chain_hits, w.el_chain_hits)
	assert_eq(r.el_strike_log, w.el_strike_log)
	assert_eq(r.el_shatter_log, w.el_shatter_log)
	assert_eq(r.state_hash(), w.state_hash(), "the restored hash equals")
	for x: World in [w, r]:
		_burst(x, 200)
	assert_eq(r.state_hash(), w.state_hash(), "and they go on the same")
