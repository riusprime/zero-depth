extends GutTest
## v0.9.5 TT: the pre-name save folder is copied once into the new one; the old folder is never changed.

var _root := ""


func before_each() -> void:
	_root = OS.get_user_data_dir().path_join("_migration_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	_rm(_root)


func _rm(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	DirAccess.remove_absolute(dir)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _old_with_profile() -> String:
	var old := _root.path_join("old")
	_write(old.path_join("profile.json"), "P")
	_write(old.path_join("saves/run.save"), "S")
	_write(old.path_join("audio_override/x.wav"), "W")
	return old


func test_copies_files_and_subfolders_and_writes_marker() -> void:
	var old := _old_with_profile()
	var new := _root.path_join("new")
	assert_eq(UserDirMigration.migrate(old, new), OK)
	assert_eq(_read(new.path_join("profile.json")), "P")
	assert_eq(_read(new.path_join("saves/run.save")), "S")
	assert_eq(_read(new.path_join("audio_override/x.wav")), "W")
	assert_true(FileAccess.file_exists(new.path_join(UserDirMigration.MARKER)))
	assert_eq(_read(old.path_join("profile.json")), "P", "old folder untouched")
	assert_true(FileAccess.file_exists(old.path_join("saves/run.save")))
	assert_false(FileAccess.file_exists(old.path_join(UserDirMigration.MARKER)))


func test_second_run_does_not_copy_again() -> void:
	var old := _old_with_profile()
	var new := _root.path_join("new")
	UserDirMigration.migrate(old, new)
	_write(new.path_join("profile.json"), "NEWER")
	DirAccess.remove_absolute(new.path_join("saves/run.save"))
	_write(old.path_join("profile.json"), "CHANGED")
	assert_eq(UserDirMigration.migrate(old, new), OK)
	assert_eq(_read(new.path_join("profile.json")), "NEWER")
	assert_false(FileAccess.file_exists(new.path_join("saves/run.save")))


func test_existing_new_profile_is_never_overwritten() -> void:
	var old := _old_with_profile()
	var new := _root.path_join("new")
	_write(new.path_join("profile.json"), "MINE")
	UserDirMigration.migrate(old, new)
	assert_eq(_read(new.path_join("profile.json")), "MINE")
	assert_false(FileAccess.file_exists(new.path_join(UserDirMigration.MARKER)))


func test_empty_or_missing_old_folder_does_nothing() -> void:
	var new := _root.path_join("new")
	var old := _root.path_join("old")
	assert_eq(UserDirMigration.migrate(old, new), OK, "missing old")
	DirAccess.make_dir_recursive_absolute(old)
	assert_eq(UserDirMigration.migrate(old, new), OK, "empty old")
	assert_false(FileAccess.file_exists(new.path_join(UserDirMigration.MARKER)))
	assert_false(DirAccess.dir_exists_absolute(new))


func test_failure_leaves_old_intact_and_no_marker() -> void:
	var old := _old_with_profile()
	# A file where the new folder's subfolder must go: the copy of 'saves' cannot be made.
	var new := _root.path_join("new")
	_write(new.path_join("saves"), "BLOCK")
	assert_ne(UserDirMigration.migrate(old, new), OK)
	assert_push_error("UserDirMigration: copy from")
	assert_engine_error("Failed to open")
	assert_false(FileAccess.file_exists(new.path_join(UserDirMigration.MARKER)))
	assert_eq(_read(old.path_join("profile.json")), "P")
	assert_eq(_read(old.path_join("saves/run.save")), "S")
