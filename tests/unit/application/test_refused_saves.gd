extends GutTest
## A run save this build can't resume is refused (EI-09): Continue gets nothing, the file is set aside on disk under
## run.bad.<time>.save with its bytes unchanged (never deleted or written over), and the menu's notice is handed out
## once. An older version's save (another payload version, another save_version, or one recorded by v0.6.1) reads as
## older; a damaged file or a payload without every part reads as unreadable. The profile is its own file and loads.

const V061 := "res://tests/fixtures/saves/v061_blade_floor1.save"

var _dir := ""


func before_each() -> void:
	_dir = "user://test_refused_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _path() -> String:
	return _dir.path_join("run.save")


func _put(bytes: PackedByteArray) -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _kept() -> Array:
	return Array(DirAccess.get_files_at(_dir)).filter(
		func(n: String) -> bool: return n.begins_with("run.bad.")
	)


func _payload() -> Dictionary:
	var run := SaveLab.run_state(41, 1)
	return RunSaver.payload_of(SaveLab.build_floor(run), run, 1, PackedByteArray([1]))


## `bytes` on disk are refused with notice `notice`: kept beside the save with the same bytes, said once, and a fresh
## boot (a new RunSaver over the same file) finds no save and says nothing.
func _assert_refused(bytes: PackedByteArray, notice: String, what: String) -> void:
	_put(bytes)
	var saver := RunSaver.new(RunSaveStore.new(_path()))
	assert_eq(saver.usable(), {}, "%s: nothing to continue" % what)
	assert_false(FileAccess.file_exists(_path()), "%s: set aside" % what)
	var kept := _kept()
	assert_eq(kept.size(), 1, "%s: kept as run.bad.*.save" % what)
	if kept.size() == 1:
		var got := FileAccess.get_file_as_bytes(_dir.path_join(String(kept[0])))
		assert_eq(got, bytes, "%s: the bytes still on disk" % what)
	assert_eq(saver.take_refused(), notice, "%s: the notice" % what)
	assert_eq(saver.take_refused(), "", "%s: once" % what)
	var next_boot := RunSaver.new(RunSaveStore.new(_path()))
	assert_eq(next_boot.usable(), {}, "%s: the next boot has no save" % what)
	assert_eq(next_boot.take_refused(), "", "%s: and says nothing" % what)


func test_a_payload_of_an_older_version_is_refused_and_kept() -> void:
	var p := _payload()
	p["version"] = RunSaver.PAYLOAD_VERSION - 1
	_assert_refused(RunSaveStore.encode(p), RunSaver.REFUSED_OLDER, "payload 4")


func test_a_save_recorded_by_v0_6_1_is_refused_and_kept() -> void:
	_assert_refused(FileAccess.get_file_as_bytes(V061), RunSaver.REFUSED_OLDER, "v0.6.1")


func test_another_save_version_is_refused_as_older() -> void:
	var bytes := RunSaveStore.encode(_payload())
	bytes.encode_u32(4, RunSaveStore.SAVE_VERSION + 1)
	_assert_refused(bytes, RunSaver.REFUSED_OLDER, "save_version")


func test_a_damaged_save_is_refused_and_kept() -> void:
	var bytes := RunSaveStore.encode(_payload())
	bytes[bytes.size() - 1] = bytes[bytes.size() - 1] ^ 0xFF
	_assert_refused(bytes, RunSaver.REFUSED_UNREADABLE, "checksum")


func test_a_payload_without_every_part_is_refused_as_unreadable() -> void:
	var p := _payload()
	(p["run"] as Dictionary).erase("heart_room")
	assert_false(RunSaver.is_usable(p))
	_assert_refused(RunSaveStore.encode(p), RunSaver.REFUSED_UNREADABLE, "a missing key")


func test_todays_payload_is_continued_and_nothing_is_said() -> void:
	var p := _payload()
	assert_true(RunSaver.is_usable(p), "every key payload_of writes is one is_usable asks for")
	for k: String in RunSaver.RUN_KEYS:
		assert_true((p["run"] as Dictionary).has(k), "%s written" % k)
	_put(RunSaveStore.encode(p))
	var saver := RunSaver.new(RunSaveStore.new(_path()))
	assert_eq(saver.usable(), p, "Continue gets it")
	assert_eq(saver.take_refused(), "")
	assert_true(FileAccess.file_exists(_path()), "left where it is")
	assert_eq(_kept().size(), 0)


## A floor that no longer fits its save (FloorPlan's err) is refused the same way, as unreadable.
func test_a_save_that_does_not_fit_its_floor_is_refused() -> void:
	var bytes := RunSaveStore.encode(_payload())
	_put(bytes)
	var saver := RunSaver.new(RunSaveStore.new(_path()))
	saver.refuse("the snapshot doesn't fit")
	assert_eq(FileAccess.get_file_as_bytes(_dir.path_join(String(_kept()[0]))), bytes, "kept")
	assert_eq(saver.take_refused(), RunSaver.REFUSED_UNREADABLE)


func test_the_profile_still_loads_beside_a_refused_save() -> void:
	var p := _payload()
	p["version"] = RunSaver.PAYLOAD_VERSION - 1
	_put(RunSaveStore.encode(p))
	var profile := ProfileStore.new(_dir.path_join("profile.json"))
	profile.section("unlocks")["test_refused"] = true
	profile.section("settings")["language"] = "es"
	assert_true(profile.save_file())
	var saver := RunSaver.new(RunSaveStore.new(_path()))
	assert_eq(saver.usable(), {})
	var back := ProfileStore.open(profile.path)
	assert_true(bool(back.section("unlocks").get("test_refused", false)), "its unlocks")
	assert_eq(String(back.section("settings").get("language", "")), "es", "and its settings")


func test_the_menu_says_why_continue_is_greyed_out() -> void:
	for key: String in [RunSaver.REFUSED_OLDER, RunSaver.REFUSED_UNREADABLE]:
		var menu: MainMenu = autofree(MainMenu.new("v", false, key))
		var l := menu.find_child("SaveNotice", true, false) as Label
		assert_not_null(l, key)
		if l != null:
			assert_eq(l.text, key)
			assert_ne(tr(key), key, "%s has its text" % key)
	var plain: MainMenu = autofree(MainMenu.new("v", true))
	assert_null(plain.find_child("SaveNotice", true, false), "no notice without a refused save")
