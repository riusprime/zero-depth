# Ported from riusprime/deathventory@1d697803:src/application/profile_store.gd.
# Changes: Deathventory's sections replaced (settings, bindings, unlocks, hints); JournalStore and its legacy
# migration cut; quarantine keeps every bad file (timestamped) instead of overwriting profile.bad.json.
class_name ProfileStore
extends RefCounted
## The player profile: settings, key bindings, unlocks and seen hints in one `user://profile.json`. Never part of
## a run's state or any sim hash. Headless runs (tests, sims, CI) keep it in memory only. Saves are atomic
## (write a .tmp, then rename). A corrupt file is kept as profile.bad.<time>.json and a fresh profile starts.

const PLAYER_PATH := "user://profile.json"
const PROFILE_VERSION := 1

static var _shared: ProfileStore = null

var path := ""
var data := {}
var _unsaved := false


func _init(p_path: String = "") -> void:
	path = p_path
	data = fresh()


## The player's profile path, or "" (memory only) in a headless run.
static func player_path() -> String:
	return "" if DisplayServer.get_name() == "headless" else PLAYER_PATH


## The process-wide profile, loaded on first use.
static func shared() -> ProfileStore:
	if _shared == null:
		_shared = open(player_path())
	return _shared


## Replace the shared profile (tests, main).
static func use_shared(store: ProfileStore) -> void:
	_shared = store


static func open(p_path: String) -> ProfileStore:
	var store := ProfileStore.new(p_path)
	store.load_file()
	return store


static func fresh() -> Dictionary:
	return {
		"profile_version": PROFILE_VERSION,
		"game_version": GameVersion.string(),
		"settings": {},
		"bindings": {},
		"unlocks": {},
		"hints": {"seen": []},
	}


func section(name: String) -> Dictionary:
	if not data.has(name) or typeof(data[name]) != TYPE_DICTIONARY:
		data[name] = (fresh().get(name, {}) as Dictionary).duplicate(true)
	return data[name]


## Loads `path`; returns true when a profile file was read.
func load_file() -> bool:
	data = fresh()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if (
		json.parse(FileAccess.get_file_as_string(path)) == OK
		and typeof(json.data) == TYPE_DICTIONARY
	):
		_merge_loaded(json.data)
		return true
	_quarantine()
	return false


func _merge_loaded(loaded: Dictionary) -> void:
	for key: Variant in loaded.keys():
		var base: Variant = data.get(key)
		if typeof(base) == TYPE_DICTIONARY and typeof(loaded[key]) == TYPE_DICTIONARY:
			var merged: Dictionary = (base as Dictionary).duplicate(true)
			merged.merge(loaded[key], true)
			data[key] = merged
		elif base == null or typeof(base) == typeof(loaded[key]):
			data[key] = loaded[key]
	data["profile_version"] = PROFILE_VERSION


func _quarantine() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var bad := path.get_base_dir().path_join("profile.bad.%s.json" % stamp)
	DirAccess.rename_absolute(path, bad)
	push_warning("ProfileStore: %s was unreadable; kept as %s and started fresh." % [path, bad])


func has_unsaved() -> bool:
	return _unsaved


## Writes the profile atomically. Memory-only profiles return false.
func save_file() -> bool:
	if path.is_empty():
		return false
	data["game_version"] = GameVersion.string()
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		_unsaved = true
		push_warning(
			(
				"ProfileStore: could not write %s (%s)."
				% [tmp, error_string(FileAccess.get_open_error())]
			)
		)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		_unsaved = true
		return false
	_unsaved = false
	return true
