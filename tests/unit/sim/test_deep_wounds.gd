extends GutTest
## v0.10.5 W3-P10d (owner W7): the Deep Wounds Constellation lifts the bleed / venom / burn stack caps (20 / 15 / 10)
## and deals x1.25 on each of their DoT ticks. Without it nothing changes.

const W := preload("res://tests/support/mx4_world.gd")


func _world(items: Array, deep: bool, bleed_lv: int = 1) -> World:
	var w := W.world(&"gun", items, [[Vector2(4.0, 0.0), 90000]])
	if deep:
		w.constellations = PackedInt32Array([Constellations.DEEP_WOUNDS])
	if bleed_lv > 1:
		CardLevels.set_level(w, W.item(w, &"shared_bleed"), bleed_lv)
	return w


func _ticks_until_damage(w: World, effect: StringName) -> Array[SimEvent]:
	for k in 90:
		W.run(w, 1)
		var evs := W.damage(w, effect)
		if not evs.is_empty():
			return evs
	return []


func test_caps_without_the_constellation() -> void:
	var w := _world([&"venom_core", &"shared_bleed", &"ember_core"], false)
	assert_eq(ElementLevels.bleed_cap(w), 8)
	assert_eq(ElementLevels.poison_cap(w), 8)
	assert_eq(ElementLevels.burn_cap(w), 5)
	Engines.add_bleed(w, 1, 30, 1)
	Venom.add(w, 1, 30, 2)
	Engines.add_burn(w, 1, 30, 3, &"t")
	assert_eq(w.actors.bleed_stacks[1], 8)
	assert_eq(w.actors.poison_stacks[1], 8)
	assert_eq(w.actors.burn_stacks[1], 5)


func test_caps_with_the_constellation() -> void:
	var w := _world([&"venom_core", &"shared_bleed", &"ember_core"], true)
	assert_eq(ElementLevels.bleed_cap(w), 20)
	assert_eq(ElementLevels.poison_cap(w), 15)
	assert_eq(ElementLevels.burn_cap(w), 10)
	Engines.add_bleed(w, 1, 30, 1)
	Venom.add(w, 1, 30, 2)
	Engines.add_burn(w, 1, 30, 3, &"t")
	assert_eq(w.actors.bleed_stacks[1], 20)
	assert_eq(w.actors.poison_stacks[1], 15)
	assert_eq(w.actors.burn_stacks[1], 10)
	ItemEffects.on_melee_hit(w, 1, 4, 30)
	assert_eq(w.actors.burn_stacks[1], 10, "the melee burn path reads the same cap")


func test_an_element_the_run_lacks_gets_no_cap() -> void:
	var w := _world([&"shared_bleed"], true)
	assert_eq(ElementLevels.poison_cap(w), 0)
	assert_eq(ElementLevels.burn_cap(w), 0)
	assert_eq(ElementLevels.bleed_cap(w), 20)


func test_dot_ticks_deal_125_percent() -> void:
	var plain := _world([&"venom_core", &"shared_bleed", &"ember_core"], false)
	var deep := _world([&"venom_core", &"shared_bleed", &"ember_core"], true)
	for w in [plain, deep]:
		Engines.add_bleed(w, 1, 8, 1)
		Venom.add(w, 1, 8, 2)
		Engines.add_burn(w, 1, 5, 3, &"t")
	assert_eq(ElementLevels.deep_dot(plain, 16), 16)
	assert_eq(ElementLevels.deep_dot(deep, 16), 20)
	assert_eq(ElementLevels.deep_dot(deep, 0), 0)
	for effect in [Engines.EFFECT_BLEED, Venom.EFFECT_POISON, ItemEffects.EFFECT_EMBER_EDGE]:
		var a := _ticks_until_damage(plain, effect)
		var b := _ticks_until_damage(deep, effect)
		assert_false(a.is_empty(), "%s ticks" % effect)
		assert_eq(b[0].amount, Stats.dot(deep, (a[0].amount * 1250 + 500) / 1000), str(effect))
		assert_gt(b[0].amount, a[0].amount)


func test_exsanguinate_bursts_at_the_lifted_cap() -> void:
	var w := _world([&"shared_bleed"], true, 3)
	Engines.add_bleed(w, 1, 5, 100)
	assert_eq(w.actors.bleed_stacks[1], 5, "no burst at 5 now")
	assert_eq(W.damage(w, ElementLevels.EFFECT_EXSANGUINATE).size(), 0)
	Engines.add_bleed(w, 1, 14, 101)
	assert_eq(w.actors.bleed_stacks[1], 19)
	Engines.add_bleed(w, 1, 3, 102)
	assert_eq(W.damage(w, ElementLevels.EFFECT_EXSANGUINATE).size(), 1, "the 20th stack bursts")
	assert_eq(w.actors.bleed_stacks[1], 0)
