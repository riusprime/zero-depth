class_name UserDirMigration
extends RefCounted
## v0.9.5 TT: the game was named (Zero Depth), and Godot keeps `user://` in a folder named after
## `config/name`. Before the name, that folder was `{{TITLE}}`. On the first launch under the new
## name this COPIES the old folder's files (profile, run save, settings, ...) into the new one, so no
## save is lost. It never moves or deletes anything in the old folder. A marker file stops it from
## running twice. Any failure is reported on the console and the game still starts.

const OLD_FOLDER := "{{TITLE}}"
const MARKER := "migrated_from_title_token"
const KEY_FILES: Array[String] = ["profile.json", "saves/run.save"]


## The one call from main: uses the real user folder.
static func run_for_user_dir() -> int:
	var new_dir := OS.get_user_data_dir()
	return migrate(new_dir.get_base_dir().path_join(OLD_FOLDER), new_dir)


## Copies `old_dir` into `new_dir` once. Returns OK when it copied or had nothing to do, else an error code.
static func migrate(old_dir: String, new_dir: String) -> int:
	if FileAccess.file_exists(new_dir.path_join(MARKER)):
		return OK
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir):
		return OK
	if _has_key_file(new_dir) or not _has_key_file(old_dir):
		return OK
	var err := _copy_dir(old_dir, new_dir)
	if err != OK:
		push_error(
			(
				"UserDirMigration: copy from '%s' failed (%s); the old folder is untouched."
				% [old_dir, error_string(err)]
			)
		)
		return err
	var marker := FileAccess.open(new_dir.path_join(MARKER), FileAccess.WRITE)
	if marker == null:
		push_error(
			(
				"UserDirMigration: cannot write the marker (%s)."
				% error_string(FileAccess.get_open_error())
			)
		)
		return FileAccess.get_open_error()
	marker.store_string(old_dir)
	marker.close()
	print("UserDirMigration: copied the saves from '%s' to '%s'." % [old_dir, new_dir])
	return OK


static func _has_key_file(dir: String) -> bool:
	for f in KEY_FILES:
		if FileAccess.file_exists(dir.path_join(f)):
			return true
	return false


static func _copy_dir(from: String, to: String) -> int:
	var err := DirAccess.make_dir_recursive_absolute(to)
	if err != OK:
		return err
	for f in DirAccess.get_files_at(from):
		err = DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
		if err != OK:
			return err
	for d in DirAccess.get_directories_at(from):
		err = _copy_dir(from.path_join(d), to.path_join(d))
		if err != OK:
			return err
	return OK
