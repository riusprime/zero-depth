extends GutTest
## v0.9.0 AF1 (owner Q7; ATTACK_FORMS.md F6 "A short-range cone of pellets: brutal up close, weak at range … 6
## pellets, 25°, 5 m range, every 0.55 s", Twin and Backfire yes, the rest off, elements per pellet at a lower chance):
## the Scatter form. Six pellets fanned over 25° every 0.55 s, gone at 5 m; all land up close, fewer at range, none past
## 5 m; the pellets past the centre feed at the secondary proc; Twin doubles the cone within 12 an attack; Backfire
## fires a copy behind; its DPS against the orbs (reported, see LANCE_SCATTER.md). v0.9.5 FC0: the card is retired into
## the Rune Explosion (no row, never offered); its code stays reachable for a held retired card, so these tests stay.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000


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


func test_twin_doubles_the_cone() -> void:
	var w := _world([&"gun_twin"], [])
	var twin := W.item(w, &"gun_twin")
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 12, "Lv 1: 2 × 6")
	CardLevels.set_level(w, twin, 5)
	assert_eq(ShotCap.shots(Modifiers.bolt(w)), 18, "Lv 5 before the cap: 3 × 6")


func test_backfire_fires_a_cone_behind() -> void:
	var w := _world([&"gun_backfire"], [])
	W.run(w, 1, 0, W.S)
	var back := 0
	for i in _pellets(w):
		back += 1 if w.projectiles.vel_x[i] < 0.0 else 0
	assert_gt(back, 0, "pellets fly behind")


## v0.9.5 FC0 (owner: Rune Explosion replaces Scatter): the Scatter card is retired (migration.tres), has no form row
## and is never offered; the code stays for a retired card the dev panel can still grant (the tests above).
func test_the_scatter_has_no_row_and_is_never_offered() -> void:
	var w := W.world(&"gun")
	var sc := W.item(w, &"gun_scatter")
	assert_true(w.item_tables[sc].retired, "retired")
	assert_does_not_have(ItemPool.available(w), sc, "never offered")
	var slots: AttackSlotsDefinition = W.repo().get_def(&"wand", &"attack_slots")
	for f in slots.forms:
		assert_ne(f.card, &"gun_scatter", "no row")


func test_it_is_deterministic() -> void:
	var a := _world([&"gun_twin", &"ember_core"])
	var b := _world([&"gun_twin", &"ember_core"])
	for x: World in [a, b]:
		W.run(x, 200, 0, W.S)
	assert_eq(a.state_hash(), b.state_hash())
