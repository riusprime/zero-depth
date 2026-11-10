extends GutTest
## A run save written by an older version, through main.tscn with real input only. The save on disk is one recorded
## with v0.6.1's own code (tests/fixtures/saves/v061_blade_floor1.save, payload 3). The menu refuses it: Continue is
## greyed out, a line under the rows says why (in the player's language), and the file is kept on disk under
## run.bad.<time>.save with its bytes unchanged. Play then starts a new run, and the profile on disk still loads. The
## next boot says nothing more.

const SAVE := "res://tests/fixtures/saves/v061_blade_floor1.save"

var _dir := ""


func before_each() -> void:
	_dir = "user://e2e_old_save_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	Input.action_release(&"ui_accept")
	TranslationServer.set_locale("en")
	if DirAccess.dir_exists_absolute(_dir):
		for f in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _menu(main: Main) -> Node:
	return main.get_node_or_null("UI/MainMenu")


func _notice(main: Main) -> Label:
	var menu := _menu(main)
	return menu.find_child("SaveNotice", true, false) as Label if menu != null else null


func _kept() -> Array:
	return Array(DirAccess.get_files_at(_dir)).filter(
		func(n: String) -> bool: return n.begins_with("run.bad.")
	)


## The recorded older save, written where the game reads its run save.
func _old_save_on_disk() -> String:
	var path := _dir.path_join("run.save")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(SAVE))
	f.close()
	return path


func test_an_older_run_save_is_refused_kept_and_reported() -> void:
	var path := _old_save_on_disk()
	var profile := ProfileStore.new(_dir.path_join("profile.json"))
	profile.section("unlocks")["e2e_old_save"] = true
	assert_true(profile.save_file(), "a profile on disk")
	var e := E2e.new(self)
	var main: Main = await e.boot(ProfileStore.open(profile.path), RunSaveStore.new(path))
	assert_not_null(_menu(main), "the main menu")
	var cont := _menu(main).find_child("Continue", true, false) as Button
	assert_true(cont.disabled, "no Continue for a save this version refuses")
	var notice := _notice(main)
	assert_not_null(notice, "the menu says why")
	if notice != null:
		assert_eq(
			notice.tr(notice.text),
			"Your saved run came from an older version and can't be resumed.",
			"in English"
		)
	assert_false(FileAccess.file_exists(path), "not left where Continue reads")
	var kept := _kept()
	assert_eq(kept.size(), 1, "kept on disk as run.bad.*.save")
	if kept.size() == 1:
		var got := FileAccess.get_file_as_bytes(_dir.path_join(String(kept[0])))
		assert_eq(got, FileAccess.get_file_as_bytes(SAVE), "its bytes unchanged")
	assert_true(
		bool(main.profile.section("unlocks").get("e2e_old_save", false)), "the profile loads"
	)
	await e.start_from_menu()
	assert_true(main.is_playing(), "Play starts a new run")
	var t0 := e.world().tick
	await e.frames(10)
	assert_gt(e.world().tick, t0, "and it plays")
	main.saves.store.flush()
	assert_true(FileAccess.file_exists(path), "the new run saves where Continue reads")
	assert_eq(_kept().size(), 1, "beside the kept file")


func test_the_notice_is_in_spanish_and_said_once() -> void:
	var path := _old_save_on_disk()
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "es"
	var e := E2e.new(self)
	var main: Main = await e.boot(profile, RunSaveStore.new(path))
	var notice := _notice(main)
	assert_not_null(notice)
	if notice != null:
		assert_eq(
			notice.tr(notice.text),
			"Tu partida guardada es de una versión anterior y no se puede reanudar.",
			"in Spanish"
		)
	main.queue_free()
	await e.frames(2)
	var again: Main = await e.boot(profile, RunSaveStore.new(path))
	assert_not_null(_menu(again), "the main menu again")
	assert_null(_notice(again), "the next boot says nothing: the save was set aside")
	assert_eq(_kept().size(), 1, "still kept")
