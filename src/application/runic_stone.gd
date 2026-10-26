class_name RunicStone
extends RefCounted
## v0.9.5 RS1 (RUNIC_STONE.md): the hub's Runic Stone, application side. The profile's `runes` section holds the ids of
## the lines it has learned ({"learned": ["r1", ...]}, in the order learned; created on the first write, so an old
## profile without it loads and saves as it was). The stone is awake once it knows r1. Never part of a run, a save or
## a sim hash. Adding an easter egg later is data (RunicLinesDefinition) plus one trigger here.
## - r1 (S3): a purple-rune room was activated in a run (the achievement stat PURPLE_STAT, AchievementTracker).
## - r2: the Codex counts DEATHS (times an enemy or a boss killed the hero).
## - r3: the woken stone pressed PRESSES times in a row, each within WINDOW_TICKS of the last, without walking away.

const SECTION := "runes"
const PURPLE_STAT := &"runes:purple"
const DEATHS := 10
const PRESSES := 7
const WINDOW_TICKS := 180

var profile: ProfileStore
var lines: RunicLinesDefinition
## A line was learned and the hub hasn't shown the pulse yet (HubRunic clears it).
var pending_pulse := false
var _streak := 0
var _last_press := -1
var _cursor := -1


func _init(p_profile: ProfileStore, p_lines: RunicLinesDefinition) -> void:
	profile = p_profile
	lines = p_lines


## The learned line ids, in the order learned.
func learned() -> Array[StringName]:
	var out: Array[StringName] = []
	var sec: Variant = profile.data.get(SECTION)
	if typeof(sec) != TYPE_DICTIONARY:
		return out
	var l: Variant = (sec as Dictionary).get("learned")
	if typeof(l) != TYPE_ARRAY:
		return out
	for v: Variant in l:
		out.append(StringName(str(v)))
	return out


func knows(id: StringName) -> bool:
	return learned().has(id)


## The learned ids, the newest first (the stone speaks its newest line first).
func newest_first() -> Array[StringName]:
	var out := learned()
	out.reverse()
	return out


## Learns line `id` (a line the content lists); true when it was new. Sets the pulse.
func learn(id: StringName) -> bool:
	if lines != null and lines.line(id) == null:
		return false
	if knows(id):
		return false
	var sec := profile.section(SECTION)
	if typeof(sec.get("learned")) != TYPE_ARRAY:
		sec["learned"] = []
	(sec["learned"] as Array).append(String(id))
	pending_pulse = true
	_cursor = -1
	return true


## Awake once r1 is known.
func is_awake() -> bool:
	return knows(&"r1")


## The lines the profile has earned by now: `purple` = the times a purple-rune room was activated, `deaths` = the
## hero's deaths (the Codex). Returns the ids learned now (the caller saves the profile when any).
func sync(purple: int, deaths: int) -> Array[StringName]:
	var got: Array[StringName] = []
	if purple >= 1 and learn(&"r1"):
		got.append(&"r1")
	if deaths >= DEATHS and learn(&"r2"):
		got.append(&"r2")
	return got


## The same from the stores: the achievement store's purple stat and the Codex's deaths (an enemy's or a boss's).
func sync_from(achievements: AchievementStore, codex: CodexStore) -> Array[StringName]:
	var purple := achievements.stat(PURPLE_STAT) if achievements != null else 0
	var deaths := 0
	if codex != null:
		deaths = codex.total(&"enemies", &"deaths") + codex.total(&"bosses", &"deaths")
	return sync(purple, deaths)


## One press of the woken stone at hub tick `tick`; true when it learned r3 (the seventh in a row).
func press(tick: int) -> bool:
	if _last_press >= 0 and tick - _last_press > WINDOW_TICKS:
		_streak = 0
	_last_press = tick
	_streak += 1
	if _streak >= PRESSES and learn(&"r3"):
		_streak = 0
		return true
	return false


## The hero walked away: the streak and the reading start over.
func walked_away() -> void:
	_streak = 0
	_last_press = -1
	_cursor = -1


## The next line to show (the newest first, then the older, round again); &"" when it knows none.
func read_next() -> StringName:
	var ids := newest_first()
	if ids.is_empty():
		return &""
	_cursor = (_cursor + 1) % ids.size()
	return ids[_cursor]


## The plain English of line `id` ("" unknown) for the cipher.
func english(id: StringName) -> String:
	var l := lines.line(id) if lines != null else null
	return l.english if l != null else ""
