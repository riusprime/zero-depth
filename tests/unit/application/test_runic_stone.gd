extends GutTest
## v0.9.5 RS1 (RUNIC_STONE.md): the Runic Stone's cipher (every line round-trips through glyphs), its learned lines in
## the profile's lazy `runes` section (order, idempotence, the pulse flag), an old profile without it, the death
## threshold (R2, also on load) and the 7-presses-in-a-row rule (R3).

const OLD_PROFILE := "user://rs1_old_profile.json"

var _repo: ContentRepository
var _lines: RunicLinesDefinition


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_lines = _repo.get_def(&"runic_lines", &"main")


func after_all() -> void:
	DirAccess.remove_absolute(OLD_PROFILE)


func _stone() -> RunicStone:
	return RunicStone.new(ProfileStore.new(""), _lines)


func test_the_lines_are_valid_content() -> void:
	assert_not_null(_lines, "data/hub/runic_lines.tres")
	assert_eq(_lines.validate().size(), 0)
	assert_eq(_lines.lines.size(), 10, "r1 to r10 (RS2 added r4 to r10 as data)")
	assert_eq(_lines.line(&"r1").english, "WHAT SLEEPS BELOW REMEMBERS")
	assert_eq(_lines.line(&"r2").english, "YOU RETURN AND RETURN")
	assert_eq(_lines.line(&"r3").english, "PATIENCE IS A KEY")


func test_a_broken_line_is_caught() -> void:
	var bad := _lines.duplicate(true) as RunicLinesDefinition
	bad.lines[0].english = "lower case"
	bad.lines[1].id = &"r1"
	var codes := []
	for i in bad.validate():
		codes.append(i.code)
	assert_has(codes, &"runic_text")
	assert_has(codes, &"runic_dup")


func test_every_line_round_trips_through_the_glyphs() -> void:
	for l in _lines.lines:
		var glyphs := RuneCipher.encode(l.english)
		assert_eq(RuneCipher.decode(glyphs), l.english, "%s decodes back" % l.id)
		for g in glyphs:
			assert_true(g == RuneCipher.GAP or (g >= 0 and g < RuneCipher.GLYPHS))
			if g != RuneCipher.GAP:
				assert_gt(RunicGlyphs.strokes(g).size(), 0, "glyph %d has strokes" % g)


func test_the_table_covers_all_24_runes_and_only_q_and_x_share() -> void:
	var seen := {}
	for g in RuneCipher.LETTER_GLYPH:
		seen[g] = int(seen.get(g, 0)) + 1
	assert_eq(seen.size(), 24, "every one of the 24 runes is a letter")
	assert_eq(RuneCipher.LETTER_GLYPH.size(), 26)
	assert_eq(RunicGlyphs.NAMES.size(), 24)
	var shared := []
	for g: int in seen:
		if seen[g] > 1:
			shared.append(g)
	shared.sort()
	assert_eq(shared, [5, 14], "kaunan (K, Q) and algiz (Z, X)")


func test_lines_wrap_at_14_glyphs_at_word_breaks() -> void:
	for l in _lines.lines:
		for row: Array in RuneCipher.wrap(RuneCipher.encode(l.english), 14):
			assert_lte(row.size(), 14)
	var rows := RuneCipher.wrap(RuneCipher.encode("WHAT SLEEPS BELOW REMEMBERS"), 14)
	assert_eq(rows.size(), 3)
	assert_eq(RuneCipher.decode(rows[0] as Array[int]), "WHAT SLEEPS")
	assert_eq(RuneCipher.decode(rows[1] as Array[int]), "BELOW")
	assert_eq(RuneCipher.decode(rows[2] as Array[int]), "REMEMBERS")
	assert_eq(RuneCipher.wrap(RuneCipher.encode("A"), 14).size(), 1)


func test_learning_is_idempotent_ordered_and_sets_the_pulse() -> void:
	var s := _stone()
	assert_false(s.is_awake())
	assert_false(s.pending_pulse)
	assert_true(s.learn(&"r1"))
	assert_true(s.pending_pulse)
	assert_false(s.learn(&"r1"), "twice learns nothing")
	assert_true(s.learn(&"r3"))
	assert_false(s.learn(&"r99"), "an unknown line is refused")
	assert_true(s.learn(&"r2"))
	assert_eq(s.learned(), [&"r1", &"r3", &"r2"], "in the order learned")
	assert_eq(s.newest_first(), [&"r2", &"r3", &"r1"])
	assert_true(s.is_awake())
	assert_eq(s.profile.section("runes")["learned"], ["r1", "r3", "r2"], "strings in the profile")


func test_reading_goes_newest_first_and_cycles() -> void:
	var s := _stone()
	assert_eq(s.read_next(), &"")
	s.learn(&"r1")
	s.learn(&"r2")
	assert_eq([s.read_next(), s.read_next(), s.read_next()], [&"r2", &"r1", &"r2"])
	s.walked_away()
	assert_eq(s.read_next(), &"r2", "newest again after walking away")


func test_an_old_profile_without_runes_loads_and_saves_as_it_was() -> void:
	var f := FileAccess.open(OLD_PROFILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"profile_version": 3, "settings": {}}))
	f.close()
	var p := ProfileStore.open(OLD_PROFILE)
	var s := RunicStone.new(p, _lines)
	assert_eq(s.learned(), [], "none learned")
	assert_false(s.is_awake())
	assert_false(p.data.has("runes"), "reading creates nothing")
	s.learn(&"r1")
	assert_true(p.save_file())
	assert_true(
		ProfileStore.open(OLD_PROFILE).data.has("runes"), "the section appears on the first write"
	)
	assert_true(RunicStone.new(ProfileStore.open(OLD_PROFILE), _lines).is_awake())


func test_r1_wakes_on_a_purple_activation() -> void:
	var s := _stone()
	assert_eq(s.sync(0, 0), [])
	assert_eq(s.sync(1, 0), [&"r1"])
	assert_true(s.is_awake())
	assert_eq(s.sync(5, 0), [], "once")


func test_r2_at_ten_deaths_also_on_load() -> void:
	var s := _stone()
	assert_eq(s.sync(0, 9), [])
	assert_eq(s.sync(0, 10), [&"r2"])
	# A profile whose Codex already holds 10 deaths (enemies and a boss) learns it on the next sync (the hub's load).
	var p := ProfileStore.new("")
	var codex := CodexStore.new(p)
	codex.add(&"enemies", &"swarmer", &"deaths", 6)
	codex.add(&"bosses", &"warlord", &"deaths", 4)
	var loaded := RunicStone.new(p, _lines)
	assert_eq(loaded.sync_from(AchievementStore.new(p), codex), [&"r2"])
	assert_false(loaded.is_awake(), "r2 alone doesn't wake the stone")
	assert_eq(loaded.sync_from(AchievementStore.new(p), codex), [], "and only once")


func test_the_purple_stat_wakes_it_through_the_stores() -> void:
	var p := ProfileStore.new("")
	var ach := AchievementStore.new(p)
	var s := RunicStone.new(p, _lines)
	assert_eq(s.sync_from(ach, CodexStore.new(p)), [])
	ach.add_stat(RunicStone.PURPLE_STAT)
	assert_eq(s.sync_from(ach, CodexStore.new(p)), [&"r1"])


func test_r3_needs_seven_presses_each_within_three_seconds() -> void:
	var s := _stone()
	s.learn(&"r1")
	for i in 6:
		assert_false(s.press(i * 100), "press %d" % (i + 1))
	var t := 500 + RunicStone.WINDOW_TICKS + 1
	assert_false(s.press(t), "a gap over 3 s starts the count again (this is the first)")
	for i in 5:
		assert_false(s.press(t + 10 * (i + 1)), "press %d of the new run" % (i + 2))
	assert_false(s.knows(&"r3"))
	assert_true(s.press(t + 60), "the seventh in a row")
	assert_true(s.knows(&"r3"))
	assert_false(s.press(t + 70), "learned once")


func test_walking_away_resets_the_r3_count() -> void:
	var s := _stone()
	s.learn(&"r1")
	for i in 6:
		s.press(i)
	s.walked_away()
	assert_false(s.press(7), "the seventh after walking away is the first")
	assert_false(s.knows(&"r3"))
