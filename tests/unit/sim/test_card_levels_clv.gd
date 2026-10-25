extends GutTest
## v0.9.5 CLV (docs/roadmap/v0.9.5/CARD_LEVELS.md, owner-approved): cards level only where it shows. A card with
## `level_max` 1 is offered once and never again while held; Twin, Halo, Split and the elements have 3 levels; an old
## save above the cap reads capped; the Pulse Gun is never offered (`offered = false`).

const W := preload("res://tests/support/mx4_world.gd")
const ONE_LEVEL: Array[StringName] = [
	&"gun_pierce",
	&"gun_homing",
	&"gun_swirl",
	&"gun_spiral",
	&"gun_ricochet",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"gun_mine",
	&"orbit_rounds",
	&"gun_backfire",
	&"gun_ring",
	&"gun_threadline",
	&"shared_faultline",
	&"gun_laser",
	&"gun_bomb",
	&"gun_void",
	&"gun_lance",
	&"gun_rune_explosion",
	&"gun_scatter",
	&"gun_glaive",
	&"gun_seekers",
	&"gun_wave",
	&"gun_wisps",
]
const THREE_LEVELS: Array[StringName] = [
	&"gun_twin",
	&"halo_shot",
	&"split_shot",
	&"ember_core",
	&"storm_core",
	&"frost_core",
	&"venom_core",
	&"shared_bleed",
]


func _take(w: World, id: StringName, times: int) -> int:
	var k := W.item(w, id)
	assert_gte(k, 0, "%s shipped" % id)
	for n in times:
		BuildSlots.take(w, k)
	return k


func test_the_caps_come_from_the_data() -> void:
	var w := W.world(&"gun")
	for id in ONE_LEVEL:
		assert_eq(CardLevels.max_level(w, W.item(w, id)), 1, "%s: 1 level" % id)
	for id in THREE_LEVELS:
		assert_eq(CardLevels.max_level(w, W.item(w, id)), 3, "%s: 3 levels" % id)
	assert_eq(CardLevels.max_level(w, W.item(w, &"wide_arc")), 5, "a Blade card keeps 5 levels")
	assert_eq(CardLevels.max_level(w, W.item(w, &"gun_spread")), 5, "a card not listed keeps 5")


func test_a_one_level_card_is_never_offered_once_held() -> void:
	for id in ONE_LEVEL:
		var w := W.world(&"gun")
		var k := W.item(w, id)
		assert_true(CardLevels.can_take(w, k), "%s: offered before it is held" % id)
		BuildSlots.take(w, k)
		assert_eq(CardLevels.level(w, k), 1)
		assert_false(CardLevels.can_take(w, k, CardLevels.MAX_LEVEL), "%s: not again" % id)
		assert_does_not_have(ItemPool.available(w, true, CardLevels.MAX_LEVEL), k, id)
		assert_false(CardLevels.level_up(w, k), "%s has no level 2" % id)
		assert_eq(CardLevels.level_after(w, k), 1)
		assert_true(CardLevels.set_level(w, k, 4))
		assert_eq(CardLevels.level(w, k), 1, "set_level clamps to the cap")


func test_a_three_level_card_stops_at_three() -> void:
	for id in THREE_LEVELS:
		var w := W.world(&"gun")
		var k := _take(w, id, 5)
		assert_eq(CardLevels.level(w, k), 3, "%s stops at 3" % id)
		assert_false(CardLevels.can_take(w, k, CardLevels.MAX_LEVEL), "%s: not offered at 3" % id)


func test_the_fixed_values_of_the_one_level_cards() -> void:
	var cases := {
		&"gun_pierce": [&"pierce", 4],
		&"gun_ricochet": [&"bounces", 3],
		&"gun_echo": [&"repeat_damage_permille", 600],
		&"gun_rapid_fire": [&"ramp_cap_permille", 900],
		&"gun_mine": [&"mine_ticks", 240],
		&"gun_spiral": [&"damage_mul_permille", 1200],
		&"orbit_rounds": [&"damage_mul_permille", 1200],
		&"gun_backfire": [&"damage_mul_permille", 1200],
		&"gun_big_shot": [&"damage_mul_permille", 1800],
	}
	for id: StringName in cases:
		var w := W.world(&"gun")
		_take(w, id, 1)
		assert_eq(Modifiers.bolt(w).get(cases[id][0]), cases[id][1], "%s at Lv 1" % id)
	var w := W.world(&"gun")
	_take(w, &"gun_ring", 1)
	assert_almost_eq(Modifiers.bolt(w).radius_m, 2.0, 1e-5, "Ring radius 2.0 m")


func test_twin_has_three_steps() -> void:
	var w := W.world(&"gun")
	var k := _take(w, &"gun_twin", 1)
	var want := [[1, 700], [1, 900], [2, 750]]
	for lvl in 3:
		assert_true(CardLevels.set_level(w, k, lvl + 1))
		var s := Modifiers.bolt(w)
		assert_eq(
			[s.twin, s.share_permille],
			want[lvl],
			"Twin at Lv %d: (extra copies, share)" % (lvl + 1)
		)


func test_halo_and_split_steps() -> void:
	var w := W.world(&"gun")
	var k := _take(w, &"halo_shot", 1)
	for lvl in 3:
		CardLevels.set_level(w, k, lvl + 1)
		assert_eq(Modifiers.bolt(w).count, [4, 6, 8][lvl], "Halo at Lv %d" % (lvl + 1))
	var w2 := W.world(&"gun")
	var s := _take(w2, &"split_shot", 1)
	for lvl in 3:
		CardLevels.set_level(w2, s, lvl + 1)
		var hook := W.hook_of(Modifiers.bolt(w2), &"split_shot")
		assert_eq(hook.child.count, [2, 3, 4][lvl], "Split at Lv %d" % (lvl + 1))


func test_an_old_save_above_the_cap_reads_capped() -> void:
	var w := W.world(&"gun")
	var pierce := _take(w, &"gun_pierce", 1)
	var twin := _take(w, &"gun_twin", 1)
	w.card_levels.resize(w.item_tables.size())
	w.card_levels[pierce] = 4  # as an older save stored it
	w.card_levels[twin] = 5
	Modifiers.invalidate(w)
	assert_eq(CardLevels.level(w, pierce), 1, "Pierce at Lv 4 reads Lv 1")
	assert_eq(CardLevels.level(w, twin), 3, "Twin at Lv 5 reads Lv 3")
	assert_eq(Modifiers.bolt(w).pierce, 4)
	assert_eq(Modifiers.bolt(w).twin, 2, "three copies")


func test_the_pulse_gun_is_never_offered() -> void:
	for form in [&"", &"gun_laser"]:
		var w := W.world(&"gun", [] if form == &"" else [form])
		var pg := -1
		for k in w.ability_tables.size():
			if w.ability_tables[k].id == &"pulse_gun":
				pg = k
		assert_gte(pg, 0, "the Pulse Gun is in the tables")
		assert_true(Abilities.owned(w, pg), "the start weapon stays owned at Lv 1")
		assert_false(Abilities.can_take(w, pg), "not offered (form %s)" % form)
		assert_does_not_have(
			Offers._abilities(w, PackedInt32Array(), false), pg, "not in the ability offers"
		)
		assert_does_not_have(Overrun.offer(w), Offers.ability_code(pg), "nor in Overrun's altar")


func test_level_values_validate() -> void:
	var d := ModifierDefinition.new()
	d.id = &"t"
	var o := ModifierOpDefinition.new()
	o.op = ModifierOpDefinition.Op.ADD
	o.field = &"twin"
	o.level_values = PackedFloat32Array([1, 1, 2, 2, 2, 2])
	d.ops = Array([o], TYPE_OBJECT, &"Resource", ModifierOpDefinition)
	var bad := d.validate().filter(
		func(i: ValidationIssue) -> bool: return "level_values" in i.message
	)
	assert_gt(bad.size(), 0, "6 entries is too many")
