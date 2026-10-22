extends GutTest
## v0.8.0 AO (owner O37: "make the order of the attacks be more important … a circle of lightning … 3 attacks make a
## triple circle … a swirl card … a 'storm'"; docs/roadmap/v0.8.0/evidence/ATTACK_ORDER.md): the order rule. Ring is a
## SHAPE card (it takes in what is left of it), Spread and Halo are COUNT cards (they multiply what is left of them),
## Swirl a MOTION card (it moves what is left of it). v0.8.0 N3 (owner O47: "the circle should substitute the fireball
## not be a circle that spawns where you aim"; evidence/N3_RING_AND_LOADING.md): the Ring is the shot itself, a
## lightning ring flying the shot's flight that hits and shocks what it passes over. The five orders compile and fight
## differently; each flies as WandRings says; the caps hold; the old cards' own results don't move. Mechanics only:
## no bot, no balance (the DPS table is the evidence's). v0.9.0 AS (owner Q3: Twin, Halo, Ring and Backfire are
## Patterns, one at a time; Spiral and Swirl ride on any of them; "D45's Ring · Spread · Swirl storm goes"): a count
## can't stand beside the Ring in a legal wand, so the orders left are Ring, Ring · Swirl and Swirl · Ring; the
## count's pulses, the storm's one-after-another rings and the spinning group are gone (a lab spec with a count still
## lays that many rings).

const W := preload("res://tests/support/mx4_world.gd")
const RING := &"gun_ring"
const SPREAD := &"gun_spread"
const SWIRL := &"gun_swirl"
## v0.9.0 AS: the orders a legal wand holds (one Pattern), by name.
const ORDERS := {
	"ring": [RING],
	"ring_swirl": [RING, SWIRL],
	"swirl_ring": [SWIRL, RING],
}
const RADIUS := 1.4


func _bolt(ids: Array) -> AttackSpec:
	return Modifiers.bolt(W.world(&"gun", ids))


## A Gun world holding `ids` in that order (and `enemies`), after one shot and `ticks` more ticks.
func _shot(ids: Array, ticks: int = 0, enemies: Array = []) -> World:
	var w := W.world(&"gun", ids, enemies)
	W.run(w, 1, 0, W.S)
	W.run(w, ticks)
	return w


## Each live ring: [where it left, its centre now, its start tick, its damage, its velocity, its root].
func _rings(w: World) -> Array:
	var out := []
	for k in w.ab.ring_pos.size():
		(
			out
			. append(
				[
					w.ab.ring_pos[k],
					ModifierAbilities.ring_centre(w, k, w.tick),
					w.ab.ring_start[k],
					w.ab.ring_dmg[k],
					w.ab.ring_vel[k],
					w.ab.ring_root[k],
				]
			)
		)
	return out


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


func test_ring_alone_is_the_shot_turned_into_a_shocking_ring_with_its_flight() -> void:
	var plain := _bolt([])
	var s := _bolt([RING])
	assert_eq(s.form, AttackSpec.Form.RING, "the shot becomes a ring")
	assert_eq([s.ring_layout, s.count, s.swirl, s.swirl_group], [1, 1, 0, 0])
	assert_almost_eq(s.radius_m, RADIUS, 1e-5, "the card's radius")
	assert_eq(s.ring_flight, plain.life_ticks, "N3: it flies the shot's flight")
	assert_almost_eq(s.speed, plain.speed, 1e-6, "at the shot's speed")
	assert_true(s.has_status(&"shock"), "it shocks")
	assert_has(s.elements, "storm", "drawn as lightning")
	assert_eq(s.ring_share_permille, 1000)


# --- The order rule (compile) ------------------------------------------------------------------------------------
func test_swirl_right_of_the_ring_throws_it_left_of_the_ring_makes_it_wobble() -> void:
	var a := _bolt([RING, SWIRL])
	var b := _bolt([SWIRL, RING])
	assert_eq([a.count, a.swirl, a.swirl_group], [1, 1, 0], "Ring · Swirl: one ring, thrown")
	assert_eq([b.count, b.swirl, b.swirl_group], [1, 0, 1], "Swirl · Ring: one ring, wobbling")
	var bolt := _bolt([SWIRL])
	assert_eq(
		[bolt.form, bolt.swirl],
		[AttackSpec.Form.BOLT, 1],
		"Swirl alone: a bolt that leaves at random"
	)
	var lab := _bolt([SPREAD, RING])  # a lab's count left of the Ring (no legal wand holds it): not taken in
	assert_eq(
		[lab.form, lab.count], [AttackSpec.Form.RING, 3], "v0.9.0 AS: no pulses, the count stays"
	)


func test_the_orders_compile_and_fight_differently_and_replay() -> void:
	var seen := {}
	for name: String in ORDERS:
		var f := WandLab.run(WandLab.fight(&"gun", ORDERS[name]), 360)
		var again := WandLab.run(WandLab.fight(&"gun", ORDERS[name]), 360)
		assert_eq([again["digest"], again["hash"]], [f["digest"], f["hash"]], "%s replays" % name)
		assert_false(seen.has(f["digest"]), "%s fights unlike the others" % name)
		seen[f["digest"]] = name
		assert_gt(int((f["hits_by_effect"] as Dictionary).get(&"", 0)), 0, "%s lands" % name)


# --- The ring shot in play (WandRings) ---------------------------------------------------------------------------
func test_the_ring_flies_from_the_hero_along_the_aim_growing_and_ends_with_its_flight() -> void:
	var w := _shot([RING])
	var r := _rings(w)
	assert_eq(r.size(), 1, "one ring shot")
	var hero := w.player_pos()
	var from: Vector2 = r[0][0]
	assert_almost_eq((from - hero).length(), w.player.radius_m, 0.01, "it leaves the hero's edge")
	var spec := Modifiers.bolt(w)
	var v: Vector2 = r[0][4]
	assert_almost_eq(v.length(), spec.speed, 1e-4, "at the shot's speed")
	assert_almost_eq(v.normalized().x, 1.0, 1e-3, "along the aim (+x)")
	var r0 := ModifierAbilities.ring_radius(w, 0, w.tick)
	assert_lt(r0, RADIUS, "it starts small")
	W.run(w, WandRings.GROW_TICKS)
	assert_almost_eq(ModifierAbilities.ring_radius(w, 0, w.tick), RADIUS, 1e-4, "and grows")
	var c := ModifierAbilities.ring_centre(w, 0, w.tick)
	assert_gt(c.x, from.x + 2.0, "it travels")
	assert_almost_eq(c.y, from.y, 1e-3, "on its line")
	assert_eq(w.ab.ring_end[0] - w.ab.ring_start[0], spec.ring_flight, "it lives the shot's flight")
	W.run(w, spec.ring_flight)
	assert_false(_rings(w).any(func(e: Array) -> bool: return e[2] == r[0][2]), "then it ends")


func test_the_ring_hits_what_it_passes_once_with_the_whole_hit() -> void:
	var dummies := [[Vector2(3.0, 0.0), 5000], [Vector2(5.0, 0.9), 5000], [Vector2(5.0, 3.5), 5000]]
	var w := W.world(&"gun", [RING], dummies)
	W.run(w, 1, 0, W.S)
	var spec := Modifiers.bolt(w)
	W.run(w, spec.ring_flight + 2)
	var hits := W.damage(w, &"")
	var by := {}
	for e in hits:
		by[e.target_id] = int(by.get(e.target_id, 0)) + 1
	assert_eq(by.size(), 2, "it hits the two it passes over, not the one 3.5 m off its line")
	for id: int in by:
		assert_eq(by[id], 1, "once each")
	var whole := PlayerBuild.bolt_damage(w, Attacks.bolt_base_damage(spec))
	assert_eq(w.ab.ring_dmg.size(), 0, "the shot is over")
	assert_eq(hits[0].amount, whole, "one ring: the whole hit (share 1000)")


func test_ring_swirl_throws_the_ring_its_own_random_way_and_replays() -> void:
	var r := _rings(_shot([RING, SWIRL]))
	assert_eq(r.size(), 1, "one ring")
	var plain := _rings(_shot([RING]))
	assert_ne(Kin.angle_of(r[0][4]), Kin.angle_of(plain[0][4]), "off the aim, its own way")
	assert_eq(_rings(_shot([RING, SWIRL])), r, "replays from the seed (the named stream)")


func test_swirl_left_of_the_ring_flies_it_along_the_aim_wobbling() -> void:
	var w := _shot([SWIRL, RING])
	var r := _rings(w)
	assert_eq(r.size(), 1)
	assert_almost_eq(Kin.angle_of(r[0][4]), 0, 2, "along the aim")
	var orb := RADIUS * WandRings.WOBBLE_PERMILLE / 1000.0
	assert_almost_eq(w.ab.ring_orb[0], orb, 1e-4, "round its line, half a radius out")
	var a := ModifierAbilities.ring_centre(w, 0, w.tick)
	var b := ModifierAbilities.ring_centre(w, 0, w.tick + 5)
	assert_ne(a, b, "moving")


func test_a_wall_cuts_the_rings_flight() -> void:
	var open := _shot([RING])
	var w := W.world(&"gun", [RING])
	w.set_walls([Obb.make(w.player_pos() + Vector2(4.0, 0.0), Vector2(0.3, 6.0), 0)])
	W.run(w, 1, 0, W.S)
	var life := w.ab.ring_end[0] - w.ab.ring_start[0]
	assert_lt(life, open.ab.ring_end[0] - open.ab.ring_start[0], "it stops at the wall")
	var end := ModifierAbilities.ring_centre(w, 0, w.ab.ring_end[0])
	assert_lt(end.x, w.player_pos().x + 3.75, "short of it")


func test_the_launchs_rings_share_a_root_and_the_next_launch_takes_a_new_one() -> void:
	var w := W.world(&"gun", [RING])
	W.run(w, 1, 0, W.S)
	var first := w.ab.ring_root[0]
	for k in w.ab.ring_root.size():
		assert_eq(w.ab.ring_root[k], first)
	var n := w.ab.ring_root.size()
	for t in 60:
		W.run(w, 1, 0, W.S)
		if w.ab.ring_root.size() > n:
			break
	assert_ne(w.ab.ring_root[w.ab.ring_root.size() - 1], first, "a new shot, a new root")


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
	assert_gt(rings.ring_flight, 0, "flying the shards' flight")
	assert_eq(
		_bolt([&"split_shot"]).hooks[0].child.alive_max, 0, "a plain Split's shards: no new cap"
	)


# --- Old saves ----------------------------------------------------------------------------------------------------
func test_a_ring_from_before_n3_is_a_plain_ring_that_grows_where_it_was() -> void:
	var w := _shot([RING], 2)
	var ab := w.ab
	for f: StringName in [&"ring_vel", &"ring_orb", &"ring_orb_a", &"ring_pulse", &"ring_k"]:
		var empty: Variant = ab.get(f)
		empty.resize(0)
		ab.set(f, empty)  # an older save's rings: no travel columns
	var at := ab.ring_pos[0]
	W.run(w, 1)
	assert_eq(ab.ring_pulse.size(), ab.ring_pos.size(), "padded")
	if not ab.ring_pos.is_empty():
		assert_eq(ModifierAbilities.ring_centre(w, 0, w.tick), at, "it stays where it was")


# --- The old cards stay as they were ----------------------------------------------------------------------------
func test_the_old_cards_results_dont_move() -> void:
	# Spread and Halo are COUNT cards now, but without a Ring nothing reads that: their bolts are as before.
	for ids: Array in [[SPREAD], [&"halo_shot"], [SPREAD, &"halo_shot"], [&"halo_shot", SPREAD]]:
		var s := _bolt(ids)
		assert_eq([s.form, s.ring_layout, s.swirl, s.ring_flight], [AttackSpec.Form.BOLT, 0, 0, 0])
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
