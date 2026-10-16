extends GutTest
## v0.8.0 AO (owner O37: "make the order of the attacks be more important … a circle of lightning … 3 attacks make a
## triple circle … a swirl card … a 'storm'"; docs/roadmap/v0.8.0/evidence/ATTACK_ORDER.md): the order rule. Ring is a
## SHAPE card (it takes in what is left of it), Spread and Halo are COUNT cards (they multiply what is left of them),
## Swirl a MOTION card (it moves what is left of it). v0.8.0 N3 (owner O47: "the circle should substitute the fireball
## not be a circle that spawns where you aim"; evidence/N3_RING_AND_LOADING.md): the Ring is the shot itself, a
## lightning ring flying the shot's flight that hits and shocks what it passes over. The five orders compile and fight
## differently; each flies as WandRings says; the caps hold; the old cards' own results don't move. Mechanics only:
## no bot, no balance (the DPS table is the evidence's).

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
	assert_eq([s.ring_layout, s.count, s.ring_pulses, s.swirl, s.swirl_group], [1, 1, 0, 0, 0])
	assert_almost_eq(s.radius_m, RADIUS, 1e-5, "the card's radius")
	assert_eq(s.ring_flight, plain.life_ticks, "N3: it flies the shot's flight")
	assert_almost_eq(s.speed, plain.speed, 1e-6, "at the shot's speed")
	assert_true(s.has_status(&"shock"), "it shocks")
	assert_has(s.elements, "storm", "drawn as lightning")
	assert_eq(s.ring_share_permille, 1000)


# --- The order rule (compile) ------------------------------------------------------------------------------------
func test_ring_then_spread_is_three_ring_shots_spread_then_ring_is_one_ring_of_three_pulses(
) -> void:
	var a := _bolt([RING, SPREAD])
	var b := _bolt([SPREAD, RING])
	assert_eq([a.count, a.ring_pulses], [3, 0], "Ring · Spread: three ring shots")
	assert_gt(a.spread, 0, "in a fan")
	assert_eq(
		[b.count, b.ring_pulses, b.spread],
		[1, 3, 0],
		"Spread · Ring: one ring shot, three pulses, no fan"
	)
	assert_eq(_bolt([SPREAD]).count, 3, "Spread alone is still a 3-shot fan")
	assert_eq(_bolt([SPREAD]).ring_layout, 0)


func test_swirl_right_of_the_rings_scatters_each_left_of_the_ring_spins_the_group() -> void:
	var a := _bolt([RING, SPREAD, SWIRL])
	var b := _bolt([SWIRL, RING, SPREAD])
	assert_eq([a.count, a.swirl, a.swirl_group], [3, 1, 0], "Ring · Spread · Swirl: the storm")
	assert_eq(
		[b.count, b.swirl, b.swirl_group], [3, 0, 1], "Swirl · Ring · Spread: one spinning group"
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


func test_ring_spread_is_a_fan_of_three_ring_shots_at_the_multi_share() -> void:
	var w := _shot([RING, SPREAD])
	var r := _rings(w)
	assert_eq(r.size(), 3, "three ring shots")
	var spec := Modifiers.bolt(w)
	var offsets := Attacks.shot_offsets(spec)
	var whole := PlayerBuild.bolt_damage(w, Attacks.bolt_base_damage(spec))
	for k in 3:
		var v: Vector2 = r[k][4]
		assert_almost_eq(Kin.angle_of(v), offsets[k] & 4095, 2, "ring %d on the fan's line" % k)
		assert_eq(r[k][2], r[0][2], "together")
		assert_eq(r[k][3], maxi(1, whole * WandRings.MULTI_PERMILLE / 1000), "each the multi share")
		assert_eq(r[k][5], r[0][5], "one root for the launch")
	assert_ne(r[0][4], r[2][4], "apart")


func test_spread_ring_is_one_bigger_ring_shot_that_pulses_three_times() -> void:
	var w := _shot([SPREAD, RING])
	assert_eq(w.ab.ring_pos.size(), 1, "one ring shot")
	assert_eq(w.ab.ring_pulse[0], 3, "of three pulses")
	var big := RADIUS * (1000 + WandRings.PULSE_GROW_PERMILLE * 2) / 1000.0
	assert_almost_eq(w.ab.ring_r[0], big, 1e-4, "bigger per pulse")
	var life := w.ab.ring_end[0] - w.ab.ring_start[0]
	var seg := life / 3
	var t0 := w.ab.ring_start[0]
	var late := ModifierAbilities.ring_radius(w, 0, t0 + seg - 1)
	assert_almost_eq(late, big, 1e-4, "the first pulse grew to the whole")
	assert_lt(ModifierAbilities.ring_radius(w, 0, t0 + seg), late, "the next grows out again")


func test_a_pulsing_ring_hits_what_it_carries_once_per_pulse() -> void:
	var dummy := [[Vector2(4.0, 0.0), 5000]]
	var one := W.world(&"gun", [RING], dummy)
	W.run(one, 1, 0, W.S)
	W.run(one, Modifiers.bolt(one).ring_flight + 2)
	assert_eq(W.damage(one, &"").size(), 1, "a plain ring: once")
	var three := W.world(&"gun", [SPREAD, RING], dummy)
	W.run(three, 1, 0, W.S)
	W.run(three, Modifiers.bolt(three).ring_flight + 2)
	var n := W.damage(three, &"").size()
	assert_between(n, 2, 3, "a three-pulse ring: once per pulse it covers the dummy (%d)" % n)


func test_the_storm_sends_each_ring_its_own_random_way_one_after_another() -> void:
	var w := _shot([RING, SPREAD, SWIRL])
	var r := _rings(w)
	assert_eq(r.size(), 3)
	var angles := {}
	for k in 3:
		assert_eq(r[k][2] - r[0][2], k * WandRings.SWIRL_GAP_TICKS, "one after the other")
		angles[Kin.angle_of(r[k][4])] = true
	assert_eq(angles.size(), 3, "each its own way")
	var again := _rings(_shot([RING, SPREAD, SWIRL]))
	assert_eq(again, r, "the storm replays from the seed (the named stream)")


func test_swirl_left_of_the_ring_spins_the_group_round_one_travelling_centre() -> void:
	var w := _shot([SWIRL, RING, SPREAD])
	var r := _rings(w)
	assert_eq(r.size(), 3)
	var orb := RADIUS * WandRings.GROUP_ORBIT_PERMILLE / 1000.0
	for e: Array in r:
		assert_eq(e[2], r[0][2], "together")
		assert_eq(e[0], r[0][0], "from one spot")
		assert_eq(e[4], r[0][4], "one velocity: along the aim")
	for t in [0, 7, 15]:
		var c := Vector2.ZERO
		var cs := []
		for k in 3:
			cs.append(ModifierAbilities.ring_centre(w, k, w.tick + t))
			c += cs[k]
		c /= 3.0
		for p: Vector2 in cs:
			assert_almost_eq((p - c).length(), orb, 0.01, "round the centre at tick +%d" % t)
	var a := ModifierAbilities.ring_centre(w, 0, w.tick)
	var b := ModifierAbilities.ring_centre(w, 0, w.tick + 5)
	assert_ne(a, b, "spinning")


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
	var w := W.world(&"gun", [RING, SPREAD])
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
	var p := _bolt_world([SPREAD, RING], 5)
	assert_eq(
		Modifiers.bolt(p).ring_pulses, 11, "a level-5 Spread left of the Ring: 11 shots taken in"
	)
	W.run(p, 1, 0, W.S)
	assert_eq(p.ab.ring_pulse[0], WandRings.PULSES_MAX, "but one ring pulses 5 times at most")


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
		assert_eq(
			[s.form, s.ring_layout, s.ring_pulses, s.swirl, s.ring_flight],
			[AttackSpec.Form.BOLT, 0, 0, 0, 0]
		)
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
