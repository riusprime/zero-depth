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


func test_the_ability_hud_follows_the_slots() -> void:
	InputDefaults.apply()  # the keys come from the live bindings
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"blade"))
	var w := World.new(3, t)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	var hud := AbilityHud.new()
	add_child_autofree(hud)
	var reader := WorldReader.new(w)
	hud.sync(reader)
	assert_eq(hud.filled_count(), 1, "the weapon")
	assert_ne(hud.slot(0).key_text, "", "a manual slot shows its key")
	Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER))
	Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BLINK))
	w.blink_cd = 100
	hud.sync(reader)
	assert_eq(hud.filled_count(), 3)
	assert_eq(hud.slot(1).key_text, "", "an auto slot has no key")
	assert_eq(hud.slot(2).ability_id, &"blink")
	assert_lt(hud.slot(2).fill, 1.0, "the cooldown sweep")
	assert_gt(hud.slot(2).seconds, 1.0, "with the seconds left")
	assert_gt(AbilityHud.SLOT, 40.0, "clearly bigger than the dash square (owner, 2026-10-07)")
