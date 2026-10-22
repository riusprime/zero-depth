extends GutTest
## v0.7.5 SM (owner N8): the first-run hints' store (the profile's hints section) and the dev panels' release switch
## (DevGate). A hint is due once; marking keeps it in the profile (and survives a save and a load); reset forgets them
## all; "Show hints: Off" makes none due. The switch is ON in this project, and project.godot's public_release override
## turns it OFF.


func test_a_hint_is_due_once_and_reset_forgets_it() -> void:
	var p := ProfileStore.new("")
	var s := HintStore.new(p)
	assert_true(s.enabled(), "hints are on by default")
	assert_true(s.due(&"move"))
	s.mark(&"move")
	assert_true(s.dirty, "the profile has something to write")
	assert_false(s.due(&"move"), "seen once, not again")
	assert_true(s.due(&"attack"), "the others still are")
	assert_eq(p.section("hints")["seen"], ["move"], "kept in the profile's hints section")
	s.mark(&"move")
	assert_eq(p.section("hints")["seen"].size(), 1, "marked once")
	s.reset()
	assert_true(s.due(&"move"), "Reset hints: due again")
	assert_eq(s.seen_ids(), [] as Array[StringName])


func test_show_hints_off_makes_none_due() -> void:
	var p := ProfileStore.new("")
	var s := HintStore.new(p)
	GameSettings.set_value(p, HintStore.SETTING, "off")
	for id in HintStore.IDS:
		assert_false(s.due(id), "%s isn't due with hints off" % id)


func test_seen_hints_survive_a_save_and_a_load() -> void:
	var path := "user://test_hint_store_profile.json"
	var p := ProfileStore.new(path)
	HintStore.new(p).mark(&"vent")
	assert_true(p.save_file())
	var again := ProfileStore.open(path)
	assert_true(HintStore.new(again).seen(&"vent"), "read back from the file")
	assert_false(HintStore.new(again).seen(&"move"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_an_old_profile_with_a_bad_hints_section_reads_as_none_seen() -> void:
	var p := ProfileStore.new("")
	p.data["hints"] = {"seen": "not a list"}
	var s := HintStore.new(p)
	assert_true(s.due(&"move"))
	s.mark(&"move")
	assert_false(s.due(&"move"))


func test_the_dev_panel_switch_is_on_here_and_off_for_a_public_release() -> void:
	assert_true(DevGate.enabled(), "playtest builds keep F10 (owner: all builds, hidden key)")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://project.godot"), OK)
	assert_eq(cfg.get_value("game", "dev/panel_enabled"), true)
	assert_eq(
		cfg.get_value("game", "dev/panel_enabled.%s" % DevGate.RELEASE_FEATURE),
		false,
		"the public_release feature tag locks it"
	)
	assert_eq(DevGate.SETTING, "game/dev/panel_enabled")
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	for s in presets.get_sections():
		if presets.has_section_key(s, "custom_features"):
			assert_false(
				String(presets.get_value(s, "custom_features")).contains(DevGate.RELEASE_FEATURE),
				"%s isn't a public release yet: the panel stays ON" % s
			)
