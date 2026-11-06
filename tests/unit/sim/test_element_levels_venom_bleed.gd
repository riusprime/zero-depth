extends GutTest
## v0.9.5 EE1 (ELEMENTS.md E1, E2): Venom and Bleed gain a behaviour at Lv 2 and 3 (ElementLevels). Venom Lv 2
## Contagion (a poisoned enemy passes its poison on every 1.5 s, the room at most 4 jumps a second), Lv 3 Virulence
## (5 stacks, +25 % a tick per stack past the first); Bleed Lv 2 Open wounds (+50 % on a tick after it moved), Lv 3
## Exsanguinate (5 stacks; the 5th bursts the rest at once). Lv 1 is the engine as it was.

const W := preload("res://tests/support/mx4_world.gd")


func _world(items: Array, enemies: Array, venom_lv: int = 1, bleed_lv: int = 1) -> World:
	var w := W.world(&"gun", items, enemies)
	if items.has(&"venom_core"):
		CardLevels.set_level(w, W.item(w, &"venom_core"), venom_lv)
	if items.has(&"shared_bleed"):
		CardLevels.set_level(w, W.item(w, &"shared_bleed"), bleed_lv)
	return w


func _ticks_until_damage(w: World, effect: StringName, limit: int) -> Array[SimEvent]:
	for k in limit:
		W.run(w, 1)
		var evs := W.damage(w, effect)
		if not evs.is_empty():
			return evs
	return []


func _jumps(w: World) -> Array[SimEvent]:
	return W.events(w, SimEvent.Kind.STATUS_APPLY, ElementLevels.EFFECT_JUMP)


# --- Lv 1: today ---------------------------------------------------------------------------------------------
func test_lv1_poison_and_bleed_tick_as_before() -> void:
	var w := _world(
		[&"venom_core", &"shared_bleed"], [[Vector2(4.0, 0.0), 5000], [Vector2(5.5, 0.0), 5000]]
	)
	Venom.add(w, 1, 3, 100)
	Engines.add_bleed(w, 2, 3, 101)
	assert_eq(w.actors.poison_stacks[1], 3)
	var p := _ticks_until_damage(w, Venom.EFFECT_POISON, 60)
	assert_eq(p[0].amount, Stats.dot(w, w.item_mods.poison_damage * 3), "3 stacks: damage x stacks")
	var b := _ticks_until_damage(w, Engines.EFFECT_BLEED, 60)
	assert_eq(b[0].amount, Stats.dot(w, w.item_mods.bleed_damage * 3), "a bleed tick is its stacks")
	W.run(w, 400)
	assert_eq(_jumps(w).size(), 0, "no Contagion at Lv 1")
	Venom.add(w, 1, 20, 102)
	Engines.add_bleed(w, 2, 20, 103)
	assert_eq(w.actors.poison_stacks[1], 8, "Lv 1 keeps the engine's cap of 8")
	assert_eq(w.actors.bleed_stacks[2], 8)


# --- Venom ---------------------------------------------------------------------------------------------------
func test_lv2_contagion_passes_to_the_nearest_unpoisoned_in_range() -> void:
	var w := _world(
		[&"venom_core"],
		[
			[Vector2(4.0, 0.0), 5000],
			[Vector2(5.5, 0.0), 5000],
			[Vector2(6.3, 0.0), 5000],
			[Vector2(10.0, 0.0), 5000]
		],
		2
	)
	Venom.add(w, 1, 3, 100)
	var start := w.tick
	W.run(w, 89)
	assert_eq(_jumps(w).size(), 0, "not before 1.5 s")
	W.run(w, 30)
	var j := _jumps(w)
	assert_eq(j.size(), 1, "one jump by the first gap tick after 1.5 s")
	assert_eq(j[0].source_id, w.actors.ids[1], "from the giver")
	assert_eq(j[0].target_id, w.actors.ids[2], "to the nearest, 1.5 m away, not the one at 2.3 m")
	assert_gte(j[0].tick - start, 90)
	assert_eq(w.actors.poison_stacks[2], 3, "Lv 2 passes its current strength")
	assert_eq(w.actors.poison_stacks[4], 0, "the one 5 m off is out of range")
	W.run(w, 400)
	assert_gt(w.actors.poison_stacks[3], 0, "it reaches the next one along")
	assert_eq(w.actors.poison_stacks[4], 0, "and never the one beyond every poisoned enemy's 2.5 m")


func test_contagion_is_a_world_budget_of_four_a_second() -> void:
	var enemies := []
	for k in 24:
		enemies.append([Vector2(3.0 + 0.9 * (k % 12), -2.0 + 1.4 * (k / 12)), 9000])
	var w := _world([&"venom_core"], enemies, 2)
	for k in 6:
		Venom.add(w, 1 + k * 4, 1, 100 + k)
	W.run(w, 420)
	var j := _jumps(w)
	assert_gt(j.size(), 4, "a crowded room keeps jumping")
	var seen := {}
	for e in j:
		var s := e.tick / 60
		seen[s] = int(seen.get(s, 0)) + 1
		assert_lte(int(seen[s]), 4, "at most 4 jumps in second %d" % s)
	for k in range(1, j.size()):
		assert_gte(j[k].tick - j[k - 1].tick, 15, "a jump every 15 ticks at the fastest")


func test_contagion_is_deterministic() -> void:
	var hashes := []
	for n in 2:
		var enemies := []
		for k in 10:
			enemies.append([Vector2(3.0 + 0.8 * k, 0.5 * (k % 3)), 9000])
		var w := _world([&"venom_core"], enemies, 2)
		Venom.add(w, 1, 2, 100)
		W.run(w, 500)
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_lv3_virulence_stacks_to_five_and_each_adds_a_quarter() -> void:
	var w := _world([&"venom_core"], [[Vector2(4.0, 0.0), 9000], [Vector2(5.0, 0.0), 9000]], 3)
	Venom.add(w, 1, 9, 100)
	assert_eq(w.actors.poison_stacks[1], 5, "capped at 5")
	var p := _ticks_until_damage(w, Venom.EFFECT_POISON, 60)
	assert_eq(p[0].amount, Stats.dot(w, w.item_mods.poison_damage * 5 * 2), "5 stacks: x2")
	W.run(w, 20)
	Venom.add(w, 1, 1, 101)
	assert_eq(w.actors.poison_t[1], w.item_mods.poison_ticks, "a new hit refreshes the duration")
	var w3 := _world([&"venom_core"], [[Vector2(4.0, 0.0), 9000]], 3)
	Venom.add(w3, 1, 3, 100)
	var q := _ticks_until_damage(w3, Venom.EFFECT_POISON, 60)
	var base := w3.item_mods.poison_damage * 3
	assert_eq(q[0].amount, Stats.dot(w3, (base * 3 + 1) / 2), "3 stacks: x1.5")


func test_lv3_contagion_passes_one_stack() -> void:
	var w := _world([&"venom_core"], [[Vector2(4.0, 0.0), 9000], [Vector2(5.0, 0.0), 9000]], 3)
	Venom.add(w, 1, 4, 100)
	W.run(w, 120)
	assert_eq(_jumps(w).size(), 1, "Lv 3 keeps Contagion")
	assert_eq(w.actors.poison_stacks[2], 1, "it passes one stack")


# --- Bleed ---------------------------------------------------------------------------------------------------
func test_lv2_open_wounds_needs_movement() -> void:
	var w := _world([&"shared_bleed"], [[Vector2(4.0, 0.0), 9000]], 1, 2)
	Engines.add_bleed(w, 1, 2, 100)
	var base := w.item_mods.bleed_damage * 2
	var a := _ticks_until_damage(w, Engines.EFFECT_BLEED, 60)
	assert_eq(a[0].amount, Stats.dot(w, base), "standing still: the plain tick")
	var n := W.damage(w, Engines.EFFECT_BLEED).size()
	w.actors.set_pos(1, w.actors.pos(1) + Vector2(0.04, 0.0))  # 0.04 m: under the 0.05 m
	W.run(w, 60)
	assert_eq(
		W.damage(w, Engines.EFFECT_BLEED)[n].amount, Stats.dot(w, base), "a drift is not moving"
	)
	w.actors.set_pos(1, w.actors.pos(1) + Vector2(0.2, 0.0))
	var m := W.damage(w, Engines.EFFECT_BLEED).size()
	W.run(w, 60)
	var evs := W.damage(w, Engines.EFFECT_BLEED)
	assert_eq(evs[m].amount, Stats.dot(w, (base * 3 + 1) / 2), "moved: +50 %")
	assert_eq(evs[m + 1].amount, Stats.dot(w, base), "standing again: plain")


func test_lv3_exsanguinate_bursts_the_rest_at_five_and_resets() -> void:
	var w := _world([&"shared_bleed"], [[Vector2(4.0, 0.0), 9000]], 1, 3)
	Engines.add_bleed(w, 1, 4, 100)
	assert_eq(W.damage(w, ElementLevels.EFFECT_EXSANGUINATE).size(), 0, "4 stacks: no burst")
	var a := w.actors
	var ticks := 1 + (a.bleed_t[1] - a.bleed_cd[1]) / w.item_mods.bleed_period_ticks
	Engines.add_bleed(w, 1, 1, 101)
	var b := W.damage(w, ElementLevels.EFFECT_EXSANGUINATE)
	assert_eq(b.size(), 1, "the 5th stack bursts")
	assert_eq(b[0].amount, Stats.dot(w, w.item_mods.bleed_damage * 5 * ticks), "the rest at once")
	assert_eq(a.bleed_stacks[1], 0, "and the bleed ends")
	Engines.add_bleed(w, 1, 1, 102)
	assert_eq(a.bleed_stacks[1], 1, "it can stack again")
	Engines.add_bleed(w, 1, 9, 103)
	assert_lte(a.bleed_stacks[1], 5, "never past 5")


func test_lv3_keeps_open_wounds() -> void:
	var w := _world([&"shared_bleed"], [[Vector2(4.0, 0.0), 9000]], 1, 3)
	Engines.add_bleed(w, 1, 2, 100)
	W.run(w, 1)
	w.actors.set_pos(1, w.actors.pos(1) + Vector2(0.3, 0.0))
	var evs := _ticks_until_damage(w, Engines.EFFECT_BLEED, 60)
	var base := w.item_mods.bleed_damage * 2
	assert_eq(evs[0].amount, Stats.dot(w, (base * 3 + 1) / 2))


# --- Saves ---------------------------------------------------------------------------------------------------
func test_the_element_state_survives_a_snapshot() -> void:
	var items := [&"venom_core", &"shared_bleed"]
	var enemies := [[Vector2(4.0, 0.0), 9000], [Vector2(5.0, 0.0), 9000], [Vector2(6.0, 0.5), 9000]]
	var w := _world(items, enemies, 2, 2)
	Venom.add(w, 1, 2, 100)
	Engines.add_bleed(w, 3, 2, 101)
	W.run(w, 50)
	w.actors.set_pos(3, w.actors.pos(3) + Vector2(0.4, 0.0))
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray())
	var base := _world(items, enemies, 2, 2)
	var r := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(r)
	if r == null:
		return
	assert_eq(r.state_hash(), w.state_hash(), "the restored hash equals")
	assert_eq(r.actors.poison_jump_cd, w.actors.poison_jump_cd)
	assert_eq(r.actors.bleed_x, w.actors.bleed_x)
	for x: World in [w, r]:
		W.run(x, 200)
	assert_eq(r.state_hash(), w.state_hash(), "and they go on the same")
	assert_gt(_jumps(r).size(), 0, "the jump timer came back")


func test_the_element_columns_are_hashed_only_from_lv2() -> void:
	var lv1 := _world([&"venom_core"], [[Vector2(4.0, 0.0), 9000]])
	var before := lv1.state_hash()
	lv1.actors.poison_jump_cd[1] = 55
	assert_eq(lv1.state_hash(), before, "Lv 1 hashes as it did")
	var lv2 := _world([&"venom_core"], [[Vector2(4.0, 0.0), 9000]], 2)
	var h2 := lv2.state_hash()
	lv2.actors.poison_jump_cd[1] = 55
	assert_ne(lv2.state_hash(), h2, "Lv 2 hashes them")
