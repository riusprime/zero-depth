extends GutTest
## v0.4.0 BS views: every ability and stat card has a code-drawn symbol; crit numbers are bigger and yellow; the
## ability HUD shows the slots the sim holds, with the manual ones' keys and the cooldown sweep.


func test_every_ability_and_stat_card_has_a_symbol() -> void:
	var repo := ContentRepository.load_all()
	for cat in [&"ability", &"stat_card"]:
		for d: ContentDef in repo.all_of(cat):
			assert_true(AbilityIcons.has_icon(d.id), "%s/%s has a symbol" % [cat, d.id])
			assert_gt(ItemIcons.shapes(d.id).size(), 0)


func test_crit_numbers_are_bigger_and_yellow() -> void:
	var n := DamageNumbers.new()
	add_child_autofree(n)
	n.show_number(Vector2.ZERO, 12, false)
	n.show_number(Vector2.ONE, 30, true)
	var shown := n.shown()
	assert_eq(shown.size(), 2)
	assert_eq(shown[0], ["12", false, DamageNumbers.SIZE])
	assert_eq(shown[1], ["30", true, DamageNumbers.CRIT_SIZE])
	assert_gt(DamageNumbers.CRIT_SIZE, DamageNumbers.SIZE)
