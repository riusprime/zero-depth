extends GutTest
## v0.9.0 AF2 (owner Q7; ATTACK_FORMS.md F8 "Three small darts that curve to the nearest enemies … 3 × 45 % a shot,
## every 0.3 s, homing 360 °/s", every pattern and motion card off, elements "all: lower status chance per dart"): the
## Seekers form. Three darts every 0.3 s at 45 % an orb hit each; they curve to the nearest enemies, one each when there
## are three; the darts past the centre feed at the secondary proc; 3 an attack, under 40 a second; its row; its DPS
## against the orbs (reported, see GLAIVE_SEEKERS.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
## v0.9.5 FC7: the five elements, and the eleven cards the row takes now (SeekerMods).
const SEEKERS_ON: Array[StringName] = [
	&"ember_core",
	&"storm_core",
	&"frost_core",
	&"venom_core",
	&"shared_bleed",
	&"gun_twin",
	&"halo_shot",
	&"gun_ring",
	&"gun_pierce",
	&"gun_ricochet",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"orbit_rounds",
]
## Three enemies spread round the aim: ahead, and 40° either side, at 4, 5 and 6 m.
const SPREAD: Array[Vector2] = [Vector2(4.0, 0.0), Vector2(3.83, 3.21), Vector2(4.6, -3.86)]


func _world(
	items: Array = [], at: Array = [Vector2(3.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_seekers"]
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


func _darts(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if Seekers.is_dart(w, i):
			out.append(i)
	return out


func test_the_card_makes_the_shot_three_homing_darts() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	assert_true(Seekers.is_seekers(s))
	assert_eq(s.form, AttackSpec.Form.BOLT)
	assert_eq(s.count, 3, "3 darts")
	assert_eq(s.period_ticks, 18, "every 0.3 s")
	assert_eq(s.homing, roundi(360.0 * 4096.0 / 360.0 / 60.0), "homing 360 °/s")
	assert_eq(s.share_permille, 450, "45 % an orb hit each")
	assert_almost_eq(
		s.speed * s.life_ticks, 10.0, 0.01, "10 m/s for 1 s: slow enough to curve onto a near enemy"
	)
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_seekers")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_seekers")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_SEEKERS", &"ITEM_GUN_SEEKERS_DESC"])


func test_a_volley_is_three_darts_and_the_centre_one_alone_is_primary() -> void:
	var w := _world([], [])
	W.run(w, 1, 0, W.S)
	var p := _darts(w)
	assert_eq(p.size(), 3)
	var primary := 0
	for i in p:
		primary += 1 if w.projectiles.second_of(i) == 0 else 0
		assert_eq(w.projectiles.damage[i], 2, "45 % of 5, rounded")
	assert_eq(primary, 1, "the rest are secondary: their statuses at the lower proc")


func test_they_curve_to_an_enemy_off_the_aim() -> void:
	var w := _world([], [Vector2(0.0, 4.0)])  # 90° off the aim
	W.run(w, 1, 0, W.S)
	W.run(w, 50, 0, 0)
	var got := _dealt(w, 1)
	gut.p("AF2 Seekers one volley at an enemy 90° off the aim, 4 m: %d hits" % got[0])
	assert_eq(got[0], 3, "all three curve onto it")


func test_three_darts_spread_over_three_enemies() -> void:
	var w := _world([], SPREAD)
	W.run(w, 1, 0, W.S)
	W.run(w, 50, 0, 0)
	var hits := []
	for k in [1, 2, 3]:
		hits.append(_dealt(w, k)[0])
	gut.p("AF2 Seekers one volley over three spread enemies (4, 5, 6 m): hits %s" % [hits])
	assert_eq(hits, [1, 1, 1], "one dart each")


func test_single_target_and_spread_dps_against_the_orbs() -> void:
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
					"AF2 Seekers one target %.1f m, 28 s: %d dmg in %d hits; orbs (3 m) %d in %d; ratio %.3f"
					% [d, s[1], s[0], orbs[1], orbs[0], ratios[d]]
				)
			)
		)
	var sw := _world([], SPREAD)
	var ow := _world([], SPREAD, true)
	W.run(sw, 600, 0, W.S)
	W.run(ow, 600, 0, W.S)
	var s_sum := 0
	var o_sum := 0
	for k in range(1, 4):
		s_sum += _dealt(sw, k)[1]
		o_sum += _dealt(ow, k)[1]
	gut.p(
		(
			"AF2 Seekers three spread enemies, aim straight, 10 s: seekers %d, orbs %d, ratio %.3f"
			% [s_sum, o_sum, float(s_sum) / float(o_sum)]
		)
	)
	assert_gt(ratios[3.0], 0.0)
	assert_gt(s_sum, 0)


func test_the_elements_feed_per_dart_at_the_lower_chance() -> void:
	var w := _world([&"venom_core"])
	var o := _world([&"venom_core"], [Vector2(3.0, 0.0)], true)
	W.run(w, 600, 0, W.S)
	W.run(o, 600, 0, W.S)
	var v := W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var orbs := W.events(o, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var hits: int = _dealt(w, 1)[0]
	gut.p(
		(
			"AF2 Seekers venom feeds in 10 s at 3 m: seekers %d (%d dart hits), orbs %d"
			% [v, hits, orbs]
		)
	)
	assert_lt(v, hits, "not every dart feeds a whole stack")
	var f := _world([&"ember_core"], SPREAD)
	W.run(f, 120, 0, W.S)
	for k in [1, 2, 3]:
		assert_gt(f.actors.burn_stacks[k], 0, "Fire on enemy %d within 2 s" % k)


func test_three_an_attack_and_under_forty_a_second() -> void:
	var w := _world([], [])
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 3)
	var launched := {}
	var per_tick: Array[int] = []
	var most := 0
	for k in 600:
		W.run(w, 1, 0, W.S)
		var n := 0
		for i in w.projectiles.size():
			var pid := w.projectiles.ids[i]
			if w.projectiles.team[i] == ActorStore.TEAM_PLAYER and not launched.has(pid):
				launched[pid] = true
				n += 1
		per_tick.append(n)
		var window := 0
		for j in range(maxi(0, per_tick.size() - 60), per_tick.size()):
			window += per_tick[j]
		most = maxi(most, window)
	gut.p("AF2 Seekers: most launched in any 60 ticks %d" % most)
	assert_lte(most, 40)


func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_seekers_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_seekers")))
	assert_eq(AttackSlots.form_id(w), &"seekers")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), SEEKERS_ON.has(it.id), "%s with the Seekers" % it.id)


func test_the_seekers_replace_the_other_forms() -> void:
	var w := _slot_world()
	var sk := W.item(w, &"gun_seekers")
	for other: StringName in [
		&"gun_laser", &"gun_bomb", &"gun_void", &"gun_glaive", &"gun_scatter"
	]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(int(Offers.info(w, sk)["replaces"]), o, "the Seekers replace %s" % other)
		assert_true(BuildSlots.take(w, sk))
		assert_false(w.items_owned.has(o), "the Seekers and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"seekers")
		assert_true(Seekers.is_seekers(Modifiers.bolt(w)))


func test_it_is_deterministic() -> void:
	var a := _world([&"ember_core"], SPREAD)
	var b := _world([&"ember_core"], SPREAD)
	for x: World in [a, b]:
		W.run(x, 200, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash())
