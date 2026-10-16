extends GutTest
## v0.8.0 AO (owner O37: "make the order of the attacks be more important … a circle of lightning … 3 attacks make a
## triple circle … a swirl card … a 'storm'"; docs/roadmap/v0.8.0/evidence/ATTACK_ORDER.md): the order rule. Ring is a
## SHAPE card (it takes in what is left of it), Spread and Halo are COUNT cards (they multiply what is left of them),
## Swirl a MOTION card (it moves what is left of it). The five orders the lead named compile and fight differently;
## each lays its rings as WandRings says; the caps hold; the old cards' own results don't move. Mechanics only: no
## bot, no balance.

const W := preload("res://tests/support/mx4_world.gd")
const RING := &"gun_ring"
const SPREAD := &"gun_spread"
const SWIRL := &"gun_swirl"
## The lead's five orders (and the plain Ring), by name.
const ORDERS := {
	"ring": [RING],
	"ring_spread": [RING, SPREAD],
	"spread_ring": [SPREAD, RING],
	"ring_spread_swirl": [RING, SPREAD, SWIRL],
	"swirl_ring_spread": [SWIRL, RING, SPREAD],
}


func _bolt(ids: Array) -> AttackSpec:
	return Modifiers.bolt(W.world(&"gun", ids))


## A Gun world holding `ids` in that order, a dummy row 3-5 m ahead, after one shot and `ticks` more ticks.
func _shot(ids: Array, ticks: int = 1) -> World:
	var w := W.world(&"gun", ids, [[Vector2(3.0, 0.0), 5000], [Vector2(4.5, 1.0), 5000]])
	W.run(w, 1, 0, W.S)
	W.run(w, ticks)
	return w


# --- The cards ---------------------------------------------------------------------------------------------------
func test_ring_swirl_and_spread_are_gun_wand_cards_of_their_order_kind() -> void:
	var w := W.world(&"gun")
	var want := {
		RING: ModifierTable.OrderKind.SHAPE,
		SPREAD: ModifierTable.OrderKind.COUNT,
		&"halo_shot": ModifierTable.OrderKind.COUNT,
		SWIRL: ModifierTable.OrderKind.MOTION,
		&"gun_big_shot": ModifierTable.OrderKind.FREE,
	}
	for id: StringName in want:
		var k := W.item(w, id)
		assert_gte(k, 0, "%s shipped" % id)
		assert_eq(Wand.order_of(w, k), want[id], "%s's order kind" % id)
		assert_true(CardLevels.is_card(w, k), "%s is a wand card" % id)
		assert_eq(
			w.item_tables[k].requires_weapon, PlayerTable.WEAPON_GUN, "%s: the Gun's pool" % id
		)
	for id: StringName in [RING, SWIRL]:
		assert_eq(w.item_tables[W.item(w, id)].rarity, ItemTable.RARE, "%s is rare" % id)
		var key := w.item_tables[W.item(w, id)].name_key
		assert_ne(String(tr(key)), String(key), "%s has an en name" % id)


func test_ring_alone_is_one_lightning_circle_that_shocks() -> void:
	var s := _bolt([RING])
	assert_eq(s.form, AttackSpec.Form.RING, "the shot becomes a ring")
	assert_eq([s.ring_layout, s.count, s.ring_pulses, s.swirl, s.swirl_group], [1, 1, 0, 0, 0])
	assert_almost_eq(s.radius_m, 2.5, 1e-5, "the card's radius")
	assert_true(s.has_status(&"shock"), "it shocks")
	assert_has(s.elements, "storm", "drawn as lightning")
	assert_eq(s.ring_share_permille, 850)


# --- The order rule (compile) ------------------------------------------------------------------------------------
func test_ring_then_spread_is_three_rings_spread_then_ring_is_one_ring_of_three_pulses() -> void:
	var a := _bolt([RING, SPREAD])
	var b := _bolt([SPREAD, RING])
	assert_eq([a.count, a.ring_pulses], [3, 0], "Ring · Spread: three rings")
	assert_eq(
		[b.count, b.ring_pulses, b.spread],
		[1, 3, 0],
		"Spread · Ring: one ring, three pulses, no fan"
	)
	assert_eq(_bolt([SPREAD]).count, 3, "Spread alone is still a 3-shot fan")
	assert_eq(_bolt([SPREAD]).ring_layout, 0)


func test_swirl_right_of_the_rings_throws_each_left_of_the_ring_throws_the_group() -> void:
	var a := _bolt([RING, SPREAD, SWIRL])
	var b := _bolt([SWIRL, RING, SPREAD])
	assert_eq(
		[a.count, a.swirl, a.swirl_group], [3, 1, 0], "Ring · Spread · Swirl: three thrown rings"
	)
	assert_eq(
		[b.count, b.swirl, b.swirl_group],
		[3, 0, 1],
		"Swirl · Ring · Spread: one thrown group of three"
	)
	var bolt := _bolt([SWIRL])
	assert_eq(
		[bolt.form, bolt.swirl],
		[AttackSpec.Form.BOLT, 1],
		"Swirl alone: a bolt that leaves at random"
	)


func test_the_five_orders_compile_and_fight_differently_and_replay() -> void:
	var seen := {}
	for name: String in ORDERS:
		var f := WandLab.run(WandLab.fight(&"gun", ORDERS[name]), 360)
		var again := WandLab.run(WandLab.fight(&"gun", ORDERS[name]), 360)
		assert_eq([again["digest"], again["hash"]], [f["digest"], f["hash"]], "%s replays" % name)
		assert_false(seen.has(f["digest"]), "%s fights unlike the others" % name)
		seen[f["digest"]] = name
		assert_gt(int((f["hits_by_effect"] as Dictionary).get(&"", 0)), 0, "%s lands" % name)


# --- The rings in play (WandRings) -------------------------------------------------------------------------------
func _rings(w: World) -> Array:
	var out := []
	for k in w.ab.ring_pos.size():
		out.append([w.ab.ring_pos[k], w.ab.ring_start[k], w.ab.ring_dmg[k]])
	return out


func test_ring_alone_lays_one_ring_in_front_of_the_hero() -> void:
	var w := _shot([RING], 0)
	var r := _rings(w)
	assert_eq(r.size(), 1)
	var at: Vector2 = r[0][0]
	var hero := w.player_pos()
	assert_almost_eq(
		(at - hero).length(), 2.5 * WandRings.FRONT_PERMILLE / 1000.0, 0.01, "in front"
	)
	assert_gt(at.x, hero.x, "along the aim")
	assert_eq(
		r[0][2], PlayerBuild.bolt_damage(w, Modifiers.bolt(w).damage), "one ring: the whole hit"
	)


func test_ring_spread_lays_three_rings_round_the_centre_each_at_085() -> void:
	var w := _shot([RING, SPREAD], 0)
	var r := _rings(w)
	assert_eq(r.size(), 3, "three rings")
	var whole := PlayerBuild.bolt_damage(w, Attacks.bolt_base_damage(Modifiers.bolt(w)))
	var centre := w.player_pos() + Vector2(2.5 * WandRings.FRONT_PERMILLE / 1000.0, 0.0)
	for e: Array in r:
		assert_almost_eq(
			(e[0] - centre).length(), 2.5 * WandRings.LAYOUT_PERMILLE / 1000.0, 0.01, "round it"
		)
		assert_eq(e[1], r[0][1], "together")
		assert_eq(e[2], maxi(1, whole * 850 / 1000), "each 0.85 of the hit")
	assert_ne(r[0][0], r[1][0])
	assert_ne(r[1][0], r[2][0])


func test_spread_ring_lays_three_pulses_on_one_spot() -> void:
	var w := _shot([SPREAD, RING], 0)
	var r := _rings(w)
	assert_eq(r.size(), 3, "three pulses")
	for k in 3:
		assert_eq(r[k][0], r[0][0], "one spot")
		assert_eq(r[k][1] - r[0][1], k * WandRings.PULSE_GAP_TICKS, "a pulse every gap")


func test_the_storm_throws_each_ring_and_the_group_throw_keeps_the_triangle() -> void:
	var w := _shot([RING, SPREAD, SWIRL], 0)
	var r := _rings(w)
	assert_eq(r.size(), 3)
	var hero := w.player_pos()
	var lo := 2.5 * WandRings.SPOT_MIN_PERMILLE / 1000.0 - 0.01
	var hi := 2.5 * WandRings.SPOT_MAX_PERMILLE / 1000.0 + 0.01
	for k in 3:
		var d: float = (r[k][0] - hero).length()
		assert_between(d, lo, hi, "ring %d thrown round the hero" % k)
		assert_eq(r[k][1] - r[0][1], k * WandRings.SWIRL_GAP_TICKS, "one after the other")
	var g := _rings(_shot([SWIRL, RING, SPREAD], 0))
	assert_eq(g.size(), 3)
	var c: Vector2 = (g[0][0] + g[1][0] + g[2][0]) / 3.0
	for e: Array in g:
		assert_almost_eq(
			(e[0] - c).length(), 2.5 * WandRings.LAYOUT_PERMILLE / 1000.0, 0.01, "a triangle"
		)
		assert_eq(e[1], g[0][1], "together")
	var again := _rings(_shot([RING, SPREAD, SWIRL], 0))
	assert_eq(again, r, "the storm replays from the seed (the named stream)")


func test_a_waiting_pulse_hits_nothing_until_it_starts() -> void:
	var w := W.world(&"gun", [SPREAD, RING], [[Vector2(3.0, 0.0), 5000]])
	W.run(w, 1, 0, W.S)
	var hits := func() -> int: return W.damage(w, &"").size()
	W.run(w, WandRings.PULSE_GAP_TICKS - 1)
	var first: int = hits.call()
	assert_eq(first, 1, "the first pulse hit the dummy once")
	W.run(w, WandRings.PULSE_GAP_TICKS * 2 + 2)
	assert_eq(hits.call(), 3, "then each pulse once more")


func test_the_triple_shocks_more_than_one_ring() -> void:
	var stacks := {}
	for name: String in ["ring", "ring_spread"]:
		var w := W.world(&"gun", ORDERS[name], [[Vector2(2.75, 0.0), 5000]])
		W.run(w, 1, 0, W.S)
		W.run(w, 20)
		stacks[name] = w.actors.shock_stacks[1]
	assert_gt(stacks["ring_spread"], stacks["ring"], "each ring is its own root: %s" % str(stacks))


# --- Caps ----------------------------------------------------------------------------------------------------------
func test_the_ring_cap_holds_and_leaves_a_limit_event() -> void:
	var w := W.world(&"gun", [RING, SPREAD, &"halo_shot", SWIRL])
	for id: StringName in [SPREAD, &"halo_shot"]:
		CardLevels.set_level(w, W.item(w, id), CardLevels.MAX_LEVEL)
	Modifiers.invalidate(w)
	var most := 0
	for t in 120:
		W.run(w, 1, 0, W.S)
		most = maxi(most, w.ab.ring_pos.size())
	assert_eq(most, WandRings.RINGS_MAX, "never more than the cap")
	assert_gt(
		W.events(w, SimEvent.Kind.LIMIT, WandRings.EFFECT_RING_CAP).size(), 0, "and it says so"
	)
	var p := _bolt_world([SPREAD, RING], 5)
	assert_eq(
		Modifiers.bolt(p).ring_pulses, 11, "a level-5 Spread left of the Ring: 11 shots taken in"
	)
	W.run(p, 1, 0, W.S)
	assert_eq(p.ab.ring_pos.size(), WandRings.PULSES_MAX, "but one shot pulses 5 times at most")


func _bolt_world(ids: Array, level: int) -> World:
	var w := W.world(&"gun", ids)
	for id: StringName in ids:
		CardLevels.set_level(w, W.item(w, id), level)
	Modifiers.invalidate(w)
	return w


func test_a_rings_shards_are_capped_split_left_of_the_ring_makes_ring_shards() -> void:
	var a := _bolt([RING, &"split_shot"])
	var shards := W.hook_of(a, &"split_shot").child
	assert_eq(shards.form, AttackSpec.Form.BOLT)
	assert_eq(
		shards.alive_max, WandRings.RING_CHILD_ALIVE_MAX, "Ring · Split: the ring's shards, capped"
	)
	var b := _bolt([&"split_shot", RING])
	var rings := W.hook_of(b, &"split_shot").child
	assert_eq(rings.form, AttackSpec.Form.RING, "Split · Ring: the shards become rings too")
	assert_eq(rings.ring_layout, 1)
	assert_eq(
		_bolt([&"split_shot"]).hooks[0].child.alive_max, 0, "a plain Split's shards: no new cap"
	)


# --- The old cards stay as they were ----------------------------------------------------------------------------
func test_the_old_cards_results_dont_move() -> void:
	# Spread and Halo are COUNT cards now, but without a Ring nothing reads that: their bolts are as before.
	for ids: Array in [[SPREAD], [&"halo_shot"], [SPREAD, &"halo_shot"], [&"halo_shot", SPREAD]]:
		var s := _bolt(ids)
		assert_eq([s.form, s.ring_layout, s.ring_pulses, s.swirl], [AttackSpec.Form.BOLT, 0, 0, 0])
	assert_eq(_bolt([&"halo_shot", SPREAD]).count, 5, "Halo · Spread: 3 + 2")
	assert_eq(_bolt([SPREAD, &"halo_shot"]).count, 9, "Spread · Halo: 3 × 3")


# --- The wand's read ----------------------------------------------------------------------------------------------
func test_the_wand_read_marks_each_cards_order_kind() -> void:
	var w := W.world(&"gun", [SWIRL, RING, SPREAD, &"gun_big_shot"])
	var cards: Array = Wand.read(w)["cards"]
	var kinds := []
	for c: Dictionary in cards:
		kinds.append(int(c["order"]))
	assert_eq(
		kinds,
		[
			ModifierTable.OrderKind.MOTION,
			ModifierTable.OrderKind.SHAPE,
			ModifierTable.OrderKind.COUNT,
			ModifierTable.OrderKind.FREE
		]
	)
