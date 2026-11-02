extends GutTest
## v0.10.5 O5a (owner L2; docs/roadmap/v0.10.5/O5_LOOPS.md): the run records (deepest loop and fastest true ending per
## weapon), the loop robes, the loop achievements and the fragments a loop earns.


func _profile() -> ProfileStore:
	return ProfileStore.new("")


func test_the_deepest_loop_is_kept_per_weapon_with_the_run_that_set_it() -> void:
	var p := _profile()
	assert_eq(RunRecords.best_loop(p), 0, "a fresh profile: no record")
	assert_false(RunRecords.note_loop(p, &"gun", 1, 7), "loop 1 is no record")
	assert_true(RunRecords.note_loop(p, &"gun", 2, 7), "loop 2: a new record")
	assert_false(RunRecords.note_loop(p, &"gun", 2, 9), "the same loop again is not")
	assert_true(RunRecords.note_loop(p, &"gun", 3, 7))
	assert_true(RunRecords.note_loop(p, &"blade", 2, 11), "each weapon has its own")
	assert_eq(RunRecords.best_loop(p, &"gun"), 3)
	assert_eq(RunRecords.best_loop(p, &"blade"), 2)
	assert_eq(RunRecords.best_loop(p), 3, "the deepest over every weapon")
	assert_true(RunRecords.holds_loop(p, &"gun", 3, 7), "run 7 holds the Gun's record at loop 3")
	assert_false(RunRecords.holds_loop(p, &"gun", 3, 9), "another run does not")
	assert_false(RunRecords.holds_loop(p, &"gun", 2, 7), "nor the same run at a shallower loop")


func test_the_fastest_true_ending_only_goes_down() -> void:
	var p := _profile()
	assert_true(RunRecords.note_win(p, &"gun", 60 * 900, 1), "the first win is a record")
	assert_false(RunRecords.note_win(p, &"gun", 60 * 1000, 2), "a slower one is not")
	assert_true(RunRecords.note_win(p, &"gun", 60 * 800, 3), "a faster one is")
	assert_eq(RunRecords.best_win_ticks(p, &"gun"), 60 * 800)
	assert_eq(RunRecords.best_win_ticks(p, &"blade"), 0, "the Blade has none")
	assert_eq(RunRecords.time_text(self, 60 * 800), "13:20")


func test_records_survive_the_profile_file() -> void:
	var path := "user://test_loop_records_profile.json"
	var p := ProfileStore.new(path)
	p.load_file()
	RunRecords.note_loop(p, &"blade", 4, 5)
	RunRecords.note_win(p, &"blade", 4321, 5)
	assert_true(p.save_file())
	var q := ProfileStore.new(path)
	q.load_file()
	assert_eq(RunRecords.best_loop(q, &"blade"), 4, "the JSON round trip keeps the loop")
	assert_eq(RunRecords.best_win_ticks(q, &"blade"), 4321, "and the time")
	assert_true(RunRecords.holds_loop(q, &"blade", 4, 5), "and the run that set it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_an_old_profile_has_no_records_and_the_hub_lines_say_so() -> void:
	var p := _profile()
	var lines := RunRecords.lines(self, p)
	assert_eq(lines.size(), 2)
	assert_eq(
		lines[0],
		(
			tr("UI_RECORD_LOOP")
			% (
				"%s %s · %s %s"
				% [tr("BUILD_GUN"), tr("UI_RECORD_NONE"), tr("BUILD_BLADE"), tr("UI_RECORD_NONE")]
			)
		)
	)
	RunRecords.note_loop(p, &"gun", 3, 1)
	assert_true(RunRecords.lines(self, p)[0].contains("%s 3" % tr("BUILD_GUN")), "the Gun's loop 3")


func test_the_loop_robes_unlock_at_loops_three_and_five() -> void:
	var p := _profile()
	var repo := ContentRepository.load_all()
	assert_eq(RunRecords.unlock_loop_robes(p, 2), [] as Array[StringName], "loop 2: none")
	assert_eq(RunRecords.unlock_loop_robes(p, 3), [&"ouroboros"] as Array[StringName])
	assert_eq(RunRecords.unlock_loop_robes(p, 3), [] as Array[StringName], "once")
	assert_eq(RunRecords.unlock_loop_robes(p, 6), [&"abyssal"] as Array[StringName])
	for id: StringName in [&"ouroboros", &"abyssal"]:
		var def: RobeDefinition = repo.get_def(&"robe", id)
		assert_not_null(def, "%s is content" % id)
		assert_true(Wardrobe.robe_unlocked(p, def), "%s is worn-able" % id)
		assert_false(String(def.unlock_hint_key).is_empty(), "earned, not sold")
		assert_false(MetaProgress.wares(repo).has(def), "not at the Progression Station")


func test_the_loop_achievements_read_the_deepest_loop() -> void:
	var profile := _profile()
	var codex := CodexStore.new(profile)
	var store := AchievementStore.new(profile)
	var repo := ContentRepository.load_all()
	var book := AchievementBook.build(repo, store, codex, CodexCatalog.build(repo))
	var tracker := AchievementTracker.new(book)
	tracker.raise(RunRecords.LOOP_STAT, 2)
	assert_false(store.is_unlocked(&"loop_3"))
	tracker.raise(RunRecords.LOOP_STAT, 3)
	assert_true(store.is_unlocked(&"loop_3"), "loop 3 reached")
	assert_false(store.is_unlocked(&"loop_5"))
	tracker.raise(RunRecords.LOOP_STAT, 2)
	assert_eq(store.stat(RunRecords.LOOP_STAT), 3, "raised, never lowered")
	tracker.raise(RunRecords.LOOP_STAT, 5)
	assert_true(store.is_unlocked(&"loop_5"), "loop 5 reached")
	tracker.enabled = false
	tracker.raise(RunRecords.LOOP_STAT, 9)
	assert_eq(store.stat(RunRecords.LOOP_STAT), 5, "a tweaked run records nothing")


func test_fragments_grow_by_half_a_loop() -> void:
	var def: RuneFragmentsDefinition = ContentRepository.load_all().get_def(
		&"rune_fragments", &"rune_fragments"
	)
	assert_eq(def.loop_bonus_permille, 500, "the starting value: +50 % a loop")
	var t := FragmentTable.new()
	t.loop_bonus_permille = 500
	assert_eq(RuneFragments.loop_scaled(t, 10, 1), 10, "loop 1 as before")
	assert_eq(RuneFragments.loop_scaled(t, 10, 2), 15, "loop 2 ×1.5")
	assert_eq(RuneFragments.loop_scaled(t, 10, 3), 20, "loop 3 ×2")
	assert_eq(RuneFragments.loop_scaled(t, 3, 2), 4, "rounded down")
	assert_eq(RuneFragments.loop_permille(t, 3), 2000)
	assert_eq(RuneFragments.loop_permille(null, 3), 1000, "no table: no bonus")


func test_a_loop_two_floor_earns_its_bonus_and_a_collectible_too() -> void:
	var t := FragmentTable.new()
	t.loop_bonus_permille = 500
	var w := CombatLab.world()
	w.boss_flow = BossFlow.create(0)
	w.boss_flow.state = BossFlow.State.OPEN
	w.loop = 1
	var one := RuneFragments.of_floor(w, t, true)
	assert_eq(one, t.boss + t.floor_cleared, "loop 1: the boss and the floor")
	w.loop = 2
	assert_eq(RuneFragments.of_floor(w, t, true), one * 3 / 2, "loop 2: ×1.5")
	var run := RunState.new()
	run.fragment_table = t
	run.loop = 3
	RuneFragments.add_collectibles(run, 2)
	assert_eq(run.fragments_done, t.collectible * 2 * 2, "a collectible on loop 3: ×2")


func test_the_recap_says_new_record_and_the_loop_bonus() -> void:
	var p := (
		EndPanel
		. new(
			false,
			WorldReader.KIND_WARDEN,
			&"",
			{
				"floor": 2,
				"floors": 5,
				"loop": 3,
				"fragments": 30,
				"fragments_total": 90,
				"loop_bonus_permille": 2000,
				"record_loop": true,
				"record_time": false,
				"rules": PackedStringArray(["LOOP_RULE_SWIFT_NAME", "LOOP_RULE_SHIELDED_NAME"]),
			}
		)
	)
	assert_eq(p.recap_line("RecordLoop"), tr("UI_RECAP_RECORD_LOOP") % 3, "new record: loop 3")
	assert_eq(p.recap_line("RecordTime"), "", "no time record")
	assert_eq(p.recap_line("LoopBonus"), tr("UI_RECAP_LOOP_BONUS") % "2.0", "the loop's ×2.0")
	assert_eq(
		p.recap_line("Rules"),
		tr("UI_RECAP_RULES") % (tr("LOOP_RULE_SWIFT_NAME") + " · " + tr("LOOP_RULE_SHIELDED_NAME"))
	)
	p.free()
	var q := EndPanel.new(false, WorldReader.KIND_WARDEN, &"", {"floor": 1, "fragments": 3})
	assert_eq(q.recap_line("LoopBonus"), "", "loop 1: no bonus line")
	assert_eq(q.recap_line("RecordLoop"), "")
	q.free()


func test_the_hub_achievements_page_shows_the_records_first() -> void:
	var profile := _profile()
	var codex := CodexStore.new(profile)
	var store := AchievementStore.new(profile)
	var repo := ContentRepository.load_all()
	var book := AchievementBook.build(repo, store, codex, CodexCatalog.build(repo))
	RunRecords.note_loop(profile, &"blade", 4, 2)
	RunRecords.note_win(profile, &"gun", 60 * 75, 3)
	var page := AchievementsPage.new(book)
	add_child_autofree(page)
	page.refresh()
	var lines := page.record_lines()
	assert_eq(lines, RunRecords.lines(page, profile), "the Records lines")
	assert_true(lines[0].contains("%s 4" % tr("BUILD_BLADE")), "the Blade's loop 4")
	assert_true(lines[1].contains("%s 01:15" % tr("BUILD_GUN")), "the Gun's 01:15")
