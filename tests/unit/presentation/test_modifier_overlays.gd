extends GutTest
## v0.6.0 MX4 (MODIFIER_ENGINE §4: an overlay only where the spec alone isn't readable): ModifierOverlays shows
## Aether Shell's shell while it is up, Ascension's ring while the next attack is charged, Phase Dash's veil during
## the intangible dash, a drop over each poisoned enemy and a mark where a queued launch waits; it reads
## WorldReader.modifier_marks only (EI-07) and shows nothing without the cards.

const W := preload("res://tests/support/mx4_world.gd")


func _overlay(w: World) -> ModifierOverlays:
	var o := ModifierOverlays.new()
	add_child_autofree(o)
	o.sync(WorldReader.new(w))
	return o


func test_nothing_shows_without_the_cards() -> void:
	var w := W.world(&"blade")
	W.run(w, 200)
	var o := _overlay(w)
	for what in ["shell", "charge", "phase"]:
		assert_false(o.shown(what), what)
	assert_eq([o.count_shown("drops"), o.count_shown("marks")], [0, 0])


func test_the_shell_and_the_charge_show_after_three_quiet_seconds() -> void:
	var w := W.world(&"blade", [&"aether_shell", &"ascension"])
	var early := _overlay(w)
	assert_false(early.shown("shell"), "not up at the start")
	W.run(w, 200)
	var o := _overlay(w)
	assert_true(o.shown("shell"), "the barrier is up")
	assert_true(o.shown("charge"), "the next attack is charged")


func test_the_phase_veil_shows_for_the_intangible_dash() -> void:
	var w := W.world(&"blade", [&"phase_dash"])
	W.run(w, 2, W.D, 0, 0, Vector2i(SimTick.MOVE_MAX, 0))
	assert_true(w.is_dashing())
	assert_true(_overlay(w).shown("phase"))


func test_poisoned_enemies_and_queued_launches_are_marked() -> void:
	var w := W.world(&"gun", [&"venom_core", &"twin_cast"], [[Vector2(2.5, 0.0), 2000]])
	W.run(w, 12, 0, W.S)
	var o := _overlay(w)
	assert_eq(o.count_shown("drops"), 1, "the poisoned dummy")
	assert_gt(o.count_shown("marks"), 0, "a repeat waits")
