extends SceneTree
## v0.9.0 CF (owner: "lets never make it a 1x1 … the enemies that spawn at the same time should be proportional to the
## room size"): the closed fights' rooms over N run seeds, floors 1-5 of each run built in order as Main builds them
## (SaveLab.build_floor, the run's purple-rune history carried, as scripts/balance/room_pacing.gd).
## - Per kind (the arenas, the Overrun room, the Lockdowns, the Elite Lockdowns, the Chaos shrine): the floors holding
##   one, and the floors holding one in a 1 x 1-cell room.
## - Per room footprint seen in a closed fight: its rooms' mean floor area (m2), and per kind the at-once cap there
##   (ClosedFights.cap at that mean area, the kind's data) next to today's at-once count on floor 5 (the whole wave).
## `rules=15` builds every floor under the floor rules before CF (the rooms a floor saved then rebuilds with:
## ClosedFights.legacy_rooms): the before; the default is today's. Prints the tables and writes
## build/balance/closed_fights_rules_<rules>.txt; copy the printed output into evidence by hand.
##   godot --headless --path . -s scripts/balance/closed_fights.gd -- seeds=1000 [rules=15]

const Lab := preload("res://tests/support/save_lab.gd")
const FLOORS := 5
const KINDS: Array[StringName] = [&"arena", &"overrun", &"lockdown", &"elite_lockdown", &"chaos"]


func _initialize() -> void:
	var seeds := 1000
	var rules := RunState.FLOOR_RULES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.trim_prefix("seeds="))
		if a.begins_with("rules="):
			rules = int(a.trim_prefix("rules="))
	var repo := ContentRepository.load_all()
	NavField.skip_build = true  # no placement reads the flow field (test_special_room_rules)
	var with := {}
	var tiny := {}
	for k in KINDS:
		with[k] = 0
		tiny[k] = 0
	var areas := {}  # footprint -> [sum of m2, rooms]
	var floors := 0
	for s in range(1, seeds + 1):
		var purple := PackedInt32Array()
		for floor_index in range(1, FLOORS + 1):
			var run := Lab.run_state(s, floor_index, &"blade", 0, repo)
			run.purple_floors = purple.duplicate()
			run.floor_rules = rules
			var w := Lab.build_floor(run, &"", repo)
			if w.purple != null and not purple.has(run.run_floor()):
				purple.append(run.run_floor())
			floors += 1
			var rooms := _rooms(w)
			for k: StringName in KINDS:
				var list: PackedInt32Array = rooms[k]
				if list.is_empty():
					continue
				with[k] += 1
				var small := false
				for r in list:
					small = small or w.floor_layout.room_cell_count(r) <= 1
					var key := w.floor_layout.room_cells[r].size
					var acc: Array = areas.get(key, [0.0, 0])
					acc[0] += _area(w.floor_layout, r)
					acc[1] += 1
					areas[key] = acc
				if small:
					tiny[k] += 1
	var lines := PackedStringArray()
	lines.append(
		(
			"CLOSED_FIGHTS| seeds=%d floors=1-%d (%d floors) floor_rules=%d"
			% [seeds, FLOORS, floors, rules]
		)
	)
	lines.append("")
	lines.append("| kind | floors with one | floors with one in a 1 x 1 room |")
	lines.append("|---|---|---|")
	for k: StringName in KINDS:
		lines.append("| %s | %d | %d |" % [k, with[k], tiny[k]])
	lines.append("")
	_caps(lines, repo, areas)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/balance"))
	var out := FileAccess.open(
		"res://build/balance/closed_fights_rules_%d.txt" % rules, FileAccess.WRITE
	)
	out.store_string(text + "\n")
	out.close()
	quit(0)


## Kind -> the floor's rooms of that kind.
func _rooms(w: World) -> Dictionary:
	var f := w.floor_layout
	var over := PackedInt32Array()
	if f.overrun_room >= 0:
		over.append(f.overrun_room)
	var lock := PackedInt32Array()
	var elite := PackedInt32Array()
	for i in f.lockdown_rooms.size():
		var kind := f.lockdown_kinds[i] if i < f.lockdown_kinds.size() else 0
		if kind == LockdownTable.Kind.ELITE:
			elite.append(f.lockdown_rooms[i])
		else:
			lock.append(f.lockdown_rooms[i])
	var chaos := PackedInt32Array()
	if w.shrine != null and w.shrine.kind == ShrineTable.Kind.CHAOS:
		chaos.append(f.room_of(w.shrine.pos))
	return {
		&"arena": f.arena_rooms.duplicate(),
		&"overrun": over,
		&"lockdown": lock,
		&"elite_lockdown": elite,
		&"chaos": chaos,
	}


func _area(f: FloorLayout, room: int) -> float:
	return f.rooms[room].size.x * f.rooms[room].size.y


## Per footprint seen: the mean area and, per kind, the cap at it against today's at-once count on floor 5.
func _caps(lines: PackedStringArray, repo: ContentRepository, areas: Dictionary) -> void:
	var arena := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	var over := ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	var lock := RunContentCompiler.compile_lockdown(repo.get_def(&"lockdown", &"lockdown"))
	var shr := RunContentCompiler.compile_shrines(repo.get_def(&"shrines", &"shrines"))
	var rules := EliteCompiler.compile_rules(repo.get_def(&"elite_rules", &"rules"))
	var elite_w := rules.elite_weight
	# today's whole wave at once on floor 5, in weight (an elite counts elite_weight)
	var today := {
		&"arena": ArenaTable.size_on(arena.wave_sizes, 5),
		&"overrun": ArenaTable.size_on(over.wave_sizes, 5),
		&"lockdown": lock.size_on(5),
		&"elite_lockdown": elite_w + rules.lockdown_escort,
		&"chaos": shr.chaos_size(5) + elite_w,
	}
	var per := {
		&"arena": arena.area_per_enemy_m2,
		&"overrun": over.area_per_enemy_m2,
		&"lockdown": lock.area_per_enemy_m2,
		&"elite_lockdown": lock.area_per_enemy_m2,
		&"chaos": shr.chaos_area_per_enemy_m2,
	}
	var keys := areas.keys()
	keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.x * a.y < b.x * b.y or (a.x * a.y == b.x * b.y and a.x < b.x)
	)
	lines.append(
		"At once on floor 5 (weight; an elite counts %d): cap / today's whole wave" % elite_w
	)
	var head := "| cells | rooms | mean m2 |"
	var rule := "|---|---|---|"
	for k: StringName in KINDS:
		head += " %s |" % k
		rule += "---|"
	lines.append(head)
	lines.append(rule)
	for key: Vector2i in keys:
		var acc: Array = areas[key]
		var mean: float = acc[0] / maxf(1.0, float(acc[1]))
		var row := "| %dx%d | %d | %.0f |" % [key.x, key.y, acc[1], mean]
		for k: StringName in KINDS:
			var cap := ClosedFights.cap_for(mean, per[k])
			row += " %d / %d |" % [mini(cap, today[k]), today[k]]
		lines.append(row)
