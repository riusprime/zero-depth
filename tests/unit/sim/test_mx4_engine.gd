extends GutTest
## v0.6.0 MX4: the engine parts around the M-list: the legendary versions (the boss's tier only), the three ability
## mods as modifiers of ops (Cluster Payload, Overclocked Drone, Afterimage), the dash, walking, a blink and Vent as
## specs (Vent's blast keeps its numbers), and an inherited every-N status counting its own form's hits (MX2's gaps).
## Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const TRIG := AttackSpec.Trigger


func test_the_legendary_versions_are_stronger() -> void:
	var w := W.world(&"gun", [&"tempest_core"])
	var k := W.hook_of(Modifiers.bolt(w), &"tempest_core")
	assert_eq([k.child.chains, k.damage_permille], [3, 750])
	var t := w.item_tables[W.item(w, &"tempest_core")]
	assert_eq(t.rarity, ItemTable.LEGENDARY)
	var inferno := W.item(w, &"inferno_core")
	assert_false(ItemPool.available(w).has(inferno), "never in a chest's pool")
	assert_true(ItemPool.available(w, true).has(inferno), "the boss's tier draws it")


func test_cluster_payload_is_an_on_end_lob_of_three_that_never_splits_again() -> void:
	var w := W.world(&"blade", [&"cluster_payload"], [[Vector2(3.0, 0.0), 2000]], [&"bomb_lobber"])
	var bomb := Modifiers.ability(w, Abilities.owned_of_kind(w, AbilityTable.Kind.BOMB_LOBBER))
	var k := W.hook_of(bomb, &"cluster_payload")
	assert_eq(
		[k.trigger, k.child.form, k.child.count, k.damage_permille], [TRIG.ON_END, FORM.LOB, 3, 400]
	)
	assert_null(W.hook_of(k.child, &"cluster_payload"), "bomblets never split")


func test_overclocked_drone_is_a_rate_on_the_drone_spec() -> void:
	var w := W.world(&"gun", [&"overclocked_drone"], [], [&"drone_buddy"], true)
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	assert_eq(Modifiers.ability(w, t).heat_rate_permille, 8)
	w.heat.milli = 50 * HeatTable.MILLI
	assert_lt(AbilityMods.drone_period(w, 60), 60, "faster with heat")


func test_afterimage_is_a_waiting_hook_on_the_blink_spec() -> void:
	var w := W.world(&"blade", [], [], [&"blink"])
	w.add_item(W.item(w, &"afterimage"))
	var k := AbilityMods.echo_hook(w)
	assert_not_null(k)
	assert_eq([k.delay_ticks, k.damage, k.child.form], [24, 18, FORM.BURST])


func test_the_dash_and_vent_are_specs_and_vent_keeps_its_numbers() -> void:
	var w := W.world(&"blade", [], [[Vector2(1.0, 0.0), 2000]], [], true)
	for id: StringName in [
		Modifiers.DASH, Modifiers.MOVE, Modifiers.BLINK, Modifiers.BODY, Modifiers.VENT
	]:
		assert_true(Modifiers.book(w).has(id), "%s has a spec" % id)
	assert_almost_eq(Modifiers.vent(w).radius_m, w.heat.table.vent_radius_m, 1e-6)
	w.heat.milli = w.heat.table.overclock_threshold * HeatTable.MILLI
	W.run(w, 2, W.V)
	var vent := W.damage(w, Heat.EFFECT_VENT)
	assert_eq(vent.size(), 1, "the blast through the vent spec hits once")


func test_an_inherited_every_n_status_counts_its_own_form() -> void:
	var w := W.world(&"gun", [&"cinder_shot"], [], [&"arc_field"])
	var field := Modifiers.ability(w, Abilities.owned_of_kind(w, AbilityTable.Kind.ARC_FIELD))
	assert_eq(field.every_of(&"burn"), 3, "the field inherits Cinder Shot's every-3rd burn")
	var applied := 0
	for n in 6:
		if ModifierRuntime.every_hit(w, field, &"burn", 3):
			applied += 1
	assert_eq(applied, 2, "every third of the field's own hits")


## v0.6.0 MX4 for MX3's views: the read carries the pattern's way, the motion cues and the weight.
func test_the_spec_read_carries_what_the_views_draw() -> void:
	var cases := [
		[&"halo_shot", "directions", "circle"],
		[&"rearguard", "directions", "back"],
		[&"seeker", "home", true],
		[&"boomerang", "return", true],
		[&"short_fuse", "damage_mul_permille", 1400],
	]
	for c: Array in cases:
		var read := Modifiers.bolt(W.world(&"gun", [c[0]])).read()
		assert_eq(read[c[1]], c[2], "%s: %s" % [c[0], c[1]])
	var plain := Modifiers.bolt(W.world(&"gun")).read()
	assert_eq(
		[plain["directions"], plain["home"], plain["return"], plain["damage_mul_permille"]],
		["forward", false, false, 1000]
	)
