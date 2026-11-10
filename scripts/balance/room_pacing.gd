extends SceneTree
## v0.9.0 RG (PLAN W2 "alternate between intense combat, exploration, discovery, and smaller environmental challenges",
## W72 §12 pacing bands, W74 "not every floor needs every interaction"): the special rooms' pacing over N run seeds,
## floors 1-5 of each run built in order as Main builds them (SaveLab.build_floor: FloorScenario, the shop, the events,
## FloorPlan.add_secrets), the run's purple-rune history carried from floor to floor (one a loop: finish_floor).
## For each floor and each special room kind (RoomCensus.KINDS, data/special_rooms): mean, min and max a floor and the
## share of floors with none; the share of rooms that are special, by W72's bands; and the spacing along the critical
## path (the shortest doorway path from the start hall to the boss room): each special room is counted at the path
## room nearest it (doorway hops, the earlier on a tie); "gap" is the path rooms between two such points in a row,
## "dry" the longest run of path rooms with none.
## Prints the tables and writes build/balance/room_pacing.txt; copy the printed output into evidence by hand.
##   godot --headless --path . -s scripts/balance/room_pacing.gd -- seeds=1000

const Census := preload("res://tests/support/room_census.gd")
const Lab := preload("res://tests/support/save_lab.gd")
const FLOORS := 5
## W72's bands: the special combat rooms, the optional puzzles and secrets; the rest are services and events.
const COMBAT: Array[StringName] = [&"arena", &"overrun", &"lockdown"]
const PUZZLE: Array[StringName] = [&"timed_door", &"rune_puzzle", &"cracked_wall", &"purple_runes"]
## The rows after the kinds: the three secrets (timed door, rune puzzle, cracked wall) together.
const SECRETS: Array[StringName] = [&"timed_door", &"rune_puzzle", &"cracked_wall"]
const ROWS: Array[StringName] = [&"any_secret"]


func _initialize() -> void:
	var seeds := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.trim_prefix("seeds="))
	var t0 := Time.get_ticks_msec()
	var repo := ContentRepository.load_all()
	NavField.skip_build = true  # no placement reads the flow field (test_special_room_rules)
	# per floor: kind -> the counts a floor; the rooms, special rooms and bands; the path's lengths, gaps and dry runs
	var stats := []
	for fi in FLOORS:
		var counts := {}
		for k in Census.KINDS:
			counts[k] = []
		counts[&"any_secret"] = []
		(
			stats
			. append(
				{
					"counts": counts,
					"rooms": 0,
					"special": 0,
					"combat": 0,
					"puzzle": 0,
					"other": 0,
					"gaps": [],
					"dry": [],
					"path": [],
				}
			)
		)
	for s in range(1, seeds + 1):
		var purple := PackedInt32Array()
		for floor_index in range(1, FLOORS + 1):
			var run := Lab.run_state(s, floor_index, &"blade", 0, repo)
			run.purple_floors = purple.duplicate()
			var w := Lab.build_floor(run, &"", repo)
			if w.purple != null and not purple.has(run.run_floor()):
				purple.append(run.run_floor())
			_count(stats[floor_index - 1], w)
	var lines := PackedStringArray()
	lines.append(
		(
			"ROOM_PACING| seeds=%d floors=1-%d (each run's floors in order, as Main builds them)"
			% [seeds, FLOORS]
		)
	)
	lines.append("")
	lines.append("Per floor, rooms of each kind a floor: mean (min-max), % of floors with none")
	var head := "| kind |"
	var rule := "|---|"
	for fi in FLOORS:
		head += " floor %d |" % (fi + 1)
		rule += "---|"
	lines.append(head)
	lines.append(rule)
	for k in Census.KINDS + ROWS:
		var row := "| %s |" % k
		for fi in FLOORS:
			var c: Array = stats[fi]["counts"][k]
			row += " %s |" % _cell(c)
		lines.append(row)
	lines.append("")
	lines.append(
		"Share of rooms (all rooms, start hall and boss room included), pooled over the floors"
	)
	(
		lines
		. append(
			"| floor | rooms a floor | special | special combat | puzzles and secrets | services and events |"
		)
	)
	lines.append("|---|---|---|---|---|---|")
	for fi in FLOORS:
		var st: Dictionary = stats[fi]
		var n: int = st["rooms"]
		(
			lines
			. append(
				(
					"| %d | %s | %s | %s | %s | %s |"
					% [
						fi + 1,
						_dec(n * 100 / seeds),
						_pct(st["special"], n),
						_pct(st["combat"], n),
						_pct(st["puzzle"], n),
						_pct(st["other"], n),
					]
				)
			)
		)
	lines.append("")
	lines.append("Along the critical path (start hall to boss room)")
	(
		lines
		. append(
			"| floor | path rooms: mean (min-max) | gap between special rooms: mean (max) | longest dry stretch: mean (max) |"
		)
	)
	lines.append("|---|---|---|---|")
	for fi in FLOORS:
		var st: Dictionary = stats[fi]
		(
			lines
			. append(
				(
					"| %d | %s | %s | %s |"
					% [
						fi + 1,
						_cell(st["path"], false),
						_mean_max(st["gaps"]),
						_mean_max(st["dry"]),
					]
				)
			)
		)
	lines.append("")
	lines.append(
		(
			"ROOM_PACING| done floors=%d wall_s=%d"
			% [seeds * FLOORS, (Time.get_ticks_msec() - t0) / 1000]
		)
	)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/balance"))
	var out := FileAccess.open("res://build/balance/room_pacing.txt", FileAccess.WRITE)
	if out != null:
		out.store_string(text + "\n")
	quit(0)


func _count(st: Dictionary, w: World) -> void:
	var f := w.floor_layout
	var census: Dictionary = Census.of(w)
	var secrets := 0
	for k in Census.KINDS:
		(st["counts"][k] as Array).append((census[k] as PackedInt32Array).size())
		if k in SECRETS:
			secrets += (census[k] as PackedInt32Array).size()
	(st["counts"][&"any_secret"] as Array).append(secrets)
	st["rooms"] += f.room_count()
	var special := Census.special_rooms(census)
	st["special"] += special.size()
	for r in special:
		if _in(census, COMBAT, r):
			st["combat"] += 1
		elif _in(census, PUZZLE, r):
			st["puzzle"] += 1
		else:
			st["other"] += 1
	var path := Census.critical_path(f)
	(st["path"] as Array).append(path.size())
	if path.is_empty():
		return
	var hits := PackedByteArray()
	hits.resize(path.size())
	for r in special:
		var d := Census.hops_from(f, r, PackedInt32Array())
		var best := 0
		for k in path.size():
			if d[path[k]] >= 0 and d[path[k]] < d[path[best]]:
				best = k
		hits[best] = 1
	var last := -1
	var dry := 0
	var run := 0
	for k in path.size():
		if hits[k] == 1:
			if last >= 0:
				(st["gaps"] as Array).append(k - last - 1)
			last = k
			run = 0
		else:
			run += 1
			dry = maxi(dry, run)
	(st["dry"] as Array).append(dry)


func _in(census: Dictionary, kinds: Array[StringName], r: int) -> bool:
	for k in kinds:
		if (census[k] as PackedInt32Array).has(r):
			return true
	return false


## "mean (min-max), none %" (with_none false: "mean (min-max)").
func _cell(c: Array, with_none: bool = true) -> String:
	if c.is_empty():
		return "—"
	var sum := 0
	var lo: int = c[0]
	var hi: int = c[0]
	var none := 0
	for v: int in c:
		sum += v
		lo = mini(lo, v)
		hi = maxi(hi, v)
		if v == 0:
			none += 1
	var s := "%s (%d-%d)" % [_dec(sum * 100 / c.size()), lo, hi]
	if with_none:
		s += ", %s none" % _pct(none, c.size())
	return s


func _mean_max(c: Array) -> String:
	if c.is_empty():
		return "—"
	var sum := 0
	var hi := 0
	for v: int in c:
		sum += v
		hi = maxi(hi, v)
	return "%s (%d)" % [_dec(sum * 100 / c.size()), hi]


## A value in hundredths as "1.23".
func _dec(hundredths: int) -> String:
	return "%d.%02d" % [hundredths / 100, hundredths % 100]


func _pct(part: int, whole: int) -> String:
	if whole <= 0:
		return "—"
	var tenths := (part * 1000 + whole / 2) / whole
	return "%d.%d %%" % [tenths / 10, tenths % 10]
