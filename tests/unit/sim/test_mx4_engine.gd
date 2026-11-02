extends GutTest
## v0.6.0 MX4: the engine parts around the M-list: the dash, walking, a blink and Vent as specs (Vent's blast keeps
## its numbers) and the spec read for the views (v0.10.5 O1: the legendary versions, the ability mods and the
## inherited every-N status went with their cards).
## Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const TRIG := AttackSpec.Trigger


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


## v0.6.0 MX4 for MX3's views: the read carries the pattern's way, the motion cues and the weight.
func test_the_spec_read_carries_what_the_views_draw() -> void:
	var cases := [
		[&"halo_shot", "directions", "circle"],
		[&"gun_backfire", "directions", "back"],
		[&"gun_homing", "home", true],
	]
	for c: Array in cases:
		var read := Modifiers.bolt(W.world(&"gun", [c[0]])).read()
		assert_eq(read[c[1]], c[2], "%s: %s" % [c[0], c[1]])
	var plain := Modifiers.bolt(W.world(&"gun")).read()
	assert_eq(
		[plain["directions"], plain["home"], plain["return"], plain["damage_mul_permille"]],
		["forward", false, false, 1000]
	)
