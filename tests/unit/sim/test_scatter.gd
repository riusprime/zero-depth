extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F6 "A short-range cone of pellets: brutal up close, weak at range … 6
## pellets, 25°, 5 m range, every 0.55 s", Twin and Backfire yes, the rest off, elements per pellet at a lower chance):
## the Scatter form. Six pellets fanned over 25° every 0.55 s, gone at 5 m; all land up close, fewer at range, none past
## 5 m; the pellets past the centre feed at the secondary proc; Twin doubles the cone within 12 an attack; Backfire
## fires a copy behind; 40 a second at most; its row; its DPS against the orbs (reported, see LANCE_SCATTER.md).

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const SCATTER_ON: Array[StringName] = [
	&"gun_twin",
	&"gun_backfire",
	&"ember_core",
	&"storm_core",
	&"frost_core",
	&"venom_core",
	&"shared_bleed"
]


func _world(
	items: Array = [], at: Array = [Vector2(2.0, 0.0)], orbs: bool = false, r: float = 0.35
) -> World:
	var ids: Array = [] if orbs else [&"gun_scatter"]
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


func _pellets(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.projectiles.size():
		if Scatter.is_pellet(w, i):
			out.append(i)
	return out


func test_the_card_makes_the_shot_a_cone_of_pellets() -> void:
	var w := _world([], [])
	var s := Modifiers.bolt(w)
	assert_true(Scatter.is_scatter(s))
	assert_eq(s.form, AttackSpec.Form.BOLT)
	assert_eq(s.count, 6, "6 pellets")
	assert_eq(s.spread, roundi(25.0 * 4096.0 / 360.0), "over 25°")
	assert_eq(s.period_ticks, 33, "every 0.55 s")
	assert_almost_eq(s.speed * s.life_ticks, 5.0, 0.01, "5 m range")
	assert_eq(s.share_permille, 1000, "each pellet one orb hit")
	var def: ItemDefinition = W.repo().get_def(&"items", &"gun_scatter")
	assert_eq([def.rarity, def.requires_weapon], [ItemDefinition.Rarity.RARE, &"gun"])
	assert_eq(w.item_tables[W.item(w, &"gun_scatter")].slot_category, AttackSlots.FORM)
	assert_eq([def.name_key, def.desc_key], [&"ITEM_GUN_SCATTER", &"ITEM_GUN_SCATTER_DESC"])


func test_a_volley_is_six_pellets_and_the_centre_one_alone_is_primary() -> void:
	var w := _world([], [])
	W.run(w, 1, 0, W.S)
	var p := _pellets(w)
	assert_eq(p.size(), 6)
	var primary := 0
	for i in p:
		primary += 1 if w.projectiles.second_of(i) == 0 else 0
		assert_eq(w.projectiles.damage[i], 5, "one orb hit each")
	assert_eq(primary, 1, "the rest are secondary: their statuses at the lower proc")
	var seen := {}
	for k in 329:
		W.run(w, 1, 0, W.S)
		for i in _pellets(w):
			seen[w.projectiles.ids[i]] = true
	assert_eq(seen.size(), 60, "10 volleys in 5.5 s")


func test_brutal_up_close_weak_at_range_nothing_past_five_metres() -> void:
	var got := {}
	for d: float in [1.2, 3.0, 4.5, 6.0]:
		var w := _world([], [Vector2(d, 0.0)])
		W.run(w, 1, 0, W.S)
		W.run(w, 40, 0, 0)
		got[d] = _dealt(w, 1)[0]
	gut.p("AF1 Scatter pellets landing from one volley at 1.2 / 3 / 4.5 / 6 m: %s" % [got])
	assert_eq(got[1.2], 6, "point blank: all six")
	assert_lt(got[4.5], got[1.2], "fewer at range")
	assert_eq(got[6.0], 0, "past 5 m: none")


func test_single_target_dps_against_the_orbs() -> void:
	var o := _world([], [Vector2(1.5, 0.0)], true)
	W.run(o, 1800, 0, W.S)
	var orbs := _dealt(o, 1, 120, 1800)
	var ratios := {}
	for d: float in [1.5, 3.0, 4.5]:
		var w := _world([], [Vector2(d, 0.0)])
		W.run(w, 1800, 0, W.S)
		var s := _dealt(w, 1, 120, 1800)
		ratios[d] = float(s[1]) / float(orbs[1])
		(
			gut
			. p(
				(
					"AF1 Scatter one target %.1f m, 28 s: %d dmg in %d hits; orbs (1.5 m) %d in %d; ratio %.3f"
					% [d, s[1], s[0], orbs[1], orbs[0], ratios[d]]
				)
			)
		)
	assert_gt(ratios[1.5], 1.0, "brutal up close")
	assert_lt(ratios[4.5], ratios[1.5], "weaker at range")


func test_the_elements_feed_per_pellet_at_the_lower_chance() -> void:
	var w := _world([&"venom_core"], [Vector2(1.2, 0.0)])
	var o := _world([&"venom_core"], [Vector2(1.2, 0.0)], true)
	W.run(w, 600, 0, W.S)
	W.run(o, 600, 0, W.S)
	var v := W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var orbs := W.events(o, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON).size()
	var hits: int = _dealt(w, 1)[0]
	gut.p(
		(
			"AF1 Scatter venom feeds in 10 s point blank: scatter %d (%d pellet hits), orbs %d"
			% [v, hits, orbs]
		)
	)
	assert_lt(v, hits, "not every pellet feeds a whole stack")
	var at: Array = [Vector2(2.0, -0.3), Vector2(2.0, 0.3)]
	var f := _world([&"ember_core"], at)
	W.run(f, 20, 0, W.S)
	for k in [1, 2]:
		assert_gt(f.actors.burn_stacks[k], 0, "Fire on enemy %d" % k)


func test_twin_doubles_the_cone_within_twelve_an_attack() -> void:
	var w := _world([&"gun_twin"], [])
	var twin := W.item(w, &"gun_twin")
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 12, "Lv 1: 2 × 6")
	CardLevels.set_level(w, twin, 5)
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 18, "Lv 5 before the cap: 3 × 6")
	var slots := _slot_world()
	for id: StringName in [&"gun_scatter", &"gun_twin"]:
		assert_true(BuildSlots.take(slots, W.item(slots, id)))
	CardLevels.set_level(slots, W.item(slots, &"gun_twin"), 5)
	assert_lte(ShotCap.shots(Modifiers.bolt(slots)), 12, "a Gun run: at most 12 an attack")


func test_backfire_fires_a_cone_behind_and_the_worst_build_stays_under_forty_a_second() -> void:
	var w := _world([&"gun_backfire"], [])
	W.run(w, 1, 0, W.S)
	var back := 0
	for i in _pellets(w):
		back += 1 if w.projectiles.vel_x[i] < 0.0 else 0
	assert_gt(back, 0, "pellets fly behind")
	var s := _slot_world()
	for id: StringName in [&"gun_scatter", &"gun_twin", &"gun_backfire"]:
		assert_true(BuildSlots.take(s, W.item(s, id)))
	CardLevels.set_level(s, W.item(s, &"gun_twin"), 5)
	CardLevels.set_level(s, W.item(s, &"gun_scatter"), 5)
	var launched := {}
	var most := 0
	var per_tick: Array[int] = []
	var behind := 0
	for k in 600:
		W.run(s, 1, 0, W.S)
		var n := 0
		for i in s.projectiles.size():
			var pid := s.projectiles.ids[i]
			if s.projectiles.team[i] == ActorStore.TEAM_PLAYER and not launched.has(pid):
				launched[pid] = true
				n += 1
				behind += 1 if s.projectiles.vel_x[i] < 0.0 else 0
		per_tick.append(n)
		var window := 0
		for j in range(maxi(0, per_tick.size() - 60), per_tick.size()):
			window += per_tick[j]
		most = maxi(most, window)
	var volleys: Array[int] = []
	for n in per_tick:
		if n > 0:
			volleys.append(n)
	(
		gut
		. p(
			(
				"AF1 Scatter + Twin Lv 5 + Backfire: most launched in any 60 ticks %d; per volley %s; behind %d of %d"
				% [most, volleys.slice(0, 8), behind, launched.size()]
			)
		)
	)
	assert_lte(most, 40, "40 a second at most")
	assert_gt(behind, 0, "Backfire's cone fires on a Gun run too")


func _slot_world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 3
	w.run_floor = 3
	return w


func test_the_scatter_row_offers_only_its_cards() -> void:
	var w := _slot_world()
	assert_true(BuildSlots.take(w, W.item(w, &"gun_scatter")))
	assert_eq(AttackSlots.form_id(w), &"scatter")
	for idx in w.item_tables.size():
		var it := w.item_tables[idx]
		var cat := AttackSlots.category(w, idx)
		if (
			it.retired
			or it.requires_weapon == PlayerTable.WEAPON_BLADE
			or cat in [AttackSlots.FREE, AttackSlots.FORM]
		):
			continue
		assert_eq(AttackSlots.usable(w, idx), SCATTER_ON.has(it.id), "%s with the Scatter" % it.id)


func test_the_scatter_replaces_the_other_forms() -> void:
	var w := _slot_world()
	var sc := W.item(w, &"gun_scatter")
	for other: StringName in [&"gun_laser", &"gun_bomb", &"gun_void", &"gun_lance"]:
		var o := W.item(w, other)
		assert_true(BuildSlots.take(w, o))
		assert_eq(int(Offers.info(w, sc)["replaces"]), o, "the Scatter replaces %s" % other)
		assert_true(BuildSlots.take(w, sc))
		assert_false(w.items_owned.has(o), "the Scatter and %s never coexist" % other)
		assert_eq(AttackSlots.form_id(w), &"scatter")
		assert_true(Scatter.is_scatter(Modifiers.bolt(w)))


func test_it_is_deterministic() -> void:
	var a := _world([&"gun_twin", &"ember_core"])
	var b := _world([&"gun_twin", &"ember_core"])
	for x: World in [a, b]:
		W.run(x, 200, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash())
