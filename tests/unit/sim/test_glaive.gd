extends GutTest
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F7 "A spinning disc that flies out and returns, hitting on both ways … 7 m
## out, ×1.6 damage per pass, every 0.7 s", Twin yes, Spiral off, Swirl yes, the rest off, elements all): the Glaive
## form. One disc every 0.7 s that turns 7 m out and comes back to the hero; it passes through every enemy both ways
## at × 1.6 an orb hit a pass; Twin throws 2 (3 at Lv 5); its row; its DPS against the orbs (reported, see
## GLAIVE_SEEKERS.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const GLAIVE_ON: Array[StringName] = [
	&"gun_twin",
	&"gun_swirl",
	&"halo_shot",  # v0.9.5 FC6: the eleven cards of GlaiveMods
	&"gun_ring",
	&"gun_backfire",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"orbit_rounds",
	&"ember_core",
	&"storm_core",
	&"frost_core",
	&"venom_core",
	&"shared_bleed"
]


func _world(
	items: Array = [], at: Array = [Vector2(3.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_glaive"]
	ids.append_array(items)
	var w := W.world(&"gun", ids)
	for p: Vector2 in at:
		w.add_dummy(p, r, HP)
	return w


func _dealt(w: World, idx: int, from: int = 0, to: int = 1 << 30) -> Array:
	var id := w.actors.ids[idx]
	var n := 0
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if e.target_id != id or e.tags & SimEvent.TAG_DOT or e.tick < from or e.tick >= to:
			continue
		n += 1
		total += e.amount
	return [n, total]


func _discs(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if Glaive.is_disc(w, i):
			out.append(i)
	return out


func test_the_card_makes_the_shot_a_returning_disc() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	assert_true(Glaive.is_glaive(s))
	assert_eq(s.form, AttackSpec.Form.BOLT)
	assert_gt(s.returns, 0, "it comes back (the retired Boomerang's rule)")
	assert_eq(s.count, 1, "one disc")
	assert_eq(s.period_ticks, 42, "every 0.7 s")
	assert_almost_eq(s.speed * s.life_ticks / 2.0, 7.0, 0.01, "7 m out")
	assert_eq(s.share_permille, 1600, "× 1.6 an orb hit a pass")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_glaive")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_glaive")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_GLAIVE", &"ITEM_GUN_GLAIVE_DESC"])


func test_it_flies_seven_metres_out_and_comes_back_to_the_hero() -> void:
	var w := _world([], [])
	W.run(w, 1, 0, W.S)
	var d := _discs(w)
	assert_eq(d.size(), 1, "one disc a throw")
	var id := w.projectiles.ids[d[0]]
	var far := 0.0
	var back := false
	var last := Vector2.INF
	for k in 70:
		W.run(w, 1, 0, 0)
		var i := w.projectiles.ids.find(id)
		if i < 0:
			break
		var p := Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i])
		far = maxf(far, (p - w.player_pos()).length())
		back = back or Glaive.coming_back(w, i)
		last = p
	gut.p(
		"AF2 Glaive flight: farthest %.2f m, last seen %.2f m from the hero" % [far, last.length()]
	)
	assert_almost_eq(far, 7.0 + w.player.radius_m + 0.35, 0.5, "it turns about 7 m out")
	assert_true(back, "then it comes back")
	assert_lt((last - w.player_pos()).length(), 1.0, "and ends at the hero")
	assert_eq(w.projectiles.ids.find(id), -1, "caught")


func test_enemies_on_its_path_do_not_carry_it_past_seven_metres() -> void:
	var w := _world([], [Vector2(2.5, 0.0), Vector2(4.5, 0.0), Vector2(6.5, 0.0)])
	W.run(w, 1, 0, W.S)
	var id := w.projectiles.ids[_discs(w)[0]]
	var far := 0.0
	for k in 70:
		W.run(w, 1, 0, 0)
		var i := w.projectiles.ids.find(id)
		if i < 0:
			break
		far = maxf(far, Vector2(w.projectiles.pos_x[i], w.projectiles.pos_y[i]).length())
	gut.p("AF2 Glaive flight through three in a row: farthest %.2f m" % far)
	assert_almost_eq(far, 7.0 + w.player.radius_m + 0.35, 0.6, "a pierce's push spends its flight")
	assert_eq(w.projectiles.ids.find(id), -1, "and it still comes home")


func test_it_hits_on_both_ways_at_one_point_six_an_orb_hit() -> void:
	var w := _world()
	W.run(w, 1, 0, W.S)
	W.run(w, 70, 0, 0)
	var got := _dealt(w, 1)
	assert_eq(got, [2, 16], "one hit out, one back: 8 each (× 1.6 of 5)")
	var row := _world([], [Vector2(2.0, 0.0), Vector2(3.5, 0.0), Vector2(5.0, 0.0)])
	W.run(row, 1, 0, W.S)
	W.run(row, 70, 0, 0)
	for k in [1, 2, 3]:
		assert_eq(_dealt(row, k)[0], 2, "it passes through enemy %d both ways" % k)


func test_single_target_dps_against_the_orbs_and_a_line() -> void:
	var o := _world([], [Vector2(3.0, 0.0)], true)
	W.run(o, 1800, 0, W.S)
	var orbs := _dealt(o, 1, 120, 1800)
	var ratios := {}
	for d: float in [1.5, 3.0, 6.0]:
		var w := _world([], [Vector2(d, 0.0)])
		W.run(w, 1800, 0, W.S)
		var s := _dealt(w, 1, 120, 1800)
		ratios[d] = float(s[1]) / float(orbs[1])
		(
			gut
			. p(
				(
					"AF2 Glaive one target %.1f m, 28 s: %d dmg in %d hits; orbs (3 m) %d in %d; ratio %.3f"
					% [d, s[1], s[0], orbs[1], orbs[0], ratios[d]]
				)
			)
		)
	var line: Array = []
	for k in 5:
		line.append(Vector2(2.0 + 1.2 * k, 0.0))
	var gl := _world([], line)
	var ol := _world([], line, true)
	W.run(gl, 600, 0, W.S)
	W.run(ol, 600, 0, W.S)
	var g_sum := 0
	var o_sum := 0
	for k in range(1, 6):
		g_sum += _dealt(gl, k)[1]
		o_sum += _dealt(ol, k)[1]
	gut.p(
		(
			"AF2 Glaive five in a line 2-6.8 m, 10 s: glaive %d, orbs %d, ratio %.3f"
			% [g_sum, o_sum, float(g_sum) / float(o_sum)]
		)
	)
	assert_gt(ratios[3.0], 0.0)
	assert_gt(g_sum, o_sum, "a line pays: every disc passes through all five both ways")


func test_the_elements_feed_on_its_hits() -> void:
	var w := _world([&"venom_core"])
	W.run(w, 600, 0, W.S)
	var v := W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	gut.p("AF2 Glaive venom feeds in 10 s at 3 m: %d (%d hits)" % [v, _dealt(w, 1)[0]])
	assert_gt(v, 0, "Venom on its hits")
	var f := _world([&"ember_core"])
	W.run(f, 1, 0, W.S)
	W.run(f, 30, 0, 0)
	assert_gt(f.actors.burn_stacks[1], 0, "Fire on its hit")


func test_twin_throws_two_side_by_side_and_three_at_level_five() -> void:
	var w := _world([&"gun_twin"], [])
	W.run(w, 1, 0, W.S)
	assert_eq(_discs(w).size(), 2, "Lv 1: two discs")
	var lv5 := _world([&"gun_twin"], [])
	CardLevels.set_level(lv5, W.item(lv5, &"gun_twin"), 5)
	W.run(lv5, 1, 0, W.S)
	assert_eq(_discs(lv5).size(), 3, "Lv 5: three")
	var primary := 0
	for i in _discs(lv5):
		primary += 1 if lv5.projectiles.second_of(i) == 0 else 0
	assert_eq(primary, 1, "the copies past the primary are secondary")
	assert_lte(ShotCap.shots(Modifiers.bolt(lv5)), 12)


func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_glaive_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_glaive")))
	assert_eq(AttackSlots.form_id(w), &"glaive")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), GLAIVE_ON.has(it.id), "%s with the Glaive" % it.id)


func test_swirl_turns_each_throw_and_it_still_comes_back() -> void:
	var w := _world([&"gun_swirl"], [])
	var angles := {}
	for k in 5:
		W.run(w, 1, 0, W.S)
		for i in _discs(w):
			angles[w.projectiles.ids[i]] = Kin.angle_of(
				Vector2(w.projectiles.vel_x[i], w.projectiles.vel_y[i])
			)
		W.run(w, 41, 0, W.S)
	assert_gt(angles.size(), 1)
	var distinct := {}
	for a: int in angles.values():
		distinct[a] = true
	assert_gt(distinct.size(), 1, "Swirl throws them at random angles")


func test_the_glaive_replaces_the_other_forms() -> void:
	var w := _slot_world()
	var gl := W.item(w, &"gun_glaive")
	for other: StringName in [&"gun_laser", &"gun_bomb", &"gun_void", &"gun_lance", &"gun_scatter"]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(int(Offers.info(w, gl)["replaces"]), o, "the Glaive replaces %s" % other)
		assert_true(BuildSlots.take(w, gl))
		assert_false(w.items_owned.has(o), "the Glaive and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"glaive")
		assert_true(Glaive.is_glaive(Modifiers.bolt(w)))


func test_it_is_deterministic() -> void:
	var a := _world([&"gun_twin", &"ember_core"])
	var b := _world([&"gun_twin", &"ember_core"])
	for x: World in [a, b]:
		W.run(x, 200, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash())
