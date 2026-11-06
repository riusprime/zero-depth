extends GutTest
## v0.6.0 MX4 (MODIFIER_ENGINE §4: an overlay only where the spec alone isn't readable): ModifierOverlays shows
## a drop over each poisoned enemy and a mark where a queued launch waits; it reads
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


func test_poisoned_enemies_and_queued_launches_are_marked() -> void:
	var w := W.world(&"gun", [&"venom_core", &"gun_echo"], [[Vector2(2.5, 0.0), 2000]])
	W.run(w, 12, 0, W.S)
	var o := _overlay(w)
	assert_eq(o.count_shown("drops"), 1, "the poisoned dummy")
	assert_gt(o.count_shown("marks"), 0, "a repeat waits")
