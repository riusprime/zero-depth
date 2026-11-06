class_name RunicStone
extends RefCounted
## v0.9.5 RS1 (RUNIC_STONE.md): the hub's Runic Stone, application side. The profile's `runes` section holds the ids of
## the lines it has learned ({"learned": ["r1", ...]}, in the order learned; created on the first write, so an old
## profile without it loads and saves as it was). The stone is awake once it knows r1. Never part of a run, a save or
## a sim hash. Adding an easter egg later is data (RunicLinesDefinition) plus one trigger here.
## - r1 (S3): a purple-rune room was activated in a run (the achievement stat PURPLE_STAT, AchievementTracker).
## - r2: the Codex counts DEATHS (times an enemy or a boss killed the hero).
## - r3: the woken stone pressed PRESSES times in a row, each within WINDOW_TICKS of the last, without walking away.
## - v0.9.5 RS2, r4-r10 (each learned once, also on load when the stored stats already meet it): r4 a floor boss beaten
##   without a hit (stat NO_HIT_STAT); r5 60 s still in the hub (HubRunic); r6 COLLECTIBLES of the 16 found (the
##   profile's `collectibles` section); r7 the Hollow Crown beaten (stat `final:won`); r8 three Ascension loops in one
##   run (the Codex's best loop reaches LOOP_BEST); r9 a cracked wall broken on CRACK_RUNS different runs (stat
##   CRACK_STAT); r10 the language switched in the hub with the stone awake (HubRunic).
## - S6: with every line learned the runes ring the stone and the Runic robe unlocks (Wardrobe.unlock_robe).

const SECTION := "runes"
const PURPLE_STAT := &"runes:purple"
## v0.9.5 RS2: the stats and counters the other lines read (see the header).
const NO_HIT_STAT := &"bosses:no_hit"
const CRACK_STAT := &"secrets:crack_runs"
const WON_STAT := &"final:won"
const ROBE := &"runic"
const COLLECTIBLES := 8
const LOOP_BEST := 4
const CRACK_RUNS := 5
const IDLE_TICKS := 3600  # R5: 60 s of hub ticks
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
	ensure_robe()
	return true


## S6: every line the content lists is learned.
func is_full() -> bool:
	if lines == null or lines.lines.is_empty():
		return false
	for l: RunicLineEntry in lines.lines:
		if not knows(l.id):
			return false
	return true


## S6: the Runic robe is in the profile's unlocks once the stone is full; true when it unlocked now.
func ensure_robe() -> bool:
	if not is_full():
		return false
	var u: Variant = profile.section("unlocks").get("robes", [])
	if u is Array and (u as Array).has(String(ROBE)):
		return false
	Wardrobe.unlock_robe(profile, ROBE)
	return true


## Awake once r1 is known.
func is_awake() -> bool:
	return knows(&"r1")


## The lines the profile has earned by now: `purple` = the times a purple-rune room was activated, `deaths` = the
## hero's deaths (the Codex), `more` = the RS2 facts (boss_no_hit, collectibles, won, loop_best, crack_runs).
## Returns the ids learned now (the caller saves the profile when any).
func sync(purple: int, deaths: int, more: Dictionary = {}) -> Array[StringName]:
	var got: Array[StringName] = []
	var rules: Array = [
		[&"r1", purple >= 1],
		[&"r2", deaths >= DEATHS],
		[&"r4", int(more.get("boss_no_hit", 0)) >= 1],
		[&"r6", int(more.get("collectibles", 0)) >= COLLECTIBLES],
		[&"r7", int(more.get("won", 0)) >= 1],
		[&"r8", int(more.get("loop_best", 0)) >= LOOP_BEST],
		[&"r9", int(more.get("crack_runs", 0)) >= CRACK_RUNS],
	]
	for r: Array in rules:
		if r[1] and learn(r[0]):
			got.append(r[0])
	if got.is_empty() and ensure_robe():  # an older profile already full: the caller saves the robe
		got.append(ROBE)
	return got


## The same from the stores: the achievement store's stats, the Codex's counters and the profile's collectibles.
func sync_from(achievements: AchievementStore, codex: CodexStore) -> Array[StringName]:
	var purple := achievements.stat(PURPLE_STAT) if achievements != null else 0
	var deaths := 0
	var found: Variant = profile.data.get(CollectibleBook.SECTION)  # read only: nothing is created
	var more := {"collectibles": (found as Dictionary).size() if found is Dictionary else 0}
	if codex != null:
		deaths = codex.total(&"enemies", &"deaths") + codex.total(&"bosses", &"deaths")
		more["loop_best"] = codex.count(&"runs", &"loop", &"best")
	if achievements != null:
		more["boss_no_hit"] = achievements.stat(NO_HIT_STAT)
		more["won"] = achievements.stat(WON_STAT)
		more["crack_runs"] = achievements.stat(CRACK_STAT)
	return sync(purple, deaths, more)


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
