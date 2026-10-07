extends GutTest


func test_settings_round_trip_through_a_profile_file() -> void:
	var path := "user://test_profile_roundtrip.json"
	var p := ProfileStore.new(path)
	GameSettings.set_value(p, "audio/ambience", 35)
	InputRemap.set_binding(p, &"dash", [[&"key", KEY_SHIFT]])
	assert_true(p.save_file())
	var q := ProfileStore.open(path)
	assert_eq(int(GameSettings.get_value(q, "audio/ambience")), 35)
	InputRemap.apply(q)
	var events := InputMap.action_get_events(&"dash")
	assert_eq(events.size(), 1)
	assert_eq(
		(events[0] as InputEventKey).physical_keycode,
		KEY_SHIFT,
		"the stored key comes back as a key code"
	)
	InputDefaults.apply()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameSettings.set_value(ProfileStore.new(""), "audio/ambience", 60)


## v0.3.0 O: the volumes apply to the buses by name when they exist (the audio workstream adds SFX and Ambience).
func test_volume_moves_its_bus() -> void:
	var p := ProfileStore.new("")
	var added := AudioServer.get_bus_index("Effects") == -1
	if added:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Effects")
	GameSettings.set_value(p, "audio/sfx", 50)
	var bus := AudioServer.get_bus_index("Effects")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5), 0.01)
	assert_ne(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), "Master is its own slider")
	GameSettings.set_value(p, "audio/sfx", 80)
	if added:
		AudioServer.remove_bus(bus)


func test_a_volume_without_its_bus_is_kept_and_harmless() -> void:
	var p := ProfileStore.new("")
	var missing := AudioServer.get_bus_index("Ambience") == -1
	GameSettings.set_value(p, "audio/ambience", 25)
	assert_eq(
		int(GameSettings.get_value(p, "audio/ambience")), 25, "stored even before the bus exists"
	)
	if missing:
		pass_test("no Ambience bus yet; nothing to move")
	GameSettings.set_value(p, "audio/ambience", 60)


func test_corrupt_profile_is_kept_and_a_fresh_one_starts() -> void:
	var path := "user://test_profile_bad.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var p := ProfileStore.open(path)
	assert_eq(p.section("settings"), {}, "fresh")
	assert_false(FileAccess.file_exists(path), "moved aside")
	var kept := Array(DirAccess.get_files_at("user://")).filter(
		func(n: String) -> bool: return n.begins_with("profile.bad.")
	)
	assert_gt(kept.size(), 0, "the bad file is kept, never deleted")
	for n in kept:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + n))
