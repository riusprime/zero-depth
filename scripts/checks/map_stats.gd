extends SceneTree
## Floor generation numbers (v0.7.5 MG; owner N9-N12): over many seeds, the rooms per floor (and with the boss room),
## the room footprints, the floor's size, the build time of a floor's layout (generate, boss room, Overrun room,
## arenas, shop pick), the challenge rooms per floor (the Overrun room and the sealed arenas), the shops on a run's
## floors and the cursed chests on a run's floors (every chest's offer rolled, as when it is opened).
## Prints the report and writes build/map_stats.txt; paste it into evidence by hand.
##   godot --headless --path . -s scripts/checks/map_stats.gd -- seeds=1000 runs=200
## Works on builds before MG too (it uses the map data and the floor rules only when they exist).

var seeds := 1000
var runs := 200


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] == "seeds":
			seeds = int(kv[1])
		if kv.size() == 2 and kv[0] == "runs":
			runs = int(kv[1])
	var repo := ContentRepository.load_all()
	var lines := PackedStringArray()
	lines.append_array(_layouts(repo))
	lines.append_array(_shops(repo))
	lines.append_array(_curses(repo))
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/map_stats.txt", FileAccess.WRITE)
	for l in lines:
		print(l)
		if f != null:
			f.store_line(l)
	quit(0)


## The map data's FloorParams when the build has them (MG), else the generator's defaults.
static func _params(repo: ContentRepository) -> FloorParams:
	var def: Variant = repo.get_def(&"map", &"floor")
	if def != null and RunContentCompiler.new().has_method("compile_map"):
		return RunContentCompiler.new().call("compile_map", def)
	return FloorParams.defaults()


func _layouts(repo: ContentRepository) -> PackedStringArray:
	var p := _params(repo)
	var share := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena")).share_permille
	var rooms := {}
	var totals := {}
	var feet := {}
	var challenge := {}
	var arenas_sum := 0
	var overrun_sum := 0
	var no_shop := 0
	var times := PackedInt64Array()
	var side_max := 0.0
	var area_sum := 0.0
	var n := 0
	for k in seeds:
		var seed_value := 1000 + k * 7919
		var t0 := Time.get_ticks_usec()
		var f := FloorGenerator.generate(seed_value, p)
		BossRoomBuilder.attach(f, BossArenaSpec.new())
		OverrunRooms.mark(f)
		ArenaRooms.mark(f, share)
		var shop := ShopPlacement.pick(f)
		times.append(Time.get_ticks_usec() - t0)
		n += 1
		var nr := f.room_count() - (1 if f.boss_room >= 0 else 0)
		rooms[nr] = int(rooms.get(nr, 0)) + 1
		totals[f.room_count()] = int(totals.get(f.room_count(), 0)) + 1
		for r in range(1, f.room_count()):
			if r == f.boss_room:
				continue
			var key := "%dx%d" % [f.room_cells[r].size.x, f.room_cells[r].size.y]
			feet[key] = int(feet.get(key, 0)) + 1
		var c := f.arena_rooms.size() + (1 if f.overrun_room >= 0 else 0)
		challenge[c] = int(challenge.get(c, 0)) + 1
		arenas_sum += f.arena_rooms.size()
		overrun_sum += 1 if f.overrun_room >= 0 else 0
		no_shop += 1 if shop < 0 else 0
		side_max = maxf(side_max, maxf(f.bounds.size.x, f.bounds.size.y))
		area_sum += f.bounds.size.x * f.bounds.size.y
	var out := PackedStringArray()
	out.append(
		"MAP| floors=%d params rooms=%d..%d max_span=%d" % [n, p.rooms_min, p.rooms_max, p.max_span]
	)
	out.append("MAP| rooms (hall included, boss room not): %s" % _hist(rooms, n))
	out.append("MAP| rooms with the boss room: %s" % _hist(totals, n))
	out.append("MAP| footprints after the hall: %s" % _hist(feet, 0))
	out.append(
		(
			"MAP| floor box: mean area %.0f m2, largest side %.1f m"
			% [area_sum / maxf(1.0, n), side_max]
		)
	)
	times.sort()
	var sum := 0
	for t in times:
		sum += t
	(
		out
		. append(
			(
				"MAP| layout build (generate+boss+overrun+arenas+shop pick): mean %.2f ms, p50 %.2f ms, p99 %.2f ms, max %.2f ms"
				% [
					sum / 1000.0 / maxf(1.0, n),
					times[times.size() / 2] / 1000.0,
					times[mini(times.size() - 1, times.size() * 99 / 100)] / 1000.0,
					times[times.size() - 1] / 1000.0
				]
			)
		)
	)
	(
		out
		. append(
			(
				(
					"MAP| challenge rooms per floor (Overrun + arenas, arena share %d permille): mean %.3f"
					+ " (Overrun %.3f, arenas %.3f); %s"
				)
				% [
					share,
					(arenas_sum + overrun_sum) / maxf(1.0, n),
					overrun_sum / maxf(1.0, n),
					arenas_sum / maxf(1.0, n),
					_hist(challenge, n)
				]
			)
		)
	)
	out.append("MAP| floors where no room takes the shop: %d" % no_shop)
	return out


## Shops on floors 1..12 under the shop's floor rule (every floor before MG).
static func _shops(repo: ContentRepository) -> PackedStringArray:
	var t := ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal"))
	var on := PackedStringArray()
	var in_three := 0
	for floor_index in range(1, 13):
		var yes := true
		if t.has_method("on_floor"):
			yes = t.call("on_floor", floor_index)
		if yes:
			on.append(str(floor_index))
			if floor_index <= 3:
				in_three += 1
	return PackedStringArray(
		["SHOP| floors with a shop (1..12): %s; in a 3-floor run: %d" % [",".join(on), in_three]]
	)


## Every chest of every floor of `runs` runs opened (its offer rolled, Curses.on_offer_rolled), as the player
## opening each one would: cursed chests per floor and per run.
func _curses(repo: ContentRepository) -> PackedStringArray:
	var count := runs
	var run_def: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	var per_floor := {}
	var per_run := {}
	var chests := 0
	var cursed := 0
	var by_index := [0, 0, 0, 0]
	var two_in_a_row := 0
	for r in count:
		var run_seed := 5000 + r * 104729
		var in_run := 0
		var last := -10
		for floor_index in range(1, run_def.floors + 1):
			var w := _floor(repo, run_seed, floor_index)
			var on := 0
			for i in w.rewards.size():
				if w.rewards.kind[i] != RewardStore.Kind.CHEST:
					continue
				chests += 1
				w.rewards.set_offer(i, Offers.roll(w, i))
				Curses.on_offer_rolled(w, i)
				if w.ev.cursed_ids.has(w.rewards.ids[i]):
					on += 1
			cursed += on
			by_index[floor_index] += on
			per_floor[on] = int(per_floor.get(on, 0)) + 1
			if on > 0:
				if floor_index - last < 2:
					two_in_a_row += 1
				last = floor_index
			in_run += on
		per_run[in_run] = int(per_run.get(in_run, 0)) + 1
	return PackedStringArray(
		[
			(
				"CURSE| runs=%d floors=%d chests=%d cursed=%d (%.3f per floor; floor 1/2/3: %d/%d/%d)"
				% [
					count,
					count * run_def.floors,
					chests,
					cursed,
					cursed / maxf(1.0, count * run_def.floors),
					by_index[1],
					by_index[2],
					by_index[3]
				]
			),
			"CURSE| cursed chests per floor: %s" % _hist(per_floor, count * run_def.floors),
			"CURSE| cursed chests per run: %s" % _hist(per_run, count),
			(
				"CURSE| a cursed chest on a floor right after one with a cursed chest: %d"
				% two_in_a_row
			),
		]
	)


## Floor `floor_index` of run `run_seed` as Main builds it (app/ is off limits to scripts/, so this follows
## FloorScenario.build and EventLab.world): enough for rewards and their offers.
static func _floor(repo: ContentRepository, run_seed: int, floor_index: int) -> World:
	var run := RunState.start(
		run_seed, ContentCompiler.compile_run(repo.get_def(&"run", RunSaver.RUN_ID)), &"blade"
	)
	run.floor_index = floor_index
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, repo.get_def(&"build", &"blade"))
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := FloorShape.boss(
		run, RunContentCompiler.compile_boss_pools(repo, run.table.floors), run.floor_index
	)
	var spec := BossArenaSpec.make(bosses[boss].arena_cells, bosses[boss].arena_template, boss)
	var layout := FloorGenerator.generate(run.floor_seed(), _params(repo))
	BossRoomBuilder.attach(layout, spec)
	OverrunRooms.mark(layout)
	var arenas := RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	ArenaRooms.mark(layout, arenas.share_permille)
	var w := World.new(run.floor_seed(), table, layout.start_pos)
	w.floor_layout = layout
	w.arena_table = arenas
	w.set_enemy_tables(enemies)
	w.spawner = ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo)
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	w.boss_flow = BossFlow.create(spec.boss_index)
	w.reward_table = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))
	w.floor_index = floor_index
	run.prepare(w)
	Rewards.place(w, layout)
	if Routes.is_deep(w):
		Routes.place_deep_rewards(w, layout, run.table.deep_extra_chests)
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	w.legendary_table = RunContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	EventCompiler.setup(w, repo)
	return w


## "value: count (share %)" sorted by value; `n` 0 = counts only.
static func _hist(h: Dictionary, n: int) -> String:
	var keys := h.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		if n > 0:
			parts.append("%s: %d (%.1f%%)" % [str(k), h[k], 100.0 * h[k] / n])
		else:
			parts.append("%s: %d" % [str(k), h[k]])
	return ", ".join(parts)
