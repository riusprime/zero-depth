class_name RunRecords
extends RefCounted
## v0.10.5 O5a (owner L2: "missing something to make the player want to go further"; docs/roadmap/v0.10.5/O5_LOOPS.md
## D1-D4, R1): the profile's run records and the loop-only robes, in the profile's `records` section (an older profile
## has none: no records). Kept outside the run and the sim (EI-07); Main and MetaHooks write it, the hub's
## Achievements page and the run recap read it. Nothing here is a stat (PD-06).
## The section: {"<weapon>": {"loop": n, "loop_seed": s, "win_ticks": t, "win_seed": s}} per weapon (the run's
## build id: gun, blade). A record keeps the run seed that set it, so the recap of that run (even after Continue)
## can say "new record".

const SECTION := "records"
## The weapons the hub lists, in order (a build id outside them is recorded but not listed).
const WEAPONS: Array[StringName] = [&"gun", &"blade"]
## R1: the robes a loop reached unlocks (RobeDefinition ids; earned, never sold: their unlock_hint_key).
const LOOP_ROBES := {3: &"ouroboros", 5: &"abyssal"}
## The achievements' stat the deepest loop raises (AchievementDefinition.STATS).
const LOOP_STAT := &"runs:loop_best"


static func _weapon(profile: ProfileStore, weapon: StringName) -> Dictionary:
	var sec := profile.section(SECTION)
	var key := String(weapon if weapon != &"" else &"gun")
	if typeof(sec.get(key)) != TYPE_DICTIONARY:
		sec[key] = {}
	return sec[key]


static func _field(profile: ProfileStore, weapon: StringName, field: String) -> int:
	var sec := profile.section(SECTION)
	var e: Variant = sec.get(String(weapon))
	return int((e as Dictionary).get(field, 0)) if typeof(e) == TYPE_DICTIONARY else 0


## The deepest loop reached with `weapon` (0: none past the first; &"": over every weapon).
static func best_loop(profile: ProfileStore, weapon: StringName = &"") -> int:
	if weapon != &"":
		return _field(profile, weapon, "loop")
	var best := 0
	for k: Variant in profile.section(SECTION).keys():
		best = maxi(best, _field(profile, StringName(str(k)), "loop"))
	return best


## The fastest true ending with `weapon`, in ticks (0: none).
static func best_win_ticks(profile: ProfileStore, weapon: StringName) -> int:
	return _field(profile, weapon, "win_ticks")


## The run (`run_seed`) reached loop `loop` with `weapon`: true when that is a new record.
static func note_loop(profile: ProfileStore, weapon: StringName, loop: int, run_seed: int) -> bool:
	var e := _weapon(profile, weapon)
	if loop <= 1 or loop <= int(e.get("loop", 0)):
		return false
	e["loop"] = loop
	e["loop_seed"] = run_seed
	return true


## The run (`run_seed`) beat the final boss with `weapon` in `ticks`: true when that is a new record.
static func note_win(profile: ProfileStore, weapon: StringName, ticks: int, run_seed: int) -> bool:
	var e := _weapon(profile, weapon)
	var was := int(e.get("win_ticks", 0))
	if ticks <= 0 or (was > 0 and ticks >= was):
		return false
	e["win_ticks"] = ticks
	e["win_seed"] = run_seed
	return true


## The run `run_seed` holds `weapon`'s deepest-loop record at `loop` (the recap's "new record" line).
static func holds_loop(profile: ProfileStore, weapon: StringName, loop: int, run_seed: int) -> bool:
	var sec := profile.section(SECTION)
	var e: Variant = sec.get(String(weapon))
	if typeof(e) != TYPE_DICTIONARY or loop <= 1:
		return false
	var d := e as Dictionary
	return int(d.get("loop", 0)) == loop and int(d.get("loop_seed", -1)) == run_seed


## R1: the loop robes loop `loop` has earned and the profile lacks; unlocks them and returns their ids.
static func unlock_loop_robes(profile: ProfileStore, loop: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for need: int in LOOP_ROBES:
		var id: StringName = LOOP_ROBES[need]
		if loop < need:
			continue
		var list: Variant = profile.section("unlocks").get("robes", [])
		if list is Array and (list as Array).has(String(id)):
			continue
		Wardrobe.unlock_robe(profile, id)
		out.append(id)
	return out


## "mm:ss" for `ticks` (60 Hz); "—" (UI_RECORD_NONE, through `ci`) for none.
static func time_text(ci: Object, ticks: int) -> String:
	if ticks <= 0:
		return ci.tr("UI_RECORD_NONE")
	var secs := ticks / SimTick.TICKS_PER_SECOND
	return "%02d:%02d" % [secs / 60, secs % 60]


## The hub's Records lines, translated through `ci`: the deepest loop and the fastest true ending per weapon.
static func lines(ci: Object, profile: ProfileStore) -> PackedStringArray:
	var loops := PackedStringArray()
	var times := PackedStringArray()
	for wp in WEAPONS:
		var name: String = ci.tr("BUILD_%s" % String(wp).to_upper())
		var l := best_loop(profile, wp)
		loops.append("%s %s" % [name, str(l) if l > 1 else ci.tr("UI_RECORD_NONE")])
		times.append("%s %s" % [name, time_text(ci, best_win_ticks(profile, wp))])
	return PackedStringArray(
		[
			ci.tr("UI_RECORD_LOOP") % " · ".join(loops),
			ci.tr("UI_RECORD_TIME") % " · ".join(times),
		]
	)
