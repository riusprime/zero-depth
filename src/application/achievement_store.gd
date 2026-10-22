class_name AchievementStore
extends RefCounted
## v0.7.5 AC (owner N7): the profile's `achievements` section (ProfileStore): what unlocked, in which order, and the
## run counters the achievements read (AchievementDefinition.STATS). Outside the run and the sim: never part of
## RunState, a save or a hash. No platform API: the list lives in `user://profile.json` only.
##
## The section: {"version": VERSION, "unlocked": {id: n}, "stats": {key: value}}. `n` is the unlock's place in the
## order they came (1, 2, 3 ...), so the page can show the newest; stats only grow. A profile from before AC has no
## section and reads as an empty one; a section with a newer or broken shape is repaired to what can be read.

## An achievement unlocked (the tracker shows its toast).
signal unlocked(id: StringName)

const SECTION := "achievements"
const VERSION := 1

var profile: ProfileStore
## True while a write hasn't reached the profile file (Main saves the profile at the end of each floor).
var dirty := false


func _init(p_profile: ProfileStore) -> void:
	profile = p_profile


## An empty section (the profile's fresh one; an old profile without it reads as this).
static func fresh() -> Dictionary:
	return {"version": VERSION, "unlocked": {}, "stats": {}}


func _part(key: String) -> Dictionary:
	var sec := profile.section(SECTION)
	if not sec.has("version"):
		sec["version"] = VERSION
	if not sec.has(key) or typeof(sec[key]) != TYPE_DICTIONARY:
		sec[key] = {}
	return sec[key]


func version() -> int:
	return int(profile.section(SECTION).get("version", VERSION))


func is_unlocked(id: StringName) -> bool:
	return _part("unlocked").has(String(id))


## Unlocks `id`; true when it was new.
func unlock(id: StringName) -> bool:
	if id == &"" or is_unlocked(id):
		return false
	var u := _part("unlocked")
	u[String(id)] = u.size() + 1
	dirty = true
	unlocked.emit(id)
	return true


## The unlock's place in the order (1 = the first), 0 when locked.
func unlock_order(id: StringName) -> int:
	return int(_part("unlocked").get(String(id), 0))


func unlocked_ids() -> Array[StringName]:
	var keys := PackedStringArray()
	for k: Variant in _part("unlocked").keys():
		keys.append(str(k))
	keys.sort()
	var out: Array[StringName] = []
	for k in keys:
		out.append(StringName(k))
	return out


func unlocked_count() -> int:
	return _part("unlocked").size()


func stat(key: StringName) -> int:
	return int(_part("stats").get(String(key), 0))


## Adds `by` to a run counter; returns the new value.
func add_stat(key: StringName, by: int = 1) -> int:
	if key == &"" or by == 0:
		return stat(key)
	var s := _part("stats")
	var v := int(s.get(String(key), 0)) + by
	s[String(key)] = v
	dirty = true
	return v


## Raises a run counter to `value` when that is higher; returns the counter after.
func raise_stat(key: StringName, value: int) -> int:
	var was := stat(key)
	if key == &"" or value <= was:
		return was
	_part("stats")[String(key)] = value
	dirty = true
	return value
