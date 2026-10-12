class_name CodexStore
extends RefCounted
## v0.7.5 CX (owner N6): the Codex's counters, kept in the player profile's `codex` section (ProfileStore). Outside
## the run and outside the sim: never part of RunState, a save or any hash; the app layer records into it from what
## the sim reports (CodexRecorder reads WorldReader and SimEvents, EI-07), and the Codex page reads it.
## The model follows Deathventory's discovery journal (riusprime/deathventory, src/application/journal_store.gd: a
## profile-backed record that only changes what pages show); the code is new.
##
## The section: {"version": VERSION, "cards": {id: {counter: n}}, "enemies": {…}, "bosses": {…}, "biomes": {…}}.
## An entry exists once it is unlocked (met in play); its counters start at 0 and only grow.
## The counter API (docs/roadmap/v0.7.5/evidence/CODEX.md "Counter API"; AC's achievements read it):
## - unlock(page, id), is_unlocked(page, id), unlocked_ids(page), unlocked_count(page);
## - add(page, id, counter, by) (counts up and unlocks), raise_to(page, id, counter, value) (keeps the highest);
## - count(page, id, counter), total(page, counter) (summed over a page's entries);
## - the `unlocked` signal on an entry's first meeting, and `changed` after every counter write.

signal changed(page: StringName, id: StringName, counter: StringName, value: int)
## An entry was unlocked (met for the first time).
signal unlocked(page: StringName, id: StringName)

const SECTION := "codex"
const VERSION := 1
const PAGES: Array[StringName] = [&"cards", &"enemies", &"bosses", &"biomes"]
## Each page's counters (what the page shows and what achievements may read).
## cards: offered (a pick, the shop or an event showed it), taken, level (the highest it reached in a run);
## enemies: kills, deaths (times it killed you); bosses: fights (times you met it), kills, deaths;
## biomes: visits (floors entered).
const COUNTERS := {
	&"cards": [&"offered", &"taken", &"level"],
	&"enemies": [&"kills", &"deaths"],
	&"bosses": [&"fights", &"kills", &"deaths"],
	&"biomes": [&"visits"],
}

var profile: ProfileStore
## True while a write hasn't reached the profile file (Main saves the profile at the end of each floor).
var dirty := false


func _init(p_profile: ProfileStore) -> void:
	profile = p_profile


## An empty Codex (the profile's fresh section; an old profile without the section reads as this).
static func fresh() -> Dictionary:
	return {"version": VERSION, "cards": {}, "enemies": {}, "bosses": {}, "biomes": {}}


## The page's entries in the profile (repaired to a Dictionary when a hand-edited file broke it).
func _page(page: StringName) -> Dictionary:
	var sec := profile.section(SECTION)
	if not sec.has("version"):
		sec["version"] = VERSION
	var key := String(page)
	if not sec.has(key) or typeof(sec[key]) != TYPE_DICTIONARY:
		sec[key] = {}
	return sec[key]


func _entry(page: StringName, id: StringName, create: bool) -> Dictionary:
	var p := _page(page)
	var key := String(id)
	if p.has(key) and typeof(p[key]) == TYPE_DICTIONARY:
		return p[key]
	if not create:
		return {}
	var fresh_entry := not p.has(key)
	p[key] = {}
	dirty = true
	if fresh_entry:
		unlocked.emit(page, id)
	return p[key]


## The section's version as stored (VERSION for a fresh or current profile).
func version() -> int:
	return int(profile.section(SECTION).get("version", VERSION))


func is_unlocked(page: StringName, id: StringName) -> bool:
	return _page(page).has(String(id))


## Unlocks an entry; true when it was new.
func unlock(page: StringName, id: StringName) -> bool:
	if id == &"" or is_unlocked(page, id):
		return false
	_entry(page, id, true)
	return true


## Adds `by` to a counter (unlocking the entry); returns the new value.
func add(page: StringName, id: StringName, counter: StringName, by: int = 1) -> int:
	if id == &"":
		return 0
	var e := _entry(page, id, true)
	var v := int(e.get(String(counter), 0)) + by
	e[String(counter)] = v
	dirty = true
	changed.emit(page, id, counter, v)
	return v


## Raises a counter to `value` when that is higher (unlocking the entry); returns the counter after.
func raise_to(page: StringName, id: StringName, counter: StringName, value: int) -> int:
	if id == &"":
		return 0
	var e := _entry(page, id, true)
	var was := int(e.get(String(counter), 0))
	if value <= was:
		return was
	e[String(counter)] = value
	dirty = true
	changed.emit(page, id, counter, value)
	return value


func count(page: StringName, id: StringName, counter: StringName) -> int:
	return int(_entry(page, id, false).get(String(counter), 0))


## A counter summed over every entry of a page (e.g. total enemy kills).
func total(page: StringName, counter: StringName) -> int:
	var n := 0
	for e: Variant in _page(page).values():
		if typeof(e) == TYPE_DICTIONARY:
			n += int((e as Dictionary).get(String(counter), 0))
	return n


func unlocked_ids(page: StringName) -> Array[StringName]:
	var keys := PackedStringArray()
	for k: Variant in _page(page).keys():
		keys.append(str(k))
	keys.sort()
	var out: Array[StringName] = []
	for k in keys:
		out.append(StringName(k))
	return out


func unlocked_count(page: StringName) -> int:
	return _page(page).size()
